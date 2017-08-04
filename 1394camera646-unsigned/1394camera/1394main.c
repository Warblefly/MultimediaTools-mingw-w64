/**\file 1394main.c 
 * \brief Core I/O and management functions
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

#define INITGUID
#include "pch.h"

/**\defgroup capi C API
 * \brief A collection of pure "C" functions through which we interface to 1394cmdr.sys
 *
 * There is a collection of C functions between the C1394Camera class and the IOCTL interface
 * that has the potential to be drawn out into a separate DLL and formed into something that
 * is signature-compatible with Linux's <i>libdc1394</i>.  It is a goal for another day, but
 * the beginnings are here.
 */

HINSTANCE g_hInstDLL;

/**\brief Dll Entry Function
 * \param hInstance Handle to the DLL instance
 * \param ulReason Action taken (process attach, etc)
 * \param pvReserved Unused
 *
 * Under 1394diag, this function did a bunch of things with shared memory and process management
 *
 * Now, it does nothing interesting at all, except to dump a bit of stuff to the debug console and
 * store the DLL's parent instance in a global var to make the Dialog functions work.
 */
BOOL
WINAPI
DllMain(
    HINSTANCE   hInstance,
    ULONG       ulReason,
    LPVOID      pvReserved
    )
{
	HKEY myKey = NULL;
	DWORD dwTraceLevel = DLL_TRACE_WARNING,dwType,dwSize = sizeof(DWORD);

	g_hInstDLL = hInstance;

	// now that we don't start the extra process nor muck around with shared
	// memory and device change signals and bus resets, DllMain is really simple

	if(ulReason == DLL_PROCESS_ATTACH)
	{
		// load the tracelevel from the registry
		DllTrace(DLL_TRACE_ALWAYS,"DllMain: DLL_PROCESS_ATTACH to 1394Camera.dll version %s (%d-bit)\n","6.04.06.240",8 * sizeof(void *));

		// set the initial trace level to "warning", then read out of the registry if possible
		dwTraceLevel = DLL_TRACE_WARNING;

		if((myKey = OpenCameraSettingsKey(NULL,REG_OPTION_NON_VOLATILE,KEY_READ)) != NULL)
		{
			if(ERROR_SUCCESS == RegQueryValueEx(myKey,"DllTraceLevel",NULL,&dwType,(LPBYTE)&dwTraceLevel,&dwSize))
			{
				DllTrace(DLL_TRACE_ALWAYS,"DllMain:   -> Using DllTraceLevel %d from registry",dwTraceLevel);
			} else {
				DllTrace(DLL_TRACE_ALWAYS,"DllMain:   -> DllTraceLevel undefined in registry, using %d by default",dwTraceLevel);
			}
			RegCloseKey(myKey);
		}
		SetDllTraceLevel(dwTraceLevel);
	}
	return TRUE;
}

/**\brief Retrieve the "state" of the kernel module
 * \ingroup capi
 * \param szDeviceName The full pathname of the device
 * \return The magic state, -1 on error
 *
 * This is Currently just a stub that doesn't do anything noteworthy
 * May eventually be used to report statistics, or more
 */
DWORD
CAMAPI
GetCmdrState( PSTR szDeviceName)
{
	DWORD state;
	HANDLE hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
		if(DeviceIoControl(hDevice,IOCTL_GET_CMDR_STATE,NULL,0,&state,sizeof(DWORD),NULL,NULL))
		{
			CloseHandle(hDevice); //SR
			return state;
		}
		CloseHandle(hDevice); //SR
	}
	return -1;
}

/**\brief Set the debug tracelevel of the kernel module
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param nlevel The trace level to set
 * \return 0 on success, -1 on error
 */
DWORD
CAMAPI
SetCmdrTraceLevel( PSTR szDeviceName, DWORD nlevel)
{
	DWORD level = nlevel;
	DWORD dwBytesRet;
	HANDLE hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
		if(DeviceIoControl(hDevice,IOCTL_SET_CMDR_TRACELEVEL,&level,sizeof(DWORD),&level,sizeof(DWORD),&dwBytesRet,NULL))
		{
			CloseHandle(hDevice); //SR
			return 0;
		}
		CloseHandle(hDevice); //SR
	}
	return -1;
}

