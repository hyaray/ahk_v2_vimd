vimd_Everything.init()
class vimd_Everything extends _ET {

    static init() {
        this.win := vimd.initWin("Everything", "ahk_exe Everything.exe")
        this.mode1 := this.win.initMode(1,, true)
        this.mode1.objTips.set(
        )

        ;hotkey("F4", (p*)=>_ET.smartDo())

        this.mode1.mapkey("\l",(p*)=>hyf_runByVim(A_ScriptDir . "\lib\Everything.ahk"),"编辑lib\Everything.ahk")
        this.mode1.mapkey("b",(p*)=>vimd_Everything.compare(),"比较")

        mapF5("{F5}")
        mapF5(k0) {
            this.mode1.mapkey(format("{1}{1}",k0),(p*)=>ControlChooseString("所有", "ComboBox1"),"显示-所有")
            this.mode1.mapkey(format("{1}f",k0),(p*)=>ControlChooseString("文件", "ComboBox1"),"显示-文件")
            this.mode1.mapkey(format("{1}d",k0),(p*)=>ControlChooseString("文件夹", "ComboBox1"),"显示-文件夹")
            this.mode1.mapkey(format("{1}e",k0),(p*)=>ControlChooseString("排除列表", "ComboBox1"),"显示-排除列表")
            this.mode1.mapkey(format("{1}i",k0),(p*)=>send("{ctrl down}i{ctrl up}"),"大小写切换")
            this.mode1.mapkey(format("{1}r",k0),(p*)=>send("{ctrl down}r{ctrl up}"),"正则切换")
            this.mode1.mapkey(format("{1}1",k0),(p*)=>vimd_Everything.toggleIgnore(),"切换-启用排除列表(不推荐)")
        }

        ;this.mode1.mapkey("e",(p*)=>hyf_runByVim(vimd_Everything.currentFilePath()),"vim打开")
        this.mode1.mapkey("<super>{F3}",(p*)=>run(vimd_Everything.currentFilePath()),"run")
        this.mode1.mapkey("<super>{F4}",(p*)=>hyf_runByVim(vimd_Everything.currentFilePath()),"run")

        mapF12("{F12}")
        mapF12(k0){
            this.mode1.mapkey(format("{1}{1}",k0),(p*)=>vimd_Everything.openOption(),"打开配置")
            this.mode1.mapkey(format("{1}k",k0),(p*)=>vimd_Everything.openOption("常规\快捷键"),"配置-快捷键")
            this.mode1.mapkey(format("{1}i",k0),(p*)=>vimd_Everything.openOption("索引\排除列表"),"配置-排除列表")
            this.mode1.mapkey(format("{1}u",k0),ObjBindMethod(vimd_Everything,"update"),"更新")
        }
    }

    static update() {
        run("https://www.voidtools.com/downloads")
        run("https://www.voidtools.com/Everything-SDK.zip")
        msgbox("注意要同时更新dll文件(下载sdk包)",,0x40000)
    }

    static toggleIgnore() {
        if (0) {
            run(format('{1} /exclude_list_enabled=1', _ET.spath))
        } else {
            vimd_Everything.openOption("索引\排除列表")
            send("{alt down}e{alt up}")
        }
    }

    static post(n) => PostMessage(0x111, n,,, "ahk_class EVERYTHING")

    static openOption(item:="") {
        this.post(40074)
        WinWaitActive("ahk_class #32770")
        if (item != "")
            _TreeView("SysTreeView321").selectByPath(item)
    }

    ;40051
    static SearchIssue() { ;部分文件搜不到
        sleep(100)
        this.openOption()
        msgbox("1、查看选项→索引→NTFS，确认所有分区都【包含到数据库】`n2、如果断电，硬盘的数据可能有缺失，对硬盘所有文件右键属性，让它重新遍历文件数")
    }

    static setFilter(item) => ControlChooseString(item, "ComboBox1", "A")

    ;static arrSelect() {
    ;    return StrSplit(ListViewGetContent("Selected", "SysListView321", "ahk_class EVERYTHING"), "`n", "`r")
    ;}

