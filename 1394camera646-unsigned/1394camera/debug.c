/**\file debug.c 
 * \brief Debug Tracing 
 * \ingroup debug
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
#include <strsafe.h>
#include "resource.h"

/**\defgroup debug Debug Tracing
 * \brief Provides runtime-configurable tracing mechanisms for DLL functions
 */

static int DllTraceLevel = DLL_TRACE_WARNING;

static const char *strMiniLevel(int level)
{
	switch(level)
	{
	case DLL_TRACE_ALWAYS:  return "NOTICE";
	case DLL_TRACE_NONE:    return " NONE ";
	case DLL_TRACE_ERROR:   return "ERROR ";
	case DLL_TRACE_WARNING: return " WARN ";
	case DLL_TRACE_CHECK:   return "CHECK ";
	case 3:                 return " CHK3 ";
	case 4:                 return " CHK4 ";
	case DLL_TRACE_ENTER:   return "ENTER ";
	case DLL_TRACE_EXIT:    return " EXIT ";
	case 7:                 return " DBG7 ";
	case 8:                 return " DBG8 ";
	case 9:                 return " DBG9 ";
	case DLL_TRACE_VERBOSE: return "DEBUG ";
	default:                return "!UNKN!";
	}
}

/**\brief Set the DLL trace level 
 * \ingroup debug
 */
void CAMAPI SetDllTraceLevel(int nlevel)
{
	DllTraceLevel = nlevel;
}

/**\brief printf-style debug tracing to the windows debug console 
 * \ingroup debug
 */
void _DllTrace(int nlevel,const char *format, ...)
{
	if(nlevel > DllTraceLevel)
	{
		return;
	} else {
	    char buf[2048] = "1394Camera.dll: ";
	    size_t presize = 0;
		va_list ap;

		StringCbPrintf(buf,2048,"1394Camera.dll: %s : ",strMiniLevel(nlevel));
		StringCbLength(buf,2048,&presize);

		va_start(ap, format);

		StringCbVPrintf(buf + presize, 2048 - presize, format, ap);
		OutputDebugStringA(buf);

		va_end(ap);
	}
}

void _DllTraceEx(const char *file, int line, int nlevel,const char *format, ...)
{
	if(nlevel > DllTraceLevel)
	{
		return;
	} else {
		const char *trimmedfile = (file[0] == '.' ? file + 2 : file);
		char buf[2048];
	    size_t presize = 0;
		va_list ap;

		StringCbPrintf(buf,2048,"1394Camera.dll: %s : %15s:%d : ",strMiniLevel(nlevel),trimmedfile,line);
		StringCbLength(buf,2048,&presize);

		va_start(ap, format);
		StringCbVPrintf(buf + presize, 2048 - presize, format, ap);
		va_end(ap);

		OutputDebugStringA(buf);
	}
}

/**\brief Encapsulate the setting of the driver trace level */
static int SetSysTraceLevel(int nlevel)
{
	int ret = -1;
	char buf[512];
	DWORD dwLen = sizeof(buf);
	HDEVINFO hDevInfo;
	if((hDevInfo = t1394CmdrGetDeviceList()) != INVALID_HANDLE_VALUE);
		if(t1394CmdrGetDevicePath(hDevInfo,0,buf,&dwLen) > 0)
		{
			ret = SetCmdrTraceLevel(buf,nlevel);
			SetupDiDestroyDeviceInfoList(hDevInfo);
		}

	return ret;
}

/**\brief Encapsulate the retrieval of the driver trace level */
static int GetSysTraceLevel(int *nlevel)
{
	int ret = -1;
	char buf[512];
	DWORD dwLen = sizeof(buf);
	HDEVINFO hDevInfo;
	*nlevel = -1;
	if((hDevInfo = t1394CmdrGetDeviceList()) != INVALID_HANDLE_VALUE);
		if(t1394CmdrGetDevicePath(hDevInfo,0,buf,&dwLen) > 0)
		{
			ret = GetCmdrTraceLevel(buf,nlevel);
			SetupDiDestroyDeviceInfoList(hDevInfo);
		}

	return ret;
}

/**\brief Gah! the windows form of strerror is so ugly...
 * \param dwError the error number
 * \ingroup debug
 * \return pointer to a static buffer holding the human-readable error string (not thread-safe)
 */

const char *WinStrError(DWORD dwError)
{
	static char buf[512];
	FormatMessage( 
		FORMAT_MESSAGE_FROM_SYSTEM | 
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		dwError,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &buf,
		512,
		NULL );
    return buf;
}

/**\brief WinStrError(GetLastError())
 */
const char *StrLastError()
{
	return WinStrError(GetLastError());
}

/**\brief convert DLL trace level to human-readable string, used in DebugDialog()
 * \param nLevel The level to convert
 * \return static null-terminated C string
 */
