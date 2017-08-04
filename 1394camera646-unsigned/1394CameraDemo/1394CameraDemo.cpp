//  1394CameraDemo.cpp : Defines the class behaviors for the application.
//
//	Version 4.1
//
//	Copyright 6/2000
// 
//	Iwan Ulrich
//	Robotics Institute
//	Carnegie Mellon University
//	Pittsburgh, PA
//

#define ISOLATION_AWARE_ENABLED 1
#define MANIFEST_RESOURCE_ID 2
#include "stdafx.h"
#include "1394CameraDemo.h"
#include "GetIntegerDialog.h"
#include <1394Camera.h>

#include "MainFrm.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/** \brief Gah! the windows form of strerror is so ugly...
 *  \return pointer to a static buffer holding the human-readable error string (not thread-safe)
 */
const char *StrLastError()
{
  DWORD err = GetLastError();
  static char buf[256];
  FormatMessage( 
    FORMAT_MESSAGE_FROM_SYSTEM | 
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    err,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
    (LPTSTR) &buf,
    256,
    NULL );
    return buf;
}

/////////////////////////////////////////////////////////////////////////////
// C1394CameraDemoApp

BEGIN_MESSAGE_MAP(C1394CameraDemoApp, CWinApp)
	//{{AFX_MSG_MAP(C1394CameraDemoApp)
	ON_COMMAND(ID_APP_ABOUT, OnAppAbout)
	ON_COMMAND(ID_1394_15FPS, On139415fps)
	ON_UPDATE_COMMAND_UI(ID_1394_15FPS, OnUpdate139415fps)
	ON_COMMAND(ID_1394_160X120YUV444, On1394160x120yuv444)
	ON_UPDATE_COMMAND_UI(ID_1394_160X120YUV444, OnUpdate1394160x120yuv444)
	ON_COMMAND(ID_1394_30FPS, On139430fps)
	ON_UPDATE_COMMAND_UI(ID_1394_30FPS, OnUpdate139430fps)
	ON_COMMAND(ID_1394_320X240YUV422, On1394320x240yuv422)
	ON_UPDATE_COMMAND_UI(ID_1394_320X240YUV422, OnUpdate1394320x240yuv422)
	ON_COMMAND(ID_1394_4FPS, On13944fps)
	ON_UPDATE_COMMAND_UI(ID_1394_4FPS, OnUpdate13944fps)
	ON_COMMAND(ID_1394_640X480YUV411, On1394640x480yuv411)
	ON_UPDATE_COMMAND_UI(ID_1394_640X480YUV411, OnUpdate1394640x480yuv411)
	ON_COMMAND(ID_1394_640X480YUV422, On1394640x480yuv422)
	ON_UPDATE_COMMAND_UI(ID_1394_640X480YUV422, OnUpdate1394640x480yuv422)
	ON_COMMAND(ID_1394_7FPS, On13947fps)
	ON_UPDATE_COMMAND_UI(ID_1394_7FPS, OnUpdate13947fps)
	ON_COMMAND(ID_1394_CAMERA_MODEL, On1394CameraModel)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA_MODEL, OnUpdate1394CameraModel)
	ON_COMMAND(ID_1394_CONTROL, On1394Control)
	ON_UPDATE_COMMAND_UI(ID_1394_CONTROL, OnUpdate1394Control)
	ON_COMMAND(ID_1394_INIT_CAMERA, On1394InitCamera)
	ON_UPDATE_COMMAND_UI(ID_1394_INIT_CAMERA, OnUpdate1394InitCamera)
	ON_COMMAND(ID_1394_MAXIMUM_SPEED, On1394MaximumSpeed)
	ON_UPDATE_COMMAND_UI(ID_1394_MAXIMUM_SPEED, OnUpdate1394MaximumSpeed)
	ON_COMMAND(ID_1394_MEASURE_FRAMERATE1, On1394MeasureFramerate)
	ON_UPDATE_COMMAND_UI(ID_1394_MEASURE_FRAMERATE1, OnUpdate1394MeasureFramerate)
	ON_UPDATE_COMMAND_UI(ID_1394_RESET_LINK, OnUpdate1394ResetLink)
	ON_COMMAND(ID_1394_SHOW_CAMERA, On1394ShowCamera)
	ON_UPDATE_COMMAND_UI(ID_1394_SHOW_CAMERA, OnUpdate1394ShowCamera)
	ON_COMMAND(ID_1394_STOP_CAMERA, On1394StopCamera)
	ON_UPDATE_COMMAND_UI(ID_1394_STOP_CAMERA, OnUpdate1394StopCamera)
	ON_UPDATE_COMMAND_UI(ID_APP_EXIT, OnUpdateAppExit)
	ON_COMMAND(ID_1394_1024X768MONO, On13941024x768mono)
	ON_UPDATE_COMMAND_UI(ID_1394_1024X768MONO, OnUpdate13941024x768mono)
	ON_COMMAND(ID_1394_1024X768RGB, On13941024x768rgb)
	ON_UPDATE_COMMAND_UI(ID_1394_1024X768RGB, OnUpdate13941024x768rgb)
	ON_COMMAND(ID_1394_1024X768YUV422, On13941024x768yuv422)
	ON_UPDATE_COMMAND_UI(ID_1394_1024X768YUV422, OnUpdate13941024x768yuv422)
	ON_COMMAND(ID_1394_1280X960MONO, On13941280x960mono)
	ON_UPDATE_COMMAND_UI(ID_1394_1280X960MONO, OnUpdate13941280x960mono)
	ON_COMMAND(ID_1394_1280X960RGB, On13941280x960rgb)
	ON_UPDATE_COMMAND_UI(ID_1394_1280X960RGB, OnUpdate13941280x960rgb)
	ON_COMMAND(ID_1394_1280X960YUV422, On13941280x960yuv422)
	ON_UPDATE_COMMAND_UI(ID_1394_1280X960YUV422, OnUpdate13941280x960yuv422)
	ON_COMMAND(ID_1394_1600X1200MONO, On13941600x1200mono)
	ON_UPDATE_COMMAND_UI(ID_1394_1600X1200MONO, OnUpdate13941600x1200mono)
	ON_COMMAND(ID_1394_1600X1200RGB, On13941600x1200rgb)
	ON_UPDATE_COMMAND_UI(ID_1394_1600X1200RGB, OnUpdate13941600x1200rgb)
	ON_COMMAND(ID_1394_1600X1200YUV422, On13941600x1200yuv422)
	ON_UPDATE_COMMAND_UI(ID_1394_1600X1200YUV422, OnUpdate13941600x1200yuv422)
	ON_COMMAND(ID_1394_640X480MONO, On1394640x480mono)
	ON_UPDATE_COMMAND_UI(ID_1394_640X480MONO, OnUpdate1394640x480mono)
	ON_COMMAND(ID_1394_640X480RGB, On1394640x480rgb)
	ON_UPDATE_COMMAND_UI(ID_1394_640X480RGB, OnUpdate1394640x480rgb)
	ON_COMMAND(ID_1394_800X600MONO, On1394800x600mono)
	ON_UPDATE_COMMAND_UI(ID_1394_800X600MONO, OnUpdate1394800x600mono)
	ON_COMMAND(ID_1394_800X600RGB, On1394800x600rgb)
	ON_UPDATE_COMMAND_UI(ID_1394_800X600RGB, OnUpdate1394800x600rgb)
	ON_COMMAND(ID_1394_800X600YUV422, On1394800x600yuv422)
	ON_UPDATE_COMMAND_UI(ID_1394_800X600YUV422, OnUpdate1394800x600yuv422)
	ON_COMMAND(ID_1394_2FPS, On13942fps)
	ON_UPDATE_COMMAND_UI(ID_1394_2FPS, OnUpdate13942fps)
	ON_COMMAND(ID_1394_60FPS, On139460fps)
	ON_UPDATE_COMMAND_UI(ID_1394_60FPS, OnUpdate139460fps)
	ON_COMMAND(ID_1394_TRIGGER, On1394Trigger)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER, OnUpdate1394Trigger)
	ON_COMMAND(ID_1394_PARTIALSCAN, On1394Partialscan)
	ON_UPDATE_COMMAND_UI(ID_1394_PARTIALSCAN, OnUpdate1394Partialscan)
	ON_COMMAND(ID_1394_CAMERA1, On1394Camera1)
	ON_COMMAND(ID_1394_CAMERA2, On1394Camera2)
	ON_COMMAND(ID_1394_CAMERA3, On1394Camera3)
	ON_COMMAND(ID_1394_CAMERA4, On1394Camera4)
	ON_COMMAND(ID_1394_CAMERA5, On1394Camera5)
	ON_COMMAND(ID_1394_CAMERA6, On1394Camera6)
	ON_COMMAND(ID_1394_CAMERA7, On1394Camera7)
	ON_COMMAND(ID_1394_CAMERA8, On1394Camera8)
	ON_COMMAND(ID_1394_CAMERA9, On1394Camera9)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA1, OnUpdate1394Camera1)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA2, OnUpdate1394Camera2)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA3, OnUpdate1394Camera3)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA4, OnUpdate1394Camera4)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA5, OnUpdate1394Camera5)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA6, OnUpdate1394Camera6)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA7, OnUpdate1394Camera7)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA8, OnUpdate1394Camera8)
	ON_UPDATE_COMMAND_UI(ID_1394_CAMERA9, OnUpdate1394Camera9)
	ON_COMMAND(ID_1394_1024X768MONO16, On13941024x768mono16)
	ON_UPDATE_COMMAND_UI(ID_1394_1024X768MONO16, OnUpdate13941024x768mono16)
	ON_COMMAND(ID_1394_1280X960MONO16, On13941280x960mono16)
	ON_UPDATE_COMMAND_UI(ID_1394_1280X960MONO16, OnUpdate13941280x960mono16)
	ON_COMMAND(ID_1394_1600X1200MONO16, On13941600x1200mono16)
	ON_UPDATE_COMMAND_UI(ID_1394_1600X1200MONO16, OnUpdate13941600x1200mono16)
	ON_COMMAND(ID_1394_640X480MONO16, On1394640x480mono16)
	ON_UPDATE_COMMAND_UI(ID_1394_640X480MONO16, OnUpdate1394640x480mono16)
	ON_COMMAND(ID_1394_800X600MONO16, On1394800x600mono16)
	ON_UPDATE_COMMAND_UI(ID_1394_800X600MONO16, OnUpdate1394800x600mono16)
	ON_COMMAND(ID_APP_DEBUG, OnAppDebug)
	ON_COMMAND(ID_1394_120FPS, On1394120fps)
	ON_UPDATE_COMMAND_UI(ID_1394_120FPS, OnUpdate1394120fps)
	ON_COMMAND(ID_1394_240FPS, On1394240fps)
	ON_UPDATE_COMMAND_UI(ID_1394_240FPS, OnUpdate1394240fps)
	ON_COMMAND(ID_1394_CHECK_LINK, On1394CheckLink)
	ON_COMMAND(ID_CAMERA_STREAM_CONTINUOUS, OnCameraStreamContinuous)
	ON_UPDATE_COMMAND_UI(ID_CAMERA_STREAM_CONTINUOUS, OnUpdateCameraStreamContinuous)
	ON_COMMAND(ID_CAMERA_STREAM_MULTISHOT, OnCameraStreamMultishot)
	ON_UPDATE_COMMAND_UI(ID_CAMERA_STREAM_MULTISHOT, OnUpdateCameraStreamMultishot)
	ON_COMMAND(ID_CAMERA_STREAM_ONESHOT, OnCameraStreamOneshot)
	ON_UPDATE_COMMAND_UI(ID_CAMERA_STREAM_ONESHOT, OnUpdateCameraStreamOneshot)
	ON_COMMAND(ID_1394_TRIGGER_MODE0, On1394TriggerMode0)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE0, OnUpdate1394TriggerMode0)
	ON_COMMAND(ID_1394_TRIGGER_MODE1, On1394TriggerMode1)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE1, OnUpdate1394TriggerMode1)
	ON_COMMAND(ID_1394_TRIGGER_MODE2, On1394TriggerMode2)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE2, OnUpdate1394TriggerMode2)
	ON_COMMAND(ID_1394_TRIGGER_MODE3, On1394TriggerMode3)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE3, OnUpdate1394TriggerMode3)
	ON_COMMAND(ID_1394_TRIGGER_PARAM, On1394TriggerParam)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_PARAM, OnUpdate1394TriggerParam)
	ON_COMMAND(ID_1394_TRIGGER_POLARITY, On1394TriggerPolarity)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_POLARITY, OnUpdate1394TriggerPolarity)
	ON_COMMAND(ID_CAMERA_STREAM_SUBSCRIBE, OnCameraStreamSubscribe)
	ON_UPDATE_COMMAND_UI(ID_CAMERA_STREAM_SUBSCRIBE, OnUpdateCameraStreamSubscribe)
	ON_COMMAND(ID_1394_POWER, On1394Power)
	ON_UPDATE_COMMAND_UI(ID_1394_POWER, OnUpdate1394Power)
	ON_COMMAND(ID_1394_B_SUPPORT, On1394BSupport)
	ON_UPDATE_COMMAND_UI(ID_1394_B_SUPPORT, OnUpdate1394BSupport)
	ON_COMMAND(ID_1394_TRIGGER_INPUT0, On1394TriggerInput0)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_INPUT0, OnUpdate1394TriggerInput0)
	ON_COMMAND(ID_1394_TRIGGER_INPUT1, On1394TriggerInput1)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_INPUT1, OnUpdate1394TriggerInput1)
	ON_COMMAND(ID_1394_TRIGGER_INPUT2, On1394TriggerInput2)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_INPUT2, OnUpdate1394TriggerInput2)
	ON_COMMAND(ID_1394_TRIGGER_INPUT3, On1394TriggerInput3)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_INPUT3, OnUpdate1394TriggerInput3)
	ON_COMMAND(ID_1394_TRIGGER_INPUT7, On1394TriggerInput7)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_INPUT7, OnUpdate1394TriggerInput7)
	ON_COMMAND(ID_1394_TRIGGER_MODE4, On1394TriggerMode4)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE4, OnUpdate1394TriggerMode4)
	ON_COMMAND(ID_1394_TRIGGER_MODE5, On1394TriggerMode5)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE5, OnUpdate1394TriggerMode5)
	ON_COMMAND(ID_1394_TRIGGER_SWTRIGGER, On1394TriggerSwtrigger)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_SWTRIGGER, OnUpdate1394TriggerSwtrigger)
	ON_COMMAND(ID_1394_OPTIONAL_PIO, On1394OptionalPio)
	ON_UPDATE_COMMAND_UI(ID_1394_OPTIONAL_PIO, OnUpdate1394OptionalPio)
	ON_COMMAND(ID_1394_OPTIONAL_SIO, On1394OptionalSio)
	ON_UPDATE_COMMAND_UI(ID_1394_OPTIONAL_SIO, OnUpdate1394OptionalSio)
	ON_COMMAND(ID_1394_OPTIONAL_STROBE, On1394OptionalStrobe)
	ON_UPDATE_COMMAND_UI(ID_1394_OPTIONAL_STROBE, OnUpdate1394OptionalStrobe)
	ON_COMMAND(ID_1394_OPTIONAL_VENDOR, On1394OptionalVendor)
	ON_UPDATE_COMMAND_UI(ID_1394_OPTIONAL_VENDOR, OnUpdate1394OptionalVendor)
	ON_COMMAND(ID_1394_TRIGGER_MODE4, On1394TriggerMode14)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE4, OnUpdate1394TriggerMode14)
	ON_COMMAND(ID_1394_TRIGGER_MODE5, On1394TriggerMode15)
	ON_UPDATE_COMMAND_UI(ID_1394_TRIGGER_MODE5, OnUpdate1394TriggerMode15)
	ON_COMMAND(ID_CAMERA_STREAM_DUAL_PACKET, OnCameraStreamDualPacket)
	ON_UPDATE_COMMAND_UI(ID_CAMERA_STREAM_DUAL_PACKET, OnUpdateCameraStreamDualPacket)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// C1394CameraDemoApp construction

