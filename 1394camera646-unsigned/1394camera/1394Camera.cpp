/**\file 1394Camera.cpp
 * \brief Implements the core members of the C1394Camera class.
 * \ingroup camcore
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

/** \defgroup camcore Camera Control
 *  \brief This is the core functionality for dealing with cameras via 1394
 */

/****************************************************/
/*                                                  */
/*            PUBLIC MEMBER FUNCTIONS               */
/*                                                  */
/****************************************************/

/**\brief Initializes a C1394Camera class
 * \ingroup camcore
 *
 * The constructor initializes internal state and assigns register offsets and parent pointers
 * to the public C1394CameraControl members.  Many C++ compilers moan about using <i>this</i> 
 * in initializers, and justifiably so.  Each of these constructors does nothing more than store 
 * <i>this</i> as its parent camera pointer.  No further processing is done downstream of the constructor.
 */ 
C1394Camera::C1394Camera():
	m_pName(NULL),
	m_linkChecked(false),
	m_cameraInitialized(false),
	m_node(-1),
	m_hDeviceAcquisition(INVALID_HANDLE_VALUE),
	m_hDevInfo(INVALID_HANDLE_VALUE),
	m_dwDevCount(0),  
	m_videoFormat(0),
	m_videoMode(0),
	m_videoFrameRate(0),
	m_InqBasicFunc(0),
	m_InqFeatureHi(0),
	m_InqFeatureLo(0),
	m_InqOptionalFunc(0),
	m_StatusPowerControl(0),
	m_StatusVideoError(0),
	m_StatusVideoDepth(0),
	m_StatusFeatureErrorHi(0),
	m_StatusFeatureErrorLo(0),
	m_AdvFuncOffset(0),
	m_PIOFuncOffset(0),
	m_SIOFuncOffset(0),
	m_StrobeFuncOffset(0),
	m_StrobeRootCaps(0),
	m_maxBytes(0),
	m_maxBufferSize(0),
	m_maxSpeed(0),
	m_width(0),
	m_height(0),
	m_colorCode(COLOR_CODE_INVALID),
	m_pFirstBuffer(NULL),
	m_pLastBuffer(NULL),
	m_pCurrentBuffer(NULL),
	m_AcquisitionTimeout(0),
	m_AcquisitionFlags(0),
	m_AcquisitionBuffers(0)
{
	int i,format,mode;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER C1394Camera Constructor\n");
	
	// this is the best place to trace the structure sizes
	DllTrace(DLL_TRACE_VERBOSE,"sizeof(C1394Camera) = %d\n",sizeof(C1394Camera));
	DllTrace(DLL_TRACE_VERBOSE,"sizeof(C1394CameraControl) = %d\n",sizeof(C1394CameraControl));
	DllTrace(DLL_TRACE_VERBOSE,"sizeof(C1394CameraControlSize) = %d\n",sizeof(C1394CameraControlSize));
	DllTrace(DLL_TRACE_VERBOSE,"sizeof(C1394CameraControlTrigger) = %d\n",sizeof(C1394CameraControlTrigger));
	
	ZeroMemory(&m_spec,sizeof(CAMERA_SPECIFICATION));
	
	// initialize video settings arrays to false
	m_InqVideoFormats = 0;
	for (format=0; format<8; format++)
	{
		m_InqVideoModes[format] = 0;
		for (mode=0; mode<8; mode++)
			m_InqVideoRates[format][mode] = 0;
	}
	
	// initialize the feature controls
	for(i=0; i<FEATURE_NUM_FEATURES; i++)
	{
		if(i != FEATURE_TRIGGER_MODE && dc1394GetFeatureName((CAMERA_FEATURE)(i)) != NULL)
			m_pControls[i] = new C1394CameraControl(this,(CAMERA_FEATURE)(i));
		else
			m_pControls[i] = NULL;
	}
	
	m_pControlTrigger = new C1394CameraControlTrigger(this);
	m_pControlSize = new C1394CameraControlSize(this);
	
	// initialize the strobe controls
	for(i=0; i<4; i++)
		this->m_controlStrobes[i] = new C1394CameraControlStrobe(this,i);

	m_nameModel[0] = 0;
	m_nameVendor[0] = 0;
	m_DevicePath[0] = 0;
	m_UniqueID.QuadPart = 0;

	DllTrace(DLL_TRACE_EXIT,"EXIT C1394Camera Constructor\n");
}


/**\brief Tear down a C1394Camera Instance
 * \ingroup camcore
 *
 * Besides typical freeing of resources, this also calls StopImageAcquisition()
 * if necessary to disable the camera streaming and free kernel-side resources 
 * as well.
 */
C1394Camera::~C1394Camera()
{
	int i;

	DllTrace(DLL_TRACE_ENTER,"ENTER C1394Camera Destructor\n");
	if(m_hDevInfo != INVALID_HANDLE_VALUE)
		SetupDiDestroyDeviceInfoList(m_hDevInfo);
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
		StopImageAcquisition();

	// nuke the strobe controls
	for(i=0; i<FEATURE_NUM_FEATURES; i++)
		if(this->m_pControls[i] != NULL)
			delete m_pControls[i];

	if(m_pControlTrigger)
		delete m_pControlTrigger;

	if(m_pControlSize)
		delete m_pControlSize;

	// nuke the strobe controls
	for(i=0; i<4; i++)
		if(this->m_controlStrobes[i] != NULL)
			delete m_controlStrobes[i];

	DllTrace(DLL_TRACE_EXIT,"EXIT C1394Camera Destructor\n");
}


/**\brief Check the 1394 subsystem for any connected cameras.
 * \ingroup camcore
 * \return
 *  - CAM_SUCCESS: Found at least one camera and have selected camera 0
 *  - CAM_ERROR: Found no cameras on the 1394 bus(es)
 *
 *   This function is now deprecated in favor of RefreshCameraList().  
 *   It is maintained for backwards compatibility and will be removed 
 *   in a future version.
 */
int C1394Camera::CheckLink()
{
	DllTrace(DLL_TRACE_ENTER,"ENTER CheckLink\n");
	if(RefreshCameraList() > 0)
	{
		SelectCamera(0);
		m_linkChecked = true;
		return 0;
	}
	return -1;
}

