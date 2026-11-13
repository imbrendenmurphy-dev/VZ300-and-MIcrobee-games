# SOUTHERN CROSS (Microbee Premium Plus) — work in progress

An FS1-style wireframe flight simulator for the Microbee Premium Plus: a light trainer, a fictional slice of Australian coast, flying school, mail runs and an Ace combat mode. VIBED BY BPM 2026.

**Status: stage 1 of 7 — flight engine test.** Horizon, runway, hangar, ground grid, text instrument panel and a full flight model. See `docs/DESIGN.md` for the whole plan.

![Final approach](screenshots/approach.png)

## Running it

Boot `release/SCROSS.DS8` (DS80) and type `SCROSS` at `A>`. Press RESET to exit.
`release/SCROSS.COM` is the program on its own, if you want it on another disk.

## Controls

| Key | Action |
|---|---|
| Q / A | Nose down / nose up |
| O / P | Bank left / right (steer on the ground) |
| T / G | Throttle up / down (throttle closed = brakes on the ground) |
| SPACE | Level the wings |
| R | Restart on the runway |
| F | Restart on final approach (1.5 km out, 100 m up) |
| D | Detail level 1–3 |

Rotate at about 52 kt, climb at 60–70 kt, stall is about 43 kt (the nose drops by itself). Land at under ~700 ft/min sink with the wings level.

## Benchmark (emulator, 3.375 MHz, on the runway)

| Detail | Scene | Frames per second |
|---|---|---|
| 1 | Horizon, runway outline | ~15 |
| 2 | + centreline, threshold bars, hangar | ~8 |
| 3 | + ground grid (default) | ~5.5 |

The panel shows the real frame rate, timed from the 6545 vertical blank (50 Hz); game speed uses the same count.

## How it works

- 64 × 16 screen of 8 × 16 cells (512 × 256). The top half is a 512 × 128 bitmap made from 512 PCG glyphs arranged as four vertical strips, one 2K PCG bank each, so a pixel column is a contiguous 128-byte run and stepping a line up or down is `INC L`/`DEC L`.
- Double buffered: page A (screen F000, banks 1–4) and page B (screen F400, banks 5–8), flipped with the 6545 start address.
- 8-bit camera matrix rebuilt each frame; world in half-metre units; frustum culling, near-plane clipping, a 3D guard band (|r|,|u| ≤ 40f) so projections never overflow, midpoint 2D clipping; shared-vertex "lattice" objects and incremental line series.
- Flight model at 50 ticks per second of game time, driven by the vertical-blank field count (thrust, drag, gravity along the path, stall, bank-to-turn, ground roll, landing check).

## Building

Python 3 only. From `src/`: `python3 build.py` writes `build/SCROSS.COM` and `build/SCROSS.DS8`. `python3 run.py` runs it in the included test emulator and saves screenshots; `prof.py` shows where the frame time goes.

The assembler (`src/tools/z80asm.py`) and emulator (`src/tools/z80emu.py`) were written for this project. The system tracks and `CCP.SYS` in `src/resources/` are the same ones used by the other Microbee disks in this repo.