C1394CameraDemoApp::C1394CameraDemoApp()
{
	m_showCamera = false;
  m_cameraInitialized = false;
  m_subscribeOnly = false;
  m_dualPacketSupport = false;
  m_useContinuous = true;
	m_pBitmap = NULL;
  m_pBitmapLength = 0;
}

C1394CameraDemoApp::~C1394CameraDemoApp()
{
}

BOOL C1394CameraDemoApp::OnIdle(LONG lCount)
{
	CMainFrame* pWnd = (CMainFrame *) theApp.GetMainWnd();
  HANDLE hFrameEvent;
  DWORD dwRet;
  BOOL GotFrame = FALSE;
  ULONG Timeout = 1000;
  ULONG Dropped = 0;
  unsigned long t;
  float fps;
  float belief;
  char buf[256];
  if(this->m_showCamera)
  {
    do {
      hFrameEvent = theCamera.GetFrameEvent();
      
      if(hFrameEvent == NULL)
      {
        // no frame is attached, push it on
        OutputDebugString("Pushing\n");
        if(theCamera.AcquireImageEx(FALSE,NULL) != CAM_ERROR_FRAME_TIMEOUT)
        {
          AfxMessageBox("WTF?");
        }
        hFrameEvent = theCamera.GetFrameEvent();
      }
      dwRet = MsgWaitForMultipleObjects(1,&hFrameEvent,FALSE,Timeout,QS_ALLINPUT);
      switch(dwRet)
      {
      case WAIT_OBJECT_0:
        // got a frame
        if(Timeout == 0)
        {
          m_dropped++;
          OutputDebugString(" -> Drop\n");
        } else {
          t = clock();
          if(m_frames >= 32)
            m_timesum -= m_times[m_frames & 31];
          m_times[m_frames & 31] = t - m_lastclock;
          m_lastclock = t;
          m_timesum += m_times[m_frames & 31];
          m_frames++;
          if(m_timesum > 0)
          {
            fps = (float)(m_frames > 32 ? 32 : m_frames);
            fps /= m_timesum;
            fps *= 1000.0;
          } else {
            fps = 0.0;
          }
          // simple kalman on fps to provide some visual stability
          belief = ((float)(m_frames > 32 ? 32 : m_frames)) / 40.0f;
          m_fps = belief * m_fps + (1.0f - belief) * fps;
          sprintf(buf,"Displaying: %.1f fps, %.1f%% dropped\n",
            m_fps,100.0f * (float)(m_dropped)/(float)(m_frames));
          ((CMainFrame*)m_pMainWnd)->SetStatus(buf);
          GotFrame = TRUE;
          Timeout = 0;
        }
        if(theCamera.AcquireImageEx(FALSE,NULL) != CAM_SUCCESS)
        {
          sprintf(buf,"Error \"%s\" while Acquiring Images, Terminate Acguitision?",StrLastError());
          if(AfxMessageBox(buf,MB_YESNO,0) == IDYES)
            this->On1394StopCamera();
        }
        break;
      case WAIT_OBJECT_0 + 1:
        // got a message
        break;
      case WAIT_TIMEOUT:
        // timeout
        if(Timeout == 1000)
        {
          m_timeouts++;
          m_timeouts &= 0x3;
          sprintf(buf,"Timeout.%c%c%c",
            m_timeouts > 0 ? '.' : ' ',
            m_timeouts > 1 ? '.' : ' ',
            m_timeouts > 2 ? '.' : ' ');
          ((CMainFrame*)m_pMainWnd)->SetStatus(buf);
        }
        break;
      default:
        // error
        sprintf(buf,"Error \"%s\" while Acquiring Images, Terminate Acquitision?",StrLastError());
        if(AfxMessageBox(buf,MB_YESNO,0) == IDYES)
          this->On1394StopCamera();
        break;
      }
    } while(dwRet == WAIT_OBJECT_0);
    if(GotFrame)
    {
    	BITMAPINFO bmi;
      unsigned long wd,ht;
      theCamera.GetVideoFrameDimensions(&wd,&ht);
	    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
      bmi.bmiHeader.biWidth = (long) wd;
      bmi.bmiHeader.biHeight = (long) ht;
	    bmi.bmiHeader.biPlanes = 1;
	    bmi.bmiHeader.biBitCount = 24;
	    bmi.bmiHeader.biCompression = BI_RGB;
	    bmi.bmiHeader.biSizeImage = 0;
	    bmi.bmiHeader.biXPelsPerMeter = 1000;
	    bmi.bmiHeader.biYPelsPerMeter = 1000;
	    bmi.bmiHeader.biClrUsed = 0;
	    bmi.bmiHeader.biClrImportant = 0;
	    RECT rect;
	    int x,y,w,h,i=0, timeouts = 0;
	    unsigned long sum = 0, t=clock(),totaldropped = 0;
      int drop = 0;
      CDC *pDC = pWnd->GetViewDC();
      HDC hDC = pDC->m_hDC;
      BOOL DropStuff = TRUE;
		  pWnd->GetWindowRect(&rect);
		  h = rect.bottom - rect.top - theApp.m_borderHeight;
		  w = rect.right - rect.left - theApp.m_borderWidth;

		  x = w - wd;
		  x >>= 1;
		  if(x < 0) x = 0;

		  y = h - ht;
		  y >>= 1;
		  if(y < 0) y = 0;

      theCamera.getDIB(this->m_pBitmap,this->m_pBitmapLength);
		  SetDIBitsToDevice(hDC, x, y, wd, ht, 0, 0, 0, ht, theApp.m_pBitmap, &bmi, DIB_RGB_COLORS);
      pWnd->ReleaseViewDC(pDC);
    } 
    return TRUE;
  }
  return FALSE;
}

