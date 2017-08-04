/**\file ControlSizeDialog.cpp
 * \brief Source for partial scan mode interface dialog
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
#include "resource.h"

LRESULT CALLBACK ControlSizeDlgProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

/**\brief encapsulate the coupling of the slider values to the camera control and back to the feedback outputs
 * \ingroup dialogs
 * \param hWndDlg The dialog handle
 */
static void ApplyValues(HWND hWndDlg)
{
	unsigned short top,left,width,height,min,max,bytes;
	COLOR_CODE              color;
	C1394Camera            *pCamera = NULL;
	C1394CameraControlSize *pControl= NULL;
	char buf[256];

	pCamera = (C1394Camera*)GetWindowLongPtr(hWndDlg,GWLP_USERDATA);

	if(!pCamera || (pControl = pCamera->GetCameraControlSize()) == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"ApplyValues: Valid Size Control Unavailable\n");
		return;
	}

	pControl->GetSizeUnits(&width,&height);
	width *= (unsigned short)SendDlgItemMessage(hWndDlg,IDC_SLIDER_WIDTH,TBM_GETPOS,0,0);
	height *= (unsigned short)SendDlgItemMessage(hWndDlg,IDC_SLIDER_HEIGHT,TBM_GETPOS,0,0);

	pControl->GetPosUnits(&left,&top);
	left *= (unsigned short)SendDlgItemMessage(hWndDlg,IDC_SLIDER_LEFT,TBM_GETPOS,0,0);
	top *= (unsigned short)SendDlgItemMessage(hWndDlg,IDC_SLIDER_TOP,TBM_GETPOS,0,0);

	pControl->GetBytesPerPacketRange(&bytes,NULL);
	bytes *= (unsigned short)SendDlgItemMessage(hWndDlg,IDC_SLIDER_BYTESPACKET,TBM_GETPOS,0,0);

	GetWindowText(GetDlgItem(hWndDlg,IDC_COMBO_COLORCODE),buf,256);
	color = (COLOR_CODE)(buf[0] - '0');

	pControl->SetSize(width,height);
	pControl->SetPos(left,top);
	pControl->SetColorCode(color);
	pControl->GetBytesPerPacketRange(&min,&max);
	if(bytes > max)
		bytes = max;
	if(bytes < min)
		bytes = min;
	pControl->SetBytesPerPacket(bytes);
}

/**\brief encapsulate the mapping of camera register values to the sliders and outputs and such
 * \ingroup dialogs
 * \param hWndDlg The dialog handle
 */
