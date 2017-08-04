/**\file      1394CameraDemo.cpp
 * \author    Christopher R. Baker
 * \date      02/13/2011
 * \brief     Win32-native demo application - implementation
 * \ingroup   win32demo
 *
 * \attention Copyright 2000-2011
 * \attention Robotics Institute
 * \attention Carnegie Mellon University
 * \attention Pittsburgh, PA
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with the CMU 1394 Digital Camera Driver; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#include "1394CameraDemo.h"

#include "resource.h"

#include <shellapi.h>
#include <strsafe.h>

// somewhere, the win32 SDK documentation implies that we should have these already
// ... but we don't
#define GET_X_LPARAM(LL) (MAKEPOINTS(LL).x)
#define GET_Y_LPARAM(LL) (MAKEPOINTS(LL).y)

/**\brief forward wndproc calls back into the owning C1394CameraDemo instance
 *
 * \note This embeds the owning instance pointer in GWLP_USERDATA, so you may NOT use that "window long" for anything
 * else!
 */
static LRESULT CALLBACK C1394CameraDemoWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
  // C1394CameraDemo::create() should have placed itself into GWLP_USERDATA
  LONG_PTR lPtr = GetWindowLongPtr(hWnd,GWLP_USERDATA);
  if(lPtr != NULL)
  {
    C1394CameraDemo *theApp = reinterpret_cast<C1394CameraDemo *>(lPtr);
    return theApp->WndProc(hWnd,message,wParam,lParam);
  }

  return DefWindowProc(hWnd,message,wParam,lParam);
}

/**\brief Construct a demo window
 * \param hInstance the instance handle (passed around to limit globals)
 */
C1394CameraDemo::C1394CameraDemo(HINSTANCE hInstance):
  theCamera_(),
  hInst_(hInstance),
  hWnd_(NULL),
  classAtom_(0),
  acqFlags_(ACQ_START_VIDEO_STREAM),
  hScrollActive_(FALSE),
  vScrollActive_(FALSE),
  mouseScrollActive_(FALSE),
  xMouseDown_(0),
  yMouseDown_(0),
  frameBuffer_(NULL),
  frameBufferSize_(0),
  getIntegerDialog_(hInstance),
  twiddleDialog_(hInstance),
  aboutDialog_(hInstance,MAKEINTRESOURCE(IDD_ABOUTBOX)),
  enableDebugOutput_(false)
{
}

/**\brief Destroy a demo window
 *
 * The only thing we have to worry about here is the frame buffer
 */
C1394CameraDemo::~C1394CameraDemo()
{
  if(frameBuffer_ != NULL)
  {
    LocalFree(frameBuffer_);
    frameBuffer_ = NULL;
  }
}

/**\brief Initialize the window
 * \param nCmdShow: whether or not to show the window
 * \return boolean success
 *
 * \note: this is a good candidate for pulling into an outer class
 */
bool C1394CameraDemo::initialize(int nCmdShow)
{
  registerWindowClass();
  createWindowInstance(nCmdShow);
  return true;
}

/**\brief Run the message pump
 * \return boolean success
 *
 * \note this is a good candidate for pulling into an outer class, modulo the frame-ready handle stuff
 */
bool C1394CameraDemo::run()
{
  MSG msg;
  HACCEL hAccelTable;
  hAccelTable = LoadAccelerators(hInst_, (LPCTSTR)IDR_MAINFRAME);

  // check the camera link once so that Ctrl-0 will work 
  this->theCamera_.CheckLink();

  // Main message loop:
  
  while(1)
  {
    while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
    {
      if(msg.message == WM_QUIT)
      {
        if(theCamera_.IsAcquiring())
        {
          theCamera_.StopImageAcquisition();
        }
        return 1;
      }

      if (!TranslateAccelerator(msg.hwnd, hAccelTable, &msg))
      {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
      }
    }

	// we will MsgWaitForMultipleObjects if the camera is running to do overlapped I/O
	HANDLE waitHandle = theCamera_.GetFrameEvent();
	DWORD dwCount = (theCamera_.IsAcquiring() ? 1 : 0);
	if((WAIT_OBJECT_0 + dwCount) ==
		MsgWaitForMultipleObjects(dwCount,&waitHandle,FALSE,INFINITE,QS_ALLINPUT))
	{
		// messages to pump: back to the top
		continue;
	} else {
		bool gotFrame=false;
		bool moreFrames=true;
		while(moreFrames)
		{
			// frame hit (will only get here if theCamera_.IsAcquiring()):
			// acquire, getDIB and flush
			if(reportCameraError(theCamera_.AcquireImageEx(FALSE,NULL),"AcquireImageEx"))
			{
				// call the stop handler directly
				processCameraMenu(IDM_CAMERA_STOP,0,0);
				moreFrames = false;
			} else {
				if(gotFrame)
				{
					dropCount_++;
				} else {
					gotFrame = true;
					frameCount_++;
				}
				// check on the next frame event to see if we're still draining
				moreFrames = (WaitForSingleObject(theCamera_.GetFrameEvent(),0) == WAIT_OBJECT_0);
			}
			if(gotFrame)
			{
				theCamera_.getDIB(frameBuffer_,frameBufferSize_);
				InvalidateRect(hWnd_,NULL,FALSE);
			}
		}
	} // while (more frames)
  } // while (1)

  return false;
}

/**\brief cleanup an the window
 *
 * \note: this may be eliminated, or made polymorphic through a parent class with a no-op default impl
 */
void C1394CameraDemo::cleanup()
{
}

/**\brief Register the actual window class
 *
 * \note: this should probably be pulled into a parent class, somehow granting specializations an opportunity to set any
 *        truly-unique variables (title, icon, etc id's)
 */
bool C1394CameraDemo::registerWindowClass()
{
  if(hInst_ != INVALID_HANDLE_VALUE)
  {
    WNDCLASSEX wcex;

    LoadString(hInst_, IDR_MAINFRAME, szTitle_, MAX_LOADSTRING);
    LoadString(hInst_, IDR_MAINFRAME, szWindowClass_, MAX_LOADSTRING);

    wcex.cbSize = sizeof(WNDCLASSEX);

    wcex.style      = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc  = (WNDPROC)C1394CameraDemoWndProc;
    wcex.cbClsExtra    = 0;
    wcex.cbWndExtra    = 0;
    wcex.hInstance    = hInst_;
    wcex.hIcon      = LoadIcon(hInst_, (LPCTSTR)IDR_MAINFRAME);
    wcex.hCursor    = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = NULL;  // no background drawing, please
    wcex.lpszMenuName  = (LPCSTR)IDR_MAINFRAME;
    wcex.lpszClassName  = szWindowClass_;
    wcex.hIconSm    = LoadIcon(wcex.hInstance, (LPCTSTR)IDR_MAINFRAME);

    classAtom_ = RegisterClassEx(&wcex);
  }

  return classAtom_ != 0;
}

/**\brief Create an instance of the registered window class
 *
 * \note: this should probably be pulled into a parent class, wholesale
 */
bool C1394CameraDemo::createWindowInstance(int nCmdShow)
{
  if(hWnd_ == NULL)
  {
    hWnd_ = CreateWindow(szWindowClass_, szTitle_, WS_OVERLAPPEDWINDOW,
                         CW_USEDEFAULT, 0, 240, 240, NULL, NULL, hInst_, NULL);
  }

  if (hWnd_ != NULL)
  {
    SetWindowLongPtr(hWnd_,GWLP_USERDATA,(LONG_PTR)this);
    ShowWindow(hWnd_, nCmdShow);
    UpdateWindow(hWnd_);
    updateScrollBarInfo(false);
    SetScrollPos(hWnd_,SB_HORZ,0,TRUE);
    SetScrollPos(hWnd_,SB_VERT,0,TRUE);
  }

  return hWnd_ != NULL;
}

