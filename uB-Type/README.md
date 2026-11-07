# μB-TYPE (work in progress)

μB-TYPE is the Microbee Premium Plus conversion of **VZ-TYPE**, BPM's original R-Type-inspired horizontal shooter for the VZ300.

VIBED BY BPM 2026.

**Status: playable from the disk image.** BPM has played it on his Microbee Premium Plus. The measurements and automated checks in `VERIFICATION.md` come from an emulator (the Premium Plus model in `src/tools/emu`).

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
- **Thinned for the Microbee.** To cut slowdown and suit keyboard play (BPM's call), μB-TYPE: keeps about 9 in 16 ordinary enemies, and 9/16 of each swimming formation; lets each gun turret have only one bullet in the air, fired faster (5/4 of the table speed instead of 5/8) so it leaves the turret instead of scrolling along with it; fires one enemy shot in three less; allows at most 5 enemy bullets at once (the VZ allows 12); keeps boss minion waves smaller; and aims the kamikaze darts one or two compass points off. Power-up carriers, reactor nodes and bosses are never thinned. Stage 1 also loses its round floating blocks, which sat in the flight path.
- **Graphics:** new artwork for all eight stages (terrain, sprites, capsules, explosions, boss bodies), plus a second glyph set made for monochrome monitors. Round things (capsules, pod, bullets, block corners) are drawn for the shape of a 4:3 screen, where a Microbee pixel is about 1.5 times taller than wide. The player's ship is a slim swept dart with a cockpit window set into a low fairing, whose glint slides along as the ship banks up and down, and its engine flame grows with speed.
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
| 1 Outer Hull | 22.5 | 22.5 | 22.2 | 19.3 |
| 2 The Hive | 21.0 | 23.2 | 21.7 | 18.2 |
| 3 Rock Belt | 22.9 | 22.5 | 20.8 | 17.4 |
| 4 Crystal Vein | 22.4 | 22.9 | 21.9 | 19.2 |
| 5 Dreadnought | 20.6 | 19.5 | 20.7 | 16.0 |
| 6 Gut Caverns | 22.7 | 22.8 | 22.1 | 18.6 |
| 7 Deep Field | 22.8 | 21.8 | 21.9 | 19.1 |
| 8 The Core | 22.8 | 22.9 | 21.2 | 17.7 |

Frames per second. Both machines cap at 25 frames per second.

Every stage now plays at or near the VZ's speed from the start. The bosses are slower (about 75–90% of the VZ's speed), because every sprite cell is rebuilt as a PCG glyph each frame. Each frame takes either 2 or 3 fields (25 or 16.7 fps), so the figures are the mix of the two. The details, including how the gameplay, sound and disk were checked, are in `VERIFICATION.md`.

## Building

Needs Python 3 with numpy and Pillow, plus gcc for the test emulator. Run `./build.sh` in `src/`. It builds everything into `src/build/`, including `UBTYPE.DS8`. `src/tools/boottest.py <boot ROM> <dir>` boots the disk in the emulator with a Microbee boot ROM, which is not included.
