; https://www.autohotkey.com/docs/v2/

; #############################################################################
; ######################################## SETTINGS ###########################
; #############################################################################

#Requires AutoHotkey v2.0
#SingleInstance Force

configDir := A_AppData "\DistractionTimer"
configFile := configDir "\Config.ini"
whitelistFile := configDir "\Whitelist.txt"

startupLink := A_Startup "\DistractedTimer.lnk"
exePath := A_ScriptFullPath
autoStartId := "Start with Windows"

; #############################################################################
; ########################################### LOGIC ###########################
; #############################################################################

; ########################### INIT ###########################
DirCreate(configDir)

if (!FileExist(whitelistFile)) {
    FileAppend("explorer.exe`nnotepad.exe`n", whitelistFile)
}

posX := IniRead(configFile, "Window", "posX", 20)
posY := IniRead(configFile, "Window", "posY", 20)
whitelist := LoadWhitelist()

dragMode := IniRead(configFile, "Window", "dragMode", false)
dragId := "Draggable"

alphaPercent := IniRead(configFile, "Window", "alpha", 60)
alphaPercent := Min(Max(alphaPercent, 0), 100)

currentDay := A_YDay

; ########################### GUI ###########################

overlay := Gui("+AlwaysOnTop -Caption +ToolWindow")
overlay.BackColor := "000000"
overlay.SetFont("s24 cFFFFFF", "Segoe UI")
overlay.MarginY := 0
overlay.MarginX := 0
overlayHeight := 100
overlayWidth := 200

timerText := overlay.AddText("Center w" overlayWidth, "00:00:00")
focusText := overlay.AddText("Center w" overlayWidth, "Focused:`n-")
focusText.SetFont("s10")

dragHitbox := overlay.AddText("x0 y0 BackgroundTrans w" overlayWidth " h" overlayHeight)
dragHitbox.OnEvent("Click", OnClick)
dragHitbox.hCursor := LoadCursor(IDC_HAND := 32646)
OnMessage(0x20, WM_SETCURSOR)

overlay.Show("NoActivate x" posX " y" posY " w" overlayWidth " h" overlayHeight)

WinSetTransparent(PercentToByte(alphaPercent), overlay.Hwnd)
if (!dragMode)
    WinSetExStyle("+0x20", overlay.Hwnd) ;click-through

OnMessage(0x404, AHK_NOTIFYICON) ; WM_USER + 4
OnExit OnExiting

; ########################### TIMER ###########################

distractionSeconds := 0
SetTimer(CheckFocus, 1000)

; ########################### TRAY ###########################

opacityMenu := Menu()
percents := [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
for p in percents {
    opacityMenu.Add(p "%", SetOpacity.Bind(, , , p), "Radio")

    if (alphaPercent = p)
        opacityMenu.Check(p "%")
}

A_TrayMenu.Delete()
A_TrayMenu.Add(dragId, ToggleDragMode)
if (dragMode)
    A_TrayMenu.Check(dragId)
A_TrayMenu.Add()
A_TrayMenu.Add("Edit whitelist", EditWhitelist)
A_TrayMenu.Add("Reload whitelist", ReloadWhitelist)
A_TrayMenu.Add()
A_TrayMenu.Add("Reset timer", ResetTimer)
A_TrayMenu.Add("Reset position", ResetPosition)
A_TrayMenu.Add("Opacity", opacityMenu)
A_TrayMenu.Add()
A_TrayMenu.Add(autoStartId, ToggleStartup)
if (IsAutoStart())
    A_TrayMenu.Check(autoStartId)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())

; #############################################################################
; ####################################### FUNCTIONS ###########################
; #############################################################################

LoadWhitelist() {
    dict := Map()

    for line in StrSplit(FileRead(whitelistFile), "`n") {
        line := Trim(line)
        if (line != "")
            dict[StrLower(line)] := true
    }

    return dict
}

