/**\file ControlPane.cpp
 * \brief Source for individual control pane dialog management
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
#include "resource.h"

/*
 * Local Function Prototypes
 */

LRESULT CALLBACK ControlPaneDlgProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

/**\brief Adds a Pane to the window, and does the various bookkeeping neccessary to do so.
 * \param hInstance Handle to the instance that contains the IDD_CONTROL_PANE resource
 * \param hWndParent Handle to the window that will host the child pane.
 * \param pExtension Pointer to the initialized extenstion for this pane
 * \return boolean success
 *
 * Exposed to other source files by ControlDialog.h
 */
BOOL CreatePane(HINSTANCE hInstance, HWND hWndParent,  PCONTROL_PANE_EXTENSION pExtension)
{
   HWND hWnd=NULL;

   DllTrace(DLL_TRACE_ENTER,"ENTER CreatePane (%08x,%08x,%08x)\n",
	   hInstance,hWndParent,pExtension);

   hWnd = CreateDialogParam(hInstance,
                            MAKEINTRESOURCE(IDD_CONTROL_PANE),
                            hWndParent,
                            (DLGPROC)ControlPaneDlgProc,
                            (LPARAM)(pExtension)); // LPARAM is 64-bit for 64-bit platforms... this will be okay

   if (!hWnd)
   {
	   DllTrace(DLL_TRACE_ERROR,"CreateDialogParam Failed (%d)",GetLastError());
	   DllTrace(DLL_TRACE_EXIT,"EXIT CreatePane (FALSE)\n");
	   return FALSE;
   }

   DllTrace(DLL_TRACE_EXIT,"EXIT CreatePane (TRUE)\n");
   return TRUE;
}

/**\brief Window procedure for the advanced controls dialog
 * \ingroup dialogs
 * \param hWnd The dialog window handle
 * \param message The message to process
 * \param wParam the window parameter
 * \param lParam the (often unused) generic long parameter
 * 
 * All this basically does is populate the absolute stuff and 
 * manage the checkbox and OK/Cancel buttons
 */
LRESULT CALLBACK AdvControlDialogProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	char buf[128];
	HWND hWndItem;
	LRESULT lRes;
	C1394CameraControl *pControl = (C1394CameraControl *)(GetWindowLongPtr(hWnd,GWLP_USERDATA));
	switch(message)
	{

	case WM_INITDIALOG:
    // On initdialog, the control instance pointer is not yet in GWLP_USERDATA, as it is our responsibilty
    // to cache it here

    // 64-bit note: according to MSDN, LPARAM is 64-bits on 64-bit platforms, so this should work just fine...
		pControl = (C1394CameraControl *)(lParam);
		SetWindowLongPtr(hWnd,GWLP_USERDATA,(LONG_PTR)(pControl));

		StringCbPrintf(buf, sizeof(buf),"Advanced Settings: %s",pControl->GetName());
		SetWindowText(hWnd,buf);
		hWndItem = GetDlgItem(hWnd,IDC_ABSCTL);
		SendMessage(hWndItem,BM_SETCHECK,(WPARAM)(pControl->HasAbsControl() && pControl->StatusAbsControl()),0);
		EnableWindow(hWndItem,pControl->HasAbsControl());

		if(pControl->HasAbsControl())
		{
			float min,max;
			pControl->GetRangeAbsolute(&min,&max);
			StringCbPrintf(buf,sizeof(buf),"Min: %.4f",min);
			SetDlgItemText(hWnd,IDC_ABSMIN,buf);
			StringCbPrintf(buf,sizeof(buf),"Max: %.4f %s",max,pControl->GetUnits());
			SetDlgItemText(hWnd,IDC_ABSMAX,buf);
		} else {
			SetDlgItemText(hWnd,IDC_ABSMIN,"");
			SetDlgItemText(hWnd,IDC_ABSMAX,"");
    }
		break;

	case WM_COMMAND:
		switch(LOWORD(wParam))
		{
		case IDC_ABSCTL:
			hWndItem = GetDlgItem(hWnd,IDC_ABSCTL);
			lRes = SendMessage(hWndItem,BM_GETCHECK,0,0);
			DllTrace(DLL_TRACE_CHECK,"AdvControl: IDC_ABSCTL %d\n",lRes);
			pControl->SetAbsControl((BOOL)lRes);
			return TRUE;
			break;
		case IDOK:
			hWndItem = GetDlgItem(hWnd,IDC_ABSCTL);
			lRes = SendMessage(hWndItem,BM_GETCHECK,0,0);
			EndDialog(hWnd,lRes);
			return TRUE;
		}
	}
	return FALSE;
}

