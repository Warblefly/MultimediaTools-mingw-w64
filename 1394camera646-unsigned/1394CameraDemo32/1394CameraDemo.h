/**\file      1394CameraDemo.h
 * \author    Christopher R. Baker
 * \date      02/13/2011
 * \brief     Win32-native demo application - declaration
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
#ifndef __1394_CAMERA_DEMO_H__
#define __1394_CAMERA_DEMO_H__

#include <windows.h>
#include <1394Camera.h>

#include "BasicModalDialog.h"
#include "GetIntegerDialog.h"
#include "TwiddleDialog.h"
#include <resource.h>

#define MAX_LOADSTRING 256

#if _MSC_VER >= 1300
// VS7+ supports variadic macros that we can use to cleanly inject file/line numbers
#define debugPrint(FMT,...) __debugPrint(__FILE__, __LINE__ , FMT, __VA_ARGS__)
#else
// VS6- doesn't support variadic macros, so we don't get file/line numbers in the output
#define debugPrint _debugPrint
#endif

/**\brief Win32-native demo application
 * \ingroup win32demo
 */
class C1394CameraDemo
{
public:
  C1394CameraDemo(HINSTANCE hInstance);
  virtual ~C1394CameraDemo();

  // singleton accessor
  static C1394CameraDemo &get();

  bool initialize(int nCmdShow);
  bool run();
  void cleanup();

  LRESULT WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

protected:

  // Initialization and cleanup
  bool registerWindowClass();
  bool createWindowInstance(int nCmdShow);

  bool processCommand(int wmId, int wmEvent, LPARAM lParam);
  bool processMenuSelect(int wmId, int menuFlags, HMENU hMenu);
  bool processPaint();

  // Specific menu handlers
  bool processCameraMenu(int wmId, int wmEvent, LPARAM lParam);

  bool updateCameraMenu(HMENU hCameraMenu);
  bool updateCameraSelectMenu(HMENU hSubmenu);
  bool updateCameraStreamMenu(HMENU hSubMenu);
  bool updateCameraTriggerMenu(HMENU hSubMenu);
  bool updateCameraTriggerModeMenu(HMENU hSubMenu);
  bool updateCameraTriggerInputMenu(HMENU hSubMenu);
  bool updateCameraOptionalMenu(HMENU hSubMenu);
  bool updateModeMenu(HMENU hCameraMenu);
  bool updateRateMenu(HMENU hCameraMenu);
  bool updateHelpMenu(HMENU hHelpMenu);

  // Utilities
  void drawFrameBuffer(HDC hDC);
  void updateWindowDimensions();
  void updateMenuItem(HMENU theMenu, int nCmdId, bool active, bool checked);
  void updateSubMenu(HMENU theMenu, int nFirstCmdID, bool active);
  void launchHelpBrowser();

  // Message Boxery
  void infoBox(const char *title, const char *format, ...);
  bool askBox(const char *title, const char *format, ...);
  void errorBox(const char *title, const char *format, ...);
  bool reportCameraError(int retval, const char *msg);

  // Scroll Magickery
  void updateScrollBarInfo(bool center = false);
  void getScrollPosition(int &xx, int &yy);
  void setScrollPosition(int xx, int yy);

  // Debug Tracery
  void _debugPrint(const char *format, ...);
  void __debugPrint(const char *file, int line, const char *format, ...);

private:
  C1394Camera theCamera_;  ///< The one and only camera instance for this app

  // Windows interface stuff
  HINSTANCE hInst_;
  HWND hWnd_;
  ATOM classAtom_;
  TCHAR szTitle_[MAX_LOADSTRING];
  TCHAR szWindowClass_[MAX_LOADSTRING];

  // Utility members for scrolling and mouse movement
  BOOL hScrollActive_, vScrollActive_, mouseScrollActive_;
  int xMouseDown_, yMouseDown_;

  int acqFlags_; ///< the currently selected set of acquisition flags
  unsigned char *frameBuffer_;  ///< the currently allocated framebuffer
  unsigned int frameBufferSize_;///< the size of the currently allocated framebuffer
  unsigned int frameCount_;
  unsigned int dropCount_;

  // Utility Dialogs
  GetIntegerDialog getIntegerDialog_;
  TwiddleDialog twiddleDialog_;
  BasicModalDialog aboutDialog_;

  bool enableDebugOutput_;   ///< Toggle debug behavior intrinsic to the demo
};

#endif
