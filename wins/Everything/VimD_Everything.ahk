;F4通过软件的【浏览路径】设置为gvim编辑文件
;结果筛选见【搜索】→管理筛选器 Ctrl-Shift-f
;ctrl-i 大小写
;ctrl-u 路径
;ctrl-r 正则
;ctrl-b 全字

class VimD_Everything {

    static __new() {
        if (this != VimD_Everything)
            return
        this.win := vimd.initWin("Everything", "ahk_exe Everything.exe")

        this.mode1 := this.win.initMode(1, true, true)

        this.win.setKeySuperVim()

        ;hotkey("F4", (p*)=>_ET.smartDo())
        hotkey("F12", (p*)=>PostMessage(0x111, 40074,,, "A"))

        this.mode1.setObjHotWin("ahk_class EVERYTHING")

        this.mode1.mapkey("\l",(p*)=>hyf_runByVim(A_ScriptDir . "\lib\Everything.ahk"),"编辑lib\Everything.ahk")
        this.mode1.mapkey("b",(p*)=>VimD_Everything.compare(),"比较")
        this.mode1.mapkey("<super>{F5}i",(p*)=>send("{ctrl down}i{ctrl up}"),"大小写切换")
        this.mode1.mapkey("<super>{F5}r",(p*)=>send("{ctrl down}r{ctrl up}"),"正则切换")
        this.mode1.mapkey("<super>{F5}a",(p*)=>ControlChooseString("所有", "ComboBox1"),"显示-所有")
        this.mode1.mapkey("<super>{F5}f",(p*)=>ControlChooseString("文件", "ComboBox1"),"显示-文件")
        this.mode1.mapkey("<super>{F5}d",(p*)=>ControlChooseString("文件夹", "ComboBox1"),"显示-文件夹")

        ;this.mode1.mapkey("e",(p*)=>hyf_runByVim(VimD_Everything.currentFilePath()),"vim打开")
        this.mode1.mapkey("r",(p*)=>run(VimD_Everything.currentFilePath()),"run")
    }

    ;光标选中的文件路径
    static currentFilePath() {
        arr := StrSplit(ListViewGetContent("Selected", "SysListView321", "ahk_class EVERYTHING"), A_Tab)
        if arr.length
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