/////////////////////////////////////////////////////////////////////////////
// The one and only C1394CameraDemoApp object

C1394CameraDemoApp theApp;
C1394Camera theCamera;


/////////////////////////////////////////////////////////////////////////////
// C1394CameraDemoApp initialization

BOOL C1394CameraDemoApp::InitInstance()
{
	AfxEnableControlContainer();

	// Standard initialization
	// If you are not using these features and wish to reduce the size
	//  of your final executable, you should remove from the following
	//  the specific initialization routines you do not need.

#ifdef _AFXDLL
	Enable3dControls();			// Call this when using MFC in a shared DLL
#else
	Enable3dControlsStatic();	// Call this when linking to MFC statically
#endif

	// Change the registry key under which our settings are stored.
	// TODO: You should modify this string to be something appropriate
	// such as the name of your company or organization.
	//SetRegistryKey(_T("Local AppWizard-Generated Applications"));

	// To create the main window, this code creates a new frame window
	// object and then sets it as the application's main window object.

	CMainFrame* pFrame = new CMainFrame;
	m_pMainWnd = pFrame;

	// create and load the frame with its resources

	HICON hIcon = LoadIcon(MAKEINTRESOURCE(IDR_MAINFRAME));

	pFrame->LoadFrame(IDR_MAINFRAME,
		WS_OVERLAPPEDWINDOW | FWS_ADDTOTITLE, NULL,
		NULL);

	pFrame->SetIcon(hIcon,TRUE);

	// The one and only window has been initialized, so show and update it.
	pFrame->ShowWindow(SW_SHOW);
	pFrame->UpdateWindow();
	CRect windowRect, clientRect;
	m_pMainWnd->GetWindowRect(&windowRect);
	m_pMainWnd->GetClientRect(&clientRect);
	m_borderWidth = windowRect.Width() - clientRect.Width() + 1;
	m_borderHeight = windowRect.Height() - clientRect.Height() + 20;
	m_pMainWnd->SetWindowPos(NULL, 0, 0, 320+m_borderWidth, 240+m_borderHeight, SWP_NOMOVE|SWP_NOZORDER);

	return TRUE;
}