/**\brief Process window messages
 * \return 1 if the default window proc should be invoked, zero otherwise
 *
 * Most of what's going on here has to do with either:
 * - Redirecting to other internal methods to handle commands, menu reveals, etc., or else
 * - Dealing with scrolling and window resizing to manage the "virtual" client area
 *
 * The latter is an ideal candidate for extraction into a parent class, as the idea of a simple window with a simple
 * scrolling client area is quite useful unto itself and can be decoupled from the rest of the logic via a simple
 * "setVirtualClientArea()" method call
 */
LRESULT C1394CameraDemo::WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
  bool processed = false;
  switch (message)
  {
   case WM_COMMAND:
     processed = processCommand(LOWORD(wParam),HIWORD(wParam),lParam);
     break;
   case WM_MENUSELECT:
     if(HIWORD(wParam) == 0xFFFF && lParam == NULL)
     {
       //debugPrint("Closed Menu");
     } else {
       processMenuSelect(LOWORD(wParam),HIWORD(wParam),(HMENU)(lParam));
     }
     processed = true;
     break;
   case WM_PAINT:
     processed = processPaint();
     break;
   case WM_DESTROY:
     PostQuitMessage(0);
     processed = true;
     break;
   case WM_LBUTTONDOWN:
     // we're going to allow the user to drag the frame around in the box
     // it's not super-important, but it's kind of fun
     if(hScrollActive_ || vScrollActive_)
     {
       // embed the current scroll position in the "mouseDown" members
       getScrollPosition(xMouseDown_,yMouseDown_);
       // and offset by the clicked position
       xMouseDown_ += GET_X_LPARAM(lParam);
       yMouseDown_ += GET_Y_LPARAM(lParam);

       // set the activity flag, and capture the mouse so drag events can leave the client area
       mouseScrollActive_ = TRUE;
       SetCapture(hWnd_);
     }
     break;
   case WM_LBUTTONUP:
     if(mouseScrollActive_)
     {
       // done dragging around
       xMouseDown_ = 0;
       yMouseDown_ = 0;
       mouseScrollActive_ = 0;
       ReleaseCapture();
     }
     break;
   case WM_MOUSEMOVE:
     if(mouseScrollActive_)
     {
       // subtract off the current mouse coordinate to
       // get back to the desired scroll offset
       int deltaX = xMouseDown_ - GET_X_LPARAM(lParam);
       int deltaY = yMouseDown_ - GET_Y_LPARAM(lParam);

       // push that offset to the scroll bars
       setScrollPosition(deltaX,deltaY);

       // and redraw
       RECT cr;
       GetClientRect(hWnd_,&cr);
       InvalidateRect(hWnd_,&cr,FALSE);
     }
     break;
   case WM_HSCROLL:
   case WM_VSCROLL:
   {
     int sbId = (message == WM_HSCROLL ? SB_HORZ : SB_VERT);
     SCROLLINFO si;
     si.cbSize = sizeof(SCROLLINFO);
     si.fMask = SIF_ALL;
     GetScrollInfo(hWnd,sbId,&si);
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
     int thePos = (LOWORD(wParam) == SB_THUMBTRACK ? si.nTrackPos : si.nPos);
     if(thePos < 0)
       thePos = 0;
     if(thePos >= si.nMax)
       thePos = si.nMax - 1;
     si.nPos = thePos;
     SetScrollInfo(hWnd,sbId,&si,TRUE);
     RECT cr;
     GetClientRect(hWnd_,&cr);
     InvalidateRect(hWnd_,&cr,FALSE);
   } break;
   case WM_SIZING:
   {
     // maintain a minimum size of 240x240
     // note: this functionality could also be embedded in a generic parent
     RECT *pRect = (RECT *)(lParam);
     if((pRect->bottom - pRect->top) < 240)
     {
       if(wParam == WMSZ_TOP || wParam == WMSZ_TOPLEFT || wParam == WMSZ_TOPRIGHT)
       {
         pRect->top = pRect->bottom - 240;
       } else {
         pRect->bottom = pRect->top + 240;
       }
     }

     if((pRect->right - pRect->left) < 240)
     {
       if(wParam == WMSZ_LEFT || wParam == WMSZ_TOPLEFT || wParam == WMSZ_BOTTOMLEFT)
       {
         pRect->left = pRect->right - 240;
       } else {
         pRect->right = pRect->left + 240;
       }
     }
     // once we're done wrestling size stuff, update scrollbar stuff
     updateScrollBarInfo(false);
     return TRUE;
   } break;
   default:
     return DefWindowProc(hWnd,message,wParam,lParam);
  }

  return processed ? 0 : 1;
}

/**\brief Process Command Messages particular to this application
 * \param wmId The id of the command
 * \param wmEvent The associated event
 * \param lParam The parameter that comes with these events
 * \return boolean indication of whether the command was "processed" (false will cause the command to be processed by DefWndProc)
 *
 * Most of the logic here is unique to the CameraDemo-ness and would make a good polymorph from the parent WndProc
 *
 * It may be valuable to readability to break this down further based on command grouping in resource.h
 */
bool C1394CameraDemo::processCommand(int wmId, int wmEvent, LPARAM lParam)
{
  // format, mode rate are easy, the approproate info is embedded in the command ID
  // so just check these and bail if there's a hit
  if(wmId >= IDM_FORMAT_MODE_START && wmId <= IDM_FORMAT_MODE_END)
  {
    // set the video format
    if(reportCameraError(theCamera_.SetVideoFormat(FORMAT_FROM_ID(wmId)),
                         "SetVideoFormat"))
    {
      // bail out
      return true;
    }

    if(FORMAT_FROM_ID(wmId) == 7)
    {
      // Format 7 modes are determined through the dialog
      CameraControlSizeDialog(hWnd_,&theCamera_);
    } else {
      // all other modes are embedded in wmID
      if(reportCameraError(theCamera_.SetVideoMode(MODE_FROM_ID(wmId)),
                           "SetVideoMode"))
      {
        // bail out
        return true;
      }
    }

    // if we get here, format and/or mode and/or dimensions may have changed
    // so update dimensions
    updateWindowDimensions();
    return true;
  }

  // Framerate is also embedded in the command ID, see resource.h
  if(wmId >= IDM_FRAMERATE_START && wmId < IDM_FRAMERATE_END)
  {
    reportCameraError(theCamera_.SetVideoFrameRate(FRAMERATE_FROM_ID(wmId)),
                      "SetVideoFrameRate");
    return true;
  }

  // Lastly, check for help commands, then fall through to processCameraMenu
  switch (wmId)
  {
   case IDM_HELP_DEBUG_SETTINGS:
     CameraDebugDialog(hWnd_);
     break;
   case IDM_HELP_DEBUG_DEMO:
     enableDebugOutput_ = !enableDebugOutput_;
	 updateScrollBarInfo(true);
     InvalidateRect(hWnd_,NULL,FALSE);
	 break;
   case IDM_HELP_DOCUMENTATION:
     launchHelpBrowser();
     break;
   case IDM_HELP_ABOUT:
     aboutDialog_.run(hWnd_);
     break;
   default:
     // embedded return: the only other thing this might be is from the camera menu
     // this is somewhat weird, and begs for a bit of refactoring
     return processCameraMenu(wmId,wmEvent, lParam);
  }

  // all our cases are explicitly handled by the above, so we should return false by default
  return false;
}

/**\brief Process WM_PAINT commands
 * \return boolean success
 */
