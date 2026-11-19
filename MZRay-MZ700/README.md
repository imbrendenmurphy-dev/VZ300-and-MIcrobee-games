# MZRAY BENCH v0.1 — Sharp MZ-700 raycaster benchmark

First step toward a WolfenDoom game for the Sharp MZ-700, converted from the VZ300 game DROPBEAR 3D.

VIBED BY BPM 2026

## Running
Load `release/MZRAY.MZT` through UniCMT (load address 1200h, starts automatically, 10K).
It runs four timed tests (32 frames each), then shows fields per 32 frames and fps:

| Test | Rays | Drawing | Simulator fields | Simulator fps |
|---|---|---|---|---|
| 1 | 20 | direct to colour RAM | 51 | 31.3 |
| 2 | 20 | buffered + copy | 58 | 27.5 |
| 3 | 40 | direct | 94 | 17.0 |
| 4 | 40 | buffered | 102 | 15.6 |

The simulator does not model MZ-700 VRAM wait states, so real figures will be slower.
On MZ-700 Emulator For Win32 it measured 76 / 85 / 125 / 134 fields (21.0 / 18.8 / 12.8 / 11.9 fps).
Not yet measured on a real MZ-700.

Developer handover notes are in `CLAUDE.md`.

Afterwards press 1-4 to walk about in that mode (cursor keys move/turn), B to rerun the benchmark.

## Renderer
Each 40x22 character cell is a "pixel" coloured by its background colour (colour RAM D800h),
so the renderer does not depend on the character ROM (European or Japanese). Textured walls:
brick, stone, tech panels, wood, doors, tiles.

## Building
From `src/`, `PYTHONPATH=tools python3 build.py` generates tables, assembles `mzray.asm` with `tools/zasm.py`
and writes `MZRAY.MZT`. `tools/runtest.py` and `tools/walktest.py` run it on the Z80/MZ-700 simulator.
