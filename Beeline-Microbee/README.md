# BEELINE (working title) — Microbee Premium Plus 3D racer

Engine milestone (phases 1–3 of the brief): hardware investigation, rendering experiments and benchmarks for a 3D racing game on the Microbee Premium Plus, native Z80.

VIBED BY BPM 2026

![RACE in the emulator](screenshots/race_themes.png)

## Loading

Boot `release/BEELINE.DS8`, then type a program name at the `A>` prompt:

| Program | What it is |
|---|---|
| `RACE` | Pseudo-3D "PCG strip" road: curves, hills, crests, kerbs, dithered bands, page flipping, 3 colour themes. FPS on the top line. |
| `BENCH` | Video RAM speed test. Wait ~8 s, photograph the screen. Emulator figures: 591 599 474 472 472 973 599. |
| `CUBE` | Solid polygon test: a dither-shaded cube rasterised live into a PCG bitmap. FPS top left. |

Each program takes over the machine; press RESET to leave.

## RACE controls

| Key | Action |
|---|---|
| M / SPACE / cursor up | Accelerate |
| N / cursor down | Brake |
| Z X (or , .) | Steer |
| C | Change colour theme |

## Measured (cycle-counting emulator)

- RACE: 12.5 fps locked (4 fields per frame), 20–32 fps with less road on screen.
- CUBE: 20 fps for one to three shaded faces.
- Static PCG library for the whole road: 128 of 2048 characters.

## Building

`src/build.sh` needs Python 3 (Pillow for screenshots) and gcc. It builds the PCG library and tables, assembles the three programs with the bundled assembler (`tools/zasm.py`), builds the cycle-counting test emulator (`tools/beemu.c`) and writes `build/BEELINE.DS8` (`tools/build_disk.py`; system tracks and CCP.SYS in `resources/` are from the earlier Premium disks in this repo).

The programs find the video window themselves at start-up (`src/vidmap.asm`): if CP/M hasn't mapped it at F000h they locate CP/M's memory block and map it there.
