/**\file 1394Camera.h
 * \brief Primary Header File for the CMU 1394 Digital Camera Driver
 * \ingroup	camcore
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

#ifndef	__1394CAMERA_H__
#define	__1394CAMERA_H__

#ifdef MY1394CAMERA_EXPORTS

// compiling library, reference
// private,	potentially	modified
// version of the headers
#include "1394camapi.h"
#include "1394CameraControl.h"
#include "1394CameraControlTrigger.h"
#include "1394CameraControlStrobe.h"
#include "1394CameraControlSize.h"


#else

// using library, use global versions
#include <1394camapi.h>
#include <1394CameraControl.h>
#include <1394CameraControlTrigger.h>
#include <1394CameraControlStrobe.h>
#include <1394CameraControlSize.h>

#endif // MY1394CAMERA_EXPORTS

/**\defgroup camerr Error Codes
 * \ingroup camcore
 *
 * C1394Camera class-specific error codes, used to indicate several specific failures
 * Success is a zero return, all errors are nonzero (should be negative)
 */

/**\brief Success
 * \ingroup camerr
 */
#define	CAM_SUCCESS	0
/**\brief Generic Error
 * \ingroup camerr
 *
 * This error typically indicates some problem from the Windows I/O subsystem.  A call
 * to the win32 GetLastError() should prove enlightening
 */
#define	CAM_ERROR -1
/**\brief The feature implied by the called function (e.g. SetPIOOutputBits()) is not supported.
 * \ingroup camerr
 */
#define	CAM_ERROR_UNSUPPORTED -10
/**\brief The camera is not properly initialized.  
 * 
 * After selecting a camera with SelectCamera(), it is necessary to make a successful call to 
 * InitCamera() before proceeding.  
 * \ingroup camerr
 */
#define	CAM_ERROR_NOT_INITIALIZED -11
/**\brief The selected video settings are unsupported.
 * \ingroup camerr
 *
 * If this comes from anything other than a SetVideoSomething call, then it indicates some
 * broken internal invariants.
 */
#define	CAM_ERROR_INVALID_VIDEO_SETTINGS -12
/**\brief Many functions are disallowed while acquiring images, you must call StopImageAcquisition() first
 * \ingroup camerr
 */
#define	CAM_ERROR_BUSY -13
/**\brief Insufficient memory or bus bandwidth is available to complete the request.
 * \ingroup camerr
 */
#define	CAM_ERROR_INSUFFICIENT_RESOURCES -14
/**\brief Many parameters have bounds, one of them has been exceeded.
 * \ingroup camerr
 */
#define	CAM_ERROR_PARAM_OUT_OF_RANGE -15
/**\brief Returned by AcquireImageEx() to indicate that the timeout has expired and no frame is ready.
 * \ingroup camerr
 */
#define	CAM_ERROR_FRAME_TIMEOUT	-16

/**\brief Whether StartImageAcquisitionEx()	should automatically start the camera stream 
 * \ingroup	acqflags
 */
#define	ACQ_START_VIDEO_STREAM 0x01

/**\brief Attempt to read channel and speed	settings from the camera and subscribe to its stream
 * \ingroup	acqflags
 */
#define	ACQ_SUBSCRIBE_ONLY	   0x02

/**\brief Enable Support for PGR Dual-Packet mode, where the camera splits isoch packets to use
 * more of the total available bandwidth.  Note: this may cause problems if enabled for non-PGR cameras
 * and is a stretch of the 1394 bus specification.
 * \ingroup acqflags
 */
#define ACQ_ALLOW_PGR_DUAL_PACKET 0x04

// the C1394Camera class
// member function implementations are in  1394Camera.cpp unless otherwise noted

/**
 * \brief This class may be	used to	control	one	camera on the 1394 bus.
 * \ingroup	camcore
 *
 * This	class encapsulates all the functionality necessary to interface	to an IIDC
 * compliant 1394 digital camera.  To interface	to multiple	cameras, you must instantiate 
 * multiple	instances of this class.
 */
class CAMAPI C1394Camera  
{
public:
	// constructor
	C1394Camera();
	// destructor
	~C1394Camera();
	
