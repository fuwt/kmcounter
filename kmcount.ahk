; AHK VSERION: AutoHotkey_2.0-a129-78d2aa15 U32
; Author: fwt
#SingleInstance force
#Persistent
OnExit(ExitFunc)
TraySetIcon("img\tray.ico")

deviceinfo := IniRead("kmcount_data.ini", "Config", A_ComputerName, GetDeviceCaps())
if(A_LastError)
  IniWrite(deviceinfo, "kmcount_data.ini", "Config", A_ComputerName)
deviceinfo := StrSplit(deviceinfo, ",")
today := SubStr(A_Now, 1, 8)
lbcount_today := IniRead("kmcount_data.ini", today, "lbcount", 0)
rbcount_today := IniRead("kmcount_data.ini", today, "rbcount", 0)
wheel_today := IniRead("kmcount_data.ini", today, "wheel", 0)
lbcount_total := IniRead("kmcount_data.ini", "total", "lbcount", 0)
rbcount_total := IniRead("kmcount_data.ini", "total", "rbcount", 0)
wheel_total := IniRead("kmcount_data.ini", "total", "wheel", 0)
oldx := 0, oldy := 0, moved_w := 0, moved_h := 0, move_today := 0, move_total := 0
MouseGetPos(&oldx, &oldy)

A_TrayMenu.Delete()
A_TrayMenu.Add("统计", MenuHandler)
A_TrayMenu.Add("退出", MenuHandler)
A_TrayMenu.Default := "统计"

pfn1 := CallbackCreate(LowLevelMouseProc , "Fast", 3)
hHookMouse := DllCall("SetWindowsHookEx", "int", 14, "uint", pfn1, "uint", 0, "uint", 0)
pfn2 := CallbackCreate(LowLevelKeyboardProc , "Fast", 3)
hHookKeyboard := DllCall("SetWindowsHookEx", "int", 13, "uint", pfn2, "uint", 0, "uint", 0)

keylist := []
vk0 := 0
loop(255){
  keyname := Format("vk{:02x}", A_Index)
  keylist.push(IniRead("kmcount_data.ini", "total", keyname, 0))
}
LowLevelKeyboardProc(nCode, wParam, lParam)
{
  global
  If(!nCode && wParam = 0x101)
  {
    vk := NumGet(lParam+0, 0, "Ushort")
    keylist[vk] += 1
  }
  return DllCall("CallNextHookEx", "Uint", 0, "int", nCode, "Uint", wParam, "Uint", lParam)
}

LowLevelMouseProc(nCode, wParam, lParam)
{
  global
  If(!nCode)
  {
    if(wParam = 0x200)
    {
      x := NumGet(lParam+0, 0, "int"), y := NumGet(lParam+0, 4, "int")
      moved_w += Abs(x - oldx), moved_h += Abs(y - oldy)
      oldx := x, oldy := y
    }
    else if(wParam = 0x0201)
      lbcount_today += 1, lbcount_total += 1  
    else if(wParam =  0x0204)
      rbcount_today += 1, rbcount_total += 1
    else if(wParam = 0x020A)
      wheel_today += 1, wheel_total += 1
  }
  return DllCall("CallNextHookEx", "Uint", 0, "int", nCode, "Uint", wParam, "Uint", lParam)
}

Hypot(x, y){
  return Sqrt(x**2 + y**2)
}

GetDeviceCaps() {
  ; 获取显示器信息
  hdcScreen := DllCall("GetDC", "int", 0)
  width := DllCall("GetDeviceCaps", "UPtr", hdcScreen, "int", 4)
  height := DllCall("GetDeviceCaps", "UPtr", hdcScreen, "int", 6)
  hypotenuse := hypot(width, height) / 25.4
  return Format("{},{},{:.1f}", width, height, hypotenuse)
}

dot_to_m(dots){
  global
  ; 像素转实际长度（米）
  screenWidthMM := deviceinfo[1]
  return dots * screenWidthMM / A_ScreenWidth / 1000
}

update_data() {
  global
  ; 保存数据
  distance := hypot(dot_to_m(moved_w), dot_to_m(moved_h))
  move_today := IniRead("kmcount_data.ini", today, "move", 0) + distance
  move_total := IniRead("kmcount_data.ini", "total", "move", 0) + distance
  IniWrite(move_total, "kmcount_data.ini", "total", "move")
  IniWrite(move_today, "kmcount_data.ini", today, "move")
  IniWrite(lbcount_total, "kmcount_data.ini", "total", "lbcount")
  IniWrite(lbcount_today, "kmcount_data.ini", today, "lbcount")
  IniWrite(rbcount_total, "kmcount_data.ini", "total", "rbcount")
  IniWrite(rbcount_today, "kmcount_data.ini", today, "rbcount")
  IniWrite(wheel_total, "kmcount_data.ini", "total", "wheel")
  IniWrite(wheel_today, "kmcount_data.ini", today, "wheel")
  moved_w := 0, moved_h := 0

  vk0 := 0
  for n in keylist
  {
    if(n > 0)
    {
      vk0 += n
      keyname := Format("vk{:02x}", A_Index)
      IniWrite(n, "kmcount_data.ini", "total", keyname)
    }
  }
  IniWrite(vk0, "kmcount_data.ini", "total", "vk0")
}

