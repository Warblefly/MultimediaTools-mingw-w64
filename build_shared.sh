#!/bin/bash

# This calls the script with the parameters I use daily.
# No other parameters have been tested.
# My aim is to make the cross compilation script default to these values
# so that this command line can be discarded.


# A default, switch to n for testing other parts of the build quickly.

build_ffmpeg=y
dump_archive=y
upload_archive=y

# This is the filename where the complete binary archive is stored
dump_file="mingw-multimedia-executables-shared.zip"

# This works out how many CPUs we have
gcc_cpu_count="$(grep -c processor /proc/cpuinfo)" 

# This is the location that scp copies your archive to
# You will UNDOUBTEDLY want to change this.
upload_location="john@johnwarburton.net:~/www/gallery/html/"

while getopts faup opt_check; do
  case $opt_check in
    f)
      echo "Not building FFmpeg"
      build_ffmpeg=n 
      ;;
    a)
      echo "Not creating archive"
      dump_archive=n
      ;;
    u)
      echo "Not uploading archive"
      upload_archive=n
      ;;
    *)
      echo "Invalid option"
      ;;
  esac
done

if [[ "${upload_archive}" = [Yy] ]]; then
  read -s -p "Password for scp when uploading: " upload_password
fi

echo "Going to cross compile."
echo "build_ffmpeg is ${build_ffmpeg}"
echo "dump_archive is ${dump_archive}"
echo "Archive will be dumped to ${dump_file}"
echo "Archive will be uploaded to ${upload_location}"


./cross_compile_ffmpeg_shared.sh --build-ffmpeg-shared=n --build-ffmpeg-static=$build_ffmpeg --disable-nonfree=n --sandbox-ok=y --build-libmxf=y --build-mp4box=y --build-choice=win64 --git-get-latest=y --prefer-stable=n --build-mplayer=n --gcc-cpu-count=$gcc_cpu_count || { echo "Build failure. Please see error messages above." ; exit 1; } 

# A few shared libraries necessary for runtime have been stored in ./lib.
# These must now be moved somewhere more useful.

# Ensure the LICENSE.rtf file goes where the installer will find it
# and don't proceed if there isn't a licence

cp -v LICENSE.rtf sandbox/mingw-w64-x86_64/x86_64-w64-mingw32/LICENSE.rtf || exit 1

# Make archive of executables
if  [[ "$dump_archive" = [Yy] ]]; then
  echo "Archive dump selected."
  # Put the unzip scripts where we can find them.
  cp -v install-zipfile.ps1 sandbox/mingw-w64-x86_64/x86_64-w64-mingw32/bin/install-zipfile.ps1
  cp -v install-zipfile.cmd sandbox/mingw-w64-x86_64/x86_64-w64-mingw32/bin/install-zipfile.cmd
  cp -v fonts.conf sandbox/mingw-w64-x86_64/x86_64-w64-mingw32/
  cd sandbox/mingw-w64-x86_64/x86_64-w64-mingw32
  rm -v archive_list.files
  # Symbolic links are de-referenced because Windows doesn't understand these.
#  zip -r -9 -v -db -dc ${dump_file}  ./bin/*exe ./bin/*com ./bin/*dll ./bin/*py ./bin/*pl ./bin/*cmd ./bin/*config ./bin/platforms/*dll ./bin/lib/* ./bin/share/* ./bin/jack/* ./lib/frei0r-1/* ./plugins/* ./share/OpenCV/* ./share/tessdata ./share/terminfo ./share/misc/magic.mgc ./share/vim/* ./bin/install-zipfile.ps1 ./bin/install-zipfile.cmd || exit 1
  # Starting to build the archive list for a proper Windows installer
  archive_list=('./bin/*exe' './bin/*com' './bin/*dll' './bin/*py' './bin/*pl' './bin/*cmd' './bin/*config' './bin/platforms/*dll' './bin/lib/*' './bin/share/*' './bin/jack/*' './lib/frei0r-1/*' './lib/gdk-pixbuf-2.0/2.10.0/loaders/*dll' './plugins/*' './share/*' './bin/install-zipfile.ps1' './bin/install-zipfile.cmd')
  for item in "${archive_list[@]}"; do
    find $item -name "*" -printf "File /nonfatal \"%p\"\n" >> archive_list.files
  done

# Build the NSIS installer script

  rm -v install_mm.nsi
# Preamble
  cat << 'EOF' >> install_mm.nsi
