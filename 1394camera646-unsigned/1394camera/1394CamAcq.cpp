/**\file 1394CamAcq.cpp
 * \brief Implements Acquisition functionality for the 1394Camera class
 * \ingroup camacq
 */

//////////////////////////////////////////////////////////////////////
//
//	Version 6.4
//
//  Copyright 8/2006
//
//  Christopher Baker
//  Robotics Institute
//  Carnegie Mellon University
//  Pittsburgh, PA
//
//	Copyright 5/2000
// 
//	Iwan Ulrich
//	Robotics Institute
//	Carnegie Mellon University
//	Pittsburgh, PA
//
//  This file is part of the CMU 1394 Digital Camera Driver
//
//  The CMU 1394 Digital Camera Driver is free software; you can redistribute 
//  it and/or modify it under the terms of the GNU Lesser General Public License 
//  as published by the Free Software Foundation; either version 2.1 of the License,
//  or (at your option) any later version.
//
//  The CMU 1394 Digital Camera Driver is distributed in the hope that it will 
//  be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with the CMU 1394 Digital Camera Driver; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//////////////////////////////////////////////////////////////////////

#include "pch.h"

/** \defgroup camacq Frame Acquisition
 *  \brief This is the primary means of grabbing camera frames via the 1394 bus.
 *  \ingroup camcore
 *
 * The I/O model for image acquisition is as follows:
 * - A handful of image buffers are maintained as a circularly-linked list.
 *
 * - The buffer pointed to by m_pCurrentBuffer is the "Current Buffer" and
 *     is guaranteed to not be attached to the isochronous buffer queue.
 *
 * - The buffer pointed to by m_pLastBuffer is the last buffer in the list
 *     to have undergone the IOTCL_ATTACH_BUFFER prodecure.  Under most 
 *     circumstances, the buffer immediately following m_pLastBuffer will
 *     be m_pCurrentBuffer
 *
 * - As each buffer is "acquired", that buffer becomes the "Current Buffer"
 *     all buffers between m_pLastBuffer and the new m_pCurrentBuffer are 
 *     reattached to the isochronous buffer queue
 */

/**
 * \brief Initialize the Image Acquisition Process
 * \ingroup camacq
 * \param nBuffers The number of buffers to allocate.  Minimum of 1
 * \param FrameTimeout Timeout, in milliseconds for blocking calls to AcquireImageEx();
 * \param Flags Acquisition Flags, \see acqflags
 * \return
 * - <b>CAM_SUCCESS</b> The camera is ready. Call AcquireImage() to grab frames 
 * - <b>CAM_ERROR_NOT_INITIALIZED</b> No camera has been selected and/or InitCamera has not been successfully called 
 * - <b>CAM_ERROR_INVALID_VIDEO_SETTINGS</b> The current video settings (format, mode, and/or rate) are not supported. 
 * - <b>CAM_ERROR_BUSY</b> The camera is already capturing or acquiring images
 * - <b>CAM_ERROR_INSUFFICIENT_RESOURCES</b> Not enough 1394 bus resoures are available to complete the operation 
 * - <b>ERROR_OUTOFMEMORY</b> GlobalAlloc for the descriptors or for the buffers has failed
 * - <i>Any other windows error code</i> Bad things happened on DeviceIoControl or on GetOverlappedResult. The particular error code indicates just what
 * 
 * Allocates and Attaches Frame Buffers, configures kernel-side 1394 resources, and (optionally) starts image streaming
 */
