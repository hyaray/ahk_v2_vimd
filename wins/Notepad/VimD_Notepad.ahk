;测试
;打开任意文件
;按 \ 会自动识别为输入状态，不会执行 vimd 命令
;如果想强制 \ 执行 vimd 命令，先按 RControl 再按 \
;执行一次命令后，超级模式会失效，再按 \ 可看到效果

;按 F2 定义为 <super>，所以任意时候按键都会执行 vimd 命令
class VimD_Notepad {

    static __new(p*) {
        if (this != VimD_Notepad)
            return
        this.win := vimd.setWin("Notepad", "ahk_exe notepad.exe")
        this.win.objDynamic := map(
            "a", (p*)=>this.dynamicAuto(),
        )
    
        this.mode1 := this.win.initMode(1, true, ObjBindMethod(this,"beforeKey"))
    
        this.win.setKeySuperVim() ;按下此键后，临时强制下一按键执行 vimd 命令，默认设置为 {RControl} 键
    
        hotkey("F1", (p*)=>PostMessage(0x111, 2, 0, , "ahk_class Notepad"))
    
        vimd.setWin("Notepad", "ahk_class Notepad") ;设置此行，则后续定义的按键只在对应窗口生效

        ;带 <super> 后的第1个按键，则在任意时间都执行 vimd 命令
        ;所以一般不用可输入的按键，否则此键就废了
        this.mode1.mapkey("<super>{F2}a",(p*)=>_Notepad.about(),"about")
        this.mode1.mapkey("<super>{F2}b",(p*)=>VimD_Notepad.ab(),"ab")
        this.mode1.mapkey("<super>{F2}w",(p*)=>_Notepad.wrap(),"自动换行")
        this.mode1.mapkey("<super>{F2}f",(p*)=>_Notepad.dialogFont(),"对话框-字体")

        ;\为可输入按键，所以当在输入状态时会自动识别并输入
        this.mode1.mapkey("\1",(p*)=>msgbox(1),"msgbox 1")
        this.mode1.mapkey("\2",(p*)=>msgbox(1),"msgbox 2")
        this.mode1.mapkey("\p",(p*)=>msgbox(_Notepad.getDocumentPath()),"msgbox 文档路径")

        ;this.win.setMode(0) ;是否默认 None 模式
    }
    
    ;NOTE 核心函数
    ;如果返回 true，则运行 vimd 命令
    ;否则，直接 send
    static beforeKey(thisKey:="") {
        return !CaretGetPos()
    }

    static aa() {
        msgbox("aa",,0x40000)
    }

    static ab() {
        msgbox("ab",,0x40000)
    }

}

class _Notepad {

    static getDocumentPath() { ;获取当前窗口编辑文档的路径
        if RegExMatch(substr(getCommandLine("A"), 4), "[a-zA-Z]:[^:]+$", &m)
            return m[0]
        getCommandLine(winTitle:="") {
            for item in ComObjGet("winmgmts:").ExecQuery(format("Select * from Win32_Process where ProcessId={1}", WinGetPID(winTitle)))
                return item.CommandLine
        }
    }

    static wrap() {
        PostMessage(0x111, 32, 0, , "ahk_class Notepad")
    }

    static about() {
        PostMessage(0x111, 65, 0, , "ahk_class Notepad")
    }

    static dialogFont() {
        PostMessage(0x111, 33, 0, , "ahk_class Notepad")
    }

    static selectByReg(reg, nOffset:=0, len:="") {
        str := ControlGetText("Edit1", "ahk_class Notepad")
        if RegExMatch(str, reg, &m) {
            start := m.pos(0)+nOffset
            if !len
                len := m.len(0)
            SendMessage(EM_SETSEL:=0xB1, start, start+len-1, "Edit1", "ahk_class Notepad ") ;要用 SendMessage
        }
    }