/**\brief Retrieve the current kernel module tracelevel
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param nlevel where to put the tracelevel
 * \return 0 on success, -1 on error
 */
DWORD
CAMAPI
GetCmdrTraceLevel( PSTR szDeviceName, DWORD *nlevel)
{
	DWORD dwBytesRet;
	HANDLE hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
		if(DeviceIoControl(hDevice,IOCTL_GET_CMDR_TRACELEVEL,NULL,0,nlevel,sizeof(DWORD),&dwBytesRet,NULL))
		{
			CloseHandle(hDevice); //SR
			return 0;
		}
		CloseHandle(hDevice); //SR
	}
	return -1;
}

/**\brief Return a copy of the GUID for the CMU 1394CMDR class
 * \ingroup capi
 * \return The GUID
 *
 * This little wrapper basically makes access to the GUID a little cleaner for anywone who wishes to use it.
 */
const
GUID
CAMAPI
t1394CmdrGetGUID()
{
	return GUID_1394CMDR;
}

/**\brief Query the Device Interface Subsystem fora list of available cameras
 * \ingroup capi
 * \return HDEVINFO for the camera list, INVALID_HANDLE_VALUE on error.
 * \see t1394CmdrGetDevicePath
 *
 * This basically abstracts the usage of the 1394CMDR GUID to locate cameras in the system.
 * The HDEVINFO provided must eventually released by a call to SetupDiDestroyDeviceInfoList()
 */
HDEVINFO
CAMAPI
t1394CmdrGetDeviceList(
    )
{
    GUID t1394CmdrGUID = GUID_1394CMDR;
	HDEVINFO hDevInfo;

    hDevInfo = SetupDiGetClassDevs( &t1394CmdrGUID,
                                    NULL,
                                    NULL,
                                    (DIGCF_PRESENT | DIGCF_INTERFACEDEVICE)
                                    );

	DllTrace(DLL_TRACE_EXIT,"t1394CmdrGetDeviceList: %08x\n",hDevInfo);
	return hDevInfo;
}

/**\brief Retrieve a device path from a device list
 * \ingroup capi
 * \param hDevInfo Device Info List from t1394CmdrGetDeviceList
 * \param dwDevIndex The index of the camera path to retrieve
 * \param pDevicePath Pointer to a char buffer to reviece the path
 * \param pDevicePathLen Length of the buffer.
 * \return Length of the device path string on success, 0 if no more cameras, -1 on error
 *
 * Again more wrapping on the otherwise ugly SetupDiBlah functions
 */
DWORD
CAMAPI
t1394CmdrGetDevicePath(
	HDEVINFO hDevInfo,
	DWORD dwDevIndex,
	PCHAR pDevicePath,
	PULONG pDevicePathLen
	)
{
    SP_DEVICE_INTERFACE_DATA            deviceInterfaceData;
    PSP_DEVICE_INTERFACE_DETAIL_DATA    DeviceInterfaceDetailData;
    GUID t1394CmdrGUID = GUID_1394CMDR;
	BOOL bReturn;

	// snag device info
    deviceInterfaceData.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);
	bReturn = SetupDiEnumDeviceInterfaces(hDevInfo, 
		                                  NULL, 
										  &t1394CmdrGUID, 
										  dwDevIndex, 
										  &deviceInterfaceData);

	if(!bReturn)
		return GetLastError() == ERROR_NO_MORE_ITEMS ? 0 : -1;

	// snag extended interface info
	DeviceInterfaceDetailData = (PSP_DEVICE_INTERFACE_DETAIL_DATA)(pDevicePath);
	memset(DeviceInterfaceDetailData,0,*pDevicePathLen);
	DeviceInterfaceDetailData->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA);
	bReturn = SetupDiGetDeviceInterfaceDetail( hDevInfo,
											   &deviceInterfaceData,
											   DeviceInterfaceDetailData,
											   *pDevicePathLen,//requiredSize,
											   pDevicePathLen,
											   NULL
											   );

	if (!bReturn) 
		return -1;

	strncpy(pDevicePath, DeviceInterfaceDetailData->DevicePath,*pDevicePathLen);
	// note: explicit cast to DWORD for 64-bit compatibility (size_t is 64-bits, but pDevicePath should not exceed a 32-bit string length)
	return (DWORD) strlen(pDevicePath);
}

