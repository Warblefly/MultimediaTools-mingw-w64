/**\file 1394camapi.h
 * \brief Root header for the C API
 * \ingroup capi
 *
 * Modified from 1394api.h as found in the Windows DDK
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

#ifndef __1394_CAMAPI_H__
#define __1394_CAMAPI_H__

#include <setupapi.h>
// extern "C" it if necessary (has something to do with calling conventions)

#ifdef __cplusplus
extern "C" {
#endif
// be sure to include the version of the header that lives in the same directory
#include "./1394common.h"

// export if compiling, import if using the library
#ifdef MY1394CAMERA_EXPORTS
#define CAMAPI __declspec(dllexport)
#else
#define CAMAPI __declspec(dllimport)
#endif

/**\brief A list of the camera features
 * The integer value behind the enumeration is important as it
 * may be used as an array index and may also be used to compute the
 * real register offsets in a camera
 */
typedef enum {
	// FEATURE_HI
	FEATURE_BRIGHTNESS = 0,
	FEATURE_AUTO_EXPOSURE,
	FEATURE_SHARPNESS,
	FEATURE_WHITE_BALANCE,
	FEATURE_HUE,
	FEATURE_SATURATION,
	FEATURE_GAMMA,
	FEATURE_SHUTTER,
	FEATURE_GAIN,
	FEATURE_IRIS,
	FEATURE_FOCUS,
	FEATURE_TEMPERATURE,
	FEATURE_TRIGGER_MODE,
	// 1.31
	FEATURE_TRIGGER_DELAY,
	FEATURE_WHITE_SHADING,
	FEATURE_FRAME_RATE,
	// 16-31 is reserved for other FEATURE_HI
	// FEATURE_LO
	FEATURE_ZOOM = 32,
	FEATURE_PAN,
	FEATURE_TILT,
	FEATURE_OPTICAL_FILTER,
	// 36-47 is reserved for other FEATURE_LO
	FEATURE_CAPTURE_SIZE = 48,
	FEATURE_CAPTURE_QUALITY,
	// 50-63 is reserved for other FEATURE_LO
	FEATURE_NUM_FEATURES = 64,
	FEATURE_INVALID_FEATURE = 0xFFFFFFFF
} CAMERA_FEATURE;

/**\brief Camera feature inquiry registers start at 0x0500 */
#define FEATURE_INQUIRY_INDEX 0x500
/**\brief Camera feature absolute controll offset registers start at 0x0700 */
#define FEATURE_ABSCTL_INDEX  0x700
/**\brief Camera feature status registers start at 0x0800 */
#define FEATURE_STATUS_INDEX  0x800

/**\brief Bitwise feature inquiry register representation */
typedef struct _FEATURE_INQUIRY_REGISTER {
	unsigned long max:12;
	unsigned long min:12;
	unsigned long manualmode:1;
	unsigned long automode:1;
	unsigned long onoff:1;
	unsigned long readout:1;
	unsigned long onepush:1;
	unsigned long _res0:1;
	unsigned long absctl:1;
	unsigned long present:1;
} FEATURE_INQUIRY_REGISTER;

/**\brief Bitwise feature inquiry status representation */
typedef struct _FEATURE_STATUS_REGISTER {
	unsigned long v_lo:12;
	unsigned long v_hi:12;
	unsigned long automode:1;
	unsigned long onoff:1;
	unsigned long onepush:1;
	unsigned long _res0:3;
	unsigned long absctl:1;
	unsigned long present:1;
} FEATURE_STATUS_REGISTER;

/**\brief Bitwise Trigger feature inquiry register */
typedef struct _TRIGGER_INQUIRY_REGISTER {
	unsigned long modebits:16;
	unsigned long sourcebits:8;
	unsigned long valueread:1;
	unsigned long polarity:1;
	unsigned long onoff:1;
	unsigned long readout:1;
	unsigned long _res0:2;
	unsigned long absctl:1;
	unsigned long present:1;
} TRIGGER_INQUIRY_REGISTER;

