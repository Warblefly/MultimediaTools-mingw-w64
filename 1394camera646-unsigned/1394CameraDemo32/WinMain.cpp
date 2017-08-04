/**\file      WinMain.cpp
 * \author    Christopher R. Baker
 * \date      02/13/2011
 * \brief     The WinMain entry point that redirects to the Demo class instance
 * \ingroup   win32demo
 */
#include "1394CameraDemo.h"

int APIENTRY WinMain(HINSTANCE hInstance,
                     HINSTANCE hPrevInstance,
                     LPSTR     lpCmdLine,
                     int       nCmdShow)
{
  C1394CameraDemo theDemo(hInstance);
  theDemo.initialize(nCmdShow);
  theDemo.run();
  return 0;
}
