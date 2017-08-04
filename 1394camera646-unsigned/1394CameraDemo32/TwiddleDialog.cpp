/**\file TwiddleDialog.cpp
 * \brief Implements TwiddleDialog class for manipulating camera registers directly
 * \ingroup win32demo
 */
#include "TwiddleDialog.h"
#include "resource.h"

#include <strsafe.h>
#include <commctrl.h>

/**\brief Construct a TwiddleDialog
 *
 * Nothing to see here, just specializing BasicModalDialog to use IDD_TWIDDLE
 */
TwiddleDialog::TwiddleDialog(HINSTANCE hInstance):
  BasicModalDialog(hInstance,MAKEINTRESOURCE(IDD_TWIDDLE)),
  theCamera_ (NULL)
{
}

/**\brief Process command messages
 *
 * The whole purpose of this dialog is to interactively poke registers: no state is saved other
 * than what is written to the camera.
 */
bool TwiddleDialog::ProcessMessage(HWND hDialog, UINT uMessage, WPARAM wParam, LPARAM lParam)
{
  // BasicModalDialog::ProcessMessage is a no-op, so we don't have to call down to it

  if(uMessage == WM_INITDIALOG)
  {
    UDACCEL uda;

    uda.nSec = 0;
    uda.nInc = 4;

    // note: commented-out segments retained for now
    // the principal problem is the the handy-dandy spinbox doesn't go all the way up to 0xffffffff
    // this is okay for the address (we'll just interpret 0x7 as 0xF for the leading 4 bits), but
    // we may want to validly set the high bit on the data field

    SetWindowText(hDialog,"Twiddling my registers, eh?");
    SendDlgItemMessage(hDialog,IDC_ADDRESS_SPIN,UDM_SETBASE,16,0);
    //SendDlgItemMessage(hDialog,IDC_DATA_SPIN,UDM_SETBASE,16,0);
    SendDlgItemMessage(hDialog,IDC_ADDRESS_SPIN,UDM_SETRANGE32,(WPARAM)0,(LPARAM)0x7FFFFFFF);
    //SendDlgItemMessage(hDialog,IDC_DATA_SPIN,UDM_SETRANGE32,(WPARAM)0x80000000,(LPARAM)0x7FFFFFFF);
    SendDlgItemMessage(hDialog,IDC_ADDRESS_SPIN,UDM_SETPOS32,0,(LPARAM)0x100);
    //SendDlgItemMessage(hDialog,IDC_DATA_SPIN,UDM_SETPOS32,0,(LPARAM)0xBAADF00D);
    SendDlgItemMessage(hDialog,IDC_ADDRESS_SPIN,UDM_SETACCEL,1,(LPARAM)(&uda));
    SetDlgItemText(hDialog,IDC_EDIT_DATA,"0xBAADF00D");

    HWND hEditBox = GetDlgItem(hDialog,IDC_EDIT_ADDRESS);
    if(hEditBox != NULL)
    {
      SetFocus(hEditBox);
      return false;
    }
    return true;
  }

  if(uMessage == WM_COMMAND)
  {
    if(LOWORD(wParam) == IDC_REGREAD || LOWORD(wParam) == IDC_REGWRITE)
    {
      // actually do the read or write
      char buf[32];
      unsigned long ulAddress = (unsigned long)SendDlgItemMessage(hDialog,IDC_ADDRESS_SPIN,UDM_GETPOS32,0,0);
      unsigned long ulData = 0;

      // hackhack: spinbox control (even with Set/Getg32) doesn't
      // let us go beyond 7FFFFFFF because it assumes a signed int
      // so... lets just force to 0xF... if anything in the high 4 is lit
      if(ulAddress & 0x70000000)
      {
        ulAddress |= 0xF0000000;
      }

      if(LOWORD(wParam) == IDC_REGREAD)
      {
        // read and format
        theCamera_->ReadQuadlet(ulAddress,&ulData);
        StringCbPrintf(buf,sizeof(buf),"0x%08X",ulData);
        SetDlgItemText(hDialog,IDC_EDIT_DATA,buf);
      } else {
        bool goodFormat = true;
        GetDlgItemText(hDialog,IDC_EDIT_DATA,buf,sizeof(buf));

        // poor-mans snscanf that will read 0x[0-9,A-F,a-f]*

        if(buf[0] == '0' && buf[1] == 'x' && buf[10] == 0)
        {
          for(int ii = 2; ii<10 && goodFormat; ++ii)
          {
            ulData <<= 4;
            if(buf[ii] >= '0' && buf[ii] <= '9')
            {
              ulData += (buf[ii] - '0');
            } else if(buf[ii] >= 'A' && buf[ii] <= 'F') {
              ulData += (buf[ii] - 'A');
            } else if(buf[ii] >= 'a' && buf[ii] <= 'f') {
              ulData += (buf[ii] - 'a');
            } else {
              goodFormat = false;
            }
          }
        } else {
          goodFormat = false;
        }

        if(goodFormat)
        {
          theCamera_->WriteQuadlet(ulAddress,ulData);
        } else {
          MessageBox(hDialog,
                     "Improper Data format: must be strict 32-bit hexadecimal.\nExample: 0xDEADBEEF",
                     "Bad Hex Format",
                     MB_OK|MB_ICONERROR);
        }
      }
      return true;
    }
  }

  // fall through and return false here, even if we process the command, to let BasicModalDialog close
  // on IDOK or IDCANCEL
  return false;
}