/**\brief Check the PnP Subsystem for attached devices.
 * \ingroup camcore
 * \return
 *  - The number of cameras available, (zero if none)
 *  - CAM_ERROR: Some problem with a system call, check GetLastError()
 *
 *   This function is meant to replace CheckLink(), as it is more semantically correct
 */
int C1394Camera::RefreshCameraList()
{
	int ret = CAM_ERROR;
	DllTrace(DLL_TRACE_ENTER,"ENTER RefreshCameraList\n");
	if(m_hDevInfo != INVALID_HANDLE_VALUE)
		SetupDiDestroyDeviceInfoList(m_hDevInfo);
	
	m_dwDevCount = 0;
	
	if((m_hDevInfo = t1394CmdrGetDeviceList()) == INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"RefreshCameraList: Error on CmdrGetDeviceList\n");
	} else {
		// count devices
		char buf[512];
		int i;
		ULONG sz = sizeof(buf);
		for(i=0; ;i++)
		{
			sz = sizeof(buf);
			if((ret = t1394CmdrGetDevicePath(m_hDevInfo,i,buf,&sz)) <= 0)
			{
				ret = (ret < 0 ? CAM_ERROR : i);
				break;
			}
			DllTrace(DLL_TRACE_CHECK,"RefreshCameraList: Enum %d: %s\n",i,buf);
		}
	}
	
	if(ret >= 0)
	{
		m_dwDevCount = ret;
	} else {
		DllTrace(DLL_TRACE_ERROR,"Error on getDevicePath:%d\n",GetLastError());
		if(m_hDevInfo != INVALID_HANDLE_VALUE)
		{
			SetupDiDestroyDeviceInfoList(m_hDevInfo);
			m_hDevInfo = INVALID_HANDLE_VALUE;
		}
	}
	
	DllTrace(DLL_TRACE_EXIT,"EXIT RefreshCameraList (%d)\n",ret);
	return ret;
}

/**\brief Indexes into the current device list to point the class at a particular camera
 * \ingroup camcore
 * \param node: the (zero-indexed) id of the camera to select
 * \return
 *   - CAM_SUCCESS on success
 *   - CAM_ERROR_PARAM_OUT_OF_RANGE: you gave a bad camera number
 *   - CAM_ERROR_BUSY: The currently Selected Camera is Busy, call StopImageAcquisition() first
 *   - CAM_ERROR: general I/O error (probably GetCameraSpecification)
 *
 *   This is the only class function that will generate dialog boxes and will do so
 *   if and only if it believes that the device you selected isn't *really* a camera
 *   that complies with the 1394 Digital Camera Specification.
 */
int C1394Camera::SelectCamera(int node)
{
	char buf[256];
	ULONG sz = sizeof(buf);
	int format, mode;
	int ret = CAM_ERROR;
	ULONG ulRet;

	DllTrace(DLL_TRACE_ENTER,"ENTER SelectCamera (%d)\n",node);

	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"SelectCamera: Currently Selected Camera is Busy, you must call StopImageAcquisition First\n");
		ret = CAM_ERROR_BUSY;
		goto _exit;
	}

	if(node < 0 || (unsigned int)node >= m_dwDevCount)
	{
		DllTrace(DLL_TRACE_ERROR,"SelectCamera: Camera %d out of range\n",node);
		ret = CAM_ERROR_PARAM_OUT_OF_RANGE;
		goto _exit;
	}

	if(t1394CmdrGetDevicePath(m_hDevInfo,node,buf,&sz) <= 0)
	{
		DllTrace(DLL_TRACE_ERROR,"SelectCamera: Error on GetDevicePath (%d)\n",GetLastError());
		ret = CAM_ERROR;
		goto _exit;
	}

	// check the software version
	ZeroMemory(&m_spec,sizeof(CAMERA_SPECIFICATION));
	if((ulRet = GetCameraSpecification(buf,&m_spec)))
	{
		DllTrace(DLL_TRACE_ERROR,"SelectCamera: Error %08x getting Camera Specification\n",ulRet);
		ret = CAM_ERROR;
		goto _exit;
	}

	if(m_spec.ulSpecification != 0x00A02D)
		DllTrace(DLL_TRACE_ALWAYS, "SelectCamera: Warning: Camera specification (%06x) does not match 0x00A02D\n", m_spec.ulSpecification);

	if (m_spec.ulVersion  < 0x000100 || m_spec.ulVersion > 0x000104)
		DllTrace(DLL_TRACE_ALWAYS,"SelectCamera: Warning: Camera software version (%06x) is not supported\n",m_spec.ulVersion);

	// get the vendor and model names from the driver
	if((ulRet = GetModelName(buf,m_nameModel,255)) < 0)
	{
		DllTrace(DLL_TRACE_ERROR,"SelectCamera: Error on GetModelName\n");
		DllTrace(DLL_TRACE_EXIT,"EXIT SelectCamera (%d)\n",CAM_ERROR);
		return CAM_ERROR;
	} else {
		// Null-Terminate
		m_nameModel[ulRet] = 0;
	}

	if((ulRet = GetVendorName(buf,m_nameVendor,255)) < 0)
	{
		DllTrace(DLL_TRACE_ERROR,"SelectCamera: Error on GetVendorName\n");
		DllTrace(DLL_TRACE_EXIT,"EXIT SelectCamera (%d)\n",CAM_ERROR);
		return CAM_ERROR;
	} else {
		// Null-Terminate
		m_nameVendor[ulRet] = 0;
	}

	GetUniqueID(buf,&m_UniqueID);
	
	// whenever we switch cameras, reset our internal stuff
	m_cameraInitialized = false;
	
	// initialize video settings matrices to false
	m_InqVideoFormats = 0;
	for (format=0; format<8; format++)
	{
		m_InqVideoModes[format] = 0;
		for (mode=0; mode<8; mode++)
			m_InqVideoRates[format][mode] = 0;
	}
	
	// empty out the static registers
	m_InqBasicFunc = 0;
	m_InqVideoFormats = 0;
	m_InqFeatureHi = m_InqFeatureLo = 0;
	
	strncpy(m_DevicePath,buf,sizeof(m_DevicePath));
	m_pName = m_DevicePath;
	m_node = node;
	ret = CAM_SUCCESS;
	DllTrace(DLL_TRACE_CHECK,"SelectCamera: Selected \"%s\"\n",m_pName);
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT SelectCamera (%d)\n",ret);
	return ret;
}

