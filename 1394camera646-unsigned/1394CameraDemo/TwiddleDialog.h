#if !defined(AFX_TWIDDLEDIALOG_H__995B03ED_6E1B_4F5A_B04B_A1A0ED20BA12__INCLUDED_)
#define AFX_TWIDDLEDIALOG_H__995B03ED_6E1B_4F5A_B04B_A1A0ED20BA12__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// TwiddleDialog.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CTwiddleDialog dialog

class CTwiddleDialog : public CDialog
{
// Construction
public:
	CTwiddleDialog(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CTwiddleDialog)
	enum { IDD = IDD_TWIDDLE };
		// NOTE: the ClassWizard will add data members here
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CTwiddleDialog)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CTwiddleDialog)
	afx_msg void OnRegread();
	afx_msg void OnRegwrite();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_TWIDDLEDIALOG_H__995B03ED_6E1B_4F5A_B04B_A1A0ED20BA12__INCLUDED_)
