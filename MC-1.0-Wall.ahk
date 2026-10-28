; MC 1.0 wall, 4 instances, AutoHotkey v2
;
; on the wall (hover an instance):
;   W / E   play it
;   Y       reset it
;   T       reset all (skips locked)
;   F       play it and reset the rest
;   R       lock / unlock
; in game:
;   Y / F6  quit, make a new world, back to the wall
; anywhere:
;   Ctrl+Alt+L  find the windows again
;   Ctrl+Alt+D  debug info
;
; resets just click through the normal menus:
; save and quit > singleplayer > create new world > enter
;
; all the settings are in Wall-Settings.ahk, keep it in the same folder as this
#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
SendMode "Event"
SetKeyDelay 10, 10
SetMouseDelay 10
SetWinDelay 20
; real pixels so windows line up with display scaling
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

#Include %A_ScriptDir%\Wall-Settings.ahk

global Inst := []      ; instance windows, in order
global Playing := 0    ; 0 = on the wall
global Busy := false
global QuitTime := Map() ; last save and quit time per instance
global Locked := Map()   ; locked instance windows
; min gap between the two singleplayer clicks. if an instance got stuck on
; select world they land on the world list, and two quick clicks on a world
; opens it. 1.0 counts anything under 250ms as a double click
global SafeListGap := 300
global ResetCount := 0
global LearnedWait := 0     ; learned save and quit wait, see LearnSaveWait
global PendingTrim := Map()  ; instances whose old worlds still need deleting
global TrimScheduled := false

LaunchIfNeeded()
FindInstances()
TileAll()
FocusWall()
SetPriorities(0)
ShowLocks(true)
LoadResetCount()
OnExit((*) => SetPriorities(0))   ; put priorities back on exit

HotIf OnWall
Hotkey KeyPlay, (*) => PlayInstance(IndexUnderMouse())
if (KeyPlay2 != "")
    Hotkey KeyPlay2, (*) => PlayInstance(IndexUnderMouse())
Hotkey KeyResetAll, (*) => ResetAll()
Hotkey KeyFocusReset, (*) => FocusReset(IndexUnderMouse())
Hotkey KeyLock, (*) => ToggleLock(IndexUnderMouse())
HotIf InGame
Hotkey KeyResetWhilePlaying, (*) => ResetPlayingAndReturn()
HotIf WallOrGame
Hotkey KeyReset, (*) => ResetKey()
HotIf
Hotkey KeyRescan, (*) => Rescan()
Hotkey "^!d", (*) => ShowDiagnostics()

IsGameWindow(hwnd) {
    try {
        exe := StrLower(WinGetProcessName(hwnd))
        if (exe != "javaw.exe" && exe != "java.exe")
            return false
        cls := WinGetClass(hwnd)
        title := WinGetTitle(hwnd)
        if !(InStr(title, "Minecraft") || cls = "SunAwtFrame" || cls = "LWJGL" || cls = "GLFW30")
            return false
        if (WinGetMinMax(hwnd) = -1)       ; minimized games still count
            return true
        WinGetPos(, , &w, &h, hwnd)
        return (w >= 200 && h >= 150)
    }
    return false
}

FindInstances() {
    global Inst
    found := []
    for hwnd in WinGetList()
        if IsGameWindow(hwnd)
            found.Push(hwnd)
    ; lowest PID first, so instance 1 is whichever launched first
    loop found.Length {
        i := A_Index
        loop found.Length - i {
            j := A_Index + i
            if (WinGetPID(found[j]) < WinGetPID(found[i])) {
                tmp := found[i], found[i] := found[j], found[j] := tmp
            }
        }
    }
    Inst := found
    for i, hwnd in Inst
        try WinSetTitle("Minecraft 1.0 - Wall " i, hwnd)
    Notify("MC 1.0 Wall: found " Inst.Length " Minecraft window(s)."
        . (Inst.Length = 0 ? "`nNo instances running. Ctrl+Alt+L searches again.`nCtrl+Alt+D shows details." : ""))
}