    static arrFpSelect() {
        arrFp := []
        loop parse, ListViewGetContent("Selected", "SysListView321", "ahk_class EVERYTHING"), "`n", "`r" {
            arrLine := StrSplit(A_LoopField, "`t")
            arrFp.push(format("{1}\{2}", arrLine[2],arrLine[1]))
        }
        return arrFp
    }

    ;光标选中的文件路径
    static currentFilePath() {
        arr := StrSplit(ListViewGetContent("Selected", "SysListView321", "ahk_class EVERYTHING"), A_Tab)
        if (arr.length)
            return format("{1}\{2}", arr[2],arr[1])
    }

    static compare() {
        cntSelect := SendMessage(LVM_GETSELECTEDCOUNT:=0x1032,,, "SysListView321", "ahk_class EVERYTHING")
        if (!cntSelect || cntSelect > 2)
            return
        arrFp := []
        if (cntSelect == 1) {
            ;当前选中的序号
            idxSelect := SendMessage(LVM_GETSELECTIONMARK:=0x1042,,, "SysListView321", "ahk_class EVERYTHING") + 1
            arrSelect := StrSplit(ListViewGetContent("Selected", "SysListView321", "ahk_class EVERYTHING"), "`t")
            arrFp.push(format("{1}\{2}", arrSelect[2],arrSelect[1]))
            ;找同名文件路径
            loop parse, ListViewGetContent(, "SysListView321", "ahk_class EVERYTHING"), "`n", "`r" {
                if (A_Index == idxSelect)
                    continue
                if (instr(A_LoopField, arrSelect[1]) == 1) { ;找到目标
                    arrLine := StrSplit(A_LoopField, "`t")
                    arrFp.push(format("{1}\{2}", arrLine[2],arrLine[1]))
                    break
                }
            }
        } else if (cntSelect == 2) {
            loop parse, ListViewGetContent("Selected", "SysListView321", "ahk_class EVERYTHING"), "`n", "`r" {
                arrLine := StrSplit(A_LoopField, "`t")
                arrFp.push(format("{1}\{2}", arrLine[2],arrLine[1]))
            }
        }
        run(format('d:\TC\soft\BCompare\BCompare.exe "{1}" "{2}"', arrFp*)) ;fpCompare := "d:\TC\soft\WinMerge\WinMergeU.exe"
    }

}
;#include hyaray.ahk

class _ET {

    static spath := "d:\TC\soft\Everything\Everything.exe"
    static dll := format("d:\BB\plugins\vimd\wins\Everything\Everything{1}.dll", A_PtrSize*8)
    static exclude:= "!c:\windows\ !c:\windows.old\ !\$RECYCLE.BIN\ !\.SynologyWorkingDirectory !\_FreeFileSync_\ !d:\hy\ !u:" ;!\_gsdata_\ !c:\Users\
    ;static res := map()