int C1394Camera::StartImageAcquisitionEx(int nBuffers, int FrameTimeout, int Flags)
{
	PACQUISITION_BUFFER				pAcqBuffer = NULL;
	DWORD							dwRet;
	HANDLE							hdev;
	int ii,retval = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER StartImageAcquisition (nBuffers = %d)\n",nBuffers);
	
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: The Camera is already acquiring images, call StopImageAcquisition first\n");
		retval =  CAM_ERROR_BUSY;
		goto _exit;
	}
	
	if(!m_cameraInitialized)
	{
		DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: Call InitCamera() first.\n");
		retval =  CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	if(nBuffers < 1)
	{
		DllTrace(DLL_TRACE_ERROR,"AcquireImage: Invalid number of buffers: %d\n",nBuffers);
		retval = CAM_ERROR_PARAM_OUT_OF_RANGE;
		goto _exit;
	}
	
	if(!CheckVideoSettings())
	{
		DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: CheckVideoSettings Failed\n");
		retval =  CAM_ERROR_INVALID_VIDEO_SETTINGS;
		goto _exit;
	}
	
	// adopt the incoming timeout and flags
	this->m_AcquisitionTimeout = FrameTimeout;
	this->m_AcquisitionFlags = Flags;
	this->m_AcquisitionBuffers = nBuffers;
	
	if(!InitResources())
	{
		DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: InitResources Failed\n");
		retval =  CAM_ERROR_INSUFFICIENT_RESOURCES;
		goto _exit;
	}
	
	///////////////////////////////////////////
	// allocate and set up the frame buffers //
	///////////////////////////////////////////
	
	DllTrace(DLL_TRACE_CHECK,"StartImageAcquisition: Initializing Buffers...\n");

    ULARGE_INTEGER uliDMABufferSize;
	t1394_GetHostDmaCapabilities(m_pName,NULL,&uliDMABufferSize);
	for(ii=0; ii<nBuffers; ii++)
	{
        pAcqBuffer = dc1394BuildAcquisitonBuffer(m_maxBufferSize,
                                                 (unsigned long)(uliDMABufferSize.QuadPart),
                                                 m_maxBytes,
                                                 ii);
		if(!pAcqBuffer)
		{
			DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: Error Allocating AcqBuffer %u\n",ii);
			retval = CAM_ERROR_INSUFFICIENT_RESOURCES;
			goto _exit;
		}
		
		// add it to our list of buffers
		if(ii == 0)
		{
			m_pLastBuffer = m_pFirstBuffer = pAcqBuffer;
			m_pLastBuffer->pNextBuffer = m_pCurrentBuffer = NULL;
		} else {
			m_pFirstBuffer->pNextBuffer = pAcqBuffer;
			m_pFirstBuffer = pAcqBuffer;
		}
        DllTrace(DLL_TRACE_CHECK,"StartImageAcquisition: Successfully Allocated buffer %u\n",ii);
	}
	
	// all done making buffers
	// open our long term device handle
	if((hdev = OpenDevice(m_pName, TRUE)) == INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: error opening device (%s)\n",m_pName);
		goto _exit;
	}
	
	// attach all our buffers
    DllTrace(DLL_TRACE_CHECK, "StartImageAcquisition: Attaching Buffers\n");
    for(pAcqBuffer = m_pLastBuffer; pAcqBuffer != NULL; pAcqBuffer = pAcqBuffer->pNextBuffer)
	{
        if(dc1394AttachAcquisitionBuffer(hdev,pAcqBuffer) != ERROR_SUCCESS)

        {
            // bad things have happened: bail and let StopImageAcquisition() clean up
            DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: Failed to attach buffer %u/%u",pAcqBuffer->index,nBuffers);
            goto _exit;
        }
    }

    // new: sleep a little while and verify that the buffers were successfully attached
    // this basically catches "Parameter is Incorrect" here instead of confusing users at AcquireImageEx()

    Sleep(50); // 50 ms is all it should take for completion routines to fire and propagate in the kernel
    for(pAcqBuffer = m_pLastBuffer; pAcqBuffer != NULL; pAcqBuffer = pAcqBuffer->pNextBuffer)
    {
        DWORD dwBytesRet = 0;
        for(unsigned int bb = 0; bb<pAcqBuffer->nSubBuffers; ++bb)
        {
            if(!GetOverlappedResult(hdev,&(pAcqBuffer->subBuffers[bb].overLapped), &dwBytesRet, FALSE))
            {
                if(GetLastError() != ERROR_IO_INCOMPLETE)
                {
                    DllTrace(DLL_TRACE_ERROR,"Buffer validation failed for buffer %u.%u : %s",
                             pAcqBuffer->index,bb,StrLastError());
                    goto _exit;
                } // else: this is the actual success case
            } else {
                DllTrace(DLL_TRACE_ERROR,"Buffer %u.%u is unexpectedly ready during pre-listen validation",
                                         pAcqBuffer->index,bb,StrLastError());
                goto _exit;
            }
        }
    }

	// all successfully attached, time to isoch listen
	if((dwRet = t1394IsochListen(m_pName)) != ERROR_SUCCESS)
	{
		DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: Error %08x on IOCTL_ISOCH_LISTEN\n",dwRet);
		goto _exit;
	}
	
	// start streaming if necessary
	if(this->m_AcquisitionFlags & ACQ_START_VIDEO_STREAM)
	{
		if((retval = StartVideoStream()) != CAM_SUCCESS)
			goto _exit;
	}
	
	// if we get here, everything is cool
	m_hDeviceAcquisition = hdev;
	retval =  CAM_SUCCESS;
	
_exit:
	
	if(retval != CAM_SUCCESS)
	{
		// we go here if something breaks and we need to clean up anything we've allocated thus far
		DllTrace(DLL_TRACE_ERROR,"StartImageAcquisition: Error on setup, Cleaning up...\n");
		this->StopImageAcquisition();
	}
	
	DllTrace(DLL_TRACE_EXIT,"EXIT StartImageAcquisition (%d)\n",retval);
	return retval;
}

