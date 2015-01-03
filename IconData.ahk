; ----------------------------------------------------------------------------------------------------------------------
; Name .........: IconData library
; Description ..: Library for creation of tray icons from hexadecimal data. Only 16x16 icons allowed.
; AHK Version ..: AHK_L 1.1.13.01 x32/64 Unicode
; Author .......: SKAN (http://goo.gl/Ch819S) & Cyruz (http://ciroprincipe.info)
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Dic. 31, 2013 - v0.1 - First revision.
; ..............: Jan. 18, 2014 - v0.2 - Used A_ScriptHwnd instead of WinExist(...).
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: IconData_Create
; Description ..: Creates an icon from hex data and returns a handle to it.
; Parameters ...: IconDataHex - Hex data of the desired icon.
; Return .......: Handle to the icon on success or NULL on error.
; ----------------------------------------------------------------------------------------------------------------------
IconData_Create(ByRef IconDataHex) {
    VarSetCapacity(IconData, (nSize := StrLen(IconDataHex) // 2))
    Loop %nSize% ; MCode by Laszlo Hars: http://www.autohotkey.com/forum/viewtopic.php?t=21172
        NumPut("0x" . SubStr(IconDataHex, 2*A_Index-1, 2), IconData, A_Index-1, "Char")
    IconDataHex := "" ; Hex contents needed no more

    Return DllCall( "CreateIconFromResourceEx", Ptr,&IconData+22, UInt,NumGet(IconData,14)
                                              , Int,1, UInt,0x00030000, Int,16, Int,16, UInt,0 )
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: IconData_Set
; Description ..: Changes the icon for the running script.
; Parameters ...: hIcon - Handle to a previously created icon.
; Return .......: TRUE on success, FALSE on error.
; ----------------------------------------------------------------------------------------------------------------------
IconData_Set(hIcon) {
    ; Thanks Chris: http://www.autohotkey.com/forum/viewtopic.php?p=69461#69461
    Gui +LastFound              ; Set our GUI as LastFound window (affects next two lines).
    SendMessage, 0x80, 0, hIcon ; Set the Titlebar Icon (WM_SETICON = 0x80).
    SendMessage, 0x80, 1, hIcon ; Set the Alt-Tab icon (WM_SETICON = 0x80).

    ; Creating NOTIFYICONDATA: www.msdn.microsoft.com/en-us/library/aa930660.aspx
    ; Thanks Lexikos: www.autohotkey.com/forum/viewtopic.php?p=162175#162175
    sz := VarSetCapacity( NID, (A_PtrSize == 4) ? 832 : 848, 0 )
    NumPut( sz,           NID, 0                               )
    NumPut( A_ScriptHwnd, NID, (A_PtrSize == 4) ? 4   : 8      )
    NumPut( 1028,         NID, (A_PtrSize == 4) ? 8   : 16     )
    NumPut( 2,            NID, (A_PtrSize == 4) ? 12  : 20     )
    NumPut( hIcon,        NID, (A_PtrSize == 4) ? 20  : 32     )

    Menu, Tray, Icon                                                     ; Show the default Tray icon...
    Return DllCall( "Shell32.dll\Shell_NotifyIcon", UInt,0x1, Ptr,&NID ) ; ...and immediately modify it.
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: IconData_Close
; Description ..: Closes icon handle.
; Parameters ...: hIcon - Handle to a previously created icon.
; Return .......: Nonzero on success, zero on error.
; ----------------------------------------------------------------------------------------------------------------------
IconData_Close(hIcon) {
    Return DllCall( "CloseHandle", Ptr,hIcon )
}

/* EXAMPLE CODE:
IconDataHex =
( Join
000001000100101010000100040028010000160000002800000010000000200000000100040000000000C00000
0000000000000000000000000000000000C6080800CE101000CE181800D6212100D6292900E13F3F00E7525200
EF5A5A00EF636300F76B6B00F7737300FF7B7B00FFC6C600FFCEC600FFDEDE00FFFFFF00CCCCCCCCCCCCCCCCC0
0000000000000CC11111111111111CC22222CFFE22222CC33333CFFE33333CC44444CFFE44444CC55555CFFE55
555CC55555CFFE55555CC55555CFFE55555CC66666CFFE66666CC77777777777777CC88888CFFC88888CC99999
CFFC99999CCAAAAAAAAAAAAAACCBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCC00000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000
)
IconData_Set(hIcon := IconData_Create(IconDataHex))
IconData_Close(hIcon)
*/