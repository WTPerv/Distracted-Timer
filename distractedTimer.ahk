; https://www.autohotkey.com/docs/v2/

; #############################################################################
; ######################################## SETTINGS ###########################
; #############################################################################

;@Ahk2Exe-SetVersion 1.3.0
;@Ahk2Exe-SetProductName Distracted Timer
;@Ahk2Exe-SetDescription Distracted Timer

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
scale := IniRead(configFile, "Window", "scale", 1)

currentDay := IniRead(configFile, "Save", "currentDay", A_YDay)
distractionSeconds := IniRead(configFile, "Save", "distractionSeconds", 0) - 1
focusedSeconds := IniRead(configFile, "Save", "focusedSeconds", 0) - 1

; ########################### GUI ###########################

overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x02000000")
overlay.BackColor := "000000"
overlay.SetFont("c888888", "Segoe UI")
overlay.MarginY := 0
overlay.MarginX := 0
overlayH := Ceil(90 * scale)
overlayW := Ceil(200 * scale)

timerDistractedText := overlay.AddText(Format("Center w{:d} h{:d} x0 y0", overlayW, Floor(40 * scale)), "00:00:00")
timerDistractedText.SetFont("s" Floor(24 * scale))

timerFocusedText := overlay.AddText(Format("Center w{:d} h{:d} x0 y{:d}", overlayW, Floor(20 * scale), Floor(40 * scale)), "00:00:00")
timerFocusedText.SetFont("s" Floor(12 * scale))

processText := overlay.AddText(Format("Center w{:d} h{:d} x0 y{:d}", overlayW, Floor(20 * scale), Floor(65 * scale)), "-")
processText.SetFont("cFFFFFF s" Floor(10 * scale))

dragHitbox := overlay.AddText("x0 y0 BackgroundTrans w" overlayW " h" overlayH)
dragHitbox.OnEvent("Click", OnClick)
dragHitbox.hCursor := LoadCursor(IDC_HAND := 32646)
OnMessage(0x20, WM_SETCURSOR)

overlay.Show("NoActivate x" posX " y" posY " w" overlayW " h" overlayH)

WinSetTransparent(PercentToByte(alphaPercent), overlay.Hwnd)
if (!dragMode)
    WinSetExStyle("+0x20", overlay.Hwnd) ;click-through

OnMessage(0x404, AHK_NOTIFYICON) ; WM_USER + 4
OnExit OnExiting

; ########################### TRAY ###########################

opacityMenu := Menu()
percents := [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
for p in percents {
    opacityMenu.Add(p "%", SetOpacity.Bind(, , , p), "Radio")

    if (alphaPercent = p)
        opacityMenu.Check(p "%")
}

scaleMenu := Menu()
scales := [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]
for s in scales {
    scaleMenu.Add("x" s, SetScale.Bind(, , , s), "Radio")

    if (scale = s)
        scaleMenu.Check("x" s)
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
A_TrayMenu.Add("Scale", scaleMenu)
A_TrayMenu.Add()
A_TrayMenu.Add(autoStartId, ToggleStartup)
if (IsAutoStart())
    A_TrayMenu.Check(autoStartId)
A_TrayMenu.Add()
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())

; ########################### LOGIC ###########################

isDistracted := -1 ; distracted = 1, focused = 0, dunno = -1
CheckFocus()
SetTimer(CheckFocus, 1000)

SetTimer(Save, 5 * 60 * 1000) ;save every 5 min

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
    global distractionSeconds, focusedSeconds, isDistracted, currentDay
    currDistracted := -1

    try
        process := StrLower(WinGetProcessName("A"))
    catch
        process := "-"

    if (!whitelist.Has(process)) {
        distractionSeconds += 1
        currDistracted := 1
    }
    else {
        focusedSeconds += 1
        currDistracted := 0
    }

    if (currentDay != A_YDay) {
        distractionSeconds := 0 ;reset every 24 hours
        focusedSeconds := 0
        currentDay := A_YDay
    }

    if (currDistracted != isDistracted) {
        if (currDistracted = 1) {
            timerDistractedText.SetFont("cFF0000")
            timerFocusedText.SetFont("c888888")
        }
        else {
            timerDistractedText.SetFont("c888888")
            timerFocusedText.SetFont("cFFFFFF")
        }
        isDistracted := currDistracted
    }

    tdValue := SecondsToTime(distractionSeconds)
    tfValue := SecondsToTime(focusedSeconds)
    if (timerDistractedText.Value != tdValue)
        timerDistractedText.Value := tdValue
    if (timerFocusedText.Value != tfValue)
        timerFocusedText.Value := tfValue
    if (processText.Value != process)
        processText.Value := process
}

SecondsToTime(seconds) {
    time := Max(seconds, 0)
    hours := Floor(time / (60 * 60))
    minutes := Mod(Floor(time / 60), 60)
    seconds := Mod(time, 60)

    return Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
}

Save() {
    overlay.GetPos(&posX, &posY)
    IniWrite(posX, configFile, "Window", "posX")
    IniWrite(posY, configFile, "Window", "posY")
    IniWrite(dragMode, configFile, "Window", "dragMode")
    IniWrite(alphaPercent, configFile, "Window", "alpha")
    IniWrite(scale, configFile, "Window", "scale")

    IniWrite(currentDay, configFile, "Save", "currentDay")
    IniWrite(distractionSeconds, configFile, "Save", "distractionSeconds")
    IniWrite(focusedSeconds, configFile, "Save", "focusedSeconds")
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
    global distractionSeconds, focusedSeconds
    distractionSeconds := -1
    focusedSeconds := -1
    CheckFocus()
    Save()
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

    Save()
}

ResetPosition(*) {
    posX := 20
    posY := 20
    overlay.Move(posX, posY)

    Save()
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
    Save()
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

    Save()
}

PercentToByte(percent) {
    return Ceil(255 * percent / 100.0)
}

SetScale(ItemName, ItemPos, MyMenu, Param1 := '') {
    global scale
    scale := Param1
    ; ResetPosition()
    Save()

    Reload
}

; ######################## AUTO START ###########################

IsAutoStart() {
    if FileExist(startupLink) {
        FileGetShortcut startupLink, &outTarget
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