MenuHandler(ItemName, ItemPos, Menu) {
  global
  if(ItemName = "退出")
    ExitApp()
  else if(ItemName = "统计")
  {
    static mygui := CreateGui()
    ; ↓↓↓获取一组渐变色，可以用showcolors查看渐变效果。 showcolors(getcolors(0xFFFFFF, 0xFF0000, 100))
    static colors := getcolors()
    update_data()
    mygui["static2"].Visible := True
    mygui["static3"].Visible := False
    For Hwnd, GuiCtrlObj in MyGui
    {
      if(GuiCtrlObj.Type = "Edit")
      {
        vk := GetKeyVK(GuiCtrlObj.key[1])
        count := keylist[vk]
        color := colors[100]
        if(t := count * 10 < vk0)
        {
          color := colors[floor(count * 1000 / vk0)+1]
        }
        GuiCtrlObj.Opt("+BackGround" color)
        if vk0 > 0
          GuiCtrlObj.info :=Format("{}`r`n{}`r`n{:.1f}%", GuiCtrlObj.key[2], NumFormat(count), count / vk0 * 100)
        GuiCtrlObj.text := GuiCtrlObj.key[2]
      }
      else if(GuiCtrlObj.Type = "Text")
      {
        GuiCtrlObj.Text :=  Format("  您当前屏幕大小为 {:.1f} 寸`n`n", deviceinfo[3])
        . Format("  鼠标今日移动 {:.2f} 米`n  鼠标累计移动 {:.2f} 米`n  已经绕地球 {:.5f} 圈`n`n", move_today, move_total, move_total / 40076 / 1000)
        . Format("  滚轮累计滚动 {:d} / {:d} 格`n", wheel_today, wheel_total)
        . Format("  鼠标左键累计点击 {:d} / {:d} 次`n", lbcount_today, lbcount_total)
        . Format("  鼠标右键累计点击 {:d} / {:d} 次`n", rbcount_today, rbcount_total)
      }
    }
    mygui.show()
  }
}

getcolors(){
  ; 生成减变色谱
  c1 := IniRead("kmcount_data.ini", "config", "c1", 0x000000)
  c2 := IniRead("kmcount_data.ini", "config", "c2", 0xFF0000)
  n := 100
  colors := []
  r1 := c1 >> 16, g1 := c1 >> 8 & 0xFF, b1 := c1 & 0xFF
  r2 := c2 >> 16, g2 := c2 >> 8 & 0xFF, b2 := c2 & 0xFF
  rd := (r2 - r1)/n, gd := (g2 - g1)/n, bd := (b2 - b1)/n
  loop(n){
    color := Format("{:02x}{:02x}{:02x}", r1 + rd * A_Index, g1 + gd * A_Index, b1 + bd * A_Index)
    colors.push(color)
  }
  return colors
}

showcolors(colors) {
  mygui := Gui.New()
  mygui.add("text", "w1 r1", "")
  for color in colors
  {
    mygui.add("text", "x+0 w1 r1 +BackGround" color, "")
  }
  mygui.show()
}

ExitFunc(ExitReason, ExitCode) {
  global
  DllCall("UnhookWindowsHookEx", "Uint", hHookMouse)
  DllCall("UnhookWindowsHookEx", "Uint", hHookKeyboard)
  return 0
}