/////////////////////////////////////////////////////////////////////////////
// C1394CameraDemoApp message handlers





/////////////////////////////////////////////////////////////////////////////
// CAboutDlg dialog used for App About

class CAboutDlg : public CDialog
{
public:
	CAboutDlg();

// Dialog Data
	//{{AFX_DATA(CAboutDlg)
	enum { IDD = IDD_ABOUTBOX };
	//}}AFX_DATA

	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CAboutDlg)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	//{{AFX_MSG(CAboutDlg)
		// No message handlers
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

CAboutDlg::CAboutDlg() : CDialog(CAboutDlg::IDD)
{
	//{{AFX_DATA_INIT(CAboutDlg)
	//}}AFX_DATA_INIT
}

void CAboutDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CAboutDlg)
	//}}AFX_DATA_MAP
}

BEGIN_MESSAGE_MAP(CAboutDlg, CDialog)
	//{{AFX_MSG_MAP(CAboutDlg)
		// No message handlers
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

// App command to run the dialog
void C1394CameraDemoApp::OnAppAbout()
{
	CAboutDlg aboutDlg;
	aboutDlg.DoModal();
}

void C1394CameraDemoApp::SetVideoMode(int f, int m)
{
  unsigned long w,h;
  if(theCamera.SetVideoFormat(f) != CAM_SUCCESS)
    AfxMessageBox("Error Setting Video Format");
  if(theCamera.SetVideoMode(m) != CAM_SUCCESS)
    AfxMessageBox("Error Setting Video Format");

  theCamera.GetVideoFrameDimensions(&w,&h);
  if(w < 200)
    w = 200;
  if(h < 150)
    h = 150;

  w += m_borderWidth;
  h += m_borderHeight;

	if(!m_pMainWnd->SetWindowPos(NULL, 0, 0, w, h, SWP_NOMOVE|SWP_NOZORDER))
    AfxMessageBox("Error Setting Window Position");
}

void C1394CameraDemoApp::SetVideoRate(int r)
{
  if(theCamera.SetVideoFrameRate(r) != CAM_SUCCESS)
    AfxMessageBox("Error Setting Video Rate");
}

void C1394CameraDemoApp::UpdateVideoMode(CCmdUI* pCmdUI, int f, int m)
{
	pCmdUI->Enable((theCamera.HasVideoMode(f,m)) && !m_showCamera && m_cameraInitialized);
	pCmdUI->SetCheck((theCamera.GetVideoFormat()==f)&&(theCamera.GetVideoMode()==m));
}

void C1394CameraDemoApp::UpdateVideoRate(CCmdUI* pCmdUI, int r)
{
	pCmdUI->Enable(theCamera.GetVideoFormat() < 3 && (theCamera.HasVideoFrameRate(theCamera.GetVideoFormat(),theCamera.GetVideoMode(),r)) && !m_showCamera && m_cameraInitialized);
	pCmdUI->SetCheck(theCamera.GetVideoFrameRate() == r);
}

/////////////////////////////////////////////////////////////////////////////
// C1394CameraDemoApp message handlers

// MENU COMMANDS

// format 0
void C1394CameraDemoApp::On1394160x120yuv444()   {SetVideoMode(0,0);}
void C1394CameraDemoApp::On1394320x240yuv422()   {SetVideoMode(0,1);}
void C1394CameraDemoApp::On1394640x480yuv411()   {SetVideoMode(0,2);}
void C1394CameraDemoApp::On1394640x480yuv422()   {SetVideoMode(0,3);}
void C1394CameraDemoApp::On1394640x480rgb()      {SetVideoMode(0,4);}
void C1394CameraDemoApp::On1394640x480mono()     {SetVideoMode(0,5);}
void C1394CameraDemoApp::On1394640x480mono16()   {SetVideoMode(0,6);}

// format 1
void C1394CameraDemoApp::On1394800x600yuv422()   {SetVideoMode(1,0);}
void C1394CameraDemoApp::On1394800x600rgb()      {SetVideoMode(1,1);}
void C1394CameraDemoApp::On1394800x600mono()     {SetVideoMode(1,2);}
void C1394CameraDemoApp::On13941024x768yuv422()  {SetVideoMode(1,3);}
void C1394CameraDemoApp::On13941024x768rgb()     {SetVideoMode(1,4);}
void C1394CameraDemoApp::On13941024x768mono()    {SetVideoMode(1,5);}
void C1394CameraDemoApp::On1394800x600mono16()   {SetVideoMode(1,6);}
void C1394CameraDemoApp::On13941024x768mono16()  {SetVideoMode(1,7);}

// format 2
void C1394CameraDemoApp::On13941280x960yuv422()  {SetVideoMode(2,0);}
void C1394CameraDemoApp::On13941280x960rgb()     {SetVideoMode(2,1);}
void C1394CameraDemoApp::On13941280x960mono()    {SetVideoMode(2,2);}
void C1394CameraDemoApp::On13941600x1200yuv422() {SetVideoMode(2,3);}
void C1394CameraDemoApp::On13941600x1200rgb()    {SetVideoMode(2,4);}
void C1394CameraDemoApp::On13941600x1200mono()   {SetVideoMode(2,5);}
void C1394CameraDemoApp::On13941280x960mono16()  {SetVideoMode(2,6);}
void C1394CameraDemoApp::On13941600x1200mono16() {SetVideoMode(2,7);}