#define ABS_SLIDER_SCALE 1000.0f

/**\brief encapsulate the coupling of the pane sliders to the feedback text
 * \ingroup dialogs
 * \param hWndPanel The panel to update
 * \param UpdateControl Whether to push the new slider value(s) to the camera
 *
 */
static void cpUpdateFeedback(HWND hWndPanel, BOOL UpdateControl)
{
	char buf[64];
	unsigned long lRes,lRes2=0;
	HWND hWndItem;
	PCONTROL_PANE_EXTENSION pPaneExt = (PCONTROL_PANE_EXTENSION)(GetWindowLongPtr(hWndPanel,GWLP_USERDATA));
	
	hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER1);
	lRes = (unsigned long)SendMessage(hWndItem,TBM_GETPOS,0,0);
	
	if(pPaneExt->pControl->StatusAbsControl())
	{
		float min,max,f;
		f = ABS_SLIDER_SCALE - (float)(lRes);
		f /= ABS_SLIDER_SCALE;
		pPaneExt->pControl->GetRangeAbsolute(&min,&max);
		f *= (max - min);
		f += min;
		StringCbPrintf(buf,sizeof(buf),"%.4f %s",f,pPaneExt->pControl->GetUnits());
		if(UpdateControl)
			pPaneExt->pControl->SetValueAbsolute(f);
	} else {
		/* standard integer mode */
		if(pPaneExt->flags & PIF_TWO_SLIDERS)
		{
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER2);
			lRes2 = (unsigned long)SendMessage(hWndItem,TBM_GETPOS,0,0);
			lRes2 = pPaneExt->slider_max - (lRes2 - pPaneExt->slider_min);
			StringCbPrintf(buf,sizeof(buf),"%d",lRes2);
			SetDlgItemText(hWndPanel,IDC_SLIDER_FEEDBACK2,buf);
		}
		lRes = pPaneExt->slider_max - (lRes - pPaneExt->slider_min);
		StringCbPrintf(buf,sizeof(buf),"%d",lRes);
		if(UpdateControl)
			pPaneExt->pControl->SetValue((unsigned short)lRes,(unsigned short)lRes2);
	}
	SetDlgItemText(hWndPanel,IDC_SLIDER_FEEDBACK1,buf);
}

/**\brief encapsulate the coupling of the slider range and values to the camera control
 * \ingroup dialogs
 * \param hWndPanel The panel to set up
 *
 * This computes the slider ranges, positions and visiblities depending on the status of
 * of the feature control
 */