/**\brief Bitwise Trigger feature status register */
typedef struct _TRIGGER_STATUS_REGISTER {
	unsigned long parameter:12;
	unsigned long _res1:4;
	unsigned long mode:4;
	unsigned long value:1;
	unsigned long source:3;
	unsigned long polarity:1;
	unsigned long onoff:1;
	unsigned long _res0:4;
	unsigned long absctl:1;
	unsigned long present:1;
} TRIGGER_STATUS_REGISTER;

/* feature accessor stuff (tables.c) */
ULONG CAMAPI dc1394GetFeatureOffset(CAMERA_FEATURE id);
LPCSTR CAMAPI dc1394GetFeatureName(CAMERA_FEATURE id);
LPCSTR CAMAPI dc1394GetFeatureUnits(CAMERA_FEATURE id);
CAMERA_FEATURE CAMAPI dc1394GetFeatureId(const char *name);
BOOL CAMAPI dc1394TriggerModeHasParameter(ULONG nModeId, unsigned short *minValue, unsigned short *maxValue);

/**\brief various possible color codes for raw frame data */
typedef enum {
	COLOR_CODE_Y8 = 0,
	COLOR_CODE_YUV411,
	COLOR_CODE_YUV422,
	COLOR_CODE_YUV444,
	COLOR_CODE_RGB8,
	COLOR_CODE_Y16,
	COLOR_CODE_RGB16,
	COLOR_CODE_Y16_SIGNED,
	COLOR_CODE_RGB16_SIGNED,
	COLOR_CODE_RAW8,
	COLOR_CODE_RAW16,
	COLOR_CODE_MAX,
	COLOR_CODE_INVALID = -1
} COLOR_CODE;

/**\brief Bind width, height and color code together per video mode */
typedef struct _VIDEO_MODE_DESCRIPTOR {
	ULONG  width;
	ULONG  height;
	COLOR_CODE colorcode;
} VIDEO_MODE_DESCRIPTOR, *PVIDEO_MODE_DESCRIPTOR;

ULONG CAMAPI dc1394GetBufferSize(ULONG f, ULONG m);
LONG CAMAPI dc1394GetModeDescriptor(ULONG f, ULONG m, PVIDEO_MODE_DESCRIPTOR pDesc);
ULONG CAMAPI dc1394GetModeString(ULONG f, ULONG m, LPSTR buf, ULONG buflen);
LONG CAMAPI dc1394GetQuadletsPerPacket(ULONG f, ULONG m, ULONG r);
LPCTSTR CAMAPI dc1394GetColorCodeDescription(COLOR_CODE code);
LONG CAMAPI dc1394GetBitsPerPixel(COLOR_CODE code);

////////////////////////////////////////////////////////////////////////
// The defines/structs below are taken from 1394.h in the windows DDK //
// These *must* be defined before including 1394common.h              //
// They are redefined here so we don't need 1394.h to use the library //
////////////////////////////////////////////////////////////////////////
//
// Definitions of Speed flags used throughout 1394 Bus APIs
//
#define SPEED_FLAGS_100                         0x01
#define SPEED_FLAGS_200                         0x02
#define SPEED_FLAGS_400                         0x04
#define SPEED_FLAGS_800                         0x08
#define SPEED_FLAGS_1600                        0x10
#define SPEED_FLAGS_3200                        0x20
#define SPEED_FLAGS_FASTEST                     0x80000000

/**\brief 1394 bus cycle time bitwise structure, currently unused */
typedef struct _CYCLE_TIME {
    ULONG               CL_CycleOffset:12;      // Bits 0-11
    ULONG               CL_CycleCount:13;       // Bits 12-24
    ULONG               CL_SecondCount:7;       // Bits 25-31
} CYCLE_TIME, *PCYCLE_TIME;

