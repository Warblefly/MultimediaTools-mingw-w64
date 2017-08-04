// GetIntegerDialog.cpp : implementation file
//

#include "stdafx.h"
#include "1394camerademo.h"
#include "GetIntegerDialog.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CGetIntegerDialog dialog


CGetIntegerDialog::CGetIntegerDialog(CWnd* pParent /*=NULL*/)
	: CDialog(CGetIntegerDialog::IDD, pParent)
{
	//{{AFX_DATA_INIT(CGetIntegerDialog)
	//}}AFX_DATA_INIT

  message = "No Message";
  value = 12345;
}


void CGetIntegerDialog::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CGetIntegerDialog)
	//}}AFX_DATA_MAP
}

BOOL CGetIntegerDialog::OnInitDialog()
{
	HWND hWndFoo;
	if(!CDialog::OnInitDialog())
		return FALSE;
	this->SetDlgItemInt(IDC_THE_INTEGER,this->value,FALSE);	
	this->SetDlgItemText(IDC_MESSAGE_TEXT,this->message);

	// select the contents of the edit control and give it focus
	// so the keyboard input goes there by default
	this->SendDlgItemMessage(IDC_THE_INTEGER,EM_SETSEL,0,-1);
	this->GetDlgItem(IDC_THE_INTEGER,&hWndFoo);
	::PostMessage(this->m_hWnd,WM_NEXTDLGCTL,(WPARAM)hWndFoo,TRUE);
	return TRUE;
}

BEGIN_MESSAGE_MAP(CGetIntegerDialog, CDialog)
	//{{AFX_MSG_MAP(CGetIntegerDialog)
	ON_EN_CHANGE(IDC_THE_INTEGER, OnChangeTheInteger)
	ON_EN_UPDATE(IDC_THE_INTEGER, OnUpdateTheInteger)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CGetIntegerDialog message handlers

void CGetIntegerDialog::OnChangeTheInteger() 
{
	// TODO: If this is a RICHEDIT control, the control will not
	// send this notification unless you override the CDialog::OnInitDialog()
	// function and call CRichEditCtrl().SetEventMask()
	// with the ENM_CHANGE flag ORed into the mask.
	
	// TODO: Add your control notification handler code here
	this->value = GetDlgItemInt(IDC_THE_INTEGER,NULL,FALSE);

}

void CGetIntegerDialog::OnUpdateTheInteger() 
{
	// TODO: If this is a RICHEDIT control, the control will not
	// send this notification unless you override the CDialog::OnInitDialog()
	// function to send the EM_SETEVENTMASK message to the control
	// with the ENM_UPDATE flag ORed into the lParam mask.
	
	// TODO: Add your control notification handler code here
}
