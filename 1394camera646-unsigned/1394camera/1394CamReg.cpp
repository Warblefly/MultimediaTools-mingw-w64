/**
 * \file 1394CamReg.cpp
 * \brief Implements storage and retrieval of camera settings to/from the system registry
 * \ingroup camreg
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
#include <strsafe.h>

/** \defgroup camreg Registry Interface
 *  \ingroup camcore
 *  \brief Store and retrieve camera settings from teh system registry.
 *
 * These functions allow the user to store a camera configuration to the system registry
 */

/**\brief Load a named camera configuration from the system registry
 * \ingroup camreg
 * \param pname NULL-terminated simple string ("Indoors", "Outdoors", etc.) that delimits the settings to load
 * \return
 * - CAM_SUCCESS: All is well
 * - CAM ERROR: something went Awry with a syscall, check GetLastError()
 */
int C1394Camera::RegLoadSettings(const char *pname)
{
	HKEY  hKey;
	DWORD dwRet,dwFoo,dwSize,dwType = REG_DWORD;
	char buf[256];
	unsigned long mask;
	int i;
	
#define REG_READ(name){\
	dwFoo = 0;\
	dwType = 0;\
	dwSize = sizeof(DWORD);\
	dwRet = RegQueryValueEx(hKey,name,0,&dwType,(LPBYTE)&dwFoo,&dwSize);\
	if(dwRet != ERROR_SUCCESS)\
	{\
	DllTrace(DLL_TRACE_ERROR,\
	"RegLoadSettings: error %d querying registry key for %s\n",\
	dwRet,name);\
	return CAM_ERROR;\
  }}

	StringCbPrintf(buf,sizeof(buf),"Software\\CMU\\1394Camera\\%08x%08x\\CameraSettings\\%s",
		           m_UniqueID.HighPart,m_UniqueID.LowPart,pname);
	
	DllTrace(DLL_TRACE_CHECK,"RegLoadSettings: Trying to open \"%s\" under camera settings key\n",buf);

	if((hKey = OpenCameraSettingsKey(buf,0,KEY_READ)) != NULL)
	{
		REG_READ("Format");
		SetVideoFormat(dwFoo);
		REG_READ("Mode");
		SetVideoMode(dwFoo);
		REG_READ("Rate");
		SetVideoFrameRate(dwFoo);
		
		// Feature_Hi_Inq
		ReadQuadlet(0x404, &mask);
		for(i = 0; i<32; i++)
		{
			if(mask & (0x80000000>>i))
			{
				REG_READ(dc1394GetFeatureName((CAMERA_FEATURE)i));
				WriteQuadlet(FEATURE_STATUS_INDEX + dc1394GetFeatureOffset((CAMERA_FEATURE)i),dwFoo);
			}
		}
		
		// Feature_Lo_Inq
		ReadQuadlet(0x408, &mask);
		for(i = 0; i<32; i++)
		{
			if(mask & (0x80000000>>i))
			{
				REG_READ(dc1394GetFeatureName((CAMERA_FEATURE)(i+32)));
				WriteQuadlet(FEATURE_STATUS_INDEX + dc1394GetFeatureOffset((CAMERA_FEATURE)(i+32)),dwFoo);
			}
		}
		// make sure the controls are kept up-to-date
		RefreshControlRegisters();
		RegCloseKey(hKey);
	} else {
		DllTrace(DLL_TRACE_ERROR,"RegLoadSettings: Error opening key %s: %s\n",buf,StrLastError());
		return CAM_ERROR;
	}
	return CAM_SUCCESS;
}

/**\brief Write the current camera configuration to the system registry under a given name
 * \ingroup camreg
 * \param pname NULL-terminated simple string ("Indoors", "Outdoors", etc.) that delimits the settings to load
 * \return
 * - CAM_SUCCESS: All is well
 * - CAM ERROR: something went Awry with a syscall, check GetLastError()
 */
int C1394Camera::RegSaveSettings(const char *pname)
{
	HKEY  hKey,hCameraSettingsKey;
	DWORD dwRet,dwDisposition,dwFoo,dwSize = sizeof(DWORD),dwType = REG_DWORD;
	LRESULT lRetval = 0;
	char buf[256];
	unsigned long mask;
	int i;

#define REG_WRITE(name,val){\
		dwFoo = val;\
		dwRet = RegSetValueEx(hKey,name,0,REG_DWORD,(LPBYTE)&dwFoo,dwSize);\
		if(dwRet != ERROR_SUCCESS)\
			DllTrace(DLL_TRACE_ERROR,\
			"RegSaveSettings: error %d setting registry key for %s\n",\
			dwRet,name);}\

	
	if((hCameraSettingsKey = OpenCameraSettingsKey(NULL,0,KEY_ALL_ACCESS)) != NULL)
	{
		StringCbPrintf(buf,sizeof(buf),"%08x%08x\\CameraSettings\\%s",m_UniqueID.HighPart,m_UniqueID.LowPart,pname);
		DllTrace(DLL_TRACE_CHECK,"RegSaveSettings: Trying to open \"%s\" inder the camera settings key\n",buf);
	
		dwRet = RegCreateKeyEx(
			hCameraSettingsKey,
			buf,
			0,
			NULL,
			REG_OPTION_NON_VOLATILE,
			KEY_ALL_ACCESS,
			NULL,
			&hKey,
			&dwDisposition);
	
		if(dwRet == ERROR_SUCCESS)
		{
			REG_WRITE("Format",m_videoFormat);
			REG_WRITE("Mode",m_videoMode);
			REG_WRITE("Rate",m_videoFrameRate);
			
			// Feature_Hi_Inq
			ReadQuadlet(0x404, &mask);
			for(i = 0; i<32; i++)
			{
				if(mask & (0x80000000>>i))
				{
					ReadQuadlet(FEATURE_STATUS_INDEX + dc1394GetFeatureOffset((CAMERA_FEATURE)i),&dwFoo);
					REG_WRITE(dc1394GetFeatureName((CAMERA_FEATURE)i),dwFoo);
				}
			}
			
			// Feature_Lo_Inq
			ReadQuadlet(0x408, &mask);
			for(i = 0; i<32; i++)
			{
				if(mask & (0x80000000>>i))
				{
					ReadQuadlet(FEATURE_STATUS_INDEX + dc1394GetFeatureOffset((CAMERA_FEATURE)(i+32)),&dwFoo);
					REG_WRITE(dc1394GetFeatureName((CAMERA_FEATURE)(i+32)),dwFoo);
				}
			}
			
			RegCloseKey(hKey);
		} else {
			DllTrace(DLL_TRACE_ERROR,"RegSaveSettings: Error %d opening key %s (%s)\n",dwRet,buf,StrLastError());
			return CAM_ERROR;
		}
		RegCloseKey(hCameraSettingsKey);
	} else {
		DllTrace(DLL_TRACE_ERROR,"RegSaveSettings: Error opening camera settings key: %s",StrLastError());
		return CAM_ERROR;
	}
	
	return CAM_SUCCESS;
}

/*********************
 * TO BE IMPLEMENTED *
 *********************/
/*
int RegGetNumSettings()
{
	//RegQueryInfoKey is your friend here
	return 0;
}

int RegEnumSettings(int index, char *buf, int buflen)
{
	// check index
	// friends are RegEnumKeyEx, RegQueryInfoKey
	return 0;
}
*/