/**\brief Retrieve the UNIT_SPEC_ID and UNIT_SW_VERSION of the camera
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param pSpec The place to put the spec.
 * \return ERROR_SUCCESS on success, win32 error code otherwise.
 *
 * Valid values are:
 *
 * ulSpecification:
 *
 * 0x00A02D
 *
 * ulVersion:
 *
 * 0x000100 = 1.04
 * 0x000101 = 1.20
 * 0x000102 = 1.30
 */
DWORD
CAMAPI
GetCameraSpecification( PSTR szDeviceName, PCAMERA_SPECIFICATION pSpec)
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;

    DllTrace(DLL_TRACE_ENTER,"Enter GetCameraVersion\r\n");

    hDevice = OpenDevice(szDeviceName, FALSE);

    if (hDevice != INVALID_HANDLE_VALUE) {

        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_CAMERA_SPECIFICATION,
                                 pSpec,
                                 sizeof(CAMERA_SPECIFICATION),
                                 pSpec,
                                 sizeof(CAMERA_SPECIFICATION),
                                 &dwBytesRet,
                                 NULL
                                 );

        if (dwRet) 
		{
            dwRet = ERROR_SUCCESS;
        } else {
            dwRet = GetLastError();
            DllTrace(DLL_TRACE_ERROR, "GetCameraSpecification: IoCtl Error -> 0x%x\r\n", dwRet);
        }

        // free up resources
        CloseHandle(hDevice);
    } else {
        dwRet = GetLastError();
        DllTrace(DLL_TRACE_ERROR, "GetCameraSpecification: Couldn't get Device Handle -> 0x%x\r\n", dwRet);        
    }

    DllTrace(DLL_TRACE_EXIT, "Exit GetCameraSpecification\r\n");
    return(dwRet);
}


/**\brief Retrieve the version of the kernel module.
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param Version Where to put the version information
 * \param bMatch Whether to complain loudly about a mismatch
 * \return ERROR_SUCCESS on success, win32 error code otherwise.
 *
 * This should be used to check for consistenty, but is borken for the time being...
 */
ULONG
CAMAPI
GetCmdrVersion(
    PSTR            szDeviceName,
    PVERSION_DATA   Version,
    BOOL            bMatch
    )
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;

    DllTrace(DLL_TRACE_ENTER,"Enter GetCmdrVersion\r\n");

    bMatch = FALSE;
    hDevice = OpenDevice(szDeviceName, FALSE);

    if (hDevice != INVALID_HANDLE_VALUE) {

        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_CMDR_VERSION,
                                 Version,
                                 sizeof(VERSION_DATA),
                                 Version,
                                 sizeof(VERSION_DATA),
                                 &dwBytesRet,
                                 NULL
                                 );

        if (dwRet) {
            dwRet = ERROR_SUCCESS;
        } else {
            dwRet = GetLastError();
            DllTrace(DLL_TRACE_ERROR, "GetCmdrVersion: IoCtl Error -> 0x%x\r\n", dwRet);
        }

        // free up resources
        CloseHandle(hDevice);
    } else {
        dwRet = GetLastError();
        DllTrace(DLL_TRACE_ERROR, "GetCmdrVersion: Couldn't get Device Handle -> 0x%x\r\n", dwRet);        
    }

    DllTrace(DLL_TRACE_EXIT, "Exit GetCmdrVersion\r\n");
    return(dwRet);
} // GetCmdrVersion

/**\brief Read a quadword from the Camera Register Space
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param ulOffset The offset of the register to read, in bytes
 * \param bytes Pointer to where to place the (four bytes of) data
 * \return 0 on success, -1 or win32 error code otherwise.
 *
 * Note: the offset is not an absolute offset by default, it is a relative offset
 * from the camera's CSR offset, which is maintained now in the device extension.
 *
 * To make it an absolute offset, prepend the offset with 0xF.  For example:
 *  - 0x00000600 will read the register at CSR_OFFSET+ 0x0600 (Typically 0xfffff0f00600)
 *  - 0xF0000600 will simply read the register at 0xfffff0000600
 */
