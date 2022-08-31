/*
详情可见 cmd.itmz

ssh 工具推荐用 MobaXterm
    备用 ssh -D 9090 -p 8889 127.0.0.1

命令行
    run(format('s:\cmder\vendor\conemu-maximus5\ConEmu64.exe -Dir "{1}"', dir))

删除整行 Ctrl-u

切换目录

问题
    进 git 仓库卡
        s:\cmder\vendor\clink.lua
        local git_dir = get_git_dir() 所在行左边加--
    因为在此系统上禁止运行脚本。有关详细信息，请参阅 https:/go.microsoft.com/fwlink/?LinkID=135170 中的 about_Execution_Policies。
        解决方法：运行 set-ExecutionPolicy RemoteSigned
*/

class VimD_Cmder {

    static __new() {
        if (this != VimD_Cmder)
            return
        this.win := vimd.initWin("Cmder", "ahk_class VirtualConsoleClass") ;Console.exe cmd.exe
        this.win.cls := this

        this.mode1 := this.win.initMode(1, true, (p*)=>1)
        this.mode1.objTips.set(
            "g", "git",
            "p", "ping",
        )

        this.win.setKeySuperVim()

        ;hotkey("F4", (p*)=>msgbox(VimD_Cmder.getCurrentTabName()))
        hotkey("F12", (p*)=>send("{alt down}{LWin down}p{LWin up}{alt up}"))

        this.mode1.setObjHotWin("管理员: ahk_class VirtualConsoleClass", false, ["ahk_class VirtualConsoleClass"])

        ;this.mode2.setObjHotWin("管理员: ahk_class VirtualConsoleClass", false, ["ahk_class VirtualConsoleClass"])

        ;this.mode2.mapkey("rz1", (p*)=>sendEx("rz1"), "rz1")
        ;this.mode2.mapkey("rz2", (p*)=>sendEx("rz2"), "rz2")
        ;this.mode2.mapkey("rz3", (p*)=>sendEx("rz3"), "rz3")
        ;this.mode2.mapkey("rz4", (p*)=>sendEx("rz4"), "rz4")
        ;this.mode2.mapkey("rz5", (p*)=>sendEx("rz5"), "rz5")
        ;this.mode2.mapkey("rz6", (p*)=>sendEx("rz6"), "rz6")
        ;this.mode2.mapkey("rz7", (p*)=>sendEx("rz7"), "rz7")
        ;this.mode2.mapkey("rz8", (p*)=>sendEx("rz8"), "rz8")
        ;this.mode2.mapkey("rz9", (p*)=>sendEx("rz9"), "rz9")

        ;cd
        this.mode1.mapkey("cdd", (p*)=>sendEx("d:\ee"), "cd d:")

        ;查看
        this.mode1.mapkey("trd", (p*)=>sendEx("tree .`n"), "tree .")
        this.mode1.mapkey("trf", (p*)=>sendEx("tree /f .`n"), "tree /f .")

        ;ping
        this.mode1.mapkey("pp", (p*)=>sendEx(format("ping 192.168.{1}.", VimD_Cmder.win.setRepeatDo(1))), "ping 192.168.16.")
        this.mode1.mapkey("p1", (p*)=>sendEx(format("ping {1} -t`n", RegExReplace(_Cmd.ipPart(),"\d+$","1"))), "ping 网关")
        this.mode1.mapkey("p2",(p*)=>sendEx(format("ping {1} -t", _Cmd.ipPart(2))), "ping ip2")
        this.mode1.mapkey("p3",(p*)=>sendEx(format("ping {1} -t", _Cmd.ipPart(3))), "ping ip3")
        this.mode1.mapkey("pt", (p*)=>sendEx("ping taobao.com -t`n"), "ping taobao")

        ;telnet
        this.mode1.mapkey("t2",(p*)=>sendEx("telnet " . _Cmd.ipPart(2)), "telnet ip2")
        this.mode1.mapkey("t6", (p*)=>sendEx("telnet 192.168.16.28 11520"), "telnet 192.168.16.28 11520")
        this.mode1.mapkey("t8", (p*)=>sendEx("telnet 192.168.16.28 1433"), "telnet 192.168.16.28 1433")

        ;tracert
        this.mode1.mapkey("tc", (p*)=>sendEx("tracert -d -w 500 "), "tracert")

        ;net user
        this.mode1.mapkey("uac", (p*)=>sendEx("net user /active", "net user administrator /active:yes"), "net user /active")
        this.mode1.mapkey("ude", (p*)=>sendEx("net user /delete", "net user administrator /delete"), "net user /active")
        this.mode1.mapkey("uad", (p*)=>_Cmd.netuserAdd(),"net user /add")
        this.mode1.mapkey("umo", (p*)=>_Cmd.netuserModify(), "net user /modify")

        ;this.mode1.mapkey("npmi", (p*)=>sendEx("npm install --modules-folder d:\TC\soft\node "), "npm install")
        ;this.mode1.mapkey("mac", (p*)=>sendEx("getmac /NH"), "getmac")
        this.mode1.mapkey("ipa", (p*)=>sendEx("ipconfig /all"), "ipconfig /all")
        this.mode1.mapkey("ipc", (p*)=>sendEx("ipconfig"), "ipconfig")
        ;this.mode1.mapkey("das", (p*)=>sendEx("django-admin startproject"), "django-admin")
        ;this.mode1.mapkey("smp", (p*)=>sendEx("ssh pi@317600.xyz",500,"{enter}",1000,"shishi",200,"{enter}"), "树莓派")
        this.mode1.mapkey("up", (p*)=>_Cmd.sendP("net user administrator *"), "net user password delete")
        ;["ub", "fix Bug", (p*)=>_Cmd.fixBug()], ;解决排版问题
        ;["vhd", "create vdisk file=d:\hy\ww.vhdx maximum=4096 type=expandable"],

        this.mode1.setObjHotWin("MINGW ahk_class VirtualConsoleClass", false, ["ahk_class VirtualConsoleClass"])
        this.mode1.mapkey("cd", (p*)=>sendEx("cd /d/ee"), "cd d:")
        ;git
        this.mode1.mapkey("gu",(p*)=>sendEx('git config --global user.name "hyaray"'), "git config --global user.name")
        this.mode1.mapkey("ge",(p*)=>sendEx('git config --global user.email "hyaray@vip.qq.com"'), "git  config --global user.email")
        this.mode1.mapkey("gl",(p*)=>sendEx("git config --global core.autocrlf false"), "git config --global 关闭自动转换换行符")
        this.mode1.mapkey("ra",(p*)=>sendEx("git remote add origin https://github.com/hyaray/ahk_v2_.git", "{left 4}"), "git remote add")
        this.mode1.mapkey("rs",(p*)=>sendEx("git remote show origin`n"), "git remote show")
        this.mode1.mapkey("rt",(p*)=>VimD_Cmder.gitSecurt(), "git remote add token")
        ;   status
        this.mode1.mapkey("st",(p*)=>sendEx("git status`n"), "git status")
        this.mode1.mapkey("lg",(p*)=>sendEx("git log`n"), "git log")
        this.mode1.mapkey("l1",(p*)=>sendEx("git log --oneline`n"), "git log --oneline")
        this.mode1.mapkey("ls",(p*)=>sendEx("git ls-files"), "git ls-files")
        this.mode1.mapkey("lv",(p*)=>sendEx("git ls-files -v"), "git ls-files -v")
        ;   diff
        this.mode1.mapkey("d1", (p*)=>sendEx("git diff"), "git diff")
        this.mode1.mapkey("d2", (p*)=>sendEx("git diff --cached"), "git diff --cached")
        this.mode1.mapkey("d3", (p*)=>sendEx("git diff HEAD"), "git diff HEAD")
        ;   add
        this.mode1.mapkey("aa",(p*)=>sendEx("git add "), "git  add")
        this.mode1.mapkey("a.",(p*)=>sendEx("git add .`n"), "git  add .")
        ;   branch
        this.mode1.mapkey("sc",(p*)=>sendEx("git switch -c "), "git switch -c")
        this.mode1.mapkey("bd",(p*)=>sendEx("git branch -d "), "git branch -d")
        this.mode1.mapkey("bD",(p*)=>sendEx("git branch -D "), "git branch -D")
        this.mode1.mapkey("co",(p*)=>sendEx("git checkout "), "git checkout")
        ;   fetch
        this.mode1.mapkey("ff",(p*)=>sendEx("git fetch origin/main"), "git fetch origin/main")
        ;   merge
        this.mode1.mapkey("mr",(p*)=>sendEx("git merge origin/main"), "git merge origin/main")
        this.mode1.mapkey("mm",(p*)=>sendEx("git merge "), "git merge")
        ;   commit
        this.mode1.mapkey("cc",(p*)=>sendEx('git commit -am ""',"{left}"), 'git commit -am')
        this.mode1.mapkey("cm",(p*)=>sendEx('git commit -amend ""',"{left}"), 'git commit -amend')
        this.mode1.mapkey("C",(p*)=>sendEx('git add .`n git commit -am ""',"{left}"), 'git add & commit -am')
        ;   rebase
        this.mode1.mapkey("ri",(p*)=>sendEx("git rebase -i "), "git rebase -i")
        this.mode1.mapkey("rh",(p*)=>sendEx(format("git rebase -i HEAD~{1}", VimD_Cmder.win.setRepeatDo(2))), "git rebase -i HEAD~n")
        ;   push
        this.mode1.mapkey("ps",(p*)=>sendEx("git push origin main"), "git push origin main")
        ;   pull
        this.mode1.mapkey("pl",(p*)=>sendEx("git pull origin main"), "git pull origin main")
        ;   restore
        this.mode1.mapkey("rs",(p*)=>sendEx("git restore"), "git restore")

        this.win.setMode(0)
    }

