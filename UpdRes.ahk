; ----------------------------------------------------------------------------------------------------------------------
; Name .........: UpdRes library
; Description ..: This library allows to load a resource from a PE file and update it. It's something written in a 
; ..............: couple of minutes, so don't expect it to work in all situations.
; AHK Version ..: AHK_L 1.1.13.01 x32/64 Unicode
; Author .......: Cyruz  (http://ciroprincipe.info)
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: May  24, 2014 - v0.1 - First version.
; ..............: Jan. 11, 2015 - v0.2 - Added the UpdateArrayOfResources and UpdateDirOfResources functions.
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: UpdRes_LockResource
; Description ..: Load the specified resource and retrieve a pointer to its binary data.
; Parameters ...: sResName - The name of the resource.
; ..............: nResType - The resource type.
; ..............: szData   - Byref parameter containing the size of the resource data.
; Return .......: A pointer to the first byte of the resource, 0 on error.
; Info .........: Resource Types - http://msdn.microsoft.com/en-us/library/windows/desktop/ms648009%28v=vs.85%29.aspx
; ----------------------------------------------------------------------------------------------------------------------
UpdRes_LockResource(sResName, nResType, ByRef szData) {
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
; Function .....: UpdRes_UpdateResource
; Description ..: Update the specified resource in the specified PE file.
; Parameters ...: sBinFile - PE file whose resource is to be updated.
; ..............: bDelOld  - Delete all old resources if 1 or leave them intact if 0.
; ..............: sResName - The name of the resource.
; ..............: nResType - The resource type.
; ..............: nLangId  - Language identifier of the resource to be updated.
; ..............: pData    - Pointer to resource data. Must not point to ANSI data.
; ..............: szData   - Size of the resource data.
; Return .......: 1 on success, 0 on error.
; Info .........: Lang. Identifiers - http://msdn.microsoft.com/en-us/library/windows/desktop/dd318691%28v=vs.85%29.aspx
; ----------------------------------------------------------------------------------------------------------------------
UpdRes_UpdateResource(sBinFile, bDelOld, sResName, nResType, nLangId, pData, szData) {
    If ( !(hMod := DllCall( "BeginUpdateResource", Str,sBinFile, Int,bDelOld )) )
        Return 0
    If ( !DllCall( "UpdateResource", Ptr,hMod, Ptr,nResType, Str,sResName, UInt,nLangId, Ptr,pData, UInt,szData ) )
        Return 0
    If ( !DllCall( "EndUpdateResource", Ptr,hMod, Int,0 ) )
        Return 0
    Return 1
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: UpdRes_UpdateArrayOfResources
; Description ..: Update the specified array of resources in the specified PE file.
; Parameters ...: sBinFile - PE file whose resources are to be updated.
; ..............: bDelOld  - Delete all old resources if 1 or leave them intact if 0.
; ..............: objRes   - Array of objects describing the resources to update. Must be structured as follows:
; ..............:            objRes[n].ResName  - The name of the resource.
; ..............:            objRes[n].ResType  - The resource type.
; ..............:            objRes[n].LangId   - Language identifier of the resource to be updated.
; ..............:            objRes[n].DataAddr - Pointer to resource data. Must not point to ANSI data.
; ..............:            objRes[n].DataSize - Size of the resource data.
; Return .......: Number of resources updated on success, 0 on error.
; ----------------------------------------------------------------------------------------------------------------------
UpdRes_UpdateArrayOfResources(sBinFile, bDelOld, ByRef objRes) {
    If ( !IsObject(objRes) )
        Return 0
    If ( !(hMod := DllCall( "BeginUpdateResource", Str,sBinFile, Int,bDelOld )) )
        Return 0
    Loop % objRes.MaxIndex()
    {
        If ( !DllCall( "UpdateResource", Ptr,hMod, Ptr,objRes[A_Index].ResType, Str,objRes[A_Index].ResName
                                       , UInt,objRes[A_Index].LangId, Ptr,objRes[A_Index].DataAddr
                                       , UInt,objRes[A_Index].DataSize ) )
            Continue
        nUpdated := A_Index
    }
    If ( !DllCall( "EndUpdateResource", Ptr,hMod, Int,0 ) )
        Return 0
    Return nUpdated
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: UpdRes_UpdateDirOfResources
; Description ..: Add the resources in the desired directory in the specified PE file. Only the file in the root
; ..............: directory will be added, any subdirectory will be ignored. All the resources will be added with the 
; ..............: same resource type and language identifier.
; Parameters ...: sDir     - Directory containing the resources to add to the PE file.
; ..............: sFile    - PE file whose resources are to be updated.
; ..............: bDelOld  - Delete all old resources if 1 or leave them intact if 0.
; ..............: nResType - The resource type.
; ..............: nLangId  - Language identifier of the resources to be updated.
; Return .......: Number of resources updated on success, 0 on error.
; ----------------------------------------------------------------------------------------------------------------------
UpdRes_UpdateDirOfResources(sDir, sFile, bDelOld, nResType, nLangId) {
    Static PAGE_READONLY := 2, FILE_MAP_READ := 4
    objRes := Object()
    try {
        Loop, %sDir%\*.*
        {
            objFile := FileOpen(A_LoopFileLongPath, "r")
            If ( !hMap := DllCall( "CreateFileMapping", Ptr,objFile.__Handle, Ptr,0, UInt,PAGE_READONLY
                                                      , UInt,0, UInt,0, Ptr,0 ) ) {
                objFile.Close()
                Continue
            }
            If ( !pMap := DllCall( "MapViewOfFile", Ptr,hMap, UInt,FILE_MAP_READ, UInt,0, UInt,0, UInt,0 ) ) {
                DllCall( "CloseHandle", Ptr,hMap ), objFile.Close()
                Continue
            }
            objRes.Insert({ "ResName"  : A_LoopFileName
                          , "ResType"  : nResType
                          , "LangId"   : nLangId
                          , "DataAddr" : pMap
                          , "DataSize" : objFile.Length
                          , "__oFile"  : objFile
                          , "__hMap"   : hMap
                          , "__pMap"   : pMap })
        }
        nUpdated := UpdRes_UpdateArrayOfResources(sFile, bDelOld, objRes)
    } finally {
        Loop % objRes.MaxIndex()
            DllCall( "UnmapViewOfFile", Ptr,objRes[A_Index].__pMap )
          , DllCall( "CloseHandle", Ptr,objRes[A_Index].__hMap )
          , objRes[A_Index].__oFile.Close()
        ObjRelease(objRes)
    }
    Return nUpdated
}