bool C1394CameraDemo::processPaint()
{
  PAINTSTRUCT ps;
  HDC hdc = BeginPaint(hWnd_, &ps);
  RECT rt;
  GetClientRect(hWnd_, &rt);
  HBRUSH backgroundBrush = GetSysColorBrush(COLOR_APPWORKSPACE);

  // TODO: Add any drawing code here...
  if(theCamera_.IsAcquiring() && frameBuffer_ != NULL)
  {
    drawFrameBuffer(hdc);
  }
  else if(enableDebugOutput_)
  {
    char buf[256];
    char vendor[64];
    char model[64];
  int xOffset, yOffset;
  vendor[0] = 0;
  model[0] = 0;
    theCamera_.GetCameraVendor(vendor,64);
    theCamera_.GetCameraName(model,64);
  getScrollPosition(xOffset,yOffset);
    FillRect(hdc,&rt,backgroundBrush);
  rt.left = -xOffset;
  // note: debug also enables the fake 640x480 client scrolling area
  // so we want to draw in the center of that
  rt.right = 640 - xOffset;
  rt.bottom = 480 - yOffset;
  rt.top = -yOffset;
    if(S_OK == StringCbPrintf(buf,sizeof(buf),"C1394Camera theCamera_ @%p:%s %s",(unsigned int)(&theCamera_),vendor,model))
    {
    SetBkColor(hdc,GetSysColor(COLOR_APPWORKSPACE));
        DrawText(hdc, buf, -1, &rt, DT_CENTER | DT_SINGLELINE | DT_VCENTER);
    }
  }
  else
  {
    FillRect(hdc,&rt,backgroundBrush);
  }
  EndPaint(hWnd_, &ps);
  return true;;
}

/**\brief Process WM_MENUSELECT messages
 * \param wmId The outer menu item that was clicked to trigger our menu
 * \param menuFlags Most importantly, whether we have popped up (MF_POPUP)
 * \param hMenu The menu that owns the outer menu item
 * \return boolean indicator of whether the message was processed
 *
 * This method and its subsidiaries that make sure that the various checkable menu
 * items reflect the camera's reported state, and also are used to populate variable-
 * length submenus that depend on dynamic variables (number of known cameras, etc.)
 */
bool C1394CameraDemo::processMenuSelect(int wmId, int menuFlags, HMENU hMenu)
{
  if(menuFlags & MF_POPUP)
  {
    HMENU hSubMenu = GetSubMenu(hMenu,wmId);
    int smID = GetMenuItemID(hSubMenu,0);
    switch(smID)
    {
    case IDM_CAMERA_START:
      return updateCameraMenu(hSubMenu);
      break;
    case IDM_CAMERA_SELECT_0:
      return updateCameraSelectMenu(hSubMenu);
      break;
    case IDM_CAMERA_STREAM_START:
      return updateCameraStreamMenu(hSubMenu);
      break;
    case IDM_CAMERA_TRIGGER_START:
      return updateCameraTriggerMenu(hSubMenu);
      break;
    case IDM_CAMERA_TRIGGER_MODE_START:
      return updateCameraTriggerModeMenu(hSubMenu);
      break;
    case IDM_CAMERA_TRIGGER_INPUT_START:
      return updateCameraTriggerInputMenu(hSubMenu);
      break;
    case IDM_CAMERA_OPTIONAL_START:
      return updateCameraOptionalMenu(hSubMenu);
      break;
    case IDM_FORMAT_MODE_START:
      return updateModeMenu(hSubMenu);
      break;
    case IDM_FRAMERATE_START:
      return updateRateMenu(hSubMenu);
      break;
    case IDM_HELP_START:
      return updateHelpMenu(hSubMenu);
      break;
    default:
      debugPrint("Unknown/Unhandled Submenu with first ID %d",smID);
      break;
    }
  }
  return false;
}

/**\brief Process WM_COMMAND messages within the scope of the IDM_CAMERA menu
 * \param wmId The menu item that was clicked to trigger the command
 * \param wmEvent The event associated with the command
 * \param lParam the Long-Parameter that comes with the command
 * \return boolean indicator of whether the message was processed
 *
 * This method and its subsidiaries that make sure that the various checkable menu
 * items reflect the camera's reported state, and also are used to populate variable-
 * length submenus that depend on dynamic variables (number of known cameras, etc.)
 */
