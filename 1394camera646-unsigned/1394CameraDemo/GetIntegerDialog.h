#if !defined(AFX_GETINTEGERDIALOG_H__A4899A9A_F645_40C4_AC9D_578A38BE8BA6__INCLUDED_)
#define AFX_GETINTEGERDIALOG_H__A4899A9A_F645_40C4_AC9D_578A38BE8BA6__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// GetIntegerDialog.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CGetIntegerDialog dialog

class CGetIntegerDialog : public CDialog
{
// Construction
public:
	CGetIntegerDialog(CWnd* pParent = NULL);   // standard constructor
  BOOL OnInitDialog();
  const char *message;
  unsigned long value;

// Dialog Data
	//{{AFX_DATA(CGetIntegerDialog)
	enum { IDD = IDD_GETINTEGER };
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CGetIntegerDialog)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CGetIntegerDialog)
	afx_msg void OnChangeTheInteger();
	afx_msg void OnUpdateTheInteger();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_GETINTEGERDIALOG_H__A4899A9A_F645_40C4_AC9D_578A38BE8BA6__INCLUDED_)
