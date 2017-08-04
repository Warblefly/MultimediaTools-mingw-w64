/**\file 1394common.h
 * \brief IOCTL interface header for 1394cmdr.sys
 * \ingroup capi
 *
 * Modified from 1394common.h as found in the Windows DDK
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

#ifndef _1394_COMMON_H_
#define _1394_COMMON_H_

#ifdef __cplusplus
extern "C" {
#endif

// 1394cmdr GUID is {F390415A-2EAF-4fd4-ACCC-3D17D38F2898}
DEFINE_GUID(GUID_1394CMDR, 0xf390415a, 0x2eaf, 0x4fd4, 0xac, 0xcc, 0x3d, 0x17, 0xd3, 0x8f, 0x28, 0x98);
#define GUID_1394CMDR_STR                   "F390415A-2EAF-4fd4-ACCC-3D17D38F2898"

//
// define's used to make sure the dll/sys driver are in synch
//
#define CMDR_MAJORVERSION 6
#define CMDR_MINORVERSION 4
#define CMDR_REVISION     6
#define CMDR_BUILD        240

#define CMDR_VERSIONSTRING "6.04.06.0240"

//
// these guys are meant to be called from a ring 3 app
// call through the port device object
//
#define IOCTL_1394_TOGGLE_ENUM_TEST_ON          CTL_CODE( \
                                                FILE_DEVICE_UNKNOWN, \
                                                0x88, \
                                                METHOD_BUFFERED, \
                                                FILE_ANY_ACCESS \
                                                )

#define IOCTL_1394_TOGGLE_ENUM_TEST_OFF         CTL_CODE( \
                                                FILE_DEVICE_UNKNOWN, \
                                                0x89, \
                                                METHOD_BUFFERED, \
                                                FILE_ANY_ACCESS \
                                                )

//
// IOCTL info, needs to be visible for application
//
#define CMDR1394_IOCTL_INDEX                            0x0800

/* old async I/O stuff, kept around for posterity
#define IOCTL_ASYNC_READ                                CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 2,       \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_ASYNC_WRITE                               CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 3,       \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
*/
#define IOCTL_ISOCH_LISTEN                              CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 13,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_ISOCH_QUERY_CURRENT_CYCLE_TIME            CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 14,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_ISOCH_QUERY_RESOURCES                     CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 15,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
#define IOCTL_ISOCH_STOP                                CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 17,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
#define IOCTL_GET_LOCAL_HOST_INFORMATION                CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 19,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
/*
#define IOCTL_GET_1394_ADDRESS_FROM_DEVICE_OBJECT       CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 20,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_CONTROL                                   CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 21,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_MAX_SPEED_BETWEEN_DEVICES             CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 22,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_SET_DEVICE_XMIT_PROPERTIES                CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 23,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
*/
#define IOCTL_GET_CONFIGURATION_INFORMATION             CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 24,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_BUS_RESET                                 CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 25,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_GENERATION_COUNT                      CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 26,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_SEND_PHY_CONFIGURATION_PACKET             CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 27,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_BUS_RESET_NOTIFICATION                    CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 28,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_ASYNC_STREAM                              CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 29,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
/*
#define IOCTL_SET_LOCAL_HOST_INFORMATION                CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 30,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
*/
#define IOCTL_SET_ADDRESS_DATA                          CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 40,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_ADDRESS_DATA                          CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 41,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_BUS_RESET_NOTIFY                          CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 50,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_CMDR_VERSION                          CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 51,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_CMDR_STATE                            CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 52,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_RESET_CMDR_STATE                          CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 53,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_SET_CMDR_TRACELEVEL                       CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 54,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_READ_REGISTER								CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 55,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_WRITE_REGISTER							CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 56,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_MODEL_NAME							CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 57,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_VENDOR_NAME							CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 58,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_CAMERA_SPECIFICATION					CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 59,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_CAMERA_UNIQUE_ID						CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 60,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_ATTACH_BUFFER								CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 61,      \
                                                        METHOD_OUT_DIRECT,              \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_CMDR_TRACELEVEL                       CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 64,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_ISOCH_SETUP_STREAM						CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 80,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_ISOCH_TEAR_DOWN_STREAM					CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 81,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)

#define IOCTL_GET_MAX_ISOCH_SPEED						CTL_CODE( FILE_DEVICE_UNKNOWN,  \
                                                        CMDR1394_IOCTL_INDEX + 82,      \
                                                        METHOD_BUFFERED,                \
                                                        FILE_ANY_ACCESS)