bool C1394CameraDemo::processCameraMenu(int wmId, int wmEvent, LPARAM lParam)
{
  bool processed = true;
  bool updateMainMenu = false;
  int ret;
  C1394CameraControlTrigger *cTrigger = theCamera_.GetCameraControlTrigger();

  // check coherent command blocks first

  // "Select Camera"
  if(wmId >= IDM_CAMERA_SELECT_0 && wmId <= IDM_CAMERA_SELECT_MAX)
  {
    reportCameraError(theCamera_.SelectCamera(wmId - IDM_CAMERA_SELECT_0),
                      "SelectCamera");
    return true;
  }

  // "Trigger->Mode"
  if(wmId >= IDM_CAMERA_TRIGGER_MODE_START && wmId <= IDM_CAMERA_TRIGGER_MODE_END)
  {
    unsigned short mode, param;
    if(!reportCameraError(cTrigger->GetMode(&mode,&param),"ControlTrigger->GetMode"))
    {
      param = 1;
      mode = wmId - IDM_CAMERA_TRIGGER_MODE_START;
      reportCameraError(cTrigger->SetMode(mode,param),"ControlTrigger->SetMode");
    }
    return true;
  }

  // "Trigger->Input"
  if(wmId >= IDM_CAMERA_TRIGGER_INPUT_START && wmId <= IDM_CAMERA_TRIGGER_INPUT_END)
  {
    unsigned short input = wmId - IDM_CAMERA_TRIGGER_INPUT_START;
    reportCameraError(cTrigger->SetTriggerSource(input),"ControlTrigger->SetTriggerSource");
    return true;
  }

  // now check for individual commands in a big switch statement
  switch(wmId)
  {
   case IDM_CAMERA_CHECKLINK:
     theCamera_.RefreshCameraList();
     if(theCamera_.GetNumberCameras() == 0)
     {
       infoBox("1394 Camera Demo", "Check Link: No Cameras Found!");
     } else {
       infoBox("1394 Camera Demo", "Check Link: Found %d Camera%s!",
               theCamera_.GetNumberCameras(),theCamera_.GetNumberCameras() > 1 ? "s" : "");
     }
     break;
   case IDM_CAMERA_INIT:
     ret = theCamera_.InitCamera(askBox("1394CameraDemo","InitCamera: Reset Powerup Defaults?"));
     if(!reportCameraError(ret,"InitCamera"))
     {
       updateWindowDimensions();
       updateMainMenu = true;
     }
     break;
   case IDM_CAMERA_1394B:
     reportCameraError(theCamera_.Set1394b(!theCamera_.Status1394b()),"Set1394b");
     break;
   case IDM_CAMERA_MODEL:
   {
     char name[64];
     char vendor[64];
     LARGE_INTEGER li;
     theCamera_.GetCameraVendor(vendor,sizeof(vendor));
     theCamera_.GetCameraName(name,sizeof(name));
     theCamera_.GetCameraUniqueID(&li);
     infoBox("1394 Camera Demo", "Vendor: %s\nModel: %s\nUniqueID: %016I64x",
             vendor,name,li.QuadPart);
   } break;
   case IDM_CAMERA_MAXSPEED:
   {
     ULARGE_INTEGER uliBufferSize;
     double fBufferSizeMB;
     theCamera_.GetMaxBufferSize(&uliBufferSize);
     fBufferSizeMB = (double)(__int64)uliBufferSize.QuadPart / (double)(1<<20);
     ISOCH_QUERY_RESOURCES iqr;
     GetMaxIsochSpeed((PSTR)theCamera_.GetDevicePath(),&iqr.fulSpeed);
     t1394IsochQueryResources((PSTR)theCamera_.GetDevicePath(),&iqr);

     // * 8 = bytes-to-bits
     // * 8000 = packets per second (1394 bus cycle is 8KHz)
     // / 1000000 = mpbs
     int availableBandwidth_mbps = (iqr.BytesPerFrameAvailable*8*8000)/1000000;

     // Big Info Box!
     infoBox("1394 Camera Demo: Stream Capabilities",
             "Maximum Bus Speed: %d mbps\n"                         \
             "Available Bandwidth: %d bytes per frame (~%dmbps)\n"  \
             "Available Channels (bitmask): %016I64x\n"             \
             "Maximum DMA Buffer: %I64u bytes (%g MB)",
             theCamera_.GetMaxSpeed(),
             iqr.BytesPerFrameAvailable,availableBandwidth_mbps,
             iqr.ChannelsAvailable,
             uliBufferSize.QuadPart,fBufferSizeMB);
   }
   break;

   // caching acq flags
   case IDM_CAMERA_STREAM_SUBSCRIBE:
     acqFlags_ ^= ACQ_SUBSCRIBE_ONLY;
     break;
   case IDM_CAMERA_STREAM_DUAL_PACKET:
     acqFlags_ ^= ACQ_ALLOW_PGR_DUAL_PACKET;
     break;
   case IDM_CAMERA_STREAM_CONTINUOUS:
     acqFlags_ ^= ACQ_START_VIDEO_STREAM;
     break;

   // stream control
   case IDM_CAMERA_STREAM_ONESHOT:
     // oneshot
     reportCameraError(theCamera_.OneShot(),"OneShot");
     break;
   case IDM_CAMERA_STREAM_MULTISHOT:
     getIntegerDialog_.SetTitle("MultiShot Frame Streaming");
     getIntegerDialog_.SetMessageText("How Many Frames to Stream?");

     // real range is 0-65535, but limitations being what they are...
     getIntegerDialog_.SetRange(0,32767);
     getIntegerDialog_.SetValue(5);
     if(IDOK == getIntegerDialog_.run(hWnd_))
     {
       reportCameraError(theCamera_.MultiShot((unsigned short)(getIntegerDialog_.GetValue())),"MultiShot");
     }
     break;

   // Acquisition start/stop
   case IDM_CAMERA_SHOW:
     if (!theCamera_.IsAcquiring())
     {
       if(!reportCameraError(theCamera_.StartImageAcquisitionEx(5,1000,acqFlags_),"StartImageAcquisitionEx"))
       {
	     frameCount_ = 0;
		 dropCount_ = 0;
         updateScrollBarInfo();
		 // clear the framebuffer: otherwise the last image will remain for stop-and-restart
		 memset(frameBuffer_,0,frameBufferSize_);
         InvalidateRect(hWnd_,NULL,FALSE);
         updateMainMenu = true;
       }
     }
     break;
   case IDM_CAMERA_STOP:
     if(theCamera_.IsAcquiring())
     {
       if(!reportCameraError(theCamera_.StopImageAcquisition(),"StopImageAcquisition"))
       {
         updateScrollBarInfo();
         InvalidateRect(hWnd_,NULL,FALSE);
         updateMainMenu = true;
       }
     }
     break;

   // power control
   case IDM_CAMERA_POWER:
     reportCameraError(theCamera_.SetPowerControl(!theCamera_.StatusPowerControl()),"SetPowerControl");
     break;

   // various modeless dialogs
   case IDM_CAMERA_CONTROL_DLG:
     CameraControlDialog(hWnd_,&theCamera_,TRUE);
     break;
   case IDM_CAMERA_TWIDDLE_DLG:
     twiddleDialog_.SetCamera(&theCamera_);
     twiddleDialog_.run(hWnd_);;
     break;

   // "Trigger" submenu
   case IDM_CAMERA_TRIGGER_ACTIVE:
     reportCameraError(cTrigger->SetOnOff(!cTrigger->StatusOnOff()),"ControlTrigger->SetOnOff");
     break;
   case IDM_CAMERA_TRIGGER_POLARITY:
     reportCameraError(cTrigger->SetPolarity(!cTrigger->StatusPolarity()),"ControlTrigger->SetPolarity");
     break;
   case IDM_CAMERA_TRIGGER_PARAMETER_DLG:
   {
     unsigned short mode,param;
     if(!reportCameraError(cTrigger->GetMode(&mode,&param),"ControlTrigger->GetMode"))
     {
       char buf[256];
       unsigned short min = 0,max = 0;

       // get bounds
       dc1394TriggerModeHasParameter(mode,&min,&max);
       // get integer dialog
       getIntegerDialog_.SetTitle("Trigger Parameter Input");
       StringCbPrintf(buf,sizeof(buf),"Enter desired parameter for Trigger\nMode %d (%d..%d)",
                      (int)mode,(int)min,(int)max);
       getIntegerDialog_.SetMessageText(buf);
       getIntegerDialog_.SetRange(min,max);
       getIntegerDialog_.SetValue(param);
       if(IDOK == getIntegerDialog_.run(hWnd_))
       {
         reportCameraError(cTrigger->SetMode(mode,getIntegerDialog_.GetValue()),"ControlTrigger->SetMode");
       } // else fall through: use cancelled
     }
   }
   break;
   case IDM_CAMERA_TRIGGER_SWTRIGGER:
     reportCameraError(cTrigger->DoSoftwareTrigger(),"ControlTrigger->DoSoftwareTrigger");
     break;

   // optional features popups
   case IDM_CAMERA_OPTIONAL_PIO_DLG:
   {
     ULONG ulInput,ulOutput;
     reportCameraError(theCamera_.GetPIOInputBits(&ulInput),"GetPIOInputBits");
     reportCameraError(theCamera_.GetPIOOutputBits(&ulOutput),"GetPIOOutputBits");
     infoBox("Parallel I/O Feature","Camera Has Parallel I/O Controls at 0x%08X\nInput:%08x   Output:%08x",theCamera_.GetPIOControlOffset(),ulInput,ulOutput);
     break;
   }
   case IDM_CAMERA_OPTIONAL_SIO_DLG:
     infoBox("Serial I/O Feature","Camera Has Serial I/O Controls at 0x%08X",theCamera_.GetSIOControlOffset());
     break;
   case IDM_CAMERA_OPTIONAL_STROBE_DLG:
     infoBox("Strobe Feature","Camera Has Strobe Controls at 0x%08X\nNOTE: These Controls are now available in the default Control Dialog",theCamera_.GetStrobeControlOffset());
     break;
   case IDM_CAMERA_OPTIONAL_VENDOR_DLG:
     infoBox("Vendor Unique Features","Camera Has Vendor Unqiue Controls at 0x%08X",theCamera_.GetAdvancedFeatureOffset());
     break;

   // quit!
   case IDM_CAMERA_EXIT:
     if(theCamera_.IsAcquiring())
     {
       reportCameraError(theCamera_.StopImageAcquisition(),"StopImageAcquisition");
     }
     DestroyWindow(hWnd_);
     break;

   // default: I dunno what this is
   default:
     processed = false;
  }

  // many of the above require that the menu changes state depending on various internal status
  if(updateMainMenu)
  {
    // this propagates menu enablement through the camera control menu,
    // which allows keyboard shortcuts to do the right thing
    updateCameraMenu(GetSubMenu(GetMenu(hWnd_),0));
  }

  return processed;
}

/**\brief Map bools to the Win32 CHECKED/ENABLED masks
 * \param theMenu The menu that contains...
 * \param nCmdId The command ID that should be
 * \param active Activated and/or..
 * \param checked Checked
 */
void C1394CameraDemo::updateMenuItem(HMENU theMenu, int nCmdId, bool active, bool checked)
{
  EnableMenuItem(theMenu,nCmdId,MF_BYCOMMAND | (active ? MF_ENABLED : MF_DISABLED | MF_GRAYED));
  CheckMenuItem(theMenu,nCmdId,MF_BYCOMMAND | (checked ? MF_CHECKED : MF_UNCHECKED));
}