/**\brief accessor for the Camera Model Name 
 * \param buf Where to put the camera model
 * \param len How long <i>buf</i> is.
 */
void C1394Camera::GetCameraName(char *buf, int len)
{
	strncpy(buf,m_nameModel,len);
}

/**\brief accessor for the Camera Vendor
 * \param buf Where to put the camera vendor
 * \param len How long <i>buf</i> is.
 */
void C1394Camera::GetCameraVendor(char *buf, int len)
{
	strncpy(buf,m_nameVendor,len);
}

/**\brief accessor for the Camera Unique ID
 * \param pUniqueID Where to put the camera ID
 */
void C1394Camera::GetCameraUniqueID(PLARGE_INTEGER pUniqueID)
{
	if(pUniqueID)
		pUniqueID->QuadPart = this->m_UniqueID.QuadPart;
}

/**\brief Performs General initialization of the C1394Camera class for the currently selected camera
 * \ingroup camcore
 * \param reset If TRUE, this will poke the camera init register to restore it to powerup defaults
 * \return
 *  CAM_SUCCESS: The camera is ready to start capturing Frames.
 *  CAM_ERROR_NOT_INITIALIZED: No camera selected (this is poorly named and may be changed)
 *  CAM_ERROR_BUSY: Usualy indicates broken invariants, but in and of itself prevents an
 *    init in the middle of image acquisition
 *  CAM_ERROR: Some register IO failed, GetLastError will tell why
 *
 * This Function currently causes a lot of I/O on the 1394 bus to populate the configuration and capability
 * information about the camera and all the available controllable features.  If there are any standard video
 * formats available (e.g. not format 7), then the first available format, mode and rate are selected by default.
 */
int C1394Camera::InitCamera(BOOL reset)
{
	DWORD dwRet;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER InitCamera\n");
	
	if(m_cameraInitialized)
		// this isn't really an error, but should be reported
		DllTrace(DLL_TRACE_WARNING,"InitCamera: Warning: Duplicate Call to InitCamera\n");
	
	// clear it for another pass
	m_cameraInitialized = false;
	
	if(!m_pName)
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: Error: no camera selected\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: Error: Camera is busy, stop image acquisition first\n");
		ret = CAM_ERROR_BUSY;
		goto _exit;
	}
	
	// this frees up any isoch resources that may be left behind
	// from a previous program that didn't clean up after itself
	// properly (i.e. crashed)
	
	// This is an ugly way to deal with it, but will have to work for now
	t1394IsochTearDownStream(m_pName);
	
	// determine max speed
	// this is used for allocating bandwidth and stuff
  /*
	GET_MAX_SPEED_BETWEEN_DEVICES maxSpeed;
	ULONG maxSpeedNotLocal, maxSpeedLocal;
	maxSpeed.fulFlags = 0;
	maxSpeed.ulNumberOfDestinations = 0;
	if (dwRet = GetMaxSpeedBetweenDevices(m_pName, &maxSpeed))
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: Error %08x on GetMaxSpeedBetweenDevices (NotLocal)\n",dwRet);
		goto _exit;
	}
	maxSpeedNotLocal = maxSpeed.fulSpeed;
	
	maxSpeed.fulFlags = 1;
	if (dwRet = GetMaxSpeedBetweenDevices(m_pName, &maxSpeed))
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: Error %08x on GetMaxSpeedBetweenDevices (Local)\n",dwRet);
		goto _exit;
	}
	maxSpeedLocal = maxSpeed.fulSpeed;
	// select the smaller of the two
	*/

  if( (dwRet = GetMaxIsochSpeed(m_pName,&m_maxSpeed)) != ERROR_SUCCESS )
  {
    DllTrace(DLL_TRACE_ERROR,"InitCamera: Error %08x on GetMaxIsochSpeed (%s)\n",dwRet,StrLastError());
    goto _exit;
  }

	
	// reset to defaults if we want
	if(reset == TRUE)
	{
		if(WriteQuadlet(0x000,0x80000000) != CAM_SUCCESS)
			DllTrace(DLL_TRACE_WARNING,"InitCamera: Warning: Reset to defaults failed: %08x\n",GetLastError());
	}
	
	// determine video formats/modes/rates
	// private functions return bools and do their own respective tracing
	if(!InquireVideoFormats())
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: Error on InquireVideoFormats\n");
		goto _exit;
	}
	
	if(!InquireVideoModes())
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: Error on InquireVideoModes\n");
		goto _exit;
	}
	
	if(!InquireVideoRates())
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: Error on InquireVideoRates\n");
		goto _exit;
	}
	
	if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x400,&m_InqBasicFunc)))
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x400)\n",dwRet);
		goto _exit;
	}
	
	if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x404,&m_InqFeatureHi)))
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x404)\n",dwRet);
		goto _exit;
	}
	
	if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x408,&m_InqFeatureLo)))
	{
		DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x408)\n",dwRet);
		goto _exit;
	}
	
	// Poke the error bits, if available
	this->StatusVideoErrors(TRUE);
	this->StatusFeatureError(FEATURE_BRIGHTNESS,TRUE);
	
	// the core registers have been updated, so it's safe to set this here
	// NOTE: this flag is very hackish, and should be replaced by explicitly nuking
	// the toplevel registers on Construction and SelectCamera()
	m_cameraInitialized = true;
	
	if(this->HasPowerControl())
	{
		if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x610,&this->m_StatusPowerControl)))
		{
			DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x reading Power Register\n");
			goto _exit;
		}
	}
	
  // some cameras have these features, so we have to turn these around a bit
  // Normally, we would check "HasFooBar" before looking up the address of FooBar
  // but if we turn it around and verify that we get a valid address, we can do a 
  // quirk-check
	if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x480,&this->m_AdvFuncOffset)))
	{
   	if(this->HasAdvancedFeature())
    {
  		DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x480)\n",dwRet);
		  goto _exit;
    } // else all is well and consistent in the universe
  } else {
    // we got a feature reading, make sure it makes sense
    if(m_AdvFuncOffset != 0)
    {
  		m_AdvFuncOffset <<= 2;
	  	m_AdvFuncOffset |= 0xf0000000;

      // and do the quirk-check
      if(!this->HasAdvancedFeature())
      {
        DllTrace(DLL_TRACE_ERROR,"InitCamera: QUIRK: InqBasicFunc Claims no Vendor Features (%08x), but 0x480 says %08x\n",
					m_InqBasicFunc,m_InqOptionalFunc);
        m_InqBasicFunc |= 0x80000000;
      }
    }
  }
	
	// again, try the optional features backwards
	// Read the Optional Function Bitmask
	if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x40C,&m_InqOptionalFunc)))
	{
		if(this->HasOptionalFeatures())
		{
			DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x40C)\n",dwRet);
			goto _exit;
		} // else all is well
	} else {
		// got one, verify and blahblah
		if(!this->HasOptionalFeatures())
		{
	        DllTrace(DLL_TRACE_ERROR,"InitCamera: QUIRK: InqBasicFunc Claims no Optional Features (%08x), but 0x40C says %08x\n",
					m_InqBasicFunc,m_InqOptionalFunc);
			m_InqBasicFunc |= 0x10000000;
		}
	}

	if(this->HasOptionalFeatures())
	{
		// And Check the Individual Features
		if(this->HasPIO())
		{
			if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x484,&this->m_PIOFuncOffset)))
			{
				DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x484)\n",dwRet);
				goto _exit;
			}
			m_PIOFuncOffset <<= 2;
			m_PIOFuncOffset |= 0xf0000000;
		}
		
		if(this->HasSIO())
		{
			if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x488,&this->m_SIOFuncOffset)))
			{
				DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x488)\n",dwRet);
				goto _exit;
			}
			m_SIOFuncOffset <<= 2;
			m_SIOFuncOffset |= 0xf0000000;
		}
		
		if(this->HasStrobe())
		{
			if(CAM_SUCCESS != (dwRet = ReadQuadlet(0x48C,&this->m_StrobeFuncOffset)))
			{
				DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x48C)\n",dwRet);
				goto _exit;
			}
			m_StrobeFuncOffset <<= 2;
			m_StrobeFuncOffset |= 0xf0000000;
			if(CAM_SUCCESS != (dwRet = ReadQuadlet(this->m_StrobeFuncOffset,&this->m_StrobeRootCaps)))
			{
				DllTrace(DLL_TRACE_ERROR,"InitCamera: error %08x on ReadQuadlet(0x%08x)\n",
					dwRet,this->m_StrobeFuncOffset);
				goto _exit;
			}
		}
	}
	
	RefreshControlRegisters(FALSE);
	UpdateParameters();
	ret = CAM_SUCCESS;
	
