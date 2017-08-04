/**\file TwiddleDialog.h
 * \brief Declares the TwiddleDialog class
 * \ingroup win32demo
 */
#ifndef __TWIDDLE_DIALOG_H__
#define __TWIDDLE_DIALOG_H__

#include "BasicModalDialog.h"
#include <1394Camera.h>

/**\brief Provide a dialog for users to directly read/write arbitrary camera registers
 * \ingroup win32demo
 */
class TwiddleDialog : public BasicModalDialog
{
public:
  TwiddleDialog(HINSTANCE hInstance);
  virtual ~TwiddleDialog() {}

  void SetCamera(C1394Camera *theCamera) {theCamera_ = theCamera;}
protected:
  // override BasicModalDialog virtual interface
  virtual bool ProcessMessage(HWND hDialog, UINT uMessage, WPARAM wParam, LPARAM lParam);

private:
  C1394Camera *theCamera_;
};

#endif // __TWIDDLE_DIALOG_H__
