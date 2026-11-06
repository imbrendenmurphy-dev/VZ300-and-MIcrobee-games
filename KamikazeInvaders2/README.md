# KAMIKAZE INVADERS 2 — "The Mothership Strikes Back"

Sequel to the VZ200/VZ300 game *KAMIKAZE INVADERS* for the Dick Smith VZ300 / VZ200.
ViBED by BPM 2026. Original code, graphics and music. Nothing from the original game is included.

> Work in progress. Progress is saved here as it goes.

## Play it

Copy `release/KAMI2.VZ` to the SD card and load it from the BennVenn SD loader. It loads low at $8000 and runs from $8000. It needs the **BennVenn 128K** RAM expansion (RAM up to $FFFF).

| Action | Keyboard | Joystick |
|---|---|---|
| Move | M left · `,` right (the original's arrow keys) | either stick |
| Fire | SPACE or SHIFT | fire |
| Start | SPACE, S, RETURN or fire | fire |
| Start at sector 1–4 | keys 1–4 on the title screen | — |
| Pause (X quits while paused) | P | — |
| Quit game | CTRL + BREAK (as the original) | — |
| Sound: music+SFX → SFX only → off | S (in game) | — |
| Name entry | move the box over the letter grid, fire or RETURN picks | stick + fire |

## Build

Needs Python 3 with Pillow, and sjasmplus (https://github.com/z00m128/sjasmplus) on your PATH.

```
cd src
./build.sh          # -> ../build/KAMI2.VZ (a finished copy is in release/)
```