_exit:
	if(ret != CAM_SUCCESS)
		m_cameraInitialized = false;
	
	DllTrace(DLL_TRACE_EXIT,"EXIT InitCamera (%d)\n",ret);
	return ret;
}

/**\brief Accessor for m_cameraInitialized
 * \ingroup camcore
 * \return Whether the camera has been successfully initialized
 *
 * This used to be cached in 1394CameraDemo and used to activate/deactivate menu
 * options.  This defeated the DRY principle, so here we have an accessor.
 */
bool CAMAPI C1394Camera::IsInitialized()
{
	return m_cameraInitialized;
}

/**\brief Accessor for m_hDeviceAcquisition
 * \ingroup camcore
 * \return Whether the camera has an active isoch stream
 *
 * Like IsInitialized, this used to be cached in 1394CameraDemo, defeating the DRY principle.
 * It should be used to verify that certain stream-relevant camera status, such as video mode,
 * framerate, etc, can be modified at present.
 */
bool CAMAPI C1394Camera::IsAcquiring()
{
	return m_hDeviceAcquisition != INVALID_HANDLE_VALUE;
}

/**\brief Read four bytes (A Quadlet) directly out of the Camera's configuration space.
 * \ingroup camcore
 * \param address The offset into the camera register space to read from.
 * \param pData The place to put the data read in from the register.  The data will be in
 *      machine order, so the most significant bit would be 0x80000000
 * \see WriteQuadlet()
 * \return
 *  - CAM_SUCCESS: Your data is ready.
 *  - CAM_ERROR: something bad happened down in the bowels of the OS, use GetLastError() to find out.
 *  - CAM_ERROR_NOT_INITIALIZED: no camera has been selected
 *
 *  ReadQuadlet catches ERROR_SEM_TIMEOUT, which means the camera was too busy to process the request.
 *  It will retry the request for the initial value of nretries times, by default this is 4, but
 *  it may become a registry variable.
 *
 *  Addresses leading with "f" as in 0xf0000344 will be treated as absolute addresses.
 *  Those without a leading "f" will be treated as offsets into the 
 *  CSR space, so 0x00000344 will be read at CSR + 0x344, usually 0xf0f00344
 *
 *  <b>USE WITH CAUTION</b>
 */