static void Refresh(HWND hWndDlg)
{
	C1394Camera *pCamera = (C1394Camera *)(GetWindowLongPtr(hWndDlg,GWLP_USERDATA));
	HWND hWndItem;
	COLOR_CODE code;
	LONG lData;
	unsigned short left,top,width,height,maxh,maxv,unith,unitv,min,max,usData;
	unsigned long ulData;
	float fData;
	int i,ret;
	C1394CameraControlSize *pControl;
	char buf[256];
	char *ptr = buf;
	
	if(!pCamera || (pControl = pCamera->GetCameraControlSize()) == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"Refresh: Valid Size Control Unavailable\n");
		return;
	}
	
	// Modes

	// nuke the current contents
	hWndItem = GetDlgItem(hWndDlg,IDC_COMBO_MODE);
	i = (int)SendMessage(hWndItem,CB_GETCOUNT,NULL,NULL);
	while(i-- > 0)
		SendMessage(hWndItem,CB_DELETESTRING,0,0);
	
	// make sure we have selected a valid mode (redundant?)
	lData = -1;
	if(pCamera->GetVideoMode() == -1)
	{
		for(i=0; i<8; i++)
			if(pCamera->HasVideoMode(7,i))
			{
				pCamera->SetVideoMode(i);
				break;
			}
	}
	
	int currentModeIndex = -1;

	// populate the combobox
	for(i=0; i<8; i++)
	{
		if(pCamera->HasVideoMode(7,i))
		{
			pCamera->ReadQuadlet(0x2e0 + 4*i,(unsigned long *)&lData);
			lData <<= 2;
			lData |= 0xF0000000;
			StringCbPrintf(buf,sizeof(buf),"%d - 0xFFFF%08X",i,lData);
			ret = (int)SendMessage(hWndItem,CB_ADDSTRING,0,(LPARAM)buf);
			if(i == pCamera->GetVideoMode())
				currentModeIndex = ret;
			// use SETITEMDATA here per SR
			ret = (int)SendMessage(hWndItem,CB_SETITEMDATA,ret,(LPARAM)i);
		}
	}
	
	if(currentModeIndex != -11)
	{
		SendMessage(hWndItem,CB_SETCURSEL,currentModeIndex,0);
	} // else cannot divine current mode?


	// color codes

	// nuke the current contents
	hWndItem = GetDlgItem(hWndDlg,IDC_COMBO_COLORCODE);
	i = (int)SendMessage(hWndItem,CB_GETCOUNT,NULL,NULL);
	while(i-- > 0)
		SendMessage(hWndItem,CB_DELETESTRING,0,0);
	
	// populate the combobox
	lData = 0;
	pControl->GetColorCode(&code);
	for(i=0; i<(int)COLOR_CODE_MAX; i++)
	{
		if(pControl->HasColorCode((COLOR_CODE)i))
		{
			StringCbPrintf(buf,sizeof(buf),"%d - %s",i,dc1394GetColorCodeDescription((COLOR_CODE)(i)));
			ret = (int)SendMessage(hWndItem,CB_ADDSTRING,0,(LPARAM)(buf));
			if(i == (int)code)
				lData = ret;
			// use SETITEMDATA here per SR
			ret = (int)SendMessage(hWndItem,CB_SETITEMDATA,ret,(LPARAM)i);
		}
	}	
	
	// Width, Height
	SendMessage(hWndItem,CB_SETCURSEL,lData,0);
	pControl->GetSize(&width,&height);
	pControl->GetSizeLimits(&maxh,&maxv);
	pControl->GetSizeUnits(&unith,&unitv);
	
	// dbzproofing
	if(unith == 0)
		unith = 1;
	if(unitv == 0)
		unitv = 1;
	
	// WIDTH
	hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_WIDTH);
	lData = MAKELONG(1,maxh/unith);
	SendMessage(hWndItem,TBM_SETRANGE,FALSE,lData);
	SendMessage(hWndItem,TBM_SETLINESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPAGESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPOS,TRUE,width/unith);
	SetDlgItemInt(hWndDlg,IDC_WIDTH_FEEDBACK,width,FALSE);
	
	// HEIGHT
	hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_HEIGHT);
	lData = MAKELONG(1,maxv/unitv);
	SendMessage(hWndItem,TBM_SETRANGE,FALSE,lData);
	SendMessage(hWndItem,TBM_SETLINESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPAGESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPOS,TRUE,height/unitv);
	SetDlgItemInt(hWndDlg,IDC_HEIGHT_FEEDBACK,height,FALSE);
	
	// left, top
	pControl->GetPos(&left,&top);
	pControl->GetPosLimits(&maxh,&maxv);
	pControl->GetPosUnits(&unith,&unitv);
	if(unith == 0)
		unith = unitv = 1;
	// LEFT
	hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_LEFT);
	lData = MAKELONG(0,maxh/unith);
	SendMessage(hWndItem,TBM_SETRANGE,FALSE,lData);
	SendMessage(hWndItem,TBM_SETLINESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPAGESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPOS,TRUE,left/unith);
	SetDlgItemInt(hWndDlg,IDC_LEFT_FEEDBACK,left,FALSE);
	
	// TOP
	hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_TOP);
	lData = MAKELONG(0,maxv/unitv);
	SendMessage(hWndItem,TBM_SETRANGE,FALSE,lData);
	SendMessage(hWndItem,TBM_SETLINESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPAGESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPOS,TRUE,top/unitv);
	SetDlgItemInt(hWndDlg,IDC_TOP_FEEDBACK,top,FALSE);
	
	
	// Fill out the frame info stuff
	pControl->GetPixelsPerFrame(&ulData);
	SetDlgItemInt(hWndDlg,IDC_PIXFRAME_FEEDBACK,ulData,FALSE);
	pControl->GetBytesPerFrame(&ulData);
	SetDlgItemInt(hWndDlg,IDC_BYTESFRAME_FEEDBACK,ulData,FALSE);
	hWndItem = GetDlgItem(hWndDlg,IDC_SLIDER_BYTESPACKET);
	pControl->GetBytesPerPacketRange(&min, &max);
	pControl->GetBytesPerPacket(&usData);
	if(min == 0) 
		min = 1;
	lData = MAKELONG(1,max/min);
	DllTrace(DLL_TRACE_CHECK,"Refresh: SLIDER_BYTESPACKET <- %d-%d:%d\n",1,max/min,usData/min);
	SendMessage(hWndItem,TBM_SETRANGE,FALSE,lData);
	SendMessage(hWndItem,TBM_SETLINESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPAGESIZE,FALSE,1);
	SendMessage(hWndItem,TBM_SETPOS,TRUE,(usData/min)-1);
	SendMessage(hWndItem,TBM_SETPOS,TRUE,usData/min);
	SetDlgItemInt(hWndDlg,IDC_BYTESPACKET_FEEDBACK,usData,FALSE);
	pControl->GetPacketsPerFrame(&ulData);
	SetDlgItemInt(hWndDlg,IDC_PACKETSFRAME_FEEDBACK,ulData,FALSE);
	pControl->GetDataDepth(&usData);
	SetDlgItemInt(hWndDlg,IDC_DATADEPTH_FEEDBACK,usData,FALSE);
	pControl->GetColorFilter(&usData);
	SetDlgItemInt(hWndDlg,IDC_COLORFILTER_FEEDBACK,usData,FALSE);
	pControl->GetFrameInterval(&fData);
	StringCbPrintf(buf,sizeof(buf),"%.04f",fData);
	SetDlgItemText(hWndDlg,IDC_FRAMEINTERVAL_FEEDBACK,buf);
	
	StringCbPrintf(buf,sizeof(buf),"None");
	if(pControl->CheckError1())
	{
		StringCbPrintf(buf,sizeof(buf),"IMG");
		ptr += strlen(buf);
	}
	
	if(pControl->CheckError2())
		StringCbPrintf(ptr,sizeof(buf) - (int)(ptr - buf),"%sBPP",ptr == buf ? "" : ",");
	
	SetDlgItemText(hWndDlg,IDC_ERROR_FEEDBACK,buf);
}