/**\brief Map bools to the Win32 mechanisms for disabling a submenu
 * \param theMenu The menu that contains the submenu whose first command ID is...
 * \param nFirstCmdID which should be...
 * \param active (de)activated
 */
void C1394CameraDemo::updateSubMenu(HMENU theMenu, int nFirstCmdID, bool active)
{
  int count = GetMenuItemCount(theMenu);
  for(int ii = 0; ii < count; ++ii)
  {
    if(GetMenuItemID(theMenu,ii) == -1)
    {
      HMENU hSubMenu = GetSubMenu(theMenu,ii);
      if(GetMenuItemID(hSubMenu,0) == (UINT) nFirstCmdID)
      {
        // found, enable the menu accordingly
        EnableMenuItem(theMenu,ii,MF_BYPOSITION | (active ? MF_ENABLED : MF_DISABLED | MF_GRAYED));
        if(active)
        {
          // push downstream
          processMenuSelect(ii,MF_POPUP,theMenu);
        }
        return;
      } // else no match
    } // else not a submenu
  }
}

/**\brief Update the enabled/checked state of the various members of the "Camera" menu
 * \param hCameraMenu The camera menu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateCameraMenu(HMENU hCameraMenu)
{
  updateMenuItem(hCameraMenu,IDM_CAMERA_CHECKLINK,
                 !theCamera_.IsAcquiring(),false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_INIT,
                 theCamera_.GetNode() != -1 && !theCamera_.IsAcquiring(), false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_INIT,
                 theCamera_.GetNode() != -1 && !theCamera_.IsAcquiring(), false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_1394B,
                 !theCamera_.IsAcquiring() && theCamera_.Has1394b(),theCamera_.Status1394b());
  updateMenuItem(hCameraMenu,IDM_CAMERA_MODEL,
                 theCamera_.GetNode() != -1,false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_MAXSPEED,
                 theCamera_.GetNode() != -1,false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_SHOW,
                 theCamera_.IsInitialized() && !theCamera_.IsAcquiring(),false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_STOP,
                 theCamera_.IsAcquiring(),false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_POWER,
                 theCamera_.HasPowerControl(),theCamera_.StatusPowerControl());
  updateMenuItem(hCameraMenu,IDM_CAMERA_CONTROL_DLG,
                 theCamera_.IsInitialized(),false);
  updateMenuItem(hCameraMenu,IDM_CAMERA_TWIDDLE_DLG,
                 theCamera_.IsInitialized(),false);
  updateSubMenu(hCameraMenu,IDM_CAMERA_STREAM_START,
                theCamera_.GetNode() != -1 && theCamera_.IsInitialized());
  updateSubMenu(hCameraMenu,IDM_CAMERA_TRIGGER_START,
                theCamera_.GetNode() != -1 && theCamera_.IsInitialized());
  updateSubMenu(hCameraMenu,IDM_CAMERA_OPTIONAL_START,
                theCamera_.GetNode() != -1 && theCamera_.IsInitialized());
  return false;
}

/**\brief Dynamically update the contents of the "Select Camera" menu with the list of known cameras
 * \param hSubMenu The "select camera" submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateCameraSelectMenu(HMENU hSubMenu)
{
  if(!theCamera_.IsAcquiring())
  {
    // empty the existing menu
    int count = GetMenuItemCount(hSubMenu);
    for(int ii = count - 1; ii >= 0; --ii)
    {
      RemoveMenu(hSubMenu,ii,MF_BYPOSITION);
    }

    // refresh the camera list
    theCamera_.RefreshCameraList();
    count = theCamera_.GetNumberCameras();
    if(IDM_CAMERA_SELECT_0 + count > IDM_CAMERA_SELECT_MAX)
    {
      // todo: warn about ignoring cameras;
      debugPrint("I only support %d cameras in the submenu, but there are %d in all!",
                 IDM_CAMERA_SELECT_MAX - IDM_CAMERA_SELECT_0 + 1,
                 count);
      count = IDM_CAMERA_SELECT_MAX - IDM_CAMERA_SELECT_0 + 1;
    }

    if(count == 0)
    {
      // no cameras: add a grayed-out complainer
      AppendMenu(hSubMenu,MF_GRAYED | MF_DISABLED | MF_STRING, IDM_CAMERA_SELECT_0,"No Cameras Found!");
    } else {
      // populate the menu
      for(int ii = 0; ii < count; ++ii)
      {
        char buf[512];
        StringCbPrintf(buf,512,"%2d: ",ii);
        theCamera_.GetNodeDescription(ii, buf + 4,512 - 5);
        AppendMenu(hSubMenu,MF_ENABLED | MF_STRING | (ii == theCamera_.GetNode() ? MF_CHECKED : 0), IDM_CAMERA_SELECT_0 + ii, buf);
      }
    }
  }
  return false;
}

/**\brief Update the enabled/checked state of the various members of the "Camera->Stream Control" submenu
 * \param hSubMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateCameraStreamMenu(HMENU hSubMenu)
{
  updateMenuItem(hSubMenu,IDM_CAMERA_STREAM_SUBSCRIBE,
                 !theCamera_.IsAcquiring(),(acqFlags_ & ACQ_SUBSCRIBE_ONLY) != 0);
  updateMenuItem(hSubMenu,IDM_CAMERA_STREAM_DUAL_PACKET,
                 !theCamera_.IsAcquiring(),(acqFlags_ & ACQ_ALLOW_PGR_DUAL_PACKET) != 0);
  updateMenuItem(hSubMenu,IDM_CAMERA_STREAM_CONTINUOUS,
                 !theCamera_.IsAcquiring(),(acqFlags_ & ACQ_START_VIDEO_STREAM) != 0);
  updateMenuItem(hSubMenu,IDM_CAMERA_STREAM_ONESHOT,
                 theCamera_.IsAcquiring() && theCamera_.HasOneShot() && (acqFlags_ & ACQ_START_VIDEO_STREAM) == 0,false);
  updateMenuItem(hSubMenu,IDM_CAMERA_STREAM_MULTISHOT,
                 theCamera_.IsAcquiring() && theCamera_.HasMultiShot() && (acqFlags_ & ACQ_START_VIDEO_STREAM) == 0,false);
  return false;
}

/**\brief Update the enabled/checked state of the various members of the "Camera->Trigger" submenu
 * \param hSubMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateCameraTriggerMenu(HMENU hSubMenu)
{
  C1394CameraControlTrigger *trigger = theCamera_.GetCameraControlTrigger();
  if(trigger == NULL || !theCamera_.IsInitialized() || !(trigger->HasPresence()))
  {
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_ACTIVE,false,false);
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_POLARITY,false,false);
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_PARAMETER_DLG,false,false);
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_SWTRIGGER,false,false);
    return false;
  } else {
    unsigned short mode, parameter, source;
    trigger->GetMode(&mode, &parameter);
    trigger->GetTriggerSource(&source);
    bool modeHasParameter = (TRUE == dc1394TriggerModeHasParameter(mode,NULL,NULL));
    bool modeHasSWTrigger = (source == 7);
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_ACTIVE,true,trigger->StatusOnOff());
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_POLARITY,trigger->HasPolarity(),trigger->StatusPolarity());
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_PARAMETER_DLG,modeHasParameter,false);
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_SWTRIGGER,trigger->HasSoftwareTrigger() && modeHasSWTrigger,false);
    return true;
  }
}

/**\brief Update the enabled/checked state of the various members of the "Camera->Trigger->Mode" submenu
 * \param hSubMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateCameraTriggerModeMenu(HMENU hSubMenu)
{
  C1394CameraControlTrigger *trigger = theCamera_.GetCameraControlTrigger();
  unsigned short currentMode = 0xFF, currentParam = 0xFF;
  if(trigger != NULL)
  {
    trigger->GetMode(&currentMode,&currentParam);
  }
  const int validTriggerModes[8] = {0, 1, 2, 3, 4, 5, 14, 15};
  for(int ii = 0; ii < 8; ++ii)
  {
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_MODE_0 + validTriggerModes[ii],
      trigger != NULL && trigger->HasMode(validTriggerModes[ii]),
      trigger != NULL && trigger->HasMode(validTriggerModes[ii]) && currentMode == validTriggerModes[ii]);
  }
  return false;
}

/**\brief Update the enabled/checked state of the various members of the "Camera->Trigger->Input" submenu
 * \param hSubMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateCameraTriggerInputMenu(HMENU hSubMenu)
{
  C1394CameraControlTrigger *trigger = theCamera_.GetCameraControlTrigger();
  unsigned short currentInput = 0xFF;
  if(trigger != NULL)
  {
    trigger->GetTriggerSource(&currentInput);
  }
  const int validTriggerInputs[5] = {0, 1, 2, 3, 7};
  for(int ii = 0; ii < 5; ++ii)
  {
    updateMenuItem(hSubMenu,IDM_CAMERA_TRIGGER_INPUT_0 + validTriggerInputs[ii],
                   trigger != NULL && trigger->HasTriggerSource(validTriggerInputs[ii]),
                   trigger != NULL && trigger->HasTriggerSource(validTriggerInputs[ii]) && currentInput == validTriggerInputs[ii]);
  }
  return false;
}

/**\brief Update the enabled/checked state of the various members of the "Camera->Optional Features" submenu
 * \param hSubMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateCameraOptionalMenu(HMENU hSubMenu)
{
  updateMenuItem(hSubMenu,IDM_CAMERA_OPTIONAL_PIO_DLG,theCamera_.HasPIO(),false);
  updateMenuItem(hSubMenu,IDM_CAMERA_OPTIONAL_SIO_DLG,theCamera_.HasSIO(),false);
  updateMenuItem(hSubMenu,IDM_CAMERA_OPTIONAL_STROBE_DLG,theCamera_.HasStrobe(),false);
  updateMenuItem(hSubMenu,IDM_CAMERA_OPTIONAL_VENDOR_DLG,theCamera_.HasAdvancedFeature(),false);
  return false;
}

/**\brief Update the enabled/checked state of the format/mode menu
 * \param hModeMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateModeMenu(HMENU hModeMenu)
{
  bool camReady = theCamera_.IsInitialized() && !theCamera_.IsAcquiring();
  int currentFormat = theCamera_.GetVideoFormat();
  int currentMode = theCamera_.GetVideoMode();
  int count = GetMenuItemCount(hModeMenu);
  for(int ii = 0; ii < count; ++ii)
  {
    int id = GetMenuItemID(hModeMenu,ii);
    if(id >= IDM_FORMAT_MODE_START && id <= IDM_FORMAT_MODE_END)
    {
      int format = FORMAT_FROM_ID(id);
      int mode = MODE_FROM_ID(id);
      bool itemActive = camReady && theCamera_.HasVideoFormat(format) && (format == 7 || theCamera_.HasVideoMode(format,mode));
      bool itemChecked = theCamera_.IsInitialized() && format == currentFormat && (format == 7 || mode == currentMode);
      CheckMenuItem(hModeMenu,ii,MF_BYPOSITION | (itemChecked ? MF_CHECKED : MF_UNCHECKED));
      EnableMenuItem(hModeMenu,ii,MF_BYPOSITION | (itemActive ? MF_ENABLED : MF_DISABLED | MF_GRAYED));
    }
  }
  return true;
}

/**\brief Update the enabled/checked state of the frame rate menu
 * \param hRateMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateRateMenu(HMENU hRateMenu)
{
  bool camReady = theCamera_.IsInitialized() && !theCamera_.IsAcquiring();
  int currentFormat = theCamera_.GetVideoFormat();
  int currentMode = theCamera_.GetVideoMode();
  int currentRate = theCamera_.GetVideoFrameRate();
  int count = GetMenuItemCount(hRateMenu);
  for(int ii = 0; ii < count; ++ii)
  {
    int id = GetMenuItemID(hRateMenu,ii);
    if(id >= IDM_FRAMERATE_START && id <= IDM_FRAMERATE_END)
    {
      int rate = FRAMERATE_FROM_ID(id);
      bool itemActive = camReady && currentFormat != 7 && theCamera_.HasVideoFrameRate(currentFormat,currentMode,rate);
      bool itemChecked = theCamera_.IsInitialized() && currentFormat != 7 && rate == currentRate;
      CheckMenuItem(hRateMenu,ii,MF_BYPOSITION | (itemChecked ? MF_CHECKED : MF_UNCHECKED));
      EnableMenuItem(hRateMenu,ii,MF_BYPOSITION | (itemActive ? MF_ENABLED : MF_DISABLED | MF_GRAYED));
    }
  }
  return true;
}

/**\brief Update the enabled/checked state of the help menu
 * \param hHelpMenu The submenu
 * \return boolean success (these all seem to be false: do we use this retval, should it be void?)
 */
