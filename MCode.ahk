; ----------------------------------------------------------------------------------------------------------------------
; Function .....: MCode
; Description ..: Allocate memory and write Machine Code there.
; Parameters ...: cBuf - Binary buffer that will receive the machine code.
; ..............: sHex - Hexadecimal representation of the machine code as a string.
; Author .......: Laszlo - http://www.autohotkey.com/board/topic/19483-machine-code-functions-bit-wizardry/
; ----------------------------------------------------------------------------------------------------------------------
MCode(ByRef cBuf, sHex) {
    VarSetCapacity(cBuf, StrLen(sHex)//2)
    Loop % StrLen(sHex)//2
        NumPut("0x" . SubStr(sHex, 2*A_Index-1, 2), cBuf, A_Index-1, "Char")
}