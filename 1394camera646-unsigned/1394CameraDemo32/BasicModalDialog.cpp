/**\file BasicModalDialog.cpp
 * \brief Implements public base class for a basic modal dialog handler
 * \ingroup win32demo
 */
#include "BasicModalDialog.h"
#include <strsafe.h>

/**\brief Construction: capture hinstance and template name here */
BasicModalDialog::BasicModalDialog(HINSTANCE hInstance, LPCTSTR lpTemplateName):
    hInstance_(hInstance),
    lpTemplateName_(lpTemplateName),
    hWndParent_(NULL)
  {}

/**\brief Default dialog message processing: this is overridden as necessary in specializations */
bool BasicModalDialog::ProcessMessage(HWND hDialog, UINT uMessage, WPARAM wParam, LPARAM lParam)
{
  // no-op, everything handled by default dialog handler
  return false;
}

/**\brief Encapsulate the call to DialogBoxParam */
INT_PTR BasicModalDialog::run(HWND hWndParent)
{
  hWndParent_ = hWndParent;

  INT_PTR result = DialogBoxParam(hInstance_,lpTemplateName_,hWndParent_,_DlgProc,(LPARAM)(this));
  // do dialogbox stuff
  hWndParent_ = NULL;
  return result;
}

/**\brief static dialog callback procedure
 *
 * The default behavior you get out of this procedure is:
 * - Stores the dialog pointer passed in on lParam in GWLP_USERDATA for later use
 * - Bails if there is no dialog pointer in GWLP_USERDATA on any message other than INITDIALOG
 * - Forwards to the polymorphic ProcessMessage method on the BMD instance
 * - Calls EndDialog if you percolate an IDOK or IDCANCEL back up the stack
 */
INT_PTR CALLBACK BasicModalDialog::_DlgProc(HWND hWndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  BasicModalDialog *bmd = (BasicModalDialog *)NULL;

  // the bmd pointer will be cached in GWLP_USERDATA once we get an INITDIALOG message
  bmd = reinterpret_cast<BasicModalDialog *>(GetWindowLongPtr(hWndDlg,GWLP_USERDATA));

  // Toss everything to the default dialog proc until we get the INITDIALOG message that has our camera pointer
  if(bmd == NULL && uMsg != WM_INITDIALOG)
  {
    // if we get a CANCEL in the interim, bail out
    if(uMsg == WM_COMMAND && LOWORD(wParam) == IDCANCEL)
    {
      EndDialog(hWndDlg,LOWORD(wParam));
      return TRUE;
    }
    return FALSE;
  } // fall through: bmd != NULL and/or WM_INITDIALOG

  if(uMsg == WM_INITDIALOG)
  {
    // bmd is in lParam
    bmd = reinterpret_cast<BasicModalDialog *>(lParam);
    // idiotproofing for bad bmd pointer at this point
    if(bmd == NULL)
    {
      MessageBox(hWndDlg,"Invalid context pointer passed to DialogBoxParam!","BasicModalDialog Error",MB_OK|MB_ICONERROR);
      EndDialog(hWndDlg,-1);
      return TRUE;
    } else {
      char buf[256];
      StringCbPrintf(buf,sizeof(buf),"BasicModalDialog::_DlgProc: bmd @ %p\n",bmd);
      OutputDebugString(buf);
      // cache in GWLP_USERDATA
      SetWindowLongPtr(hWndDlg,GWLP_USERDATA,(LONG_PTR)(bmd));
    }
    // here bmd guaranteed non-NULL
  } // else msg != WM_INITDIALOG, so bmd != NULL from previous test... fall through

  // all paths here lead to bmd != NULL, so forward the message to the virtual handler

  bool res = bmd->ProcessMessage(hWndDlg,uMsg,wParam,lParam);
  if(!res)
  {
    // do minimum of watching for IDOK/IDCANCEL and closing the dialog
    if(uMsg == WM_COMMAND && (LOWORD(wParam) == IDOK || LOWORD(wParam) == IDCANCEL) )
    {
      EndDialog(hWndDlg, LOWORD(wParam));
      res = true;
    }
  }
  return res ? TRUE : FALSE;
}
