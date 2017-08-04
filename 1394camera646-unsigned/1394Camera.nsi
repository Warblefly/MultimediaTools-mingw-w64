!include Library.nsh
!include x64.nsh

OutFile 1394camera646.exe
InstallDir "$PROGRAMFILES\CMU\1394Camera"
XPStyle on
Name "CMU 1394 Digital Camera Driver"

PageEx license
  LicenseText "License"
  LicenseData lgpl.txt
  LicenseForceSelection checkbox
PageExEnd

PageEx components
PageExEnd

PageEx directory
  DirVar $INSTDIR
PageExEnd

PageEx instfiles
PageExEnd

UninstPage uninstConfirm
UninstPage components
UninstPage instfiles

Section "-CMU 1394 Digital Camera Driver"
#!insertmacro InstallLib DLL NOTSHARED NOREBOOT_NOTPROTECTED 1394camera\Release\1394camera.dll $SYSDIR\1394camera.dll $SYSDIR
SetOutPath $SYSDIR
File "Release\1394camera.dll"
# also install the appropriate 64-bit native binary if we are running 64-bit
${If} ${RunningX64}
    !insertmacro DisableX64FSRedirection
    SetOutPath $SYSDIR
    ; TODO: figure out how to determine amd64 vs ia64
    File "Release\x64\1394Camera.dll"
    !insertmacro EnableX64FSRedirection
${Endif}
SetOutPath $INSTDIR\Driver
File "1394Camera.inf"
File "cmudc1394.cat"
File "1394cmdr_x86.sys"
File "1394cmdr_ia64.sys"
File "1394cmdr_amd64.sys"

; TODO: remove this segment when release signing is complete?
SetOutPath $INSTDIR\Driver\cert
File "certs\1394CameraTest.cer"
File "certs\installcerts.bat"
File "certs\CertMgr.exe"
File "certs\removecerts.bat"

SetOutPath $INSTDIR
File "Release\1394CameraDemo.exe" 
File "Release\Win32\1394CameraDemo32.exe"
File "Release\Win32\autoupdater.exe"
File "doc\html\1394camera.chm" 
${If} ${RunningX64}
    SetOutPath $INSTDIR\bin-x64
    File "Release\x64\1394CameraDemo32.exe"
    File "Release\x64\autoupdater.exe"
${Endif}

# create an initial entry in HKLM\Software\CMU\1394Camera to hold install path and guarantee user access
# NOTE: the name of this key is identical to the one in 1394CamReg.cpp
WriteRegStr HKLM "Software\CMU\1394Camera" "InstallPath" "$INSTDIR"

# Allow non-admin users to access an manipulate keys in this directory: note requires the AccessControl plugin
AccessControl::GrantOnRegKey HKLM "Software\CMU\1394Camera" "(BU)" "FullAccess"

WriteUninstaller $INSTDIR\uninstall.exe
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "DisplayName" "CMU 1394 Digital Camera Driver"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "InstallLocation" "$INSTDIR"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "DisplayIcon" "$INSTDIR\1394CamerDemo.exe,0"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "UninstallString" "$INSTDIR\uninstall.exe"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "Publisher" "Carnegie Mellon University"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "DisplayVersion" "6.4.6.200"
WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "NoModify" 1
WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "NoRepair" 1
SectionEnd

Section /o "Program Group and Desktop Shortcuts"
CreateDirectory "$SMPROGRAMS\CMU 1394Camera"
${If} ${RunningX64}
CreateShortCut "$SMPROGRAMS\CMU 1394Camera\1394Camera Demo 32-bit.lnk" "$INSTDIR\1394CameraDemo32.exe"
CreateShortCut "$SMPROGRAMS\CMU 1394Camera\1394Camera Demo 64-bit.lnk" "$INSTDIR\bin-x64\1394CameraDemo32.exe"
CreateShortCut "$DESKTOP\1394Camera Demo.lnk" "$INSTDIR\bin-x64\1394CameraDemo32.exe"
${Else}
CreateShortCut "$SMPROGRAMS\CMU 1394Camera\1394Camera Demo.lnk" "$INSTDIR\1394CameraDemo32.exe"
CreateShortCut "$DESKTOP\1394Camera Demo.lnk" "$INSTDIR\1394CameraDemo32.exe"
${Endif}
CreateShortCut "$SMPROGRAMS\CMU 1394Camera\1394Camera Documentation.lnk" "$INSTDIR\1394camera.chm"
CreateShortCut "$SMPROGRAMS\CMU 1394Camera\Uninstall.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

Section /o "Disable Default Windows Driver"
DetailPrint "Disabling default windows driver: $WINDIR\inf\image.[inf,pnf]"
IfFileExists $WINDIR\inf\image.inf 0 movedinf
  Rename $WINDIR\inf\image.inf $WINDIR\inf\image.ibk
