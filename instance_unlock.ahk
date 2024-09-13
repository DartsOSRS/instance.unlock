; Instructions: 
; 1. Launch RuneScape 3 clients until you hit the limit of 16
; 2. Run this script, or click the Refresh button if it was already running
; 3. Click the 🔒Unlock button
; 4. Repeat steps 1-3 for as many clients as you'd like

; Credits to T-vK for creating 'WhoLockedMe' which this script is forked from: https://github.com/T-vK/WhoLockedMe/

#NoEnv
SetBatchLines, -1
RunAsAdmin()
LoadLibraries()
EnablePrivilege()
If (A_Is64bitOS && (A_PtrSize = 4))
    DllCall("Wow64DisableWow64FsRedirection", "UInt*", OldValue)
File := FileOpen(A_ScriptFullPath, "r") ; cause this script to appear in the list
; ==================================================================================================================================
    Gui, Add, Edit, ReadOnly w452 r1 gGui_FileHandles_CtrlEvt vGui_FileHandles_ApplyFilter, C:\ProgramData\Jagex\launcher\instance.lock
    Gui, Add, Button, w452 gGui_FileHandles_CtrlEvt vGui_FileHandles_ReloadData, Refresh
    Gui, Add, ListView, w452 r15 gGui_FileHandles_CtrlEvt vGui_FileHandles_LV, Path|Process|PID|Handle
    LV_ModifyCol(1,234), LV_ModifyCol(2,100), LV_ModifyCol(3,50), LV_ModifyCol(4,50)
    Gui, Add, Button, +Disabled w452 h50 gGui_FileHandles_CtrlEvt vGui_FileHandles_CloseHandles, 🔓Unlocked
    Gui, Add, Progress, w452 vGui_FileHandles_ProgressBar
    Gui, +ToolWindow
    Gui, Show,, instance.unlock

Gui_FileHandles_CtrlEvt("Gui_FileHandles_ReloadData")

; ==================================================================================================================================
Gui_FileHandles_CtrlEvt(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
    Static DataArray := []
    If (A_DefaultListView != "Gui_FileHandles_LV")
        Gui, ListView, Gui_FileHandles_LV
    GuiControlGet, ControlName, Name, %CtrlHwnd%
    If (ControlName = "Gui_FileHandles_ApplyFilter") {
        GuiControlGet, Gui_FileHandles_ApplyFilter
        LV_Delete()
        GuiControl, -Redraw, Gui_FileHandles_LV
        Loop % DataArray.Length() {
            Data := DataArray[A_Index]
            FilePath := Data.FilePath ? Data.FilePath : Data.DevicePath
            If (InStr(FilePath, Gui_FileHandles_ApplyFilter))
                LV_Add(, FilePath, Data.ProcName, Data.PID, Data.Handle)
        }
        GuiControl, +Redraw, Gui_FileHandles_LV
        if (LV_GetCount() != 0) {
            GuiControl, Enable, Gui_FileHandles_CloseHandles
            GuiControl,, Gui_FileHandles_CloseHandles, 🔒Unlock
        } else {
            GuiControl, Disable, Gui_FileHandles_CloseHandles
            GuiControl,, Gui_FileHandles_CloseHandles, 🔓Unlocked
        }
    } Else If (ControlName = "Gui_FileHandles_ReloadData") {
        LV_Delete()
        Callback := Func("FileHandleCallback")
        DataArray := GetAllFileHandleInfo(Callback)
        GuiControl, , Gui_FileHandles_ProgressBar, 0
        DataArrayCount := DataArray.Length()
        Loop % DataArrayCount {
            GuiControl, , Gui_FileHandles_ProgressBar, % A_Index/DataArrayCount*100
            Data := DataArray[A_Index]
        }
        Gui_FileHandles_CtrlEvt("Gui_FileHandles_ApplyFilter")
    } Else If (ControlName = "Gui_FileHandles_CloseHandles") {
        Loop % LV_GetCount(){
            LV_GetText(Handle, A_Index, 4)
            LV_GetText(PID, A_Index, 3)
            
            ProcHandle := OpenProcess(PID, 0x40)
            HandleClosed := DuplicateObject(ProcHandle, 0, Handle, 0x1) ; Close handle
            
            If HandleClosed {
                LV_GetText(Path, A_Index, 1)
                LV_GetText(Name, A_Index, 2)
                MsgBox, Error: Unable to close %Name%'s (PID: %PID%) handle on "%Path%"!
            } Else {
                i := 1
                Loop % DataArray.Length() {
                    If (DataArray[i].Handle = Handle)
                        DataArray.RemoveAt(i)
                    Else
                        i++
                }
            }
        }
        Gui_FileHandles_CtrlEvt("Gui_FileHandles_ApplyFilter")
    }
}
; ==================================================================================================================================
FileHandleCallback(PercentDone) {
    GuiControl, , Gui_FileHandles_ProgressBar, %PercentDone%
}
; ==================================================================================================================================
LoadLibraries() {
    DllCall("LoadLibrary", "Str", "Advapi32.dll", "UPtr")
    DllCall("LoadLibrary", "Str", "Ntdll.dll", "UPtr")
    DllCall("LoadLibrary", "Str", "Shell32.dll", "UPtr")
    DllCall("LoadLibrary", "Str", "psapi.dll", "UPtr")
}
; ==================================================================================================================================
GuiClose(Hwnd){
    ExitApp
}

