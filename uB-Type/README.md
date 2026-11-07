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
- **Gameplay:** VZ-TYPE's own game logic, ported. With thinning switched off, a frame-by-frame comparison against the original running in a VZ300 model matches on every frame, apart from the frames where a life restarts (an artefact of how the test harness lines the two machines up).
- **Thinned for the Microbee.** To cut slowdown and suit keyboard play, μB-TYPE leaves out every fourth ordinary enemy (and a quarter of each swimming formation), fires every third enemy shot less, and allows at most 6 enemy bullets on screen at once instead of the VZ's 12. Carriers (the power-ups), reactor nodes and bosses are never thinned.
- **Graphics:** new artwork for all eight stages (terrain, sprites, capsules, explosions, boss bodies), plus a second glyph set made for monochrome monitors. The player's ship has a cockpit canopy whose glint slides across as the ship banks up and down, and its engine flame grows with speed.
- **Front end:**
  - choice of colour or monochrome monitor
  - title with the μB-TYPE logo, glint, starfield and scroller
  - hall of fame, how to play and power-ups pages
  - attract mode: the real game on a different stage each time, flown by an autopilot
  - stage intro, game over, name entry, and congratulations after stage 8
- **Lettering:** all the game's text (HUD, title pages, stage intros, the big headings and the capsule letters) uses a 70s 'future' face redrawn for the 8×16 cell, with its trademark double-width stroke on the lower left of each character.
- **Music:** VZ-TYPE's two-voice tunes, retimed for 3.375 MHz.

## Performance so far (emulator, same input on both machines, Microbee thinned)

| Stage | VZ300 start | Microbee start | VZ300 boss | Microbee boss |
|---|---|---|---|---|
| 1 Outer Hull | 22.5 | 21.8 | 22.2 | 18.4 |
| 2 The Hive | 21.0 | 20.6 | 21.7 | 17.4 |
| 3 Rock Belt | 22.9 | 21.9 | 20.8 | 16.8 |
| 4 Crystal Vein | 22.4 | 22.6 | 21.9 | 19.1 |
| 5 Dreadnought | 20.6 | 17.1 | 20.7 | 15.9 |
| 6 Gut Caverns | 22.7 | 22.8 | 22.1 | 18.5 |
| 7 Deep Field | 22.8 | 21.3 | 21.9 | 18.3 |
| 8 The Core | 22.8 | 22.4 | 21.2 | 16.6 |

Frames per second. Both machines cap at 25 frames per second.

Lighter scenes run at the VZ's speed. Busy scenes and the bosses are slower (about 75–90% of the VZ's speed), because every sprite cell is rebuilt as a PCG glyph each frame. Each frame takes either 2 or 3 fields (25 or 16.7 fps), so the figures are the mix of the two. The details, including how the gameplay, sound and disk were checked, are in `VERIFICATION.md`.

## Building

Needs Python 3 with numpy and Pillow, plus gcc for the test emulator. Run `./build.sh` in `src/`. It builds everything into `src/build/`, including `UBTYPE.DS8`. `src/tools/boottest.py <boot ROM> <dir>` boots the disk in the emulator with a Microbee boot ROM, which is not included.