/**
 *  EnvVarUpdate.nsh
 *    : Environmental Variables: append, prepend, and remove entries
 *
 *     WARNING: If you use StrFunc.nsh header then include it before this file
 *              with all required definitions. This is to avoid conflicts
 *
 *  Usage:
 *    ${EnvVarUpdate} "ResultVar" "EnvVarName" "Action" "RegLoc" "PathString"
 *
 *  Credits:
 *  Version 1.0 
 *  * Cal Turney (turnec2)
 *  * Amir Szekely (KiCHiK) and e-circ for developing the forerunners of this
 *    function: AddToPath, un.RemoveFromPath, AddToEnvVar, un.RemoveFromEnvVar,
 *    WriteEnvStr, and un.DeleteEnvStr
 *  * Diego Pedroso (deguix) for StrTok
 *  * Kevin English (kenglish_hi) for StrContains
 *  * Hendri Adriaens (Smile2Me), Diego Pedroso (deguix), and Dan Fuhry  
 *    (dandaman32) for StrReplace
 *
 *  Version 1.1 (compatibility with StrFunc.nsh)
 *  * techtonik
 *
 *  http://nsis.sourceforge.net/Environmental_Variables:_append%2C_prepend%2C_and_remove_entries
 *
 */
 
 
!ifndef ENVVARUPDATE_FUNCTION
!define ENVVARUPDATE_FUNCTION
!verbose push
!verbose 3
!include "LogicLib.nsh"
!include "WinMessages.NSH"
!include "StrFunc.nsh"
 
; ---- Fix for conflict if StrFunc.nsh is already includes in main file -----------------------
!macro _IncludeStrFunction StrFuncName
  !ifndef ${StrFuncName}_INCLUDED
    ${${StrFuncName}}
  !endif
  !ifndef Un${StrFuncName}_INCLUDED
    ${Un${StrFuncName}}
  !endif
  !define un.${StrFuncName} "${Un${StrFuncName}}"
!macroend
 
!insertmacro _IncludeStrFunction StrTok
!insertmacro _IncludeStrFunction StrStr
!insertmacro _IncludeStrFunction StrRep
 
; ---------------------------------- Macro Definitions ----------------------------------------
!macro _EnvVarUpdateConstructor ResultVar EnvVarName Action Regloc PathString
  Push "${EnvVarName}"
  Push "${Action}"
  Push "${RegLoc}"
  Push "${PathString}"
    Call EnvVarUpdate
  Pop "${ResultVar}"
!macroend
!define EnvVarUpdate '!insertmacro "_EnvVarUpdateConstructor"'
 
!macro _unEnvVarUpdateConstructor ResultVar EnvVarName Action Regloc PathString
  Push "${EnvVarName}"
  Push "${Action}"
  Push "${RegLoc}"
  Push "${PathString}"
    Call un.EnvVarUpdate
  Pop "${ResultVar}"
!macroend
!define un.EnvVarUpdate '!insertmacro "_unEnvVarUpdateConstructor"'
; ---------------------------------- Macro Definitions end-------------------------------------
 
;----------------------------------- EnvVarUpdate start----------------------------------------
!define hklm_all_users     'HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'
!define hkcu_current_user  'HKCU "Environment"'
 
!macro EnvVarUpdate UN
 