movedinf:
IfFileExists $WINDIR\inf\image.pnf 0 movedpnf
  Rename $WINDIR\inf\image.pnf $WINDIR\inf\image.pbk
movedpnf:
SectionEnd

Section /o "Update Driver for Attached Devices"
    DetailPrint "Updating Driver for IIDC DCAM-Compliant Cameras..."
    ${If} ${RunningX64}
        ; TODO - remove me when release signature is complete
    	MessageBox MB_YESNO "This version of the CMU Camera driver is not yet digitally signed.  Would you like to enable test mode and install the test-signing certificates?  Answering 'No' here requires that you disable driver signature enforcement manually per-boot via the Windows Boot Menu (F8)" IDYES installcerts IDNO certsdone
	installcerts:
        ExecWait "$INSTDIR\Driver\cert\installcerts.bat" $0
	DetailPrint "installcerts:$0"
        ExecWait "$INSTDIR\bin-x64\autoupdater.exe /teston" $0
	DetailPrint "autoupdater:$0"
        MessageBox MB_OK "Test mode certificates installed.  If you are not already running in test mode, you will have to restart your computer for the CMU camera driver to successfully load"
        certsdone:
        ExecWait "$INSTDIR\bin-x64\autoupdater.exe /i" $0
	DetailPrint "autoupdater:$0"
    ${Else}
    	ExecWait "$INSTDIR\autoupdater.exe /i" $0
	DetailPrint "autoupdater:$0"
    ${Endif}
SectionEnd

SectionGroup "Development Files"
Section /o "Development Files"
SetOutPath $INSTDIR\lib
File "Release\1394Camera.dll"
File "Debug\1394Camerad.dll"
File "Release\1394Camera.lib"
File "Debug\1394camerad.lib"
SetOutPath $INSTDIR\include
File "1394camera\1394camapi.h"
File "1394camera\1394common.h"
File "1394camera\1394Camera.h"
File "1394camera\1394CameraControl.h"
File "1394camera\1394CameraControlSize.h"
File "1394camera\1394CameraControlStrobe.h"
File "1394camera\1394CameraControlTrigger.h"
SectionEnd

Section /o "Development Files (64-bit)"
SetOutPath $INSTDIR\lib64\Itanium
File "Release\Itanium\1394Camera.dll"
File "Debug\Itanium\1394Camerad.dll"
File "Release\Itanium\1394Camera.lib"
File "Debug\Itanium\1394camerad.lib"
SetOutPath $INSTDIR\lib64\x64
File "Release\x64\1394Camera.dll"
File "Debug\x64\1394Camerad.dll"
File "Release\x64\1394Camera.lib"
File "Debug\x64\1394camerad.lib"
SectionEnd

Section /o "Demo Application Source (MFC)"
SetOutPath $INSTDIR\1394CameraDemo-MFC
File "1394CameraDemo\1394CameraDemo.dsw"
File "1394CameraDemo\1394CameraDemo.dsp"
File "1394CameraDemo\1394CameraDemo.cpp"
File "1394CameraDemo\1394CameraDemo.exe.manifest"
File "1394CameraDemo\1394camerademo.h"
File "1394CameraDemo\1394CameraDemo.rc"
File "1394CameraDemo\ChildView.cpp"
File "1394CameraDemo\ChildView.h"
File "1394CameraDemo\TwiddleDialog.cpp"
File "1394CameraDemo\TwiddleDialog.h"
File "1394CameraDemo\GetIntegerDialog.cpp"
File "1394CameraDemo\GetIntegerDialog.h"
File "1394CameraDemo\MainFrm.cpp"
File "1394CameraDemo\MainFrm.h"
File "1394CameraDemo\resource.h"
File "1394CameraDemo\StdAfx.cpp"
File "1394CameraDemo\StdAfx.h"
SetOutPath $INSTDIR\1394CameraDemo-MFC\res
File "1394CameraDemo\res\1394CameraDemo.ico"
File "1394CameraDemo\res\1394CameraDemo.rc2"
File "1394CameraDemo\res\toolbar1.bmp"
SectionEnd

Section /o "Demo Application Source (Win32)"
SetOutPath $INSTDIR\1394CameraDemo-Win32
File "1394CameraDemo32\1394CameraDemo32.dsp"
File "1394CameraDemo32\1394CameraDemo32.vcproj"
File "1394CameraDemo32\WinMain.cpp"
File "1394CameraDemo32\1394CameraDemo.cpp"
File "1394CameraDemo32\1394CameraDemo.exe.manifest"
File "1394CameraDemo32\1394CameraDemo.h"
File "1394CameraDemo32\1394CameraDemo.rc"
File "1394CameraDemo32\TwiddleDialog.cpp"
File "1394CameraDemo32\TwiddleDialog.h"
File "1394CameraDemo32\GetIntegerDialog.cpp"
File "1394CameraDemo32\GetIntegerDialog.h"
File "1394CameraDemo32\BasicModalDialog.cpp"
File "1394CameraDemo32\BasicModalDialog.h"
File "1394CameraDemo32\resource.h"
SetOutPath $INSTDIR\1394CameraDemo-Win32\res
File "1394CameraDemo32\res\1394CameraDemo.ico"
File "1394CameraDemo32\res\1394CameraDemo.rc2"
SectionEnd

