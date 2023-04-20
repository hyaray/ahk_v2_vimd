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
;插件配制：见 wins\Notepad\vimd_Notepad.ahk
;NOTE 注意有两个阶段
;   1. 【定义】热键: mapkey mapDynamic
;   2. 【触发】热键: keyIn 进行各种获取和判断
;NOTE 脚本出错后务必运行 vimd.errorDo()，取消注释末尾的 OnError
;不能简单区分模式的软件，推荐用Fx功能键，设计思路：
;   1. F10 vimd内置调试的功能
;   2. F12 当前软件全局配置，调试等功能
;   3. F1 进入各页面相关功能
;   4. F3 全局功能
;   5. F4 当前页面的动态功能
;   6. F6 根据markdown笔记的提示功能
;   7. F7 脚本的相关提示功能(更强大灵活)
;NOTE by 火冷 <2023-04-15 12:40:54> 重构了动态命令，全整合到 objFKey 里，用 normal和dynamic区分
;如果第1个键下的命令太多，全显示会太杂乱，增加分组功能，关键词是 group
;   按第1个键，如果有 group 属性则考虑：只出现2级的功能列表(相当于菜单文件夹，而非最终命令)
;   再按第2个键，如果类似菜单文件夹，则显示对应文件夹下的命令
;       NOTE 同时支持按下0时，如果没有匹配到命令，则执行当前显示的所有命令(批量执行分组的所有功能)
;       如果非分组热键，则全局搜索由 groupKeymap 定义的子节点热键
;定义示例
/*
mapF11("{F11}")
mapF11(k0) {
    this.mode1.setGroup(k0) ;额外增加这句
    ;推荐简化版
    a := [
        ["分组a","a"],
        [
            ["注释axy","xy"],
            ["注释ayx","yx"],
        ]
    ]
    this.mode1.mapGroup(format("<super>{1}",k0), a)
    ;原始
    this.mode1.mapkey(format("<super>{1}{2}",k0,"b"),,"分组b", 1)
    this.mode1.mapkey(format("<super>{1}{2}",k0,"bxy"),msgbox.bind("bxy"),"注释bxy", 2)
    this.mode1.mapkey(format("<super>{1}{2}",k0,"bxz"),msgbox.bind("bxz"),"注释bxz", 2)
    this.mode1.mapkey(format("<super>{1}{2}",k0,"byx"),msgbox.bind("byx"),"注释byx", 2)
    this.mode1.mapkey(format("<super>{1}{2}",k0,"bz"),msgbox.bind("bz"),"注释bz", 2)
}
*/

