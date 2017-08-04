/**\file ControlDialog.cpp
 * \brief Source for CameraControlDialog and associated functions
 * \ingroup dialogs
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
#include "ControlDialog.h"
#include "1394CameraControlStrobe.h"
#include "resource.h"

/**\defgroup dialogs Utility Dialogs
 * \brief A collection of modal and modeless dialogs for interfacing to C1394Camera elements.
 *
 * The Utility Dialogs are provided as part of the DLL instead of the demo app to make them more
 * used in other applications.  They are written against the straight win32 API and thus make no
 * unnecessary assumptions (and thus force hairy linkage) about the operating environment (MFC, .NET, etc).
 */

LRESULT CALLBACK ControlDialogWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

/**\brief Display a modeless dialog to all the C1394CameraControl members of a C1394Camera class
 * \ingroup dialogs
 * \param hWndParent The parent window for this instance
 * \param pCamera Pointer to the camera to be controlled
 * \param bLoadDefaultView If TRUE, load the default control selections from the registry
 * \return HWND to the control window, NULL on error.  GetLastError() should be handy.
 *
 * Note that this is modeless and thus allows multiple control windows to be 
 * open for multiple cameras.  Also note that you must provide your own message pump.
 */
HWND
CAMAPI
CameraControlDialog(
	HWND hWndParent,
	C1394Camera *pCamera,
	BOOL bLoadDefaultView
	)
{
	HWND hWnd;
	WNDCLASSEX wcex;

	DllTrace(DLL_TRACE_ENTER,"ENTER CameraControlDialog(%08x,%08x)\n",
		hWndParent,
		pCamera);
	// we need common controls for the slider class to work
	InitCommonControls();

	// register the window class
	ZeroMemory(&wcex,sizeof(WNDCLASSEX));

	wcex.cbSize = sizeof(WNDCLASSEX); 
	wcex.style			= CS_HREDRAW | CS_VREDRAW;
	wcex.lpfnWndProc	= (WNDPROC)ControlDialogWndProc;
	wcex.cbClsExtra		= 0;
	wcex.cbWndExtra		= 0;
	wcex.hInstance		= g_hInstDLL;
	wcex.hIcon			= LoadIcon(g_hInstDLL, (LPCTSTR)IDR_ICON1);
	wcex.hIconSm		= LoadIcon(g_hInstDLL, (LPCTSTR)IDR_ICON1);
	wcex.hCursor		= LoadCursor(NULL, IDC_ARROW);
	wcex.hbrBackground	= (HBRUSH)(COLOR_3DFACE+1);
	wcex.lpszMenuName	= (LPCSTR)IDR_CONTROL_MENU;
	wcex.lpszClassName	= "1394 Control Panes Dialog Class";

	RegisterClassEx(&wcex);

	// Init the instance
	hWnd = InitControlDialogInstance (g_hInstDLL, hWndParent, pCamera);

	if(bLoadDefaultView)
	{
		DllTrace(DLL_TRACE_CHECK,"CameraControlDialog: Loading Default View\n");
		SendMessage(hWnd,WM_COMMAND,MAKELONG(ID_FILE_LOADDEFAULTVIEW,0),0);
	}

	DllTrace(DLL_TRACE_EXIT,"EXIT CameraControlDialog(%08x)\n",hWnd);

	return hWnd;
}

/**\brief Window procedure for the control dialog
 * \ingroup dialogs
 * \param hWnd The dialog window handle
 * \param message The message to process
 * \param wParam the window parameter
 * \param lParam the (often unused) generic long parameter
 * 
 * Duties:
 *  - menu items
 *     - load/save view settings to from/to registry
 *     - close the window
 *     - view menu toggles panes on and off
 *  - messages
 *     - paint: nothing (for now)
 *     - destroy: localfree the window extension structure
 *     - hscroll: scroll the panes back and forth
 */