Section /o "Debug Binaries"
#!insertmacro InstallLib DLL NOTSHARED NOREBOOT_NOTPROTECTED 1394Camera\Debug\1394camerad.dll $SYSDIR\1394camerad.dll $SYSDIR
SetOutPath $SYSDIR
File "Debug\1394camerad.dll"
${If} ${RunningX64}
    !insertmacro DisableX64FSRedirection
    SetOutPath $SYSDIR
    File "Debug\x64\1394camerad.dll"
    !insertmacro EnableX64FSRedirection
${Endif}
SetOutPath $INSTDIR
File "Debug\1394CameraDemoD.exe" 
File "Debug\Win32\1394CameraDemo32d.exe" 
${If} ${RunningX64}
    SetOutPath $INSTDIR\bin-x64
    File "Debug\x64\1394CameraDemo32d.exe"
${Endif}
SectionEnd  

Section /o "Kernel Debugging Symbol Files"
SetOutPath $INSTDIR\Driver\x86
File "1394cmdr\objfre_wnet_x86\i386\1394cmdr.sym"
File "1394cmdr\objfre_wnet_x86\i386\1394cmdr.pdb"
SetOutPath $INSTDIR\Driver\amd64
File "1394cmdr\objfre_wnet_amd64\amd64\1394cmdr.sym"
File "1394cmdr\objfre_wnet_amd64\amd64\1394cmdr.pdb"
SetOutPath $INSTDIR\Driver\ia64
File "1394cmdr\objfre_wnet_ia64\ia64\1394cmdr.pdb"
SectionEnd

SectionGroupEnd

Section "-un.Delete Installed Files"
    ReadRegStr $INSTDIR HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver" "InstallLocation"

    IfFileExists $WINDIR\inf\image.ibk 0 movedinf
        DetailPrint "Restoring default windows driver (image.inf)..."
        Rename $WINDIR\inf\image.ibk $WINDIR\inf\image.inf
    movedinf:
    IfFileExists $WINDIR\inf\image.pbk 0 movedpnf
        Rename $WINDIR\inf\image.pbk $WINDIR\inf\image.pnf
    movedpnf:
    
    DetailPrint "Removing devices presently using the CMU driver and cleaning up oemXX.inf files"
    ${If} ${RunningX64}
        ; TODO - remove me when release signature is complete
        ExecWait "$INSTDIR\Driver\cert\removecerts.bat" $0
	DetailPrint "removecerts:$0"
        ExecWait "$INSTDIR\bin-x64\autoupdater.exe /testoff" $0
	DetailPrint "autoupdater:$0"
    	ExecWait "$INSTDIR\bin-x64\autoupdater.exe /u" $0
	DetailPrint "autoupdater:$0"
    ${Else}
    	ExecWait "$INSTDIR\autoupdater.exe /u" $0
	DetailPrint "autoupdater:$0"
    ${Endif}

    IfFileExists "$SYSDIR\Drivers\1394cmdr.sys" 0 nukedsys
        Delete /REBOOTOK "$SYSDIR\Drivers\1394cmdr.sys"
    nukedsys:
    DetailPrint "Deactivation of CMU 1394 Digital Camera Driver Complete, removing installed files"

    RMDir /r /REBOOTOK $INSTDIR
    RMDir /r /REBOOTOK "$SMPROGRAMS\CMU 1394Camera"
    Delete "$DESKTOP\1394Camera Demo.lnk"
    IfFileExists $SYSDIR\1394camerad.dll 0 nodebugdll
      Delete $SYSDIR\1394camerad.dll
    nodebugdll:
    Delete $SYSDIR\1394camera.dll   
    DeleteRegKEY HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\CMU 1394 Digital Camera Driver"
    ${If} ${RunningX64}
        !insertmacro DisableX64FSRedirection
        IfFileExists $SYSDIR\1394camerad.dll 0 nodebug64dll
          Delete $SYSDIR\1394camerad.dll
        nodebug64dll:
        Delete $SYSDIR\1394camera.dll   
        !insertmacro EnableX64FSRedirection
    ${Endif}
SectionEnd

Section /o "un.Remove Registry Settings for Cameras"
    DeleteRegKEY HKLM "Software\CMU\1394Camera"
SectionEnd
