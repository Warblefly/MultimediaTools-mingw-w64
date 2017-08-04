/**\file isochapi.c 
 * \brief Isochronous management functions
 * \ingroup capi
 */

/*
 *	Version 6.4
 *
 *  Copyright 8/2006
 *
 *  Christopher Baker
 *  Robotics Institute
 *  Carnegie Mellon University
 *  Pittsburgh, PA
 *
 *	Copyright 5/2000
 * 
 *	Iwan Ulrich
 *	Robotics Institute
 *	Carnegie Mellon University
 *	Pittsburgh, PA
 *
 *  This file is part of the CMU 1394 Digital Camera Driver
 *
 *  The CMU 1394 Digital Camera Driver is free software; you can redistribute 
 *  it and/or modify it under the terms of the GNU Lesser General Public License 
 *  as published by the Free Software Foundation; either version 2.1 of the License,
 *  or (at your option) any later version.
 *
 *  The CMU 1394 Digital Camera Driver is distributed in the hope that it will 
 *  be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with the CMU 1394 Digital Camera Driver; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "pch.h"

/**\brief Set up an isochronous stream.
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param pStreamParams The parameters to use
 * \return ERROR_SUCCESS on success, other codes on error
 * \see t1394IsochTearDownStream
 *
 * This is almost a direct wrapper over IOCTL_ISOCH_SETUP_STREAM, which
 * was introduced for version 6.4
 *
 * This will fail if an isoch stream has already been configured for the camera
 */
DWORD
CAMAPI
t1394IsochSetupStream(
	PSTR szDeviceName ,
	PISOCH_STREAM_PARAMS pStreamParams
	)
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;
	
    hDevice = OpenDevice(szDeviceName, FALSE);
	
    if (hDevice != INVALID_HANDLE_VALUE) {
		
        dwRet = DeviceIoControl( hDevice,
			IOCTL_ISOCH_SETUP_STREAM,
			pStreamParams,
			sizeof(ISOCH_STREAM_PARAMS),
			pStreamParams,
			sizeof(ISOCH_STREAM_PARAMS),
			&dwBytesRet,
			NULL
			);
        // Boolean: True is good, False needs GetLastError()
        dwRet = dwRet ? ERROR_SUCCESS : GetLastError();
        // free up resources
        CloseHandle(hDevice);
    } else {
		dwRet = GetLastError();
	}
	
    return(dwRet);
}

/**\brief Tear down an isochronous stream, if any.
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \return ERROR_SUCCESS on success, other codes on error
 * \see t1394IsochSetupStream
 *
 * This is the counterpart to t1394IsochSetupStream.  It is not harmful to 
 * call it if no stream has been configured, and is in fact the only way to 
 * guarantee that the camera is idle before proceeding with the creation
 * of a new stream.
 */
DWORD
CAMAPI
t1394IsochTearDownStream(
	PSTR szDeviceName 
	)
{
	HANDLE			hDevice;
	DWORD 			dwRet, dwBytesRet;
	
	hDevice = OpenDevice(szDeviceName, FALSE);
	if (hDevice != INVALID_HANDLE_VALUE) {
		
		dwRet = DeviceIoControl(hDevice,
			IOCTL_ISOCH_TEAR_DOWN_STREAM,
			NULL,
			0,
			NULL,
			0,
			&dwBytesRet,
			NULL
			);
        // Boolean: True is good, False needs GetLastError()
        dwRet = dwRet ? ERROR_SUCCESS : GetLastError();
        // free up resources
        CloseHandle(hDevice);
	} else {
		dwRet = GetLastError();
	}
	
	return(dwRet);
}

/**\brief Attach a frame buffer to an isochronous stream.
 * \ingroup capi
 * \param hDevice The device handle to attach to.
 * \param pBuffer The frame buffer
 * \param ulBufferLength The length of the frame buffer
 * \param pParams Pointer to the ISOCH_BUFFER_PARAMS structure to be associated with this buffer
 * \param pOverLapped The overlapped I/O structure to use for asynchronous notification
 * \return ERROR_SUCCESS or ERROR_IO_PENDING on success, other codes on error
 *
 * This will fail with ERROR_INSUFFICIENT_RESOURCES if no stream is in place per t1394IsochSetupStream()
 */
