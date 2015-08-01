; ----------------------------------------------------------------------------------------------------------------------
; Name .........: TrayIcon library
; Description ..: Provide some useful functions to deal with Tray icons.
; AHK Version ..: AHK_L 1.1.13.01 x32/64 Unicode
; Author .......: Cyruz (http://ciroprincipe.info) - from a Sean idea and code (http://goo.gl/dh0xIX)
; Thanks .......: FanaticGuru
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Dic. 31, 2013 - v0.1   - First revision.
; ..............: Jan. 16, 2014 - v0.2   - Added NotifyIconOverflowWindow parsing and DetectHiddenWindows management.
; ..............: Jul. 28, 2015 - v0.2.1 - Added TrayIcon_SetIcon function.
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_GetInfo
; Description ..: Get a series of useful information about tray icons.
; Parameters ...: sExeName  - The exe or the PID for which we are searching the tray icon data. Leave it empty to 
; ..............:             receive data for all tray icons.
; Return .......: oTrayInfo - An array of objects containing tray icons data. Any entry is structured like this:
; ..............:             oTrayInfo[A_Index].idx     - 0 based tray icon index.
; ..............:             oTrayInfo[A_Index].idcmd   - Command identifier associated with the button.
; ..............:             oTrayInfo[A_Index].pid     - Process ID.
; ..............:             oTrayInfo[A_Index].uid     - Application defined identifier for the icon.
; ..............:             oTrayInfo[A_Index].msgid   - Application defined callback message.
; ..............:             oTrayInfo[A_Index].hicon   - Handle to the tray icon.
; ..............:             oTrayInfo[A_Index].hwnd    - Window handle.
; ..............:             oTrayInfo[A_Index].class   - Window class.
; ..............:             oTrayInfo[A_Index].process - Process executable.
; ..............:             oTrayInfo[A_Index].tooltip - Tray icon tooltip.
; ..............:             oTrayInfo[A_Index].place   - Place where to find the icon.
; Info .........: TB_BUTTONCOUNT message - http://goo.gl/DVxpsg
; ..............: TB_GETBUTTON message   - http://goo.gl/2oiOsl
; ..............: TBBUTTON structure     - http://goo.gl/EIE21Z
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_GetInfo(sExeName:="")
{
    d := A_DetectHiddenWindows
	DetectHiddenWindows, On   

    oTrayInfo := Object()
	For key, sTrayPlace in ["Shell_TrayWnd", "NotifyIconOverflowWindow"]
    {	
        idxTB := TrayIcon_GetTrayBar()
        WinGet, pidTaskbar, PID, ahk_class %sTrayPlace%

        hProc := DllCall( "OpenProcess",    UInt,0x38, Int,0, UInt,pidTaskbar                       )
        pRB   := DllCall( "VirtualAllocEx", Ptr,hProc, Ptr,0, UInt,20,        UInt,0x1000, UInt,0x4 )

        szBtn := VarSetCapacity( btn, (A_Is64bitOS) ? 32 : 24, 0 )
        szNfo := VarSetCapacity( nfo, (A_Is64bitOS) ? 32 : 24, 0 )
        szTip := VarSetCapacity( tip, 128 * 2,                 0 )

        SendMessage, 0x418, 0, 0, ToolbarWindow32%idxTB%, ahk_class %sTrayPlace% ; TB_BUTTONCOUNT
        Loop, %ErrorLevel%
        {
            SendMessage, 0x417, A_Index - 1, pRB, ToolbarWindow32%idxTB%, ahk_class %sTrayPlace% ; TB_GETBUTTON

            DllCall( "ReadProcessMemory", Ptr,hProc, Ptr,pRB, Ptr,&btn, UInt,szBtn, UInt,0 )

            iBitmap	:= NumGet( btn, 0                       )
            idCmd   := NumGet( btn, 4                       )
            Statyle := NumGet( btn, 8                       )
            dwData	:= NumGet( btn, (A_Is64bitOS) ? 16 : 12 )
            iString	:= NumGet( btn, (A_Is64bitOS) ? 24 : 16 )

            DllCall( "ReadProcessMemory", Ptr,hProc, Ptr,dwData, Ptr,&nfo, UInt,szNfo, UInt,0 )

            hWnd  := NumGet( nfo, 0                       )
            uID	  := NumGet( nfo, (A_Is64bitOS) ? 8  : 4  )
            nMsg  := NumGet( nfo, (A_Is64bitOS) ? 12 : 8  )
            hIcon := NumGet( nfo, (A_Is64bitOS) ? 24 : 20 )

            WinGet,      pid,      PID,         ahk_id %hWnd%
            WinGet,      sProcess, ProcessName, ahk_id %hWnd%
            WinGetClass, sClass,                ahk_id %hWnd%

            If ( !sExeName || (sExeName == sProcess) || (sExeName == pid) )
                DllCall( "ReadProcessMemory", Ptr,hProc, Ptr,iString, Ptr,&tip, UInt,szTip, UInt,0 )
              , oTrayInfo.Insert({ "idx": A_Index-1, "idcmd": idCmd, "pid": pid, "uid": uID, "msgid": nMsg
                                 , "hicon": hIcon, "hwnd": hWnd, "class": sClass, "process": sProcess
                                 , "tooltip": StrGet(&tip, "UTF-16"), "place": sTrayPlace })
        }
        
        DllCall( "VirtualFreeEx", Ptr,hProc, Ptr,pRB, UInt,0, UInt,0x8000 )
        DllCall( "CloseHandle",   Ptr,hProc                               )
	}
	DetectHiddenWindows, %d%
	Return ( oTrayInfo.MaxIndex() > 0 ) ? oTrayInfo : 0
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Hide
; Description ..: Hide or unhide a tray icon.
; Parameters ...: idCmd      - Command identifier associated with the button.
; ..............: sTrayPlace - Place where to find the icon ("Shell_TrayWnd" or "NotifyIconOverflowWindow").
; ..............: bHide      - True for hide, False for unhide.
; Info .........: TB_HIDEBUTTON message - http://goo.gl/oelsAa
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Hide(idCmd, sTrayPlace:="Shell_TrayWnd", bHide:=True)
{
    d := A_DetectHiddenWindows
	DetectHiddenWindows, On
	idxTB := TrayIcon_GetTrayBar()
	SendMessage, 0x404, idCmd, bHide, ToolbarWindow32%idxTB%, ahk_class %sTrayPlace% ; TB_HIDEBUTTON = 0x404
	SendMessage, 0x1A, 0, 0, , ahk_class %sTrayPlace%
    DetectHiddenWindows, %d%
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Remove
; Description ..: Remove a Tray icon. It should be more reliable than TrayIcon_Delete.
; Parameters ...: hWnd - Window handle.
; ..............: uId  - Application defined identifier for the icon.
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Remove(hWnd, uId)
{
	VarSetCapacity( NID, (A_PtrSize == 4) ? (A_IsUnicode ? 828 : 444) : 848, 0 )
	NumPut( sz, NID, 0 ), NumPut( hWnd, NID, A_PtrSize ), NumPut( uId, NID, A_PtrSize*2 )
	DllCall( "Shell32.dll\Shell_NotifyIcon", UInt,2, Ptr,&NID )
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Delete
; Description ..: Delete a tray icon.
; Parameters ...: idx        - 0 based tray icon index.
; ..............: sTrayPlace - Place where to find the icon ("Shell_TrayWnd" or "NotifyIconOverflowWindow").
; Info .........: TB_DELETEBUTTON message - http://goo.gl/L0pY4R
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Delete(idx, sTrayPlace:="Shell_TrayWnd")
{
    d := A_DetectHiddenWindows
	DetectHiddenWindows, On
	idxTB := TrayIcon_GetTrayBar()
	SendMessage, 0x416, idx, 0, ToolbarWindow32%idxTB%, ahk_class %sTrayPlace% ; TB_DELETEBUTTON = 0x416
	SendMessage, 0x1A, 0, 0, , ahk_class %sTrayPlace%
	DetectHiddenWindows, %d%
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Move
; Description ..: Move a tray icon.
; Parameters ...: idxOld     - 0 based index of the tray icon to move.
; ..............: idxNew     - 0 based index where to move the tray icon.
; ..............: sTrayPlace - Place where to find the icon ("Shell_TrayWnd" or "NotifyIconOverflowWindow").
; Info .........: TB_MOVEBUTTON message - http://goo.gl/1F6wPw
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Move(idxOld, idxNew, sTrayPlace:="Shell_TrayWnd")
{
    d := A_DetectHiddenWindows
	DetectHiddenWindows, On
	idxTB := TrayIcon_GetTrayBar()
	SendMessage, 0x452, idxOld, idxNew, ToolbarWindow32%idxTB%, ahk_class %sTrayPlace% ; TB_MOVEBUTTON = 0x452
    DetectHiddenWindows, %d%
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Set
; Description ..: Modify icon with the given index for the given window.
; Parameters ...: hWnd       - Window handle.
; ..............: uId        - Application defined identifier for the icon.
; ..............: hIcon      - Handle to the tray icon.
; ..............: hIconSmall - Handle to the small icon, for window menubar. Optional.
; ..............: hIconBig   - Handle to the big icon, for taskbar. Optional.
; Return .......: True on success, false on failure.
; Info .........: NOTIFYICONDATA structure  - https://goo.gl/1Xuw5r
; ..............: Shell_NotifyIcon function - https://goo.gl/tTSSBM
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Set(hWnd, uId, hIcon, hIconSmall:=0, hIconBig:=0)
{
    d := A_DetectHiddenWindows
    DetectHiddenWindows, On
    ; WM_SETICON = 0x80
    If ( hIconSmall ) 
        SendMessage, 0x80, 0, hIconSmall,, ahk_id %hWnd%
    If ( hIconBig )
        SendMessage, 0x80, 1, hIconBig,, ahk_id %hWnd%
    DetectHiddenWindows, %d%

    sz := VarSetCapacity( NID, (A_PtrSize == 4) ? (A_IsUnicode ? 828 : 444) : 848, 0 )
    NumPut( sz,    NID, 0                           )
    NumPut( hWnd,  NID, (A_PtrSize == 4) ? 4   : 8  )
    NumPut( uId,   NID, (A_PtrSize == 4) ? 8   : 16 )
    NumPut( 2,     NID, (A_PtrSize == 4) ? 12  : 20 )
    NumPut( hIcon, NID, (A_PtrSize == 4) ? 20  : 32 )
    
    ; NIM_MODIFY := 0x1
    Return DllCall( "Shell32.dll\Shell_NotifyIcon", UInt,0x1, Ptr,&NID )
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_GetTrayBar
; Description ..: Get the tray icon handle.
; Return .......: Tray icon handle.
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_GetTrayBar()
{
    d := A_DetectHiddenWindows
	DetectHiddenWindows, On
	WinGet, ControlList, ControlList, ahk_class Shell_TrayWnd
	RegExMatch( ControlList, "(?<=ToolbarWindow32)\d+(?!.*ToolbarWindow32)", nTB )

	Loop, %nTB%
	{
		ControlGet, hWnd, hWnd,, ToolbarWindow32%A_Index%, ahk_class Shell_TrayWnd
		hParent := DllCall( "GetParent", Ptr,hWnd )
		WinGetClass, sClass, ahk_id %hParent%
		If ( sClass != "SysPager" )
			Continue
		idxTB := A_Index
			Break
	}
	
	DetectHiddenWindows, %d%
	Return	idxTB
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_GetHotItem
; Description ..: Get the index of tray's hot item.
; Return .......: Index of tray's hot item.
; Info .........: TB_GETHOTITEM message - http://goo.gl/g70qO2
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_GetHotItem()
{
   idxTB := TrayIcon_GetTrayBar()
   SendMessage, 0x447, 0, 0, ToolbarWindow32%idxTB%, ahk_class Shell_TrayWnd ; TB_GETHOTITEM = 0x447
   Return ErrorLevel << 32 >> 32
}