DWORD
CAMAPI
ReadRegister(
	PSTR szDeviceName,
	ULONG ulOffset,
	PUCHAR bytes
	)
{
	HANDLE hDevice;
	DWORD dwRet,bytesRet;
	REGISTER_IOBUF regbuf;
	DllTrace(DLL_TRACE_ENTER,"Enter ReadRegister (%s,0x%08x,%08x)\n",szDeviceName,ulOffset,bytes);
	
	regbuf.ulOffset = ulOffset;
	memset(regbuf.data,0,4);
	hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
		dwRet = DeviceIoControl( hDevice,
			IOCTL_READ_REGISTER,
			&regbuf,
			sizeof(REGISTER_IOBUF),
			&regbuf,
			sizeof(REGISTER_IOBUF),
			&bytesRet,
			NULL
			);
		if(!dwRet)
		{
			dwRet = GetLastError();
		} else {
			DllTrace(DLL_TRACE_CHECK,"ReadRegister: 0x%08x -> [%02x,%02x,%02x,%02x]\n",
				ulOffset,
				regbuf.data[0],
				regbuf.data[1],
				regbuf.data[2],
				regbuf.data[3]
				);
			dwRet = 0;
		}
		CloseHandle(hDevice);
	} else {
		DllTrace(DLL_TRACE_ERROR,"ReadRegister: Couldn't open handle to %s\n",szDeviceName);
		dwRet = -1;
	}
	
	memcpy(bytes,regbuf.data,4);
	DllTrace(DLL_TRACE_EXIT,"Exit ReadRegister (%d)\n",dwRet);
	return dwRet;
}

/**\brief Read a register as an unsigned long
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param ulOffset Same as ReadRegister()
 * \param pData where to put the data;
 * \return same as ReadRegister()
 *
 * The difference provided here is that the incoming bytes are reordered
 * to allow intuitive manipulation on our little-endian machines (the DCAM
 * Spec is Big-Endian).
 */
DWORD
CAMAPI
ReadRegisterUL(
	PSTR szDeviceName,
	ULONG ulOffset,
	PULONG pData
	)
{
	DWORD dwRet;
	unsigned char bytes[4];
	int i;

	dwRet = ReadRegister(szDeviceName,ulOffset,bytes);
	*pData = 0;
	for(i=0; i<4; i++)
	{
		*pData <<= 8;
		*pData += bytes[i];
	}

	return dwRet;
}

/**\brief Write a quadlet to a camera register
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param ulOffset Same as ReadRegister()
 * \param bytes Same as ReadRegister
 * \return Same as ReadRegister();
 */
DWORD
CAMAPI
WriteRegister(
	PSTR szDeviceName,
	ULONG ulOffset,
	PUCHAR bytes
	)
{
	HANDLE hDevice;
	DWORD dwRet,bytesRet;
	REGISTER_IOBUF regbuf;

	DllTrace(DLL_TRACE_ENTER,"Enter WriteRegister (%s,0x%08x,%08x)\n",szDeviceName,ulOffset,bytes);

	regbuf.ulOffset = ulOffset;
	memcpy(regbuf.data,bytes,4);

	hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_WRITE_REGISTER,
                                 &regbuf,
                                 sizeof(REGISTER_IOBUF),
                                 &regbuf,
                                 sizeof(REGISTER_IOBUF),
                                 &bytesRet,
                                 NULL
                                 );
		if(!dwRet)
		{
			dwRet = GetLastError();
		} else {
			DllTrace(DLL_TRACE_CHECK,"WriteRegister: 0x%08x <- [%02x,%02x,%02x,%02x]\n",
				ulOffset,
				regbuf.data[0],
				regbuf.data[1],
				regbuf.data[2],
				regbuf.data[3]
				);
			dwRet = 0;
		}
		CloseHandle(hDevice);
	} else {
		DllTrace(DLL_TRACE_ERROR,"WriteRegister: Couldn't open handle to %s\n",szDeviceName);
		dwRet = -1;
	}

	DllTrace(DLL_TRACE_EXIT,"Exit WriteRegister (%d)\n",dwRet);
	return dwRet;
}

