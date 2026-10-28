; wall settings
; change whatever you want here, save, then right click the green H > Reload Script
; run MC-1.0-Wall.ahk, not this file

; has to match GUI Scale in video settings. 0 auto, 1 small, 2 normal, 3 large
GuiScaleSetting := 0

; ms to wait after save and quit before clicking singleplayer. this is the
; shortest it'll wait, the script makes it longer on its own if your saves
; take longer (it goes back down when they don't)
DelayAfterSaveQuit := 50

; same thing but for Y / F6 while playing. a world you've been in takes
; longer to save, and there's no other instance to click in the meantime,
; so this one stays higher
DelayAfterLeaving := 1000

; wait between the other menus, raise if clicks get missed
DelayBetweenScreens := 250

; Y/F6 in game: true makes a new world after quitting, false stops on the title screen
CreateWorldAfterLeaving := true

; click every menu twice. older versions of the wall needed this because
; 1.0 would sometimes ignore a click, but the reset's been reworked since
; and single clicks are reliable now, so it's off. turn it on if an
; instance keeps getting stuck on a menu (costs about a second per reset)
ClickTwice := false

; after clicking create + enter, the saves folder gets checked for a new
; world (just the file dates). if there isn't one it goes round
; singleplayer > create > enter again. this is how many times it goes round
; before giving up, 0 = off
CreateRetries := 6

; click speed: 1 slow, 2 fast, 3 faster. doesn't change the menu delays.
; back to 2 if clicks get ignored
Speed := 2

; background clicks don't work on 1.0, keep false
BackgroundClicks := false

; delete the oldest New World folders on reset so saves doesn't fill up.
; always keeps the newest KeepNewestWorlds (the 5 before a run have to be
; kept, A.7.8). cleared with a mod
DeleteResetWorlds := true

; how many of the newest worlds to keep
KeepNewestWorlds := 6

; only folders starting with this get deleted. rename a world's folder
; (like RUN 1) to keep it
DeletableWorldName := "New World"

; leave empty to find saves automatically. if Ctrl+Alt+D says NOT FOUND,
; put the path in, e.g. "C:\MultiMC\instances\YourInstanceA\.minecraft\saves"
SavesFolders := ["", "", "", ""]

; opens the instances through MultiMC when you run the script, if none are
; open yet. they open one at a time in this order, so the first one is
; instance 1. names are the instance folder names (right click an instance
; in MultiMC > Instance Folder to see it). false = open them yourself
LaunchInstances := false
MultiMCPath := ""
InstanceFolders := ["", "", "", ""]
TitleScreenWait := 8000         ; ms to give the last one to reach the title screen

; wait after switching to a window before clicking, raise if clicks get missed
ClickFocusDelay := 100

; false = played instance just gets maximized (runs better on 1.0) imo
; true = borderless fullscreen
Borderless := false

; only used without the projector. false = wall stops above the taskbar,
; true = whole screen
WallFillsWholeScreen := false

; which monitor, 1 = main
WallMonitor := 1

; true = the wall is the OBS projector of the 1.0 Wall scene and the
; instances sit fullscreen behind it. false = tile the actual windows 2x2
UseProjector := true
ProjectorTitle := "1.0 Wall"    ; obs wall scene name

; OBS scene hotkeys, same ones go in OBS settings > hotkeys
SwitchObsScenes := true
ObsWallSceneKey := "^!+0"       ; Ctrl+Alt+Shift+0
ObsInstanceSceneKeys := ["^!+1", "^!+2", "^!+3", "^!+4"]   ; Ctrl+Alt+Shift+1..4

; lock pictures in OBS (Lock 1-4 sources in 1.0 Wall), shown and hidden
; with these hotkeys. false = draw them on screen instead (not on the recording)
ObsLockPictures := true
ObsLockShowKeys := ["^!+5", "^!+6", "^!+7", "^!+8"]   ; Ctrl+Alt+Shift+5..8
ObsLockHideKeys := ["^!+z", "^!+x", "^!+c", "^!+v"]   ; Ctrl+Alt+Shift+Z, X, C, V

; LiveSplit starts on play and resets on Y/F6. needs global hotkeys on and
; the same keys as LiveSplit. Esc > save and quit leaves the timer alone
LiveSplitTimer := true
LiveSplitStartKey := "{vkDE}"      ; LiveSplit "Start / Split" (Oem7)
LiveSplitResetKey := "{vkBA}"      ; LiveSplit "Reset" (Oem1)

; reset counter, written to resets.txt for an OBS text source.
; carries over between sessions, delete the file to start from 0
ResetCounter := true
ResetCounterFile := "resets.txt"
ResetCounterText := "Resets: "  ; text before the number

; while playing, the other instances get low priority and only
; BackgroundCores cores, and the played one stays off those cores.
; everything goes back to normal on the wall
FocusPlayedInstance := true
BackgroundCores := 1            ; 0 = no limit
; Low or BelowNormal
BackgroundPriority := "Low"

; hotkeys
KeyPlay := "w"
KeyPlay2 := "e"                 ; set to "" to turn off
KeyReset := "y"
KeyResetAll := "t"
KeyFocusReset := "f"
KeyLock := "r"                  ; lock / unlock
KeyResetWhilePlaying := "F6"
KeyRescan := "^!l"              ; Ctrl+Alt+L