/**
 * \brief Initialize the Image Acquisition Process
 * \ingroup camacq
 * \return same as StartImageAcquisitionEx()
 *
 * As of Version 6.3, this wraps StartImageAcquisitionEx() for backwards compatiblility.
 * It is equivalent to StartImageAcquisitionEx(6,1000,ACQ_START_VIDEO_STREAM)
 */
int C1394Camera::StartImageAcquisition()
{
	return StartImageAcquisitionEx(6,1000,ACQ_START_VIDEO_STREAM);
}

/**
 * \brief Grab the most recent frame from the queue, dropping stale frames.
 * \ingroup camacq
 * \return same as AcquireImageEx()
 *
 * As of Version 6.3, this wraps AcquireImageEx() for backwards compatiblility.
 * It is equivalent to AcquireImageEx(TRUE,NULL)
 */
int C1394Camera::AcquireImage()
{
	return AcquireImageEx(TRUE,NULL);
}

/**
 * \brief Grab a frame off the queue.
 * \ingroup camacq
 * \param DropStaleFrames Boolean: whether to skip stale frames in the list
 * \param lpnDroppedFrames: where to put the  number of dropped frames
 * \return
 * - <b>CAM_SUCCESS</b> An image was successfully grabbed and the data awaits 
 * - <b>CAM_ERROR_NOT_INITIALIZED</b> StartImageAcquisitionEx() has not been successfully called.
 * - <i>Any other windows error code</i> Bad things happened on DeviceIoControl or on GetOverlappedResult.<i>GetLastError</i> will indicate what.
 *
 * According to the model, this reattaches all buffers that have fallen off up to, but not including the
 * buffer described by C1394camera::m_pCurrentBuffer, thus maintaining all invaraints
 *   
 * Also, this will block until at least the next buffer in the isochronous queue is ready.  To avoid Blocking, see GetFrameEvent()
 */