Function ${UN}EnvVarUpdate
 
  Push $0
  Exch 4
  Exch $1
  Exch 3
  Exch $2
  Exch 2
  Exch $3
  Exch
  Exch $4
  Push $5
  Push $6
  Push $7
  Push $8
  Push $9
  Push $R0
 
  /* After this point:
  -------------------------
     $0 = ResultVar     (returned)
     $1 = EnvVarName    (input)
     $2 = Action        (input)
     $3 = RegLoc        (input)
     $4 = PathString    (input)
     $5 = Orig EnvVar   (read from registry)
     $6 = Len of $0     (temp)
     $7 = tempstr1      (temp)
     $8 = Entry counter (temp)
     $9 = tempstr2      (temp)
     $R0 = tempChar     (temp)  */
 
  ; Step 1:  Read contents of EnvVarName from RegLoc
  ;
  ; Check for empty EnvVarName
  ${If} $1 == ""
    SetErrors
    DetailPrint "ERROR: EnvVarName is blank"
    Goto EnvVarUpdate_Restore_Vars
  ${EndIf}
 
  ; Check for valid Action
  ${If}    $2 != "A"
  ${AndIf} $2 != "P"
  ${AndIf} $2 != "R"
    SetErrors
    DetailPrint "ERROR: Invalid Action - must be A, P, or R"
    Goto EnvVarUpdate_Restore_Vars
  ${EndIf}
 
  ${If} $3 == HKLM
    ReadRegStr $5 ${hklm_all_users} $1     ; Get EnvVarName from all users into $5
  ${ElseIf} $3 == HKCU
    ReadRegStr $5 ${hkcu_current_user} $1  ; Read EnvVarName from current user into $5
  ${Else}
    SetErrors
    DetailPrint 'ERROR: Action is [$3] but must be "HKLM" or HKCU"'
    Goto EnvVarUpdate_Restore_Vars
  ${EndIf}
 
  ; Check for empty PathString
  ${If} $4 == ""
    SetErrors
    DetailPrint "ERROR: PathString is blank"
    Goto EnvVarUpdate_Restore_Vars
  ${EndIf}
 
  ; Make sure we've got some work to do
  ${If} $5 == ""
  ${AndIf} $2 == "R"
    SetErrors
    DetailPrint "$1 is empty - Nothing to remove"
    Goto EnvVarUpdate_Restore_Vars
  ${EndIf}
 
  ; Step 2: Scrub EnvVar
  ;
  StrCpy $0 $5                             ; Copy the contents to $0
  ; Remove spaces around semicolons (NOTE: spaces before the 1st entry or
  ; after the last one are not removed here but instead in Step 3)
  ${If} $0 != ""                           ; If EnvVar is not empty ...
    ${Do}
      ${${UN}StrStr} $7 $0 " ;"
      ${If} $7 == ""
        ${ExitDo}
      ${EndIf}
      ${${UN}StrRep} $0  $0 " ;" ";"         ; Remove '<space>;'
    ${Loop}
    ${Do}
      ${${UN}StrStr} $7 $0 "; "
      ${If} $7 == ""
        ${ExitDo}
      ${EndIf}
      ${${UN}StrRep} $0  $0 "; " ";"         ; Remove ';<space>'
    ${Loop}
    ${Do}
      ${${UN}StrStr} $7 $0 ";;" 
      ${If} $7 == ""
        ${ExitDo}
      ${EndIf}
      ${${UN}StrRep} $0  $0 ";;" ";"
    ${Loop}
 
    ; Remove a leading or trailing semicolon from EnvVar
    StrCpy  $7  $0 1 0
    ${If} $7 == ";"
      StrCpy $0  $0 "" 1                   ; Change ';<EnvVar>' to '<EnvVar>'
    ${EndIf}
    StrLen $6 $0
    IntOp $6 $6 - 1
    StrCpy $7  $0 1 $6
    ${If} $7 == ";"
     StrCpy $0  $0 $6                      ; Change ';<EnvVar>' to '<EnvVar>'
    ${EndIf}
    ; DetailPrint "Scrubbed $1: [$0]"      ; Uncomment to debug
  ${EndIf}
 
  /* Step 3. Remove all instances of the target path/string (even if "A" or "P")
     $6 = bool flag (1 = found and removed PathString)
     $7 = a string (e.g. path) delimited by semicolon(s)
     $8 = entry counter starting at 0
     $9 = copy of $0
     $R0 = tempChar      */
 
  ${If} $5 != ""                           ; If EnvVar is not empty ...
    StrCpy $9 $0
    StrCpy $0 ""
    StrCpy $8 0
    StrCpy $6 0
 
    ${Do}
      ${${UN}StrTok} $7 $9 ";" $8 "0"      ; $7 = next entry, $8 = entry counter
 
      ${If} $7 == ""                       ; If we've run out of entries,
        ${ExitDo}                          ;    were done
      ${EndIf}                             ;
 
      ; Remove leading and trailing spaces from this entry (critical step for Action=Remove)
      ${Do}
        StrCpy $R0  $7 1
        ${If} $R0 != " "
          ${ExitDo}
        ${EndIf}
        StrCpy $7   $7 "" 1                ;  Remove leading space
      ${Loop}
      ${Do}
        StrCpy $R0  $7 1 -1
        ${If} $R0 != " "
          ${ExitDo}
        ${EndIf}
        StrCpy $7   $7 -1                  ;  Remove trailing space
      ${Loop}
      ${If} $7 == $4                       ; If string matches, remove it by not appending it
        StrCpy $6 1                        ; Set 'found' flag
      ${ElseIf} $7 != $4                   ; If string does NOT match
      ${AndIf}  $0 == ""                   ;    and the 1st string being added to $0,
        StrCpy $0 $7                       ;    copy it to $0 without a prepended semicolon
      ${ElseIf} $7 != $4                   ; If string does NOT match
      ${AndIf}  $0 != ""                   ;    and this is NOT the 1st string to be added to $0,
        StrCpy $0 $0;$7                    ;    append path to $0 with a prepended semicolon
      ${EndIf}                             ;
 
      IntOp $8 $8 + 1                      ; Bump counter
    ${Loop}                                ; Check for duplicates until we run out of paths
  ${EndIf}
 
  ; Step 4:  Perform the requested Action
  ;
  ${If} $2 != "R"                          ; If Append or Prepend
    ${If} $6 == 1                          ; And if we found the target
      DetailPrint "Target is already present in $1. It will be removed and"
    ${EndIf}
    ${If} $0 == ""                         ; If EnvVar is (now) empty
      StrCpy $0 $4                         ;   just copy PathString to EnvVar
      ${If} $6 == 0                        ; If found flag is either 0
      ${OrIf} $6 == ""                     ; or blank (if EnvVarName is empty)
        DetailPrint "$1 was empty and has been updated with the target"
      ${EndIf}
    ${ElseIf} $2 == "A"                    ;  If Append (and EnvVar is not empty),
      StrCpy $0 $0;$4                      ;     append PathString
      ${If} $6 == 1
        DetailPrint "appended to $1"
      ${Else}
        DetailPrint "Target was appended to $1"
      ${EndIf}
    ${Else}                                ;  If Prepend (and EnvVar is not empty),
      StrCpy $0 $4;$0                      ;     prepend PathString
      ${If} $6 == 1
        DetailPrint "prepended to $1"
      ${Else}
        DetailPrint "Target was prepended to $1"
      ${EndIf}
    ${EndIf}
  ${Else}                                  ; If Action = Remove
    ${If} $6 == 1                          ;   and we found the target
      DetailPrint "Target was found and removed from $1"
    ${Else}
      DetailPrint "Target was NOT found in $1 (nothing to remove)"
    ${EndIf}
    ${If} $0 == ""
      DetailPrint "$1 is now empty"
    ${EndIf}
  ${EndIf}
 
  ; Step 5:  Update the registry at RegLoc with the updated EnvVar and announce the change
  ;
  ClearErrors
  ${If} $3  == HKLM
    WriteRegExpandStr ${hklm_all_users} $1 $0     ; Write it in all users section
  ${ElseIf} $3 == HKCU
    WriteRegExpandStr ${hkcu_current_user} $1 $0  ; Write it to current user section
  ${EndIf}
 
  IfErrors 0 +4
    MessageBox MB_OK|MB_ICONEXCLAMATION "Could not write updated $1 to $3"
    DetailPrint "Could not write updated $1 to $3"
    Goto EnvVarUpdate_Restore_Vars
 
  ; "Export" our change
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
 
  EnvVarUpdate_Restore_Vars:
  ;
  ; Restore the user's variables and return ResultVar
  Pop $R0
  Pop $9
  Pop $8
  Pop $7
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Push $0  ; Push my $0 (ResultVar)
  Exch
  Pop $0   ; Restore his $0
 