bool C1394CameraDemo::updateHelpMenu(HMENU hHelpMenu)
{
  // express debug-output-enabled state here
  CheckMenuItem(hHelpMenu,IDM_HELP_DEBUG_DEMO,MF_BYCOMMAND | (enableDebugOutput_ ? MF_CHECKED : MF_UNCHECKED));
  return true;
}

/**\brief Actually paint the active frame buffer
 * \param hdc The Device Context to paint into
 */
void C1394CameraDemo::drawFrameBuffer(HDC hdc)
{
  RECT rt,tmp;
  BITMAPINFO bmi;
  unsigned long wd,ht,xx=0,yy=0;
  int xOffset, yOffset;
  getScrollPosition(xOffset,yOffset);
  theCamera_.GetVideoFrameDimensions(&wd,&ht);
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = (long) wd;
  bmi.bmiHeader.biHeight = (long) ht;
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 24;
  bmi.bmiHeader.biCompression = BI_RGB;
  bmi.bmiHeader.biSizeImage = 0;
  bmi.bmiHeader.biXPelsPerMeter = 1000;
  bmi.bmiHeader.biYPelsPerMeter = 1000;
  bmi.bmiHeader.biClrUsed = 0;
  bmi.bmiHeader.biClrImportant = 0;

  GetClientRect(hWnd_,&rt);

  // handle centering the image and filling the perimeter with APPWORKSPACE
  HBRUSH marginBrush = GetSysColorBrush(COLOR_APPWORKSPACE);
  if(rt.right > (LONG) wd)
  {
    xx = (rt.right - wd) >> 1;
    tmp.left = 0;
    tmp.top = -1;
    tmp.bottom = rt.bottom;
    tmp.right = xx;
    FillRect(hdc,&tmp,marginBrush);
    tmp.left = xx + wd;
    tmp.right = rt.right;
    FillRect(hdc,&tmp,marginBrush);

	if(enableDebugOutput_)
	{
		char buf[256];
		if(S_OK == StringCbPrintf(buf,sizeof(buf),"\n Frames:\n  %d\n\n Drops:\n  %d\n\n Rate:\n  ?? fps",
			frameCount_,dropCount_))
		{
			SetBkColor(hdc,GetSysColor(COLOR_APPWORKSPACE));
			DrawText(hdc, buf, -1, &tmp, DT_LEFT | DT_VCENTER);
		}
	}
  } else {
    if(rt.right < (LONG) wd)
    {
      // must be scrolling, use the offset
      xx = -xOffset;
    } else {
      // precise fit: xx = 0;
      xx = 0;
    }
  }

  if(rt.bottom > (LONG) ht)
  {
    yy = (rt.bottom - ht) >> 1;
    tmp.left = xx;
    tmp.top = 0;
    tmp.bottom = yy;
    tmp.right = xx + wd;
    FillRect(hdc,&tmp,marginBrush);
    tmp.top = yy + ht;
    tmp.bottom = rt.bottom;
    FillRect(hdc,&tmp,marginBrush);
  } else {
    if(rt.bottom < (LONG) ht)
    {
      // must be scrolling, use the offset
      yy = -yOffset;
    } else {
      // precise fit: yy = 0;
      yy = 0;
    }
  }

  // actually paint the bits
  SetDIBitsToDevice(hdc, xx, yy, wd, ht, 0, 0, 0, ht, frameBuffer_, &bmi, DIB_RGB_COLORS);
}

