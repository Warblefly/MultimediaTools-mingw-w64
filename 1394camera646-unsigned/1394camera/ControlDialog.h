/**\file ControlDialog.h
 * \brief Internal header for the control dialog stuff
 * \ingroup dialogs
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

#ifndef __CONTROL_DIALOG_H__
#define __CONTROL_DIALOG_H__

#define PIF_TWO_SLIDERS 1
#define PIF_VISIBLE 2
#define PIF_STROBE 4

#define MAX_PANES 64

/**\brief Encapsulate everything a control pane needs to survive, stored in GWLP_USERDATA */
typedef struct _CONTROL_PANE_EXTENSION
{
	long window_id;
	HWND hWndParent;
	HINSTANCE hInstance;
	long flags;
	unsigned short slider_min, slider_max;
	const char *pane_name;
	C1394CameraControl *pControl; // the control this pane is monitoring
} CONTROL_PANE_EXTENSION, *PCONTROL_PANE_EXTENSION;

/**\brief Encapsulate everything the control dialog needs to survive, stored in GWLP_USERDATA */
typedef struct _CONTROL_WINDOW_EXTENSION
{
	long nPanes; // how many panes?
	HWND hWndParent;
	HACCEL hAccel;
	long flags;
	long trackpos;
	C1394Camera *pCamera; // the camera that this dialog is controlling
	unsigned char PaneState[MAX_PANES]; 
} CONTROL_WINDOW_EXTENSION, *PCONTROL_WINDOW_EXTENSION;

HWND InitControlDialogInstance(HINSTANCE hInstance, HWND hWndParent, C1394Camera *pCamera);
BOOL ShowControlPanes(HWND hWnd,BOOL bChanged);
BOOL CreatePane(HINSTANCE hInstance, HWND hWndParent, PCONTROL_PANE_EXTENSION pExtension);

#endif