    ; https://www.autohotkey.com/boards/viewtopic.php?t=30050
    static getDoc(winTitle:="A") {
        if (WinGetClass(winTitle) != "Notepad")
            return
        MAX_PATH := 260
        ;PROCESS_QUERY_INFORMATION := 0x400 ;PROCESS_VM_READ := 0x10
        if !hProc := dllcall("kernel32\OpenProcess", "uint",0x410, "Int",0, "uint",WinGetPID(winTitle), "ptr")
            return
        vPVersion := FileGetVersion(WinGetProcessPath(winTitle))
        dllcall("kernel32\IsWow64Process", "ptr",hProc, "int*",&vIsWow64Process:=0)
        if (vPVersion = "5.1.2600.5512") ;Notepad (Windows XP version)
            vAddress := 0x100A900
        else if (vPVersion = "10.0.14393.0") ;Notepad (Windows 10 version)
            vAddress := vIsWow64Process ? 0xFBD220 : 0x7FF770C545C0 ;(0xFBE000 also appears to work)
        if !vAddress {
            MEMORY_BASIC_INFORMATION := buffer(A_PtrSize=8?48:28, 0)
            vAddress := 0
            loop {
                if !dllcall("kernel32\VirtualQueryEx", "ptr",hProc, "ptr",vAddress, "ptr",&MEMORY_BASIC_INFORMATION, "uptr",(A_PtrSize=8)?48:28, "uptr")
                    break
                vMbiBaseAddress := numget(MEMORY_BASIC_INFORMATION, 0, "ptr")
                vMbiRegionSize := numget(MEMORY_BASIC_INFORMATION, A_PtrSize*3, "uptr")
                vMbiState := numget(MEMORY_BASIC_INFORMATION, A_PtrSize*4, "uint")
                vMbiType := numget(MEMORY_BASIC_INFORMATION, (A_PtrSize=8)?40:24, "uint")
                vPath := ""
                vPath := buffer(MAX_PATH*2)
                dllcall("psapi\GetMappedFileName", "ptr",hProc, "ptr",vMbiBaseAddress, "str",vPath, "uint",MAX_PATH*2, "uint")
                if !(vPath = "")
                    SplitPath(vPath, &vName)
                ;MEM_COMMIT := 0x1000
                ;MEM_IMAGE := 0x1000000
                if (vMbiState & 0x1000) && (vMbiType & 0x1000000) && instr(vName, "notepad") {
                    ;get address where path starts
                    if A_Is64bitOS
                        dllcall("kernel32\IsWow64Process", "ptr",hProc, "int*",&vIsWow64Process)
                    if !A_Is64bitOS || vIsWow64Process ;if process is 32-bit
                        vAddress := vMbiBaseAddress + 0xCAE0 ;(vMbiBaseAddress + 0xD378 also appears to work)
                    else
                        vAddress := vMbiBaseAddress + 0x10B40
                    break
                }
                vAddress += vMbiRegionSize
                if (vAddress > 2**32-1) ;4 gigabytes
                    return
            }
        }
        vPath := buffer(MAX_PATH*2, 0)
        dllcall("kernel32\ReadProcessMemory", "ptr",hProc, "ptr",vAddress, "str",vPath, "uptr",MAX_PATH*2, "uptr",0)
        dllcall("kernel32\CloseHandle", "ptr",hProc)
        return vPath
    }

    ;arr := [
    ;   ["item1",(p*)=>msgbox(1)],
    ;   ["item2",(p*)=>msgbox(3)],
    ;]
    ; appedMenu(arr) {
        ; hMyMenu := DllCall("CreateMenu")
        ; DllCall("AppendMenu", "Ptr",hMyMenu, "UInt",MF_STRING:=0, "UInt","", "Str","Item 1")
        ; DllCall("AppendMenu", "Ptr",hMyMenu, "UInt",MF_STRING:=0, "UInt","", "Str","Item 2")
        ; hwnd := WinGetid("A")
        ; hMenu := DllCall("GetMenu", "Ptr",hWnd, "Ptr")
        ; DllCall("AppendMenu", "Ptr",hMenu, "UInt",MF_POPUP:=0x10, "Ptr",hMyMenu, "Str","MyMenu")
        ; DllCall("DrawMenuBar", "Ptr",hWnd)
        ; WinActivate()
        ; return
        ;
        ; ~LButton::
        ; DllCall("GetCursorPos", "Int64P",POINT)
        ; idx := DllCall("MenuItemFromPoint", "Ptr",hWnd, "Ptr",hMyMenu, "Int64",POINT)
        ; if (idx >= 0)
        ;     msgBox(idx + 1)
        ; return
    ; }
}