    ;fpOrFn用来运行程序
    ;funcHwndOrwinClass很多程序，还需要进一步筛选
    ;   如果是 ahk_class class，则默认会过滤空标题
    ;   如果还要考虑标题，必须要传入函数来判断
    ;objFunApi的键是br(beforeRun), ar(afterRun), ba(beforeActive), aa(afterActive), bh(beforeHide), ah(afterHide)
    ;有些窗口不需要记录窗口id
    static smartWin(fpOrFn, funcHwndOrwinClass:=unset, objFunApi:="", allWin:=0) {
        ;获取 exeName
        if (instr(fpOrFn, ":"))
            SplitPath(fpOrFn, &exeName)
        else
            exeName := fpOrFn
        if (exeName ~= "i)\.[vbe|cmd|bat]") ;NOTE cmd的需要转换
            exeName := substr(exeName,1,strlen(exeName)-4) . ".exe"
        ;获取 winTitle(用来遍历)
        winTitle := "ahk_exe " . exeName
        if (isset(funcHwndOrwinClass)) {
            if (funcHwndOrwinClass is string) {
                winTitle := format("{1} {2}", funcHwndOrwinClass,winTitle)
                funcHwndOrwinClass := (*)=>1
            }
        }
        ;if (isobject(funcHwndOrwinClass) || (funcHwndOrwinClass == ""))
        ;    winTitle := "ahk_exe " . exeName
        ;else
        ;    winTitle := funcHwndOrwinClass . " ahk_exe " . exeName
        ;获取 fnn
        fnn := exeName.noExt64()
        if (fnn ~= "^\d") ;数字开头不能当函数名
            fnn := "_" . fnn
        ;处理逻辑
        ;OutputDebug(format("i#{1} {2}:ProcessExist(exeName)={3}", A_LineFile,A_LineNumber,ProcessExist(exeName)))
        if (!ProcessExist(exeName)) {
            smartRun()
        } else if (WinActive(winTitle)) {
            if (isobject(objFunApi) && objFunApi.has("bh")) ;返回 运行函数
                objFunApi["bh"].call()
            WinHide(winTitle)
            if (allWin) {
                for hwnd in WinGetList(winTitle)
                    WinHide(hwnd)
            }
            ;激活鼠标所在窗口 TODO
            MouseGetPos(,, &idMouse)
            WinActivate(idMouse)
        } else { ;NOTE
            arrHwnd := hyf_hwnds(winTitle, funcHwndOrwinClass)
            if (allWin) { ;激活所有匹配窗口(比如开了多个谷歌浏览器)
                for v in arrHwnd {
                    WinShow(v)
                    WinActivate(v)
                    idWin := v
                }
                WinActivate(idWin)
            } else {
                if (arrHwnd.length) {
                    idWin := arrHwnd[1]
                    WinShow(idWin)
                    WinActivate(idWin)
                } else {
                    tooltip("找不到窗口，从激活改成【打开】")
                    smartRun()
                    SetTimer(tooltip, -1000)
                }
            }
            if (isobject(objFunApi) && objFunApi.has("aa"))
                objFunApi["aa"].call()
        }
        smartRun() {
            ;_ToolTip.tips("启动中，请稍等...")
            params := ""
            if (isobject(objFunApi) && objFunApi.has("br")) ;返回 运行函数
                params := objFunApi["br"]() ;TODO 待验证 删除了 .call
            fp := instr(fpOrFn, ":") ? fpOrFn : _ET.get(fpOrFn)
            SplitPath(fp, &fn, &dir)
            if (params != "")
                fp := format("{1} {2}", fp,params)
            OutputDebug(format("i#{1} {2}:fp={3}", A_LineFile,A_LineNumber,fp))
            ;打开程序
            try
                run(fp, dir)
            catch
                throw ValueError(fp)
            ;打开后自动运行
            if (isobject(objFunApi) && objFunApi.has("ar")) { ;返回 运行函数
                objFunApi["ar"].call()
            } else {
                ;sleep(1000)
                ;if !ProcessExist(exeName) {
                ;    msgbox(exeName . "`n未出现，打开软件失败",,0x40000)
                ;    exit
                ;}
                if (WinWait(winTitle,, 2)) { ;自动激活
                    if !WinWaitActive(winTitle,, 0.2)
                        WinActivate(winTitle)
                }
            }
        }
    }