/**\brief Window procedure for the partial scan interface dialog
 * \ingroup dialogs
 * \param hWndDlg The dialog window handle
 * \param uMsg The message to process
 * \param wParam the window parameter
 * \param lParam the (often unused) generic long parameter
 * 
 * This manages a bunch of sliders and calls Refresh() as appropriate
 */
static LRESULT CALLBACK ControlSizeDlgProc(
  HWND hWndDlg,  // handle to dialog box
  UINT uMsg,     // message
  WPARAM wParam, // first message parameter
  LPARAM lParam  // second message parameter
)
{
	C1394Camera *pCamera = (C1394Camera *)NULL;
	C1394CameraControlSize *pControl = NULL;
	LONG lData;
	unsigned short left,top,height,width,unith,unitv,unithpos,unitvpos,unitbpp;
	int dwFeedbackID;
	int dwFeedbackVal;
	int dwScrollVal;
	HWND hWndItem;
	char buf[256];

	// retrieve the camera and size control from GWLP_USERDATA
	pCamera = (C1394Camera *)GetWindowLongPtr(hWndDlg,GWLP_USERDATA);
	if(pCamera != NULL)
		pControl = pCamera->GetCameraControlSize();

	// Toss everything to the default dialog proc until we get the INITDIALOG message that has our camera pointer
	if(uMsg != WM_INITDIALOG && (pCamera == NULL || pControl == NULL))
	{
		// if we get a CANCEL in the interim, bail out
		if(uMsg == WM_COMMAND && LOWORD(wParam) == IDCANCEL)
		{
			EndDialog(hWndDlg,LOWORD(wParam));
			return TRUE;
		}
		return FALSE;
	}
	
	switch(uMsg)
	{
	case WM_INITDIALOG:
		// pCamera is in lParam, idiotproof and store in GWLP_USERDATA
		// note: passing a pointer in on lparam is OK on 64-bit according to MSDN
		pCamera = (C1394Camera*) (lParam);
		if(pCamera == NULL || (pControl = pCamera->GetCameraControlSize()) == NULL)
		{
			StringCbPrintf(buf,sizeof(buf),"Invalid Camera or Control Pointer, Terminating Dialog...");
			MessageBox(hWndDlg,buf,"Partial Scan Dialog Error",MB_OK|MB_ICONERROR);
			EndDialog(hWndDlg,-1);
			return TRUE;
		}

		// double-check the video format
		if(pCamera->GetVideoFormat() != 7)
		{
			StringCbPrintf(buf,sizeof(buf),"Warning: Camera at 0x%08x does not appear to be in partial scan mode.  Continue Anyway?",pCamera);
			if(MessageBox(hWndDlg,buf,"Partial Scan Dialog Warning",MB_YESNO|MB_ICONWARNING) == IDNO)
			{
				EndDialog(hWndDlg,-1);
				return TRUE;
			}
		}

		// store in GWLP_USERDATA
		SetWindowLongPtr(hWndDlg,GWLP_USERDATA,(LONG_PTR)(pCamera));
		// flesh out the controls
		Refresh(hWndDlg);
		return TRUE;
		break;
	case WM_HSCROLL:
	case WM_VSCROLL:
		// use the scroll messages to provide feedback about the tracelevel
		
		lData = (LONG) GetDlgCtrlID((HWND)lParam);
		DllTrace(DLL_TRACE_CHECK,"ControlSizeDialog:WM_SCROLL: CtlID = %d\n",lData);
		
		dwScrollVal = (int)SendMessage((HWND)lParam,TBM_GETPOS,NULL,NULL);
		pControl->GetSize(&width,&height);
		pControl->GetSizeUnits(&unith,&unitv);
		pControl->GetPos(&left,&top);
		pControl->GetPosUnits(&unithpos,&unitvpos);
		pControl->GetBytesPerPacketRange(&unitbpp,NULL);
		// since most of the work for these sliders is fundamentally the same, 
		// we will catch parameters in the switch statement and process them afterward.
		dwFeedbackID = -1;
		
		switch(lData)
		{
		case IDC_SLIDER_WIDTH:
			dwFeedbackID = IDC_WIDTH_FEEDBACK;
			dwFeedbackVal = dwScrollVal * unith;
			pControl->SetSize(dwFeedbackVal,height);
			Refresh(hWndDlg);
			break;
		case IDC_SLIDER_HEIGHT:
			dwFeedbackID = IDC_HEIGHT_FEEDBACK;
			dwFeedbackVal = dwScrollVal * unitv;
			pControl->SetSize(width,dwFeedbackVal);
			Refresh(hWndDlg);
			break;
		case IDC_SLIDER_LEFT:
			dwFeedbackID = IDC_LEFT_FEEDBACK;
			dwFeedbackVal = dwScrollVal * unithpos;
			pControl->SetPos(dwFeedbackVal,top);
			break;
		case IDC_SLIDER_TOP:
			dwFeedbackID = IDC_TOP_FEEDBACK;
			dwFeedbackVal = dwScrollVal * unitvpos;
			pControl->SetPos(left,dwFeedbackVal);
			break;
		case IDC_SLIDER_BYTESPACKET:
			dwFeedbackID = IDC_BYTESPACKET_FEEDBACK;
			dwFeedbackVal = dwScrollVal * unitbpp;
			pControl->SetBytesPerPacket(dwFeedbackVal);
			Refresh(hWndDlg);
			break;
		default:
			DllTrace(DLL_TRACE_WARNING,"SizeDialog: WM_HSCROLL: warning: unknown slider ID %d\n",lData);
			break;
		}
		
		DllTrace(DLL_TRACE_CHECK,"SizeDialog: feedback = %d:%d\n",
			dwFeedbackID,dwFeedbackVal);
		
		if(dwFeedbackID >= 0)
			SetDlgItemInt(hWndDlg,dwFeedbackID,dwFeedbackVal,FALSE);
		return TRUE;
		break;
		case WM_COMMAND:
			switch(LOWORD(wParam))
			{
			case IDAPPLY:
				ApplyValues(hWndDlg);
			case IDREFRESH:
				pCamera->SetVideoMode(pCamera->GetVideoMode());
				Refresh(hWndDlg);
				return TRUE;
				break;
			case IDOK:
				ApplyValues(hWndDlg);
			case IDCANCEL:
				EndDialog(hWndDlg,LOWORD(wParam));
				return TRUE;
				break;
			case IDC_COMBO_MODE:
				if(HIWORD(wParam) == CBN_SELENDOK)
				{
					hWndItem = (HWND)lParam;
					lData = (LONG)SendMessage(hWndItem,CB_GETCURSEL,0,0);
					lData = (LONG)SendMessage(hWndItem,CB_GETITEMDATA,lData,0);
					DllTrace(DLL_TRACE_CHECK,"SizeDialog: Mode %d Selected\n",lData);
					pCamera->SetVideoMode(lData);
					Refresh(hWndDlg);
				}
				return TRUE;
				break;
			case IDC_COMBO_COLORCODE:
				if(HIWORD(wParam) == CBN_SELENDOK)
				{
					hWndItem = (HWND)lParam;
					lData = (LONG)SendMessage(hWndItem,CB_GETCURSEL,0,0);
					lData = (LONG)SendMessage(hWndItem,CB_GETITEMDATA,lData,0);
					DllTrace(DLL_TRACE_CHECK,"SizeDialog: Color Code %d Selected\n",lData);
					pControl->SetColorCode((COLOR_CODE)lData);
					Refresh(hWndDlg);
				}
				return TRUE;
				break;
			}
			break;
	}
	return FALSE;
}