CheckFocus() {
    global distractionSeconds, currentDay

    try process := StrLower(WinGetProcessName("A"))
    catch
        process := "-"

    if (!whitelist.Has(process)) {
        distractionSeconds += 1
        timerText.SetFont("cFF0000")
    }
    else {
        timerText.SetFont("cFFFFFF")
    }

    if (currentDay != A_YDay) {
        distractionSeconds := 0 ;reset every 24 hours
        currentDay := A_YDay
    }

    hours := Floor(distractionSeconds / (60 * 60))
    minutes := Mod(Floor(distractionSeconds / 60), 60)
    seconds := Mod(distractionSeconds, 60)

    timerText.Value := Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
    focusText.Value := "Focused:`n" process
}

; ######################## SYSTEM TRAY ###########################

EditWhitelist(*) {
    Run whitelistFile
}

ReloadWhitelist(*) {
    global whitelist
    whitelist := LoadWhitelist()
}

ResetTimer(*) {
    global whitelist
    distractionSeconds := 0
    CheckFocus()
}

ToggleDragMode(*) {
    global dragMode, dragId
    dragMode := !dragMode

    if (dragMode) {
        A_TrayMenu.Check(dragId)
        WinSetExStyle("-0x20", overlay.Hwnd) ;clickable
    }
    else {
        A_TrayMenu.Uncheck(dragId)
        WinSetExStyle("+0x20", overlay.Hwnd) ;click-through
    }
}

ResetPosition(*) {
    posX := 20
    posY := 20
    overlay.Show("x" posX " y" posY)
}

ToggleStartup(*) {
    autoStart := IsAutoStart()
    if (autoStart)
        FileDelete (startupLink)
    else
        FileCreateShortcut exePath, startupLink

    autoStart := !autoStart
    if (autoStart)
        A_TrayMenu.Check(autoStartId)
    else
        A_TrayMenu.Uncheck(autoStartId)
}

; ######################## DRAG ###########################

OnClick(*) {
    PostMessage(0xA1, 2) ;WM_NCLBUTTONDOWN, HTCAPTION
}

OnExiting(*) {
    overlay.GetPos(&posX, &posY)
    IniWrite(posX, configFile, "Window", "posX")
    IniWrite(posY, configFile, "Window", "posY")
    IniWrite(dragMode, configFile, "Window", "dragMode")
    IniWrite(alphaPercent, configFile, "Window", "alpha")
}

; https://www.autohotkey.com/board/topic/32608-changing-the-system-cursor/
; https://www.autohotkey.com/boards/viewtopic.php?p=536239#p536239
WM_SETCURSOR(wp, *) {
    if (wp = dragHitbox.hwnd) {
        return DllCall('SetCursor', 'Ptr', GuiCtrlFromHwnd(wp).hCursor)
    }
}
LoadCursor(cursorId) {
    static IMAGE_CURSOR := 2, flags := (LR_DEFAULTSIZE := 0x40) | (LR_SHARED := 0x8000)
    return DllCall('LoadImage', 'Ptr', 0, 'UInt', cursorId, 'UInt', IMAGE_CURSOR,
        'Int', 0, 'Int', 0, 'UInt', flags, 'Ptr')
}

; ######################## OPACITY ###########################

; https://www.autohotkey.com/boards/viewtopic.php?p=524247#p524247
SetOpacity(ItemName, ItemPos, MyMenu, Param1 := '') {
    global alphaPercent
    alphaPercent := Param1
    alpha := PercentToByte(alphaPercent)
    WinSetTransparent(alpha, overlay.Hwnd)

    for p in percents {
        if (alphaPercent = p)
            opacityMenu.Check(p "%")
        else
            opacityMenu.Uncheck(p "%")
    }
}

PercentToByte(percent) {
    return Ceil(255 * percent / 100.0)
}

; ######################## AUTO START ###########################

IsAutoStart() {
    if FileExist(startupLink) {
        FileGetShortcut startupLink, &outTarget
        TrayTip(outTarget " VS " exePath)
        return outTarget = exePath
    }
    else
        return false
}

; ######################## EXTRA ###########################

AHK_NOTIFYICON(wParam, lParam, msg, hwnd) {
    if (lParam = 0x202) { ;show tray menu on WM_LBUTTONUP
        A_TrayMenu.Show()
        return 0
    }
}