	// Selection/Control
	int	RefreshCameraList();
	int	InitCamera(BOOL	reset=FALSE);
	bool IsInitialized();
	int	GetNode();
	int	GetNodeDescription(int node, char *buf,	int	buflen);
    const char *GetDevicePath();
	int	SelectCamera(int node);
	unsigned long GetVersion();
	int	GetNumberCameras();
	void GetCameraName(char	*buf, int len);
	void GetCameraVendor(char *buf,	int	len);
	void GetCameraUniqueID(PLARGE_INTEGER pUniqueID);
	int	 GetMaxSpeed();
	void GetMaxBufferSize(PULARGE_INTEGER puliBufferSize);
	int	 CheckLink();
	bool HasPowerControl();
	bool StatusPowerControl();
	int	 SetPowerControl(BOOL	on);
	bool Has1394b();
	bool Status1394b();
	int	 Set1394b(BOOL on);
	
	// Store/Retrieve Settings from	camera EEPROM
	int	MemGetNumChannels();
	int	MemGetCurrentChannel();
	int	MemLoadChannel(int channel);
	int	MemSaveChannel(int channel);
	
	// Store/Retrieve Settings from	system Registry
	int	RegLoadSettings(const char *pname);
	int	RegSaveSettings(const char *pname);
	
	// Raw register	I/O
	int	WriteQuadlet(unsigned long address,	unsigned long data);
	int	ReadQuadlet(unsigned long address, unsigned	long *pData);
	
	// Video format/mode/rate
	BOOL HasVideoFormat(unsigned long format);
	int	SetVideoFormat(unsigned	long format);
	int	GetVideoFormat();
	
	BOOL HasVideoMode(unsigned long	format,	unsigned long mode);
	int	SetVideoMode(unsigned long mode);
	int	GetVideoMode();
	
	BOOL HasVideoFrameRate(unsigned	long format, unsigned long mode, unsigned long rate);
	int	SetVideoFrameRate(unsigned long	rate);
	int	GetVideoFrameRate();
	
	void GetVideoFrameDimensions(unsigned long *pWidth,	unsigned long *pHeight);
	void GetVideoDataDepth(unsigned short *depth);
	bool StatusVideoErrors(BOOL Refresh);
	
	void UpdateParameters(BOOL UpdateOnly = FALSE);

	// Image Capture (1394CamCap.cpp)
	int	StartImageCapture();
	int	CaptureImage();
	int	StopImageCapture();
	
	// Image Acquisition (1394CamAcq.cpp)
	int	StartImageAcquisition();
	int	StartImageAcquisitionEx(int	nBuffers, int FrameTimeout,	int	Flags);
	int	AcquireImage();
	int	AcquireImageEx(BOOL	DropStaleFrames, int *lpnDroppedFrames);
	int	StopImageAcquisition();
	bool IsAcquiring();
	unsigned char *GetRawData(unsigned long	*pLength);
	HANDLE GetFrameEvent();
	
	// Video Stream	Control
	int	StartVideoStream();
	int	StopVideoStream();
	bool HasOneShot();
	int	OneShot();
	bool HasMultiShot();
	int	MultiShot(unsigned short count);
	
	// Color Format	Conversion (1394CamRGB.cpp)
	
	// convert data	to standard: RGB, upper-left corner
	// based on	video format/mode
	int	getRGB(unsigned	char *pBitmap, unsigned	long length);
	
	// same	as getRGB, except data is returned in the
	// bottom-up, BGR format the MS	calls a	DIB
	int	getDIB(unsigned	char *pBitmap, unsigned	long length);
	
	// individual RGB converters
	int	YtoRGB(unsigned	char *pBitmap, unsigned	long length);
	int	Y16toRGB(unsigned char *pBitmap, unsigned long length);
	int	YUV411toRGB(unsigned char* pBitmap,	unsigned long length);
	int	YUV422toRGB(unsigned char* pBitmap,	unsigned long length);
	int	YUV444toRGB(unsigned char* pBitmap,	unsigned long length);
	int	RGB16toRGB(unsigned	char *pBitmap, unsigned	long length);
	
	// Basic Features Interface
	void RefreshControlRegisters(BOOL bForceAll = FALSE);
	bool HasFeature(CAMERA_FEATURE fID);
	bool StatusFeatureError(CAMERA_FEATURE fID, BOOL Refresh);
	C1394CameraControl *GetCameraControl(CAMERA_FEATURE fID);
	C1394CameraControlTrigger *GetCameraControlTrigger();
	C1394CameraControlSize *GetCameraControlSize();

	// Optional Functions
	bool HasOptionalFeatures();
	