/**\brief Encode the policy of maintaining a minimum window size and updating the scroll info on WM_SIZE
 */
void C1394CameraDemo::updateWindowDimensions()
{
  // Minimum size is 240x240: anything smaller starts to mess with menus
  const int minW = 240;
  const int minH = 240;

  // lookup the current desktop, window, and client area rects
  RECT dr,wr,cr;
  GetWindowRect(GetDesktopWindow(),&dr);
  GetWindowRect(hWnd_,&wr);
  GetClientRect(hWnd_,&cr);

  // difference between client and window rects give us decoration (menu, etc) sizes
  int ww = wr.right - wr.left - cr.right;
  int hh = wr.bottom - wr.top - cr.bottom;

  // get camera frame dimensions
  unsigned long wd,ht;
  theCamera_.GetVideoFrameDimensions(&wd,&ht);

  debugPrint("updateWindowDimensions: Desktop(%dx%d), Window(%d,%d), Client(%d,%d), Frame(%u,%u)",
             dr.right,dr.bottom,wr.right-wr.left,wr.bottom - wr.top,cr.right,cr.bottom,wd,ht);
  // cache framebuffer size
  unsigned long bufsize = wd * ht * 3;

  const unsigned int maxW = dr.right - ww;
  const unsigned int maxH = dr.bottom - hh;

  // impose min, max
  if(wd < minW) wd = minW;
  if(wd > maxW) wd = maxW;

  if(ht < minH) ht = minH;
  if(ht > maxH) ht = maxH;

  // do our best to not resize off the screen
  int xx = wr.left;
  int yy = wr.top;

  if( xx + (int)wd + ww > dr.right )
  {
    xx = dr.right - wd - ww;
  }

  if( yy + (int)ht + hh > dr.bottom )
  {
    yy = dr.bottom - ht - hh;
  }

  debugPrint("  -> %dx%d+%d+%d",wd+ww,ht+hh,xx,yy);
  SetWindowPos(hWnd_,NULL,xx,yy,wd + ww,ht + hh,SWP_NOZORDER);

  if(bufsize != frameBufferSize_ || frameBuffer_ == NULL)
  {
    if(frameBuffer_ == NULL)
    {
      LocalFree(frameBuffer_);
      frameBuffer_ = NULL;
      frameBufferSize_ = 0;
    }
    frameBufferSize_ = bufsize;
    frameBuffer_ = (unsigned char *)LocalAlloc(LPTR,bufsize);
  }
  updateScrollBarInfo(true);
}

/**\brief Utility for popping up an informative dialog box using printf-style formatting
 * \param title The title for the dialog (static)
 * \param format The format string (variadic)
 */
void C1394CameraDemo::infoBox(const char *title, const char *format, ...)
{
  char buf[512];
  va_list vlist;
  va_start(vlist,format);
  StringCbVPrintf(buf,sizeof(buf),format,vlist);
  MessageBox(hWnd_,buf,title,MB_OK|MB_ICONINFORMATION);
}

/**\brief Utility for popping up an querulous dialog box using printf-style formatting
 * \param title The title for the dialog (static)
 * \param format The format string (variadic)
 * \return boolean assent from the user (true = yes, false = no/cancel)
 */
bool C1394CameraDemo::askBox(const char *title, const char *format, ...)
{
  char buf[512];
  va_list vlist;
  va_start(vlist,format);
  StringCbVPrintf(buf,sizeof(buf),format,vlist);
  return (IDYES == MessageBox(hWnd_,buf,title,MB_YESNO|MB_ICONQUESTION));
}

/**\brief Utility for popping up an erroneous dialog box using printf-style formatting
 * \param title The title for the dialog (static)
 * \param format The format string (variadic)
 */
void C1394CameraDemo::errorBox(const char *title, const char *format, ...)
{
  char buf[512];
  va_list vlist;
  va_start(vlist,format);
  StringCbVPrintf(buf,sizeof(buf),format,vlist);
  MessageBox(hWnd_,buf,title,MB_OK|MB_ICONERROR);
}

/**\brief Encapsulate the policy for showing and scaling vertical and horizontal scroll bars
 * \param center Whether the virtual client area should be re-set to be centered (default = false)
 * \note: given setVirtualClientArea(), this could be extracted into a separate class
 */
void C1394CameraDemo::updateScrollBarInfo(bool center)
{
  // scrollbars steal space when activated: cache these here for use below
  SCROLLBARINFO sbi;
  sbi.cbSize = sizeof(SCROLLBARINFO);
  hScrollActive_ = FALSE;
  vScrollActive_ = FALSE;
  unsigned long fbw,fbh;

  if(theCamera_.IsAcquiring())
  {
    theCamera_.GetVideoFrameDimensions(&fbw,&fbh);
  }
  else if(enableDebugOutput_)
  {
    fbw = 640;
    fbh = 480;
  } else {
    // by default, 0x0 so the scrollbars are disabled
    fbw = fbh = 0;
  }

  // get client rect to determine drawing area
  RECT cr;
  GetClientRect(hWnd_,&cr);
  int cw = cr.right - cr.left;
  int ch = cr.bottom - cr.top;

  // adjust client rect to account for current scrollbar vis
  GetScrollBarInfo(hWnd_,OBJID_HSCROLL,&sbi);
  if(!(sbi.rgstate[0] & STATE_SYSTEM_INVISIBLE))
  {
    // hscroll visible, underlying client rect is taller
    ch += sbi.dxyLineButton;
  }

  GetScrollBarInfo(hWnd_,OBJID_VSCROLL,&sbi);
  if(!(sbi.rgstate[0] & STATE_SYSTEM_INVISIBLE))
  {
    // vscroll visible, underlying client rect is wider
    cw += sbi.dxyLineButton;
  }

  // now compute the margins as though the scrollbars weren't there
  int hDelta = cw - fbw;
  int vDelta = ch - fbh;

  debugPrint("updateScrollInfo: Client %dx%d, FrameBuffer %dx%d",cw,ch,fbw,fbh);

  // check width first
  if(hDelta < 0)
  {
    hScrollActive_ = TRUE;
    ShowScrollBar(hWnd_,SB_HORZ,TRUE);

    // account for hscroll height in vDelta
    GetScrollBarInfo(hWnd_,OBJID_HSCROLL,&sbi);
    vDelta -= sbi.dxyLineButton;
  }

  if(vDelta < 0)
  {
    vScrollActive_ = TRUE;
    ShowScrollBar(hWnd_,SB_VERT,TRUE);

    // account for vScroll width in hDelta
    GetScrollBarInfo(hWnd_,OBJID_VSCROLL,&sbi);
    hDelta -= sbi.dxyLineButton;

    // and double-check that we don't need to light up hScroll as well
    if(hDelta < 0 && hScrollActive_ == FALSE)
    {
      hScrollActive_ = TRUE;
      ShowScrollBar(hWnd_,SB_HORZ,TRUE);

      // vDelta update again, we need it to set scroll info below
      GetScrollBarInfo(hWnd_,OBJID_HSCROLL,&sbi);
      vDelta -= sbi.dxyLineButton;
    }
  }

  // these should be encapsulated in a mini-method
  if(hScrollActive_ == TRUE)
  {
    SCROLLINFO sih;
    sih.cbSize = sizeof(SCROLLINFO);
    sih.fMask = SIF_ALL;
    GetScrollInfo(hWnd_,SB_VERT,&sih);
    sih.nMax = -hDelta;
    sih.nMin = 0;
    if(sih.nPos < sih.nMin)
    {
      sih.nPos = sih.nMin;
    }

    if(sih.nPos > sih.nMax)
    {
      sih.nPos = sih.nMax;
    }

    sih.nPage = 5;
    if(center)
    {
      sih.nPos = sih.nMax >> 1;
    }

    sih.nTrackPos = sih.nPos;
    SetScrollInfo(hWnd_,SB_HORZ,&sih,ESB_ENABLE_BOTH);
    debugPrint(" -> HSCROLL: %d in [%d -> %d]\n",sih.nPos,sih.nMin,sih.nMax);
  } else {
    ShowScrollBar(hWnd_,SB_HORZ,FALSE);
  }

  if(vScrollActive_ == TRUE)
  {
    SCROLLINFO siv;
    siv.cbSize = sizeof(SCROLLINFO);
    siv.fMask = SIF_ALL;
    GetScrollInfo(hWnd_,SB_VERT,&siv);
    siv.nMax = -vDelta;
    siv.nMin = 0;
    if(siv.nPos < siv.nMin)
    {
      siv.nPos = siv.nMin;
    }

    if(siv.nPos > siv.nMax)
    {
      siv.nPos = siv.nMax;
    }

    if(center)
    {
      siv.nPos = siv.nMax >> 1;
    }
    siv.nPage = 5;
    siv.nTrackPos = siv.nPos;
    SetScrollInfo(hWnd_,SB_VERT,&siv,ESB_ENABLE_BOTH);
    debugPrint(" -> VSCROLL: %d in [%d -> %d]\n",siv.nPos,siv.nMin,siv.nMax);
  } else {
    ShowScrollBar(hWnd_,SB_VERT,FALSE);
  }
}