DWORD
CAMAPI
t1394IsochAttachBuffer(
    HANDLE hDevice,
    LPVOID pBuffer,
    ULONG  ulBufferLength,
    PISOCH_BUFFER_PARAMS pParams,
    LPOVERLAPPED pOverLapped
    )
{
	DWORD 			dwRet, dwBytesRet;
	
    dwRet = DeviceIoControl(hDevice,
		IOCTL_ATTACH_BUFFER,
		pParams,
		sizeof(ISOCH_BUFFER_PARAMS),
		pBuffer,
		ulBufferLength,
		&dwBytesRet,
		pOverLapped
		);
    // Boolean: True is good, False needs GetLastError()
    dwRet = dwRet ? ERROR_SUCCESS : GetLastError();
	
    return dwRet;
}

/**\brief Activate isochronous stream reception
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \return ERROR_SUCCESS on success, other codes on error
 *
 * This is almost a direct wrapper over IOCTL_ISOCH_LISTEN, which
 * causes the 1394 bus subsystem to actually start shovelling data
 *
 * This will fail with ERROR_INSUFFICIENT_RESOURCES if no stream is in place per 
 * t1394IsochSetupStream() or if no buffers have been attached.
 */
DWORD
CAMAPI
t1394IsochListen(
    PSTR            szDeviceName
    )
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;
	
    hDevice = OpenDevice(szDeviceName, FALSE);
	
    if (hDevice != INVALID_HANDLE_VALUE) {
		
		dwRet = DeviceIoControl( hDevice,
			IOCTL_ISOCH_LISTEN,
			NULL,
			0,
			NULL,
			0,
			&dwBytesRet,
			NULL
			);
        // Boolean: True is good, False needs GetLastError()
        dwRet = dwRet ? ERROR_SUCCESS : GetLastError();
        // free up resources
        CloseHandle(hDevice);
    }
	
    return(dwRet);
} // IsochListen

/**\brief Dectivate isochronous stream reception
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \return ERROR_SUCCESS on success, other codes on error
 *
 * This is almost a direct wrapper over IOCTL_ISOCH_STOP, which
 * stops the 1394 bus subsystem shovelling data
 *
 * This will fail with ERROR_INSUFFICIENT_RESOURCES if no stream is in place per 
 * t1394IsochSetupStream() or if no buffers have been attached.
 */
DWORD
CAMAPI
t1394IsochStop(
    PSTR            szDeviceName
    )
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;
	
    hDevice = OpenDevice(szDeviceName, FALSE);
	
    if (hDevice != INVALID_HANDLE_VALUE) {
		
		dwRet = DeviceIoControl( hDevice,
			IOCTL_ISOCH_STOP,
			NULL,
			0,
			NULL,
			0,
			&dwBytesRet,
			NULL
			);
        // Boolean: True is good, False needs GetLastError()
        dwRet = dwRet ? ERROR_SUCCESS : GetLastError();
        // free up resources
        CloseHandle(hDevice);
    }
	
    return(dwRet);
} // IsochStop

/**\brief Query the bus cycle time.
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param CycleTime where to put the data
 * \return ERROR_SUCCESS on success, other codes on error
 *
 * The uses of the Cycle Time are slim for us, so this may leave 
 * in a future version
 */
DWORD
CAMAPI
t1394IsochQueryCurrentCycleTime(
    PSTR            szDeviceName,
    PCYCLE_TIME     CycleTime
    )
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;
	
    hDevice = OpenDevice(szDeviceName, FALSE);
	
    if (hDevice != INVALID_HANDLE_VALUE) {
		
        dwRet = DeviceIoControl( hDevice,
			IOCTL_ISOCH_QUERY_CURRENT_CYCLE_TIME,
			NULL,
			0,
			CycleTime,
			sizeof(CYCLE_TIME),
			&dwBytesRet,
			NULL
			);
        // Boolean: True is good, False needs GetLastError()
        dwRet = dwRet ? ERROR_SUCCESS : GetLastError();
        // free up resources
        CloseHandle(hDevice);
    }
	
    return(dwRet);

} // IsochQueryCurrentCycleTime