FunctionEnd
 
!macroend   ; EnvVarUpdate UN
!insertmacro EnvVarUpdate ""
!insertmacro EnvVarUpdate "un."
;----------------------------------- EnvVarUpdate end----------------------------------------
 
!verbose pop
!endif


OutFile "MultimediaTools-mingw-w64-Open-source.exe"
BrandingText "Windows 64-bit only"
Name "Open Source Multimedia Tools"
CompletedText "Installation is complete."
InstallDir "$PROGRAMFILES64\ffmpeg\"
LicenseData LICENSE.rtf
LicenseForceSelection radiobuttons "Accept" "Decline"
ShowInstDetails show
ShowUninstDetails show
SetCompressor lzma
SetCompressorDictSize 16
XPStyle on


Page license
Page directory
Page instfiles



Section "install"
setOutPath $INSTDIR

setOutPath "$INSTDIR\bin"
File /nonfatal /r "./bin/*.exe"
File /nonfatal /r "./bin/*.com"
File /nonfatal /r "./bin/*.dll"
File /nonfatal /r "./bin/*.py"
File /nonfatal /r "./bin/*.pl"
File /nonfatal /r "./bin/*.cmd"
File /nonfatal /r "./bin/*config"
File /nonfatal /r "./bin/*.config"

setOutPath "$INSTDIR\bin\platforms"
File /nonfatal /r "./bin/platforms/*.dll"