	// PIO Interface
	bool HasPIO();
	unsigned long GetPIOControlOffset();
	int GetPIOInputBits (unsigned long *ulBits);
	int GetPIOOutputBits(unsigned long *ulBits);
	int SetPIOOutputBits(unsigned long ulBits);
	int GetSIOStatusByte(unsigned char *byte);
	int GetSIOConfig(unsigned long *ulBits);

	// SIO Interface
	bool HasSIO();
	unsigned long GetSIOControlOffset();
	int SIOConfigPort(unsigned long baud, unsigned long databits, unsigned long stopbits, unsigned long parity);
	int SIOEnable(BOOL bReceive, BOOL bTransmit);
	int SIOReadBytes(unsigned char *data, unsigned long datalen);
	int SIOWriteBytes(unsigned char *data, unsigned long datalen);

	// Strobe Interface
	bool HasStrobe();
	unsigned long GetStrobeControlOffset();
	C1394CameraControlStrobe *GetStrobeControl(unsigned long strobeID);

	// advanced/optional feature offsets
	bool HasAdvancedFeature();
	unsigned long GetAdvancedFeatureOffset();
private:
	// Utility Private Functions
	BOOL InitResources();
	BOOL FreeResources();
	unsigned long ComputeBufferParameters(const unsigned long frameBufferSize,
										 const unsigned long bytesPerIsochPacket,
										 const unsigned long maxDMABufferSize,
										 unsigned long &leadingBufferSize,
										 unsigned long &trailingBufferSize);
	BOOL InquireVideoFormats();
	BOOL InquireVideoModes();
	BOOL InquireVideoRates();
	bool CheckVideoSettings();
	
	// static inquiry registers
	ULONG m_InqBasicFunc;
	ULONG m_InqFeatureHi;
	ULONG m_InqFeatureLo;
	ULONG m_InqOptionalFunc;
	ULONG m_InqVideoFormats;
	ULONG m_InqVideoModes[8];
	ULONG m_InqVideoRates[8][8];
	
	// status	registers
	ULONG m_StatusPowerControl;
	ULONG m_StatusVideoError;
	ULONG m_StatusVideoDepth;
	ULONG m_StatusFeatureErrorHi;
	ULONG m_StatusFeatureErrorLo;
	
	// optional feature offsets
	ULONG m_AdvFuncOffset;
	ULONG m_PIOFuncOffset;
	ULONG m_SIOFuncOffset;
	ULONG m_StrobeFuncOffset;
	ULONG m_StrobeRootCaps;
	
	// pertaining to video format/mode/rate
	int	m_videoFrameRate;
	int	m_videoMode;
	int	m_videoFormat;
	int	m_maxBytes;
	int	m_maxBufferSize;
	ULONG m_maxSpeed;
	int	m_width;
	int	m_height;
	COLOR_CODE m_colorCode;
	
	// which camera	are	we using
	int	m_node;
	char* m_pName;
	
	// utility members
	bool m_linkChecked;
	bool m_cameraInitialized;
	char m_nameModel[256];
	char m_nameVendor[256];
	LARGE_INTEGER m_UniqueID;
	
	// camera data grabbed from	the	driver
	CAMERA_SPECIFICATION m_spec;
	
	// buffer management
	PACQUISITION_BUFFER	m_pFirstBuffer;
	PACQUISITION_BUFFER	m_pLastBuffer;
	PACQUISITION_BUFFER	m_pCurrentBuffer;
	
	// acquisition vars
	int	m_AcquisitionTimeout;
	int	m_AcquisitionFlags;
	int	m_AcquisitionBuffers;
	
	// persistent handles
	HANDLE	 m_hDeviceAcquisition;
	HDEVINFO m_hDevInfo;
	DWORD    m_dwDevCount;
	char m_DevicePath[512];
	
	// controls
	C1394CameraControl        *m_pControls[FEATURE_NUM_FEATURES];
	C1394CameraControlTrigger *m_pControlTrigger;
	C1394CameraControlSize    *m_pControlSize;
	C1394CameraControlStrobe  *m_controlStrobes[4];
};


/***************************/
/* common dialog functions */
/***************************/

HWND
CAMAPI
CameraControlDialog(
	HWND hWndParent,
	C1394Camera	*pCamera,
	BOOL bLoadDefaultView
	);

long
CAMAPI
CameraControlSizeDialog(HWND hWndParent, 
						C1394Camera	*pCamera);

LPCSTR CAMAPI CameraErrorString(int camerror);

extern "C" {
void
CAMAPI
CameraDebugDialog(
	HWND hWndParent
	);
}


#endif // __1394CAMERA_H__