    static gitSecurt() {
        SendText("git remote set-url origin https://")
        hyf_char("340909171C3B0B2526291E1E2E060D5720163D0B1F0A350A0400310427140F3F14595C1337072700")
        sleep(500)
        sendEx("@github.com/hyaray/ahk_v2_.git", "{left 4}")
    }

    static getCurrentTabName() {
        elWin := UIA.ElementFromHandle(WinActive("A"), true)
        elTab := elWin.GetLast().GetLast()
        ;elTab.getTabItems()
        return elTab.FindControl("TabItem", ComValue(0xB,-1), "SelectionItemIsSelected").CurrentName
    }

    static youget(){
        WinActive("A")
        ctl := (ControlGetFocus() || WinGetID())
        url := _CB.getUrl()
        str := "you-get -o c:\Users\Administrator\Desktop " . url
        loop parse, str
            PostMessage(0x102, ord(A_LoopField),, ctl)
        return
    }

}

class _Cmd {

    ;static fixBug() { ;ConsoleZ
    ;    RegWrite(0x000003a8, "REG_DWORD", "HKEY_CURRENT_USER\Console\ConsoleZ command window", "CodePage")
    ;    RegWrite(0x000a0000, "REG_DWORD", "HKEY_CURRENT_USER\Console\ConsoleZ command window", "FontSize")
    ;    RegWrite(0x00000036, "REG_DWORD", "HKEY_CURRENT_USER\Console\ConsoleZ command window", "FontFamily")
    ;    RegWrite(0x00000190, "REG_DWORD", "HKEY_CURRENT_USER\Console\ConsoleZ command window", "FontWeight")
    ;    RegWrite("Consolas", "REG_SZ", "HKEY_CURRENT_USER\Console\ConsoleZ command window", "FaceName")
    ;    RegWrite(0x00000000, "REG_DWORD", "HKEY_CURRENT_USER\Console\ConsoleZ command window", "HistoryNoDup")
    ;}