setOutPath "$INSTDIR\bin\lib"
File /nonfatal /r "./bin/lib/*.*"

setOutPath "$INSTDIR\bin\share"
File /nonfatal /r "./bin/share/*.*"

setOutPath "$INSTDIR\bin\jack"
File /nonfatal /r "./bin/jack/*.*"

setOutPath "$INSTDIR\lib\frei0r-1"
File /nonfatal /r "./lib/frei0r-1/*.*"

setOutPath "$INSTDIR\lib\gdk-pixbuf-2.0\2.10.0\loaders"
File /nonfatal /r "./lib/gdk-pixbuf-2.0/2.10.0/loaders/*.dll"

setOutPath "$INSTDIR\lib\gtk-3.0\3.0.0\immodules"
File /nonfatal /r "./lib/gtk-3.0\3.0.0\immodules\*.dll"

setOutPath "$INSTDIR\plugins"
File /nonfatal /r "./plugins/*.*"

setOutPath "$INSTDIR\share"
File /nonfatal /r "./share/*.*"

setOutPath "$INSTDIR\doc"
File /nonfatal /r *./doc/*.*"

setOutPath "$LOCALAPPDATA\fontconfig"
File /nonfatal fonts.conf

setOutPath "$INSTDIR"
writeUninstaller "$INSTDIR\uninstall.exe"

${EnvVarUpdate} $0 PATH "A" "HKCU" "$INSTDIR\bin"
${EnvVarUpdate} $0 FONTCONFIG_FILE "A" "HKCU" "fonts.conf"
${EnvVarUpdate} $0 FONTCONFIG_PATH "A" "HKCU" "$LOCALAPPDATA\fontconfig"
${EnvVarUpdate} $0 FREI0R_PATH "A" "HKCU" "$INSTDIR\lib\frei0r-1"
${EnvVarUpdate} $0 TESSDATA_PREFIX "A" "HKCU" "$INSTDIR\share\"
${EnvVarUpdate} $0 TERMINFO "A" "HKCU" "$INSTDIR\share\terminfo"
${EnvVarUpdate} $0 VIMRUNTIME "A" "HKCU" "$INSTDIR\share\vim"
${EnvVarUpdate} $0 GDK_PIXBUF_MODULE_FILE "A" "HKCU" "$INSTDIR\lib\gdk-pixbuf-2.0\2.10.0\loaders.cache"

; Set up the GTK loader cache

ExecWait '"$INSTDIR\bin\gdk-pixbuf-query-loaders.exe" > "$INSTDIR\lib\gdk-pixbuf-2.0\2.10.0\loaders.cache"' $0
ExecWait '"$INSTDIR\bin\update-mime-database.exe" > "$INSTDIR\share\mime"' $0
DetailPrint "The pixbuf loader ran as $INSTDIR\bin\gdk-pixbuf-query-loaders.exe returned value $0"

SectionEnd


Section "uninstall"

RMDir /r "$INSTDIR\bin"
RMDir /r "$INSTDIR\lib"
RMDir /r "$INSTDIR\plugins"
RMDir /r "$INSTDIR\share"
RMDir /r "$INSTDIR\doc"
Delete "$INSTDIR\uninstall.exe"
SectionEnd
EOF

  # Make the Windows installer
  makensis install_mm.nsi
  # Move the Windows installer into the root of the build tree
  mv -v  MultimediaTools-mingw-w64-Open-source.exe ../../..
  cd ../../..
  echo "Archive made and stored in MultimediaTools-mingw-w64-Open-source.exe"
fi

if [[ "${upload_archive}" = [Yy] ]]; then
  echo "Uploading archive to ${upload_location}..."
  sshpass -p "${upload_password}" scp -v -l 250 "MultimediaTools-mingw-w64-Open-source.exe" "${upload_location}"
# We also upload the installation command files separately.
#  echo "Uploading installation scripts to ${upload_location}..."
#  sshpass -p "${upload_password}" scp -v -l 250 "install-zipfile.ps1" "install-zipfile.cmd" "${upload_location}"
  echo "SSH uploads complete."
fi

echo "Build script finished."