/**\brief Spawn a modal dialog interface to C1394CameraControlSize
 * \ingroup dialogs
 * \param hWndParent The parent window for this instance
 * \param pCamera Pointer to the camera whose size you wish to control
 * \return IDOK if things are OK, IDCANCEL if NOT
 * 
 * Notes: 
 * - This is a modal dialog, which means it	will block until you click "OK"	or "Cancel"
 * - It	is not recommended to futz with	the	partial	scan controls while	the	camera is sending
 * image data.
 *
 * Location: ControlSizeDialog.cpp
 */
long CAMAPI CameraControlSizeDialog(HWND hWndParent, 
									C1394Camera *pCamera)
{
	// we need common controls to use the trackbar class
	InitCommonControls();
	
	if(!pCamera->HasVideoFormat(7))
	{
		DllTrace(DLL_TRACE_ERROR,"ControlSizeDialog: Camera at %08x does not support format 7!\n");
		return -1;
	}
	
	// 64-bit note: forced cast to long to maintain ABI, but assumes return values of DialogBoxParam are 32-bit (probably ok, but maybe not)
	return (long)DialogBoxParam(g_hInstDLL,MAKEINTRESOURCE(IDD_PARTIAL_SCAN),hWndParent,(DLGPROC)(ControlSizeDlgProc),(LPARAM)pCamera);
}