const char *StrDllTraceLevel(int nLevel)
{
	switch(nLevel)
	{
	case DLL_TRACE_NONE: return "None/Disabled";
	case DLL_TRACE_ERROR: return "Critical Errors";
	case DLL_TRACE_WARNING: return "Non-critical Errors/Warnings";
	case DLL_TRACE_CHECK: return "Intermediate Checkpoints";
	case 3: return "Unspecified medium checkpoints";
	case 4: return "Unspecified minor checkpoints";
	case DLL_TRACE_ENTER: return "Function/Method Entry Points";
	case DLL_TRACE_EXIT: return "Function/Method Exit Points";
	case 7: return "Unspecified minor verbosity";
	case 8: return "Unspecified medium verbosity";
	case 9: return "Unspecified major verbosity";
	case DLL_TRACE_VERBOSE: return "Complete Verbosity/Everything";
	default:
		return "Unknown/Unspecified DLL Trace Level > 10";
	}
}

/**\brief Window procedure for the debug settings dialog
 * \ingroup dialogs
 * \param hWndDlg The dialog window handle
 * \param uMsg The message to process
 * \param wParam the window parameter
 * \param lParam the (often unused) generic long parameter
 * 
 * Responsibilities:
 *  - catch SCROLL messages and feed them back to the static texts
 *  - save the settings to the registry if necessary
 */
static HRESULT CALLBACK DebugDlgProc(
  HWND hWndDlg,  // handle to dialog box
  UINT uMsg,     // message
  WPARAM wParam, // first message parameter
  LPARAM lParam  // second message parameter
)
{
	HWND hWndItem;
	DWORD dwPos;
	HKEY myKey = NULL;
	DWORD dwRet,dwSize = sizeof(DWORD);

	switch(uMsg)
	{
	case WM_INITDIALOG:
		// set the sliders to range from 0-101
		hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_DLL);
		SendMessage(hWndItem,TBM_SETRANGE,FALSE,MAKELONG(0,11));
		SendMessage(hWndItem,TBM_SETPOS,TRUE,DllTraceLevel + 1);
		SetDlgItemText(hWndDlg,IDC_DLL_DESCRIPTION,StrDllTraceLevel(DllTraceLevel));

		GetSysTraceLevel(&dwPos);
		hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_SYS);
		SendMessage(hWndItem,TBM_SETRANGE,FALSE,MAKELONG(0,11));
		SendMessage(hWndItem,TBM_SETPOS,TRUE,dwPos + 1);
		SetDlgItemInt(hWndDlg,IDC_SYS_DESCRIPTION,dwPos,TRUE);

		return TRUE;
		break;
	case WM_HSCROLL:
	case WM_VSCROLL:
		// use the scroll messages to provide feedback about the tracelevel
		// these may eventually be strings, but leave them as numbers for now
		hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_DLL);
		dwPos = (DWORD)SendMessage(hWndItem,TBM_GETPOS,0,0);
		SetDlgItemText(hWndDlg,IDC_DLL_DESCRIPTION,StrDllTraceLevel(dwPos - 1));
		hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_SYS);
		dwPos = (DWORD)SendMessage(hWndItem,TBM_GETPOS,0,0);
		SetDlgItemInt(hWndDlg,IDC_SYS_DESCRIPTION,dwPos - 1,TRUE);
		return TRUE;
		break;
	case WM_COMMAND:
		switch(LOWORD(wParam))
		{
		case IDOK:
			hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_DLL);
			DllTraceLevel = (int)SendMessage(hWndItem,TBM_GETPOS,0,0) - 1;
			hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_SYS);
			dwPos = (DWORD)SendMessage(hWndItem,TBM_GETPOS,0,0) - 1;
			SetSysTraceLevel(dwPos);
			if(BST_CHECKED == IsDlgButtonChecked(hWndDlg,IDC_CHECK_DEFAULT))
			{
				// this is where we write the data into the registry
				if((myKey = OpenCameraSettingsKey(NULL,0,KEY_ALL_ACCESS)) != NULL)
				{
					dwRet = RegSetValueEx(myKey,"DllTraceLevel",0,REG_DWORD,(LPBYTE)&DllTraceLevel,dwSize);
					if(dwRet != ERROR_SUCCESS)
						DllTrace(DLL_TRACE_ERROR,"DebugDlgProc: failed to set DllTraceLevel registry key (%d)\n",dwRet);

					dwRet = RegSetValueEx(myKey,"SysTraceLevel",0,REG_DWORD,(LPBYTE)&dwPos,dwSize);
					if(dwRet != ERROR_SUCCESS)
						DllTrace(DLL_TRACE_ERROR,"DebugDlgProc: failed to set SysTraceLevel registry key (%d)\n",dwRet);

					RegCloseKey(myKey);
				} else {
					DllTrace(DLL_TRACE_ERROR,"DebugDlgProc: Failed to open camera settings key: %s",StrLastError());
				}
			}
		case IDCANCEL:
			EndDialog(hWndDlg,0);
			return TRUE;
			break;
		}
		break;
	}
	return FALSE;
}

/**\brief Display a Modal dialog that allows the configuration of tracelevels
 * \ingroup dialogs
 * \param hWndParent The parent window for the dialog.
 * 
 * Note: this is a modal dialog, which means it	will block until you click "OK"
 */
void CAMAPI CameraDebugDialog(HWND hWndParent)
{
	// we need basic common controls to use the trackbar class
	InitCommonControls();
	DialogBox(g_hInstDLL,MAKEINTRESOURCE(IDD_DEBUG),hWndParent,(DLGPROC)(DebugDlgProc));
}
