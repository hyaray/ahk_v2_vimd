;说明：
;内置两个模式 mode0(原生) 和 mode1(vimd功能)，名称定义在 arrModeName
;默认按键 map 见 mapDefault
;按 ` 从 mode1→mode0
;按 escape 从 mode0→mode1(可能需要优先执行原生的escape功能,见 funCheckEscape)
;按键格式切换
;   keyIn 里，keyMap := vimd.key_hot2map(ThisHotkey) 主要逻辑都用 keyMap 处理
;插件配制：见 wins\Notepad\VimD_Notepad.ahk
;NOTE 脚本出错后务必运行 vimd.errorDo()，取消注释末尾的 OnError

class vimd {
    static arrModeName := ["None","Vim"]
    ;static charSplit := "※" ;分隔各命令
    static winCurrent := "" ;记录当前的窗口，用来出错后 init
    static tipLevel := 15
    static tipLevel1 := 16 ;其他辅助显示

    static __new() {
        ;OutputDebug(A_ThisFunc)
        this.objWin := map() ;在 setWin里设置
        ;HotIfWinActive ;TODO 关闭
    }

    ;NOTE 核心，由各插件自行调用
    ;TODO 这里把命令分类了，但 objByFirstKey 无法识别
    static setWin(winName, winTitle, cls:="") {
        ;msgbox(winName . "`n" . json.stringify(this.objWin, 4))
        if !this.objWin.has(winName)
            this.objWin[winName] := this.vimdWins(winName)
        win := this.objWin[winName]
        if (winTitle == "")
            throw ValueError("setWin mush set winTitle")
        win.setHotkeyWin(winTitle)
        if (cls != "")
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

    static showTips1(str, x:=0, y:=0) { ;辅助显示，固定在某区域
        tooltip(str, x, y, this.tipLevel1)
    }
    static hideTips1() {
        tooltip(,,, this.tipLevel1)
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
        "<Enter>","Enter", "<Esc>","Escape", "<BS>","Backspace",
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
    ;   space --> {space}
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
            keyMap := format("{{1}}", keyMap)
            ;keyMap := (ThisHotkey=="space") ? A_Space : format("{{1}}", ThisHotkey)
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
            keyMap := format("{{1}}", keyMap)
        return keyMap
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
            ;this.modeList := map()
            this.currentMode := ""
            this.hotwin := ""
            this.objSingleKey := map() ;以 this.hotwin 为key1，单键为key2, 记录所有拦截的按键(ThisHotkey)
            this.objSingleKey.CaseSense := true
            ;其他属性
            this.count := 0
            this.isBreak := false ;无视count
            this.isRepeat := false
            this.arrXYTips := [] ;显示 tooltip 的坐标
            ;event(部分事件在 vimdWins 部分事件在 vimdModes)
            this.onBeforeChangeMode := ""
            this.onAfterChangeMode := ""
            ;this.onBeforeMap := ""
            ;this.onAfterMap := ""
            this.onBeforeShowTip := ""
            this.onBeforeHideTip := ""
            ;搭配 keySuperVim 使用
            this.keySuperVim := ""
            this.typeSuperVim := 0 ;1=只切换 2=切换并执行按键
            this.objKeySuperVim := map() ;记录超级按键，比 keySuperVim 多了个生效当前按键功能
        }

        ;初始化内置的模式(mode0|mode1)
        ;此方法由各插件调用(生成+map一并进行)
        ;默认的模式放最后定义，或者最后加上 win.changeMode(i)
        ;NOTE 必须先 initMode(0) 再 initMode(1)
        ;NOTE 必须先 setHotkeyWin
        initMode(idx, bCount:=true, funOnBeforeKey:=false, modename:="") {
            if (this.hotwin == "")
                throw ValueError('request "setHotkeyWin" done')
            ;mode0 未定义，则自动定义
            if (idx == 1 && this.arrMode.length == 0)
                this.initMode(0)
            this.currentMode := vimd.vimdModes(idx, this, modename)
            if (this.arrMode.length < idx+1)
                this.arrMode.push(this.currentMode)
            else
                this.arrMode[idx] := this.currentMode
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

        ;超级模式
        ;md 1=只切换 2=切换并执行按键
        setSuperMode(md:=1, bTooltip:=false) {
            if bTooltip {
                tooltip("super " . vimd.arrModeName[2])
                SetTimer(tooltip, -1000)
            }
            this.typeSuperVim := md
            ;记录之前的模式，后续恢复用
            this.modeBeforeSuper := this.currentMode
            this.currentMode := this.getMode(1)
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

        ;指定后面热键的窗口(大部分是针对ahk_class的)
        setHotkeyWin(winTitle) {
            ;智能处理winTitle
            ;if !strlen(winTitle)
            ;    winTitle := format("ahk_exe {1}.exe", this.name)
            HotIfWinActive(winTitle)
            this.hotwin := winTitle ;NOTE 做个标记未设置
            this.objSingleKey[this.hotwin] := map()
        }

        ;NOTE 至少需要初始化一个模式
        setKeySuperVim(keySuperVim:="{RControl}") {
            ;标记此键
            this.keySuperVim := keySuperVim
            ;vimd 拦截此键，功能为切换到 super mode1(不判断 onBeforeKey，结束用 typeSuperVim 来全局判断)
            ;用任意模式定义一次按键即可，能拦截到，后续由 keyIn 处理逻辑
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
        ;后续细节转到 vimdModes.deal() 处理
        keyIn(ThisHotkey) {
            keyMap := vimd.key_hot2map(ThisHotkey)
            ;OutputDebug(ThisHotkey . " " . keyMap)
            ;NOTE 记录当前的窗口，用来出错后 init
            vimd.winCurrent := this
            ;1. 判断 keySuperVim
            if (!this.currentMode.arrKeyMap.length && keyMap == this.keySuperVim) {
                this.setSuperMode(1, true)
                exit
            }
            ;OutputDebug(format("arrKeyMap.length={1} keyMap={2} objKeySuperVim={3}", this.currentMode.arrKeyMap.length,keyMap,json.stringify(this.objKeySuperVim)))
            if (!this.currentMode.arrKeyMap.length && this.objKeySuperVim.has(keyMap)) {
                ;OutputDebug(format("objKeySuperVim.has({1})", keyMap))
                this.setSuperMode(2)
            } else {
                ;2. 判断 onBeforeKey
                if (!this.typeSuperVim && this.currentMode.onBeforeKey) { ;TODO typeSuperVim 则不执行 onBeforeKey
                    if (!this.currentMode.onBeforeKey.call(keyMap)) { ;返回 false，则相当于 None 模式
                        ;OutputDebug("onBeforeKey false")
                        send(vimd.key_map2send(keyMap))
                        exit
                    } else {
                        ;OutputDebug("onBeforeKey true")
                    }
                }
                ;3. 第1个按键
                if (!this.currentMode.arrKeyMap.length) {
                    ;OutputDebug("first 3")
                    ;NOTE 特殊键
                    if (this.currentMode.index == 0) {
                        ;OutputDebug("mode 0")
                        if (keyMap == "{escape}") { ;原始{escape}优先还是切换模式到Vim？
                            if (this.currentMode.HasOwnProp("funCheckEscape") && this.currentMode.funCheckEscape.call()) {
                                send("{escape}")
                                exit
                            }
                        }
                    }
                    ;NOTE NOTE NOTE 自动运行 objDynamic()
                    if (this.currentMode.HasOwnProp("objDynamic") && this.currentMode.objDynamic.has(keyMap)) {
                        ;OutputDebug(format("{1}.objDynamic({2})", this.currentMode.name,keyMap))
                        this.currentMode.arrListDynamic := []
                        this.currentMode.objDynamic[keyMap].call()
                        ;OutputDebug(format("{1}.arrListDynamic.length == {2}", this.currentMode.name,this.currentMode.arrListDynamic.length))
                    }
                }
            }
            this.currentMode.deal(keyMap)
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
                vimd.arrModeName.push(modename!="" ? modename : format("mode{1}",(idx+1)))
            else if (modename != "") ;修改内置模式名
                vimd.arrModeName[this.index+1] := modename
            this.name := this.win.name . "-" . vimd.arrModeName[this.index+1]
            ;this.funcDo := ""
            this.doSave := ["nothing","first"] ;保存上个命令
            this.objTips := map() ;NOTE 大纲提示(可动态在命令里用 this.mode1.objTips[key] 来添加)
            this.objtips.CaseSense := true
            ;NOTE 用 array 可以记录顺序
            ;改进：根据第1个单按键分组
            this.objByFirstKey := map() ;以第1个 keyMap(因为keyIn转成了keyMap) 分类
            this.objByFirstKey.CaseSense := true
            this.objDynamic := map() ;记录所有需要验证动态信息的按键(可以快速过滤无关按键)
            this.objDynamic.CaseSense := true
            this.arrListDynamic := [] ;动态命令
            ;event(部分事件在 vimdWins 部分事件在 vimdModes)
            ;NOTE 智能判断按键(智能模式识别的核心)返回 false 则直接发送按键
            ;TODO 如果是第2个键，是否还要判断？
            this.onBeforeKey := ""
            this.onAfterKey := ""
            this.onBeforeDo := ""
            this.onAfterDo := ""
            ;NOTE NOTE NOTE 在 None 模式下临时切换为 Vim <2022-07-28 15:00:47>
            ;按键定义参考 key_hot2map 返回值
            this.keySuperVim := ""
            this.arrKeyMap := [] ;记录每个按键
            this.tipsDynamic := "" ;NOTE 动态生成，所以不需要 map()
        }

        ;脚本运行过程出错，要先运行此命令退出，否则下次按键会无效(TODO 具体原因)
        init(noTips:=true) { ;默认隐藏 tooltip
            ;OutputDebug("init start")
            ;win 属性
            this.win.count := 0
            this.win.isRepeat := false
            this.win.isBreak := false
            ;自身属性
            this.arrKeyMap := [] ;记录每个按键
            ;this.funcDo := ""
            this.tipsDynamic := "" ;NOTE 动态生成，所以不需要 map()
            if (this.win.typeSuperVim)
                this.win.exitSuperMode()
            vimd.hideTips1()
            if (noTips)
                this.hideTips()
            ;OutputDebug("init end")
        }

        ;NOTE 被keyIn调用
        ;TODO count情况是否优先处理
        deal(keyMap) {
            if (keyMap == "{escape}") {
                if (this.objByFirstKey.has(keyMap)) {
                    this.callFunc(this.objByFirstKey[keyMap][1]["action"])
                } else { ;mode0
                    send(keyMap) ;mode0模式下需要 TODO
                    this.init()
                    return
                }
            } else if (keyMap == "{BackSpace}") {
                if (this.objByFirstKey.has(keyMap)) {
                    this.callFunc(this.objByFirstKey[keyMap][1]["action"])
                } else {
                    send(keyMap) ;None模式下需要 TODO
                    this.init()
                    return
                }
            } else if (!this.arrKeyMap.length) { ;第一个按键
                if (keyMap ~= "^\d$" && this.objByFirstKey.has(keyMap)) { ;防止None模式
                    this.dealCount(keyMap)
                } else if (keyMap == "." && this.win.currentMode.index == 1) { ;Repeat
                    ;msgbox(json.stringify(this.objByFirstKey[keyMap], 4))
                    this.callFunc(this.objByFirstKey[keyMap][1]["action"])
                    this.init()
                } else {
                    this.update(keyMap)
                }
            } else {
                this.update(keyMap)
            }
        }

        dealCount(keyMap:="") {
            if (keyMap != "")
                this.win.count := this.win.count ? this.win.count*10+integer(keyMap) : integer(keyMap)
            else { ;按了 BackSpace
                if this.win.count>9
                    this.win.count := this.win.count//10
                else {
                    this.init()
                    return
                }
            }
            this._show(string(this.win.count))
        }

        getStrCache() { ;arrKeyMap连接字符串
            str := ""
            for v in this.arrKeyMap
                str .= v
            return str
        }

        ;更新当前匹配的命令并 showTips
        ;先修改arrKeyMap再运行
        update(keyMap:="") {
            if (keyMap != "") {
                this.arrKeyMap.push(keyMap)
            } else {
                this.arrKeyMap.pop()
                if (!this.arrKeyMap.length) {
                    this.init()
                    return
                }
            }
            arrMatch := [] ;记录所有匹配热键
            ;匹配动态命令
            strCache := this.getStrCache()
            ;msgbox(this.arrListDynamic.length)
            for objDo in this.arrListDynamic {
                ;OutputDebug(arc[1] . " -- " . strCache)
                if (instr(objDo["string"],strCache,true) == 1)
                    arrMatch.push(objDo)
            }
            ;OutputDebug("after check doListDynamic")
            ;匹配普通命令
            if (this.objByFirstKey.has(this.arrKeyMap[1])) {
                for objDo in this.objByFirstKey[this.arrKeyMap[1]] {
                    if (instr(objDo["string"],strCache,true) == 1) ;NOTE 匹配大小写
                        arrMatch.push(objDo)
                }
            }
            ;OutputDebug("arrMatch.length = " . arrMatch.length)
            if (!arrMatch.length) { ;没找到命令
                if (this.arrKeyMap.length == 1) ;为第1个按键
                    send(this.arrKeyMap[1])
                this.init()
            } else if (arrMatch.length == 1) { ;单个结果
                ;msgbox(json.stringify(arrMatch[1], 4))
                this.do(arrMatch[1])
                this.init() ;NOTE 初始化
            } else { ;大部分情况
                this.showTips(arrMatch)
            }
        }

        ;-----------------------------------maps-----------------------------------

        /*
        objDo := {}
        objDo.arrkey := []
        objDo.string := "" ;按键字符串
        objDo.hotwin := "" ;NOTE 记录按键当前的窗口，用来精细化管理
        objDo.action := ""
        objDo.comment := ""
        objDo.super := super ;热键永远 on(无视模式)，直接用 hotkey()定义即可
        */
        ;公共 map
        mapDefault(bCount:=true) {
            if (this.index == 0) { ;mode0
                this.mapkey("{escape}",ObjBindMethod(this,"doGlobal_Escape"),"进入 mode1")
            } else if (this.index == 1) { ;mode1
                this.mapkey("``",ObjBindMethod(this.win,"changeMode",0),"进入 mode0")
                this.mapkey("{escape}",ObjBindMethod(this,"doGlobal_Escape"),"有count或arrKeyMap，则退出")
                this.mapkey("{BackSpace}",ObjBindMethod(this,"doGlobal_BackSpace"),"BackSpace")
                this.mapkey("\e",ObjBindMethod(this,"doGlobal_Edit"),"【编辑】VimD_" . this.win.name)
                this.mapkey("\|",ObjBindMethod(this,"doGlobal_objByFirstKey"),"查看所有功能(按首键分组)objByFirstKey")
                this.mapkey("\_",ObjBindMethod(this,"doGlobal_Debug_objSingleKey"),"查看所有拦截的按键 objSingleKey")
                this.mapkey("\s",ObjBindMethod(this,"doGlobal_Debug_objKeySuperVim"),"查看所有的<super>键 objKeySuperVim")
                if bCount
                    this.mapCount()
                this.mapkey("." ,ObjBindMethod(this,"doGlobal_Repeat"),"重做")
            }
        }

        ;keysmap类型 <^enter> {F1} + A
        mapkey(keysmap, funcObj, comment) {
            objDo := this._map(keysmap, funcObj, comment)
            keyMapFirst := vimd.key_hot2map(objDo["arrkey"][1])
            ;添加到objByFirstKey(objTips用) NOTE keysmap要区分大小写，否则会被覆盖
            if (!this.objByFirstKey.has(keyMapFirst))
                this.objByFirstKey[keyMapFirst] := [objDo]
            else
                this.objByFirstKey[keyMapFirst].push(objDo)
        }
        mapDynamic(keysmap, funcObj, comment) {
            objDo := this._map(keysmap, funcObj, comment)
            objDo["comment"] := "***" . objDo["comment"] ;动态功能，前面加 ***
            this.arrListDynamic.push(objDo)
        }
        mapCount() {
            loop(10)
                this.mapkey(A_Index-1,ObjBindMethod(this.win,"keyIn"),"count")
        }

        ;把定义打包为 objDo
        _map(keysmap, funcObj, comment) {
            objDo := this.key_map2arrHot(keysmap)
            objDo["action"] := funcObj
            objDo["comment"] := comment
            objDo["hotwin"] := this.win.hotwin
            for v in objDo["arrkey"] {
                if (A_Index == 1) {
                    if (objDo["super"]) ;记录超级键
                        this.win.objKeySuperVim[vimd.key_hot2map(v)] := 1
                }
                if (!this.win.objSingleKey[this.win.hotwin].has(v)) { ;单键避免重复定义
                    hotkey(v, ObjBindMethod(this.win,"keyIn")) ;NOTE 相关的键全部要拦截，用 vimd 控制
                    this.win.objSingleKey[this.win.hotwin][v] := 1
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

        doSend(key) {
            if GetKeyState("CapsLock")
                send(format("{shift down}{1}{shift up}", key))
            else
                send(key)
        }

        ;最终执行的命令
        do(doObj) {
            this.hideTips()
            ;msgbox(this.win.isRepeat . "`n" . json.stringify(doObj, 4))
            cnt := this.win.GetCount()
            ;timeSave := A_TickCount
            ;NOTE 运行
            loop(cnt) {
                this.callFunc(doObj["action"], true)
                if this.win.isBreak ;运行后才知道是否 isBreak
                    break
            }
            ;tooltip(A_TickCount - timeSave,,, 9)
            ;SetTimer(tooltip.bind(,,, 9), -1000)
            ;处理 repeat 和 count
            if !this.win.isRepeat {
                this.doSave := doObj
                this.CountSave := cnt
            }
            ;if isobject(this.onAfterDo)
            ;    this.callFunc(this.onAfterDo)
        }

        ;TODO 是否设置全局，这样出提示后，在其他未定义软件界面按键也能退出
        doGlobal_Escape() {
            if (this.index != 1)
                this.win.changeMode(1)
            else if (!this.arrKeyMap.length && !this.win.count)
                send("{escape}")
        }

        ;删除最后一个字符
        doGlobal_BackSpace() {
            if (this.arrKeyMap.length) {
                this.update()
            } else if (this.win.count) {
                this.dealCount()
            } else {
                send("{BackSpace}")
            }
        }
        doGlobal_Edit() {
            SplitPath(A_LineFile,, &dn)
            if (this.win.HasOwnProp("cls") && this.win.cls.HasOwnProp("getTitleEx")) {
                title := this.win.cls.getTitleEx(1)
                hyf_runByVim(format("{1}\wins\{2}\VimD_{2}.ahk",dn,this.win.name), title)
            } else {
                hyf_runByVim(format("{1}\wins\{2}\VimD_{2}.ahk",dn,this.win.name))
            }
        }
        doGlobal_Repeat() {
            this.win.isRepeat := true
            this.callFunc(this.doSave["action"], true)
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
        doGlobal_objByFirstKey() {
            res := ""
            oInput := inputbox("首键")
            if (oInput.result=="Cancel" || oInput.value == "") {
                for k, arrKey in this.objByFirstKey {
                    for objDo in arrKey
                        res .= format("{1}`t{2}: {3}`t{4}`n", objDo["hotwin"],k,objDo["string"],objDo["comment"])
                }
            } else {
                ;msgbox(json.stringify(this.objByFirstKey[oInput.value], 4))
                for objDo in this.objByFirstKey[oInput.value]
                    res .= format("{1}`t{2}: {3}`t{4}`n", objDo["hotwin"],A_Index,objDo["string"],objDo["comment"])
            }
            msgbox(res,,0x40000)
        }
        doGlobal_Debug_objSingleKey() {
            res := ""
            for winTitle, obj in this.win.objSingleKey {
                for k, arr in obj
                    res .= format("{1}`n", k)
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
                ;strTooltip .= RegExReplace(objDo[1],"\s|\{space\}","☐") . A_Tab . objDo[3] . "`n"
            this._show(strTooltip)
        }

        hideTips() {
            tooltip(,,, vimd.tipLevel)
        }

        ;NOTE
        _show(str) {
            if (this.win.arrXYTips.length) {
                cmToolTip := A_CoordModeToolTip
                CoordMode("ToolTip", "window")
                tooltip(str, this.win.arrXYTips[1], this.win.arrXYTips[2], vimd.tipLevel)
                CoordMode("ToolTip", cmToolTip)
            } else {
                MouseGetPos(&x, &y)
                x += 40
                y += 40
                tooltip(str, x, y, vimd.tipLevel)
            }
        }

        ;-----------------------------------tips__-----------------------------------

        callFunc(funcObj, errExit:=false) {
            res := hyf_do(funcObj)
            this.init()
            if !res {
                if errExit
                    exit
                else
                    throw OSError("action not find")
            }
        }

    }

}

;OnError(errorDo)
;errorDo(exception, mode) {
;    msgbox(exception.file . "`n" . exception.line,,0x40000)
;    vimd.errorDo() ;NOTE 否则 vimd 下个按键会无效
;}

#include *i hyaray.ahk
#include vimdInclude.ahk

