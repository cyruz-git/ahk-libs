; ----------------------------------------------------------------------------------------------------------------------
; Name .........: UpdRes library
; Description ..: This library allows to load a resource from a PE file and update it. It's something written in a 
; ..............: couple of minutes, so don't expect it to work in all situations.
; AHK Version ..: AHK_L 1.1.13.01 x32/64 Unicode
; Author .......: Cyruz  (http://ciroprincipe.info)
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: May  24, 2014 - v0.1 - First version
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: LockResource
; Description ..: Load the specified resource and retrieve a pointer to its binary data.
; Parameters ...: sResName - The name of the resource.
; ..............: nResType - The resource type.
; ..............: szData   - Byref parameter containing the size of the resource data.
; Return .......: A pointer to the first byte of the resource, 0 on error.
; Info .........: Resource Types - http://msdn.microsoft.com/en-us/library/windows/desktop/ms648009%28v=vs.85%29.aspx
; ----------------------------------------------------------------------------------------------------------------------
LockResource(sResName, nResType, ByRef szData) {
    If ( !(hLib   := DllCall( "GetModuleHandle", Ptr,0 )) )
        Return 0
    If ( !(hRes   := DllCall( "FindResource", Ptr,hLib, Str,sResName, Ptr,nResType )) )
        Return 0
    If ( !(szData := DllCall( "SizeofResource", Ptr,hLib, Ptr,hRes )) )
        Return 0
    If ( !(hData  := DllCall( "LoadResource", Ptr,hLib, Ptr,hRes )) )
        Return 0
    If ( !(pData  := DllCall( "LockResource", Ptr,hData )) )
        Return 0
    Return pData
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: UpdateResource
; Description ..: Update the specified resource in the specified PE file.
; Parameters ...: sExeFile   - PE file whose resource is to be updated.
; ..............: bDeleteOld - Delete all old resources if 1 or leave them intact if 0.
; ..............: sResName   - The name of the resource.
; ..............: nResType   - The resource type.
; ..............: nLang      - Language identifier of the resource to be updated.
; ..............: pData      - Resource data. Must not point to ANSI data.
; ..............: szData     - Size of the resource data.
; Return .......: 1 on success, 0 on error.
; Info .........: Lang. Identifiers - http://msdn.microsoft.com/en-us/library/windows/desktop/dd318691%28v=vs.85%29.aspx
; ----------------------------------------------------------------------------------------------------------------------
UpdateResource(sExeFile, bDeleteOld, sResName, nResType, nLang, pData, szData) {
    If ( !(hMod := DllCall( "BeginUpdateResource", Str,sExeFile, Int,bDeleteOld )) )
        Return 0
    If ( !DllCall( "UpdateResource", Ptr,hMod, Ptr,nResType, Str,sResName, UInt,nLang, Ptr,pData, UInt,szData ) )
        Return 0
    If ( !DllCall( "EndUpdateResource", Ptr,hMod, Int,0 ) )
        Return 0
    Return 1
}