LRESULT CALLBACK ControlDialogWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	int wmId, wmEvent;
	int i;
	PAINTSTRUCT ps;
	HDC hdc;
	HKEY  hKey,hCSK;
	DWORD dwRet,dwDisposition,dwFoo,dwSize = sizeof(DWORD),dwType = REG_DWORD;
	SCROLLINFO si;
	PCONTROL_WINDOW_EXTENSION pExt = (PCONTROL_WINDOW_EXTENSION) GetWindowLongPtr(hWnd,GWLP_USERDATA);
	PCONTROL_PANE_EXTENSION pPaneExt;
	C1394Camera *pCam;
	C1394CameraControl *pControl;
	char buf[256];
	LRESULT lRetval = 0;
	HWND hWndChild;
	MSG msg;
	LARGE_INTEGER UniqueID;
	
	DllTrace(DLL_TRACE_ENTER,"ControlDialogProc(%08x,%08x,%08x,%08x)\n",
		hWnd,
		message,
		wParam,
		lParam);
	
	/* to maintain reasonable encapsulation, we need to translate our own accelerator messages */
	if(pExt)
	{
		msg.hwnd = hWnd;
		msg.message = message;
		msg.wParam = wParam;
		msg.lParam = lParam;
		TranslateAccelerator(hWnd,pExt->hAccel,&msg);
		message = msg.message;
		lParam = msg.lParam;
		wParam = msg.wParam;
	}
	
	switch (message) 
	{
	case WM_COMMAND:
		wmId    = LOWORD(wParam); 
		wmEvent = HIWORD(wParam); 
		// Parse the menu selections:
		switch (wmId)
		{
		case ID_CONTROL_POLLALL:
			for(i=0; i<pExt->nPanes; i++)
			{
				if(pExt->PaneState[i])
					SendDlgItemMessage(hWnd,ID_FIRST_CONTROL_PANE + i,WM_COMMAND,MAKELONG(IDC_BUT_POLL,0),0);
			}
			break;
		case ID_FILE_LOADDEFAULTVIEW:
			pCam = pExt->pCamera;
			if(pCam)
			{
				if((hCSK = OpenCameraSettingsKey(NULL,0,KEY_ALL_ACCESS)) != NULL)
				{
					pCam->GetCameraUniqueID(&UniqueID);
					StringCbPrintf(buf,sizeof(buf),"%08x%08x\\ControlPanes\\DefaultView",UniqueID.HighPart,UniqueID.LowPart);
					dwRet = RegCreateKeyEx(hCSK,buf,0,NULL,REG_OPTION_NON_VOLATILE,KEY_ALL_ACCESS,NULL,&hKey,&dwDisposition);
					if(dwRet == ERROR_SUCCESS)
					{
						if(dwDisposition == REG_CREATED_NEW_KEY)
						{
							// we made a new key, so we need to write the initial settings
							for(i=0; i<pExt->nPanes; i++)
							{
								hWndChild = GetDlgItem(hWnd,ID_FIRST_CONTROL_PANE + i);
								pPaneExt = (PCONTROL_PANE_EXTENSION) GetWindowLongPtr(hWndChild,GWLP_USERDATA);
								dwFoo = 1;
								dwRet = RegSetValueEx(hKey,pPaneExt->pane_name,0,REG_DWORD,(LPBYTE)&dwFoo,dwSize);
								if(dwRet != ERROR_SUCCESS)
									DllTrace(DLL_TRACE_ERROR,
									"ControlDialogProc: Load Default View: error %d setting registry key for %s\n",
									dwRet,pPaneExt->pane_name);
							}
						}
						
						
						for(i=0; i<pExt->nPanes; i++)
						{
							hWndChild = GetDlgItem(hWnd,ID_FIRST_CONTROL_PANE + i);
							pPaneExt = (PCONTROL_PANE_EXTENSION) GetWindowLongPtr(hWndChild,GWLP_USERDATA);
							dwFoo = pExt->PaneState[i];
							dwRet = RegQueryValueEx(hKey,pPaneExt->pane_name,0,&dwType,(LPBYTE)&(dwFoo),&dwSize);
							
							if(dwRet != ERROR_SUCCESS)
								DllTrace(DLL_TRACE_ERROR,
								"ControlDialogProc: Load Default View: error %d setting registry key for %s\n",
								dwRet,pPaneExt->pane_name);
							
							CheckMenuItem(
								GetMenu(hWnd),
								ID_VIEW_CONTROL_START + i,
								MF_BYCOMMAND | (dwFoo ? MF_CHECKED : MF_UNCHECKED));
							
							pExt->PaneState[i] = (BOOL)dwFoo;
							
						}
						
						ShowControlPanes(hWnd,TRUE);
						
						RegCloseKey(hKey);
					} else {
						DllTrace(DLL_TRACE_ERROR,"ControlPaneDlgProc: Load Default View: Error %08x on RegCreateKeyEx\n",dwRet);
					}
					RegCloseKey(hCSK);
				} else {
					DllTrace(DLL_TRACE_ERROR,"ControlPaneDlgProc: Failed to open camera settings key: %s",StrLastError());
				}
			} else {
				// no camera: nothing to do
			}
			break;
			
		case ID_FILE_SAVEDEFAULTVIEW:
			pCam = pExt->pCamera;
			if(pCam)
			{
				if((hCSK = OpenCameraSettingsKey(NULL,0,KEY_ALL_ACCESS)) != NULL)
				{
					pCam->GetCameraUniqueID(&UniqueID);
					StringCbPrintf(buf,sizeof(buf),"%08x%08x\\ControlPanes\\DefaultView",UniqueID.HighPart,UniqueID.LowPart);
					dwRet = RegCreateKeyEx(hCSK,buf,0,NULL,REG_OPTION_NON_VOLATILE,KEY_ALL_ACCESS,NULL,&hKey,&dwDisposition);
					if(dwRet == ERROR_SUCCESS)
					{
						for(i=0; i<pExt->nPanes; i++)
						{
							hWndChild = GetDlgItem(hWnd,ID_FIRST_CONTROL_PANE + i);
							pPaneExt = (PCONTROL_PANE_EXTENSION) GetWindowLongPtr(hWndChild,GWLP_USERDATA);
							dwFoo = pExt->PaneState[i];
							dwRet = RegSetValueEx(hKey,pPaneExt->pane_name,0,REG_DWORD,(LPBYTE)&dwFoo,dwSize);
							if(dwRet != ERROR_SUCCESS)
								DllTrace(DLL_TRACE_ERROR,
								"ControlDialogProc: Save Default View: error %d setting registry key for %s\n",
								dwRet,pPaneExt->pane_name);
						}
						RegCloseKey(hKey);
					} else {
						DllTrace(DLL_TRACE_ERROR,"ControlDialogProc: Save Default View: Error %d opening key %s\n",dwRet,buf);
					}
					RegCloseKey(hCSK);
				} else {
					DllTrace(DLL_TRACE_ERROR,"ControlPaneDlgProc: Failed to open camera settings key: %s",StrLastError());
				}			
			} else {
				// no camera, nothing to do
			}
			break;
			
		case ID_FILE_CLOSE:
			DestroyWindow(hWnd);
			break;
		case ID_VIEW_ALLCONTROLS:
			for(i=0; i<pExt->nPanes; i++)
			{
				pExt->PaneState[i] = 1;
				CheckMenuItem(
					GetMenu(hWnd),
					ID_VIEW_CONTROL_START + i,
					MF_BYCOMMAND | MF_CHECKED);
			}
			ShowControlPanes(hWnd,TRUE);
			break;
		case ID_VIEW_STRICT_PRESENT:
			for(i=0; i<pExt->nPanes; i++)
			{
				HWND hWndPanel = GetDlgItem(hWnd,ID_FIRST_CONTROL_PANE + i);
				PCONTROL_PANE_EXTENSION pCPExt;
				pCPExt = (PCONTROL_PANE_EXTENSION)GetWindowLongPtr(hWndPanel,GWLP_USERDATA);
				pControl = pCPExt->pControl;
				pExt->PaneState[i] = 
					(((pCPExt->flags & PIF_STROBE) != 0) || pExt->pCamera->HasFeature(pControl->GetFeatureID()) &&
					pControl->HasPresence() &&
					pControl->StatusPresence());
				CheckMenuItem(
					GetMenu(hWnd),
					ID_VIEW_CONTROL_START + i,
					MF_BYCOMMAND | (pExt->PaneState[i] ? MF_CHECKED : MF_UNCHECKED));
			}
			ShowControlPanes(hWnd,TRUE);
			break;
		case ID_VIEW_LOOSE_PRESENT:
			for(i=0; i<pExt->nPanes; i++)
			{
				HWND hWndPanel = GetDlgItem(hWnd,ID_FIRST_CONTROL_PANE + i);
				PCONTROL_PANE_EXTENSION pCPExt;
				pCPExt = (PCONTROL_PANE_EXTENSION)GetWindowLongPtr(hWndPanel,GWLP_USERDATA);
				pControl = pCPExt->pControl;
				pExt->PaneState[i] = (pExt->pCamera->HasFeature(pControl->GetFeatureID()) ||
					pControl->HasPresence() ||
					pControl->StatusPresence());
				CheckMenuItem(
					GetMenu(hWnd),
					ID_VIEW_CONTROL_START + i,
					MF_BYCOMMAND | (pExt->PaneState[i] ? MF_CHECKED : MF_UNCHECKED));
			}
			ShowControlPanes(hWnd,TRUE);
			break;
		default:
			if(wmId >= ID_VIEW_CONTROL_START && wmId < ID_VIEW_CONTROL_END)
			{
				// toggle a pane
				i = wmId - ID_VIEW_CONTROL_START;
				pExt->PaneState[i] ^= 1;
				CheckMenuItem(
					GetMenu(hWnd),
					wmId,
					MF_BYCOMMAND | (pExt->PaneState[i] ? MF_CHECKED : MF_UNCHECKED));
				ShowControlPanes(hWnd,TRUE);
			} else {
				lRetval = DefWindowProc(hWnd, message, wParam, lParam);
			}
			
		} // switch(wmId)
		break;
		
	case WM_PAINT:
		hdc = BeginPaint(hWnd, &ps);
		// TODO: Add any drawing code here...
		EndPaint(hWnd, &ps);
		break;
		
	case WM_DESTROY:
		DllTrace(DLL_TRACE_CHECK,"ControlDialogWndProc: WM_DESTROY: Freeing %08x\n",pExt);
		DestroyAcceleratorTable(pExt->hAccel);
		SetFocus(pExt->hWndParent);
		LocalFree(pExt);
		break;
		
	case WM_HSCROLL:
		si.cbSize = sizeof(SCROLLINFO);
		si.fMask = SIF_ALL;
		GetScrollInfo(hWnd,SB_HORZ,&si);
		switch(LOWORD(wParam))
		{
		case SB_THUMBPOSITION:
			si.nPos = si.nTrackPos;
			break;
		case SB_LEFT:
		case SB_LINELEFT:
			si.nPos -= 10;
			break;
		case SB_RIGHT:
		case SB_LINERIGHT:
			si.nPos += 10;
			break;
		case SB_PAGELEFT:
			si.nPos -= si.nPage;
			break;
		case SB_PAGERIGHT:
			si.nPos += si.nPage;
			break;
		}
		si.fMask = SIF_POS;
		pExt->trackpos = (LOWORD(wParam) == SB_THUMBTRACK ? si.nTrackPos : si.nPos);
		if(pExt->trackpos < 0)
			pExt->trackpos = 0;
		if(pExt->trackpos >= (si.nMax - (int)si.nPage))
			pExt->trackpos = si.nMax - si.nPage - 1;
		SetScrollInfo(hWnd,SB_HORZ,&si,TRUE);
		if(LOWORD(wParam) != SB_THUMBPOSITION)
			ShowControlPanes(hWnd,FALSE);
		break;
		
		default:
			lRetval = DefWindowProc(hWnd, message, wParam, lParam);
   }
   
   DllTrace(DLL_TRACE_EXIT,"EXIT ControlDialogWndProc (%d)\n",lRetval);
   return lRetval;
}

