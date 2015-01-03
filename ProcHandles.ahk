; ----------------------------------------------------------------------------------------------------------------------
; Function .....: ProcHandles
; Description ..: Return a collection of all the system handles.
; Parameters ...: sPidList - Comma separated list of the PIDs for which we want to retrieve the handles.
; Return .......: An associative array, with PIDs as indexes, where each element is an array of objects describing the 
; ..............: handles. Each object is a direct implementation of the _SYSTEM_HANDLE_TABLE_ENTRY_INFO struct.
; ..............: The associative array is structured as the following:
; ..............: Array[PID] -> Array[n] -> Object.ObjectTypeNumber
; ..............:                                 .Flags
; ..............:                                 .Handle
; ..............:                                 .Object
; ..............:                                 .GrantedAccess
; Remarks ......: The structures used are not well documented, so this is what I discovered:
; ..............:
; ..............: The following are the structures used by NtQuerySystemInformation to return the handles:
; ..............: -----------------------------------------------------------
; ..............: typedef struct _SYSTEM_HANDLE_TABLE_ENTRY_INFO
; ..............: {
; ..............:     ULONG ProcessId;
; ..............:	  BYTE ObjectTypeNumber;
; ..............:     BYTE Flags;
; ..............:     USHORT Handle;
; ..............:     PVOID Object;
; ..............:     ACCESS_MASK GrantedAccess;
; ..............:  } SYSTEM_HANDLE, *PSYSTEM_HANDLE;
; ..............:
; ..............:  OFFSET  |  SIZE
; ..............:  [0]     |  [4]      ULONG ProcessId
; ..............:  [4]     |  [1]      BYTE ObjectTypeNumber
; ..............:  [5]     |  [1]      BYTE Flags
; ..............:  [6]     |  [2]      USHORT Handle
; ..............:  [8]     |  [4/8]    PVOID Object
; ..............:  [12/16] |  [4]      ACCESS_MASK GrantedAccess
; ..............:  
; ..............:  32 bit size = 4 + 1 + 1 + 2 + 4 + 4              = 16 bytes
; ..............:  64 bit size = 4 + 1 + 1 + 2 + 8 + 4 + 4(padding) = 24 bytes
; ..............: ------------------------------------------------------------
; ..............:  typedef struct _SYSTEM_HANDLE_INFORMATION
; ..............:  {
; ..............:      ULONG HandleCount;
; ..............:      SYSTEM_HANDLE Handles[1];
; ..............:  } SYSTEM_HANDLE_INFORMATION, *PSYSTEM_HANDLE_INFORMATION;
; ..............:
; ..............:  OFFSET  |  SIZE
; ..............:  [0]     |  [4]      ULONG HandleCount
; ..............:  [4]     |  [16/24]  SYSTEM_HANDLE Handles[1]
; ..............:
; ..............:  32 bit size = 4 + 16*n              = 20 bytes if n = 1
; ..............:  64 bit size = 4 + 24*n + 4(padding) = 32 bytes if n = 1
; ..............: ------------------------------------------------------------
; AHK Version ..: AHK_L x32/64 Unicode
; Author .......: Cyruz - http://ciroprincipe.info
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Feb. 10, 2013 - v0.1 - First version.
; ----------------------------------------------------------------------------------------------------------------------
ProcHandles(sPidList:="") {
	; SystemHandleInformation = 16
	; We need the first call to get the required size as nOutLen.
	szBuf := VarSetCapacity( cBuf, 1024, 0 )
	DllCall( "Ntdll.dll\NtQuerySystemInformation", UInt,16, Ptr,&cBuf, UInt,szBuf, UIntP,nOutLen )
	; We adjust the buffer size and call the function again.
	szBuf := VarSetCapacity( cBuf, nOutLen, 0 )
	DllCall( "Ntdll.dll\NtQuerySystemInformation", UInt,16, Ptr,&cBuf, UInt,szBuf, UIntP,nOutLen )

	arrPids := [], nIdx := 4 ; Start from 4 because of HandleCount.
	Loop % NumGet(&cBuf, 0, "UInt") ; HandleCount.
	{
		nPid := NumGet(&cBuf, nIdx+0, "UInt")
		If ( sPidList != "" && !InStr(sPidList, nPid) )
			Continue ; Go on with next PID if this one is not in the list.
		If ( !arrPids.HasKey(nPid) )
			arrPids[nPid] := []
		arrPids[nPid].Insert({ "ObjectTypeNumber": NumGet( &cBuf, nIdx+4,           "UChar"  )
							 , "Flags":            NumGet( &cBuf, nIdx+5,           "UChar"  )
							 , "Handle":           NumGet( &cBuf, nIdx+6,           "UShort" )
		                     , "Object":           NumGet( &cBuf, nIdx+8,           "Ptr"    )
                             , "GrantedAccess":    NumGet( &cBuf, nIdx+8+A_PtrSize, "UInt"   ) })
		nIdx += (A_PtrSize == 4) ? 16 : 24
	}

	VarSetCapacity(cBuf, 0) ; Free buffer.
	Return arrPids
}