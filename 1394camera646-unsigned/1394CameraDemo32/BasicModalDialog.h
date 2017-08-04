/**\file BasicModalDialog.h
 * \brief Declares public base class for a basic modal dialog handler
 * \ingroup win32demo
 */
#ifndef __BASIC_MODAL_DIALOG_H__
#define __BASIC_MODAL_DIALOG_H__

#include <windows.h>

/**\brief Yet another class wrapper for a windows dialog box
 * \ingroup win32demo
 *
 * The BasicModalDialog class is meant to capture the basic process of:
 *  - create a dialog from a named template from a resource file
 *  - configure that dialog with specialized params
 *  - run it as a modal dialog
 *  - capture results
 *  - deallocate resources on destruction
 *
 * Subclassing from here allows you to populate the template name and bind
 * semantics to dialog entities within the template.
 */
class BasicModalDialog
{
public:
  BasicModalDialog(HINSTANCE hInstance, LPCTSTR lpTemplateName);
  virtual ~BasicModalDialog() {}

  // call this to execute the dialog.  Returns the result from DialogBoxParam()
  INT_PTR run(HWND hWndParent);
protected:
  // dlgproc virtual interface... not public, but should be specialized in children
  virtual bool ProcessMessage(HWND hDialog, UINT uMessage, WPARAM wParam, LPARAM lParam);

  // children may need hinstance to look up resources
  HINSTANCE hInstance_;
  // and the parent window for reference
  HWND hWndParent_;
private:
  // _DlgProc shall be hidden in scope, static so we can pass it to DialogBoxParam
  static INT_PTR CALLBACK _DlgProc(HWND hWndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);

  // children should have no reason to mess with the template name
  LPCTSTR lpTemplateName_;
};

#endif // __BASIC_MODAL_DIALOG_H__
