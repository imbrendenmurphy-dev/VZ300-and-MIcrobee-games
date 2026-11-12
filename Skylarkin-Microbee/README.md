# SKYLARKIN'! (Microbee Premium Plus) — work in progress

A Parodius-style comedy horizontal shoot-'em-up for the Microbee Premium Plus. Four larrikin pilots against Head Office. VIBED BY BPM 2026.

**Status: engine build, stage 1 in progress.** Not yet playable end to end. See `docs/DESIGN.md` for the full plan.

- 40 × 25 cells of 8 × 8 pixels (the 40-column mode from BPM's MODES40 test)
- Smooth 2-pixel scrolling from pre-rendered strip rows, 25 frames a second in the emulator so far
- Disk: `release/SKYLARK.DS8` (DS80). Boot it, type `SKYLARK` at `A>`.

Build: Python 3 with numpy and Pillow, gcc for the test emulator. `python3 src/tools/build.py` from `src/`.
