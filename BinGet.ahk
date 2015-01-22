; ----------------------------------------------------------------------------------------------------------------------
; Name .........: BinGet library
; Description ..: This library is a collection of functions that return different kind of data from binary buffers.
; AHK Version ..: AHK_L 1.1.13.01 x32/64 ANSI/Unicode
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Jan. 22, 2015 - v0.1   - First version.
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: BinGet_Bitmap
; Description ..: Create a bitmap from a binary buffer and return a handle to it.
; Parameters ...: adrBuf - Pointer to the binary data buffer containing the bitmap.
; ..............: szBuf  - Size of the buffer.
; Return .......: Handle to a bitmap.
; Code from ....: SKAN - http://goo.gl/iknYZB
; ----------------------------------------------------------------------------------------------------------------------
BinGet_Bitmap(adrBuf, szBuf)
{
    hGlob := DllCall( "GlobalAlloc", UInt,2, UInt,szBuf, Ptr ) ; 2 = GMEM_MOVEABLE
    pGlob := DllCall( "GlobalLock", Ptr,hGlob, Ptr )
    DllCall( "RtlMoveMemory", Ptr,pGlob, Ptr,adrBuf, UInt,szBuf )
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

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: BinGet_Icon
; Description ..: Create an icon from a binary buffer and return a handle to it.
; Parameters ...: adrBuf     - Pointer to the binary data buffer containing the icon.
; ..............: nIconWidth - Width of the desired icon (used to retrieve the icon inside a multi-icon file).
; Return .......: Handle to an Icon.
; Remarks ......: The function is based on the implicit structure of an icon file (.ico):
; ..............: ICONDIR structure:
; ..............: { sizeof(ICONDIR) = 6 + sizeof(ICONDIRENTRY) * n
; ..............:   Offset Type         Name           Description
; ..............:   00     WORD         idReserved     // Reserved (must be 0).
; ..............:   02     WORD         idType         // Resource type (1 for icons).
; ..............:   04     WORD         idCount        // How many images?
; ..............:   06     ICONDIRENTRY idEntries[n]   // The entries for each icon.
; ..............: }
; ..............: ICONDIRENTRY structure:
; ..............: { sizeof(ICONDIRENTRY) = 16
; ..............:   Offset Type         Name           Description
; ..............:   06     BYTE         bWidth;        // Width, in pixels, of the image.
; ..............:   07     BYTE         bHeight;       // Height, in pixels, of the image.
; ..............:   08     BYTE         bColorCount;   // Number of colors in image (0 if >=8bpp).
; ..............:   09     BYTE         bReserved;     // Reserved.
; ..............:   10     WORD         wPlanes;       // Color Planes.
; ..............:   12     WORD         BitCount;      // Bits per pixel.
; ..............:   14     DWORD        dwBytesInRes;  // How many bytes in this resource?
; ..............:   18     DWORD        dwImageOffset; // Where in the file is this image?
; ..............: }
; ----------------------------------------------------------------------------------------------------------------------
BinGet_Icon(adrBuf, nIconWidth)
{
    Loop % NumGet(adrBuf+0, 4, "UShort")
    {
        nOfft := 6 + 16*(A_Index-1)
        If ( NumGet(adrBuf+0, nOfft, "UChar") == nIconWidth )
            szData := NumGet(adrBuf+0, nOfft+8,  "UInt")
          , pData  := NumGet(adrBuf+0, nOfft+12, "UInt")
    }
    Return DllCall( "CreateIconFromResourceEx", Ptr,adrBuf+pData, UInt,szData, Int,1, UInt,0x30000
                                              , Int,nIconWidth, Int,nIconWidth, UInt,0 )
}
