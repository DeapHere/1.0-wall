# Minecraft 1.0 RSG Wall

This is a 4 instance wall for 1.0 random seed runs. The script resets your instances by clicking through the normal menus (save and quit, singleplayer, create new world, enter), and when you see a seed you like you just play it. The wall itself is an OBS fullscreen projector.

Keep all of these in one folder please:

- `MC-1.0-Wall.ahk` - the script, this is the one you run
- `Wall-Settings.ahk` - all the settings, this is the one you edit
- `lock.png` and `lock.wav` - the lock picture and sound
- `resets.txt` - your reset count, the script makes this itself
- `SETUP-GUIDE.md` - this file megalul

---

## 1. Instances

Make four copies of your 1.0 instance in MultiMC. I call them A, B, C and D (like `1.0 A` to `1.0 D`). Each one has its own `.minecraft` folder, which you need anyway for rule A.9.1.

On each one go to Edit Instance > Settings > Java and set:

- Java to JDK 17
- Memory to 2048 min and 2048 max. Having them the same stops Java resizing its memory mid run, which causes lag spikes.

Also set the same GUI Scale in all four. Auto is fine.

## 2. AutoHotkey

Get AutoHotkey v2 from autohotkey.com (Download > v2.0). It has to be v2, v1 won't run the script.

## 3. OBS

Before doing anything in OBS, open the 4 instances in order (A, B, C, D) and run the script once. That renames the windows to `Minecraft 1.0 - Wall 1` up to `Wall 4`, so OBS can find them. A is instance 1 and D is instance 4.

### Instance scenes

Make 4 scenes called `Instance 1` to `Instance 4`. In each one add a Game Capture source called `Wall 1` to `Wall 4` (not Window Capture, that just shows 1.0 as a white box). Set it to:

- Mode: Capture specific window
- Window: `[javaw.exe]: Minecraft 1.0 - Wall N`
- Window Match Priority: Window title must match
- Capture Cursor: off, otherwise you get a second cursor on the projector

### Wall scene

Make a scene called exactly `1.0 Wall`. Add your four Wall sources to it (+ > Game Capture > Add Existing), make each one 960 x 540 and put them here:

```
Wall 1   0, 0        Wall 2   960, 0
Wall 3   0, 540      Wall 4   960, 540
```

### Lock pictures

Still in `1.0 Wall`, add four Image sources using `lock.png`, each 90 x 90, and drag them above the Wall sources in the list:

```
Lock 1   12, 12      Lock 2   972, 12
Lock 3   12, 552     Lock 4   972, 552
```

### Reset counter

The script writes your reset count to `resets.txt` in its own folder (it shows up the first time you run it). To put it on screen, add a Text (GDI+) source called `Resets` in any scene, tick Read from file, and pick `resets.txt`. Font, size and colour are up to you.

It shows as `Resets: 123` and goes up every reset. It carries over between sessions, so if you want to start from 0 again just delete `resets.txt`.

### Hotkeys

In Settings > Hotkeys set these up, the script presses them for you:

```
1.0 Wall scene            Ctrl+Alt+Shift+0
Instance 1 to 4 scenes    Ctrl+Alt+Shift+1 to 4

Lock 1    show Ctrl+Alt+Shift+5    hide Ctrl+Alt+Shift+Z
Lock 2    show Ctrl+Alt+Shift+6    hide Ctrl+Alt+Shift+X
Lock 3    show Ctrl+Alt+Shift+7    hide Ctrl+Alt+Shift+C
Lock 4    show Ctrl+Alt+Shift+8    hide Ctrl+Alt+Shift+V
```

Then right click `1.0 Wall` > Fullscreen Projector > your monitor, and that's your wall.

## 4. LiveSplit

The timer starts when you play an instance (W, E or F) and resets when you leave with Y or F6. If you leave with Esc > Save and quit to title instead, nothing gets sent, so the timer stays put for a run you want to keep.

In LiveSplit right click > Settings, turn Global Hotkeys on and set Start / Split to Oem7 and Reset to Oem1. You can use other keys if you want, just change `LiveSplitStartKey` and `LiveSplitResetKey` in the settings to match. If you don't want the script touching LiveSplit at all, set `LiveSplitTimer := false`.

Heads up, Oem7 and Oem1 are different keys depending on your keyboard layout, so if the timer doesn't start, that's probably why.

## 5. Starting a session

Open A to D in order, wait for the title screens, then run `MC-1.0-Wall.ahk`. A green H shows up in the tray and the instances go fullscreen behind the projector. Press T to make your first set of worlds and you're going.

If you want the script to open the instances for you, set these once in `Wall-Settings.ahk`:

- `LaunchInstances := true`
- `MultiMCPath` - where your `MultiMC.exe` is, like `C:\MultiMC\MultiMC.exe`
- `InstanceFolders` - each instance's folder name, A to D. Right click an instance in MultiMC > Instance Folder, and the name of that folder is what goes here.

Then it'll open them one at a time when you run it, wait for the title screens, and you can just press T.

If you close or reopen an instance, Ctrl+Alt+L finds the windows again. To stop the script, right click the green H > Exit.