//
// struct used with IOCTL_ISOCH_SETUP_STREAM
//

// To maintain backwards-compatibility and to make efficient use of otherwise wasted space
// we embed stream flags in the top eight bytes of nMaxByresPerFrame

#define BYTES_PER_FRAME_FLAG_MASK 0xff000000
#define BYTES_PER_FRAME_DATA_MASK (~BYTES_PER_FRAME_FLAG_MASK)

// This will allow packet splitting consistent with Point Grey's Dual-Packet Feature as appropriate
#define BYTES_PER_FRAME_ALLOW_PGR_DUAL_PACKET  0x80000000

typedef struct _ISOCH_STREAM_PARAMS {
  ULONG fulSpeed;
  ULONG nMaxBytesPerFrame;
  ULONG nChannel;
  ULONG nNumberOfBuffers;
  ULONG nMaxBufferSize;
} ISOCH_STREAM_PARAMS, *PISOCH_STREAM_PARAMS;

#define ISOCH_BUFFER_PRIMARY 0x00
#define ISOCH_BUFFER_SECONDARY 0x01

typedef struct _ISOCH_BUFFER_PARAMS {
    ULONG ulFlags;
} ISOCH_BUFFER_PARAMS, *PISOCH_BUFFER_PARAMS;
/*
//
// struct used to pass in with IOCTL_ASYNC_READ
//
typedef struct _ASYNC_READ {
    ULONG           bRawMode;
    ULONG           bGetGeneration;
    IO_ADDRESS      DestinationAddress;
    ULONG           nNumberOfBytesToRead;
    ULONG           nBlockSize;
    ULONG           fulFlags;
    ULONG           ulGeneration;
    UCHAR           Data[1];
} ASYNC_READ, *PASYNC_READ;

//
// struct used to pass in with IOCTL_ASYNC_WRITE
//
typedef struct _ASYNC_WRITE {
    ULONG           bRawMode;
    ULONG           bGetGeneration;
    IO_ADDRESS      DestinationAddress;
    ULONG           nNumberOfBytesToWrite;
    ULONG           nBlockSize;
    ULONG           fulFlags;
    ULONG           ulGeneration;
    UCHAR           Data[1];
} ASYNC_WRITE, *PASYNC_WRITE;
*/

//
// struct used to pass in with IOCTL_ISOCH_QUERY_RESOURCES
//
typedef struct _ISOCH_QUERY_RESOURCES {
    ULONG           fulSpeed;
    ULONG           BytesPerFrameAvailable;
    LARGE_INTEGER   ChannelsAvailable;
} ISOCH_QUERY_RESOURCES, *PISOCH_QUERY_RESOURCES;
//
// struct used to pass in with IOCTL_GET_LOCAL_HOST_INFORMATION
//
typedef struct _GET_LOCAL_HOST_INFORMATION {
    ULONG           Status;
    ULONG           nLevel;
    ULONG           ulBufferSize;
    UCHAR           Information[1];
} GET_LOCAL_HOST_INFORMATION, *PGET_LOCAL_HOST_INFORMATION;


//
// struct used to pass in with IOCTL_GET_MAX_SPEED_BETWEEN_DEVICES
//
/* cbaker: deprecated at 6.4.6 in favor of IOCTL_GET_MAX_ISOCH_SPEED
typedef struct _GET_MAX_SPEED_BETWEEN_DEVICES {
    ULONG           fulFlags;
    ULONG           ulNumberOfDestinations;
    HANDLE          hDestinationDeviceObjects[64];
    ULONG           fulSpeed;
} GET_MAX_SPEED_BETWEEN_DEVICES, *PGET_MAX_SPEED_BETWEEN_DEVICES;
*/

//
// struct used to pass in with IOCTL_GET_DIAG_VERSION
//
typedef struct _VERSION_DATA {
    USHORT           usMajor;
    USHORT           usMinor;
    USHORT           usRevision;
    USHORT           usBuild;
} VERSION_DATA, *PVERSION_DATA;

//
// struct for use with reading/writing registers
//
typedef struct _REGISTER_IOBUF
{
	ULONG		ulOffset;
	UCHAR		data[4];
} REGISTER_IOBUF, *PREGISTER_IOBUF;

//
// struct used to get camera specification information
//
typedef struct _CAMERA_SPECIFICATION
{
	ULONG		ulSpecification;
	ULONG		ulVersion;
} CAMERA_SPECIFICATION, *PCAMERA_SPECIFICATION;

#ifdef __cplusplus
}
#endif

#endif // #ifndef _1394_COMMON_H_