; ==================================================================================================================================
; General functions that can simply be used in other scripts =======================================================================
; ==================================================================================================================================
GetProcessFilePath(hProcess) {
    nSize := VarSetCapacity(lpFilename, 260 * (A_IsUnicode ? 2 : 1), 0)
    If !(DllCall("GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", lpFilename, "UInt", nSize))
        If !(DllCall("psapi.dll\GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", lpFilename, "UInt", nSize))
            Return (ErrorLevel := 2) & 0
    Return lpFilename
}
; ==================================================================================================================================
GetProcessFilePathByPID(PID) {
    If !(hProcess := DllCall("OpenProcess", "UInt", 0x10|0x400, "Int", 0, "UInt", PID, "UPtr"))
        Return (ErrorLevel := 1) & 0
    lpFilename := GetProcessFilePath(hProcess)
    DllCall("CloseHandle", "Ptr", hProcess)
    Return lpFilename
}

;==================================================================================================================================
OpenProcess(PID := 0, Privileges := -1) {
    Return DllCall("OpenProcess", "Uint", (Privileges = -1) ? 0x1F0FFF : Privileges, "Uint", False, "Uint", PID ? PID : DllCall("GetCurrentProcessId"))
} 
; ==================================================================================================================================
GetAllFileHandleInfo(Callback:="") {
    Static hCurrentProc := DllCall("GetCurrentProcess", "UPtr")
    DataArray := []
    If !(SHI := QuerySystemHandleInformation()) {
        MsgBox, 16, Error!, % "Couldn't get SYSTEM_HANDLE_INFORMATION`nLast Error: " . Format("0x{:08X}", ErrorLevel)
        Return False
    }
    HandleCount := SHI.Count
    devicePathsObj := GetDevicePaths()
    Loop %HandleCount% {
        ; PROCESS_DUP_HANDLE = 0x40, PROCESS_QUERY_INFORMATION = 0x400
        If !(hProc := DllCall("OpenProcess", "UInt", 0x0400|0x40|0x10, "UInt", 0, "UInt", SHI[A_Index, "PID"], "UPtr"))
            Continue
        ; DUPLICATE_SAME_ATTRIBUTES = 0x04 (4)
        If !(hObject := DuplicateObject(hProc, hCurrentProc, SHI[A_Index, "Handle"], 4)) {
            DllCall("CloseHandle", "Ptr", hProc)
            Continue
        }
        If (OBI := QueryObjectBasicInformation(hObject))
        && (OTI := QueryObjectTypeInformation(hObject))
        && (OTI.Type = "File")
        && (DllCall("GetFileType", "Ptr", hObject, "UInt") = 1)
        && (ONI := QueryObjectNameInformation(hObject)) {
            VarSetCapacity(ProcFullPath, 520, 0)
            DllCall("QueryFullProcessImageName", "Ptr", hProc, "UInt", 0, "Str", ProcFullPath, "UIntP", sz := 260) ; NOT COMPATIBLE WITH WINDOWS XP
            
            Data := {}
            Data.ProcFullPath := ProcFullPath ? ProcFullPath : GetProcessFilePath(hProc) ; For XP compatibility
            Data.PID := SHI[A_Index].PID
            Data.Handle := SHI[A_Index].Handle
            Data.GrantedAccess := SHI[A_Index].Access
            Data.Flags := SHI[A_Index].Flags
            Data.Attributes := OBI.Attr
            Data.HandleCount := (OBI.Handles - 1)
            Data.DevicePath := ONI.Name
            
            FilePath := GetPathNameByHandle(hObject) ; NOT COMPATIBLE WITH WINDOWS XP
            
            If (!FilePath) {  ; For XP compatibility
                RegexMatch(Data.DevicePath, "OS)(^\\.+?\\.+?)(\\|$)", matches)
                FilePath := StrReplace(Data.DevicePath,matches[1],devicePathsObj[matches[1]],o,1)
            }
            Data.FilePath := FilePath
            Data.Drive := SubStr(FilePath, 1, 1)
            FileExists := FileExist(FilePath)
            Data.Exists := FileExists ? True : False
            Data.Isfolder := InStr(FileExists, "D") ? True : False
            SplitPath, ProcFullPath, ProcName
            Data.ProcName := ProcName
        
            ProgressInPercent := A_Index/HandleCount*100
            If Callback
                Callback.Call(ProgressInPercent)
            
            DataArray.Push(Data)
        }
        DllCall("CloseHandle", "Ptr", hObject)
        DllCall("CloseHandle", "Ptr", hProc)
    }
    If Callback
        Callback.Call(100)
    Return DataArray
}
; ==================================================================================================================================
GetPathNameByHandle(hFile) {
    VarSetCapacity(FilePath, 4096, 0)
    DllCall("GetFinalPathNameByHandle", "Ptr", hFile, "Str", FilePath, "UInt", 2048, "UInt", 0, "UInt")
    Return SubStr(FilePath, 1, 4) = "\\?\" ? SubStr(FilePath, 5) : FilePath
}
; ==================================================================================================================================
GetDevicePaths() {
    DriveGet, driveLetters, List
    driveLetters := StrSplit(driveLetters)
    devicePaths := {}
    Loop % driveLetters.MaxIndex()
        devicePaths[QueryDosDevice(driveLetters[A_Index] ":")] := driveLetters[A_Index] ":"
    Return devicePaths
}
; ==================================================================================================================================
QueryDosDevice(DeviceName := "C:") {
    size := VarSetCapacity(TargetPath, 1023) + 1
    DllCall("QueryDosDevice", "str", DeviceName, "str", TargetPath, "uint", size)
    return TargetPath
}
; ==================================================================================================================================
DuplicateObject(hProc, hCurrentProc, Handle, Options) {
    ; PROCESS_DUP_HANDLE = 0x40, PROCESS_QUERY_INFORMATION = 0x400, DUPLICATE_SAME_ATTRIBUTES = 0x04 (4)
    Status := DllCall("Ntdll.dll\ZwDuplicateObject", "Ptr", hProc
                                                   , "Ptr", Handle
                                                   , "Ptr", hCurrentProc
                                                   , "PtrP", hObject
                                                   , "UInt", 0
                                                   , "UInt", 0
                                                   , "UInt", Options
                                                   , "UInt")
    Return (Status) ? !(ErrorLevel := Status) : hObject
}
; ==================================================================================================================================
QueryObjectBasicInformation(hObject) {
    ; ObjectBasicInformation = 0, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
    Static Size := 56 ; size of OBJECT_BASIC_INFORMATION
    VarSetCapacity(OBI, Size, 0)
    Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 0, "Ptr", &OBI, "UInt", Size, "UIntP", L, "UInt")
    If (Status = 0xC0000004) {
        VarSetCapacity(OBI, L)
        Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 0, "Ptr", &OBI, "UInt", L, "Ptr", 0, "UInt")
    }
    Return (Status) ? !(ErrorLevel := Status)
                    : {Attr: NumGet(OBI, 0, "UInt")
                       , Access: NumGet(OBI, 4, "UInt")
                       , Handles: NumGet(OBI, 8, "UInt")
                       , Pointers: NumGet(OBI, 12, "UInt")}
}
; ==================================================================================================================================
QueryObjectTypeInformation(hObject, Size := 4096) {
    ; ObjectTypeInformation = 2, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
    VarSetCapacity(OTI, Size, 0)
    Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 2, "Ptr", &OTI, "UInt", Size, "UIntP", L, "UInt")
    If (Status = 0xC0000004) {
        VarSetCapacity(OTI, L)
        Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 2, "Ptr", &OTI, "UInt", L, "Ptr", 0, "UInt")
    }
    Return (Status) ? !(ErrorLevel := Status)
                    : {Type: StrGet(NumGet(OTI, A_PtrSize, "UPtr"), NumGet(OTI, 0, "UShort") // 2, "UTF-16")}
}
; ==================================================================================================================================
QueryObjectNameInformation(hobject, Size := 4096) {
    ; ObjectNameInformation = 1, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
    VarSetCapacity(ONI, Size, 0)
    Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 1, "Ptr", &ONI, "UInt", Size, "UIntP", L, "UInt")
    If (Status = 0xc0000004) {
        VarSetCapacity(ONI, L)
        Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 1, "Ptr", &ONI, "UInt", L, "Ptr", 0, "UInt")
    }
    Return (Status) ? !(ErrorLevel := Status)
                    : {Name: StrGet(NumGet(ONI, A_PtrSize, "UPtr"), NumGet(ONI, 0, "UShort") // 2, "UTF-16")}
}
; ==================================================================================================================================
QuerySystemHandleInformation() {
    ; SystemHandleInformation = 16, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
    Static SizeSH := 8 + (A_PtrSize * 2)
    Static Size := A_PtrSize * 4096
    VarSetCapacity(SHI, Size)
    Status := DllCall("Ntdll.dll\NtQuerySystemInformation", "UInt", 16, "Ptr", &SHI, "UInt", Size, "UIntP", L, "UInt")
    While (Status = 0xc0000004) {
        VarSetCapacity(SHI, L)
        Status := DllCall("Ntdll.dll\NtQuerySystemInformation", "UInt", 16, "Ptr", &SHI, "UInt", L, "UIntP", L, "UInt")
    }
    If (Status)
        Return !(ErrorLevel := Status)
    HandleCount := NumGet(SHI, "UInt")
    ObjSHI := {Count: HandleCount}
    Addr := &SHI + A_PtrSize
    Loop, %HandleCount% {
        ObjSHI.Push({PID: NumGet(Addr + 0, "UInt")
                   , Type: NumGet(Addr + 4, "UChar")
                   , Flags: NumGet(Addr + 5, "UChar")
                   , Handle: NumGet(Addr + 6, "UShort")
                   , Addr: NumGet(Addr + 8, "UPtr")
                   , Access: NumGet(Addr + 8, A_PtrSize, "UInt")})
        Addr += SizeSH
    }
    Return ObjSHI
}
; ==================================================================================================================================
EnablePrivilege(Name := "SeDebugPrivilege") {
    hProc := DllCall("GetCurrentProcess", "UPtr")
    If DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", Name, "Int64P", LUID := 0, "UInt")
    && DllCall("Advapi32.dll\OpenProcessToken", "Ptr", hProc, "UInt", 32, "PtrP", hToken := 0, "UInt") { ; TOKEN_ADJUST_PRIVILEGES = 32
        VarSetCapacity(TP, 16, 0) ; TOKEN_PRIVILEGES
        , NumPut(1, TP, "UInt")
        , NumPut(LUID, TP, 4, "UInt64")
        , NumPut(2, TP, 12, "UInt") ; SE_PRIVILEGE_ENABLED = 2
        , DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", hToken, "UInt", 0, "Ptr", &TP, "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt")
    }
    LastError := A_LastError
    If (hToken)
        DllCall("CloseHandle", "Ptr", hToken)
    Return !(ErrorLevel := LastError)
}
; ==================================================================================================================================
RunAsAdmin() {
    If !(A_IsAdmin) {
        Run % "*RunAs " . (A_IsCompiled ? "" : A_AhkPath . " ") . """" . A_ScriptFullPath . """"
        ExitApp
    }
}