/**\brief Query the available bus resources
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param isochQueryResources where to put the data
 * \return ERROR_SUCCESS on success, other codes on error
 *
 * Retrieve the available resources (channels, bandwidth, etc) for the bus
 * the camera is attached to.
 */
DWORD
CAMAPI
t1394IsochQueryResources(
    PSTR                        szDeviceName,
    PISOCH_QUERY_RESOURCES      isochQueryResources
    )
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;
	
    hDevice = OpenDevice(szDeviceName, FALSE);
	
    if (hDevice != INVALID_HANDLE_VALUE) {
		
        dwRet = DeviceIoControl( hDevice,
			IOCTL_ISOCH_QUERY_RESOURCES,
			isochQueryResources,
			sizeof(ISOCH_QUERY_RESOURCES),
			isochQueryResources,
			sizeof(ISOCH_QUERY_RESOURCES),
			&dwBytesRet,
			NULL
			);
        // Boolean: True is good, False needs GetLastError()
        dwRet = dwRet ? ERROR_SUCCESS : GetLastError();
        // free up resources
        CloseHandle(hDevice);
    }
	
    return(dwRet);
} // IsochQueryResources

/**\brief It's so sad that the C-standard math library doesn't include gcd
 * \param aa One number
 * \param bb another number
 * \return greatest common divisor
 */
static unsigned long gcd(unsigned long aa, unsigned long bb)
{
    // enforce precondition: a >= b
    if(aa < bb)
    {
        // in-place swap with xor;
        aa ^= bb; bb ^= aa; aa ^= bb;
    }

    // euclid's algo
    while(bb != 0)
    {
        // in-place swap with xor
        aa ^= bb; bb ^= aa; aa ^= bb;
        // modulus for euclid
        bb %= aa;
    }

    return aa;        
}

/**\brief It's so sad that the C-standard math library doesn't include lcm either
 * \param aa One number
 * \param bb another number
 * \return least common multiple
 */
static unsigned long lcm(unsigned long aa, unsigned long bb)
{
    // catch zero explicitly
    if(aa == 0 || bb == 0)
    {
        return 0;
    }

    return (aa / gcd(aa,bb)) * bb;
}

/**\brief Allocate an ACQUISITION_BUFFER structure that satisfies the parameterized constraints:
 * \ingroup capi
 * \param frameBufferSize The number of bytes to allocate in the overall frame buffer
 * \param maxDMABufferSize The maximum number of bytes permissible in a single DMA buffer
 * \param targetBytesPerPacket The isoch packet size that will occur for this transfer (used to break sub-buffers if possible)
 * \param index User-specified semantic "index" for this buffer
 * \return fully-formed ACQUISITON_BUFFER instance on success, NULL on error
 * \see dc1394FreeAcquitionBuffer
 *
 * This used to be embedded in C1394Camera::StartImageAcquisitionEx, but has been extracted here because:
 *  1 - It makes a very useful component of the C API, and
 *  2 - It can be more easily unit tested apart from a C1394Camera Instance
 */