/**\brief Write an unsigned long to a camera register
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param ulOffset Same as ReadRegister()
 * \param data Same as ReadRegisterUL()
 * \return Same as ReadRegisterUL()
 *
 * Again, byteswapping happens here between userland and the camera.
 */
DWORD
CAMAPI
WriteRegisterUL(
	PSTR szDeviceName,
	ULONG ulOffset,
	ULONG data
	)
{
	unsigned char bytes[4];
	int i;
	for(i=0; i<4; i++)
		bytes[i] = (unsigned char)((data >> (8 * (3 - i))) & 0xff);

	return WriteRegister(szDeviceName,ulOffset,bytes);
}

/**\brief Retrieve the Camera Model Name
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param buffer Where to put it.
 * \param buflen How long the buffer is.
 * \return Length of the string on success, -1 on error
 *
 * Retrieves (at most buflen bytes) of the model name from the 
 * device driver and places it into buffer
 */
DWORD
CAMAPI
GetModelName(
	PSTR szDeviceName,
	PSTR buffer,
	ULONG buflen
	)
{
	HANDLE hDevice;
	DWORD dwRet,bytesRet;

	DllTrace(DLL_TRACE_ENTER,"Enter GetModelName (%s)\n",szDeviceName);

	hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_MODEL_NAME,
                                 NULL,
                                 0,
                                 buffer,
                                 buflen,
                                 &bytesRet,
                                 NULL
                                 );
		if(!dwRet)
		{
			DllTrace(DLL_TRACE_ERROR,"GetModelName: IoCtl Failed\n");
			dwRet = -1;
		} else {
			dwRet = bytesRet;
		}
		CloseHandle(hDevice);
	} else {
		DllTrace(DLL_TRACE_ERROR,"GetModelName: Couldn't open handle to %s\n",szDeviceName);
		dwRet = -1;
	}

	DllTrace(DLL_TRACE_EXIT,"Exit GetModelName (%d)\n",dwRet);
	return dwRet;
}

/**\brief Retrieve the Camera Vendor Name
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param buffer Where to put it.
 * \param buflen How long the buffer is.
 * \return Length of the string on success, -1 on error
 *
 * Retrieves (at most buflen bytes) of the vendor name from the 
 * device driver and places it into buffer
 */
DWORD
CAMAPI
GetVendorName(
	PSTR szDeviceName,
	PSTR buffer,
	ULONG buflen
	)
{
	HANDLE hDevice;
	DWORD dwRet,bytesRet;

	DllTrace(DLL_TRACE_ENTER,"Enter GetVendorName (%s)\n",szDeviceName);

	hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_VENDOR_NAME,
                                 NULL,
                                 0,
                                 buffer,
                                 buflen,
                                 &bytesRet,
                                 NULL
                                 );
		if(!dwRet)
		{
			DllTrace(DLL_TRACE_ERROR,"GetVendorName: IoCtl Failed\n");
			dwRet = -1;
		} else {
			dwRet = bytesRet;
		}
		CloseHandle(hDevice);
	} else {
		DllTrace(DLL_TRACE_ERROR,"GetVendorName: Couldn't open handle to %s\n",szDeviceName);
		dwRet = -1;
	}

	DllTrace(DLL_TRACE_EXIT,"Exit GetVendorName (%d)\n",dwRet);
	return dwRet;
}

/**\brief Retrieve the Camera Unique ID
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param pliUniqueID Where to put it.
 * \return 0 on success, -1 on error
 */