int C1394Camera::AcquireImageEx(BOOL DropStaleFrames, int *lpnDroppedFrames)
{
	DWORD dwRet=0, dwBytesRet=0;
	BOOL ready=FALSE,bWaited=FALSE;
	int frameCount=0;
	int ret = CAM_ERROR; // default return value is CAM_ERROR
	
	DllTrace(DLL_TRACE_ENTER,"ENTER AcquireImage\n");
	
	if(m_hDeviceAcquisition == INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"AcquireImage: Not Acquiring Images: Call StartImageAcquisition First");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	// this loop is basically: attach the "current" buffer and snag the next until we have something or we time out
	do
	{
		// first things first, attach the current buffer, if possible
		if(m_pCurrentBuffer != NULL)
		{
            if(dc1394AttachAcquisitionBuffer(m_hDeviceAcquisition,m_pCurrentBuffer) != ERROR_SUCCESS)
            {
                DllTrace(DLL_TRACE_ERROR,"AcquireImage: Error Reattaching current buffer!");
                goto _exit;
            }

			// push m_pCurrentBuffer onto the Buffer Queue
            // Note: m_pFirstBuffer is the most recently attached buffer, which is at the end of the queue (confusing names...)
			if(m_pFirstBuffer == NULL)
			{
                // there is only one buffer, and we just attached it
				m_pLastBuffer = m_pCurrentBuffer;
			} else {
                // current buffer goes onto the end of the queue
				m_pFirstBuffer->pNextBuffer = m_pCurrentBuffer;
			}

            // current buffer is now the most recently attached buffer
			m_pFirstBuffer = m_pCurrentBuffer;

            // which marks the end of the line
			m_pFirstBuffer->pNextBuffer = NULL;

            // and means that there is, for now, no "current" buffer
            m_pCurrentBuffer = NULL;
		}
		
		// Poll the oldest frame on the queue for completion
        LPOVERLAPPED pOverlapped = &(m_pLastBuffer->subBuffers[m_pLastBuffer->nSubBuffers - 1].overLapped);
        ready = GetOverlappedResult(m_hDeviceAcquisition,pOverlapped,&dwBytesRet, FALSE);
		if(!ready)
		{
            // no frame ready yet, let's figure out why...
			dwRet = GetLastError();
			if(dwRet == ERROR_IO_INCOMPLETE) 
			{
				// try waiting
				DllTrace(DLL_TRACE_VERBOSE,"AcquireImage: First Frame Incomplete, blocking...\n");
				dwRet = WaitForSingleObject(
                    pOverlapped->hEvent,
					this->m_AcquisitionTimeout >= 0 ? this->m_AcquisitionTimeout : INFINITE ); //crb: is INFINITE ever a good idea here?

				if(dwRet == WAIT_OBJECT_0)
				{
					// the wait worked, check the result
                    ready = GetOverlappedResult(m_hDeviceAcquisition, pOverlapped, &dwBytesRet, FALSE);
					if(!ready)
					{
                        DllTrace(DLL_TRACE_ERROR,"AcquireImage: Error while getting overlapped result (post-wait):%s",StrLastError());
						goto _exit;
					} else {
                        // success, and we had to waited, so this is our first non-stale frame
						bWaited = TRUE;
					}
				} else {
					if(dwRet == WAIT_TIMEOUT)
					{
						DllTrace(DLL_TRACE_VERBOSE,"AcquireImage: Timeout waiting for frame %d\n",m_pLastBuffer->index);
						ret = CAM_ERROR_FRAME_TIMEOUT;
						goto _exit;
					} else {
                        DllTrace(DLL_TRACE_ERROR,"AcquireImage: Error on WaitForSingleObject: %s\n",StrLastError());
						goto _exit;
					}
				}        
			} else {
                DllTrace(DLL_TRACE_ERROR,"AcquireImage: Error while Getting Overlapped Result (Initial Poll): %s\n",StrLastError());
				goto _exit;
			}
		}
		
		if(ready)
		{
			DllTrace(DLL_TRACE_VERBOSE,"AcquireImage: Frame %d is ready\n",m_pLastBuffer->index);
            // pull it off the queue as the "current" buffer
			m_pCurrentBuffer = m_pLastBuffer;

            // advance the buffer queue
			m_pLastBuffer = m_pLastBuffer->pNextBuffer;

            // handle the single-buffer case (again, this would be more clear as simply "head" and "tail"
			if(m_pLastBuffer == NULL)
				m_pFirstBuffer = NULL;

            // increment the total number of frames
			++frameCount;
		}
	} while(DropStaleFrames && !bWaited);
	
	DllTrace(DLL_TRACE_VERBOSE,"AcquireImage: Current Buffer is now %d, data at %08x\n",m_pCurrentBuffer->index, m_pCurrentBuffer->pFrameStart);
	
	if(lpnDroppedFrames)
    {
        // give the dropped-frame count to the user
		*lpnDroppedFrames = frameCount - 1;
    } else {
        // trace at warning level for dropped frames
        if(frameCount > 1)
        {
            DllTrace(DLL_TRACE_WARNING,"AcquireImage: (almost) silently dropping %d frames\n",frameCount - 1);
        }
    }

	ret = CAM_SUCCESS;

_exit:

    DllTrace(DLL_TRACE_EXIT,"EXIT AcquireImage (%d)\n",ret);
	return ret;
}

/**
 * \brief Halt frame transfer and free bus resources.
 * \ingroup camacq
 * \return
 * - <b>CAM_SUCCESS</b> This is slightly deceptive in that it will return "success" 
 *    regardless of whether is successfully turned things off. If it does encounter 
 *    an error in the process, it traces it, but then continues on to free whatever remaining resource it can. 
 * - <b>CAM_ERROR_NOT_INITIALIZED</b> StartImageAcquisitionEx() has not been successfully called.
 *
 *  This function stops the camera stream, cancels pending I/O for any attached buffers, and frees all resources
 *  (memory, bandwidth, events, handles, etc.) allocated by StartImageAcquisitionEx()
 */