class vimd {
    static arrModeName := ["None","Vim"]
    ;static charSplit := "※" ;分隔各命令
    static winCurrent := "" ;记录当前的窗口，用来出错后 init
    static tipLevel := 15
    static tipLevel1 := 16 ;其他辅助显示
    static debugLevel := 0 ;用于方便地显示提示信息
    static groupKeymap := "groupString" ;分组的全局搜索时，objDo 的字段定义在 groupKeymap
    static groupGlobal := 0
    static groupKeyAll := "{F12}" ;NOTE 执行当前全部命令

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
        if (isset(cls))
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
        ;OutputDebug(format("i#{1} {2}:hideTips", A_LineFile,A_LineNumber))
        tooltip(,,, vimd.tipLevel)
    }

    static setDebugLevel() {
        vimd.debugLevel := !vimd.debugLevel
        status := vimd.debugLevel ? "显示" : "隐藏"
        tooltip(format("【{1}】调试信息", status))
        SetTimer(tooltip, -1000)
    }
    static hideTips1() => tooltip(,,, vimd.tipLevel1)
    static showTips1(str, x:=0, y:=0) => tooltip(str, x, y, vimd.tipLevel1) ;辅助显示，固定在某区域

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
            if (GetKeyState("CapsLock", "T")) { ;大小写转换
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
        if (!g.HotCriterion)
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
        arr := StrSplit(rtrim(fileread(fp),"`r`n"), "`n", "`r").map(v=>StrSplit(v,"\")[2])
        ;objInclude := StrSplit(rtrim(fileread(fp),"`r`n"), "`n", "`r").map(v=>)
        if (hyf_checkNewPlugin("d:\BB\plugins\vimd\vimdInclude.ahk", [["d:\BB\plugins\vimd", "wins"]], "vimd_")) {
            f := FileOpen(fp, "w", "utf-8-raw")
            strInclude := ""
            loop files, format("{1}\wins\*",A_LineFile.dir()), "D"
                strInclude .=  format("#include wins\{1}\vimd_{1}.ahk`n",A_LoopFileName)
            f.write(strInclude)
            f.close()
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
            this.arrHistory := [] ;记录所有已运行的命令
            this.lastAction := []
            ;this.modeList := map()
            this.currentMode := ""
            this.currentHotIfWin := ""
            ;目的：单键在同个 HotIfWinActive 下不要重复【定义】(【使用】记录的对象在 vimdModes 属性里记录)
            ;用任意模式【定义一次hotkey】即可(是否要特殊考虑第一个按键？)，能拦截到，后续由 keyIn 处理逻辑
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
            this.keyToMode0 := "``" ;如果设置为空，则永远是vim模式，比如在gvim里
            this.keyToMode1 := "{escape}" ;如果设置为空，则永远是mode0模式，只用<super>键功能
            this.keyDebug := "{F10}" ;用得较少 {F12}一般用在配置文件
            this.typeSuperVim := 0 ;1=只切换 2=切换并执行按键
            this.objKeySuperVim := map() ;记录超级按键，比 keySuperVim 多了个生效当前按键功能
        }

        ;初始化内置的模式(mode0|mode1)
        ;此方法由各插件调用(生成+map一并进行)
        ;默认的模式放最后定义，或者最后加上 win.changeMode(i)
        ;NOTE 必须先 initMode(0) 再 initMode(1)
        ;NOTE 必须先 setHotIf
        ;binMap(二进制理解) 0=none 1=count 2=repeat 3=both
        initMode(idx, binMap:=3, funOnBeforeKey:=false, modename:="") {
            if (this.currentHotIfWin == "")
                throw ValueError('request "setHotIf" done')
            ;mode0 未定义，则自动定义
            if (idx == 1 && this.arrMode.length == 0)
                this.initMode(0)
            this.currentMode := vimd.vimdModes(idx, this, modename) ;modename 用来修改内置模式名
            if (this.arrMode.length < idx+1)
                this.arrMode.push(this.currentMode)
            else
                this.arrMode[idx+1] := this.currentMode
            ;NOTE 在这里直接定义 initWin 时设置的 currentHotIfWin
            this.currentMode.mapDefault(binMap)
            if (funOnBeforeKey)
                this.currentMode.onBeforeKey := isobject(funOnBeforeKey) ? funOnBeforeKey : ObjBindMethod(this.currentMode,"beforeKey")
            return this.currentMode
        }

        getMode(i:=-1) {
            if (i == -1)
                return this.currentMode
            else
                return this.arrMode[i+1]
        }
        setMode(i) => this.currentMode := this.getMode(i)

        ;指定后面热键的窗口(大部分是针对ahk_class的)
        ;NOTE bAsHotIfWin 推荐 false
        ;   如果全为true，则会存在抢热键的情况，单个键只能在一个窗口生效，【先定义】的 HotIfWin 优先，所以要考虑兼容性问题
        ;   如果为 false，热键仍然生效，菜单仍会出现，可根据 objHotIfWins[winTitle] 的数组自由组合
        ;vimd.initWin 内容较多，这是纯净版
        setHotIf(winTitle, bAsHotIfWin:=true) {
            this.arrHotIfWin.push(winTitle)
            ;定义 vimdWins 的属性
            this.currentHotIfWin := winTitle
            this.objHotIfWin_SingleKey[this.currentHotIfWin] := map()
            if (bAsHotIfWin)
                HotIfWinActive(winTitle)
        }

        ;超级模式
        ;md 1=只切换 2=切换并执行按键
        ;TODO 热键由 mode0 接入，所有的代码属性都是 mode0 的，如何处理？
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
            if (bTooltip) {
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
        ;NOTE 模式不能自动识别的才需要
        setKeySuperVim(keySuperVim:="{RControl}") {
            ;标记此键
            this.keySuperVim := keySuperVim
            ;vimd 拦截此键，功能为切换到 super mode1(不判断 onBeforeKey，结束用 typeSuperVim 来全局判断)
            this.currentMode.mapkey(keySuperVim ,ObjBindMethod(this,"changeMode",1),"super mode1")
        }

        ;临时把 count 当值使用(默认是执行 count 次功能)
        ;方便插件调用
        setBreak(cntDefault:=1) {
            this.isBreak := true
            if (this.isRepeat)
                cnt := this.lastAction[2]
            else
                cnt := this.GetCount(cntDefault)
            OutputDebug(format("i#{1} {2}:setBreak cnt={3}", A_LineFile,A_LineNumber,cnt))
            return cnt
        }

        GetCount(cntDefault:=1) => this.count ? this.count : cntDefault ;执行时用(默认返回1，而用count属性默认为0)

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
        ;byScript 非手工按键，而是用脚本触发时，需要传入此参数，如 vimd_WeChat.win.keyIn("F3", "ahk_exe WeChat.exe")
        keyIn(ThisHotkey, byScript:=0) {
            keyMap := vimd.key_hot2map(ThisHotkey)
            ;OutputDebug(format("i#{1} {2}:A_ThisFunc={3}-------------------start", A_LineFile,A_LineNumber,A_ThisFunc))
            ;OutputDebug(format("currentMode.index={1}", this.currentMode.index))
            ;OutputDebug(format("arrKeymapPressed.length = {1}", this.currentMode.arrKeymapPressed.length))
            ;OutputDebug(format("keyMap={1}", keyMap))
            ;OutputDebug(format("typeSuperVim = {1}", this.typeSuperVim ))
            ;OutputDebug(format("objKeySuperVim={1}", json.stringify(this.objKeySuperVim)))
            ;OutputDebug(format("i#{1} {2}:A_ThisFunc={3}-------------------end", A_LineFile,A_LineNumber,A_ThisFunc))
            ;NOTE 记录当前的窗口，用来出错后 init
            vimd.winCurrent := this
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
            this.objTips := map() ;NOTE 大纲提示(可动态在命令里用 this.mode1.objTips[key] 来添加)
            this.objTips.CaseSense := true
            this.objFunDynamic := map() ;记录所有需要验证动态信息的按键(可以快速过滤无关按键)
            this.objFunDynamic.CaseSense := true
            ;NOTE objHotIfWin_xxx 对象，都先定义了 key1 = currentHotIfWin(为了支持子窗口)
            this.objKeysmap := map() ;{keysmap, objDo}
            this.objKeysmap.CaseSense := true
            ;每个key 后的value 都分normal|dynamic|group(若有)
            this.objFKey := map()
            ;先根据窗口区分执行，再通过第1个热键分隔
            ;this.objHotIfWins := map() ;记录当前子窗口的关联窗口名
            ;this.thisHotIfWin := "" ;以第一个键判断当前匹配窗口(解决窗口乱匹配，导致热键识别问题)
            ;NOTE 用 array 可以记录顺序
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
            this.arrDynamicTips := []
        }

        ;脚本运行过程出错，要先运行此命令退出，否则下次按键会因为 arrKeymapPressed 误判(往往使下一按键无效)
        ;NOTE 执行命令或中途退出才执行
        ;tp -1=执行前半段 0=全部执行 1=执行后半段
        init(tp:=0) {
            ;OutputDebug(format("i#{1} {2}:init tp={3} start", A_LineFile,A_LineNumber,tp))
            if (tp <= 0) { ;用于在do之前先初始化一部分
                this.arrKeymapPressed := [] ;记录每个按键
                this.arrDynamicTips := []
                vimd.groupGlobal := 0
                if (this.win.typeSuperVim)
                    this.win.exitSuperMode()
                vimd.hideTips1()
                vimd.hideTips()
            }
            if (tp >= 0) { ;影响执行逻辑的属性
                this.win.count := 0
                this.win.isRepeat := false
                this.win.isBreak := false
            }
        }

        ;NOTE 设置关联，适合复杂逻辑，否则用 setHotIf 即可
        ;TODO 尽量不用，用 setDynamics 来实现动态 <2023-03-24 18:56:52> hyaray
        setObjHotWin(winTitle, bAsHotIfWin:=true, arrWinTitle:=unset) {
            this.win.setHotIf(winTitle, bAsHotIfWin)
        }

        ;NOTE 这个只是方便调用，方法名格式为 dynamicF1
        setDynamics(arr, cls) {
            for key in arr {
                key1 := vimd.key_hot2map(key)
                this.setDynamic(format("<super>{{1}}", key), ObjBindMethod(cls,"dynamic" . key,key1))
            }
        }

        ;objFun 如果有true的返回值，则直接 init 结束
        setDynamic(key, objFun) {
            if instr(key, "<super>") {
                key := StrReplace(key, "<super>")
                this.win.objKeySuperVim[key] := 1
            }
            this.objFunDynamic[key] := objFun
            this._map(key) ;NOTE 定义的时候必须要确保 key 在拦截清单内
        }

        ;NOTE 被keyIn调用
        _keyIn(keyMap, byScript, checkSuper:=true) {
            ;第一个按键
            if (this.arrKeymapPressed.length == 0) {
                ;无视模式的按键
                if (keyMap == this.win.keySuperVim) { ;如 {RControl}
                    this.win.setSuperMode(1, true)
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} is keySuperVim", A_LineFile,A_LineNumber,A_ThisFunc))
                    exit
                } else if (checkSuper && this.win.objKeySuperVim.has(keyMap)) { ;<super>
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} {4} is <super>", A_LineFile,A_LineNumber,A_ThisFunc,keyMap))
                    this.win.setSuperMode(2)
                    this.win.currentMode._keyIn(keyMap, byScript, false) ;NOTE 以 mode1 运行
                    exit
                }
                ;NOTE 判断当前匹配窗口 update 用
                ;this.thisHotIfWin := (byScript==0) ? vimd.getHotIfWin() : this.win.arrHotIfWin[1] ;NOTE 不太准确，可能两个窗口都定义了此按键
                ;4. 判断 onBeforeKey
                if (this.win.typeSuperVim==0 && isobject(this.onBeforeKey)) { ;NOTE typeSuperVim 则不执行 onBeforeKey
                    if (this.onBeforeKey.call(keyMap) == 0) { ;返回 false，则相当于 None 模式
                        if (vimd.debugLevel > 0)
                            OutputDebug(format("i#{1} {2}:{3} keyMap={4} onBeforeKey false", A_LineFile,A_LineNumber,A_ThisFunc,keyMap))
                        send(vimd.key_map2send(keyMap))
                        exit
                    }
                }
                if (this.win.typeSuperVim == 2) ;<super>键显示保存的模式名
                    this.addTipsDynamic(this.win.modeBeforeSuper.name)
                ;自动运行 objFunDynamic()
                if (this.HasOwnProp("objFunDynamic") && this.objFunDynamic.has(keyMap)) {
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} {4}.objFunDynamic({5})", A_LineFile,A_LineNumber,A_ThisFunc,this.name,keyMap))
                    if (this.objFKey.has(keyMap))
                        this.objFKey[keyMap]["dynamic"] := [] ;NOTE 每次都要清空
                    if (this.objFunDynamic[keyMap]()) { ;TODO 特意有返回值的，表示已执行完动作，直接结束 <2023-01-20 22:25:39> hyaray
                        this.init()
                        exit
                    }
                } else {
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} 键没有动态", A_LineFile,A_LineNumber,keyMap))
                }
                ;非常规功能
                if (this.objKeysmap.has(keyMap)) { ;单键功能
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:this.objKeysmap.has({3}) comment={4}", A_LineFile,A_LineNumber,keyMap,this.objKeysmap[keyMap]["comment"]))
                    if (keyMap ~= "^\d$") {
                        this.dealCount(integer(keyMap)) ;因为要传入参数，所以单独处理
                    } else if (keyMap == "{BackSpace}") {
                        this.doGlobal_BackSpace() ;因为无需 init，所以单独处理
                    } else if (keyMap == ".") {
                        this.init(-1)
                        this.doGlobal_Repeat() ;一般是 do(objDo["action"], this.win.GetCount())，repeat 刚好相反
                        this.init(1)
                    } else {
                        this.init(-1)
                        this.do(this.objKeysmap[keyMap]["action"], this.win.GetCount(), this.objKeysmap[keyMap]["comment"])
                        this.init(1)
                    }
                    exit
                } else {
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("d#{1} {2}:this.objKeysmap.not has({3}) index={4}", A_LineFile,A_LineNumber,keyMap,this.index))
                    if (this.index == 0) {
                        send(vimd.key_map2send(keyMap))
                    } else {
                        this.update(keyMap)
                    }
                }
            } else {
                this.update(keyMap)
            }
        }

        ;更新当前匹配的命令并 showTips
        ;先修改arrKeymapPressed再运行
        update(keyMap) {
            ;OutputDebug(format("i#{1} {2}:{3} keyMap={4}", A_LineFile,A_LineNumber,A_ThisFunc,keyMap))
            if (keyMap == "{BackSpace}") {
                if (!this.setArrKeymapPressed().length) {
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} no key", A_LineFile,A_LineNumber,A_ThisFunc))
                    this.init()
                    return
                } else if (this.objFKey[this.arrKeymapPressed[1]].has("group")) { 
                    if (this.arrKeymapPressed.length == 1) { ;分组会提示 按0执行全部功能
                        vimd.groupGlobal := 0 ;NOTE 切换回普通状态
                        this.addTipsDynamic()
                    }
                }
            } else if (keyMap == "{escape}") {
                this.init()
                return
            } else {
                this.setArrKeymapPressed(keyMap)
            }
            if (vimd.debugLevel > 0)
                OutputDebug(format("i#{1} {2}:{3} this.arrKeymapPressed={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(this.arrKeymapPressed,4)))
            ;NOTE 核心：获取匹配项
            arrMatch := getMatchAction()
            ;处理逻辑
            switch arrMatch.length {
                case 0: ;没找到命令
                    if (this.arrKeymapPressed.length == 1) { ;为第1个按键
                        if (vimd.debugLevel > 0)
                            OutputDebug(format("i#{1} {2}:{3} send({4})", A_LineFile,A_LineNumber,A_ThisFunc,this.arrKeymapPressed[1]))
                        send(this.arrKeymapPressed[1])
                        this.init()
                    } else if (keyMap ~= "^[1-9]$") { ;NOTE 按了不存在的数字键，当序号使用 <2023-01-20 23:34:18> hyaray
                        this.setArrKeymapPressed()
                        ;重新获取匹配命令
                        i := integer(keyMap)
                        arrMatch := getMatchAction()
                        if (i <= arrMatch.length) {
                            this.init(-1)
                            this.do(arrMatch[i]["action"], this.win.GetCount(), arrMatch[i]["comment"])
                            this.init(1)
                        }
                    } else { ;TODO 按错了，忽略
                        this.setArrKeymapPressed()
                    }
                case 1: ;单个结果
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} 1 matched={4}", A_LineFile,A_LineNumber,A_ThisFunc,arrMatch[1]["comment"]))
                    this.init(-1)
                    this.do(arrMatch[1]["action"], this.win.GetCount(), arrMatch[1]["comment"])
                    this.init(1)
                default: ;大部分情况
                    this.showTips(arrMatch)
            }
            ;所有匹配热键(dynamic+normal)
            getMatchAction() {
                ;按键未定义功能
                if (!this.objFKey.has(this.arrKeymapPressed[1])) {
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} first key not matched", A_LineFile,A_LineNumber,A_ThisFunc))
                    return []
                }
                ;常规情况
                if (!this.objFKey[this.arrKeymapPressed[1]].has("group")) {
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("i#{1} {2}:{3} first key no group", A_LineFile,A_LineNumber,A_ThisFunc))
                    return _matchAction()
                }
                ;NOTE group 情况
                switch this.arrKeymapPressed.length {
                    case 1: ;首个按键，只显示分组功能
                        ;arrMatch := _matchAction((objDo)=>(objDo["groupLevel"]==1))
                        arrMatch := _matchAction(1)
                        if (arrMatch.length == 1) { ;只有1组，则直接展开下级
                            if (vimd.debugLevel > 0)
                                OutputDebug(format("i#{1} {2}:{3} only 1 group, groupGlobal", A_LineFile,A_LineNumber,A_ThisFunc))
                            groupLoadGlobal()
                            this.addTipsDynamic(format("按{1}执行全部功能", vimd.groupKeyAll))
                        }
                    case 2: ;第2按键
                        if (vimd.groupGlobal) { ;已经展开了全局
                            groupLoadGlobal()
                        } else {
                            groupLoadAndCheck()
                        }
                    default: ;3-n个按键
                        if (vimd.groupGlobal) { ;直接全局搜子节点
                            arrMatch := _matchAction(2, vimd.groupKeymap)
                        } else { ;仍然分组搜索
                            OutputDebug(format("i#{1} {2}:{3} group", A_LineFile,A_LineNumber,A_ThisFunc))
                            arrMatch := _matchAction()
                            groupDoAll()
                        }
                }
                return arrMatch
                groupLoadAndCheck() { ;加载分组，如果不存在，则加载所有子节点
                    vimd.groupGlobal := 0
                    arrMatch := _matchAction(2)
                    if (!arrMatch.length) { ;TODO 找不到，搜索全部分组下的节点
                        if (vimd.debugLevel > 0)
                            OutputDebug(format("i#{1} {2}:{3} group not matched", A_LineFile,A_LineNumber,A_ThisFunc))
                        groupLoadGlobal()
                    } else {
                        this.addTipsDynamic(format("按{1}执行全部功能", vimd.groupKeyAll))
                    }
                }
                groupLoadGlobal() { ;跳过分组，直接加载全局命令
                    vimd.groupGlobal := 1
                    arrMatch := _matchAction(2, vimd.groupKeymap)
                    if (!arrMatch.length)
                        groupDoAll()
                }
                groupDoAll() { ;判断是否按键执行分组下所有命令
                    if (this.arrKeymapPressed[-1] == vimd.groupKeyAll) {
                        this.setArrKeymapPressed()
                        arrMatch := _matchAction(2)
                        for objDo in arrMatch
                            this.do(objDo["action"], this.win.GetCount())
                        this.init()
                        exit
                    }
                }
                ;NOTE 分组情况下，如果全局搜子节点，会删除分组的热键(场景：不知道在哪个全组，所以才全局搜索)
                _matchAction(groupLevel:=0, key:="string") {
                    arrTmp := []
                    for tp in ["dynamic", "normal"] {
                        if (!this.objFKey[this.arrKeymapPressed[1]].has(tp))
                            continue
                        for objDo in this.objFKey[this.arrKeymapPressed[1]][tp] {
                            if (key == vimd.groupKeymap && !objDo.has(key))
                                continue
                            if (instr(objDo[key],this.sKeymapPressed,true) == 1) { ;NOTE 匹配大小写
                                if (groupLevel) {
                                    if (objDo["groupLevel"] == groupLevel)
                                        arrTmp.push(objDo)
                                } else {
                                    arrTmp.push(objDo)
                                }
                            }
                        }
                    }
                    ;if (vimd.debugLevel > 0)
                    ;    OutputDebug(format("i#{1} {2}:{3} arrMatch={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(arrTmp,4)))
                    return arrTmp
                }
            }
        }

        dealCount(keyMap) {
            if (keyMap == "{BackSpace}") {
                if (this.win.count > 9) { ;两位数
                    this.win.count := this.win.count//10
                    OutputDebug(format("i#{1} {2}:this.win.count={3}", A_LineFile,A_LineNumber,this.win.count))
                } else {
                    this.init()
                    return
                }
            } else {
                this.win.count := this.win.count ? this.win.count*10+integer(keyMap) : integer(keyMap)
            }
            this._show(string(this.win.count))
        }

        ;NOTE 会同时更新 this.sKeymapPressed
        setArrKeymapPressed(k:="") {
            (k == "") ? this.arrKeymapPressed.pop() : this.arrKeymapPressed.push(k)
            this.sKeymapPressed := "".join(this.arrKeymapPressed) ;TODO 是否直接修改
            return this.arrKeymapPressed
        }

        ;-----------------------------------maps-----------------------------------

        ;objDo 来源于 key_map2arrHot
        ;公共 map
        mapDefault(binMap) {
            if (this.index == 0) { ;mode0
                if (this.win.keyToMode1 != "")
                    this.mapkey(this.win.keyToMode1,ObjBindMethod(this,"doGlobal_Escape"),"进入 mode1")
            } else if (this.index == 1) { ;mode1
                this.mapkey("{escape}",ObjBindMethod(this,"doGlobal_Escape"),"escape")
                this.mapkey("{BackSpace}",ObjBindMethod(this,"doGlobal_BackSpace"),"BackSpace")
                ;由于这次模式还没生成，如果这两个键定义在 win 的属性
                if (this.win.keyToMode0 != "")
                    this.mapkey(this.win.keyToMode0,ObjBindMethod(this.win,"changeMode",0),"进入 mode0")
                ;NOTE 定义debug的内置功能，自带 <super> 参数
                keymapDebug := format("<super>{1}", this.win.keyDebug)
                this.mapkey(keymapDebug . keymapDebug,ObjBindMethod(this,"doGlobal_Edit"),"【编辑】vimd_" . this.win.name)
                this.mapkey(keymapDebug . "d",ObjBindMethod(vimd,"setDebugLevel"),"显示/隐藏调试信息")
                this.mapkey(keymapDebug . "{F9}",ObjBindMethod(this,"doGlobal_objFKey"),"查看所有功能(按首键分组)objFKey")
                this.mapkey(keymapDebug . "]",ObjBindMethod(this,"doGlobal_objKeysmap"),"查看所有功能(按keymap分组)objKeysmap")
                this.mapkey(keymapDebug . "-",ObjBindMethod(this,"doGlobal_Debug_objSingleKey"),"查看所有拦截的按键 objHotIfWin_SingleKey")
                this.mapkey(keymapDebug . "|",ObjBindMethod(this,"doGlobal_Debug_objKeySuperVim"),"查看所有的<super>键 objKeySuperVim")
                this.mapkey(keymapDebug . "\",ObjBindMethod(this,"doGlobal_Debug_objFunDynamic"),"查看所有的<super>键 objFunDynamic")
                this.mapkey(keymapDebug . "/",ObjBindMethod(this,"doGlobal_Debug_arrHistory"),"查看运行历史 arrHistory")
                n := 0 ;二进制的位数(从右开始)
                if ((binMap & 2**n) >> n) ;也可以用 "10" 这种字符串来判断
                    this.mapCount()
                n++
                if ((binMap & 2**n) >> n)
                    this.mapkey("." ,"","重做")
            }
        }
        mapCount() {
            loop(10)
                this.mapkey(string(A_Index-1),"",format("<{1}>", A_Index-1))
        }

        ;显性为分组做准备，否则每次 mapkey 都要判断是否已完成
        setGroup(k0, val:=true) {
            if (this.objFKey.has(k0))
                this.objFKey[k0]["group"] := val
            else
                this.objFKey[k0] := map("group", val)
        }

        ;keysmap类型 <^enter> {F1} + A
        mapkey(keysmap, funcObj:=unset, comment:=unset, groupLevel:=0) {
            objDo := this._map(keysmap, funcObj?, comment?, groupLevel, "normal")
        }
        mapDynamic(keysmap, funcObj:=unset, comment:=unset, groupLevel:=0) {
            objDo := this._map(keysmap, funcObj?, "*" . comment, groupLevel, "dynamic") ;动态功能，前面加 *
        }
        ;arr2 格式
        ; [
        ;   [groupName, groupHot], ;第1项为分组
        ;   [
        ;       [item1Name, item1Hot],
        ;       [item2Name, item2Hot],
        ;   ]
        ;]
        mapGroup(hotBefore, arr2) {
            groupName := format("【{1}】", arr2[1][1])
            if (arr2[2].length == 1) { ;只有1项子元素，则直接显示到分组上
                switch arr2[2][1].length {
                    case 1, 2:
                        groupName .= "--" . arr2[2][1][1]
                    default:
                        groupName .= "--" . arr2[2][1][3]
                }
            }
            this.mapDynamic(hotBefore . arr2[1][2],, groupName, 1)
            for arrTmp in arr2[2] {
                hot := hotBefore . arr2[1][2]
                switch arrTmp.length {
                    case 1:
                        name := arrTmp[1]
                        hot .= string(A_Index) ;默认序号
                    case 2:
                        name := arrTmp[1]
                        hot .= arrTmp[2]
                    default:
                        name := arrTmp[3]
                        hot .= (arrTmp[2]=="") ? string(A_Index) : arrTmp[2]
                }
                this.mapDynamic(hot, ((x)=>_U9Web().searchPage(x)).bind(arrTmp[1]), name, 2)
            }
        }
        ;把定义打包为 objDo
        ;如果 funcObj 在 keyIn 里明确了逻辑，则这里随便定义都行，比如 mapCount
        ;NOTE 在 setDynamic 只传入第1个参数，为了拦截热键而已
        ;groupLevel 0=普通 1=分组 2=功能
        _map(keysmap, funcObj:=unset, comment:=unset, groupLevel:=0, tp:="normal") {
            objDo := this.key_map2arrHot(keysmap, groupLevel)
            if (isset(comment)) {
                if (isset(funcObj))
                    objDo["action"] := funcObj
                objDo["comment"] := comment
                objDo["hotwin"] := this.win.currentHotIfWin
                objDo["groupLevel"] := groupLevel
                if (!this.objFKey.has(objDo["keyMapFirst"]))
                    this.objFKey[objDo["keyMapFirst"]] := map(tp,[objDo])
                else if (!this.objFKey[objDo["keyMapFirst"]].has(tp))
                    this.objFKey[objDo["keyMapFirst"]][tp] := [objDo]
                else
                    this.objFKey[objDo["keyMapFirst"]][tp].push(objDo)
                this.objKeysmap[objDo["string"]] := objDo
                ;if (this.win.name = "notepad" && objDo["keyMapFirst"] = "{F9}")
                ;    msgbox(json.stringify(objDo, 4))
            }
            for key in objDo["arrkey"] {
                if (A_Index == 1 && objDo["super"]) ;记录超级键
                    this.win.objKeySuperVim[vimd.key_hot2map(key)] := 1
                if (!this.win.objHotIfWin_SingleKey[this.win.currentHotIfWin].has(key)) { ;单键避免重复定义
                    hotkey(key, ObjBindMethod(this.win,"keyIn")) ;NOTE 相关的键全部拦截，用 vimd 控制
                    this.win.objHotIfWin_SingleKey[this.win.currentHotIfWin][key] := 1
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
        ;返回 objDo 的初步结果，后续由 _map 完善
        ;["arrkey"] := []
        ;["keyMapFirst"] := [] ;第1个按键
        ;["string"] := "" ;按键字符串
        ;["hotwin"] := "" ;NOTE 记录按键当前的窗口，实际上因为按键冲突，没用
        ;["action"] := ""
        ;["comment"] := ""
        ;["super"] := super ;热键永远 on(无视模式)，直接用 hotkey()定义即可
        key_map2arrHot(keysmap, groupLevel) {
            ;keysmap := RegExReplace(RegExReplace(RegExReplace(keysmap, "i)<super>", "", &super), "i)<noWait>", "", &noWait), "i)<noMulti>", "", &noMulti)
            keysmap := RegExReplace(keysmap, "i)<super>", "", &isSuper)
            objDo := map(
                "arrkey", [], ;hotkey命令用
                "super", isSuper,
                "string", keysmap,
            )
            if (groupLevel > 1)
                objDo[vimd.groupKeymap] := "" ;删除分组热键(第2个按键)
            ;msgbox(json.stringify(objDo, 4))
            while(keysmap != "") {
                ;优先提取<>组合键，<^a>
                if (RegExMatch(keysmap, "^<.+?>", &m)) {
                    thisKey := substr(keysmap, 2, m.Len(0)-2) ;^a
                    keysmap := substr(keysmap, m.Len(0)+1)
                    if (A_Index == 1)
                        objDo["keyMapFirst"] := m[0]
                } else if (RegExMatch(keysmap, "^\{.+?\}", &m)) { ;{F1}
                    thisKey := substr(keysmap, 2, m.Len(0)-2) ;F1
                    keysmap := substr(keysmap, m.Len(0)+1)
                    if (A_Index == 1)
                        objDo["keyMapFirst"] := m[0]
                } else {
                    thisKey := substr(keysmap, 1, 1)
                    keysmap := substr(keysmap, 2)
                    if (A_Index == 1)
                        objDo["keyMapFirst"] := thisKey
                }
                ;添加 groupString
                if (groupLevel > 1 && A_Index != 2)
                    objDo[vimd.groupKeymap] .= vimd.key_hot2map(thisKey)
                ;二次处理
                if (thiskey == " ")
                    thisKey := "space"
                else if (thisKey ~= "^[A-Z]$") ;大写字母单个大写字母转成 +a
                    thisKey := "+" . StrLower(thisKey)
                objDo["arrkey"].push(thisKey)
            }
            ;if (groupLevel > 1)
            ;    msgbox(json.stringify(objDo, 4))
            return objDo
        }

        ;getmap(sKey) {
        ;}

        ;-----------------------------------do__-----------------------------------
        beforeKey(p*) => !CaretGetPos() ;有些软件要用 UIA.GetFocusedElement().CurrentControlType != UIA.ControlType.Edit

        ;doSend(key) {
        ;    if GetKeyState("CapsLock")
        ;        send(format("{shift down}{1}{shift up}", key))
        ;    else
        ;        send(key)
        ;}

        ;最终执行的命令
        ;因为 doGlobal_Repeat 调用，所以把 cnt 放参数
        ;为什么第一个参数不用 objDo
        do(varDo, cnt, comment:=unset) {
            ;处理 repeat 和 count
            if (!this.win.isRepeat) {
                this.win.lastAction := [varDo, cnt, comment?] ;this.sKeymapPressed
                this.win.arrHistory.push(this.win.lastAction)
            }
            ;timeSave := A_TickCount
            if (vimd.debugLevel > 0)
                OutputDebug(format("d#{1} {2}:{3} count={4}", A_LineFile,A_LineNumber,A_ThisFunc,cnt))
            ;NOTE 运行
            loop(cnt) {
                this.callFunc(varDo, true)
                if (this.win.isBreak) { ;运行后才知道是否 isBreak
                    if (vimd.debugLevel > 0)
                        OutputDebug(format("d#{1} {2}:break", A_LineFile,A_LineNumber))
                    break
                }
            }
            ;tooltip(A_TickCount - timeSave,,, 9)
            ;SetTimer(tooltip.bind(,,, 9), -1000)
            if (isobject(this.onAfterDo))
                this.callFunc(this.onAfterDo)
        }

        ;NOTE 这里不能初始化 isBreak
        ;网址没在内
        callFunc(funcObj, errExit:=false) {
            if !(funcObj is string) {
                funcObj()
                return true
            }
            try {
                if (type(%funcObj%).isFunc()) {
                    %funcObj%()
                    return true
                }
            }
            if !(funcObj ~= "i)^[a-z]:[\\/]") {
                if (funcObj ~= "^\w+\(\S*\)$") { ;运行function()
                    arr := StrSplit(substr(funcObj, 1, strlen(funcObj)-1), "(")
                    (arr[2]=="") ? %arr[1]%() : %arr[1]%(arr[2])
                    return true
                } else if (funcObj ~= "^(\w+)\.(\w+)\((.*)\)$") { ;NOTE 运行 class.method(param1)
                    RegExMatch(funcObj, "^(\w+)\.(\w+)\((.*)\)$", &m)
                    (m[3] != "") ?  %m[1]%.%m[2]%(m[3]) : %m[1]%.%m[2]%()
                    return true
                }
                if (funcObj ~= '^\{\w{8}(-\w{4}){3}-\w{12}\}$') { ;clsid
                    funcObj := "explorer.exe shell:::" . funcObj
                } else if (funcObj ~= '^\w+\.cpl(,@?\d?)*$') { ;cpl
                    funcObj := "control.exe " . funcObj
                    ;} else if (substr(funcObj,1,12) == "ms-settings:") {
                    ;    funcObj := funcObj
                    ;} else if (funcObj ~= 'i)^control(\.exe)?\s+\w+\.cpl$') {
                    ;    funcObj := funcObj
                }
                tooltip(funcObj)
                run(funcObj)
                SetTimer(tooltip, -1000)
                return true
            }
            if (errExit)
                exit
            else
                throw OSError("action not find")
        }

        ;TODO 是否设置全局，这样出提示后，在其他未定义软件界面按键也能退出
        doGlobal_Escape() {
            OutputDebug(format("d#{1} {2}:A_ThisFunc={3} index={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.index))
            if (this.index == 0) {
                if (this.HasOwnProp("funCheckEscape") && this.funCheckEscape.call()) {
                    OutputDebug(format("d#{1} {2}:funCheckEscape=true", A_LineFile,A_LineNumber))
                    send("{escape}")
                } else {
                    OutputDebug(format("d#{1} {2}:to mode1", A_LineFile,A_LineNumber))
                    this.win.changeMode(1)
                }
            ;} else if (this.index > 0 && this.win.arrMode.length > 2) { ;TODO 更多模式，还是热键兼容问题
            ;    n := this.index + 1
            ;    if (n == this.win.arrMode.length)
            ;        n := 1
            ;    this.win.changeMode(n)
            } else if (!this.arrKeymapPressed.length && !this.win.count) {
                send("{escape}")
            } else {
                OutputDebug(format("i#{1} {2}: isBreak", A_LineFile,A_LineNumber))
                this.win.isBreak := true
            }
        }

        ;删除最后一个字符
        doGlobal_BackSpace() {
            this.win.isBreak := true
            if (this.arrKeymapPressed.length) {
                OutputDebug(format("i#{1} {2}:update", A_LineFile,A_LineNumber))
                this.update()
            } else if (this.win.count) {
                OutputDebug(format("i#{1} {2}:dealCount", A_LineFile,A_LineNumber))
                this.dealCount("{BackSpace}")
            } else {
                send("{BackSpace}")
            }
        }
        doGlobal_Edit() {
            SplitPath(A_LineFile,, &dn)
            if (this.win.HasOwnProp("cls") && this.win.cls.HasOwnProp("getTitleEx")) {
                title := this.win.cls.getTitleEx()
                hyf_runByVim(format("{1}\wins\{2}\vimd_{2}.ahk",dn,this.win.name), title)
                OutputDebug(format("i#{1} {2}:title={3}", A_LineFile,A_LineNumber,title))
            } else {
                hyf_runByVim(format("{1}\wins\{2}\vimd_{2}.ahk",dn,this.win.name))
                OutputDebug(format("i#{1} {2}", A_LineFile,A_LineNumber))
            }
        }
        doGlobal_Repeat() {
            this.win.isRepeat := true
            if (this.win.count)
                this.win.lastAction[2] := this.win.GetCount() ;覆盖 lastAction 的count
            OutputDebug(format("i#{1} {2}:do repeat={3} cnt={4}", A_LineFile,A_LineNumber,this.win.lastAction[3],this.win.lastAction[2]))
            this.do(this.win.lastAction*)
            this.win.isRepeat := false
        }
        doGlobal_Up() => send("{up}")
        doGlobal_Down() => send("{down}")
        doGlobal_Left() => send("{left}")
        doGlobal_Right() => send("{right}")
        doGlobal_objKeysmap() {
            ;msgbox(this.name . "`n" . this.index)
            res := ""
            for keymap, objDo in this.objKeysmap
                res .= format("{1}`t{2}`t{3}`t{4}`n", keymap,objDo["hotwin"],objDo["string"],objDo["comment"])
            msgbox(res,,0x40000)
        }
        doGlobal_objFKey(key:="") {
            arr2 := []
            ;尝试获取key
            if (key == "") {
                oInput := inputbox("首键")
                if (oInput.result!="Cancel" && oInput.value != "")
                    key := oInput.value
            }
            if (key == "") {
                for _, obj in this.objFKey
                    getStr(obj, _)
            } else {
                getStr(this.objFKey[key], key)
            }
            hyf_GuiListView(arr2, ["标题","类型","首键","所有键","描述","其他"])
            getStr(obj, k0:="") {
                for tp in ["dynamic", "normal"] {
                    if (!obj.has(tp))
                        continue
                    for objDo in obj[tp] {
                        ;if (k0 == "")
                        ;    res .= format("{1}`t{2}`t{3}`t{4}`n", objDo["hotwin"],keysmap,objDo["string"],objDo["comment"])
                        ;else
                        arr2.push([objDo["hotwin"],tp,k0,objDo["string"],objDo["comment"]])
                        if (objDo["groupLevel"])
                            arr2[-1].push(objDo.get(vimd.groupKeymap, "group"))
                    }
                }
            }
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
        doGlobal_Debug_objFunDynamic() {
            res := ""
            for k, arr in this.objFunDynamic
                res .= format("{1}`n", k)
            msgbox(res,,0x40000)
        }
        doGlobal_Debug_arrHistory() {
            res := ""
            for arr in this.win.arrHistory
                res .= format("{1}, {2}`n", arr[3], arr[2])
            msgbox(res,,0x40000)
        }

        ;-----------------------------------tip-----------------------------------

        ;添加动态提示内容
        addTipsDynamic(str:="") {
            if (str == "") {
                if (this.arrDynamicTips.length)
                    this.arrDynamicTips.pop()
            } else {
                if (!this.arrDynamicTips.length) 
                    this.arrDynamicTips.push(str)
                else if (this.arrDynamicTips[-1] != str) ;如果按 BackSpace 会造成重复添加
                    this.arrDynamicTips.push(str)
            }
        }

        showTips(arrMatch) {
            if (vimd.debugLevel > 0)
                OutputDebug(format("i#{1} {2}:{3} this.sKeymapPressed={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.sKeymapPressed))
            strTooltip := this.objTips.has(this.sKeymapPressed)
                ? format("{1}`t{2}", this.sKeymapPressed,this.objTips[this.sKeymapPressed])
                : this.sKeymapPressed
            for s in this.arrDynamicTips
                strTooltip .= "`t" . s ;NOTE 添加动态信息
            strTooltip .= "`n=====================`n"
            key := vimd.groupGlobal ? vimd.groupKeymap : "string"
            for objDo in arrMatch
                strTooltip .= format("{1}`t{2}`n", objDo[key],objDo["comment"])
            this._show(strTooltip)
        }

        ;NOTE
        _show(str) {
            ;OutputDebug(format("i#{1} {2}:isobject={3} _show str={4}", A_LineFile,A_LineNumber,isobject(this.win.funTipsCoordinate),str))
            if (isobject(this.win.funTipsCoordinate)) {
                cmToolTip := A_CoordModeToolTip
                CoordMode("ToolTip", "window") ;强制为 window 模式
                arrXY := this.win.funTipsCoordinate.call()
                ;OutputDebug(format("i#{1} {2}:arrXY={3}", A_LineFile,A_LineNumber,json.stringify(arrXY)))
                tooltip(str, arrXY[1], arrXY[2], vimd.tipLevel)
                ;OutputDebug(format("i#{1} {2}:after tooltip", A_LineFile,A_LineNumber))
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