; opens the instances through MultiMC if none are running yet. waits for
; each window before opening the next so they stay in order
LaunchIfNeeded() {
    if (!LaunchInstances || CountGameWindows() > 0)
        return
    if !FileExist(MultiMCPath) {
        MsgBox("Couldn't find MultiMC at:`n" MultiMCPath "`n`nFix MultiMCPath in Wall-Settings.ahk, or open the instances yourself and press Ctrl+Alt+L.", "MC 1.0 Wall")
        return
    }
    SplitPath(MultiMCPath, , &dir)
    ; MultiMC launches by folder name, so make sure they all exist first
    missing := ""
    for name in InstanceFolders
        if !DirExist(dir "\instances\" name)
            missing .= "`n   " name
    if (missing != "") {
        have := ""
        loop files dir "\instances\*", "D"
            if FileExist(A_LoopFileFullPath "\instance.cfg")
                have .= "`n   " A_LoopFileName
        MsgBox("These instance folders aren't in " dir "\instances:" missing
            . "`n`nThe instance folders that are there:" (have != "" ? have : "`n   (none)")
            . "`n`nPut the right names in InstanceFolders in Wall-Settings.ahk.", "MC 1.0 Wall")
        return
    }
    for n, name in InstanceFolders {
        Notify("opening instance " n "...", 60000)
        try Run('"' MultiMCPath '" -l "' name '"', dir)
        catch {
            Notify("couldn't open " name, 8000)
            continue
        }
        start := A_TickCount
        while (CountGameWindows() < n && A_TickCount - start < 60000)
            Sleep 500
    }
    Notify("waiting for the title screens...", TitleScreenWait)
    Sleep TitleScreenWait
}

CountGameWindows() {
    n := 0
    for hwnd in WinGetList()
        if IsGameWindow(hwnd)
            n++
    return n
}

; tooltip for a few seconds
Notify(text, ms := 4000) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}

; Ctrl+Alt+D, lists every java window to help figure out why one isn't found
ShowDiagnostics() {
    text := "Instances found by the script: " Inst.Length "`n`nJava windows open right now:`n"
    n := 0
    for hwnd in WinGetList() {
        try exe := StrLower(WinGetProcessName(hwnd))
        catch
            continue
        if (exe != "javaw.exe" && exe != "java.exe")
            continue
        n++
        try WinGetPos(, , &w, &h, hwnd)
        catch
            w := h := 0
        text .= "- " exe "  |  title: " WinGetTitle(hwnd) "  |  class: " WinGetClass(hwnd)
            . "  |  " w "x" h "  |  " (WinGetMinMax(hwnd) = -1 ? "MINIMIZED" : WinGetMinMax(hwnd) = 1 ? "maximized" : "normal")
            . "  |  used: " (IsGameWindow(hwnd) ? "yes" : "no") "`n"
    }
    if (n = 0)
        text .= "(none - is Minecraft open?)`n"
    for i, hwnd in Inst
        text .= "`nInstance " i " saves: " ((d := SavesDir(i)) != "" ? d : "NOT FOUND")
    try text .= "`nActive window: " WinGetTitle("A") "  |  " WinGetProcessName("A")
    text .= "`nAutoHotkey version: " A_AhkVersion
    A_Clipboard := text
    MsgBox(text "`n`n(Copied to clipboard.)", "MC 1.0 Wall details")
}

InstHas(hwnd) {
    for h in Inst
        if (h = hwnd)
            return true
    return false
}

Rescan() {
    global Playing := 0
    FindInstances()
    TileAll()
    FocusWall()
    ShowLocks(true)
}

GridSize(n, &cols, &rows) {
    cols := Max(1, Ceil(Sqrt(n)))
    rows := Max(1, Ceil(n / cols))
}

TileAll() {
    if (Inst.Length = 0)
        return
    loop Inst.Length
        Arrange(A_Index)
}

; put an instance back on the wall
Arrange(i) {
    if UseProjector {
        try FillMonitor(Inst[i])   ; full size behind the projector
    } else {
        TileOne(i)
    }
}

TileOne(i) {
    hwnd := Inst[i]
    if WallFillsWholeScreen
        MonitorGet(WallMonitor, &L, &T, &R, &B)
    else
        MonitorGetWorkArea(WallMonitor, &L, &T, &R, &B)
    GridSize(Inst.Length, &cols, &rows)
    col := Mod(i - 1, cols), row := (i - 1) // cols
    ; exact edges so the tiles touch
    x1 := L + (R - L) * col // cols, x2 := L + (R - L) * (col + 1) // cols
    y1 := T + (B - T) * row // rows, y2 := T + (B - T) * (row + 1) // rows
    try {
        if (WinGetMinMax(hwnd) != 0)
            WinRestore(hwnd)
        WinSetStyle("+0xC40000", hwnd)       ; title bar and border back
        WinMove(x1, y1, x2 - x1, y2 - y1, hwnd)
        ; windows adds invisible borders that leave gaps, so stretch over them
        FrameOffsets(hwnd, &fl, &ft, &fr, &fb)
        if (fl || ft || fr || fb)
            WinMove(x1 - fl, y1 - ft, (x2 - x1) + fl + fr, (y2 - y1) + ft + fb, hwnd)
    }
}

; invisible border size on each side
FrameOffsets(hwnd, &l, &t, &r, &b) {
    l := t := r := b := 0
    rect := Buffer(16, 0)
    try {
        if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9, "ptr", rect, "uint", 16)
            return
        WinGetPos(&x, &y, &w, &h, hwnd)
        l := NumGet(rect, 0, "int") - x
        t := NumGet(rect, 4, "int") - y
        r := (x + w) - NumGet(rect, 8, "int")
        b := (y + h) - NumGet(rect, 12, "int")
    }
}