/**\brief Walks the pane list and displays the appropriate controls
 * \ingroup dialogs
 * \param hWnd The window holding the panes
 * \param bChanged If TRUE, then number of active panes may have changed, se extra work is done to recount everything
 * \return TRUE for now (may eventually be FALSE on failures, if any)
 *
 * This is an internal-use-only function, so there is less 
 *   idiotproofing than there really should be
 */
BOOL ShowControlPanes(HWND hWnd,BOOL bChanged)
{
	int i,x,y,h=0,w=0,n=0,totalw;
	RECT wRect,cRect;
	HWND hWndChild;
	SCROLLINFO si;
	PCONTROL_WINDOW_EXTENSION pExt = (PCONTROL_WINDOW_EXTENSION) GetWindowLongPtr(hWnd,GWLP_USERDATA);

	DllTrace(DLL_TRACE_ENTER,"ENTER ShowControlPanes(%08x,%d)\n",hWnd,bChanged);

	if(bChanged)
	{
		DllTrace(DLL_TRACE_CHECK,"ShowControlPanes: Pane status has changed, going to work...\n");

		for(i=0; i<pExt->nPanes; i++)
		{
			if(pExt->PaneState[i])
			{
				if(n == 0)
				{
					// get the w & h for the first window we get
					hWndChild = GetDlgItem(hWnd,ID_FIRST_CONTROL_PANE + i);
					GetWindowRect(hWndChild,&wRect);
					w = (wRect.right - wRect.left);
					h = wRect.bottom - wRect.top;
				}
				n++;
			}
		}

		if(n == 0)
		{
			DllTrace(DLL_TRACE_CHECK,"ShowControlPanes: No active windows found\n");
			// no windows, make it small
			x = 200;
			y = 100;
			// and hide the scrollbar
			ShowScrollBar(hWnd,SB_HORZ,FALSE);
			pExt->trackpos = 0;
		} else {
			if(n > 6)
			{
				totalw = (n - 5) * w;
				// more than 6, show the scrollbar
				ShowScrollBar(hWnd,SB_HORZ,TRUE);

				// set up the params
				si.cbSize = sizeof(SCROLLINFO);
				si.nMax = totalw;
				si.nMin = 0;
				si.nPage = w;
				si.fMask = SIF_RANGE | SIF_PAGE;

				if(pExt->trackpos >= totalw - w)
				{
					// the number of panes shrank and we can see the last one
					pExt->trackpos = totalw - w - 1;
					si.nPos = pExt->trackpos;
					si.fMask |= SIF_POS;
				}

				SetScrollInfo(hWnd,SB_HORZ,&si,TRUE);

				// cap it at 6 wide
				n = 6;
			} else {
				// don't need it
				ShowScrollBar(hWnd,SB_HORZ,FALSE);
				pExt->trackpos = 0;
			}

			GetWindowRect(hWnd,&wRect);
			GetClientRect(hWnd,&cRect);

			x = (wRect.right - wRect.left) - (cRect.right - cRect.left);
			y = (wRect.bottom - wRect.top) - (cRect.bottom - cRect.top);

			y += h;
			x += n * w;
		}

		SetWindowPos(hWnd,NULL,0,0,x,y,SWP_NOMOVE);

	} // if(bChanged)

	x = -pExt->trackpos;
	for(i=0; i<pExt->nPanes; i++)
	{
		hWndChild = GetDlgItem(hWnd,ID_FIRST_CONTROL_PANE + i);
		GetWindowRect(hWndChild,&wRect);
		w = wRect.right - wRect.left;
		if(pExt->PaneState[i])
		{
			if((x + w) > 0 && x <= (6 * w))
			{
				SetWindowPos(hWndChild,NULL,x,0,0,0,SWP_NOSIZE);
				ShowWindow(hWndChild,SW_SHOW);
			} else {
				ShowWindow(hWndChild,SW_HIDE);
			}
			x += w;
		} else {
			ShowWindow(hWndChild,SW_HIDE);
		}
	}

	DllTrace(DLL_TRACE_EXIT,"EXIT ShowControlPanes (TRUE)\n");

	return TRUE;
}