int C1394Camera::ReadQuadlet(unsigned long address, unsigned long *pData)
{
	unsigned long data = 0;
	int nretries = 4;
	int ret = CAM_ERROR;
	DWORD dwRet;

	DllTrace(DLL_TRACE_ENTER,"ENTER ReadQuadlet (%08x,%08x)\n",address,pData);

	if(!m_pName)
	{
		DllTrace(DLL_TRACE_ERROR,"ReadQuadlet: No Camera has been selected\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}

	if(!pData)
	{
		DllTrace(DLL_TRACE_ERROR,"ReadQuadlet: You gave me a NULL pointer you fool!\n");
		SetLastError(ERROR_INVALID_PARAMETER);
		goto _exit;
	}

	// we're gonna try this nretries times, looking for
	// ERROR_SEM_TIMEOUT, which maps to STATUS_IO_TIMEOUT
	// meaning that the camera can't keep up.
	while((dwRet = ReadRegisterUL(m_pName,address,pData)) != 0 && nretries > 0)
	{
		if(dwRet == ERROR_SEM_TIMEOUT ||
		   dwRet == ERROR_BUSY)
		{
			// Sleep for 10 ms
			Sleep(10);
			nretries--;
			DllTrace(DLL_TRACE_WARNING,"ReadQuadlet: Warning: Timeout on ReadRegisterUL@0x%08x.  Retries Remaining: %d\n",
				address,nretries);
		} else {
			// some other error, break out of the loop
			break;
		}

	}

	if(dwRet != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"ReadQuadlet: Unrecoverable error %08x on ReadRegisterUL\n",dwRet);
		goto _exit;
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT ReadQuadlet (%d)\n",ret);
	return ret;
}


/**\brief Write four bytes (A Quadlet) directly into the Camera's configuration space.
 * \ingroup camcore
 * \param address The offset into the camera register space to write to.
 * \param data The data to write.  The data should be in machine order; the most significant bit would be 0x80000000
 * \see ReadQuadlet()
 * \return
 *  - CAM_SUCCESS: Your data has been written
 *  - CAM_ERROR: something bad happened down in the bowels of the OS, use GetLastError() to find out.
 *  - CAM_ERROR_NOT_INITIALIZED: no camera has been selected
 *
 *  WriteQuadlet catches ERROR_SEM_TIMEOUT, which means the camera was too busy to process the request.
 *  It will retry the request for the initial value of nretries times, by default this is 4, but
 *  it may become a registry variable.
 *
 *  Addresses leading with "f" as in 0xf0000344 will be treated as absolute addresses.
 *  Those without a leading "f" will be treated as offsets into the 
 *  CSR space, so 0x00000344 will be read at CSR + 0x344, usually 0xf0f00344
 */

int C1394Camera::WriteQuadlet(unsigned long address, unsigned long data)
{
	int ret = CAM_ERROR;
	int nretries = 4;
	DWORD dwRet;

	DllTrace(DLL_TRACE_ENTER,"ENTER WriteQuadlet (%08x,%08x)\n",address,data);

	if(!m_pName)
	{
		DllTrace(DLL_TRACE_ERROR,"WriteQuadlet: No Camera has been selected\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}

	// we're gonna try this nretries times, looking for
	// ERROR_SEM_TIMEOUT, which maps to STATUS_IO_TIMEOUT
	// meaning that the camera can't keep up.
	while((dwRet = WriteRegisterUL(m_pName,address,data)) != 0 && nretries > 0)
	{
		if(dwRet == ERROR_SEM_TIMEOUT ||
		   dwRet == ERROR_BUSY)
		{
			// Sleep for 10 ms
			Sleep(10);
			nretries--;
			DllTrace(DLL_TRACE_WARNING,"ReadQuadlet: Warning: Timeout on WriteRegisterUL@0x%08x.  Retries Remaining: %d\n",
				address,nretries);
		} else {
			// some other error, break out of the loop
			break;
		}
	}

	if(dwRet != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"WriteQuadlet: Unrecoverable error %08x on WriteRegisterUL\n",dwRet);
		goto _exit;
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT WriteQuadlet (%d)\n",ret);
	return ret;
}



/**\brief Get the maximum bus speed on the path to the selected camera
 * \ingroup camcore
 * \return Maximum speed in mbps, or zero if the camera has not been initialized.
 */
int C1394Camera::GetMaxSpeed()
{
  DWORD dwRet;
  if( (dwRet = GetMaxIsochSpeed(m_pName,&m_maxSpeed)) != ERROR_SUCCESS )
  {
    DllTrace(DLL_TRACE_ERROR,"GetMaxSpeed: Error %08x on GetMaxIsochSpeed (%s)\n",dwRet,StrLastError());
    m_maxSpeed = 0;
  }

	return m_maxSpeed * 100;
}

void C1394Camera::GetMaxBufferSize(PULARGE_INTEGER puliBufferSize)
{
  t1394_GetHostDmaCapabilities(m_pName,NULL,puliBufferSize);
}

/**\brief Get specification revision for this particular camera
 * \ingroup camcore
 * \return The camera specification:
 *  - 0x100: Version 1.04
 *  - 0x101: Version 1.20
 *  - 0x102: Version 1.30
 *  - 0x103: Version 1.31
 */
unsigned long C1394Camera::GetVersion()
{
	return m_spec.ulVersion;
}


/**\brief Get the number of cameras available on the bus.
 * \ingroup camcore
 * \return The number of available cameras, or -1 on error.
 */
int C1394Camera::GetNumberCameras()
{
	return m_dwDevCount;
}


/**\brief Get the node index for the selected camera.
 * \ingroup camcore
 * \return Node index, -1 if none selected
 *
 * This function is largely useless, and may be removed in future versions
 */
int C1394Camera::GetNode()
{
	return m_node;
}

/**\brief Get the a textual description of the camera indexed by <i>node</i>.
 * \param node The node to describe
 * \param buf  The output buffer
 * \param buflen The output buffer length;
 * \ingroup camcore
 * \return Length of the string, 0 for an invalid node
 *
 * 
 */
int C1394Camera::GetNodeDescription(int node, char *buf, int buflen)
{
	char *pout, *pin, *pend;
	unsigned int sharps = 0;
	
	if(this->m_hDevInfo)
	{
		if(t1394CmdrGetDevicePath(m_hDevInfo,node,buf,(unsigned long *)&buflen) <= 0)
		{
			DllTrace(DLL_TRACE_ERROR,"SelectCamera: Error on GetDevicePath (%d)\n",GetLastError());
			return 0;
		}
		pin = pout = buf;
		pend = pin + strlen(buf);
		// the format is junk#vendor&model#ID#junk
		// first sharp
		while(pin < pend && sharps < 3)
		{
			if(*pin == '#')
			{
				sharps++;
				if(sharps == 2)
				{
					*pout++ = ' ';
					*pout++ = '(';
				}
				if(sharps == 3)
				{
					*pout++ = ')';
					*pout = 0;
				}
			} else if(sharps > 0) {
				if(*pin == '&')
					*pin = ' ';
				*pout++ = *pin;
			}
			pin++;
		}
		return (int)(pout - buf);
	}
	return 0;
}

/**\brief Accessor for internal device name for use with functionality in the C API
 */
const char * C1394Camera::GetDevicePath()
{
    return m_pName;
}

/**\brief Enable continuous streaming of camera data.
 * \ingroup camcore
 * \return CAM_SUCCESS if successful, CAM_ERROR otherwise
 *
 * This is essentially a one-liner that is referenced from one place and may soon be removed
 */
int C1394Camera::StartVideoStream()
{
	ULONG ulRet;
	int retval = CAM_SUCCESS;

	DllTrace(DLL_TRACE_ENTER,"ENTER StartVideoStream\n");
	if((ulRet = WriteQuadlet(0x614,0x80000000)) != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"StartVideoStream: error %08x on WriteQuadlet(0x614)\n",ulRet);
		retval = CAM_ERROR;
	}
	DllTrace(DLL_TRACE_EXIT,"EXIT StartVideoStream (%d)\n",retval);
	return retval;
}

/**\brief Disable continuous streaming of camera data.
 * \ingroup camcore
 * \return CAM_SUCCESS if successful, CAM_ERROR otherwise
 *
 * This is essentially a one-liner that is referenced from one place and may soon be removed
 */
int C1394Camera::StopVideoStream()
{
	ULONG ulRet;
	int retval = CAM_SUCCESS;

	DllTrace(DLL_TRACE_ENTER,"ENTER StopVideoStream\n");
	if((ulRet = WriteQuadlet(0x614,0x00000000)) != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"StopVideoStream: error %08x on WriteQuadlet(0x614)\n",ulRet);
		retval = CAM_ERROR;
	}
	DllTrace(DLL_TRACE_EXIT,"EXIT StopVideoStream (%d)\n",retval);
	return retval;
}

/**\brief Check for the presence of the OneShot feature
 * \ingroup camcore
 * \return boolean whether the camera supports oneshot or not
 */
bool C1394Camera::HasOneShot()
{
  return (m_InqBasicFunc & (0x80000000 >> 19)) != 0;
}

/**\brief Trigger the transfer of exactly one frame from the camera
 * \ingroup camcore
 * \return CAM_SUCCESS if successful, CAM_ERROR otherwise
 *
 *   This function is a wrapper for an otherwise simple procedure.  Maybe it should
 *   be inlined and just return whatever the WriteRegister returns
 *
 *   This function is currently not used by anything at all because it does not integrate
 *   cleanly with the acquisition code.
 */
int C1394Camera::OneShot()
{
	ULONG ulRet;
	int retval = CAM_SUCCESS;

	DllTrace(DLL_TRACE_ENTER,"ENTER OneShot\n");
	if((ulRet = WriteQuadlet(0x61c,0x80000000)) != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"OneShot: error %08x on WriteQuadlet(0x61c)\n",ulRet);
		retval = CAM_ERROR;
	}
	DllTrace(DLL_TRACE_EXIT,"EXIT OneShot (%d)\n",retval);
	return retval;
}

/**\brief Check for the presence of the MultiShot feature
 * \ingroup camcore
 * \return boolean whether the camera supports oneshot or not
 */
bool C1394Camera::HasMultiShot()
{
	return (m_InqBasicFunc & (0x80000000 >> 20)) != 0;
}

/**\brief Trigger the transfer of exactly <i>N</i> frames from the camera
 * \param count The number of frames to transfer (0 to stop a running multishot)
 * \ingroup camcore
 * \return CAM_SUCCESS if successful, CAM_ERROR otherwise
 *
 *   This function is a wrapper for an otherwise simple procedure.  Maybe it should
 *   be inlined and just return whatever the WriteRegister returns
 *
 *   This function is currently not used by anything at all because it does not integrate
 *   cleanly with the acquisition code.
 *
 *   Also, MultiShot() should be implemented
 */
int C1394Camera::MultiShot(unsigned short count)
{
	ULONG ulRet,ulData;
	int retval = CAM_SUCCESS;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER MultiShot\n");
	ulData = (ULONG) count; // count in the low 16 bits
	if(count != 0)(ulData |= 0x40000000); // bit 1 (second-to-highest) enables multishot
	DllTrace(DLL_TRACE_CHECK,"MultiShot: Writing 0x%08x to %03x\n",ulData,0x61c);
	if((ulRet = WriteQuadlet(0x61c,ulData)) != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"MultiShot: error %08x on WriteQuadlet(0x61c)\n",ulRet);
		retval = CAM_ERROR;
	}
	DllTrace(DLL_TRACE_EXIT,"EXIT MultiShot (%d)\n",retval);
	return retval;
}