; make the played instance fill the monitor
FillMonitor(hwnd) {
    if !Borderless {
        ; leave it if it's already maximized, resizing breaks the OBS capture
        if (WinGetMinMax(hwnd) != 1)
            WinMaximize(hwnd)
        return
    }
    MonitorGet(WallMonitor, &L, &T, &R, &B)
    if (WinGetMinMax(hwnd) != 0)
        WinRestore(hwnd)
    WinSetStyle("-0xC40000", hwnd)
    WinMove(L, T, R - L, B - T, hwnd)
}

; is this the one being played (not a wall tile)
IsBig(hwnd) {
    try {
        if (WinGetMinMax(hwnd) = 1)
            return true
        MonitorGet(WallMonitor, &L, &T, &R, &B)
        WinGetPos(, , &w, , hwnd)
        return (w > (R - L) * 3 // 4)
    }
    return false
}

; instance under the mouse, 0 if none
IndexUnderMouse() {
    MouseGetPos(&mx, &my, &under)
    if (Inst.Length = 0 || !InstHas(under) && IsGameWindow(under)) {
        Rescan()
        MouseGetPos(&mx, &my, &under)
    }
    for i, hwnd in Inst
        if (hwnd = under)
            return i
    ; over the projector, so work it out from the 2x2 grid on that monitor
    loop MonitorGetCount() {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (mx >= L && mx < R && my >= T && my < B) {
            GridSize(Inst.Length, &cols, &rows)
            col := Floor((mx - L) * cols / (R - L))
            row := Floor((my - T) * rows / (B - T))
            i := row * cols + col + 1
            return (i <= Inst.Length) ? i : 0
        }
    }
    return 0
}

; take focus off the instances so new worlds pause when they load
; (1.0 pauses when it loses focus)
FocusWall() {
    if (UseProjector && WinExist(ProjectorTitle " ahk_exe obs64.exe")) {
        WinActivate
    } else {
        try WinActivate("ahk_class Progman")
        catch
            try WinActivate("ahk_class Shell_TrayWnd")
    }
    ; game isn't focused anymore so it won't get these keys
    if (SwitchObsScenes && UseProjector && Playing = 0)
        Send ObsWallSceneKey
}

OnWall(*) {
    if (Playing != 0)
        return false
    active := WinExist("A")
    ; maximized = being played, let the keys go to the game
    if (IsGameWindow(active) && IsBig(active))
        return false
    for hwnd in Inst
        if (hwnd = active)
            return true
    if (WinActive("ahk_class Shell_TrayWnd") || WinActive("ahk_class Progman") || WinActive("ahk_class WorkerW"))
        return true
    if IsGameWindow(active)
        return true
    if (UseProjector && WinActive(ProjectorTitle " ahk_exe obs64.exe"))
        return true
    return false
}

WallOrGame(*) {
    return !Busy && (OnWall() || IsGameWindow(WinExist("A")))
}

InGame(*) {
    return (Playing >= 1 && Playing <= Inst.Length && !Busy && WinActive(Inst[Playing]))
}

; works out where a 1.0 button is, using the game's own gui scale maths
ClickButton(hwnd, which) {
    if !WinExist(hwnd)
        return
    ; bring it to the front first, skip the wait if it's already there
    if (!BackgroundClicks && !WinActive(hwnd)) {
        WinActivate(hwnd)
        WinWaitActive(hwnd, , 1)
        Sleep ClickFocusDelay
    }
    WinGetClientPos(&cx, &cy, &cw, &ch, hwnd)
    limit := (GuiScaleSetting = 0) ? 1000 : GuiScaleSetting
    s := 1
    while (s < limit && cw // (s + 1) >= 320 && ch // (s + 1) >= 240)
        s++
    w := Ceil(cw / s), h := Ceil(ch / s)
    switch which {
        ; save and quit and singleplayer get clicked near their left end. if a
        ; reset has to go round again these can land on the wrong screen, and
        ; there they're empty space: the gaps on the title screen and pause
        ; menu, and left of More World Options and below Game Mode on create
        ; new world. on select world they can only pick a world, never open one
        case "savequit":     gx := w // 2 - 90, gy := h // 4 + 120  ; Save and Quit to Title
        case "backtogame":   gx := w // 2,      gy := h // 4 + 18   ; Back to Game
        case "singleplayer": gx := w // 2 - 90, gy := h // 4 + 64   ; Singleplayer
        ; create new world gets clicked near its right end. that spot is empty on
        ; the title screen (quit game ends at w/2+100), the pause menu and create
        ; new world (cancel starts at h-28), so it's safe to click again
        case "create":       gx := w // 2 + 130, gy := h - 42       ; Create New World
    }
    x := cx + Floor((gx + 0.5) * s), y := cy + Floor((gy + 0.5) * s)
    if BackgroundClicks
        BgClick(hwnd, x, y)
    else
        SlowClick(x, y)
}

; the LWJGL window inside the frame that actually gets input
InputWindow(hwnd) {
    try {
        for ctrl in WinGetControlsHwnd(hwnd)
            if (WinGetClass(ctrl) = "LWJGL")
                return ctrl
    }
    return hwnd
}

; click without bringing the window to the front (doesn't work on 1.0)
BgClick(hwnd, x, y) {
    target := InputWindow(hwnd)
    pt := Buffer(8, 0)
    DllCall("ClientToScreen", "ptr", target, "ptr", pt)
    lx := x - NumGet(pt, 0, "int"), ly := y - NumGet(pt, 4, "int")
    lp := (ly << 16) | (lx & 0xFFFF)
    DllCall("PostMessage", "ptr", target, "uint", 0x200, "ptr", 0, "ptr", lp)   ; mouse move
    Wait(30)
    DllCall("PostMessage", "ptr", target, "uint", 0x201, "ptr", 1, "ptr", lp)   ; left button down
    Wait(50)
    DllCall("PostMessage", "ptr", target, "uint", 0x202, "ptr", 0, "ptr", lp)   ; left button up
    Wait(20)
}

; Enter without bringing the window to the front
BgEnter(hwnd) {
    target := InputWindow(hwnd)
    DllCall("PostMessage", "ptr", target, "uint", 0x100, "ptr", 0x0D, "ptr", 0x001C0001)  ; key down
    DllCall("PostMessage", "ptr", target, "uint", 0x102, "ptr", 0x0D, "ptr", 0x001C0001)  ; character
    Wait(40)
    DllCall("PostMessage", "ptr", target, "uint", 0x101, "ptr", 0x0D, "ptr", 0xC01C0001)  ; key up
}

; move, wiggle so the game notices the mouse, then press and release.
; old LWJGL misses clicks that are too fast
SlowClick(x, y) {
    MouseMove(x, y, 0)
    Wait(30)
    MouseMove(x + 1, y, 0)
    MouseMove(x, y, 0)
    Wait(30)
    Click("Down")
    Wait(50)
    Click("Up")
    Wait(20)
}

; Enter on the create world screen. world keeps its default name, no renaming
FinishCreate(i) {
    hwnd := Inst[i]
    if !WinExist(hwnd)
        return
    if BackgroundClicks {
        BgEnter(hwnd)
        return
    }
    ; usually still in front from the create click, so only a short wait
    ; for the create world screen to open
    if WinActive(hwnd)
        Sleep 50
    else {
        WinActivate(hwnd)
        WinWaitActive(hwnd, , 1)
        Sleep ClickFocusDelay
    }
    Send "{Enter}"
    ; second Enter in case the first got ignored, does nothing once the world's generating
    Sleep 50
    Send "{Enter}"
}

; resets a list of instances side by side: step 1 on all of them, then step 2...
ResetList(list, alreadyQuit := false, refocus := true) {
    global Busy, TrimScheduled
    if (list.Length = 0 || Busy)
        return
    Busy := true
    SetPriorities(0)
    CountResets(list.Length)
    try ResetSteps(list, alreadyQuit, refocus)
    finally Busy := false
    ; give the new worlds a few seconds to generate before deleting anything,
    ; doing both at once was causing lag spikes. only the first reset starts
    ; the countdown, so fast resetting can't keep pushing it back
    if (PendingTrim.Count > 0 && !TrimScheduled) {
        TrimScheduled := true
        SetTimer(TrimPending, -3000)
    }
}

ResetSteps(list, alreadyQuit, refocus) {
    MouseGetPos(&ox, &oy)
    started := FileTimeNow()
    ; a world that's been played takes longer to save, so Y / F6 in game
    ; gets its own wait
    saveWait := alreadyQuit ? DelayAfterLeaving : Max(DelayAfterSaveQuit, LearnedWait)
    ; each instance goes save and quit > singleplayer > create > enter, then
    ; the saves folder gets checked for a new world. no new world = it goes
    ; round singleplayer > create > enter again. every click spot is empty on
    ; the screens it isn't meant for, so going round again can't do anything bad
    ; ready[i] = when instance i's next click can happen. whichever is ready
    ; first goes next, so while one waits the others get clicked
    ready := Map(), step := Map(), tries := Map(), listClick := Map(), requit := Map()
    canCheck := Map()
    ; never more than this long on one reset, in case a window closed or froze
    deadline := A_TickCount + 20000
    for i in list {
        if !alreadyQuit {
            QuitTime[i] := A_Now
            ClickButton(Inst[i], "savequit")
        }
        ; old worlds get deleted after the reset (TrimPending), deleting
        ; here held up every singleplayer click
        if DeleteResetWorlds
            PendingTrim[i] := true
        ready[i] := A_TickCount + saveWait
        step[i] := "singleplayer"
        tries[i] := 0
        listClick[i] := 0
        requit[i] := 0
        ; no saves folder = no way to tell if a world got made, so it just
        ; goes through once like before
        canCheck[i] := (SavesDir(i) != "")
    }
    left := list.Clone()
    failed := []
    ; lag on the one being clicked is what makes clicks get missed, and the
    ; lag comes from the others making their worlds. so while it's clicking,
    ; the ones it isn't clicking get a lower priority. back to normal after
    BusyPriorities(left)
    while (left.Length > 0) {
        n := 1
        for k, i in left
            if (ready[i] < ready[left[n]])
                n := k
        i := left[n]
        WaitUntil(ready[i])
        if (canCheck[i] && MadeNewWorld(i, started)) {
            if (!alreadyQuit && requit[i] = 0)
                LearnSaveWait(tries[i] <= 1)
            left.RemoveAt(n)
            BusyPriorities(left)
            continue
        }
        if (!WinExist(Inst[i]) || A_TickCount > deadline)
            step[i] := "giveup"
        switch step[i] {
        case "singleplayer":
            ; still in the old world means save and quit got missed, usually
            ; from resetting it before 1.0 opened the pause menu. 1.0 only
            ; opens it once the window's been in the background for half a
            ; second, so it gets put in the background first
            if (tries[i] > 0 && !alreadyQuit && !LeftWorld(i, started)) {
                requit[i] += 1
                if (Mod(requit[i], 2) = 1) {
                    if WinActive(Inst[i])
                        FocusWall()
                    ready[i] := A_TickCount + 600
                } else {
                    QuitTime[i] := A_Now
                    ClickButton(Inst[i], "savequit")
                    ready[i] := A_TickCount + DelayAfterLeaving
                }
                continue
            }
            ; if it's already on select world this lands on the world list,
            ; and two clicks on a world under 250ms apart opens it. so never
            ; two singleplayer clicks closer than SafeListGap
            if (A_TickCount - listClick[i] < SafeListGap) {
                ready[i] := listClick[i] + SafeListGap
                continue
            }
            ClickButton(Inst[i], "singleplayer")
            listClick[i] := A_TickCount
            step[i] := "create"
            ready[i] := A_TickCount + (ClickTwice ? Max(DelayBetweenScreens, SafeListGap) : DelayBetweenScreens)
        case "create":
            ; ClickTwice: 1.0 sometimes ignores a click so each one's done twice
            if (ClickTwice && A_TickCount - listClick[i] >= SafeListGap) {
                ClickButton(Inst[i], "singleplayer")
                listClick[i] := A_TickCount
                Sleep ClickFocusDelay       ; give select world a moment
            }
            ClickButton(Inst[i], "create")
            step[i] := "enter"
            ready[i] := A_TickCount + DelayBetweenScreens
        case "enter":
            if ClickTwice
                ClickButton(Inst[i], "create")
            FinishCreate(i)
            tries[i] += 1
            if !canCheck[i] {
                left.RemoveAt(n)
                BusyPriorities(left)
                continue
            }
            ; a new world shows up straight away, so this is only a short
            ; wait before checking
            if (tries[i] > CreateRetries)
                step[i] := "giveup"
            else
                step[i] := "singleplayer"
            ready[i] := A_TickCount + 150
        case "giveup":
            ; out of tries and still no new world, leave it
            if (CreateRetries > 0)
                failed.Push(i)
            left.RemoveAt(n)
            BusyPriorities(left)
        }
    }
    SetPriorities(0)
    MouseMove(ox, oy, 0)
    if refocus
        FocusWall()
    if (failed.Length > 0) {
        names := ""
        for i in failed
            names .= (names = "" ? "" : ", ") i
        Notify("instance " names " didn't make a new world, press Y on it")
    }
}

; how long saving takes changes from PC to PC and with lag. a click on
; singleplayer while it's still saving gets thrown away, so this learns the
; wait as it goes: a bit longer after a reset that had to go round again,
; a bit shorter after one that worked first time. it never goes below
; DelayAfterSaveQuit, and starts there each time the script starts
LearnSaveWait(firstTime) {
    global LearnedWait
    if firstTime
        LearnedWait := Max(DelayAfterSaveQuit, LearnedWait - 15)
    else
        LearnedWait := Min(1500, Max(DelayAfterSaveQuit, LearnedWait) + 80)
}

; finds an instance's saves folder from the MultiMC path in its command line
SavesDir(i) {
    static cache := Map()
    if (i <= SavesFolders.Length && SavesFolders[i] != "")
        return SavesFolders[i]
    try pid := WinGetPID(Inst[i])
    catch
        return ""
    if cache.Has(pid)
        return cache[pid]
    dir := ""
    try {
        for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId=" pid) {
            if RegExMatch(proc.CommandLine, 'i)([A-Za-z]:[^"=;]*?[\\/]instances[\\/][^\\/";]+)', &m) {
                for sub in [".minecraft", "minecraft"]
                    if DirExist(m[1] "\" sub "\saves") {
                        dir := m[1] "\" sub "\saves"
                        break
                    }
            }
        }
    }
    cache[pid] := dir
    return dir
}

; true if a world started in instance i since `since`. a new world writes
; session.lock straight away, only its date is checked. also true if the
; saves folder can't be found, so nothing gets retried blindly
MadeNewWorld(i, since) {
    saves := SavesDir(i)
    if (saves = "")
        return true
    loop files saves "\*", "D"
        if (FileWriteTime(A_LoopFileFullPath "\session.lock") >= since)
            return true
    return false
}

; true if instance i saved a world since `since`. save and quit writes
; level.dat, only its date is checked, same as above
LeftWorld(i, since) {
    saves := SavesDir(i)
    if (saves = "")
        return true
    loop files saves "\*", "D"
        if (FileWriteTime(A_LoopFileFullPath "\level.dat") >= since)
            return true
    return false
}

; the time right now, exact to the millisecond. A_Now only goes to the
; second, so a world from the reset just before could pass as new
FileTimeNow() {
    DllCall("GetSystemTimeAsFileTime", "int64*", &t := 0)
    return t
}

; when a file was last changed, exact like above. -1 if it isn't there
FileWriteTime(path) {
    info := Buffer(36, 0)
    if !DllCall("GetFileAttributesExW", "str", path, "int", 0, "ptr", info)
        return -1
    return NumGet(info, 20, "int64")
}

; runs once a reset's done, so the deleting doesn't slow the clicks down
TrimPending() {
    global TrimScheduled
    ; never touch saves folders during a run, wait until back on the wall.
    ; mid reset, try again straight after it
    if (Playing != 0) {
        SetTimer(TrimPending, -2000)
        return
    }
    if Busy {
        SetTimer(TrimPending, -500)
        return
    }
    ; one world at a time, a second apart, so the disk never gets hammered.
    ; Critical makes a play key wait for this one delete to finish, so it can
    ; never still be deleting once you're in an instance
    Critical
    for i in PendingTrim {
        PendingTrim.Delete(i)
        if (TrimOldWorlds(i, 1, 1) > 0)
            PendingTrim[i] := true      ; still more to go
        break
    }
    if (PendingTrim.Count > 0)
        SetTimer(TrimPending, -1000)
    else
        TrimScheduled := false
}

; deletes the oldest worlds and keeps the newest KeepNewestWorlds.
; extraKeep: the new world already exists by the time this runs, so keep one
; more to still have KeepNewestWorlds from before it
; maxDelete caps how many go in one call, returns how many are still left
TrimOldWorlds(i, extraKeep := 0, maxDelete := 3) {
    saves := SavesDir(i)
    if (saves = "")
        return 0
    worlds := []
    loop files saves "\*", "D" {
        if (SubStr(A_LoopFileName, 1, StrLen(DeletableWorldName)) != DeletableWorldName)
            continue
        f := A_LoopFileFullPath "\level.dat"
        t := FileExist(f) ? FileGetTime(f) : A_LoopFileTimeModified
        worlds.Push({path: A_LoopFileFullPath, t: t})
    }
    extra := worlds.Length - KeepNewestWorlds - extraKeep
    if (extra <= 0)
        return 0
    ; oldest first
    loop worlds.Length {
        a := A_Index
        loop worlds.Length - a {
            b := A_Index + a
            if (worlds[b].t < worlds[a].t) {
                tmp := worlds[a], worlds[a] := worlds[b], worlds[b] := tmp
            }
        }
    }
    loop Min(extra, maxDelete) {
        old := worlds[A_Index].path
        loop 3 {
            try {
                DirDelete(old, true)
                break
            }
            Sleep 200
        }
    }
    return extra - Min(extra, maxDelete)
}

; Y: in game, quit and go back to the wall. on the wall, reset the one under the mouse
ResetKey() {
    global Playing
    active := WinExist("A")
    i := 0
    for n, hwnd in Inst
        if (hwnd = active)
            i := n
    if (i = 0 && IsGameWindow(active)) {
        Rescan()
        return
    }
    if (i > 0 && (Playing = i || IsBig(active))) {
        Playing := i
        ResetPlayingAndReturn()
        return
    }
    if (Playing = 0)
        ResetOne(IndexUnderMouse())
}

ResetOne(i) {
    if (i >= 1 && i <= Inst.Length) {
        Unlock(i)
        ResetList([i])
    }
}

ResetAll() {
    if (Inst.Length = 0)
        Rescan()
    list := []
    loop Inst.Length
        if !IsLocked(A_Index)
            list.Push(A_Index)
    ResetList(list)
}

PlayInstance(i) {
    global Playing, Busy
    if (i < 1 || i > Inst.Length || Busy)
        return
    hwnd := Inst[i]
    Busy := true
    Playing := i
    Unlock(i)
    ShowLocks()                     ; hide the lock pics while playing
    SetPriorities(i)
    ; reset LiveSplit first so a leftover timer can't turn the start into a
    ; split. double tap prevention ignores a 2nd key within 0.3s, so start
    ; goes after the click below
    if LiveSplitTimer
        Send LiveSplitResetKey
    resetAt := A_TickCount
    try {
        ; switch the OBS scene before the game gets focus
        if (SwitchObsScenes && UseProjector && i <= ObsInstanceSceneKeys.Length)
            Send ObsInstanceSceneKeys[i]
        WinActivate(hwnd)
        WinWaitActive(hwnd, , 1)
        FillMonitor(hwnd)
        Wait(300)                   ; let it catch up with the new size
        ClickButton(hwnd, "backtogame")
        if LiveSplitTimer {
            WaitUntil(resetAt + 350)
            Send LiveSplitStartKey
        }
    }
    finally Busy := false
}

FocusReset(i) {
    if (i < 1 || i > Inst.Length || Busy)
        return
    others := []
    loop Inst.Length
        if (A_Index != i && !IsLocked(A_Index))
            others.Push(A_Index)
    ResetList(others, false, false)
    PlayInstance(i)
}

ResetPlayingAndReturn() {
    global Playing, Busy
    i := Playing
    hwnd := Inst[i]
    Busy := true
    if LiveSplitTimer
        Send LiveSplitResetKey      ; run's over
    try {
        Send "{Esc}"                ; pause menu
        Sleep DelayBetweenScreens
        QuitTime[i] := A_Now
        ClickButton(hwnd, "savequit")
        Playing := 0
        ; back to the wall scene now, the game's on the saving screen so it
        ; won't get these keys
        if (SwitchObsScenes && UseProjector)
            Send ObsWallSceneKey
        Wait(150)
        Arrange(i)                  ; back on the wall
    }
    finally {
        Playing := 0
        SetPriorities(0)
        ShowLocks()
        Busy := false
    }
    if CreateWorldAfterLeaving
        ResetList([i], true)
    else
        FocusWall()
}

; R: lock / unlock. T and F skip locked ones, playing it or Y unlocks it
ToggleLock(i) {
    if (i < 1 || i > Inst.Length)
        return
    hwnd := Inst[i]
    if Locked.Has(hwnd) {
        Locked.Delete(hwnd)
    } else {
        Locked[hwnd] := true
        PlayLockSound("lock.wav")
    }
    ShowLocks()
}

Unlock(i) {
    if (i >= 1 && i <= Inst.Length && Locked.Has(Inst[i])) {
        Locked.Delete(Inst[i])
        ShowLocks()
    }
}

IsLocked(i) => (i >= 1 && i <= Inst.Length && Locked.Has(Inst[i]))

PlayLockSound(name) {
    f := A_ScriptDir "\" name
    if FileExist(f)
        try SoundPlay(f)
}

; lock pictures. with OBS it shows/hides the Lock sources, only sending keys
; when something changed (force sends all of them). without OBS it draws
; lock.png in the tile's corner, click-through, hidden while playing
ShowLocks(force := false) {
    static guis := Map(), sizes := Map(), obsShown := Map()
    useObs := UseProjector && ObsLockPictures
    if useObs {
        for i, hwnd in Inst {
            want := Locked.Has(hwnd)
            if (force || !obsShown.Has(i) || obsShown[i] != want) {
                keys := want ? ObsLockShowKeys : ObsLockHideKeys
                if (i <= keys.Length)
                    Send keys[i]
                obsShown[i] := want
            }
        }
    }
    for i, g in guis
        if (useObs || i > Inst.Length || Playing != 0 || !Locked.Has(Inst[i]))
            g.Hide()
    if (useObs || Playing != 0)
        return
    for i, hwnd in Inst {
        if !Locked.Has(hwnd) || !TileRect(i, &x, &y, &w, &h)
            continue
        size := Max(48, Round(Min(w, h) / 6))
        if (!guis.Has(i) || sizes[i] != size) {
            if guis.Has(i)
                guis[i].Destroy()
            guis[i] := MakeLockGui(size)
            sizes[i] := size
        }
        guis[i].Show("x" (x + 12) " y" (y + 12) " w" size " h" size " NoActivate")
    }
}

MakeLockGui(size) {
    ; on top, no border, no taskbar button, click-through
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80020 -DPIScale")
    g.BackColor := "1E1E1E"
    g.MarginX := 0, g.MarginY := 0
    f := A_ScriptDir "\lock.png"
    if FileExist(f) {
        g.Add("Picture", "x0 y0 w" size " h" size, f)
    } else {
        g.SetFont("s" Round(size / 5) " bold cF5C542")
        g.Add("Text", "x0 y0 w" size " h" size " Center 0x200", "LOCK")
    }
    DllCall("SetLayeredWindowAttributes", "ptr", g.Hwnd, "uint", 0, "uchar", 235, "uint", 2)
    return g
}

; where instance i is on the wall (its projector tile, or the window itself)
TileRect(i, &x, &y, &w, &h) {
    if UseProjector {
        if WinExist(ProjectorTitle " ahk_exe obs64.exe") {
            WinGetPos(&L, &T, &areaW, &areaH)
        } else {
            MonitorGet(WallMonitor, &L, &T, &R, &B)
            areaW := R - L, areaH := B - T
        }
        GridSize(Inst.Length, &cols, &rows)
        col := Mod(i - 1, cols), row := (i - 1) // cols
        x := L + col * areaW // cols, y := T + row * areaH // rows
        w := areaW // cols, h := areaH // rows
        return true
    }
    try {
        WinGetPos(&x, &y, &w, &h, Inst[i])
        return true
    }
    return false
}

; sets priority and cores for every instance. playing = 0 means on the wall
SetPriorities(playing) {
    if !FocusPlayedInstance
        return
    procMask := 0, sysMask := 0
    DllCall("GetProcessAffinityMask", "ptr", DllCall("GetCurrentProcess", "ptr")
        , "uptr*", &procMask, "uptr*", &sysMask)
    bgMask := BackgroundMask(sysMask)
    playMask := sysMask & ~bgMask       ; played one stays off the background cores
    if !playMask
        playMask := sysMask
    for n, hwnd in Inst {
        try pid := WinGetPID(hwnd)
        catch
            continue
        if (playing = 0)
            prio := "Normal", mask := sysMask
        else if (n = playing)
            prio := "AboveNormal", mask := playMask
        else
            prio := BackgroundPriority, mask := bgMask
        try ProcessSetPriority(prio, pid)
        SetAffinity(pid, mask)
    }
}

; during a reset: normal for the ones still being clicked, below normal for
; the rest. does nothing if FocusPlayedInstance is off
BusyPriorities(clicking) {
    if !FocusPlayedInstance
        return
    for n, hwnd in Inst {
        prio := "BelowNormal"
        for i in clicking
            if (i = n)
                prio := "Normal"
        SetInstPriority(n, prio)
    }
}

SetInstPriority(n, prio) {
    try ProcessSetPriority(prio, WinGetPID(Inst[n]))
}

; the last BackgroundCores cores (the played one usually sits on the first ones)
BackgroundMask(sysMask) {
    if (BackgroundCores <= 0)
        return sysMask
    mask := 0, count := 0, bit := 63
    while (bit >= 0 && count < BackgroundCores) {
        if ((sysMask >> bit) & 1) {
            mask |= 1 << bit
            count++
        }
        bit--
    }
    return mask ? mask : sysMask
}

SetAffinity(pid, mask) {
    if !mask
        return
    ; PROCESS_SET_INFORMATION | PROCESS_QUERY_INFORMATION
    h := DllCall("OpenProcess", "uint", 0x0600, "int", 0, "uint", pid, "ptr")
    if !h
        return
    DllCall("SetProcessAffinityMask", "ptr", h, "uptr", mask)
    DllCall("CloseHandle", "ptr", h)
}

; wait until a tick count. not affected by Speed, these are what keep
; clicks on the right screen
WaitUntil(t) {
    left := t - A_TickCount
    if (left > 0)
        Sleep left
}

ResetCountPath() {
    return A_ScriptDir "\" ResetCounterFile
}

; load last session's count
LoadResetCount() {
    global ResetCount
    if !ResetCounter
        return
    try {
        if RegExMatch(FileRead(ResetCountPath(), "UTF-8"), "(\d+)\D*$", &m)
            ResetCount := Integer(m[1])
    }
    WriteResetCount()
}

CountResets(n) {
    global ResetCount
    if !ResetCounter
        return
    ResetCount += n
    WriteResetCount()
}

WriteResetCount() {
    try {
        f := FileOpen(ResetCountPath(), "w", "UTF-8-RAW")
        f.Write(ResetCounterText ResetCount)
        f.Close()
    }
}

; sleep, shorter at higher Speed
Wait(ms) {
    Sleep Round(ms / Speed)
}