DWORD
CAMAPI
GetUniqueID(
	PSTR szDeviceName,
	PLARGE_INTEGER pliUniqueID
	)
{
	HANDLE hDevice;
	DWORD dwRet,bytesRet;

	DllTrace(DLL_TRACE_ENTER,"Enter GetUniqueID (%s)\n",szDeviceName);

	hDevice = OpenDevice(szDeviceName,FALSE);
	if(hDevice != INVALID_HANDLE_VALUE)
	{
        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_CAMERA_UNIQUE_ID,
                                 NULL,
                                 0,
                                 pliUniqueID,
                                 sizeof(LARGE_INTEGER),
                                 &bytesRet,
                                 NULL
                                 );
		if(!dwRet)
		{
			DllTrace(DLL_TRACE_ERROR,"GetUniqueID: IoCtl Failed\n");
			dwRet = GetLastError();
		} else {
			dwRet = 0;
		}
		CloseHandle(hDevice);
	} else {
		DllTrace(DLL_TRACE_ERROR,"GetUniqueID: Couldn't open handle to %s\n",szDeviceName);
		dwRet = GetLastError();
	}

	DllTrace(DLL_TRACE_EXIT,"Exit GetUniqueID (%d)\n",dwRet);
	return dwRet;
}

/**\brief Create a device handle to a camera object
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param bOverLapped Whether to configure the handle for non-blocking I/O
 * \return Camera Handle on success, INVALID_HANDLE_VALUE on error
 *
 * This just wraps the complexity of CreateFile and makes sure the right thing happens
 */
HANDLE
CAMAPI
OpenDevice(
    LPCSTR    szDeviceName,
    BOOL    bOverLapped
    )
{
    HANDLE  hDevice;

    if (bOverLapped) {

        hDevice = CreateFile( szDeviceName,
                              GENERIC_WRITE | GENERIC_READ,
                              FILE_SHARE_WRITE | FILE_SHARE_READ,
                              NULL,
                              OPEN_EXISTING,
                              FILE_FLAG_OVERLAPPED,
                              NULL
                              );
    } else {
    
        hDevice = CreateFile( szDeviceName,
                              GENERIC_WRITE | GENERIC_READ,
                              FILE_SHARE_WRITE | FILE_SHARE_READ,
                              NULL,
                              OPEN_EXISTING,
                              0,
                              NULL
                              );
    }

	if (hDevice == INVALID_HANDLE_VALUE) {
		DllTrace(DLL_TRACE_ERROR,"OpenDevice: Error getting handle for %s\r\n",szDeviceName);
    }

    return(hDevice);
} // OpenDevice


/* \brief Retrieve the maximum transmit speed of the camera
 * \ingroup capi
 * \param szDeviceName The full pathname of the device 
 * \param GetMaxSpeedBetweenDevices
 * \return ERROR_SUCCESS on success, other error code on error
 *
 * The max speed between devices is a function of the bus topology,
 * not necessarily the camera.
 *
 * cbaker: deprecated at 6.4.6

ULONG
CAMAPI
GetMaxSpeedBetweenDevices(
    PSTR                            szDeviceName,
    PGET_MAX_SPEED_BETWEEN_DEVICES  GetMaxSpeedBetweenDevices
    )
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;
    ULONG       i;

    DllTrace(DLL_TRACE_ENTER,"ENTER GetMaxSpeedBetweenDevices\n");
    DllTrace(DLL_TRACE_VERBOSE, "fulFlags = 0x%x\r\n", GetMaxSpeedBetweenDevices->fulFlags);
    DllTrace(DLL_TRACE_VERBOSE, "ulNumberOfDestinations = 0x%x\r\n", GetMaxSpeedBetweenDevices->ulNumberOfDestinations);

    for (i=0; i<GetMaxSpeedBetweenDevices->ulNumberOfDestinations; i++) {

        DllTrace(DLL_TRACE_VERBOSE, "hDestinationDeviceObjects[%d] = 0x%x\r\n", i, 
            GetMaxSpeedBetweenDevices->hDestinationDeviceObjects[i]);
    }

    hDevice = OpenDevice(szDeviceName, FALSE);

    if (hDevice != INVALID_HANDLE_VALUE) {

        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_MAX_SPEED_BETWEEN_DEVICES,
                                 GetMaxSpeedBetweenDevices,
                                 sizeof(GET_MAX_SPEED_BETWEEN_DEVICES),
                                 GetMaxSpeedBetweenDevices,
                                 sizeof(GET_MAX_SPEED_BETWEEN_DEVICES),
                                 &dwBytesRet,
                                 NULL
                                 );

        if (dwRet) {

            dwRet = ERROR_SUCCESS;

            DllTrace(DLL_TRACE_VERBOSE, "fulSpeed = 0x%x\r\n", GetMaxSpeedBetweenDevices->fulSpeed);
        }
        else {

            dwRet = GetLastError();
            DllTrace(DLL_TRACE_ERROR, "Error = 0x%x\r\n", dwRet);
        }

        // free up resources
        CloseHandle(hDevice);
    }
    else {

        dwRet = GetLastError();
        DllTrace(DLL_TRACE_ERROR, "Error = 0x%x\r\n", dwRet);        
    }
    
    DllTrace(DLL_TRACE_ENTER,"EXIT GetMaxSpeedBetweenDevices (%d)\n",dwRet);
    return(dwRet);
} // GetMaxSpeedBetweenDevices

*/

