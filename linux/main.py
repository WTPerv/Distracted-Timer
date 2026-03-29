import resources_rc

import sys
import subprocess
import psutil
import os
import math
from datetime import datetime
import signal
import atexit
from configparser import ConfigParser
from PySide6.QtWidgets import QApplication, QLabel, QWidget, QSystemTrayIcon, QMenu
from PySide6.QtGui import QIcon, QAction, QActionGroup, QCursor
from PySide6.QtCore import Qt, QTimer, QEvent, QLockFile
from ewmh import EWMH

# -------------------------------------------------------------------------------------
# ---------------- CLASSES ------------------------------------------------------------
# -------------------------------------------------------------------------------------

class MyQWidget(QWidget):
    def __init__(self):
        super(MyQWidget, self).__init__()
        self.clickDiff = None
        self.draggable = True

        QApplication.instance().installEventFilter(self)

    def eventFilter(self, source, event):
        if self.draggable:
            if (event.type() == QEvent.MouseButtonPress and 
                event.button() == Qt.LeftButton):
                    self.clickDiff = self.pos() - QCursor.pos()
                    return True
            
            elif event.type() == QEvent.MouseMove and self.clickDiff is not None:
                self.move(QCursor.pos() + self.clickDiff)
                return True
            
            elif event.type() == QEvent.MouseButtonRelease and self.clickDiff is not None:
                self.clickDiff = None
                return True
        
        return super(MyQWidget, self).eventFilter(source, event)    

# -------------------------------------------------------------------------------------
# ---------------- FUNCTIONS ----------------------------------------------------------
# -------------------------------------------------------------------------------------

def LoadWhitelist():
    with open(whitelistFile) as f:
        return set(line.strip() for line in f if line.strip())

def GetActiveProcess():
    try:
        windowId = ewmh.getActiveWindow()
        pid = ewmh.getWmPid(windowId)
        process = psutil.Process(int(pid)).name()
        return process
    except:
        return "-"

def SecondsToTime(seconds):
    time = max(seconds, 0)
    h = math.floor(time / 3600)
    m = math.floor(time / 60) % 60
    s = seconds % 60
    return f"{h:02}:{m:02}:{s:02}"

def SaveData():
    global posX, posY
    rootpos = root.pos()
    posX = rootpos.x()
    posY = rootpos.y()

    config["Window"]["posX"] = str(posX)
    config["Window"]["posY"] = str(posY)
    config["Window"]["dragMode"] = str(dragMode)
    config["Window"]["scale"] = str(scale)
    config["Window"]["alpha"] = str(alphaPercent)

    config["Save"]["currentDay"] = str(currentDay)
    config["Save"]["distractionSeconds"] = str(distractionSeconds)
    config["Save"]["focusedSeconds"] = str(focusedSeconds)

    with open(configFile, 'w') as f:
        config.write(f)

def OnKilled(sig, frame):
    app.quit()

def RegisterOnClose():
    app.aboutToQuit.connect(SaveData)
    atexit.register(SaveData)
    signal.signal(signal.SIGINT, OnKilled)
    signal.signal(signal.SIGTERM, OnKilled)
    signal.signal(signal.SIGHUP, OnKilled)
    signal.signal(signal.SIGQUIT, OnKilled)
    signal.signal(signal.SIGABRT, OnKilled)

def UpdateGUIDraggable(firstTime = False):
    root.setWindowFlag(Qt.WindowType.WindowTransparentForInput, not dragMode)
    
    if not firstTime:
        root.show()

def UpdateGUIOpacity():
    def PercentToByte(percent) :
        return math.ceil(255 * percent / 100.0)

    root.setStyleSheet(f"background-color: rgba(0, 0, 0, {PercentToByte(alphaPercent)});")