int C1394Camera::StopImageAcquisition()
{
	DWORD							dwBytesRet;
	PACQUISITION_BUFFER				pAcqBuffer = NULL;
	int ret;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER StopImageAcquisition\n");
	
	if(m_hDeviceAcquisition == INVALID_HANDLE_VALUE)
		DllTrace(DLL_TRACE_WARNING,"StopImageAcquisition: Called with invalid device handle\n");
	
	if(this->m_AcquisitionFlags & ACQ_START_VIDEO_STREAM)
		StopVideoStream();
	
	// Tear down the stream
	if(!FreeResources())
		DllTrace(DLL_TRACE_WARNING,"StartmageAcquisition: Cleanup Warning: FreeResources() failed\n");
	
	// put m_pCurrentBuffer on the list for the sake of cleanup
	if(m_pCurrentBuffer != NULL)
	{
		m_pCurrentBuffer->pNextBuffer = m_pLastBuffer;
		m_pLastBuffer = m_pCurrentBuffer;
	}
	
	while(m_pLastBuffer)
	{
		DllTrace(DLL_TRACE_VERBOSE,"StopImageAcquisition: Removing buffer %d\n",m_pLastBuffer->index);
		if(m_pLastBuffer != m_pCurrentBuffer)
		{
			// check the IO status, just in case
            for(unsigned int ii = 0; ii<m_pLastBuffer->nSubBuffers; ++ii)
            {
    			DllTrace(DLL_TRACE_CHECK,"StopImageAcquisition: Checking on buffer %d.%d\n",m_pLastBuffer->index,ii);
	    		if(!GetOverlappedResult(m_hDeviceAcquisition, &m_pLastBuffer->subBuffers[ii].overLapped, &dwBytesRet, TRUE))
		    	{
			    	DllTrace(DLL_TRACE_WARNING,"StopImageAcqisition: Warning Buffer %d.%d has not been detached, error = %d\n",
				    	m_pLastBuffer->index,ii,GetLastError());
			    }
            }
		}
		
		// check the IO status, just in case
        for(unsigned int ii = 0; ii<m_pLastBuffer->nSubBuffers; ++ii)
        {
		    // close event: NOTE: must pre-populate correctly above
		    if(m_pLastBuffer->subBuffers[ii].overLapped.hEvent != NULL)
			{
			    CloseHandle(m_pLastBuffer->subBuffers[ii].overLapped.hEvent);
				m_pLastBuffer->subBuffers[ii].overLapped.hEvent = NULL;
			}
        }

		// free data buffer
		if(m_pLastBuffer->pDataBuf)
			GlobalFree(m_pLastBuffer->pDataBuf);
		
		// advance to next buffer
		pAcqBuffer = m_pLastBuffer;
		m_pLastBuffer = m_pLastBuffer->pNextBuffer;
		
		// free buffer struct
		GlobalFree(pAcqBuffer);
	}
	
	// clean up our junk
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		CloseHandle(m_hDeviceAcquisition);
		m_hDeviceAcquisition = INVALID_HANDLE_VALUE;
	}

	m_pFirstBuffer = m_pLastBuffer = m_pCurrentBuffer = NULL;
	this->m_AcquisitionTimeout = 0;
	this->m_AcquisitionFlags = 0;
	this->m_AcquisitionBuffers = 0;

	ret = CAM_SUCCESS;
	DllTrace(DLL_TRACE_EXIT,"EXIT StopImageAcquisition (%d)\n",ret);
	return ret;
}

/**
 * \brief Retrieve the synchronization event for the next pending frame
 * \ingroup camacq
 * \return
 *  - Asynchronous Event Handle for the next pending frame on the list
 *  - INVALID_HANDLE_VALUE if there is no pending frame (not Acquiring images, or else the single buffer case)
 *
 *  This is a minor hack to allow blocking on multiple cameras via WaitForMultipleObjects.
 *  Once this event is triggered, the next call to AcquireImageEx() is guaranteed not to block.
 *  This must be called after each call to AcquireImageEx() to retrieve the proper handle for the next pending frame.
 *
 *  If StartImageAcquisitionEx() was called with nBuffers=1, then this will only return a valid handle after a call to 
 *  AcquireImageEx() that returns CAM_ERROR_FRAME_TIMEOUT
 */
 HANDLE C1394Camera::GetFrameEvent()
 {
	 if(m_pLastBuffer)
		 return m_pLastBuffer->subBuffers[m_pLastBuffer->nSubBuffers - 1].overLapped.hEvent;
	 else
		 return INVALID_HANDLE_VALUE;
 }

/**\brief Get a pointer to the raw frame data from the current frame
 * \ingroup camacq
 * \param pLength If non-NULL, receives the length (in bytes) of the frame data
 * \return Pointer to the first byte of frame data, or NULL if none is available
 *
 * This is a safety-checked accessor for m_pCurrentBuffer
 */
unsigned char *C1394Camera::GetRawData(unsigned long *pLength)
{
	if(this->m_pCurrentBuffer)
	{
        // flatten the buffer before returning the internal pointer
        // note: this can only be made more efficient via the "smart" way discussed in CamRGB.cpp: provide
        // an stl-containerlike iterator mechanism that "hides" the flattened-or-not-ness.  Putting that here
        // would, however, break the external API in a way that might require a majorversion bump...
        dc1394FlattenAcquisitionBuffer(m_pCurrentBuffer);

		if(pLength)
			*pLength = m_pCurrentBuffer->ulBufferSize;
		return m_pCurrentBuffer->pFrameStart;

	} else {
		if(pLength)
			*pLength = 0;
		return NULL;
	}
}
