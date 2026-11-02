; Included in the Windows installer by electron-builder (build/installer.nsh).
;
; The installer names its version in Apps & features (DisplayVersion) as the
; app's version alone, 0.18.0 for every build of 0.18.0. winget tells
; installed builds apart by it, so name the build too, 0.18.0.71: the
; version of the Anchor+.exe just installed, which the release workflow sets
; with -c.buildNumber. A build without one stays 0.18.0.

!macro customInstall
  GetDLLVersion "$appExe" $R0 $R1
  IntOp $R2 $R0 >> 16
  IntOp $R3 $R0 & 0xFFFF
  IntOp $R4 $R1 >> 16
  IntOp $R5 $R1 & 0xFFFF
  ${If} $R5 != 0
    WriteRegStr SHELL_CONTEXT "${UNINSTALL_REGISTRY_KEY}" "DisplayVersion" "$R2.$R3.$R4.$R5"
  ${EndIf}
!macroend