def UpdateGUIScale():
    global fs_distracted, fs_focused, fs_process    

    root.resize(200*scale, 85*scale)

    dColor = "red" if isDistracted==1 else "grey"
    fColor = "white" if isDistracted==0 else "grey"
    fs_distracted = str(28*scale) + "px"
    fs_focused = str(16*scale) +"px"
    fs_process = str(12*scale) +"px"

    distractedTimerText.setStyleSheet("color: " + dColor + "; font-size: " + fs_distracted)
    distractedTimerText.setAlignment(Qt.AlignCenter)
    distractedTimerText.setGeometry(0, 0, 200*scale, 40*scale)

    focusedTimerText.setStyleSheet("color: " + fColor + "; font-size: " + fs_focused)
    focusedTimerText.setAlignment(Qt.AlignCenter)
    focusedTimerText.setGeometry(0, 40*scale, 200*scale, 20*scale)

    processText.setStyleSheet("color: white; font-size: " + fs_process)
    processText.setAlignment(Qt.AlignCenter)
    processText.setGeometry(0, 60*scale, 200*scale, 25*scale)

def CheckFocus(isFlash=False):
    global isDistracted, distractionSeconds, focusedSeconds, currentDay
    currDistracted = -1

    process = GetActiveProcess()

    if process not in whitelist:
        if not isFlash:
            distractionSeconds += 1
        currDistracted = 1
    else:
        if not isFlash:
            focusedSeconds += 1
        currDistracted = 0

    today = datetime.now().timetuple().tm_yday
    if today != currentDay:
        distractionSeconds = 0
        focusedSeconds = 0
        currentDay = today

    if currDistracted != isDistracted:
        if currDistracted == 1:
            distractedTimerText.setStyleSheet("color: red; font-size: " + fs_distracted)
            focusedTimerText.setStyleSheet("color: gray; font-size: " + fs_focused)
        else:
            distractedTimerText.setStyleSheet("color: gray; font-size: " + fs_distracted)
            focusedTimerText.setStyleSheet("color: white; font-size: " + fs_focused)
        isDistracted = currDistracted

    distractedTimerText.setText(SecondsToTime(distractionSeconds))
    focusedTimerText.setText(SecondsToTime(focusedSeconds))
    processText.setText(process)

# ---------------- TRAY FUNCTIONS ----------------

def ToggleDragMode():
    global dragMode
    dragMode = not dragMode
    UpdateGUIDraggable()
    SaveData()

def EditWhitelist():
    subprocess.Popen(["xdg-open", whitelistFile])

def ReloadWhitelist():
    global whitelist
    whitelist = LoadWhitelist()

def ResetTimer():
    global distractionSeconds, focusedSeconds
    distractionSeconds = 0
    focusedSeconds = 0
    CheckFocus(True)
    SaveData()

def ResetPosition():
    global posX, posY
    posX = 20
    posY = 20
    root.move(posX, posY)
    SaveData()

def CreateTrayScale():
    scales = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]

    tray_scaleGroup = QActionGroup(tray_scale)
    for s in scales:
        action = QAction(f"x{s}", tray_scale)
        action.setData(s)
        action.setCheckable(True)
        if scale == s:
            action.setChecked(True)
        tray_scaleGroup.addAction(action)
        tray_scale.addAction(action)

    def OnTrayScaleClick(action):
        global scale
        scale = action.data()
        SaveData()
        UpdateGUIScale()

    tray_scaleGroup.triggered.connect(OnTrayScaleClick)

def CreateTrayOpacity():
    percents = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    
    tray_opacityGroup = QActionGroup(tray_opacity)
    for p in percents:
        action = QAction(f"{p}%", tray_opacity)
        action.setData(p)
        action.setCheckable(True)
        if alphaPercent == p:
            action.setChecked(True)
        tray_opacityGroup.addAction(action)
        tray_opacity.addAction(action)

    def OnTrayOpacityClick(action):
        global alphaPercent
        alphaPercent = action.data()
        SaveData()
        UpdateGUIOpacity()

    tray_opacityGroup.triggered.connect(OnTrayOpacityClick)

def RestartApp():
    SaveData()
    lock.unlock()
    subprocess.Popen(sys.argv)
    app.quit()

def QuitApp():
    app.quit()

# -------------------------------------------------------------------------------------
# ---------------- LOGIC -------------------------------------------------------------
# -------------------------------------------------------------------------------------

# ---------------- CONFIG ----------------

configDir = os.path.expanduser("~/.distraction_timer")

lockFile = os.path.join(configDir, "app.lock")
lock = QLockFile(lockFile)
if not lock.tryLock(0):
    print("Another instance is already running.")
    sys.exit(0)

