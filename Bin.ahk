; ----------------------------------------------------------------------------------------------------------------------
; Name .........: Bin library
; Description ..: This library is a collection of functions that deal with binary data.
; AHK Version ..: AHK_L 1.1.13.01 x32/64 ANSI/Unicode
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Jan. 21, 2015 - v0.1 - First version.
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: Bin_ToHex
; Description ..: Convert a binary buffer to a RAW hexadecimal string.
; Parameters ...: sHex  - ByRef variable that will receive the buffer as hexadecimal string.
; ..............: cBuf  - Binary data buffer.
; ..............: szBuf - Size of the buffer.
; Return .......: String length.
; ----------------------------------------------------------------------------------------------------------------------
Bin_ToHex(ByRef sHex, ByRef cBuf, szBuf:=0)
{
    (!szBuf) ? szBuf := VarSetCapacity(cBuf)
    VarSetCapacity(sHex, szBuf*4+32, 0) ; Try to avoid dynamic reallocation, 1 byte  -> max 4 chars (0x12).
    adr := &cBuf
    f := A_FormatInteger
    SetFormat, Integer, Hex
    Loop %szBuf%
        sHex .= *adr++
    SetFormat, Integer, %f%
    sHex := RegExReplace(sHex, "S)x(?=.0x|.$)|0x(?=..0x|..$)")
    Return StrLen(sHex)
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: Bin_CryptToString
; Description ..: Convert a binary buffer to a string, using the CryptBinaryToString system function. Default to hex.
; Parameters ...: sStr   - ByRef variable that will receive the buffer as a string.
; ..............: cBuf   - Binary data buffer.
; ..............: szBuf  - Size of the buffer.
; ..............: nFlags - Flags for the CryptBinaryToString function: http://goo.gl/huxbgT.
; Return .......: String length.
; Remarks ......: The default flag value of 0x4 return a string with a ending CRLF. So final length is 2 bytes bigger.
; ----------------------------------------------------------------------------------------------------------------------
Bin_CryptToString(ByRef sStr, ByRef cBuf, szBuf:=0, nFlags:=0x4)
{
    (!szBuf) ? szBuf := VarSetCapacity(cBuf)
    DllCall( "Crypt32.dll\CryptBinaryToString", Ptr,&cBuf, UInt,szBuf, UInt,nFlags, Ptr,0, UIntP,nLen )
    VarSetCapacity(cHex, nLen*(A_IsUnicode ? 2 : 1), 0)
    DllCall( "Crypt32.dll\CryptBinaryToString", Ptr,&cBuf, UInt,szBuf, UInt,nFlags, Ptr,&cHex, UIntP,nLen )
    sStr := StrGet(&cHex, nLen, (A_IsUnicode ? "UTF-16" : "CP0")), cHex := ""
    Return nLen
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: Bin_FromHex
; Description ..: Convert a RAW hexadecimal string to binary data.
; Parameters ...: cBuf - Variable that will receive the binary data.
; ..............: sHex - Hexadecimal string to be converted.
; Return .......: Buffer size.
; ----------------------------------------------------------------------------------------------------------------------
Bin_FromHex(ByRef cBuf, ByRef sHex)
{
    VarSetCapacity(cBuf, szBuf:=StrLen(sHex)//2, 0)
    Loop %szBuf%
        NumPut("0x" . SubStr(sHex, 2*A_Index-1, 2), cBuf, A_Index-1, "UChar")
    Return szBuf
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: Bin_CryptFromString
; Description ..: Convert a string to binary data. Default from hex.
; Parameters ...: cBuf   - Variable that will receive the binary data.
; ..............: sStr   - String to be converted.
; ..............: nFlags - Flags for the CryptStrinToBinary function: http://goo.gl/FsgBwI.
; Return .......: Buffer size.
; ----------------------------------------------------------------------------------------------------------------------
Bin_CryptFromString(ByRef cBuf, ByRef sStr, nFlags:=0x4)
{
    DllCall( "Crypt32.dll\CryptStringToBinary", Ptr,&sStr, UInt,StrLen(sStr), UInt,nFlags
                                              , Ptr,0, UIntP,szBuf, Ptr,0, Ptr,0 )
    VarSetCapacity(cBuf, szBuf)
    DllCall( "Crypt32.dll\CryptStringToBinary", Ptr,&sStr, UInt,StrLen(sStr), UInt,nFlags
                                              , Ptr,&cBuf, UIntP,szBuf, Ptr,0, Ptr,0 )
    Return szBuf
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: Bin_GetBitmap
; Description ..: Run the current AutoHotkey script as administrator.
; Parameters ...: cBuf  - Binary data buffer containing the bitmap.
; ..............: szBuf - Size of the buffer.
; Return .......: Handle to a bitmap.
; Code from ....: SKAN - http://goo.gl/iknYZB
; ----------------------------------------------------------------------------------------------------------------------
Bin_GetBitmap(cBuf, szBuf:=0)
{
    (!szBuf) ? szBuf := VarSetCapacity(cBuf)
    hGlob := DllCall( "GlobalAlloc", UInt,2, UInt,szBuf, Ptr ) ; 2 = GMEM_MOVEABLE
    pGlob := DllCall( "GlobalLock", Ptr,hGlob, Ptr )
    DllCall( "RtlMoveMemory", Ptr,pGlob, Ptr,&cBuf, UInt,szBuf )
    DllCall( "GlobalUnlock", Ptr,hGlob )
    DllCall( "ole32.dll\CreateStreamOnHGlobal", Ptr,hGlob, Int,1, PtrP,pStream )

    hGdip := DllCall( "LoadLibrary", Str,"Gdiplus.dll" )
    VarSetCapacity(si, 16, 0), NumPut(1, si, "UChar")
    DllCall( "Gdiplus.dll\GdiplusStartup", PtrP,gdipToken, Ptr,&si, Ptr,0 )
    DllCall( "Gdiplus.dll\GdipCreateBitmapFromStream",  Ptr,pStream, PtrP,pBitmap )
    DllCall( "Gdiplus.dll\GdipCreateHBITMAPFromBitmap", Ptr,pBitmap, PtrP,hBitmap, UInt,0 )

    DllCall( "Gdiplus.dll\GdipDisposeImage", Ptr,pBitmap )
    DllCall( "Gdiplus.dll\GdiplusShutdown", Ptr,gdipToken )
    DllCall( "FreeLibrary", Ptr,hGdip )
    ObjRelease(pStream)
    Return hBitmap
}

