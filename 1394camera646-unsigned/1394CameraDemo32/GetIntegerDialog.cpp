/**\file GetIntegerDialog.cpp
 * \brief Implements GetIntegerDialog class for querying user input
 * \ingroup win32demo
 */
#include "GetIntegerDialog.h"
#include "resource.h"

#include <strsafe.h>
#include <commctrl.h>

/**\brief Construct a GetIntegerDialog
 *
 * This sets some default min and max values that indicate failure-to-initialize
 */
GetIntegerDialog::GetIntegerDialog(HINSTANCE hInstance):
  BasicModalDialog(hInstance,MAKEINTRESOURCE(IDD_GETINTEGER)),
  min_(-27),
  max_(33),
  value_(-4)
{
  SetTitle("Foobnutter");
  SetMessageText("All your base are\n belong to us!!!");
}

/**\brief Mutate the range of the integer you're about to get
 * \param min The minimum value
 * \param max The maximum value
 */
void GetIntegerDialog::SetRange(short min, short max)
{
  min_ = min;
  max_ = max;
}

/**\brief Mutate the default value of the integer you're about to get
 * \param value The default value to set
 */
void GetIntegerDialog::SetValue(short value)
{
  value_ = value;
}

/**\brief Access the value that was set
 * \return the value that was set
 */
short GetIntegerDialog::GetValue()
{
  return value_;
}

/**\brief Set the title of the dialog
 * \param title The title to set
 *
 * Note: this will truncate at 512 chars (sizeof(title_));
 */
void GetIntegerDialog::SetTitle(const char *title)
{
  StringCbCopy(title_,sizeof(title_),title);
}

/**\brief Set the message text for the dialog
 * \param message The message to set
 *
 * Note: this will truncate at 512 chars (sizeof(message_));
 */
void GetIntegerDialog::SetMessageText(const char *message)
{
  StringCbCopy(message_,sizeof(message_),message);
}

/**\brief Process messages
 *
 * Here, we set title, text, range and default value on WM_INITDIALOG,
 * and capture the value from the spinbox on COMMAND/OK
 */
bool GetIntegerDialog::ProcessMessage(HWND hDialog, UINT uMessage, WPARAM wParam, LPARAM lParam)
{
  // BasicModalDialog::ProcessMessage is a no-op, so we don't have to call down to it

  if(uMessage == WM_INITDIALOG)
  {
    SetWindowText(hDialog,title_);
    SetDlgItemText(hDialog,IDC_MESSAGE_TEXT,message_);
    SendDlgItemMessage(hDialog,IDC_THE_INTEGER_SPIN,UDM_SETRANGE,0,(LPARAM)MAKELONG(max_,min_));
    SendDlgItemMessage(hDialog,IDC_THE_INTEGER_SPIN,UDM_SETPOS,0,(LPARAM)MAKELONG(value_,0));
    HWND hEditBox = GetDlgItem(hDialog,IDC_THE_INTEGER);
    if(hEditBox != NULL)
    {
      SetFocus(hEditBox);
      return false;
    }
    return true;
  }

  if(uMessage == WM_COMMAND)
  {
    if(LOWORD(wParam) == IDOK)
    {
      LRESULT lResult = SendDlgItemMessage(hDialog,IDC_THE_INTEGER_SPIN,UDM_GETPOS,0,0);
      if(HIWORD(lResult) == 0)
      {
        value_ = LOWORD(lResult);
      } // else failed to get value, or out of range
    } // else cancel, leave as default
  }

  // fall through and return false here, even if we process the command, to let BasicModalDialog close
  // on IDOK or IDCANCEL
  return false;
}
