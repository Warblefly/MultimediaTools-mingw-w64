# Microsoft Developer Studio Project File - Name="1394camera" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Dynamic-Link Library" 0x0102

CFG=1394camera - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "1394camera.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "1394camera.mak" CFG="1394camera - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "1394camera - Win32 Release" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE "1394camera - Win32 Debug" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "1394camera - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "../Release"
# PROP Intermediate_Dir "../Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MT /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /D "_USRDLL" /D "MY1394CAMERA_EXPORTS" /YX /FD /c
# ADD CPP /nologo /MT /W3 /GX /O2 /D _WIN32_WINNT=0x500 /D WINVER=0x500 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /D "_USRDLL" /D "MY1394CAMERA_EXPORTS" /FR /FD /c
# SUBTRACT CPP /X /YX
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /dll /machine:I386
# ADD LINK32 shlwapi.lib strsafe.lib comctl32.lib setupapi.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /dll /debug /machine:I386

!ELSEIF  "$(CFG)" == "1394camera - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "../Debug"
# PROP Intermediate_Dir "../Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MTd /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /D "_USRDLL" /D "MY1394CAMERA_EXPORTS" /YX /FD /GZ /c
# ADD CPP /nologo /MTd /W3 /Gm /GX /ZI /Od /D _WIN32_WINNT=0x500 /D WINVER=0x500 /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /D "_USRDLL" /D "MY1394CAMERA_EXPORTS" /FD /GZ /c
# SUBTRACT CPP /YX
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /dll /debug /machine:I386 /pdbtype:sept
# ADD LINK32 shlwapi.lib strsafe.lib comctl32.lib setupapi.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /dll /debug /machine:I386 /out:"../Debug/1394camerad.dll" /pdbtype:sept

!ENDIF 

# Begin Target

# Name "1394camera - Win32 Release"
# Name "1394camera - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=.\1394CamAcq.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CamCap.cpp
# End Source File
# Begin Source File

SOURCE=.\1394Camera.cpp
# End Source File
# Begin Source File

SOURCE=.\1394camera.rc
# End Source File
# Begin Source File

SOURCE=.\1394CameraControl.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CameraControlSize.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CameraControlStrobe.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CameraControlTrigger.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CamFMR.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CamMem.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CamPIO.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CamReg.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CamRGB.cpp
# End Source File
# Begin Source File

SOURCE=.\1394CamSIO.cpp
# End Source File
# Begin Source File

SOURCE=.\1394main.c
# End Source File
# Begin Source File

SOURCE=.\ControlDialog.cpp
# End Source File
# Begin Source File

SOURCE=.\ControlPane.cpp
# End Source File
# Begin Source File

SOURCE=.\ControlSizeDialog.cpp
# End Source File
# Begin Source File

SOURCE=.\ControlWrappers.cpp
# End Source File
# Begin Source File

SOURCE=.\debug.c
# End Source File
# Begin Source File

SOURCE=.\isochapi.c
# End Source File
# Begin Source File

SOURCE=.\tables.c
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=.\1394camapi.h
# End Source File
# Begin Source File

SOURCE=.\1394Camera.h
# End Source File
# Begin Source File

SOURCE=.\1394CameraControl.h
# End Source File
# Begin Source File

SOURCE=.\1394CameraControlSize.h
# End Source File
# Begin Source File

SOURCE=.\1394CameraControlStrobe.h
# End Source File
# Begin Source File

SOURCE=.\1394CameraControlTrigger.h
# End Source File
# Begin Source File

SOURCE=.\1394common.h
# End Source File
# Begin Source File

SOURCE=.\ControlDialog.h
# End Source File
# Begin Source File

SOURCE=.\debug.h
# End Source File
# Begin Source File

SOURCE=.\pch.h
# End Source File
# Begin Source File

SOURCE=.\resource.h
# End Source File
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
# Begin Source File

SOURCE=.\res\1394CameraDemo.ico
# End Source File
# End Group
# End Target
# End Project