static void cpSetupPanel(HWND hWndPanel)
{
	PCONTROL_PANE_EXTENSION pPaneExt = (PCONTROL_PANE_EXTENSION)(GetWindowLongPtr(hWndPanel,GWLP_USERDATA));
	unsigned short min, max, curr, curr2;
	RECT wRect,sRect;
	HWND hWndItem;
	
	/* determine min, max, current value(s) */
	/* don't forget: Sliders are down-increasing, so for up-increasing, we need to reflect them */
	if(pPaneExt->pControl->StatusAbsControl())
	{
		float fmin,fmax,fval;
		/* using absolute (IEEE float) control */
		/* slider range is 0-ABS_SLIDER_SCALE */
		min = pPaneExt->slider_min = 0;
		max = pPaneExt->slider_max = (int)(ABS_SLIDER_SCALE);
		pPaneExt->pControl->GetRangeAbsolute(&fmin,&fmax);
		pPaneExt->pControl->GetValueAbsolute(&fval);
		curr = (int)(ABS_SLIDER_SCALE * (fmax - fval) / (fmax - fmin));
		/* no absolute controls have multiple sliders */
		curr2 = 0;
	} else {
		/* using traditional integer control */
		pPaneExt->pControl->GetRange(&min,&max);
		pPaneExt->slider_min = min;
		pPaneExt->slider_max = max;
		pPaneExt->pControl->GetValue(&curr,&curr2);
		curr = max - (curr - min);
		curr2 = max - (curr2 - min);
	}
	
	/* Init Slider1 */
	hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER1);
	SendMessage(hWndItem,TBM_SETRANGE,(WPARAM)FALSE,(LPARAM)MAKELONG(min,max));
	SendMessage(hWndItem,TBM_SETPOS,(WPARAM)TRUE,(LPARAM)curr);

	/* everything is relative to the panel rect, so grab that */
	GetWindowRect(hWndPanel,&wRect);

	/* handle the two-slider case */
	if(pPaneExt->flags & PIF_TWO_SLIDERS)
	{
		int x,y,w,h;
				
		if(pPaneExt->pControl->HasAbsControl())
		{
			/* Hide Slider2 */
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER2);
			ShowWindow(hWndItem,SW_HIDE);
			
			/* Center Slider1 within wRect*/
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER1);
			GetWindowRect(hWndItem,&sRect);
			
			w = sRect.right - sRect.left;
			h = sRect.bottom - sRect.top;
			x = (wRect.right - wRect.left - w)/2;
			y = sRect.top - wRect.top;
			MoveWindow(hWndItem,x,y,w,h,FALSE);
			
			/* similarly hide feedback2 and move/expand feedback1 */
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER_FEEDBACK2);
			ShowWindow(hWndItem,SW_HIDE);
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER_FEEDBACK1);
			GetWindowRect(hWndItem,&sRect);
			w = wRect.right - wRect.left - 40;
			h = sRect.bottom - sRect.top;
			x = (wRect.right - wRect.left - w)/2;
			y = sRect.top - wRect.top;
			MoveWindow(hWndItem,x,y,w,h,FALSE);
		} else {
			/* Setup and show slider 2 */
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER2);
			SendMessage(hWndItem,TBM_SETRANGE,(WPARAM)FALSE,(LPARAM)MAKELONG(min,max));
			SendMessage(hWndItem,TBM_SETPOS,(WPARAM)TRUE,(LPARAM)curr2);
			ShowWindow(hWndItem,SW_SHOW);
			
			/* use the coordinates of slider2 to move slider1 */
			GetWindowRect(hWndItem,&sRect);      
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER1);
			MoveWindow(hWndItem,wRect.right - sRect.right,sRect.top - wRect.top,
				sRect.right - sRect.left, sRect.bottom - sRect.top,FALSE);
			
			/* similarly show feedback2 and move feedback1 */
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER_FEEDBACK2);
			ShowWindow(hWndItem,SW_SHOW);
			GetWindowRect(hWndItem,&sRect);
			hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER_FEEDBACK1);
			MoveWindow(hWndItem,wRect.right - sRect.right,sRect.top - wRect.top,
				sRect.right - sRect.left, sRect.bottom - sRect.top,FALSE);
			SetDlgItemInt(hWndPanel,IDC_SLIDER_FEEDBACK2,curr2,TRUE);
		}
	}

	if(pPaneExt->flags & PIF_STROBE)
	{
		// sliders look a little different, we have to hide a few things and
		// change the text in others
		hWndItem = GetDlgItem(hWndPanel,IDC_BUT_ONEPUSH);
		ShowWindow(hWndItem,SW_HIDE);

		hWndItem = GetDlgItem(hWndPanel,IDC_BUT_ADVANCED);
		ShowWindow(hWndItem,SW_HIDE);

		hWndItem = GetDlgItem(hWndPanel,IDC_STA_MANUAL);
		ShowWindow(hWndItem,SW_HIDE);

		hWndItem = GetDlgItem(hWndPanel,IDC_STA_ONEPUSH);
		ShowWindow(hWndItem,SW_HIDE);

		SetDlgItemText(hWndPanel,IDC_BUT_AUTO_MAN,"Polarity");
		SetDlgItemText(hWndPanel,IDC_INQ_AUTO,"p");
		SetDlgItemText(hWndPanel,IDC_STA_AUTO,"p");

		/* cheat and slip the unused inq textboxes under the feedback ones
		 * to show delay vs duration
		 */
		hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER_FEEDBACK1);
		GetWindowRect(hWndItem,&sRect);
		hWndItem = GetDlgItem(hWndPanel,IDC_INQ_MANUAL);
		SetWindowText(hWndItem,"Duration");
		MoveWindow(hWndItem,sRect.left - wRect.left/* + (sRect.right - sRect.left) / 2*/,sRect.bottom - wRect.top + 5,sRect.right - sRect.left,sRect.bottom - sRect.top,FALSE);
		hWndItem = GetDlgItem(hWndPanel,IDC_SLIDER_FEEDBACK2);
		GetWindowRect(hWndItem,&sRect);
		hWndItem = GetDlgItem(hWndPanel,IDC_INQ_ONEPUSH);
		SetWindowText(hWndItem,"Delay");
		MoveWindow(hWndItem,sRect.left - wRect.left/* + (sRect.right - sRect.left) / 2*/,sRect.bottom - wRect.top + 5,sRect.right - sRect.left,sRect.bottom - sRect.top,FALSE);
	}

	/* update the feedback (it is unnecessary to frob the camera) */
	cpUpdateFeedback(hWndPanel,FALSE);
	
	// now set all the bitflags
	// they are all initially disabled
	
	// the inquiry register
	hWndItem = GetDlgItem(hWndPanel,IDC_INQ_PRES);
	EnableWindow(hWndItem,pPaneExt->pControl->HasPresence());
	hWndItem = GetDlgItem(hWndPanel,IDC_INQ_ONEPUSH);
	EnableWindow(hWndItem,pPaneExt->pControl->HasOnePush() || (pPaneExt->flags & PIF_STROBE));
	hWndItem = GetDlgItem(hWndPanel,IDC_INQ_READ);
	EnableWindow(hWndItem,pPaneExt->pControl->HasReadout());
	hWndItem = GetDlgItem(hWndPanel,IDC_INQ_ONOFF);
	EnableWindow(hWndItem,pPaneExt->pControl->HasOnOff());
	hWndItem = GetDlgItem(hWndPanel,IDC_INQ_AUTO);
	EnableWindow(hWndItem,pPaneExt->pControl->HasAutoMode());
	hWndItem = GetDlgItem(hWndPanel,IDC_INQ_MANUAL);
	EnableWindow(hWndItem,pPaneExt->pControl->HasManualMode() || (pPaneExt->flags & PIF_STROBE));
	
	// the status register
	hWndItem = GetDlgItem(hWndPanel,IDC_STA_PRES);
	EnableWindow(hWndItem,pPaneExt->pControl->StatusPresence());
	hWndItem = GetDlgItem(hWndPanel,IDC_STA_ONEPUSH);
	EnableWindow(hWndItem,pPaneExt->pControl->StatusOnePush());
	hWndItem = GetDlgItem(hWndPanel,IDC_STA_ONOFF);
	EnableWindow(hWndItem,pPaneExt->pControl->StatusOnOff());
	hWndItem = GetDlgItem(hWndPanel,IDC_STA_AUTO);
	EnableWindow(hWndItem,pPaneExt->pControl->StatusAutoMode());
	hWndItem = GetDlgItem(hWndPanel,IDC_STA_MANUAL);
	EnableWindow(hWndItem,(pPaneExt->pControl->HasManualMode() && !pPaneExt->pControl->StatusAutoMode()));
}