ULONG
CAMAPI
GetMaxIsochSpeed(
    PSTR szDeviceName,
    PULONG pfulSpeed
    )
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;

    DllTrace(DLL_TRACE_ENTER,"ENTER GetMaxIsochSpeed\n");
    DllTrace(DLL_TRACE_VERBOSE, "pfulSpeed @ %p \n", pfulSpeed);

    hDevice = OpenDevice(szDeviceName, FALSE);

    if (hDevice != INVALID_HANDLE_VALUE) {

        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_MAX_ISOCH_SPEED,
                                 pfulSpeed,
                                 sizeof(ULONG),
                                 pfulSpeed,
                                 sizeof(ULONG),
                                 &dwBytesRet,
                                 NULL
                                 );

        if (dwRet) {

            dwRet = ERROR_SUCCESS;
            DllTrace(DLL_TRACE_VERBOSE, "fulSpeed = 0x%x\r\n", *pfulSpeed);
        }
        else {

            dwRet = GetLastError();
            DllTrace(DLL_TRACE_ERROR, "Error = 0x%x\r\n", dwRet);
        }

        // free up resources
        CloseHandle(hDevice);
    }
    else {

        dwRet = GetLastError();
        DllTrace(DLL_TRACE_ERROR, "Error = 0x%x\r\n", dwRet);        
    }
    
    DllTrace(DLL_TRACE_ENTER,"EXIT GetMaxIsochSpeed (%d)\n",dwRet);
    return(dwRet);
}


DWORD
CAMAPI
t1394_GetHostDmaCapabilities(
	LPCSTR szDeviceName,
	PULONG pulCapabilitiesMask,
	PULARGE_INTEGER puliMaxBufferSize
	)
{
    HANDLE      hDevice;
    DWORD       dwRet, dwBytesRet;
	  unsigned char _buf[sizeof(GET_LOCAL_HOST_INFORMATION[1]) + 2 * sizeof(ULARGE_INTEGER)];
	  PGET_LOCAL_HOST_INFORMATION pLHI = (PGET_LOCAL_HOST_INFORMATION)(_buf);

    PULARGE_INTEGER puliTmp = (PULARGE_INTEGER)(pLHI->Information);
    PULONG pulTmp = (PULONG)(pLHI->Information);

    DllTrace(DLL_TRACE_ENTER,"ENTER GetHostDmaCapabilities\n");
    DllTrace(DLL_TRACE_VERBOSE, "pulCapabilitiesMask @ %p \n", pulCapabilitiesMask);
    DllTrace(DLL_TRACE_VERBOSE, "puliMaxBufferSize @ %p \n", puliMaxBufferSize);

    hDevice = OpenDevice(szDeviceName, FALSE);

    if (hDevice != INVALID_HANDLE_VALUE) {
		
        pLHI->nLevel = 7;
        pLHI->ulBufferSize = sizeof(_buf);
        pLHI->Status = 0;
        puliTmp[0].QuadPart = 0;
        puliTmp[1].QuadPart = 0;

        dwRet = DeviceIoControl( hDevice,
                                 IOCTL_GET_LOCAL_HOST_INFORMATION,
                                 _buf,
                                 sizeof(_buf),
                                 _buf,
                                 sizeof(_buf),
                                 &dwBytesRet,
                                 NULL
                                 );

        if (dwRet) {
            dwRet = ERROR_SUCCESS;
        } else {
            dwRet = GetLastError();
            DllTrace(DLL_TRACE_ERROR, "Error = 0x%x\r\n", dwRet);
        }

        DllTrace(DLL_TRACE_VERBOSE,"Host reports capabilities: %016I64x, max buffer size: %016I64x\n",puliTmp[0],puliTmp[1]);

        // copy data from Information buffer
        // note this requires knowledge of the GET_LOCAL_HOST_INFO_7 structure
        // which is comparatively deep juju here in userland
        // it is basically:
        // {
        //    ULONG capabilities;
        //    ULARGE_INTEGER maxBufferSize;
        // }
        // but structure alignment on 32 vs. 64-bit makes this tricky
        if(puliMaxBufferSize != NULL)
        {
          *puliMaxBufferSize = puliTmp[1];
        }

        if(pulCapabilitiesMask != NULL)
        {
          *pulCapabilitiesMask = pulTmp[0];
        }
        // free up resources
        CloseHandle(hDevice);
    }
    else {

        dwRet = GetLastError();
        DllTrace(DLL_TRACE_ERROR, "Error = 0x%x\r\n", dwRet);        
    }
    
    DllTrace(DLL_TRACE_ENTER,"EXIT GetHostDmaCapabilities (%d)\n",dwRet);
    return(dwRet);
}


