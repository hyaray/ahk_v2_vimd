;说明：
;内置两个模式 mode0(原生) 和 mode1(vimd功能)，名称定义在 arrModeName
;默认按键 map 见 mapDefault
;按 ` 从 mode1→mode0
;按 escape 从 mode0→mode1(可能需要优先执行原生的escape功能,见 funCheckEscape)
;按键格式切换
;   keyIn 里，keyMap := vimd.key_hot2map(ThisHotkey) 主要逻辑都用 keyMap 处理
;进阶：
;   全局热键，建议 initWin 用 ahk_exe，再直接用 hotkey 定义热键
;   支持子窗口管理：各子窗口相对独立，但能在 initWin 后指定数组[hotwin1, hotwin2]，表明和其共用热键
;   像TC里，比如按了d后，是不希望执行vimd功能的
;   在Cmder里，git界面不想显示其他命令，在cmd界面，想显示git命令
;插件配制：见 wins\Notepad\VimD_Notepad.ahk
;NOTE 注意有两个阶段
;   1. 【定义】热键: mapkey mapDynamic
;   2. 【触发】热键: keyIn 进行各种获取和判断
;NOTE 脚本出错后务必运行 vimd.errorDo()，取消注释末尾的 OnError

class vimd {
    static arrModeName := ["None","Vim"]
    ;static charSplit := "※" ;分隔各命令
    static winCurrent := "" ;记录当前的窗口，用来出错后 init
    static tipLevel := 15
    static tipLevel1 := 16 ;其他辅助显示

    static __new() {
        OutputDebug(format("i#{1} {2}:{3}", A_LineFile,A_LineNumber,A_ThisFunc))
        this.objWin := map() ;在 initWin里设置
        ;HotIfWinActive ;TODO 关闭
    }

    ;NOTE 核心，由各插件自行调用
    static initWin(winName, winTitle, cls:=unset) {
        ;msgbox(winName . "`n" . json.stringify(this.objWin, 4))
        if !this.objWin.has(winName)
            this.objWin[winName] := this.vimdWins(winName)
        win := this.objWin[winName]
        ;定义 hotwin
        if (winTitle == "")
            throw ValueError("winTitle is empty")
        HotIfWinActive(winTitle)
        win.arrHotIfWin.push(winTitle)
        win.currentHotIfWin := winTitle ;NOTE 做个标记未设置
        win.objHotIfWin_SingleKey[win.currentHotIfWin] := map()
        ;定义cls(可选)，比如和 cls.getTitleEx 联动
        if isset(cls)
            win.cls := cls
        return win
    }

    ;NOTE 运行出错后必须要执行此方法，否则下次 vimd 的第一个键会无效
    static errorDo(str:="") {
        if (this.winCurrent)
            this.winCurrent.currentMode.init()
        if (str != "") {
            msgbox(A_ThisFunc . "`n" . str,,0x40000)
            exit
        }
    }

    static hideTips() {
        tooltip(,,, this.tipLevel)
    }

    static hideTips1() {
        tooltip(,,, this.tipLevel1)
    }

    static showTips1(str, x:=0, y:=0) { ;辅助显示，固定在某区域
        tooltip(str, x, y, this.tipLevel1)
    }

    ;-----------------------------------key__-----------------------------------
    /*
    this.DictVimKey := map(
        "<LButton>","LButton", "<RButton>","RButton", "<MButton>","MButton",
        "<XButton1>","XButton1",   "<XButton2>","XButton2",
        "<WheelDown>","WheelDown", "<WheelUp>","WheelUp",
        "<WheelLeft>","WheelLeft", "<WheelRight>","WheelRight",
        键盘控制,
        "<CapsLock>","CapsLock", "<Space>","Space", "<Tab>","Tab",
        "<Enter>","Enter", "<Esc>","Escape", "<BS>","BackSpace",
        Fn,
        "<F1>","F1","<F2>","F2","<F3>","F3","<F4>","F4","<F5>","F5","<F6>","F6",
        "<F7>","F7","<F8>","F8","<F9>","F9","<F10>","F10","<F11>","F11","<F12>","F12",
        光标控制,
        "<ScrollLock>","ScrollLock", "<Del>","Del", "<Ins>","Ins",
        "<Home>","Home", "<End>","End", "<PgUp>","PgUp", "<PgDn>","PgDn",
        "<Up>","Up", "<Down>","Down", "<Left>","Left", "<Right>","Right",
        修饰键,
        "<Lwin>","LWin", "<Rwin>","RWin",
        "<control>","control", "<Lcontrol>","Lcontrol", "<Rcontrol>","Rcontrol",
        "<Alt>","Alt", "<LAlt>","LAlt", "<RAlt>","RAlt",
        "<Shift>","Shift", "<LShift>","LShift", "<RShift>","RShift",
        特殊键,
        "<Insert>","Insert", "<Ins>","Insert",
        "<AppsKey>","AppsKey", "<LT>","<", "<RT>",">",
        "<PrintScreen>","PrintScreen",
        "<controlBreak>","controlBrek",
    )
    ; 数字小键盘暂时不支持
    ; 功能键
    this.DictVimModifier := map(
        "S","shift", "LS","lshift", "RS","rshift &",
        "A","alt", "LA","lalt", "RA","ralt",
        "C","control", "LC","lcontrol", "RC","rcontrol",
        "W","lwin", "LW","lwin", "RW","lwin",
        "T","tab", "L","CapsLock", "E","Escape",
    )
    this.DictVimModifierSend := map(
        "S","+", "LS","+", "RS","+",
        "A","!", "LA","!", "RA","!",
        "C","^", "LC","^", "RC","^",
        "W","#", "LW","#", "RW","#",
    )
    */

    ;NOTE 用于内部逻辑判断
    ;从 ThisHotkey (vimd里map定义的键)提取 keyMap
    ;带修饰键
    ;   +a --> A
    ;   ^a --> <^a> 一般都直接执行
    ;多字符
    ;   space --> A_Space 不用{space}
    ;   enter --> {enter}
    ;   escape --> {escape}
    ;单字符
    ;   CapsLock则转换大小写
    ;   其他不处理
    static key_hot2map(ThisHotkey) {
        keyMap := ThisHotkey
        if (keyMap ~= "[+!#^].") { ;带修饰键
            keyMap := (keyMap ~= "^\+[a-z]$") ;大写字母 +a
                ? (GetKeyState("CapsLock", "T") ? substr(keyMap,-1) : StrUpper(substr(keyMap,-1)))
                : format("<{1}>", keyMap)
        ;} else if (ThisHotkey ~= "i)^[rl]\w+\s\&\s\S+") { ;LShift & a
        ;    keyMap := (ThisHotkey ~= "i)^[rl]shift\s\&\s[a-z]")
        ;        ? StrUpper(substr(ThisHotkey,-1))
        ;        : format("<{1}>", ThisHotkey)
        } else if (strlen(keyMap) > 1) {
            if (1) ;更符合用户查看方式
                keyMap := (ThisHotkey=="space") ? A_Space : format("{{1}}", ThisHotkey)
            else
                keyMap := format("{{1}}", keyMap)
        } else { ;长度=1
            if GetKeyState("CapsLock", "T") { ;大小写转换
                if (keyMap ~= "^[a-z]$")
                    keyMap := StrUpper(keyMap)
                else if (keyMap ~= "^[A-Z]$")
                    keyMap := StrLower(keyMap)
            }
        }
        return keyMap
    }

    ;keyMap := vimd.key_hot2map()
    static key_map2send(keyMap) {
        if (keyMap ~= "^<.+>")
            keyMap := substr(keyMap, 2, strlen(keyMap)-2)
        else if (strlen(keyMap) == 1) ;支持大小写
            keyMap := (keyMap==" " ? "{space}" : format("{{1}}", keyMap))
        return keyMap
    }

    ;获取当前 hotif 指定的 WinTitle 字符串
    ;感谢【天黑请闭眼】大佬的支持
    static getHotIfWin() {
        GlobalStruct := '
        (
            int64 mLoopIteration;
            ptr mLoopFile;
            ptr mLoopRegItem;
            ptr mLoopReadFile;
            LPTSTR mLoopField;
            ptr CurrentFunc;
            ptr CurrentMacro;
            ptr CurrentTimer;
            ptr hWndLastUsed;
            int EventInfo;
            ptr DialogHWND;
            ptr DialogOwner;
            ptr ThrownToken;
            int ExcptMode;
            uint LastError;
            int Priority;
            int UninterruptedLineCount;
            int UninterruptibleDuration;
            uint ThreadStartTime;
            uint CalledByIsDialogMessageOrDispatchMsg;
            bool IsPaused;
            bool MsgBoxTimedOut;
            bool CalledByIsDialogMessageOrDispatch;
            bool AllowThreadToBeInterrupted;
            ptr HotCriterion;
            uint PeekFrequency;
            int TitleMatchMode;
            int WinDelay;
            int ControlDelay;
            int KeyDelay;
            int KeyDelayPlay;
            int PressDuration;
            int PressDurationPlay;
            int MouseDelay;
            int MouseDelayPlay;
            uint RegView;
            int SendMode;
            UINT Encoding;
            int CoordMode;
            bool TitleFindFast;
            bool DetectHiddenWindows;
            bool DetectHiddenText;
            bool AllowTimers;
            bool ThreadIsCritical;
            UCHAR DefaultMouseSpeed;
            bool StoreCapslockMode;
            int SendLevel;
            bool ListLinesIsEnabled;
            ptr ExcptDeref;
            BYTE ZipCompressionLevel;
        )'
        g := Struct(GlobalStruct, A_GlobalStruct)
        if !g.HotCriterion
            return
        HotkeyCriterion := '
        (
            int Type;
            LPTSTR WinTitle;
            LPTSTR WinText;
            LPTSTR OriginalExpr;
            ptr Callback;
            ptr NextCriterion;
            ptr NextExpr;
            uint ThreadID;
        )'
        hc := Struct(HotkeyCriterion, g.HotCriterion)
        return hc.WinTitle
        ;return ['HOT_NO_CRITERION', 'HOT_IF_ACTIVE', 'HOT_IF_NOT_ACTIVE', 'HOT_IF_EXIST', 'HOT_IF_NOT_EXIST', 'HOT_IF_CALLBACK'][hc.Type+1] . "`n" . hc.WinTitle . "`n" . hc.WinText . "`n" . hc.OriginalExpr
    }

    static checkInclude() {
        SplitPath(A_LineFile,, &dir)
        fp := format("{1}\vimdInclude.ahk",dir)
        str := fileread(fp)
        loop files, dir . "\wins\*", "D" {
            if (A_LoopFileAttrib ~= "[HS]")
                continue
            if instr(str, A_LoopFileName)
                continue
            f := FileOpen(fp, "w", "utf-8-raw")
            strInclude := ""
            loop files, format("{1}\wins\*",A_LineFile.dir()), "D"
                strInclude .=  format("#include wins\{1}\VimD_{1}.ahk`n",A_LoopFileName)
            f.write(strInclude)
            f.close()
            return
        }
    }

    ;窗口对象会直接生成两个默认的mode(changeMode获取)
    ;模式由各插件自行定义(生成+map一并进行)
    class vimdWins {
        __new(name) {
            ;主要属性
            this.name := name
            this.arrMode := [] ;默认2个模式
            this.arrHotIfWin := [] ;记录所有 currentHotIfWin
            ;this.modeList := map()
            this.currentMode := ""
            this.currentHotIfWin := ""
            ;目的：单键在同个 HotIfWinActive 下不要重复【定义】(【使用】记录的对象在 vimdModes 属性里记录)
            ;NOTE 先定义了 key1 = currentHotIfWin(为了支持子窗口)
            ;用任意模式【定义一次hotkey】即可(是否要特殊考虑第一个按键？)，能拦截到，后续由 keyIn 处理逻辑
            ;key2 = 单键, 记录所有已拦截的按键
            this.objHotIfWin_SingleKey := map()
            this.objHotIfWin_SingleKey.CaseSense := true
            ;其他属性
            this.count := 0
            this.isBreak := false ;无视count
            this.isRepeat := false
            this.funTipsCoordinate := "" ;获取 tooltip 的坐标
            ;event(部分事件在 vimdWins 部分事件在 vimdModes)
            this.onBeforeChangeMode := ""
            this.onAfterChangeMode := ""
            ;this.onBeforeMap := ""
            ;this.onAfterMap := ""
            this.onBeforeShowTip := ""
            this.onBeforeHideTip := ""
            ;搭配 keySuperVim 使用
            this.keySuperVim := ""
            this.keyToMode0 := "``"
            this.keyDebug := "{F10}" ;用得较少 {F12}一般用在配置文件
            this.typeSuperVim := 0 ;1=只切换 2=切换并执行按键
            this.objKeySuperVim := map() ;记录超级按键，比 keySuperVim 多了个生效当前按键功能
        }

        ;初始化内置的模式(mode0|mode1)
        ;此方法由各插件调用(生成+map一并进行)
        ;默认的模式放最后定义，或者最后加上 win.changeMode(i)
        ;NOTE 必须先 initMode(0) 再 initMode(1)
        ;NOTE 必须先 setHotIf
        initMode(idx, bCount:=true, funOnBeforeKey:=false, modename:="") {
            if (this.currentHotIfWin == "")
                throw ValueError('request "setHotIf" done')
            ;mode0 未定义，则自动定义
            if (idx == 1 && this.arrMode.length == 0)
                this.initMode(0)
            this.currentMode := vimd.vimdModes(idx, this, modename)
            if (this.arrMode.length < idx+1)
                this.arrMode.push(this.currentMode)
            else
                this.arrMode[idx] := this.currentMode
            ;NOTE 在这里直接定义 initWin 时设置的 currentHotIfWin
            this.currentMode.objHotIfWin_FirstKey[this.currentHotIfWin] := map()
            this.currentMode.mapDefault(bCount)
            if funOnBeforeKey
                this.currentMode.onBeforeKey := isobject(funOnBeforeKey) ? funOnBeforeKey : ObjBindMethod(this.currentMode,"beforeKey")
            return this.currentMode
        }

        getMode(i:=-1) {
            if (i == -1)
                return this.currentMode
            else
                return this.arrMode[i+1]
        }
        setMode(i) {
            return this.currentMode := this.getMode(i)
        }

        getArrWinMatch(winTitle, pushself:=false) {
            OutputDebug("-----------------------------------arrTitle-----------------------------------")
            OutputDebug(format("d#{1} {2}:{3} winTitle={4}", A_LineFile,A_LineNumber,A_ThisFunc,winTitle))
            hwnd := WinExist(winTitle)
            if (hwnd == 0)
                throw TargetError(winTitle)
            arrMaybe := []
            for win in this.arrHotIfWin {
                if (win == winTitle)
                    continue
                thisHwnd := WinExist(win)
                if (thisHwnd == hwnd)
                    arrMaybe.push(win)
            }
            arrMaybe.push(winTitle)
            ;获取所有窗口
            obj := map()
            for win in arrMaybe {
                obj[win] := 1
                if this.currentMode.objHotIfWins.has(win) {
                    for win1 in this.currentMode.objHotIfWins[win]
                        obj[win1] := 1
                }
            }
            arrRes := []
            for k in obj
                arrRes.push(k)
            OutputDebug(format("d#{1} {2}:{3}", A_LineFile,A_LineNumber,json.stringify(arrRes)))
            return arrRes
        }

        ;指定后面热键的窗口(大部分是针对ahk_class的)
        ;NOTE bAsHotIfWin 如果全为true，则会存在抢热键的情况，单个键只能在一个窗口生效，【先定义】的 HotIfWin 优先，所以要考虑兼容性问题
        ;   如果为 false，热键仍然生效，菜单仍会出现，可根据 objHotIfWins[winTitle] 的数组自由组合
        ;vimd.initWin 内容较多，这是纯净版
        setHotIf(winTitle, bAsHotIfWin:=true) {
            this.arrHotIfWin.push(winTitle)
            ;定义 vimdWins 的属性
            this.currentHotIfWin := winTitle
            this.objHotIfWin_SingleKey[this.currentHotIfWin] := map()
            if bAsHotIfWin
                HotIfWinActive(winTitle)
        }

        ;超级模式
        ;md 1=只切换 2=切换并执行按键
        setSuperMode(md:=1, bTooltip:=false) {
            if (this.typeSuperVim == md && bTooltip) {
                tooltip(format("don't repeat!`nmodeBeforeSuper = {1}", this.modeBeforeSuper.name))
                SetTimer(tooltip, -1000)
                return
            }
            this.typeSuperVim := md
            ;记录之前的模式，后续恢复用
            this.modeBeforeSuper := this.currentMode
            this.currentMode := this.getMode(1)
            if bTooltip {
                tooltip(format("modeBeforeSuper = {1}", this.modeBeforeSuper.name))
                SetTimer(tooltip, -1000)
            }
        }
        exitSuperMode() {
            if (this.typeSuperVim == 1) {
                tooltip(this.modeBeforeSuper.name)
                SetTimer(tooltip, -1000)
            }
            this.typeSuperVim := 0
            ;记录之前的模式，后续恢复用
            this.currentMode := this.DeleteProp("modeBeforeSuper")
        }

        ;NOTE 至少需要初始化一个模式
        setKeySuperVim(keySuperVim:="{RControl}") {
            ;标记此键
            this.keySuperVim := keySuperVim
            ;vimd 拦截此键，功能为切换到 super mode1(不判断 onBeforeKey，结束用 typeSuperVim 来全局判断)
            this.currentMode.mapkey(keySuperVim ,ObjBindMethod(this,"changeMode",1),"super mode1")
        }

        ;临时把 count 当值使用(默认是执行 count 次功能)
        ;方便插件调用
        setRepeatDo(cntDefault:=1) {
            this.isBreak := true
            return this.GetCount(cntDefault)
        }

        GetCount(cntDefault:=1) { ;执行时用(默认返回1，而用count属性默认为0)
            return this.count ? this.count : cntDefault
        }

        ;设置currentMode，不存在会自动new
        ;由于会触发事件，所以不能在初始化时使用，很可能找不到窗口出错
        ;i 从0开始
        changeMode(i) {
            if (this.onBeforeChangeMode)
                this.onBeforeChangeMode.call(this.currentMode)
            tooltip((this.typeSuperVim==1 ? "super " : "") . this.setMode(i).name)
            SetTimer(tooltip, -1000)
            if (this.onAfterChangeMode) ;TODO 一般用来修改样式让用户清楚当前在哪个模式
                this.onAfterChangeMode.call(this.currentMode)
            return this.currentMode
        }

        ;NOTE 由 vimdWins 对象接收按键并调度
        ;这里只处理特殊情况
        ;由 _keyIn() 处理后续细节
        ;byScript 非手工按键，而是用脚本触发时，需要传入此参数，如 VimD_WeChat.win.keyIn("F3", "ahk_exe WeChat.exe")
        keyIn(ThisHotkey, byScript:=0) {
            keyMap := vimd.key_hot2map(ThisHotkey)
            OutputDebug(format("i#{1} {2}:A_ThisFunc={3}-------------------start", A_LineFile,A_LineNumber,A_ThisFunc))
            OutputDebug(format("currentMode.index={1}", this.currentMode.index))
            OutputDebug(format("arrKeymapPressed.length = {1}", this.currentMode.arrKeymapPressed.length))
            OutputDebug(format("keyMap={1}", keyMap))
            OutputDebug(format("typeSuperVim = {1}", this.typeSuperVim ))
            OutputDebug(format("objKeySuperVim={1}", json.stringify(this.objKeySuperVim)))
            OutputDebug(format("i#{1} {2}:A_ThisFunc={3}-------------------end", A_LineFile,A_LineNumber,A_ThisFunc))
            ;NOTE 记录当前的窗口，用来出错后 init
            vimd.winCurrent := this
            bChecked := false
            ;第一个按键 && 无视模式的按键
            if (this.currentMode.arrKeymapPressed.length == 0) {
                if (keyMap == this.keySuperVim) { ;如 {RControl}
                    this.setSuperMode(1, true)
                    exit
                } else if (this.objKeySuperVim.has(keyMap)) { ;<super>
                    OutputDebug(format("i#{1} {2}:{3} is <super>", A_LineFile,A_LineNumber,keyMap))
                    this.setSuperMode(2)
                    bChecked := true
                }
            }
            this.currentMode._keyIn(keyMap, byScript)
            if (this.currentMode.onAfterKey)
                this.currentMode.onAfterKey.call(keyMap)
        }

    }

    ;TODO mode暂时不支持子窗口
    ;-----------------------------------maps-----------------------------------
    ;-----------------------------------do__-----------------------------------
    ;-----------------------------------tip-----------------------------------
    class vimdModes {

        __new(idx, win, modename:="") {
            this.index := idx
            this.win := win ;标记是哪个窗口的mode
            if (idx > 1)
                vimd.arrModeName.push(modename!="" ? modename : format("mode{1}",idx))
            else if (modename != "") ;修改内置模式名
                vimd.arrModeName[this.index+1] := modename
            this.name := this.win.name . "-" . vimd.arrModeName[this.index+1]
            ;this.funcDo := ""
            this.objDoSave := {} ;保存上个 objDo
            this.objTips := map() ;NOTE 大纲提示(可动态在命令里用 this.mode1.objTips[key] 来添加)
            this.objTips.CaseSense := true
            this.objFunDynamic := map() ;记录所有需要验证动态信息的按键(可以快速过滤无关按键)
            this.objFunDynamic.CaseSense := true
            ;NOTE objHotIfWin_xxx 对象，都先定义了 key1 = currentHotIfWin(为了支持子窗口)
            ;key2 = keyMapFirst, value = objDo
            this.objKeysmap := map() ;{keysmap, objDo}
            this.objKeysmap.CaseSense := true
            this.objHotIfWin_FirstKey := map()
            this.objHotIfWin_FirstKey.CaseSense := true
            this.thisHotIfWin := "" ;以第一个键判断当前匹配窗口(解决窗口乱匹配，导致热键识别问题)
            ;NOTE 用 array 可以记录顺序
            this.arrListDynamic := [] ;动态命令
            ;event(部分事件在 vimdWins 部分事件在 vimdModes)
            ;NOTE 智能判断按键(智能模式识别的核心)返回 false 则直接发送按键
            ;NOTE 如果是第2个键则不进行判断
            this.onBeforeKey := ""
            this.onAfterKey := ""
            this.onBeforeDo := ""
            this.onAfterDo := ""
            ;NOTE NOTE NOTE 在 None 模式下临时切换为 Vim <2022-07-28 15:00:47>
            ;按键定义参考 key_hot2map 返回值
            this.keySuperVim := ""
            this.arrKeymapPressed := [] ;记录每个按键
            this.tipsDynamic := "" ;NOTE 动态生成，所以不需要 map()
            this.objHotIfWins := map() ;记录当前子窗口的关联窗口名
        }

        ;脚本运行过程出错，要先运行此命令退出，否则下次按键会无效(TODO 具体原因)
        ;NOTE 执行命令或中途退出才执行
        init(done:=true, noTips:=true) { ;默认隐藏 tooltip
            OutputDebug(format("i#{1} {2}:{3}", A_LineFile,A_LineNumber,A_ThisFunc))
            ;自身属性
            this.arrKeymapPressed := [] ;记录每个按键
            ;this.funcDo := ""
            this.tipsDynamic := "" ;NOTE 动态生成，所以不需要 map()
            if (this.win.typeSuperVim)
                this.win.exitSuperMode()
            vimd.hideTips1()
            if (noTips)
                vimd.hideTips()
            if (done) {
                ;win 属性
                this.win.count := 0
                this.win.isRepeat := false
                this.win.isBreak := false
            }
        }

        ;NOTE 设置关联，适合复杂逻辑，否则用 setHotIf 即可
        setObjHotWin(winTitle, bAsHotIfWin:=true, arrWinTitle:=unset) {
            this.win.setHotIf(winTitle, bAsHotIfWin)
            this.objHotIfWin_FirstKey[this.win.currentHotIfWin] := map()
            if isset(arrWinTitle)
                this.objHotIfWins[winTitle] := arrWinTitle is array ? arrWinTitle : [arrWinTitle]
        }

        ;NOTE 被keyIn调用
        _keyIn(keyMap, byScript) {
            OutputDebug(format("i#{1} {2}:{3}", A_LineFile,A_LineNumber,A_ThisFunc))
            if (this.arrKeymapPressed.length) {
                this.update(keyMap)
                return
            }
            ;NOTE 以第一个键判断当前匹配窗口
            this.thisHotIfWin := (byScript==0) ? vimd.getHotIfWin() : this.win.arrHotIfWin[1] ;NOTE 不太准确，可能两个窗口都定义了此按键
            ;4. 判断 onBeforeKey
            if (this.win.typeSuperVim==0 && isobject(this.onBeforeKey)) { ;NOTE typeSuperVim 则不执行 onBeforeKey
                if (this.onBeforeKey.call(keyMap) == 0) { ;返回 false，则相当于 None 模式
                    OutputDebug(format("d#{1} {2}:onBeforeKey false", A_LineFile,A_LineNumber))
                    send(vimd.key_map2send(keyMap))
                    exit
                }
            }
            ;自动运行 objFunDynamic()
            if (this.HasOwnProp("objFunDynamic") && this.objFunDynamic.has(keyMap)) {
                OutputDebug(format("i#{1} {2}:{3}.objFunDynamic({4})", A_LineFile,A_LineNumber,this.name,keyMap))
                this.arrListDynamic := [] ;NOTE 每次都要清空
                this.objFunDynamic[keyMap].call()
                OutputDebug(format("i#{1} {2}:{3}.arrListDynamic.length == {4}", A_LineFile,A_LineNumber,this.name,this.arrListDynamic.length))
            } else {
                OutputDebug(format("i#{1} {2}:{3} 键没有动态", A_LineFile,A_LineNumber,keyMap))
            }
            ;非常规功能
            if this.objKeysmap.has(keyMap) { ;单键功能
                OutputDebug(format("this.objKeysmap.has({1}) do={2}", keyMap,this.objKeysmap[keyMap]["comment"]))
                if (keyMap ~= "^\d$") {
                    this.dealCount(integer(keyMap))
                } else {
                    this.do(this.objKeysmap[keyMap])
                }
                exit
            } else {
                OutputDebug(format("this.objKeysmap.not has({1})", keyMap))
                if (this.index == 0) {
                    send(vimd.key_map2send(keyMap))
                } else {
                    this.update(keyMap)
                }
            }
        }

        ;更新当前匹配的命令并 showTips
        ;先修改arrKeymapPressed再运行
        update(keyMap) {
            OutputDebug(format("{1} keyMap={2}", A_ThisFunc,keyMap))
            if (keyMap == "{BackSpace}") {
                this.arrKeymapPressed.pop()
                OutputDebug(format("new arrKeymapPressed = {1}", json.stringify(this.arrKeymapPressed)))
                if (!this.arrKeymapPressed.length) {
                    this.init()
                    return
                }
            } else {
                this.arrKeymapPressed.push(keyMap)
            }
            arrMatch := [] ;记录所有匹配热键(不分动态和普通)
            strCache := this.getStrCache()
            OutputDebug(format("i#{1} {2}:strCache={3}", A_LineFile,A_LineNumber,strCache))
            ;匹配动态命令
            if (keyMap == "\")
                this.addTipsDynamic(this.name)
            ;   命令列表是在第1个键动态生成，后续按键需要动态更新
            for objDo in this.arrListDynamic {
                if (instr(objDo["string"],strCache,true) == 1)
                    arrMatch.push(objDo)
            }
            OutputDebug(format("i#{1} {2}:after check doListDynamic, arrMatch.length={3}", A_LineFile,A_LineNumber,arrMatch.length))
            ;匹配普通命令
            arrTitle := this.win.getArrWinMatch(this.thisHotIfWin, true) ;NOTE NOTE NOTE 获取当前热键可能匹配的 arrTitle
            for winTitle in arrTitle  {
                arrThis := addByWinTitle(winTitle)
                OutputDebug(format("i#{1} {2}:winTitle={3} arrThis={4}", A_LineFile,A_LineNumber,winTitle,json.stringify(arrThis, 4)))
            }
            OutputDebug(format("i#{1} {2}:last arrMatch.length={3}", A_LineFile,A_LineNumber,arrMatch.length))
            if (!arrMatch.length) { ;没找到命令
                if (this.arrKeymapPressed.length == 1) ;为第1个按键
                    send(this.arrKeymapPressed[1])
                this.init()
            } else if (arrMatch.length == 1) { ;单个结果
                ;msgbox(json.stringify(arrMatch[1], 4))
                this.do(arrMatch[1])
            } else { ;大部分情况
                this.showTips(arrMatch)
            }
            addByWinTitle(winTitle) {
                arrThis := []
                if (this.objHotIfWin_FirstKey[winTitle].has(this.arrKeymapPressed[1])) {
                    for objDo in this.objHotIfWin_FirstKey[winTitle][this.arrKeymapPressed[1]] {
                        OutputDebug(format('i#{1} {2}:objDo["string"]={3}', A_LineFile,A_LineNumber,objDo["string"]))
                        if (instr(objDo["string"],strCache,true) == 1) { ;NOTE 匹配大小写
                            arrMatch.push(objDo)
                            arrThis.push(objDo["string"])
                        }
                    }
                }
                return arrThis
            }
        }

        dealCount(keyMap) {
            if (keyMap == "{BackSpace}") {
                if (this.win.count > 9) { ;两位数
                    this.win.count := this.win.count//10
                } else {
                    this.init()
                    return
                }
            } else {
                this.win.count := this.win.count ? this.win.count*10+integer(keyMap) : integer(keyMap)
            }
            this._show(string(this.win.count))
        }

        getStrCache() { ;arrKeymapPressed连接字符串
            str := ""
            for v in this.arrKeymapPressed
                str .= v
            return str
        }

        ;-----------------------------------maps-----------------------------------

        /*
        objDo := map()
        objDo["arrkey"] := []
        objDo["string"] := "" ;按键字符串
        objDo["hotwin"] := "" ;NOTE 记录按键当前的窗口，实际上因为按键冲突，没用
        objDo["action"] := ""
        objDo["comment"] := ""
        objDo["super"] := super ;热键永远 on(无视模式)，直接用 hotkey()定义即可
        */
        ;公共 map
        mapDefault(bCount:=true) {
            if (this.index == 0) { ;mode0
                this.mapkey("{escape}",ObjBindMethod(this,"doGlobal_Escape"),"进入 mode1")
            } else if (this.index == 1) { ;mode1
                this.mapkey("{escape}",ObjBindMethod(this,"doGlobal_Escape"),"escape")
                this.mapkey("{BackSpace}",ObjBindMethod(this,"doGlobal_BackSpace"),"BackSpace")
                ;由于这次模式还没生成，如果这两个键定义在 win 的属性
                this.mapkey(this.win.keyToMode0,ObjBindMethod(this.win,"changeMode",0),"进入 mode0")
                ;NOTE 定义debug的内置功能，自带 <super> 参数
                this.win.keyDebug := format("<super>{1}", this.win.keyDebug)
                this.mapkey(this.win.keyDebug . "{F10}",ObjBindMethod(this,"doGlobal_Edit"),"【编辑】VimD_" . this.win.name)
                this.mapkey(this.win.keyDebug . "[",ObjBindMethod(this,"doGlobal_objByFirstKey"),"查看所有功能(按窗口和首键分组)objHotIfWin_FirstKey")
                this.mapkey(this.win.keyDebug . "]",ObjBindMethod(this,"doGlobal_objKeysmap"),"查看所有功能(按keymap分组)objKeysmap")
                this.mapkey(this.win.keyDebug . "=",ObjBindMethod(this,"doGlobal_objHotIfWins"),"查看所有窗口关系objHotIfWins")
                this.mapkey(this.win.keyDebug . "-",ObjBindMethod(this,"doGlobal_Debug_objSingleKey"),"查看所有拦截的按键 objHotIfWin_SingleKey")
                this.mapkey(this.win.keyDebug . "|",ObjBindMethod(this,"doGlobal_Debug_objKeySuperVim"),"查看所有的<super>键 objKeySuperVim")
                if bCount
                    this.mapCount()
                this.mapkey("." ,ObjBindMethod(this,"doGlobal_Repeat"),"重做")
            }
        }
        mapCount() {
            loop(10)
                this.mapkey(string(A_Index-1),ObjBindMethod(this,"dealCount"),format("<{1}>", A_Index-1)) ;TODO keyIn
        }

        ;keysmap类型 <^enter> {F1} + A
        mapkey(keysmap, funcObj, comment) {
            objDo := this._map(keysmap, funcObj, comment)
            keyMapFirst := vimd.key_hot2map(objDo["arrkey"][1])
            ;添加到objHotIfWin_FirstKey(objTips用) NOTE keysmap要区分大小写，否则会被覆盖
            if (!this.objHotIfWin_FirstKey[this.win.currentHotIfWin].has(keyMapFirst))
                this.objHotIfWin_FirstKey[this.win.currentHotIfWin][keyMapFirst] := [objDo]
            else
                this.objHotIfWin_FirstKey[this.win.currentHotIfWin][keyMapFirst].push(objDo)
            this.objKeysmap[keysmap] := objDo
        }
        mapDynamic(keysmap, funcObj, comment) {
            objDo := this._map(keysmap, funcObj, "***" . comment) ;动态功能，前面加 ***
            this.arrListDynamic.push(objDo)
            this.objKeysmap[keysmap] := objDo
        }
        ;把定义打包为 objDo
        _map(keysmap, funcObj, comment) {
            objDo := this.key_map2arrHot(keysmap)
            objDo["action"] := funcObj
            objDo["comment"] := comment
            objDo["hotwin"] := this.win.currentHotIfWin
            for v in objDo["arrkey"] {
                if (A_Index == 1) {
                    if (objDo["super"]) ;记录超级键
                        this.win.objKeySuperVim[vimd.key_hot2map(v)] := 1
                }
                if (!this.win.objHotIfWin_SingleKey[this.win.currentHotIfWin].has(v)) { ;单键避免重复定义
                    hotkey(v, ObjBindMethod(this.win,"keyIn")) ;NOTE 相关的键全部要拦截，用 vimd 控制
                    this.win.objHotIfWin_SingleKey[this.win.currentHotIfWin][v] := 1
                }
            }
            return objDo
        }

        ;NOTE 和 vimd.key_hot2map() 相反，只用于转换用户定义的按键为 vimd 格式
        ;keysmap类型 <^enter> {F1} + A
        ;插件里定义的 keyMap(尽量兼容hotkey) 转成 hotkey 命令识别的格式的数组
        ;返回 arr(比如 <^a>A{enter}，则返回["^a","+a","enter"])
        ;带修饰键(一般都直接执行)
        ;   <^f> --> ^f
        ;多字符
        ;   {F1} --> F1
        ;单字符
        ;   空格 --> space
        ;   不处理
        ;二次处理
        ;   A --> +a
        key_map2arrHot(keysmap) {
            ;keysmap := RegExReplace(RegExReplace(RegExReplace(keysmap, "i)<super>", "", &super), "i)<noWait>", "", &noWait), "i)<noMulti>", "", &noMulti)
            keysmap := RegExReplace(keysmap, "i)<super>", "", &isSuper)
            objDo := map(
                "arrkey", [],
                "super", isSuper,
                "string", keysmap,
            )
            ;msgbox(json.stringify(objDo, 4))
            while(keysmap != "") {
                ;优先提取<>组合键，<^a>
                if RegExMatch(keysmap, "^<.+?>", &m) {
                    thisKey := substr(keysmap, 2, m.Len(0)-2) ;^a
                    keysmap := substr(keysmap, m.Len(0)+1)
                } else if RegExMatch(keysmap, "^\{.+?\}", &m) { ;{F1}
                    thisKey := substr(keysmap, 2, m.Len(0)-2) ;F1
                    keysmap := substr(keysmap, m.Len(0)+1)
                } else {
                    thisKey := substr(keysmap, 1, 1)
                    keysmap := substr(keysmap, 2)
                }
                ;二次处理
                if (thiskey == " ")
                    thisKey := "space"
                else if (thisKey ~= "^[A-Z]$") ;大写字母单个大写字母转成 +a
                    thisKey := "+" . StrLower(thisKey)
                objDo["arrkey"].push(thisKey)
            }
            return objDo
        }

        ;getmap(sKey) {
        ;}

        ;-----------------------------------do__-----------------------------------
        beforeKey(p*) {
            return !CaretGetPos()
        }

        ;doSend(key) {
        ;    if GetKeyState("CapsLock")
        ;        send(format("{shift down}{1}{shift up}", key))
        ;    else
        ;        send(key)
        ;}

        ;最终执行的命令
        ;NOTE 自动 init()
        do(objDo) {
            vimd.hideTips()
            ;msgbox(this.win.isRepeat . "`n" . json.stringify(objDo, 4))
            cnt := this.win.GetCount()
            ;timeSave := A_TickCount
            this.init(0)
            ;NOTE 运行
            loop(cnt) {
                this.callFunc(objDo["action"], true)
                if this.win.isBreak ;运行后才知道是否 isBreak
                    break
            }
            ;tooltip(A_TickCount - timeSave,,, 9)
            ;SetTimer(tooltip.bind(,,, 9), -1000)
            ;处理 repeat 和 count
            if !this.win.isRepeat {
                this.objDoSave := objDo
                this.CountSave := cnt
            }
            ;if isobject(this.onAfterDo)
            ;    this.callFunc(this.onAfterDo)
            this.init()
        }

        ;NOTE 这里不能初始化 isBreak
        ;网址没在内
        callFunc(funcObj, errExit:=false) {
            res := hyf_do(funcObj)
            if !res {
                if errExit
                    exit
                else
                    throw OSError("action not find")
            }
            hyf_do(var) {
                if !(var is string) {
                    var()
                    return 1
                }
                try {
                    if (type(%var%) ~= "^(ObjBindMethod|Closure|BoundFunc|Func)$") {
                        %var%()
                        return 1
                    }
                }
                if !(var ~= "i)^[a-z]:[\\/]") {
                    if (var ~= "^\w+\(\S*\)$") { ;运行function()
                        arr := StrSplit(substr(var, 1, strlen(var)-1), "(")
                        (arr[2]=="") ? %arr[1]%() : %arr[1]%(arr[2])
                        return 1
                    } else if (var ~= "^(\w+)\.(\w+)\((.*)\)$") { ;NOTE 运行 class.method(param1)
                        RegExMatch(var, "^(\w+)\.(\w+)\((.*)\)$", &m)
                        (m[3] != "") ?  %m[1]%.%m[2]%(m[3]) : %m[1]%.%m[2]%()
                        return 1
                    }
                    if (var ~= '^\{\w{8}(-\w{4}){3}-\w{12}\}$') { ;clsid
                        var := "explorer.exe shell:::" . var
                    } else if (var ~= '^\w+\.cpl(,@?\d?)*$') { ;cpl
                        var := "control.exe " . var
                        ;} else if (substr(var,1,12) == "ms-settings:") {
                        ;    var := var
                        ;} else if (var ~= 'i)^control(\.exe)?\s+\w+\.cpl$') {
                        ;    var := var
                    }
                    tooltip(var)
                    run(var)
                    SetTimer(tooltip, -1000)
                    return 1
                } else { ;打开文件，需要判断文件是否已打开，所以不处理
                    return 0
                }
            }
        }

        ;TODO 是否设置全局，这样出提示后，在其他未定义软件界面按键也能退出
        doGlobal_Escape() {
            OutputDebug(A_ThisFunc)
            OutputDebug(format("this.index = {1}", this.index))
            if (this.index == 0) {
                if (this.HasOwnProp("funCheckEscape") && this.funCheckEscape.call())
                    send("{escape}")
                else
                    this.win.changeMode(1)
            ;} else if (this.index > 0 && this.win.arrMode.length > 2) { ;TODO 更多模式，还是热键兼容问题
            ;    n := this.index + 1
            ;    if (n == this.win.arrMode.length)
            ;        n := 1
            ;    this.win.changeMode(n)
            } else if (!this.arrKeymapPressed.length && !this.win.count) {
                send("{escape}")
            } else {
                this.init()
            }
        }

        ;删除最后一个字符
        doGlobal_BackSpace() {
            if (this.arrKeymapPressed.length) {
                this.update()
            } else if (this.win.count) {
                this.dealCount("{BackSpace}")
            } else {
                send("{BackSpace}")
            }
        }
        doGlobal_Edit() {
            SplitPath(A_LineFile,, &dn)
            if (this.win.HasOwnProp("cls") && this.win.cls.HasOwnProp("getTitleEx")) {
                title := this.win.cls.getTitleEx(1)
                runByVim(format("{1}\wins\{2}\VimD_{2}.ahk",dn,this.win.name), title)
            } else {
                runByVim(format("{1}\wins\{2}\VimD_{2}.ahk",dn,this.win.name))
            }
            runByVim(fp, line:=0, params:="--remote-tab-silent") { ;用文本编辑器打开
                if (line is integer) {
                    if (line)
                        params .= " +" . line
                } else {
                    if !instr(line, " ") {
                        params .= format(' +/{1}', line)
                        if !(line ~= "\/[+-]\d+$") ;查找内容没有偏移行数，则手工添加/(FIXME 临时方案)
                            params .= "/"
                    }
                }
                if ProcessExist("gvim.exe")
                    WinShow("ahk_class Vim")
                run(format('d:\TC\soft\Vim\gvim.exe {1} "{2}"', params, fp))
                WinWait("ahk_class Vim")
                WinActivate("ahk_class Vim")
                WinWaitActive("ahk_class Vim")
                ;检查多进程 TODO 原因？？
                objPid := map()
                for hwnd in WinGetList("ahk_class Vim")
                    objPid[WinGetPID("ahk_id " . hwnd)] := 1
                if (objPid.count > 1)
                    msgbox("注意：gvim 有两个进程",,0x40000)
            }
        }
        doGlobal_Repeat() {
            this.win.isRepeat := true
            this.do(this.objDoSave)
        }
        doGlobal_Up() {
            send("{up}")
        }
        doGlobal_Down() {
            send("{down}")
        }
        doGlobal_Left() {
            send("{left}")
        }
        doGlobal_Right() {
            send("{right}")
        }
        doGlobal_objKeysmap() {
            ;msgbox(this.name . "`n" . this.index)
            res := ""
            for keymap, objDo in this.objKeysmap
                res .= format("{1}`t{2}`t{3}`t{4}`n", keymap,objDo["hotwin"],objDo["string"],objDo["comment"])
            msgbox(res,,0x40000)
        }
        doGlobal_objByFirstKey() {
            res := ""
            oInput := inputbox("首键")
            if (oInput.result=="Cancel" || oInput.value == "") {
                for winTitle, objKey in this.objHotIfWin_FirstKey {
                    for keysmap, arrKey in objKey {
                        for objDo in arrKey
                            res .= format("{1}`t{2}`t{3}`t{4}`t{5}`n", winTitle,objDo["hotwin"],keysmap,objDo["string"],objDo["comment"])
                    }
                }
            } else {
                for winTitle, objKey in this.objHotIfWin_FirstKey {
                    if objKey.has(oInput.value) {
                        for objDo in objKey[oInput.value]
                            res .= format("{1}`t{2}`t{3}`t{4}`t{5}`n", winTitle,objDo["hotwin"],oInput.value,objDo["string"],objDo["comment"])
                    }
                }
            }
            msgbox(res,,0x40000)
        }
        doGlobal_objHotIfWins() {
            msgbox(json.stringify(this.objHotIfWins, 4))
        }
        doGlobal_Debug_objSingleKey() {
            res := ""
            for winTitle, obj in this.win.objHotIfWin_SingleKey {
                for k, arr in obj
                    res .= format("{1}:{2}`n", winTitle,k)
            }
            msgbox(res,,0x40000)
        }
        doGlobal_Debug_objKeySuperVim() {
            res := ""
            for k, arr in this.win.objKeySuperVim
                res .= format("{1}`n", k)
            msgbox(res,,0x40000)
        }

        ;-----------------------------------tip-----------------------------------

        ;添加动态提示内容
        addTipsDynamic(str) {
            this.tipsDynamic .= "`t" . str
        }

        showTips(arrMatch) {
            OutputDebug(format("i#{1} {2}:{3}", A_LineFile,A_LineNumber,A_ThisFunc))
            strCache := this.getStrCache()
            ;sKey := (strCache ~= "^[A-Z]$") ? "S-" . strCache : strCache
            sKey := strCache
            strTooltip := this.objTips.has(sKey)
                ? strCache . A_Tab . this.objTips[sKey]
                : strCache
            strTooltip .= this.tipsDynamic ;NOTE 添加动态信息
            strTooltip .= "`n=====================`n"
            for objDo in arrMatch
                strTooltip .= format("{1}`t{2}`n", objDo["string"],objDo["comment"])
            OutputDebug(format("i#{1} {2}:strTooltip={3}", A_LineFile,A_LineNumber,strTooltip))
            this._show(strTooltip)
        }

        ;NOTE
        _show(str) {
            if (isobject(this.win.funTipsCoordinate)) {
                cmToolTip := A_CoordModeToolTip
                CoordMode("ToolTip", "window")
                arrXY := this.win.funTipsCoordinate.call()
                tooltip(str, arrXY[1], arrXY[2], vimd.tipLevel)
                CoordMode("ToolTip", cmToolTip)
            } else {
                MouseGetPos(&x, &y)
                x += 40
                y += 40
                tooltip(str, x, y, vimd.tipLevel)
            }
        }

    }

}

;OnError(errorDo)
;errorDo(exception, mode) {
;    msgbox(exception.file . "`n" . exception.line,,0x40000)
;    vimd.errorDo() ;NOTE 否则 vimd 下个按键会无效
;}

#include vimdInclude.ahk