/**\brief Window procedure for the control pane dialog
 * \ingroup dialogs
 * \param hWnd The dialog window handle
 * \param message The message to process
 * \param wParam the window parameter
 * \param lParam the (often unused) generic long parameter
 *
 * This manages a few buttons that get mapped to status mutators and calls cpSetupPanel and cpUpdateFeedback
 * when appropriate.
 */
LRESULT CALLBACK ControlPaneDlgProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	PCONTROL_PANE_EXTENSION pPaneExt = (PCONTROL_PANE_EXTENSION)(GetWindowLongPtr(hWnd,GWLP_USERDATA));
	HWND hWndItem;
	LONG lRes;
	LRESULT lRetval = FALSE;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER ControolPaneDlgProc(%08x,%08x,%08x,%08x\n",
		hWnd, message, wParam, lParam);
	
	switch(message)
	{
	case WM_INITDIALOG:
    {
		  // pPaneExt isn't in GWLP_USERDATA yet, it has been passed in lParam
      // note: LPARAM is 64-bits on 64-bit platforms, so this should continue to work
      PCONTROL_PANE_EXTENSION inputExtension = (PCONTROL_PANE_EXTENSION) (lParam);

      // allocate memory for our local copy, matching LocalFree() in WM_DESTROY
		  pPaneExt = (PCONTROL_PANE_EXTENSION) LocalAlloc(LPTR,sizeof(CONTROL_PANE_EXTENSION));
		  CopyMemory(pPaneExt,inputExtension,sizeof(CONTROL_PANE_EXTENSION));

      // cache our local copy in GWLP_USERDATA
		  SetWindowLongPtr(hWnd,GWLP_USERDATA,(LONG_PTR)(pPaneExt));
		  
		  pPaneExt->pControl->Inquire();
		  pPaneExt->pControl->Status();
		  cpSetupPanel(hWnd);
		  
		  // set the title and initial feedback statics
		  SetDlgItemText(hWnd,IDC_TITLE,pPaneExt->pane_name);
		  
		  // update our windowID to be the one assigned
		  // this is necessary because this child is a dialog per-se
		  // and we don't have an opportunity to use the HMENU part
		  // of CreateWindow To assign one off-the-bat
		  SetWindowLong(hWnd,GWL_ID,pPaneExt->window_id);
		  
		  lRetval = TRUE;
    }
		break;
	case WM_HSCROLL:
	case WM_VSCROLL:
		cpUpdateFeedback(hWnd,TRUE);
		lRetval = TRUE;
		break;
	case WM_COMMAND:
		switch(LOWORD(wParam))
		{
		case IDC_BUT_ADVANCED:
			lRes = (LONG)DialogBoxParam(pPaneExt->hInstance,MAKEINTRESOURCE(IDD_ADVANCED_CONTROL),hWnd,(DLGPROC)AdvControlDialogProc,(LPARAM)(pPaneExt->pControl));
			pPaneExt->pControl->Status();
			cpSetupPanel(hWnd);
			lRetval = TRUE;
			break;
		case IDC_BUT_ONOFF:
			if(pPaneExt->pControl)
			{
				pPaneExt->pControl->SetOnOff(!pPaneExt->pControl->StatusOnOff());
				pPaneExt->pControl->Status();
				hWndItem = GetDlgItem(hWnd,IDC_STA_ONOFF);
				EnableWindow(hWndItem,pPaneExt->pControl->StatusOnOff());
			}
			
			lRetval = TRUE;
			break;
		case IDC_BUT_AUTO_MAN:
			if(pPaneExt->pControl)
			{
				pPaneExt->pControl->SetAutoMode(!pPaneExt->pControl->StatusAutoMode());
				pPaneExt->pControl->Status();
				hWndItem = GetDlgItem(hWnd,IDC_STA_AUTO);
				EnableWindow(hWndItem,pPaneExt->pControl->StatusAutoMode());
				hWndItem = GetDlgItem(hWnd,IDC_STA_MANUAL);
				EnableWindow(hWndItem,(pPaneExt->pControl->HasManualMode() && !pPaneExt->pControl->StatusAutoMode()));
			}
			lRetval = TRUE;
			break;
		case IDC_BUT_ONEPUSH:
			if(pPaneExt->pControl)
			{
				pPaneExt->pControl->SetOnePush(!pPaneExt->pControl->StatusOnePush());
				pPaneExt->pControl->Status();
				hWndItem = GetDlgItem(hWnd,IDC_STA_ONEPUSH);
				EnableWindow(hWndItem,pPaneExt->pControl->StatusOnePush());
			}
			lRetval = TRUE;
			break;
		case IDC_BUT_POLL:
			pPaneExt->pControl->Inquire();
			pPaneExt->pControl->Status();
			cpSetupPanel(hWnd);
			lRetval = TRUE;    
			break;
		} // switch(command)
		break;
		case WM_DESTROY:
			DllTrace(DLL_TRACE_CHECK,"ControlPaneDlgProc: WM_DESTROY: Freeing %08x\n",pPaneExt);
			LocalFree(pPaneExt);
			break;
	}
	
	DllTrace(DLL_TRACE_EXIT,"EXIT ControlPaneDlgProc (%s)\n",lRetval ? "TRUE" : "FALSE");
	return lRetval;
}