    static netuserAdd(user:="administrator", pwd:="", fullname:="") {
        if (fullname != "")
            SendText(format('net user {1} {2} /add /fullname:"{3}"', user,pwd,fullname))
        else
            SendText(format('net user {1} {2} /add', user,pwd))
    }

    static netuserModify(user:="administrator", pwd:="", fullname:="") {
        if (fullname != "")
            SendText(format('net user {1} {2} /fullname:"{3}"', user,pwd,fullname))
        else
            SendText(format('net user {1} {2}', user,pwd))
    }

    ;static ipPi() {
    ;    ip := _Windows.getIP()
    ;    arr := StrSplit(ip, ".")
    ;    obj := map(
    ;        "2","192.168.2.215",
    ;        "9","192.168.2.229",
    ;    )
    ;    if obj.has(arr[3])
    ;        return obj[arr[3]]
    ;}

    ;task 不含{}
    static runSend(sCmd, dir:="", task:="") {
        if (dir == "")
            dir := A_Desktop
        sRun := format('s:\cmder\vendor\conemu-maximus5\ConEmu64.exe /single -dir "{1}"', dir)
        if (task != "")
            sRun .= format(" -run {{1}}", task)
        run(sRun)
        WinWaitActive("ahk_class VirtualConsoleClass")
        ;OutputDebug(sCmd)
        ;if WinExist("ahk_class Console_2_Main")
        ;    WinActivate
        ;else
        ;    run(format('{1}\tool\ConsoleZ\Console.exe -d "{2}"', _TC.dir, dir))
        ;WinWaitActive("ahk_class Console_2_Main")
        while(!CaretGetPos())
            sleep(100)
        SendText(sCmd)
    }

    static ipPart(n:=4) {
        ip := _Windows.getIP()
        if (ip == "")
            ip := "192.168.1.1"
        if (n == 4)
            return ip
        arr := StrSplit(ip, ".")
        res := ""
        loop(n)
            res .= arr[A_Index] . "."
        return res
    }

    static sendP(str, key:="") {
        SendText(str)
        if (key != "")
            send(key)
        ;WinActive("A")
        ;ctl := (ControlGetFocus() || WinGetID())
        ;loop parse, str
        ;    PostMessage(WM_CHAR:=0x102, ord(A_LoopField),, ctl)
    }
}
