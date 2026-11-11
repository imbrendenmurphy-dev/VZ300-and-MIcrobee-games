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

## Version 3: monochrome dithered ground, animated car

- The ground is one colour on black per theme; verge, kerb chevrons and road differ only by dither, and every light/dark band swaps the patterns (road solid / checker, verge checker / sparse, kerb black / solid).
- Road edges are dithered too: each edge character is built per frame from a 105-entry edge-mask library and the current band patterns, into the hidden page's PCG banks 1-8 (double buffered). Colour RAM for road rows is static.
- The car is rendered from a 3D model in 5 steering poses that blend over a few frames: black rear with tail lights, dithered side panels and tyres; the road shows through its outline pixel by pixel.
- Frame pacing is locked to 4 fields (12.5 fps). A frame that overruns waits for the 5th field.

## Version 4: faster engine

The game logic needs the road engine to be quick, so this version targets 12.5 fps. All of these changes were checked pixel for pixel against v3 frames rendered with fixed timing:
- Rendering costs about 20% less: a register-based edge builder, table-driven code passes, a fast path for car cells over plain road, read-back of the car's underlying characters, and HUD digits and sky rows redrawn only when they change.
- The horizon is lower (line 80, camera height lowered to match), closer to the art-direction photos. This gives fewer ground rows to build.
- The two rows nearest the horizon skip kerbs. They are only a few pixels wide there anyway.
- Result: median work is 3.4-3.6 fields per frame, and 91-95% of frames hold 4 fields. The rest (sharp crests with 7-8 ground rows) take 5.

## Measured

| | Emulator (with real-hardware wait states) | Real Premium Plus |
|---|---|---|
| BENCH (blocks/s) | 603 507 414 413 472 973 599 | 603 517 415 413 465 954 527 |
| RACE v4 | 12.3 fps (locked at 4 fields; 91-95% of frames hit it) | to be confirmed |
| RACE v3 | 10 fps locked (work 4.0-5.2 fields per frame) | |
| RACE v2 (flat colours) | 12.9 fps | |
| CUBE | 18 fps | |

## Building

`src/build.sh` needs Python 3 (Pillow for screenshots) and gcc. It builds the PCG library and tables, assembles the three programs with the bundled assembler (`tools/zasm.py`), builds the cycle-counting test emulator (`tools/beemu.c`) and writes `build/BEELINE.DS8` (`tools/build_disk.py`; system tracks and CCP.SYS in `resources/` are from the earlier Premium disks in this repo).

The programs find the video window themselves at start-up (`src/vidmap.asm`): if CP/M hasn't mapped it at F000h they locate CP/M's memory block and map it there.
