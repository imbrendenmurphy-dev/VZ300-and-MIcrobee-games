# μB-TYPE (work in progress)

μB-TYPE is the Microbee Premium Plus conversion of **VZ-TYPE**, BPM's original R-Type-inspired horizontal shooter for the VZ300.

Directed and playtested by BPM. Code, graphics and music by Claude (Anthropic).

**Status: playable from the disk image, still being optimised.** So far it has been tested only in an emulator (the Premium Plus model in `src/tools/emu`), not on real hardware.

## Running it

1. Boot `release/UBTYPE.DS8` on a Premium Plus with 1MB of RAM. The disk boots to the CP/M `A>` prompt. It has no Microbee shell.
2. Type `UBTYPE` and press RETURN. The loader fills the memory banks, which took about 40 seconds in the emulator.
3. Choose your monitor: **C** for colour, **M** for monochrome.

| Key | Action |
|---|---|
| Q A O P or cursor keys | move |
| SPACE | fire; hold it to charge the beam |
| M or Z | launch or recall the pod |
| H | pause (X while paused ends the game) |
| ESC or RETURN | back to the title |
| T on the title | trainer mode (no high scores) |

A joystick on the parallel port also works.

## What's in it

- **Display:** 64×16 characters of 8×16 PCG cells (512×256, exactly 4× the VZ300's 128×64).
- **Scrolling:** smooth and tear-free. The game uses the 6545 start address with two screen pages and pre-shifted glyphs, scrolls one VZ pixel (4 Microbee pixels) per frame as on the VZ, and flips pages in vertical blank.
- **Gameplay:** VZ-TYPE's own game logic, ported. A frame-by-frame comparison against the original running in a VZ300 model matches on every frame, apart from the frames where a life restarts. Those frames differ only because of how the test harness lines the two machines up.
- **Graphics:** new artwork for all eight stages (terrain, sprites, capsules, explosions, boss bodies), plus a second glyph set made for monochrome monitors. The player's ship has a cockpit canopy whose glint slides across as the ship banks up and down, and its engine flame grows with speed.
- **Front end:**
  - choice of colour or monochrome monitor
  - title with the μB-TYPE logo, glint, starfield and scroller
  - hall of fame, how to play and power-ups pages
  - attract mode: the real game on a different stage each time, flown by an autopilot
  - stage intro, game over, name entry, and congratulations after stage 8
- **Lettering:** all the game's text (HUD, title pages, stage intros, the big headings and the capsule letters) uses a 70s 'future' face redrawn for the 8×16 cell, with its trademark double-width stroke on the lower left of each character.
- **Music:** VZ-TYPE's two-voice tunes, retimed for 3.375 MHz.

## Performance so far (emulator, identical gameplay on both machines)

| Stage | VZ300 start | Microbee start | VZ300 boss | Microbee boss |
|---|---|---|---|---|
| 1 Outer Hull | 22.5 | 21.9 | 22.2 | 17.8 |
| 2 The Hive | 21.0 | 18.5 | 21.7 | 16.5 |
| 3 Rock Belt | 22.9 | 21.7 | 20.8 | 16.1 |
| 4 Crystal Vein | 22.4 | 22.6 | 21.9 | 19.4 |
| 5 Dreadnought | 20.6 | 15.4 | 20.7 | 14.7 |
| 6 Gut Caverns | 22.7 | 22.8 | 22.1 | 17.7 |
| 7 Deep Field | 22.8 | 21.2 | 21.9 | 17.6 |
| 8 The Core | 22.8 | 22.1 | 21.2 | 15.4 |

Frames per second. Both machines cap at 25 frames per second.

Lighter scenes run at the VZ's speed. Busy scenes and the bosses are slower (about 75–90% of the VZ's speed), because every sprite cell is rebuilt as a PCG glyph each frame. The details, including how the gameplay, sound and disk were checked, are in `VERIFICATION.md`.

## Building

Needs Python 3 with numpy and Pillow, plus gcc for the test emulator. Run `./build.sh` in `src/`. It builds everything into `src/build/`, including `UBTYPE.DS8`. `src/tools/boottest.py <boot ROM> <dir>` boots the disk in the emulator with a Microbee boot ROM, which is not included.
