/**\file GetIntegerDialog.h
 * \brief Declares GetIntegerDialog class for querying user input
 * \ingroup win32demo
 */
#ifndef __GET_INTEGER_DIALOG_H__
#define __GET_INTEGER_DIALOG_H__

#include "BasicModalDialog.h"

/**\brief Provide a dialog that querys users for a number
 * \ingroup win32demo
 *
 * It's sad that Win32 doesn't have an array of handy little dialogs like this...
 */
class GetIntegerDialog : public BasicModalDialog
{
public:
  GetIntegerDialog(HINSTANCE hInstance);
  virtual ~GetIntegerDialog() {}

  void SetRange(short min, short max);
  void SetValue(short value);

  short GetValue();

  void SetTitle(const char *title);
  void SetMessageText(const char *message);

protected:
  // override BasicModalDialog virtual interface
  virtual bool ProcessMessage(HWND hDialog, UINT uMessage, WPARAM wParam, LPARAM lParam);

private:
  short min_,max_,value_;
  char title_[512];
  char message_[512];
};

#endif // __GET_INTEGER_DIALOG_H__