PACQUISITION_BUFFER
CAMAPI
dc1394BuildAcquisitonBuffer(ULONG frameBufferSize, ULONG maxDMABufferSize, ULONG targetBytesPerPacket, ULONG index)
{
    PACQUISITION_BUFFER pAcqBuffer = NULL;
    ULONG leadingBufferSize = 0, leadingBuffers = 0, trailingBufferSize = frameBufferSize;
    ULONG ii;
    unsigned char *pSubBufferStart = NULL;

    // grab a system_info struct so we know about page alignment
    SYSTEM_INFO si;
    GetSystemInfo(&si);

    // At least on 64-bit systems, the maxDMABufferSize seems to be reported one page larger than it actually is, so
    // shave off a page at this point.  This won't hurt things on 32-bit systems, unless you intend to allocate a ~3GB frame buffer
    maxDMABufferSize -= si.dwPageSize;

    // allocate the buffer header (stores data about the whole (set of) buffer(s))
    pAcqBuffer = (PACQUISITION_BUFFER) GlobalAlloc(LPTR,sizeof(ACQUISITION_BUFFER));
    if(pAcqBuffer == NULL)
    {
        DllTrace(DLL_TRACE_ERROR,"dc1394BuildAcquisitionBuffer: Failed to allocate buffer header (%d bytes)!",
                 sizeof(ACQUISITION_BUFFER));
        return NULL;
    }

    // initialize pAcqBuf to ensure proper cleanup on failure
    pAcqBuffer->index = -1;
    pAcqBuffer->pDataBuf = NULL;
    pAcqBuffer->pFrameStart = NULL;
    pAcqBuffer->pNextBuffer = NULL;
    pAcqBuffer->bNativelyContiguous = TRUE;
    pAcqBuffer->bCurrentlyContiguous = TRUE;
    pAcqBuffer->nSubBuffers = 0;
    pAcqBuffer->ulBufferSize = 0;

    for(ii = 0; ii < MAX_SUB_BUFFERS; ++ii)
    {
        pAcqBuffer->subBuffers[ii].pData = NULL;
        pAcqBuffer->subBuffers[ii].ulSize = 0;
        pAcqBuffer->subBuffers[ii].overLapped.hEvent = NULL;
    }

    // set the index (mostly for debugging purposes)
    pAcqBuffer->index = index;
    pAcqBuffer->ulBufferSize = frameBufferSize;

    if(trailingBufferSize > maxDMABufferSize)
    {
        // todo: LCM of pagesize and targetBytesPerPacket?
        unsigned long perfectBufferSize = lcm(targetBytesPerPacket,si.dwPageSize);
        if(perfectBufferSize > maxDMABufferSize)
        {
            DllTrace(DLL_TRACE_WARNING,"dc1394BuildAcquisitionBuffer: LCM(%u,%u) = %u exceeds max buffer size (%u), framebuffer will require flattening!",
                targetBytesPerPacket,si.dwPageSize,perfectBufferSize,maxDMABufferSize);
            leadingBufferSize = maxDMABufferSize - (maxDMABufferSize % targetBytesPerPacket);
            pAcqBuffer->bNativelyContiguous = FALSE;
        } else {
            // we actually alias correctly, use the largest multiple less than maxDMABufferSize;
            unsigned long numPerfectBuffers = maxDMABufferSize / perfectBufferSize;
            leadingBufferSize = perfectBufferSize * numPerfectBuffers;
            DllTrace(DLL_TRACE_CHECK,"dc1394BuildAcquisitionBuffer: using %u * LCM(%u,%u) = %u for leading buffer size...",
                numPerfectBuffers,targetBytesPerPacket,si.dwPageSize,leadingBufferSize);
        }

        leadingBuffers = trailingBufferSize / leadingBufferSize;
        trailingBufferSize -= leadingBuffers * leadingBufferSize;

        // catch the "exact fit case, make sure we always have a trailing buffer"
        if(trailingBufferSize == 0)
        {
            trailingBufferSize = leadingBufferSize;
            leadingBuffers--;
        }
    }

    // make sure we can handle it: presently, MAX_SUB_BUFFFERS is 64, which gets us up to
    // ~60MB, which would be a 20-megapixel RGB image (10-megapixel if 16-bit)
    // the general-case solution is to allocate the ACQUISITION_BUFFER dynamically as something like
    // sizeof(ACQUISITON_BUFFER) + nSubBuffers * sizeof(struct ACQUISITION_BUFFER::_subBuffer[1])
    pAcqBuffer->nSubBuffers = leadingBuffers + 1;
    if(pAcqBuffer->nSubBuffers > MAX_SUB_BUFFERS)
    {
        DllTrace(DLL_TRACE_ERROR,"dc1394BuildAcquisitionBuffer: %u-byte frame buffer at %u bytes per packet requires %u sub-buffers, which exceeds maximum of %u",
                 frameBufferSize,targetBytesPerPacket,pAcqBuffer->nSubBuffers,MAX_SUB_BUFFERS);
        GlobalFree(pAcqBuffer);
        return NULL;
    }

    DllTrace(DLL_TRACE_CHECK,"Allocating %lu-byte frame buffer as %lu buffer(s) (leading buffer(s) = %lu bytes, trailing buffer = %lu bytes, %s",
             pAcqBuffer->ulBufferSize,pAcqBuffer->nSubBuffers,leadingBufferSize,trailingBufferSize,
             pAcqBuffer->bNativelyContiguous ? "Contiguous" : "NON-Contiguous");

    // allocate the actual frame buffer
    // the buffer passed to ATTACH_BUFFER must be aligned on a page boundary, so we must
    // allocate an extra page per sub-buffer, and make sure that each one starts at a page boundary
    pAcqBuffer->pDataBuf = (unsigned char *)GlobalAlloc(LPTR,frameBufferSize + si.dwPageSize * pAcqBuffer->nSubBuffers);
    if(pAcqBuffer->pDataBuf == NULL)
    {
        DllTrace(DLL_TRACE_ERROR,"dc1394BuildAcquisitionBuffer: Failed to allocate actual frame buffer (%d bytes)",
                 frameBufferSize + si.dwPageSize);
        GlobalFree(pAcqBuffer);
        return NULL;
    }

    // point pFrameStart at the first page boundary
    pAcqBuffer->pFrameStart = pAcqBuffer->pDataBuf + (si.dwPageSize - (((unsigned long)(pAcqBuffer->pDataBuf)) % si.dwPageSize));
    DllTrace(DLL_TRACE_CHECK,"dc1394BuildAcquisitionBuffer: Shifted FrameStart from %p to %p to accommodate page size 0x%x",
             pAcqBuffer->pDataBuf, pAcqBuffer->pFrameStart, si.dwPageSize);

    pSubBufferStart = pAcqBuffer->pFrameStart;

    // note: <= because we always make a "trailing buffer"
    for(ii = 0; ii <= leadingBuffers; ++ii)
    {
        pAcqBuffer->subBuffers[ii].pData = pSubBufferStart;
        pSubBufferStart += leadingBufferSize;
        if((ii < leadingBuffers) && (leadingBufferSize % si.dwPageSize) != 0)
        {
            // bump the sub-buffer pointer to the next page
            ULONG ulPageOffset = (si.dwPageSize - (leadingBufferSize % si.dwPageSize));
            DllTrace(DLL_TRACE_CHECK,"  -> Advancing Sub-Buffer %u.%u from %p to %p for page alignment",
                            pAcqBuffer->index,ii+1,pSubBufferStart,pSubBufferStart+ulPageOffset);
            pSubBufferStart += ulPageOffset;
        }
        pAcqBuffer->subBuffers[ii].ulSize = (ii < leadingBuffers ? leadingBufferSize : trailingBufferSize);

        // give the overlapped structure an event
        pAcqBuffer->subBuffers[ii].overLapped.hEvent = CreateEvent(NULL,TRUE,FALSE,NULL);
        if(pAcqBuffer->subBuffers[ii].overLapped.hEvent == NULL)
        {
            DllTrace(DLL_TRACE_ERROR,"Failed to create Overlapped Event for sub-buffer %u (%s)",ii,WinStrError(GetLastError()));
            dc1394FreeAcquisitionBuffer(pAcqBuffer);
            return NULL;
        }
    }
    return pAcqBuffer;
}