CreateGui(){
  MyGui := Gui("+ToolWindow -Caption", "统计")
  MyGui.MarginX := 0, MyGui.MarginY := 0
  MyGui.BackColor := "EEEEEE"
  MyGui.Add("Picture","w1470 h430","img\bg.png")
  MyGui.SetFont("", "comic sans ms")
  ; 第一排
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 xm+20 ym+60", "Esc").key := ["Esc", "Esc"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+47", "F1").key := ["F1", "F1"]
  loop(3)
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "F" A_Index + 1).key := ["F" A_Index + 1, "F" A_Index + 1]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+47", "F5").key := ["F5", "F5"]
  loop(3)
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "F" A_Index + 5).key := ["F" A_Index + 5, "F" A_Index + 5]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+47", "F9").key := ["F9", "F9"]
  loop(3)
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "F" A_Index + 9).key := ["F" A_Index + 9, "F" A_Index + 9]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+10", "PtrSc").key := ["PrintScreen", "PtrSc"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "Scroll").key := ["ScrollLock", "Scroll"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "Pause").key := ["Pause", "Pause"]
  MyGui.Add("Picture","x+130 w32 h32 BackgroundTrans" ,"img\s1.png").OnEvent("Click", ShowCount)
  MyGui.Add("Picture","x+-32 w32 h32 BackgroundTrans" ,"img\s2.png").OnEvent("Click", HideCound)
  MyGui["static3"].Visible := False
  MyGui.Add("Picture","x+10 w32 h32 BackgroundTrans" ,"img\m.png").OnEvent("Click", (*)=>MyToolTip(MyGui["Static6"].text))
  MyGui.Add("Picture","x+10 w32 h32 BackgroundTrans" ,"img\close.png").OnEvent("Click", (*)=>MyGui.Hide())
  ; 第二排
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 y+36 xm+20", "~").key := ["~", "~"]
  for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "+"]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", k).key := [k, k]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w134 h56 x+2", "BackSpace").key := ["BackSpace", "BackSpace"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+10", "Insert").key := ["Insert", "Insert"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "Home").key := ["Home", "Home"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "PgUp").key := ["PgUp", "PgUp"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+10", "NumLock").key := ["NumLock", "NumLock"]
  for k in [["NumpadDiv", "/"], ["NumpadMult", "*"], ["NumpadSub", "-"]]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", k[2]).key := k
  ; 第三排
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w98 h56 xm+20 y+2", "Tab").key := ["Tab", "Tab"]
  for k in ["Q","W","E","R","T","Y","U","I","O","P","[","]"]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", k).key := [k, k]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w98 h56 x+2", "\").key := ["\", "\"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+10", "Delete").key := ["Delete", "Delete"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "End").key := ["End", "End"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "PgDn").key := ["PgDn", "PgDn"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+10", "NumLock").key := ["Numpad7", "7"]
  for k in [["Numpad8", "8"], ["Numpad9", "9"]]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", k[2]).key := k
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h114 x+2", "+").key := ["NumpadAdd", "+"]
  ; 第四排
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w130 h56 xm+20 y+-56", "CapsLock").key := ["CapsLock", "CapsLock"]
  for k in ["A","S","D","F","G","H","J","K","L",";","'" ]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", k).key := [k, k]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w130 h56 x+2", "Enter").key := ["Enter", "Enter"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+210", "4").key := ["Numpad4", "4"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "5").key := ["Numpad5", "5"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "6").key := ["Numpad5", "6"]
  ; 第五排
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w162 h56 xm+20 y+2", "LShift").key := ["LShift", "LShift"]
  for k in ["Z","X","C","V","B","N","M",",",".","/"]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", k).key := [k, k]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w162 h56 x+2", "RShift").key := ["RShift", "RShift"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+74", "Up").key := ["Up", "↑"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+74", "1").key := ["Numpad1", "1"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "2").key := ["Numpad2", "2"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "3").key := ["Numpad3", "3"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h114 x+2", "Enter").key := ["NumpadEnter", "Enter"]
  ; 第六排
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w98 h56 xm+20 y+-56", "LCtrl").key := ["LCtrl", "LCtrl"]
  for k in ["lwin", "LAlt"]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", k).key := [k, k]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w458 h56 x+2", "Space").key := ["Space", "Space"]
  for k in ["RAlt", "Rwin", "AppsKey", "RCtrl"]
    MyGui.Add("edit", "Disabled -Vscroll 0x201 w68 h56 x+2", k).key := [k, k]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+10", "Left").key := ["Left", "←"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "Down").key := ["Down", "↓"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+2", "Right").key := ["Right", "→"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w62 h56 x+10", "0").key := ["Numpad0", "0"]
  MyGui.Add("edit", "Disabled -Vscroll 0x201 w126 h56 x+2", ".").key := ["NumpadDot", "."]

  MyGui.Add("text", "Border y+0 w0 h0", "abc")

  WinSetTransColor(MyGui.BackColor, MyGui)
  OnMessage(0x201, GuiMove)
  return MyGui
}
GuiMove(wParam, lParam, msg, hwnd) {
  if(!GuiCtrlFromHwnd(hwnd))
  SendMessage(0xA1, 2, lParam,hwnd)
}

NumFormat(num){
  if num < 1000
    return num
  else if(num < 1000000)
    return(Format("{:.1f}k", num / 1000))
  else
    return(Format("{:.1f}m", num / 1000000))
}

ShowCount(GuiCtrlObj, Info){
  GuiObj := GuiCtrlObj.Gui
  For Hwnd, GuiCtrlObj in GuiObj
  {
    if(GuiCtrlObj.Type = "Edit")
    {
      GuiCtrlObj.text := GuiCtrlObj.info
    }
  }
  GuiObj["static2"].Visible := False
  GuiObj["static3"].Visible := True
}

HideCound(GuiCtrlObj, Info){
  GuiObj := GuiCtrlObj.Gui
  For Hwnd, GuiCtrlObj in GuiObj
  {
    if(GuiCtrlObj.Type = "Edit")
    {
      GuiCtrlObj.text := GuiCtrlObj.key[2]
    }
  }
  GuiObj["static2"].Visible := True
  GuiObj["static3"].Visible := False
}

MyToolTip(text){
  ToolTip(text)
  KeyWait("Lbutton")
  ToolTip
}