/**\brief Determine whether the camera supports power control
 * \return boolean whether the feature is supported
 */
bool C1394Camera::HasPowerControl()
{
	if(m_cameraInitialized && (m_InqBasicFunc & (1<<15)))
		return true;
	return false;
}

/**\brief Determine whether the camera's power control is active
 * \return boolean whether the feature is active
 */
bool C1394Camera::StatusPowerControl()
{
	if(m_cameraInitialized && (m_StatusPowerControl & 0x80000000))
		return true;
	return false;
}

/**\brief Change the Camera's Power Control Setting
 * \return Same as WriteQuadlet()
 */
int  C1394Camera::SetPowerControl(BOOL on)
{
	int ret;
	if((ret = WriteQuadlet(0x610,0x80000000)) != CAM_SUCCESS)
		return ret;
	ReadQuadlet(0x610,&m_StatusPowerControl);
	return CAM_SUCCESS;
}

/**\brief boolean accessor for 1394b support */
bool C1394Camera::Has1394b()
{
	return (m_cameraInitialized && (m_InqBasicFunc & 0x00800000) != 0);
}

/**\brief boolean accessor for 1394b status */
bool C1394Camera::Status1394b()
{
	if(Has1394b())
	{
		unsigned long ulData;
		ReadQuadlet(0x60c, &ulData);
		return (ulData & 0x00008000) != 0;
	}
	return false;
}

/**\brief (de-)activate 1394b support in a compliant camera
 * \param on Whether to turn 1394b support on (TRUE) or off (FALSE)
 * \return
 *  - CAM_ERROR_BUSY if in the middle of image acquisition
 *  - CAM_ERROR_UNSUPPORTED if the camera does not support 1394b
 *  - Other errors: Bad things happened in Register I/O
 *
 * After successfully changing 1394b support, we must re-read all the
 * format, mode, rate, etc registers
 */