configFile = os.path.join(configDir, "config.ini")
whitelistFile = os.path.join(configDir, "whitelist.txt")

os.makedirs(configDir, exist_ok=True)

config = ConfigParser()
config["Window"] = {}
config["Save"] = {}

if not os.path.exists(configFile):
    with open(configFile, 'w') as f:
        f.write("")
else:
    config.read(configFile)

if not os.path.exists(whitelistFile):
    with open(whitelistFile, "w") as f:
        f.write("gnome-terminal\nnemo\n")

posX = config.getint("Window","posX", fallback = 20)
posY = config.getint("Window","posY", fallback = 20)
dragMode = config.getboolean("Window", "dragMode", fallback = True)
scale = config.getfloat("Window", "scale", fallback = 1)
alphaPercent = config.getfloat("Window", "alpha", fallback = 70)
alphaPercent = min(max(alphaPercent, 0), 100)

distractionSeconds = config.getint("Save","distractionSeconds", fallback = 0)
focusedSeconds = config.getint("Save","focusedSeconds", fallback = 0)
currentDay = config.getint("Save","currentDay", fallback = datetime.now().timetuple().tm_yday)

whitelist = LoadWhitelist()

# ---------------- INIT ----------------

isDistracted = -1
ewmh = EWMH()

# ---------------- GUI ----------------

app = QApplication([])
app.setQuitOnLastWindowClosed(False)
app.setWindowIcon(QIcon(":/clock.png"))
RegisterOnClose()

root = MyQWidget()
root.setWindowFlags(Qt.FramelessWindowHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus | Qt.X11BypassWindowManagerHint)
UpdateGUIDraggable(True)
root.setAttribute(Qt.WA_TranslucentBackground)
root.setAttribute(Qt.WA_ShowWithoutActivating)
root.setAttribute(Qt.WA_X11DoNotAcceptFocus)
root.setGeometry(posX, posY, 200, 85)
UpdateGUIOpacity()

distractedTimerText = QLabel(SecondsToTime(distractionSeconds), root)
focusedTimerText = QLabel(SecondsToTime(focusedSeconds), root)
processText = QLabel("-", root)
UpdateGUIScale()

root.show()

# dock type windows are always on top, even on top of fullscreen
subprocess.run([
    "xprop",
    "-id", str(int(root.winId())),
    "-f", "_NET_WM_WINDOW_TYPE", "32a",
    "-set", "_NET_WM_WINDOW_TYPE", "_NET_WM_WINDOW_TYPE_DOCK"
])

# ---------------- TRAY ----------------

tray = QSystemTrayIcon(QIcon(":/clock.png"), app)
menu = QMenu()

tray_draggable = QAction("Draggable", triggered = ToggleDragMode)
tray_draggable.setCheckable(True)
if dragMode:
    tray_draggable.setChecked(True)
menu.addAction(tray_draggable)

menu.addSeparator()

tray_editWhitelist = QAction("Edit whitelist", triggered = EditWhitelist)
menu.addAction(tray_editWhitelist)
tray_reloadWhitelist = QAction("Reload whitelist", triggered = ReloadWhitelist)
menu.addAction(tray_reloadWhitelist)

menu.addSeparator()

tray_resetTimer = QAction("Reset timer", triggered = ResetTimer)
menu.addAction(tray_resetTimer)
tray_resetPosition = QAction("Reset position", triggered = ResetPosition)
menu.addAction(tray_resetPosition)
tray_opacity = QMenu("Opacity")
CreateTrayOpacity()
menu.addMenu(tray_opacity)
tray_scale = QMenu("Scale")
CreateTrayScale()
menu.addMenu(tray_scale)

menu.addSeparator()

tray_quit = QAction("Quit", triggered = QuitApp)
menu.addAction(tray_quit)

tray.setContextMenu(menu)
tray.setToolTip("Distracted Timer")

tray.setVisible(True)

# ---------------- MAIN LOOP ----------------

checkTimer = QTimer()
checkTimer.timeout.connect(CheckFocus)
checkTimer.start(1000)

saveTimer = QTimer()
saveTimer.timeout.connect(SaveData)
saveTimer.start(5*60*1000)

app.exec()