// rates
void C1394CameraDemoApp::On13942fps()   {SetVideoRate(0);}
void C1394CameraDemoApp::On13944fps()   {SetVideoRate(1);}
void C1394CameraDemoApp::On13947fps()   {SetVideoRate(2);}
void C1394CameraDemoApp::On139415fps()  {SetVideoRate(3);}
void C1394CameraDemoApp::On139430fps()  {SetVideoRate(4);}
void C1394CameraDemoApp::On139460fps()  {SetVideoRate(5);}
void C1394CameraDemoApp::On1394120fps() {SetVideoRate(6);}
void C1394CameraDemoApp::On1394240fps() {SetVideoRate(7);}

// UPDATES

// format 0
void C1394CameraDemoApp::OnUpdate1394160x120yuv444(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,0,0);}
void C1394CameraDemoApp::OnUpdate1394320x240yuv422(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,0,1);}
void C1394CameraDemoApp::OnUpdate1394640x480yuv411(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,0,2);}
void C1394CameraDemoApp::OnUpdate1394640x480yuv422(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,0,3);}
void C1394CameraDemoApp::OnUpdate1394640x480rgb(CCmdUI* pCmdUI)      {UpdateVideoMode(pCmdUI,0,4);}
void C1394CameraDemoApp::OnUpdate1394640x480mono(CCmdUI* pCmdUI)     {UpdateVideoMode(pCmdUI,0,5);}
void C1394CameraDemoApp::OnUpdate1394640x480mono16(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,0,6);}

// format 1
void C1394CameraDemoApp::OnUpdate1394800x600yuv422(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,1,0);}
void C1394CameraDemoApp::OnUpdate1394800x600rgb(CCmdUI* pCmdUI)      {UpdateVideoMode(pCmdUI,1,1);}
void C1394CameraDemoApp::OnUpdate1394800x600mono(CCmdUI* pCmdUI)     {UpdateVideoMode(pCmdUI,1,2);}
void C1394CameraDemoApp::OnUpdate13941024x768yuv422(CCmdUI* pCmdUI)  {UpdateVideoMode(pCmdUI,1,3);}
void C1394CameraDemoApp::OnUpdate13941024x768rgb(CCmdUI* pCmdUI)     {UpdateVideoMode(pCmdUI,1,4);}
void C1394CameraDemoApp::OnUpdate13941024x768mono(CCmdUI* pCmdUI)    {UpdateVideoMode(pCmdUI,1,5);}
void C1394CameraDemoApp::OnUpdate1394800x600mono16(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,1,6);}
void C1394CameraDemoApp::OnUpdate13941024x768mono16(CCmdUI* pCmdUI)  {UpdateVideoMode(pCmdUI,1,7);}

// format 2
void C1394CameraDemoApp::OnUpdate13941280x960yuv422(CCmdUI* pCmdUI)  {UpdateVideoMode(pCmdUI,2,0);}
void C1394CameraDemoApp::OnUpdate13941280x960rgb(CCmdUI* pCmdUI)     {UpdateVideoMode(pCmdUI,2,1);}
void C1394CameraDemoApp::OnUpdate13941280x960mono(CCmdUI* pCmdUI)    {UpdateVideoMode(pCmdUI,2,2);}
void C1394CameraDemoApp::OnUpdate13941600x1200yuv422(CCmdUI* pCmdUI) {UpdateVideoMode(pCmdUI,2,3);}
void C1394CameraDemoApp::OnUpdate13941600x1200rgb(CCmdUI* pCmdUI)    {UpdateVideoMode(pCmdUI,2,4);}
void C1394CameraDemoApp::OnUpdate13941600x1200mono(CCmdUI* pCmdUI)   {UpdateVideoMode(pCmdUI,2,5);}
void C1394CameraDemoApp::OnUpdate13941280x960mono16(CCmdUI* pCmdUI)  {UpdateVideoMode(pCmdUI,2,6);}
void C1394CameraDemoApp::OnUpdate13941600x1200mono16(CCmdUI* pCmdUI) {UpdateVideoMode(pCmdUI,2,7);}

// rates
void C1394CameraDemoApp::OnUpdate13942fps(CCmdUI* pCmdUI)   {UpdateVideoRate(pCmdUI,0);}
void C1394CameraDemoApp::OnUpdate13944fps(CCmdUI* pCmdUI)   {UpdateVideoRate(pCmdUI,1);}
void C1394CameraDemoApp::OnUpdate13947fps(CCmdUI* pCmdUI)   {UpdateVideoRate(pCmdUI,2);}
void C1394CameraDemoApp::OnUpdate139415fps(CCmdUI* pCmdUI)  {UpdateVideoRate(pCmdUI,3);}
void C1394CameraDemoApp::OnUpdate139430fps(CCmdUI* pCmdUI)  {UpdateVideoRate(pCmdUI,4);}
void C1394CameraDemoApp::OnUpdate139460fps(CCmdUI* pCmdUI)  {UpdateVideoRate(pCmdUI,5);}
void C1394CameraDemoApp::OnUpdate1394120fps(CCmdUI* pCmdUI) {UpdateVideoRate(pCmdUI,6);}
void C1394CameraDemoApp::OnUpdate1394240fps(CCmdUI* pCmdUI) {UpdateVideoRate(pCmdUI,7);}

void C1394CameraDemoApp::On1394ShowCamera() 
{
  unsigned long ulFlags = 0;
  if(m_useContinuous)
    ulFlags |= ACQ_START_VIDEO_STREAM;
  if(m_subscribeOnly)
    ulFlags |= ACQ_SUBSCRIBE_ONLY;
  if(m_dualPacketSupport)
    ulFlags |= ACQ_ALLOW_PGR_DUAL_PACKET;

  if (theCamera.StartImageAcquisitionEx(6,0,ulFlags))
		AfxMessageBox("Problem Starting Image Acquisition");
	else
	{
    unsigned long w,h;
		m_showCamera = true;
    theCamera.GetVideoFrameDimensions(&w,&h);
    m_pBitmapLength = w * h * 3;
		m_pBitmap = new unsigned char [m_pBitmapLength];
    m_dropped = m_frames = m_timesum = 0;
    m_lastclock = clock();
	}
}

void C1394CameraDemoApp::On1394StopCamera() 
{
	m_showCamera = false;
  theCamera.StopImageAcquisition();
	delete [] theApp.m_pBitmap;
	theApp.m_pBitmap = NULL;
  theApp.m_pBitmapLength = 0;
  if(theApp.m_pMainWnd)
  {
    ((CMainFrame *)(theApp.m_pMainWnd))->SetStatus("Ready");
    theApp.m_pMainWnd->Invalidate(TRUE);
  }
}


void C1394CameraDemoApp::OnUpdate1394ShowCamera(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(!m_showCamera && m_cameraInitialized);
}


void C1394CameraDemoApp::OnUpdate1394StopCamera(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(m_showCamera);
}


void C1394CameraDemoApp::On1394MeasureFramerate() 
{
	CString text;
	DWORD start, duration;
	int frames = 0;
  int timeouts = 0;
  int ret;

	if (theCamera.StartImageAcquisition())
		AfxMessageBox("Problem Starting Image Acquisition");

	start = GetTickCount();
  do
	{
   		if((ret = theCamera.AcquireImage() != CAM_SUCCESS))
        break;
  		frames++;
      duration = GetTickCount() - start;
	}
	while (duration < 3000);

	if (theCamera.StopImageAcquisition())
		AfxMessageBox("Problem Stopping Image Acquisition");

	double rate = (1000.0*frames)/duration;
	text.Format("Frames = %d, Timeouts = %d Rate = %3.1f", frames, timeouts, rate);
	AfxMessageBox(text);
}