    static search(filename, exclude:="") { ;返回为数组，部分路径(分隔符不能是/)
        findInDir := false
        if (filename ~= "i)^[a-z]:[\\/]") {
            if (FileExist(filename))
                return [filename]
            else
                findInDir := true
        }
        ;确定修饰词sType
        if (findInDir)
            sType := ""
        else if (filename ~= "\\$") ;文件夹
            sType := "folder:"
        else if (instr(filename, "\"))
            sType := "file:" ;NOTE file:后面的*能确保匹配结果末尾一致
        else
            sType := "wfn:"
        ;修改filename
        ;if (filename ~= "\\.*[^\\]$") ;1.部分路径的文件，加*配合file:使用
        if !findInDir && (filename ~= "\\\S") ;1.部分路径的文件，加*配合file:使用
            filename := "*" . filename
        if (filename ~= "\\$") ;2.删除末尾\
            filename := RTrim(filename, "\")
        if !findInDir && instr(filename, A_Space) ;3.包含空格，则两边加上"
            filename := '"' . filename . '"' ;NOTE 搜文件夹必须去掉末尾的\
        ;exclude
        if (exclude == "")
            exclude := this.exclude
        ;sSearch开始搜索
        sSearch := format("{1}{2} {3}", sType,filename,exclude) ;添加前缀修饰符和过滤文件夹
        ;开始搜索
        if !dllcall("GetModuleHandle", "str",this.dll)
            hModule := dllcall("LoadLibrary", "str",this.dll)
        dllcall(this.dll . "\Everything_SetSearch", "str",sSearch)
        ;msgbox(FileExist(this.dll))
        if (dllcall(this.dll . "\Everything_Query", "int",1)) { ;搜索成功
            n := dllcall(this.dll . "\Everything_GetTotResults")
            if (!n)
                return [filename] ;系统应用比如mspaint.exe，res未加载，直接返回mspaint.exe
            arr := []
            loop(n) {
                res := _ET.GetResultFullPathName(A_Index-1)
                arr.push(res)
            }
            ;dllcall("FreeLibrary", "Ptr", hModule)
            return arr
        } else {
            throw ValueError(format("搜索失败: {1}`nGetSearch: {2}`nGetLastError: {3}", sSearch,strget(dllcall(this.dll "\Everything_GetSearch")),dllcall(this.dll "\Everything_GetLastError")))
            ;return []
        }
    }

    ;获取Everything的单个搜索结果
    ;部分路径(分隔符用\)，搜文件夹则末尾加上\
    static get(filename) { ;从Everything多个结果中选择一个，如果没则返回空
        if (filename ~= "i)^[a-z]:[\\/]" && FileExist(filename))
            return filename
        if (filename ~= "\.exe$") ;TODO 不搜c:\windows的exe
            exclude := this.exclude
        else
            exclude := this.exclude
            ;exclude := StrReplace(this.exclude, "!c:\windows\", "!c:\") ;不搜C:\的文档资料
        fps := this.search(filename, exclude)
        OutputDebug(format("i#{1} {2}:fps={3}", A_LineFile,A_LineNumber,json.stringify(fps,4)))
        n := fps.length
        if (n) { ;有找到
            if (n >= 1) {
                arrRes := hyf_tooltipAsMenu(fps)
                if (arrRes.length >= 2)
                    return arrRes[2]
                else
                    return ""
            } else {
                return fps[1]
            }
        } else if !(filename ~= "\\|\/") { ;不包含/或\，则继续从PATH里寻找
            p := RegRead("HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\control\Session Manager\Environment", "PATH")
            loop parse, p, "`;" {
                fp := format("{1}\{2}", A_LoopField,filename)
                if (instr(fp, "%"))
                    fp := var2Str(fp)
                if (FileExist(fp))
                    return fp
            }
        }
        var2Str(str) { ;把%var%(只匹配\w的字符串)转换成变量的值
            reg := "(.*?)%([a-zA-Z_]\w+)%(.*)"
            startPos := 1
            loop { ;有变量
                p := RegExMatch(str, reg, &m, startPos)
                if (p) {
                    varPath := EnvGet(m[2])
                    if (varPath != "") {
                        startPos := m.pos(2)+ strlen(varPath) - 1
                        str := format("{1}{2}{3}{4}", substr(str,1,p-1),m[1],varPath,m[3])
                    } else { ;没有变量(一般没用)
                        startPos := m.pos(2)+ strlen(m[2]) + 1
                        str := format("{1}{2}%{3}%{4}", substr(str,1,p-1),m[1],m[2],m[3])
                    }
                } else
                    return str
            }
        }
    }

    ;先排序后限制个数
    ;sSearch已包含修饰符
    ;dllcall(this.dll . "\Everything_SetMax", "int",nLimit) ;使用 count:3 限制数量更好
    ;nSort
    ;EVERYTHING_SORT_NAME_ASCENDING                      (1)
    ;EVERYTHING_SORT_NAME_DESCENDING                     (2)
    ;EVERYTHING_SORT_PATH_ASCENDING                      (3)
    ;EVERYTHING_SORT_PATH_DESCENDING                     (4)
    ;EVERYTHING_SORT_SIZE_ASCENDING                      (5)
    ;EVERYTHING_SORT_SIZE_DESCENDING                     (6)
    ;EVERYTHING_SORT_EXTENSION_ASCENDING                 (7)
    ;EVERYTHING_SORT_EXTENSION_DESCENDING                (8)
    ;EVERYTHING_SORT_TYPE_NAME_ASCENDING                 (9)
    ;EVERYTHING_SORT_TYPE_NAME_DESCENDING                (10)
    ;EVERYTHING_SORT_DATE_CREATED_ASCENDING              (11)
    ;EVERYTHING_SORT_DATE_CREATED_DESCENDING             (12)
    ;EVERYTHING_SORT_DATE_MODIFIED_ASCENDING             (13)
    ;EVERYTHING_SORT_DATE_MODIFIED_DESCENDING            (14)
    ;EVERYTHING_SORT_ATTRIBUTES_ASCENDING                (15)
    ;EVERYTHING_SORT_ATTRIBUTES_DESCENDING               (16)
    ;EVERYTHING_SORT_FILE_LIST_FILENAME_ASCENDING        (17)
    ;EVERYTHING_SORT_FILE_LIST_FILENAME_DESCENDING       (18)
    ;EVERYTHING_SORT_RUN_COUNT_ASCENDING                 (19)
    ;EVERYTHING_SORT_RUN_COUNT_DESCENDING                (20)
    ;EVERYTHING_SORT_DATE_RECENTLY_CHANGED_ASCENDING     (21)
    ;EVERYTHING_SORT_DATE_RECENTLY_CHANGED_DESCENDING    (22)
    ;EVERYTHING_SORT_DATE_ACCESSED_ASCENDING             (23)
    ;EVERYTHING_SORT_DATE_ACCESSED_DESCENDING            (24)
    ;EVERYTHING_SORT_DATE_RUN_ASCENDING                  (25)
    ;EVERYTHING_SORT_DATE_RUN_DESCENDING                 (26)
    static searchAdvanced(sSearch, nSort:=0) {
        if !dllcall("GetModuleHandle", "str",this.dll)
            hModule := dllcall("LoadLibrary", "str",this.dll)
        dllcall(this.dll . "\Everything_SetSearch", "str",sSearch)
        if (nSort)
            dllcall(this.dll . "\Everything_SetSort", "uint",nSort)
        ;dllcall(this.dll . "\Everything_SetMax", "int",3) ;使用 count:3 限制数量更好
        if (dllcall(this.dll . "\Everything_Query", "uint",true)) { ;等待结果
            n := dllcall(this.dll . "\Everything_GetNumResults")
            dllcall(this.dll . "\Everything_GetTotResults")
            if !n ;NOTE mklink的文件夹，此搜索会有问题
                return [] ;系统应用比如mspaint.exe，fp未加载，直接返回mspaint.exe
            arr := []
            loop(n) {
                fp := _ET.GetResultFullPathName(A_Index-1)
                arr.push(fp)
            }
            ;dllcall("FreeLibrary", "Ptr",hModule)
            return arr
        }
    }

    ;第i个结果
    static GetResultFullPathName(i:=0, nLen:=256) {
        VarSetStrCapacity(&fp, nLen*2)
        dllcall(this.dll . "\Everything_GetResultFullPathName", "int",i, "str",fp, "int",nLen)
        return fp
    }

    ;搜索扩展名最新文件
    static searchExtNewFile(ext) => run(format("{1} -sort-descending -search *.{2}", this.spath,ext))

    ;NOTE 返回arr
    ;获取文件夹最新的cnt个项目路径数组
    ;tp F或D(参考loop files的标识)
    ;TODO 屏蔽TC隐藏文件
    static getNewItems(dir, cnt:=1, tp:="F", filterHide:=true) {
        obj := map("F","file","D","folder")
        tp := obj.has(tp) ? obj[tp] : "file"
        return _ET.searchAdvanced(format('count:{1} {2}:nosubfolders:"{3}"', cnt,tp,dir), 14)
    }

    static runc(p) { ;运行Everything
        run(p . " -startup")
        while(1) { ;等待Everything运行完毕
            if !ProcessExist("Everything.exe") {
                if (A_Index < 10) ;循环5秒
                    sleep(500)
                else {
                    msgbox("Everything运行失败，脚本退出`n" . p,,0x40000)
                    ExitApp
                }
            } else {
                sleep(500)
                break
            }
        }
    }

    static onekey(bCopy:=false) {
        sSearch := bCopy ? hyf_getSelect() : ""
        if (WinActive("ahk_class EVERYTHING")) {
            WinHide
            MouseGetPos(,, &idA)
            WinActivate(idA)
        } else if (sSearch != "") {
            if (sSearch.isabs() || (sSearch ~= "^\\\\"))
                run(format('{1} -search "{2}"', _ET.spath,sSearch.fnn()))
            else
                run(format('{1} -search "{2}"', _ET.spath,sSearch))
        } else
            run(_ET.spath)
    }

    static sendquery(hwnd,num,search_string,RegEx,match_case,match_whole_word,match_path) {
        DetectHiddenWindows(true)
        if (idEv := WinExist("ahk_class EVERYTHING_TASKBAR_NOTIFICATION")) {
            len := strlen(search_string)
            size := 22 + len*2
            query := buffer(size)
            numput("UPtr", hwnd, query)
            numput("UPtr", RegEx<<3|match_case<<2|match_whole_word<<1|match_path, query, A_PtrSize*2)
            numput("UPtr", num, query, A_PtrSize*4)
            dllcall("RtlMoveMemory","Uint",query.ptr+A_PtrSize*5, "Uint",&search_string, "Uint",(len+1)*2)
            cds := buffer(A_PtrSize*3)
            numput("UPtr", 2, cds)
            numput("UPtr", size, cds, A_PtrSize)
            numput("UPtr", query.ptr, cds, A_PtrSize*2)
            SendMessage(0x4A, hwnd, &cds,, idEv)
            ;if errorlevel != FAIL
            ;return true
        } else
            msgbox("Everything未打开")
        return 0
    }

    static version(a) {
        idEv := WinExist("ahk_class EVERYTHING_TASKBAR_NOTIFICATION")
        if (idEv)
            return SendMessage(0x400, a,,, idEv)
    }

    static searchMode() { ;[Everything 区分大小写]
        obj := map(
            "大小写","case,",
            "正则","RegEx,",
            "文件名","wfn,",
	    )
        SendMessage(0x147, 0, 0, "Edit1", "A")
        str_EvEdit1 := ControlGetText("Edit1", "A")
        if (instr(str_EvEdit1, "case:")) {
            str_EvEdit1 := StrReplace(str_EvEdit1, "case:")
            ControlSetText(str_EvEdit1, "Edit1", "A")
        } else {
            ControlSetText("case:" . str_EvEdit1, "Edit1", "A")
        }
        send("{end}")
        return
    }

    ;获取所有exe、ahk、lnk数据，依赖dll
    ;多个结果，只获取第一个 TODO
    static build() {
        if !ProcessExist("Everything.exe")
            _ET.runc(_ET.spath)
        ;加载Everything查询数据!c:\users因为Chromium取消
        arrSearch := ["wfn:*.exe" , "wfn:*.ah1|*.ahk|*.lnk|*.txt|*.chm|*.pdf"]
        res := map()
        if !dllcall("GetModuleHandle", "str",this.dll)
            hModule := dllcall("LoadLibrary", "str",this.dll, "ptr")
        for k, v in arrSearch {
            dllcall(this.dll . "\Everything_SetSearch", "str",format("{1} {2}", v,this.exclude))
            dllcall(this.dll . "\Everything_Query", "int",true)
            loop(dllcall(this.dll . "\Everything_GetTotResults")) {
                i := A_Index - 1
                fn := strget(dllcall(this.dll . "\Everything_GetResultFileName", "int",i)) ;res用fn(如QQ.exe)当Key
                fp := _ET.GetResultFullPathName(i)
                if (res.has(fn)) {
                    continue ;只获取第一个结果 TODO
                    ;if !isobject(res[fn]) ;有多个结果
                    ;res[fn] := [res[fn]]
                    ;res[fn].push(bufFP)
                } else
                    res[fn] := fp
            }
        }
        try
            dllcall("FreeLibrary", "Ptr", hModule)
        return res
    }

}