/**\brief swap endianity for an unsigned long */
#define bswap(value)    (((ULONG) (value)) << 24 |\
                        (((ULONG) (value)) & 0x0000FF00) << 8 |\
                        (((ULONG) (value)) & 0x00FF0000) >> 8 |\
                        ((ULONG) (value)) >> 24)

/**\brief swap endianity for an unsigned short */
#define bswapw(value)   (((USHORT) (value)) << 8 |\
                        (((USHORT) (value)) & 0xff00) >> 8)

//
// function prototypes
//

// isochapi.c

DWORD
CAMAPI
t1394IsochSetupStream(
	PSTR szDeviceName,
	PISOCH_STREAM_PARAMS pStreamParams
	);

DWORD
CAMAPI
t1394IsochTearDownStream(
	PSTR szDeviceName 
	);

DWORD
CAMAPI
t1394IsochAttachBuffer(
    HANDLE hDevice,
    LPVOID pBuffer,
    ULONG  ulBufferLength,
    PISOCH_BUFFER_PARAMS pParams,
    LPOVERLAPPED pOverLapped
    );

DWORD
CAMAPI
t1394IsochListen(
    PSTR            szDeviceName
    );

DWORD
CAMAPI
t1394IsochStop(
    PSTR            szDeviceName
    );

DWORD
CAMAPI
t1394IsochQueryCurrentCycleTime(
    PSTR            szDeviceName,
    PCYCLE_TIME     CycleTime
    );

DWORD
CAMAPI
t1394IsochQueryResources(
    PSTR                        szDeviceName,
    PISOCH_QUERY_RESOURCES      isochQueryResources
    );

/* Extensions to isochapi.c, particularly in support of 64-bit DMA issues */

/**\brief Maximum number of sub-buffers associated with a given framebuffer */
#define MAX_SUB_BUFFERS 64

/**\brief Keep everything about a frame buffer in one place
 * \ingroup capi
 *
 * Associates all the necessary	information	for	an image acquisition buffer
 * This	includes the overlapped	structures used with	DeviceIoControl, pointers
 * to the buffer and other bookeeping issues such as the concept of "sub-buffers"
 * necessary to transfer large frame buffers on 64-bit platforms
 */
typedef	struct _ACQUISITION_BUFFER {
	ULONG							ulBufferSize; ///< the size of the overall buffer
	PUCHAR							pDataBuf;     ///< pointer to the actual underlying buffer
	PUCHAR							pFrameStart;  ///< page-aligned pointer within pDataBuf to start the frame
	ULONG                           index;        ///< user-defined index for this buffer
    ULONG                           nSubBuffers;  ///< the number of sub-buffers that comprise this frame buffer
    BOOL                            bNativelyContiguous; ///< Whether the sub-buffers are natively contiguous (false = requires "flattening" after DMA is complete)
    BOOL                            bCurrentlyContiguous; ///< Whether the buffer has been "flattened" (only relevant for !bNativelyContiguous, reset on attach)
    struct _subBuffer {
        OVERLAPPED                  overLapped;   ///< the overlapped I/O structure associated with this sub-buffer
        PUCHAR                      pData;        ///< the page-aligned starting point for this buffer
        ULONG                       ulSize;       ///< the size of this sub-buffer
    } subBuffers[MAX_SUB_BUFFERS];
	struct _ACQUISITION_BUFFER		*pNextBuffer; ///< support linked lists of buffers
} ACQUISITION_BUFFER, *PACQUISITION_BUFFER;

PACQUISITION_BUFFER
CAMAPI
dc1394BuildAcquisitonBuffer(ULONG frameBufferSize, ULONG maxDMABufferSize, ULONG targetBytesPerPacket, ULONG index);

void
CAMAPI
dc1394FreeAcquisitionBuffer(PACQUISITION_BUFFER pAcqBufer);