void C1394CameraDemoApp::OnUpdate1394MeasureFramerate(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(!m_showCamera && m_cameraInitialized);
}

void C1394CameraDemoApp::On1394InitCamera() 
{
  unsigned long w,h;
  BOOL reset = FALSE;
  m_cameraInitialized = false;
	((CMainFrame *)m_pMainWnd)->SetStatus("Initializing Camera...");
  if(AfxMessageBox("Reset to powerup defaults?",MB_YESNO,0) == IDYES)
    reset = TRUE;

	if(theCamera.InitCamera(reset) != CAM_SUCCESS)
  {
    AfxMessageBox("Error initializing camera\n");
    return;
  }
  m_cameraInitialized = true;
  ((CMainFrame *)m_pMainWnd)->SetStatus("Ready");
  theCamera.GetVideoFrameDimensions(&w,&h);
  if(w < 200)
    w = 200;
  if(h < 50)
    h = 50;
  w += m_borderWidth;
  h += m_borderHeight;

	if(!((CMainFrame *)m_pMainWnd)->SetWindowPos(NULL, 0, 0, w, h, SWP_NOMOVE|SWP_NOZORDER))
    AfxMessageBox("Error Setting Window Position");
}


void C1394CameraDemoApp::OnUpdate1394InitCamera(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(!m_showCamera && theCamera.GetNode() >= 0);
}


void C1394CameraDemoApp::On1394CameraModel() 
{
	char vendor[256],model[256],buf[512];
  LARGE_INTEGER ID;
  theCamera.GetCameraName(model,sizeof(model));
  theCamera.GetCameraVendor(vendor,sizeof(vendor));
  theCamera.GetCameraUniqueID(&ID);
	sprintf(buf,"Vendor: %s\r\nModel: %s\r\nUniqueID: %08X%08X",
		vendor,model,ID.HighPart,ID.LowPart);
	MessageBox(m_pMainWnd->GetSafeHwnd(),buf,"1394Camera Identification",MB_OK);

}


void C1394CameraDemoApp::OnUpdate1394CameraModel(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(m_cameraInitialized);
}


void C1394CameraDemoApp::On1394Control() 
{
	CameraControlDialog(m_pMainWnd->GetSafeHwnd(),&theCamera,TRUE);
}


void C1394CameraDemoApp::OnUpdate1394Control(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(m_cameraInitialized);
}


void C1394CameraDemoApp::OnUpdateAppExit(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(!m_showCamera);
}


void C1394CameraDemoApp::OnUpdate1394ResetLink(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(!m_showCamera);
}


void C1394CameraDemoApp::On1394MaximumSpeed() 
{
	CString text;
	text.Format("Maximum Speed: %d MBits/s", theCamera.GetMaxSpeed());	
	AfxMessageBox(text);
}


void C1394CameraDemoApp::OnUpdate1394MaximumSpeed(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(m_cameraInitialized);
}

void C1394CameraDemoApp::On1394Partialscan() 
{
	// grab the old modes
	int ret,of,om;
	of = theCamera.GetVideoFormat();
	om = theCamera.GetVideoMode();

	// try to set the format to 7
	if((ret = theCamera.SetVideoFormat(7)) != CAM_SUCCESS)
	{
		CString text;
		text.Format("Error %d on SetVideoFormat(7)",ret);
		AfxMessageBox(ret);
		return;
	}

	// run the dll-supplied dialog
	if(CameraControlSizeDialog(GetMainWnd()->GetSafeHwnd(),&theCamera) == IDOK)
	{
		// update the window size;
		unsigned long w,h;
		theCamera.GetVideoFrameDimensions(&w,&h);
		if(w < 200)
			w = 200;
		if(h < 200)
			h = 200;
		
		w += m_borderWidth;
		h += m_borderHeight;
		m_pMainWnd->SetWindowPos(NULL, 0, 0, w, h, SWP_NOMOVE|SWP_NOZORDER);
	} else {
		// restore the old format, mode
		theCamera.SetVideoFormat(of);
		theCamera.SetVideoMode(om);
	}
}


void C1394CameraDemoApp::OnUpdate1394Partialscan(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable(!m_showCamera && m_cameraInitialized && theCamera.HasVideoFormat(7));
	pCmdUI->SetCheck(theCamera.GetVideoFormat() == 7);
}

void C1394CameraDemoApp::SelectCamera(int node)
{
	theCamera.SelectCamera(node);
  m_cameraInitialized = false;
}

void C1394CameraDemoApp::On1394Camera1() {SelectCamera(0);}
void C1394CameraDemoApp::On1394Camera2() {SelectCamera(1);}
void C1394CameraDemoApp::On1394Camera3() {SelectCamera(2);}
void C1394CameraDemoApp::On1394Camera4() {SelectCamera(3);}
void C1394CameraDemoApp::On1394Camera5() {SelectCamera(4);}
void C1394CameraDemoApp::On1394Camera6() {SelectCamera(5);}
void C1394CameraDemoApp::On1394Camera7() {SelectCamera(6);}
void C1394CameraDemoApp::On1394Camera8() {SelectCamera(7);}
void C1394CameraDemoApp::On1394Camera9() {SelectCamera(8);}

void C1394CameraDemoApp::UpdateCamera(CCmdUI* pCmdUI, int node)
{
  char buf[512];
  if(theCamera.GetNumberCameras() > node)
  {
    sprintf(buf,"%d: ",node);
    theCamera.GetNodeDescription(node,buf + strlen(buf),512 - strlen(buf));
    pCmdUI->SetText(buf);
  	pCmdUI->Enable(!m_showCamera);
	  pCmdUI->SetCheck(theCamera.GetNode() == node);
  } else {
    sprintf(buf,"%d: (n/a)",node);
    pCmdUI->SetText(buf);
    pCmdUI->Enable(0);
    pCmdUI->SetCheck(0);
  }
}

void C1394CameraDemoApp::OnUpdate1394Camera1(CCmdUI* pCmdUI) 
{
  if (pCmdUI->m_pSubMenu) {
    // update submenu item (Camera|Stream Control)
    UINT fGray = theCamera.GetNumberCameras() > 0 ? 0 : MF_GRAYED;
    pCmdUI->m_pMenu->EnableMenuItem(
      pCmdUI->m_nIndex, MF_BYPOSITION|fGray);    
  } else {
    UpdateCamera(pCmdUI,0);
  }
}

void C1394CameraDemoApp::OnUpdate1394Camera2(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,1);}
void C1394CameraDemoApp::OnUpdate1394Camera3(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,2);}
void C1394CameraDemoApp::OnUpdate1394Camera4(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,3);}
void C1394CameraDemoApp::OnUpdate1394Camera5(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,4);}
void C1394CameraDemoApp::OnUpdate1394Camera6(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,5);}
void C1394CameraDemoApp::OnUpdate1394Camera7(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,6);}
void C1394CameraDemoApp::OnUpdate1394Camera8(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,7);}
void C1394CameraDemoApp::OnUpdate1394Camera9(CCmdUI* pCmdUI) {UpdateCamera(pCmdUI,8);}

int C1394CameraDemoApp::ExitInstance() 
{
	// TODO: Add your specialized code here and/or call the base class
	if(m_showCamera)
  {
    this->On1394StopCamera();
  }
	return CWinApp::ExitInstance();
}