int C1394Camera::Set1394b(BOOL on)
{
	int ret;
	if(this->m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
		return CAM_ERROR_BUSY;
	
	if(Has1394b())
	{
		unsigned long ulData;
		if((ret = ReadQuadlet(0x60c, &ulData)) != CAM_SUCCESS)
			return ret;
		if(on)
			ulData |= 0x00008000;
		else
			ulData &= ~0x00008000;
		if((ret = WriteQuadlet(0x60c, ulData)) != CAM_SUCCESS)
			return ret;
		// by changing this setting, other random stuff may change as well
		return InitCamera();
	}
	return CAM_ERROR_UNSUPPORTED;
}

/****************************************************/
/*                                                  */
/*           PRIVATE MEMBER FUNCTIONS               */
/*                                                  */
/****************************************************/


/**\brief Initialize and allocate the Isochronous resources necessary to start an isochronous
 * streaming operation.
 * \ingroup camcore
 * \return TRUE if initialization was successful, false if not (check GetLastError())
 *
 * The information necessary to allocate stream resources is gleaned from the selected video modes
 * this whole function may be converted to a single IOCTL code and moved into kernel land.  There is
 * no reason for userland to have any of this information.
 */
BOOL C1394Camera::InitResources()
{
	ISOCH_STREAM_PARAMS StreamParams;
	ULONG ulData = 0;
	BOOL bRet = FALSE;
	ULARGE_INTEGER uliDMABufferSize;
  PACQUISITION_BUFFER pBuf;
  DllTrace(DLL_TRACE_ENTER,"ENTER InitResources\n");
	
	// Tripping either of these would indicate some sort of broken invariant
	// As they are also checked by StartImage*, which are the only functions
	// that call this.
	
	// however, we will check them anyway
	
	if (!m_pName)
	{
		DllTrace(DLL_TRACE_ERROR,"InitResources: Error: No camera selected\n");
		goto _exit;
	}
	
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"InitResources: Error: Camera is busy, stop image acquisition first\n");
		goto _exit;
	}
	
	// for the hell of it, make sure the camera is free to be allocated
	FreeResources();

    // populate initial speed and channel 
	if(this->m_AcquisitionFlags & ACQ_SUBSCRIBE_ONLY)
	{
        // read present status from the camera and use that
    	if(ReadQuadlet(0x60c, &ulData) != ERROR_SUCCESS)
        {
            DllTrace(DLL_TRACE_ERROR,"InitResources: Failed to read current isoch settings for SUBSCRIBE_ONLY!\n");
            goto _exit;
        }

		if(ulData & 0x00008000)
		{
			// 1394b mode
			StreamParams.fulSpeed = 1 << (ulData & 0x0F);
			StreamParams.nChannel = ((ulData>>8) & 0x0F);
		} else {
			// 1394a mode
			StreamParams.fulSpeed = 1 << ((ulData>>24) & 0x0F);
			StreamParams.nChannel = ((ulData>>28) & 0x0F);
		}

        DllTrace(DLL_TRACE_CHECK,"InitResources: Attempting to subscribe to existing stream at %d/%umbps\n",
                 StreamParams.nChannel,StreamParams.fulSpeed * 100);
    } else {
        // set max speed and request channel allocation
		StreamParams.fulSpeed = m_maxSpeed;
		StreamParams.nChannel = -1;
	}
	
    // populate max buffer size and number of buffers

    // hackhack: build a buffer to figure out how many to allocate
    // todo: either absorb frame buffer allocation into initresources(), or move stream parameter stuff
    // into StartImageAcquisitionEx

    t1394_GetHostDmaCapabilities(m_pName,NULL,&uliDMABufferSize);
    pBuf = dc1394BuildAcquisitonBuffer(m_maxBufferSize,
                                                           (unsigned long)uliDMABufferSize.QuadPart,
                                                           m_maxBytes,
                                                           0);

    if(pBuf != NULL)
    {
        StreamParams.nMaxBufferSize = pBuf->subBuffers[0].ulSize;
    	StreamParams.nNumberOfBuffers = (this->m_AcquisitionBuffers * pBuf->nSubBuffers) + 1;
        DllTrace(DLL_TRACE_CHECK,"InitResources: %u frames @ %u bytes -> %u DMA Buffers @ %u bytes (max)",
            m_AcquisitionBuffers, m_maxBufferSize, StreamParams.nNumberOfBuffers, StreamParams.nMaxBufferSize);

        // free the buffer: this wouldn't be necessary if this were merged into StartImageAcquisitionEx
        dc1394FreeAcquisitionBuffer(pBuf);
        pBuf = NULL;

    } else {
        DllTrace(DLL_TRACE_ERROR,"InitResources: failed to determine required buffer size and count!");
        goto _exit;
    }

    // populate maxBytesPerFrame
    StreamParams.nMaxBytesPerFrame = m_maxBytes;

    // nMaxBytesPerFrame is a ULONG, but we will only ever use the lower ~16 (max per isoch channel at S3200 = 32K)
    // so: the high bits are used to "sneak" extra parameters in while retaining backwards compatibility
    if(this->m_AcquisitionFlags & ACQ_ALLOW_PGR_DUAL_PACKET)
    {
        StreamParams.nMaxBytesPerFrame |= BYTES_PER_FRAME_ALLOW_PGR_DUAL_PACKET;
    }

    // now fully populated, try to set up the stream
	if(t1394IsochSetupStream(m_pName,&StreamParams) != ERROR_SUCCESS)
    {
        DllTrace(DLL_TRACE_ERROR,"InitResources: Error on IsochSetupStream: %s\n",StrLastError());
		goto _exit;
	}

    // if we're not subscribing, we have to jam 
	if(!(this->m_AcquisitionFlags & ACQ_SUBSCRIBE_ONLY))
	{
		DllTrace(DLL_TRACE_CHECK,"InitResources: Setting channel %d speed %d mbps\n",
                 StreamParams.nChannel,StreamParams.fulSpeed * 100);

        // read present status from the camera to determine 1394b-ness
    	if(ReadQuadlet(0x60c, &ulData) != ERROR_SUCCESS)
        {
            DllTrace(DLL_TRACE_ERROR,"InitResources: Failed to read current isoch settings!");
            goto _exit;
        }

		if(ulData & 0x00008000)
		{
			//1394b mode, we pack the low 15 bits of 0x60C with channel,speed
			ulData &= 0xffff8000;
			ulData |= (StreamParams.nChannel & 0x3f) << 8;
			ulData |= SpeedFlagToIndex(StreamParams.fulSpeed);
		} else {
			//1394a mode, we pack the high 8 bits of 0x60C with channel,speed
			ulData &= 0x0000ffff;
			ulData |= (StreamParams.nChannel << 28);
			ulData |= (SpeedFlagToIndex(StreamParams.fulSpeed) << 24);
		}

		if(WriteQuadlet(0x60c, ulData) != ERROR_SUCCESS)
		{
			DllTrace(DLL_TRACE_ERROR,"InitResources: Failed to write Isoch settings to camera!\n");
			goto _exit;
		}
	}
	bRet = TRUE;