/**\brief Encapsulate the de-allocation policy for an ACQUISITION_BUFFER
 * \ingroup capi
 * \param pAcqBuffer the buffer to tear down
 */
void CAMAPI dc1394FreeAcquisitionBuffer(PACQUISITION_BUFFER pAcqBuffer)
{
    ULONG ii;
    if(pAcqBuffer == NULL)
    {
        DllTrace(DLL_TRACE_ERROR,"I refuse to free an already-NULL acquisition buffer!");
        return; // embedded failure case
    }

    // there is an overlapped event to free per sub buffer
    for(ii = 0; ii<pAcqBuffer->nSubBuffers; ++ii)
    {
        // close event if non-null
        if(pAcqBuffer->subBuffers[ii].overLapped.hEvent != NULL)
        {
            CloseHandle(pAcqBuffer->subBuffers[ii].overLapped.hEvent);
            pAcqBuffer->subBuffers[ii].overLapped.hEvent = NULL;
        } else {
            DllTrace(DLL_TRACE_WARNING,"Skipping NULL overlapped event for sub-buffer %u of buffer %u @ %p",
                                       ii,pAcqBuffer->index,pAcqBuffer);
        }
    }

    // free data buffer
    if(pAcqBuffer->pDataBuf != NULL)
    {
        GlobalFree(pAcqBuffer->pDataBuf);
        pAcqBuffer->pDataBuf = NULL;
    }

    // free buffer header
    GlobalFree(pAcqBuffer);
}