void C1394CameraDemoApp::OnAppDebug() 
{
	// TODO: Add your command handler code here
	CameraDebugDialog(GetMainWnd()->GetSafeHwnd());	
}


void C1394CameraDemoApp::On1394CheckLink() 
{
  char buf[64];
  int ret = theCamera.RefreshCameraList();
  int type;
  if(ret >= 0)
  {
    sprintf(buf,"CheckLink: Found %d Camera%s\n",ret,ret == 1 ? "" : "s");
    type = MB_OK | (ret > 0 ? MB_ICONINFORMATION : MB_ICONWARNING);
  } else {
    sprintf(buf,"CheckLink: Error %08x Refreshing Camera List",GetLastError());
    type = MB_OK | MB_ICONERROR;
  }
  AfxMessageBox(buf,type);
}

void C1394CameraDemoApp::OnCameraStreamContinuous() 
{
  // TODO: Add your command handler code here
  m_useContinuous = !m_useContinuous;
}

void C1394CameraDemoApp::OnUpdateCameraStreamContinuous(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
  // update first submenu item (File|Submenu|Foo)
 	pCmdUI->Enable(m_cameraInitialized && !m_showCamera);
  pCmdUI->SetCheck(m_useContinuous);
}

void C1394CameraDemoApp::OnCameraStreamMultishot() 
{
  // TODO: Add your command handler code here
  CGetIntegerDialog gid;
  gid.value = 10;
  gid.message = "Enter Frame Count for MultiShot";
  m_lastclock = clock();
  if(gid.DoModal() == IDOK)
  {
	if(theCamera.MultiShot((unsigned short)(gid.value)) != CAM_SUCCESS)
      AfxMessageBox("Error calling Multishot");
  }
}

void C1394CameraDemoApp::OnUpdateCameraStreamMultishot(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
  pCmdUI->Enable(m_showCamera && !m_useContinuous && theCamera.HasMultiShot());
}

void C1394CameraDemoApp::OnCameraStreamOneshot() 
{
	// TODO: Add your command handler code here
	theCamera.OneShot();
}

void C1394CameraDemoApp::OnUpdateCameraStreamOneshot(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
  pCmdUI->Enable(m_showCamera && !m_useContinuous && theCamera.HasOneShot());	
}

void C1394CameraDemoApp::On1394Trigger()
{
  theCamera.GetCameraControlTrigger()->SetOnOff(!theCamera.GetCameraControlTrigger()->StatusOnOff());
  theCamera.GetCameraControlTrigger()->Status();
}

void C1394CameraDemoApp::OnUpdate1394Trigger(CCmdUI* pCmdUI) 
{
  if (pCmdUI->m_pSubMenu) {
    // update submenu item (Camera|External Trigger)
    UINT fGray = (m_cameraInitialized && theCamera.HasFeature(FEATURE_TRIGGER_MODE)) ? 0 : MF_GRAYED;
    pCmdUI->m_pMenu->EnableMenuItem(
      pCmdUI->m_nIndex, MF_BYPOSITION|fGray);    
  } else {
    // update first submenu item (File|Submenu|Foo)
  	pCmdUI->Enable(theCamera.GetCameraControlTrigger()->HasOnOff());
	pCmdUI->SetCheck(theCamera.GetCameraControlTrigger()->StatusOnOff());
  }
}

void C1394CameraDemoApp::UpdateTriggerMode(CCmdUI* pCmdUI,int m)
{
  unsigned short mode,param;
  pCmdUI->Enable(theCamera.GetCameraControlTrigger()->HasMode(m));
  theCamera.GetCameraControlTrigger()->GetMode(&mode,&param);
  pCmdUI->SetCheck(mode == m);
}
void C1394CameraDemoApp::SetTriggerMode(int m)
{
  int ret;
  unsigned short mode,param;
  theCamera.GetCameraControlTrigger()->GetMode(&mode,&param);
  if(mode != m)
  {
    mode = (unsigned short)(m);
    if((ret = theCamera.GetCameraControlTrigger()->SetMode(mode,param)) != CAM_SUCCESS)
      AfxMessageBox("Error Setting Trigger Mode\n");
    theCamera.GetCameraControlTrigger()->Status();
  }
}

// trigger submenu stuff

void C1394CameraDemoApp::On1394TriggerMode0()  {SetTriggerMode(0);}
void C1394CameraDemoApp::On1394TriggerMode1()  {SetTriggerMode(1);}
void C1394CameraDemoApp::On1394TriggerMode2()  {SetTriggerMode(2);}
void C1394CameraDemoApp::On1394TriggerMode3()  {SetTriggerMode(3);}
void C1394CameraDemoApp::On1394TriggerMode4()  {SetTriggerMode(4);}
void C1394CameraDemoApp::On1394TriggerMode5()  {SetTriggerMode(5);}
void C1394CameraDemoApp::On1394TriggerMode14() {SetTriggerMode(14);}
void C1394CameraDemoApp::On1394TriggerMode15() {SetTriggerMode(15);}

void C1394CameraDemoApp::OnUpdate1394TriggerMode0(CCmdUI* pCmdUI)  {UpdateTriggerMode(pCmdUI,0);}
void C1394CameraDemoApp::OnUpdate1394TriggerMode1(CCmdUI* pCmdUI)  {UpdateTriggerMode(pCmdUI,1);}
void C1394CameraDemoApp::OnUpdate1394TriggerMode2(CCmdUI* pCmdUI)  {UpdateTriggerMode(pCmdUI,2);}
void C1394CameraDemoApp::OnUpdate1394TriggerMode3(CCmdUI* pCmdUI)  {UpdateTriggerMode(pCmdUI,3);}
void C1394CameraDemoApp::OnUpdate1394TriggerMode4(CCmdUI* pCmdUI)  {UpdateTriggerMode(pCmdUI,4);}
void C1394CameraDemoApp::OnUpdate1394TriggerMode5(CCmdUI* pCmdUI)  {UpdateTriggerMode(pCmdUI,5);}
void C1394CameraDemoApp::OnUpdate1394TriggerMode14(CCmdUI* pCmdUI) {UpdateTriggerMode(pCmdUI,14);}
void C1394CameraDemoApp::OnUpdate1394TriggerMode15(CCmdUI* pCmdUI) {UpdateTriggerMode(pCmdUI,15);}

void C1394CameraDemoApp::On1394TriggerParam() 
{
  unsigned short mode,param;
  theCamera.GetCameraControlTrigger()->GetMode(&mode,&param);
	CGetIntegerDialog gid;
  gid.value = param;
  gid.message = "Enter the Trigger Value";
  if(gid.DoModal() == IDOK)
  {
    param = (unsigned short) gid.value;
    if(theCamera.GetCameraControlTrigger()->SetMode(mode,param) != CAM_SUCCESS)
      AfxMessageBox("Error Setting Trigger Mode/Parameter");
  }
}

void C1394CameraDemoApp::OnUpdate1394TriggerParam(CCmdUI* pCmdUI) 
{
  unsigned short mode,param;
  theCamera.GetCameraControlTrigger()->GetMode(&mode,&param);
  // param is only valid for modes 2 and above
  pCmdUI->Enable(mode >= 2);  
}

void C1394CameraDemoApp::On1394TriggerPolarity() 
{
	// TODO: Add your command handler code here
  theCamera.GetCameraControlTrigger()->SetPolarity(!theCamera.GetCameraControlTrigger()->StatusPolarity());
}