DWORD
CAMAPI
dc1394AttachAcquisitionBuffer(HANDLE hDevice, PACQUISITION_BUFFER pAcqBuffer);

void CAMAPI dc1394FlattenAcquisitionBuffer(PACQUISITION_BUFFER pAcqBuffer);

// 1394main.c
DWORD
CAMAPI
ReadRegister(
	PSTR szDeviceName,
	ULONG ulOffset,
	PUCHAR bytes
	);

DWORD
CAMAPI
ReadRegisterUL(
	PSTR szDeviceName,
	ULONG ulOffset,
	PULONG pData
	);

DWORD
CAMAPI
WriteRegister(
	PSTR szDeviceName,
	ULONG ulOffset,
	PUCHAR bytes
	);

DWORD 
CAMAPI
WriteRegisterUL(
	PSTR szDeviceName,
	ULONG ulOffset,
	ULONG data
	);


DWORD
CAMAPI
GetModelName(
	PSTR szDeviceName,
	PSTR buffer,
	ULONG buflen
	);

DWORD
CAMAPI
GetVendorName(
	PSTR szDeviceName,
	PSTR buffer,
	ULONG buflen
	);

DWORD
CAMAPI
GetUniqueID(
	PSTR szDeviceName,
	PLARGE_INTEGER pliUniqueID
	);

DWORD
CAMAPI
GetCameraSpecification( 
	PSTR szDeviceName, 
	PCAMERA_SPECIFICATION pSpec
	);

DWORD
CAMAPI
GetCmdrState(
	PSTR szDeviceName
	);

DWORD
CAMAPI
ResetCmdrState(
	PSTR szDeviceName 
	);

DWORD
CAMAPI
SetCmdrTraceLevel(
	PSTR szDeviceName, 
	DWORD nlevel
	);

DWORD
CAMAPI
GetCmdrTraceLevel( PSTR szDeviceName, DWORD *nlevel);

const
GUID
CAMAPI
t1394CmdrGetGUID(
);

HDEVINFO
CAMAPI
t1394CmdrGetDeviceList(
    );

DWORD
CAMAPI
t1394CmdrGetDevicePath(
	HDEVINFO hDevInfo,
	DWORD dwDevIndex,
	PCHAR pDevicePath,
	PULONG pDevicePathLen
	);

ULONG
CAMAPI
GetCmdrVersion(
    PSTR            szDeviceName,
    PVERSION_DATA   Version,
    BOOL            bMatch
    );

// getmaxspeed was moved from 1394camapi.c into 1394main.c because it was the only function we use from that file
/* cbaker: deprecated at 6.4.6 in favor of GetMaxIsochSpeed()
ULONG
CAMAPI
GetMaxSpeedBetweenDevices(
    PSTR                            szDeviceName,
    PGET_MAX_SPEED_BETWEEN_DEVICES  GetMaxSpeedBetweenDevices
    );
    */

ULONG
CAMAPI
GetMaxIsochSpeed(
    PSTR szDeviceName,
    PULONG fulSpeed
    );

DWORD
CAMAPI
t1394_GetHostDmaCapabilities(
	LPCSTR szDeviceName,
	PULONG pulCapabilitiesMask,
	PULARGE_INTEGER puliMaxBufferSize
	);

// Opendevice moved out of util.c for similar reasons

HANDLE
CAMAPI
OpenDevice(
    LPCSTR    szDeviceName,
    BOOL    bOverLapped
    );

LONG 
CAMAPI
SpeedFlagToIndex(ULONG fulFlags);

// debug.c

void 
CAMAPI
SetDllTraceLevel(int nlevel);

// 1394main.c
HKEY
CAMAPI
OpenCameraSettingsKey(LPCSTR subkey, DWORD dwOptions, REGSAM samDesired);

// cap off the extern "C"

#ifdef __cplusplus
}
#endif

#endif /* __1394_CAMAPI_H__ */