## 6. Keys

On the wall the keys work on whichever instance your mouse is over, you don't need to click anything.

- **T** - reset all of them (locked ones get skipped)
- **Y** - reset this one
- **W / E** - play this one
- **F** - play this one and reset the rest (locked ones get skipped)
- **R** - lock / unlock

In game, **Y** or **F6** saves and quits, makes a new world and puts you back on the wall.

A few things to know:

- The mouse moves on its own while it's resetting, that's just the script clicking the menus.
- Y / F6 works from the death screen too, and if your inventory was open it sorts itself out, it just takes a couple of seconds longer.
- Playing a locked instance or resetting it with Y unlocks it.
- If you want to keep a run, leave with Esc > Save and quit to title instead of Y. Then rename its folder in that instance's `.minecraft\saves` to something like `RUN 1` so auto delete never touches it. Renaming the world in game doesn't change the folder name, so do it in the folder.

## 7. Settings

Everything's in `Wall-Settings.ahk`. Open it in Notepad, change what you want, save, then right click the green H > Reload Script. The ones you'll most likely touch:

- `DelayAfterSaveQuit` (50) - the shortest it waits after save and quit before clicking singleplayer. If your saves take longer the script works that out and waits longer on its own.
- `DelayAfterLeaving` (1000) - same thing but for Y / F6 in game, a world you've played saves slower.
- `DelayBetweenScreens` (250) - wait between the other menus.
- `ClickFocusDelay` (100) - wait after bringing an instance to the front before clicking.
- `ClickTwice` (false) - clicks every menu twice. Older versions needed it, now it's only worth turning on if instances keep getting stuck.
- `CreateRetries` (6) - if an instance didn't make a new world, it goes through singleplayer, create new world and enter again, up to this many times. If it's still in the old world it puts it in the background for a second (so 1.0 opens the pause menu) and quits it again first. 0 turns it off.
- `DeleteResetWorlds` (true) - deletes old New World folders, one at a time between resets and never during a run.
- `KeepNewestWorlds` (6) - how many worlds each instance always keeps.
- `BackgroundCores` (1) - how many CPU cores the other instances get while you're playing one.
- `LaunchInstances` (false) - open the instances through MultiMC when the script starts.
- `LiveSplitTimer` (true) - start / reset LiveSplit when you play and leave.
- `ResetCounter` (true) and `ResetCounterText` ("Resets: ") - the reset count file and the text in front of the number.

The hotkeys are at the bottom of the file if you want different keys.

## 8. If something's not working

- **Reset stops on the title screen or clicks Texture Packs:** raise `DelayAfterSaveQuit`. If it only happens on Y / F6 in game, raise `DelayAfterLeaving` instead. You shouldn't need to, since it tries again on its own.
- **Instances getting stuck on a menu:** raise `ClickFocusDelay` or `DelayBetweenScreens`, or turn `ClickTwice` on.
- **Clicks landing in the wrong spot:** make sure all four have the same GUI Scale and that it matches `GuiScaleSetting` (0 is Auto).
- **Projector shows a white box:** you're using Window Capture, switch to Game Capture.
- **OBS stuck on an instance scene:** check the scene hotkeys in OBS match.
- **Lag while playing:** lower `BackgroundCores`, and check memory is 2048 / 2048.
- **Keys do nothing:** the projector or desktop has to be focused. Press Ctrl+Alt+L.

---

## Rules

This is going off the speedrun.com Minecraft Java rules (v8).

- **Multi instance:** every instance needs its own folder (A.9.1) and all of them have to be recorded (A.9.2). Pausing the others while you play one is fine (A.3.6.a), but switching instances mid run makes that run unverifiable (A.3.6).
- **Resets:** every reset comes from a key press (A.10.5). One key resetting more than one instance is allowed. The script doesn't read your screen.
- **During a run:** no macros apart from resizing (A.10.4). The play key only unpauses before the run starts, and Y / F6 ends the run.
- **Pause on lost focus** stays on (A.6.2.b). 1.0 doesn't have an option to turn it off anyway.
- **F3:** can't be shown before or during a run on anything before 1.3 (B.2.1).
- **Mods:** only builds on the legal-builds list (A.8.5).
- **Worlds:** you have to keep the 5 worlds before a run (A.7.8). Auto delete always keeps the newest 6 plus the one that was just made. Keep the world folder of anything you submit (sub 30 or WR pace) until it's verified (A.7.2.a).
- **Auto delete:** only reads folder names and file dates, never what's inside the files, and never runs during a run. This was cleared with a moderator.
- **New world check:** after a reset the script looks at the date on `session.lock` in the saves folder to see if a new world started, and goes through the menus again if it didn't. It also looks at the dates on `level.dat` to tell if save and quit got missed (1.0 saves it every 2 seconds while a world is running, and once when you quit). Same as auto delete, it only reads the dates.

Full rules are here: [Minecraft Java Edition speedrunning rules (v8)](https://github.com/Minecraft-Java-Edition-Speedrunning/rules/blob/main/pub/pdf/rules_v8.pdf)