/**\brief Convert a win32 SPEED_FLAG to a DCAM index
 * \ingroup capi
 * \param fulFlags The flag to convert
 * \return non-negative index on success, -1 on error
 * 
 * I know this is just a bit shift, but better safe than sorry...
 */
LONG CAMAPI SpeedFlagToIndex(ULONG fulFlags)
{
  switch(fulFlags)
  {
  case SPEED_FLAGS_100:
    return 0;
  case SPEED_FLAGS_200:
    return 1;
  case SPEED_FLAGS_400:
    return 2;
  case SPEED_FLAGS_800:
    return 3;
  case SPEED_FLAGS_1600:
    return 4;
  case SPEED_FLAGS_3200:
    return 5;
  default:
    return -1;
  }
}

/**\brief Get a registry handle to the camera settings group
 * \ingroup capi
 * \param subkey The sub-key to open (NULL implies the camera settings root)
 * \param dwOptions Registry Key options, see homonymous parameter to RegOpenKeyEx
 * \param samDesired Desired access rights, again see documentation for RegOpenKeyEx
 * \return Valid HKEY on success, NULL on failure (check GetLastError())
 * 
 * The objective here is to encapsulate several critical issues:
 * - That camera settings are stored at HKLM/Software/CMU/1394Camera
 * - That this registry path is created by the installer, with appropriate access rights for "all users" (important on Vista and later)
 * - That we have to wrestle with the SysWOW64 redirection stuff on 64-bit windows
 */
HKEY
CAMAPI
OpenCameraSettingsKey(LPCSTR subkey, DWORD dwOptions, REGSAM samDesired)
{
	char buf[512];
	const char *camSettingsRoot = "Software\\CMU\\1394Camera";
	HKEY hKey = NULL;
	LRESULT lRes;
// Only compile with WINNT >= 0x501 if you are willing to give up Win2k support
// The distributed version only does so for the 64-bit DLL's, thus allowing
// 32-bit version of the DLL to remain compatible with Win2k
#if (_WIN32_WINNT >= 0x501)
	  samDesired |= KEY_WOW64_32KEY; // keep everything in "emulated" 32-bit registry on 64-bit systems
#endif

	if(subkey != NULL)
	{
		StringCbPrintf(buf,sizeof(buf),"%s\\%s",camSettingsRoot,subkey);
	} else {
		StringCbPrintf(buf,sizeof(buf),"%s",camSettingsRoot);
	}

	lRes = RegOpenKeyEx(HKEY_LOCAL_MACHINE,buf,dwOptions,samDesired,&hKey);
	if(lRes != ERROR_SUCCESS)
	{
		DllTrace(DLL_TRACE_ERROR,"OpenCameraSettingsKey: Failed to Open HKLM\\%s: (%ld)%s",
			buf,lRes,WinStrError((DWORD)lRes));
		hKey = NULL;
	} // fall through

	return hKey;
}