// common exit point
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT InitResources (%s)\n",bRet ? "TRUE" : "FALSE");
	return bRet;
}

/**\brief Break down and free the resources necessary for streaming.
 * \ingroup camcore
 * \return TRUE if cleanup was successful, FALSE otherwise (check GetLastError()).
 */
BOOL C1394Camera::FreeResources()
{
	ULONG ulRet;
	BOOL bRet = TRUE;
	if (ulRet = t1394IsochTearDownStream(m_pName))
	{
		DllTrace(DLL_TRACE_ERROR,"FreeResources: Error %08x on TearDown\n",ulRet);
		return FALSE;
	}
	return TRUE;
}

/**\brief Encapsulate the treatment of frame buffers larger than the maximum DMA buffer size
 * \param frameBufferSize The size of the requested frame buffer
 * \param bytesPerIsochPacket The number of bytes per isoch packet (e.g., from the FMR tables)
 * \param maxDMABufferSize    The maximum DMA buffer size (as reported by t1394_GetHostDmaCapabilities)
 * \param leadingBufferSize   The principal buffer size (all but the last buffer)
 * \param trailingBufferSize  The size of the last buffer (i.e., the leftovers when things don't divide evenly)
 * \return The total number of sub-buffers to allocate and attach
 *
 * On 32-bit systems, there is no practical limit on the size of DMA buffer that
 * is attached to an Isochronous stream.  On 64-bit systems, however, at least
 * for 1394a hosts and devices, there is a fairly small (typically 1MB) limit
 * on the maximum size of an individual DMA buffer.  This requires a single framebuffer
 * to be subdivided and attached as multiple separate "buffers"
 *
 * This function computes an "optimal" number of sub-buffers to pass to the kernel-side
 * driver, where optimal is the "best" ideally a combination of:
 * - Individual buffers are page-aligned (this is required on some platforms, so is a hard requirement here)
 * - Individual buffers are packet-aligned, so the DMA buffer transaction does not require controllers
 *   to buffer a partial isoch frame (this could conceivably tickle problems in quirky controllers)
 *
 * This means that we should really check for least-common-multiple of bpp and page_size, then
 * divide down from there to get under the maxDMABuffer limit
 *
 * For now, though, we just say "the whole of maxDMABufferSize" and roll on...
 * \todo: investigate whether forcing the 1394 host controller to bridge a packet across a DMA
 * \todo: see if we need to halve (or quarter) this to allow multiple cameras to run on one host controller
 *        The current behavior is that Win7-64 BSOD's in the "new" firewire stack if we get two big frames going at once
 */
unsigned long C1394Camera::ComputeBufferParameters(const unsigned long frameBufferSize,
                                                   const unsigned long bytesPerIsochPacket,
                                                   const unsigned long maxDMABufferSize,
                                                   unsigned long &leadingBufferSize,
                                                   unsigned long &trailingBufferSize)
{
  if(frameBufferSize <= maxDMABufferSize)
  {
    // base case: it fits!
    leadingBufferSize = frameBufferSize;
    trailingBufferSize = 0;
    return 1;
  } else {

    // painful case: it doesn't

    // Get the page size out of the SYSTEM_INFO structure
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    unsigned long pagesPerFrame = (frameBufferSize + si.dwPageSize - 1) / si.dwPageSize;
    unsigned long maxPagesPerDMABuffer = maxDMABufferSize / si.dwPageSize;

    // it seems that the reported maxDMABufferSize is a non-inclusive bound, because trying
    // to allocate resources to manage max-sized buffers fails (at least on Vista and Win7-64)
    // While unclear why, and thus a little hacky, the solution is to shave off one page
    maxPagesPerDMABuffer--;

    // todo: investigate whether forcing the 1394 host controller to bridge a packet across a DMA
    // buffer is problematic.  If so, then we should find LCM of page size and bytesPerIsochFrame
    //
    // But for now, just go with max DMA buffers up front, and a partial at the back.
    unsigned long leadingBuffers = pagesPerFrame / maxPagesPerDMABuffer;
    leadingBufferSize = maxPagesPerDMABuffer * si.dwPageSize;
    trailingBufferSize = frameBufferSize - (leadingBuffers * leadingBufferSize);
    if(trailingBufferSize == 0)
    {
      // perfect fit in leading buffers
      return leadingBuffers;
    } else {
      // one more for trailing buffer
      return leadingBuffers + 1;
    }
  }
  // should never get here
  return 0;
}

/**\brief Convert C1394Camera error code to human-readable (English) string
 * \param camerror the error to convert
 * \return NULL-terminated C-style error string
 * \ingroup camerr
 * \todo: make this a static member of C1394Camera?
 */
LPCSTR CAMAPI CameraErrorString(int camerror)
{
  switch(camerror)
  {
   case CAM_SUCCESS:
     return "Success (No Error)";
   case CAM_ERROR:
     return "I/O Error";
   case CAM_ERROR_UNSUPPORTED:
     return "Feature Unsupported";
   case CAM_ERROR_NOT_INITIALIZED:
     return "Camera Not Initialized";
   case CAM_ERROR_INVALID_VIDEO_SETTINGS:
     return "Invalid Video Settings";
   case CAM_ERROR_BUSY:
     return "Camera Busy Acquiring Images: Call StopImageAcquisition() First";
   case CAM_ERROR_INSUFFICIENT_RESOURCES:
     return "Insufficient Memory or 1394 bus resources";
   case CAM_ERROR_PARAM_OUT_OF_RANGE:
     return "Parameter Out of Range";
   case CAM_ERROR_FRAME_TIMEOUT:
     return "Frame Timeout";
  } // fall through
  return "Unknown Error";
}