/**\brief Encapsulate the addition of a camera control pane to the dialog window
 * \ingroup dialogs
 */
void AddControlPane(HINSTANCE hInstance,HWND hWnd,PCONTROL_WINDOW_EXTENSION pWndExt,C1394CameraControl *pCtl,ULONG ulFlags)
{
	CONTROL_PANE_EXTENSION PaneExt;
	HMENU hMenu,hSubMenu;
	const char *name = "UNKNOWN!";

	if(ulFlags & PIF_STROBE)
	{
		C1394CameraControlStrobe *pStrobe = (C1394CameraControlStrobe *)(pCtl);
		if(pStrobe != NULL)
		{
			name = pStrobe->GetName();
		}
	} else {
		name = pCtl->GetName();
	}

	PaneExt.flags = ulFlags;
	PaneExt.pane_name = name;//dc1394GetFeatureName(pCtl->GetFeatureID());
	PaneExt.pControl = pCtl;
	PaneExt.window_id = ID_FIRST_CONTROL_PANE + pWndExt->nPanes;
	PaneExt.hInstance = hInstance;

	CreatePane(hInstance,hWnd,&PaneExt);
	hMenu = GetMenu(hWnd);
	hSubMenu = GetSubMenu(hMenu,1);
	AppendMenu(hSubMenu,MF_CHECKED,ID_VIEW_CONTROL_START + pWndExt->nPanes,PaneExt.pane_name);
	pWndExt->PaneState[pWndExt->nPanes] = 1;
	pWndExt->nPanes++;
}


