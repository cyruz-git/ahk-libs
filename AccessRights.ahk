; ----------------------------------------------------------------------------------------------------------------------
; Name .........: AccessRights library
; Description ..: This library is a collection of functions that deal with privileges and access rights.
; AHK Version ..: AHK_L 1.1.13.01 x32/64 Unicode
; Author .......: Cyruz  (http://ciroprincipe.info)
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Oct. 25, 2011 - v0.1 - First version.
; ..............: Dic. 27, 2013 - v0.2 - Added AccessRights_RunAsAdmin.
; ..............: Feb. 05, 2014 - v0.3 - Code refactoring. Unicode and x64 version. Added AccessRights_EnableSeDebug.
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: AccessRights_RunAsAdmin
; Description ..: Run the current AutoHotkey script as administrator.
; Author .......: shajul
; ----------------------------------------------------------------------------------------------------------------------
AccessRights_RunAsAdmin() {
    Global
    If ( !A_IsAdmin ) {
        Loop, %0%  ; For each parameter
            sParams .= A_Space . %A_Index%
        Local ShellExecute
        ShellExecute := (A_IsUnicode) ? "Shell32.dll\ShellExecute" : "Shell32.dll\ShellExecuteA"
        A_IsCompiled
        ? DllCall( ShellExecute, UInt,0, Str,"RunAs", Str,A_ScriptFullPath, Str,sParams , Str,A_WorkingDir, Int,1 )
        : DllCall( ShellExecute, UInt,0, Str,"RunAs", Str,A_AhkPath, Str,"""" A_ScriptFullPath """ " sParams
                               , Str,A_WorkingDir, Int,1 )
        ExitApp
    }
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: AccessRights_RunAsUser
; Description ..: Run a program as limited user, stripping all eventual administrator rights.
; Parameters ...: sCmdLine - Commandline to be executed.
; ----------------------------------------------------------------------------------------------------------------------
AccessRights_RunAsUser(sCmdLine)
{
    hMod := DllCall( "LoadLibrary", Str,"Advapi32.dll" )

    ; PROCESS_QUERY_INFORMATION = 0x0400
    hProc := DllCall( "OpenProcess", UInt,0x0400, Int,0, UInt,DllCall("GetCurrentProcessId") )

    ; TOKEN_ASSIGN_PRIMARY = 0x0001 ; TOKEN_DUPLICATE      = 0x0002
    ; TOKEN_QUERY          = 0x0008 ; TOKEN_ADJUST_DEFAULT = 0x0080
    DllCall( "Advapi32.dll\OpenProcessToken", Ptr,hProc, UInt,0x0001|0x0002|0x0008|0x0080, PtrP,hToken )

    ; The flag LUA_TOKEN doesn't work on XP, we need to deny the Administrators SID.
    If A_OSVersion in WIN_2000,WIN_XP
    {   ; Create an Administrators SID and fill SID structure.
        bOldSys = 1

        ; * [IMPORTANT]
        ; * The Well-Known Administrators SID needs 2 subauthorities: 
        ; * SECURITY_BUILTIN_DOMAIN_RID and DOMAIN_ALIAS_RID_ADMINS.
        ; * http://msdn.microsoft.com/en-us/library/windows/desktop/aa379597.aspx
        szSid := DllCall( "Advapi32.dll\GetSidLengthRequired", UChar,2 )
        VarSetCapacity(pSid, szSid, 0)

        ; Well-Known SID Structures - http://msdn.microsoft.com/en-us/library/cc980032.aspx
        ; WELL_KNOWN_SID_TYPE { ... WinBuiltinAdministratorsSid = 26 ... }
        DllCall( "Advapi32.dll\CreateWellKnownSid", UInt,26, Ptr,0, Ptr,&pSid, UIntP,szSid )

        ; SID_AND_ATTRIBUTES - http://msdn.microsoft.com/en-us/library/aa379595
        VarSetCapacity( SIDATTR, (A_PtrSize == 4) ? 8 : 16, 0 )
        NumPut( &pSid, &SIDATTR, 0, "Ptr"                     )
        ; missing SE_GROUP_USE_FOR_DENY_ONLY
    }

    ; Restrict the token (deny the Administrators SID on XP).
    ; DISABLE_MAX_PRIVILEGE = 0x1 ; LUA_TOKEN = 0x4
    DllCall( "Advapi32.dll\CreateRestrictedToken", Ptr,hToken, UInt,(bOldSys)?0x1:0x4, UInt,(bOldSys)?1:0
                                                 , Ptr,(bOldSys)?&SIDATTR:0, UInt,0, Ptr,0, UInt,0, Ptr,0
                                                 , PtrP,hResToken )

    ; We can set integrity levels only on Windows Vista/7/8.
    If A_OSVersion in WIN_VISTA,WIN_7,WIN_8
    {   ; Create an integrity SID and set the integrity level.
    
        ; * [IMPORTANT]
        ; * The Well-Known Integrity SIDs need 1 subauthority.
        ; * In our case, we need SECURITY_MANDATORY_LOW_RID or SECURITY_MANDATORY_MEDIUM_RID.
        ; * http://msdn.microsoft.com/en-us/library/bb625963.aspx
        szSid := DllCall( "Advapi32.dll\GetSidLengthRequired", UChar,1 )
        VarSetCapacity(pSid, szSid, 0)

        ; Well-Known SID Structures - http://msdn.microsoft.com/en-us/library/cc980032.aspx
        ; WELL_KNOWN_SID_TYPE { ... WinLowLabelSid = 66, WinMediumLabelSid = 67 ...}
        DllCall( "Advapi32.dll\CreateWellKnownSid", UInt,66, UInt,0, Ptr,&pSid, UIntP,szSid )

        ; SE_GROUP_INTEGRITY = 0x00000020L
        VarSetCapacity(      SIDATTR,  (A_PtrSize == 4) ? 8 : 16, 0      )
        NumPut( &pSid,       &SIDATTR, 0,                         "Ptr"  )
        NumPut( 0x00000020L, &SIDATTR, (A_PtrSize == 4) ? 4 : 8,  "UInt" )

        ; TOKEN_INFORMATION_CLASS = {... TokenIntegrityLevel = 25 ...}
        DllCall( "Advapi32.dll\SetTokenInformation", Ptr,hResToken, UInt,25, Ptr,&SIDATTR, UInt,A_PtrSize*2 )
    }

	; PROCESS_INFORMATION struct - http://msdn.microsoft.com/en-us/library/ms684873
	; STARTUPINFO struct         - http://msdn.microsoft.com/en-us/library/ms686331
	lpDesktop := "winsta0\default"
    VarSetCapacity( PROCINFO,  (A_PtrSize == 4) ? 16 : 24,  0            )
    VarSetCapacity( STARTINFO, (A_PtrSize == 4) ? 68 : 104, 0            )
    NumPut( (A_PtrSize == 4) ? 68 : 104, &STARTINFO, 0,           "UInt" )
	NumPut( &lpDesktop                 , &STARTINFO, A_PtrSize*2, "Ptr"  )

	; Run the process with the restricted token.
    ; NORMAL_PRIORITY_CLASS = 0x00000020
    DllCall( "Advapi32.dll\CreateProcessAsUser", Ptr,hResToken, Ptr,0, Str,sCmdLine, Ptr,0, Ptr,0, Int,0
											   , UInt,0x00000020, Ptr,0, Ptr,0, Ptr,&STARTINFO, Ptr,&PROCINFO )

    ; Close handles and free libraries and structures.
	DllCall( "Advapi32.dll\FreeSid", Ptr,pSid                        )
    DllCall( "CloseHandle",          Ptr,hProc                       )
    DllCall( "CloseHandle",          Ptr,hToken                      )
    DllCall( "CloseHandle",          Ptr,hResToken                   )
    DllCall( "CloseHandle",          Ptr,NumGet(&PROCINFO,0)         )
    DllCall( "CloseHandle",          Ptr,NumGet(&PROCINFO,A_PtrSize) )
    DllCall( "FreeLibrary",          Ptr,hMod                        )
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: AccessRights_EnableSeDebug
; Description ..: Enable the SE_DEBUG_PRIVILEGE on the current script instance.
; ----------------------------------------------------------------------------------------------------------------------
AccessRights_EnableSeDebug() {
	hProc := DllCall( "OpenProcess", UInt,0x0400, Int,0, UInt,DllCall("GetCurrentProcessId"), "Ptr" )
	DllCall( "Advapi32.dll\OpenProcessToken", Ptr,hProc, UInt,0x0020|0x0008, PtrP,hToken )

	VarSetCapacity(LUID, 8, 0)
	DllCall( "Advapi32.dll\LookupPrivilegeValue", Ptr,0, Str,"SeDebugPrivilege", Ptr,&LUID )

	VarSetCapacity( TOKPRIV, 16, 0   )					      ; TOKEN_PRIVILEGES structure: http://goo.gl/AGXeAp.
	NumPut( 1, &TOKPRIV, 0,   "UInt" )                        ; TOKEN_PRIVILEGES > PrivilegeCount.
	NumPut( NumGet( &LUID, 0, "UInt" ), &TOKPRIV, 4, "UInt" ) ; TOKEN_PRIVILEGES > LUID_AND_ATTRIBUTES > LUID > LoPart.
	NumPut( NumGet( &LUID, 4, "UInt" ), &TOKPRIV, 8, "UInt" ) ; TOKEN_PRIVILEGES > LUID_AND_ATTRIBUTES > LUID > HiPart.
	NumPut( 2, &TOKPRIV, 12,  "UInt" )                        ; TOKEN_PRIVILEGES > LUID_AND_ATTRIBUTES > Attributes.
														      ; SE_PRIVILEGE_ENABLED = 2.

	DllCall( "Advapi32.dll\AdjustTokenPrivileges", Ptr,hToken, Int,0, Ptr,&TOKPRIV, UInt,0, Ptr,0, Ptr,0 )
    DllCall( "CloseHandle", Ptr,hToken )
    DllCall( "CloseHandle", Ptr,hProc  )
}