/**\brief Encapsulate the attachment policy for an ACQUISITION_BUFFER
 * \ingroup capi
 * \param hDevice the device handle to attach to
 * \param pAcqBuffer the buffer to attach
 * \return windows error code (ERROR_SUCCESS = success)
 */
DWORD CAMAPI dc1394AttachAcquisitionBuffer(HANDLE hDevice, PACQUISITION_BUFFER pAcqBuffer)
{
    DWORD dwRet = 0;
    unsigned int ii;
    ISOCH_BUFFER_PARAMS bufParams;

    if(pAcqBuffer == NULL || hDevice == INVALID_HANDLE_VALUE)
    {
        DllTrace(DLL_TRACE_ERROR,"Bad arguments passed to dc1394AttachAcquisitionBuffer(%p,%p)",hDevice,pAcqBuffer);
        return ERROR_INVALID_PARAMETER;
    } 

    for(ii = 0; ii<pAcqBuffer->nSubBuffers; ++ii)
    {
        // reset the overlapped event
        ResetEvent(pAcqBuffer->subBuffers[ii].overLapped.hEvent);

        DllTrace(DLL_TRACE_VERBOSE,"Attaching Acquisition buffer %d.%d, size:%d, FrameStart:%p\n",
            pAcqBuffer->index,
            ii,
            pAcqBuffer->subBuffers[ii].ulSize,
            pAcqBuffer->subBuffers[ii].pData);

        // construct the buffer parameters structure
        bufParams.ulFlags = (ii == 0 ? ISOCH_BUFFER_PRIMARY : ISOCH_BUFFER_SECONDARY);

        // attach
        dwRet = t1394IsochAttachBuffer( hDevice,
                                        pAcqBuffer->subBuffers[ii].pData,
                                        pAcqBuffer->subBuffers[ii].ulSize,
                                        &bufParams,
                                        &(pAcqBuffer->subBuffers[ii].overLapped) );

        // crb: at this point, we always expect PENDING, right?  What does SUCCESS mean here?
        if ((dwRet != ERROR_IO_PENDING) && (dwRet != ERROR_SUCCESS)) 
        {
            DllTrace(DLL_TRACE_ERROR,"Error while attaching buffer %u.%u: %s\n",
                     pAcqBuffer->index,ii,WinStrError(dwRet));
            // propagate the error upstream
            return dwRet;
        }
    }

    // successfully attached all buffers, reset the contiguity flag as necessary and return SUCCESS
    pAcqBuffer->bCurrentlyContiguous = pAcqBuffer->bNativelyContiguous;
    return ERROR_SUCCESS;
}

void CAMAPI dc1394FlattenAcquisitionBuffer(PACQUISITION_BUFFER pAcqBuffer)
{
    // note: our data buffers are guaranteed to be a multiple of 4, because all mechanisms
    // in the IIDC 1394 spec specify "quadlets" per packet
    // so, treating these as 32-bit quads will move things along more quickly
    PULONG pout, pin, pend;
    unsigned int ii;
    if(pAcqBuffer != NULL)
    {
        if(!pAcqBuffer->bCurrentlyContiguous)
        {
            pout = (PULONG)(pAcqBuffer->subBuffers[0].pData + pAcqBuffer->subBuffers[0].ulSize);
            DllTrace(DLL_TRACE_CHECK,"Flattening acquisition buffer %u, starting at the end of the first sub-buffer, %u sub-buffers to 'flatten' thereafter",
                     pAcqBuffer->index,pAcqBuffer->nSubBuffers - 1);
            for(ii = 1; ii<pAcqBuffer->nSubBuffers; ++ii)
            {
                // note: leaving pout untouched and resetting pin/pend for every buffer is what accomplishes the "flattening"
                pin = (PULONG) pAcqBuffer->subBuffers[ii].pData;
                pend = (PULONG) (pAcqBuffer->subBuffers[ii].pData + pAcqBuffer->subBuffers[ii].ulSize);
                while(pin < pend)
                {
                    *pout++ = *pin++;
                }
            }
        } // else already contiguous... no op
    } else {
        DllTrace(DLL_TRACE_WARNING,"I refuse to flatten a NULL acquisition buffer!");
    }
}