/**\brief Builds and displays an instance of the 1394 Camera Control Dialog
 * \ingroup dialogs
 * \param hInstance The instance the class was registered against
 * \param hWndParent The parent window
 * \param pCamera The Camera this dialog will control
 * \return HWND to the instance, NULL on error
 *
 * This is an internal function, so there is less idiotproofing
 */
HWND InitControlDialogInstance(HINSTANCE hInstance, HWND hWndParent, C1394Camera *pCamera)
{
	HWND hWnd = NULL;
	PCONTROL_WINDOW_EXTENSION pWndExt;
	int i;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER InitControlDialogInstance(%08x,%08x,%08x)\n",
		hInstance, hWndParent, pCamera);
	
	if(!pCamera)
	{
		DllTrace(DLL_TRACE_ERROR,"InitControlDialogInstance: NULL Camera Passed, Aborting!\n");
		goto _exit;
	}
	
	pWndExt = (PCONTROL_WINDOW_EXTENSION) LocalAlloc(LPTR,sizeof(CONTROL_WINDOW_EXTENSION));
	
	if(!pWndExt)
	{
		DllTrace(DLL_TRACE_ERROR,"InitControlDialogInstance: Failed to Allocate pWndExt (%08x)\n",GetLastError());
		goto _exit;
	}
	
	pWndExt->pCamera = pCamera;
	
	hWnd = CreateWindow("1394 Control Panes Dialog Class", "1394 Camera Controls", 
		WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_BORDER|WS_MINIMIZEBOX|WS_CLIPCHILDREN|WS_HSCROLL,
		CW_USEDEFAULT, 0, 200, 100, hWndParent, NULL, hInstance, NULL);
	
	if (!hWnd)
	{
		DllTrace(DLL_TRACE_ERROR,"InitControlDialogInstance: CreateWindow Failed (%08x)\n",GetLastError());
		LocalFree(pWndExt);
		goto _exit;
	}
	
	pWndExt->hAccel = LoadAccelerators(hInstance,MAKEINTRESOURCE(IDR_CONTROL_ACCEL));
	SetWindowLongPtr(hWnd,GWLP_USERDATA,(LONG_PTR)(pWndExt));
	
	ShowWindow(hWnd, SW_SHOW);
	ShowScrollBar(hWnd,SB_HORZ,FALSE);
	UpdateWindow(hWnd);
	
	DllTrace(DLL_TRACE_CHECK,"InitControlDialogInstance: adding panes...\n");
	for(i=0; i<FEATURE_NUM_FEATURES; i++)
	{
		C1394CameraControl *pControl;
		ULONG flags = PIF_VISIBLE;
		CAMERA_FEATURE fID = (CAMERA_FEATURE)(i);
		
		if((pControl = pCamera->GetCameraControl(fID)) != NULL)
		{
			if(	fID == FEATURE_WHITE_BALANCE || 
				fID == FEATURE_TEMPERATURE ||
				fID == FEATURE_WHITE_SHADING )
				flags |= PIF_TWO_SLIDERS;
			
			AddControlPane(hInstance,hWnd,pWndExt,pControl,flags);
		}
	}
	for(i=0; i<4; i++)
	{
		C1394CameraControlStrobe *pStrobe = pCamera->GetStrobeControl(i);
		if(pStrobe != NULL)
		{
			AddControlPane(hInstance,hWnd,pWndExt,(C1394CameraControl *)pStrobe,PIF_VISIBLE | PIF_TWO_SLIDERS | PIF_STROBE);
		}
	}
	ShowControlPanes(hWnd,TRUE);
	
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT InitControlDialogInstance (%08x)\n",hWnd);
	return hWnd;
}
