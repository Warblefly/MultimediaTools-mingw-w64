// TwiddleDialog.cpp : implementation file
//

#include "stdafx.h"
#include "1394camerademo.h"
#include "TwiddleDialog.h"
#include <strsafe.h>
#include <1394Camera.h>
#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CTwiddleDialog dialog


CTwiddleDialog::CTwiddleDialog(CWnd* pParent /*=NULL*/)
	: CDialog(CTwiddleDialog::IDD, pParent)
{
	//{{AFX_DATA_INIT(CTwiddleDialog)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT
}


void CTwiddleDialog::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CTwiddleDialog)
		// NOTE: the ClassWizard will add DDX and DDV calls here
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CTwiddleDialog, CDialog)
	//{{AFX_MSG_MAP(CTwiddleDialog)
	ON_BN_CLICKED(IDC_REGREAD, OnRegread)
	ON_BN_CLICKED(IDC_REGWRITE, OnRegwrite)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CTwiddleDialog message handlers

void CTwiddleDialog::OnRegread() 
{
	// TODO: Add your control notification handler code here
	char addrbuf[256];
	char databuf[256];
	char buf[256];
	unsigned long ulAddress;
	unsigned long ulData;
	unsigned int len;
	char *pend;

	this->GetDlgItemText(IDC_EDIT_ADDRESS,addrbuf,sizeof(addrbuf)-1);
	StringCbLength(addrbuf,256,&len);
	if(len <= 8)
	{
		StringCbPrintfA(buf,256,"0x%s",addrbuf);
		ulAddress = strtol(buf,&pend,16);
		theCamera.ReadQuadlet(ulAddress,&ulData);
		StringCbPrintfA(databuf,256,"%08x",ulData);
		this->SetDlgItemText(IDC_EDIT_DATA,databuf);
	}
}

void CTwiddleDialog::OnRegwrite() 
{
	// TODO: Add your control notification handler code here
	
}