void C1394CameraDemoApp::OnUpdate1394TriggerPolarity(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
	pCmdUI->Enable(theCamera.GetCameraControlTrigger()->HasPolarity());
}

void C1394CameraDemoApp::OnCameraStreamSubscribe() 
{
	// TODO: Add your command handler code here
  m_subscribeOnly = !m_subscribeOnly;
}

void C1394CameraDemoApp::OnUpdateCameraStreamSubscribe(CCmdUI* pCmdUI) 
{
  // do the submenu dance since this is the first item
  if (pCmdUI->m_pSubMenu) {
    // update submenu item (Camera|Stream Control)
    UINT fGray = m_cameraInitialized ? 0 : MF_GRAYED;
    pCmdUI->m_pMenu->EnableMenuItem(
      pCmdUI->m_nIndex, MF_BYPOSITION|fGray);    
  } else {
  	// TODO: Add your command update UI handler code here
    pCmdUI->Enable(!m_showCamera);
    pCmdUI->SetCheck(m_subscribeOnly);
  }
}

void C1394CameraDemoApp::On1394Power() 
{
	// TODO: Add your command handler code here
  if(theCamera.HasPowerControl())
    theCamera.SetPowerControl(!theCamera.StatusPowerControl());
}

void C1394CameraDemoApp::OnUpdate1394Power(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
	pCmdUI->Enable(!m_showCamera && theCamera.HasPowerControl());
  pCmdUI->SetCheck(theCamera.StatusPowerControl());
}

void C1394CameraDemoApp::On1394BSupport() 
{
	// TODO: Add your command handler code here
  if(theCamera.Has1394b())
    theCamera.Set1394b(!theCamera.Status1394b());
}

void C1394CameraDemoApp::OnUpdate1394BSupport(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
	pCmdUI->Enable(!m_showCamera && theCamera.Has1394b());
  pCmdUI->SetCheck(theCamera.Status1394b());
}

void C1394CameraDemoApp::UpdateTriggerInput(CCmdUI* pCmdUI,int i)
{
  unsigned short src;
  pCmdUI->Enable(theCamera.GetCameraControlTrigger()->HasTriggerSource((unsigned short)i));
  theCamera.GetCameraControlTrigger()->GetTriggerSource(&src);
  pCmdUI->SetCheck(src == i);
}

void C1394CameraDemoApp::SetTriggerInput(int i)
{
  int ret;
  if((ret = theCamera.GetCameraControlTrigger()->SetTriggerSource((unsigned short)i)) != CAM_SUCCESS)
    AfxMessageBox("Error Setting Trigger Source\n");
  theCamera.GetCameraControlTrigger()->Status();
}

void C1394CameraDemoApp::On1394TriggerInput0() {SetTriggerInput(0);}
void C1394CameraDemoApp::On1394TriggerInput1() {SetTriggerInput(1);}
void C1394CameraDemoApp::On1394TriggerInput2() {SetTriggerInput(2);}
void C1394CameraDemoApp::On1394TriggerInput3() {SetTriggerInput(3);}
void C1394CameraDemoApp::On1394TriggerInput7() {SetTriggerInput(7);}

void C1394CameraDemoApp::OnUpdate1394TriggerInput0(CCmdUI* pCmdUI) {UpdateTriggerInput(pCmdUI,0);}
void C1394CameraDemoApp::OnUpdate1394TriggerInput1(CCmdUI* pCmdUI) {UpdateTriggerInput(pCmdUI,1);}
void C1394CameraDemoApp::OnUpdate1394TriggerInput2(CCmdUI* pCmdUI) {UpdateTriggerInput(pCmdUI,2);}
void C1394CameraDemoApp::OnUpdate1394TriggerInput3(CCmdUI* pCmdUI) {UpdateTriggerInput(pCmdUI,3);}
void C1394CameraDemoApp::OnUpdate1394TriggerInput7(CCmdUI* pCmdUI) {UpdateTriggerInput(pCmdUI,7);}

void C1394CameraDemoApp::On1394TriggerSwtrigger() 
{
  int ret;
  if((ret = theCamera.GetCameraControlTrigger()->DoSoftwareTrigger()) != CAM_SUCCESS)
    AfxMessageBox("Error Frobbing SW Trigger\n");
}

void C1394CameraDemoApp::OnUpdate1394TriggerSwtrigger(CCmdUI* pCmdUI) 
{
  unsigned short src;
  theCamera.GetCameraControlTrigger()->GetTriggerSource(&src);
  pCmdUI->Enable(theCamera.GetCameraControlTrigger()->HasSoftwareTrigger() && src == 7);
}

void C1394CameraDemoApp::On1394OptionalPio() 
{
  char buf[256];
  sprintf(buf,"Camera Has Parallel I/O Controls at 0x%08x\n",theCamera.GetPIOControlOffset());
  AfxMessageBox(buf,MB_OK | MB_ICONINFORMATION);
}

void C1394CameraDemoApp::OnUpdate1394OptionalPio(CCmdUI* pCmdUI) 
{
  if (pCmdUI->m_pSubMenu) {
    // update submenu item (Camera|Optional Features)
    UINT fGray = MF_GRAYED;
    if(m_cameraInitialized && (theCamera.HasAdvancedFeature() || theCamera.HasOptionalFeatures()))
      fGray = 0;

    pCmdUI->m_pMenu->EnableMenuItem(pCmdUI->m_nIndex, MF_BYPOSITION|fGray);    
  } else {
    // update first submenu item (File|Submenu|Foo)
    pCmdUI->Enable(theCamera.HasPIO());	
  }
}

void C1394CameraDemoApp::On1394OptionalSio() 
{
  char buf[256];
  sprintf(buf,"Camera Has Serial I/O Controls at 0x%08x\n",theCamera.GetSIOControlOffset());
  AfxMessageBox(buf,MB_OK | MB_ICONINFORMATION);
}

void C1394CameraDemoApp::OnUpdate1394OptionalSio(CCmdUI* pCmdUI) 
{
  pCmdUI->Enable(theCamera.HasSIO());	
}

void C1394CameraDemoApp::On1394OptionalStrobe() 
{
  char buf[256];
  sprintf(buf,"Camera Has Strobe Controls at 0x%08x\n",theCamera.GetStrobeControlOffset());
  AfxMessageBox(buf,MB_OK | MB_ICONINFORMATION);
}

void C1394CameraDemoApp::OnUpdate1394OptionalStrobe(CCmdUI* pCmdUI) 
{
  pCmdUI->Enable(theCamera.HasStrobe());	
}

void C1394CameraDemoApp::On1394OptionalVendor() 
{
  char buf[256];
  sprintf(buf,"Camera Has Vendor Unique Controls at 0x%08x\n",theCamera.GetAdvancedFeatureOffset());
  AfxMessageBox(buf,MB_OK | MB_ICONINFORMATION);
}

void C1394CameraDemoApp::OnUpdate1394OptionalVendor(CCmdUI* pCmdUI) 
{
  pCmdUI->Enable(theCamera.HasAdvancedFeature());	
}

void C1394CameraDemoApp::OnCameraStreamDualPacket() 
{
	// TODO: Add your command handler code here
  m_dualPacketSupport = !m_dualPacketSupport;
	
}

void C1394CameraDemoApp::OnUpdateCameraStreamDualPacket(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
  pCmdUI->Enable(TRUE);
  pCmdUI->SetCheck(m_dualPacketSupport);
}