/**\brief Accessor for current scroll offset
 * \param xx X position (out by reference)
 * \param yy Y position (out by reference)
 */
void C1394CameraDemo::getScrollPosition(int &xx, int &yy)
{
  SCROLLINFO si;
  si.cbSize = sizeof(SCROLLINFO);
  si.fMask = SIF_ALL;

    if(hScrollActive_)
    {
        GetScrollInfo(hWnd_,SB_HORZ,&si);
        xx = si.nPos;
    } else {
        xx = 0;
    }

    if(vScrollActive_)
    {
        GetScrollInfo(hWnd_,SB_VERT,&si);
        yy = si.nPos;
    } else {
        yy = 0;
    }
}

/**\brief Mutator for current scroll offset
 * \param xx X position
 * \param yy Y position
 */
void C1394CameraDemo::setScrollPosition(int xx, int yy)
{
  if(hScrollActive_)
  {
    SCROLLINFO sih;
    sih.cbSize = sizeof(SCROLLINFO);
    sih.fMask = SIF_ALL;

    GetScrollInfo(hWnd_,SB_HORZ,&sih);
    if(xx < sih.nMin)
      xx = sih.nMin;
    if(xx > sih.nMax)
      xx = sih.nMax;
    sih.nPos = xx;

    SetScrollInfo(hWnd_,SB_HORZ,&sih,TRUE);
  }

  if(vScrollActive_)
  {
    SCROLLINFO siv;
    siv.cbSize = sizeof(SCROLLINFO);
    siv.fMask = SIF_ALL;

    GetScrollInfo(hWnd_,SB_VERT,&siv);
    if(yy < siv.nMin)
      yy = siv.nMin;
    if(yy > siv.nMax)
      yy = siv.nMax;

    siv.nPos = yy;

    SetScrollInfo(hWnd_,SB_VERT,&siv,TRUE);
  }
}

/**\brief Encapsulate the formatting of a useful error dialog for a camera error
 * \param retval The return code to check from the C1394Camera class
 * \param msg A short (static) message that will be associated with the error
 * \return boolean indication of whether retval is successful (true) or erroneous(false)
 *
 * For any erroneous version of retval, this will format and pop up a dialog box that shows:
 *  - The message you specify,
 *  - The stringified error from C1394Camera, and, if the error is CAM_ERROR or ..._INSUFFICIENT_RESOURCES,
 *  - The stringified error from the Windows I/O subsystem
 *
 * The intent here is to basically wrap all calls into C1394Camera with this method so we actually catch and
 * report errors in a useful way
 */
bool C1394CameraDemo::reportCameraError(int retval, const char *msg)
{
  if(retval != CAM_SUCCESS)
  {
    if(retval == CAM_ERROR ||
       retval == CAM_ERROR_INSUFFICIENT_RESOURCES)
    {
      // win32 strerror equivalent
      char buf[256];
      FormatMessage(
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        GetLastError(),
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
        (LPTSTR) &buf,
        256,
        NULL );

      errorBox("C1394Camera Error","%s: %s\r\nSystem Error %d: %s",
          msg,CameraErrorString(retval),GetLastError(),buf);
    } else {
      errorBox("C1394Camera Error","%s: %s",
          msg,CameraErrorString(retval));
    }
    // had an error, return true to allow actions to be triggered on error
    return true;
  } else {
    //  no error, return false;
    return false;
  }
}

/**\brief Encapsulate the lookup of the install path and the execution of the help browser
 */
void C1394CameraDemo::launchHelpBrowser()
{
  char buf[512];
  HKEY hCSK = OpenCameraSettingsKey(NULL,0,KEY_READ);
  DWORD dwSize = 512, dwType = REG_SZ;
  LONG lRet;

  if(hCSK != NULL)
  {
    if((lRet = RegQueryValueEx(hCSK,"InstallPath",NULL,&dwType,(LPBYTE)buf,&dwSize)) == ERROR_SUCCESS)
    {
      if(dwType == REG_SZ)
      {
        buf[dwSize] = 0;
        debugPrint("launchHelpBrowser: read InstallPath as %s",buf);
        StringCbPrintf(buf + dwSize - 1,512-dwSize,"\\1394camera.chm");
        debugPrint("  -> opening '%s'",buf);
        ShellExecute(hWnd_,"open",buf,NULL,NULL,SW_SHOWNORMAL);
      } else {
        debugPrint("  -> InstallPath not a REG_SZ (%d instead)",dwType);
      }
    }
  }
}


/**\brief a Simple printf-er to the debug console (simpler, pre-VC7 version)
 * \param format The printf-style format
 *
 * Why doesn't windows provide one of these by default?
 */
void C1394CameraDemo::_debugPrint(const char *format, ...)
{
  if(enableDebugOutput_)
  {
    char buf[2048] = "1394CameraDemo: DEBUG : ";
    va_list ap;
    va_start(ap, format);
    StringCbVPrintf(buf + 16, sizeof(buf) - 16, format, ap);
    OutputDebugString(buf);
    va_end(ap);
  }
}

/**\brief a Simple printf-er to the debug console (extended, post-VC7 version)
 * \param filename use with __FILE__
 * \param line use with __LINE__
 * \param format The printf-style format
 *
 * Why doesn't windows provide one of these by default?
 */
void C1394CameraDemo::__debugPrint(const char *filename, int line, const char *format, ...)
{
  if(enableDebugOutput_)
  {
    char buf[2048];
    const char *trimmedfilename = (filename[0] == '.' ? filename + 2 : filename);
    StringCbPrintf(buf,sizeof(buf), "1394CameraDemo: DEBUG : %15s:%d: ", trimmedfilename, line);
    size_t preamble = 0;
    StringCbLength(buf,sizeof(buf),&preamble);
    va_list ap;
    va_start(ap, format);
    StringCbVPrintf(buf + preamble, sizeof(buf) - preamble, format, ap);
    OutputDebugString(buf);
    va_end(ap);
  }
}
