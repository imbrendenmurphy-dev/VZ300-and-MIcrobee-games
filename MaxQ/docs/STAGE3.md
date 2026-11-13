# VZ300 3D RACER — Stage 3: first moving track
*VIBED BY BPM 2026 · working notes · 11 Nov 2026*

## What `RACE3D.VZ` does

- Loads at $8000–$DDDF (24 KB). No ROM or DOS calls, no mapper writes, the same loading rules as the builds that already work on your machine.
- Title card for about 2 seconds, then the **autopilot attract mode** drives laps of a 512-section looping track: curves, hills, crests and banking, gates every 16 sections, a sunset sky.
- **Press any control to take over.** About 5 seconds without input hands back to the autopilot.

| Control | Keyboard | Joystick 1 |
|---|---|---|
| Steer | `,` left · `.` right | left / right |
| Accelerate | SPACE | up or fire |
| Brake | N | down |
| Palette split on/off | M | — |

- **HUD:** speed (top left), then fields per frame (`6F` means 6 fields, about 8 fps), then `AUTO` when the autopilot is driving.
- **Forgiving handling:** the track edges bounce you back and scrub some speed; you can't fall off.
- **Camera:** about 3.5 units up, horizon around row 30, as agreed.
- **Craft:** five animation frames (hard left to hard right) chosen from steering plus sideways slide. The canopy and deck lean into the turn, the far tail light narrows, and a dithered flank comes into view, with dithered hover pads underneath.
- **Tear-free:** each finished frame is copied to the screen by the field interrupt, starting at field sync, so the copy stays ahead of the beam.
- **Palette split (M):** the sky switches to the second colour set mid-frame, as in the bench. It costs CPU time every field (see below), so it's off by default. The default sky is a sunset made from the normal colour set.

## Correctness

The renderer exists twice: an exact integer model in Python (`ref3.py`) and the Z80 engine (`engine.asm`). **42 random camera positions render byte-for-byte identically** in the cycle-exact emulator. That includes banked bends, crests, near-plane clipping, gates and every row-composition edge case found on the way.

## Performance — measured, not estimated

| Run | Result |
|---|---|
| 40 s of autopilot in the cycle-exact emulator (field length set to your measured 70,630 T) | **≈ 7.6 fields per frame, about 6.6 fps** |

This is far slower than needed. Profile of one frame (~615,000 T):

| Part | Share | What it is |
|---|---|---|
| Row builder (strip rows + coverage) | ~37% | Building each row's colour runs and merging them front to back |
| Edge rasterising | ~12% | Walking each strip's four edges down the rows |
| Compose | ~13% | Writing the 2,048 screen bytes from the run lists |
| Transform + projection | ~12% | Track geometry and perspective |
| Row finishing | ~7% | Sky, background and terminators for every row |

The cycle-level profile shows the builder's cost spread thinly over many instructions — about 1,100–1,700 T per row-strip — rather than one hot loop. Instruction-level tuning won't deliver the 3× needed; the builder needs a leaner design. I tried two optimisations this stage: a register-based edge loop, and skipping rows already hidden behind nearer track (about 30% of row-strips). Both are kept, but neither is enough on its own.

**Palette split cost:** with no hardware timer, holding the split at the horizon means the CPU counts time from field sync to that row every field, about 45,000 T. That's affordable for title and attract screens, but in-game it currently costs roughly a third of the frame rate. Making it free requires doing useful, fixed-length work (the frame copy, sound) in that window. That's planned for Stage 4.

## Please test on your VZ300

1. Does it load and reach the attract mode? Does the track move smoothly, with no tearing?
2. What does the HUD's `F` number show? (The emulator shows 6–8.)
3. Do the keyboard keys and joystick 1 steer, accelerate and brake?
4. Press M: does the sky switch colour set cleanly at the horizon? How much does the `F` number rise?

## Stage 4 plan: speed

Target: **3 fields per frame or better (16.7 fps)**, from today's 7.6.

1. **Leaner row builder.** Process each strip once per row with the run pattern decided per strip, not per row. Emit runs straight into the row lists for uncovered rows, and keep the coverage merge only for rows that extend sideways. Target ~400 T per row-strip, from ~1,700.
2. **Edge setup:** reuse each section's projected edge between the two strips that share it.
3. **Row finishing:** fold the sky and background into the composer, removing a whole pass.
4. **Transform:** keep the accumulators in registers; one log lookup per point instead of three.
5. **Composer:** have the builder store ready-made byte data, as identified in Stage 2.
6. **Palette split:** use the field window for the frame copy and sound instead of counting time.

Every step is checked against `ref3.py` frame by frame, so speed work can't silently change the picture.

## Files

- `RACE3D.VZ` — the game build for your SD card
- `race/ref3.py` — exact reference renderer and track generator
- `race/engine.asm`, `race/race.asm` — Z80 engine and game
- `race/build_race.py` — builds the game; `build_race.py test N` runs the byte-exact comparison
- `race/craft.py` — craft animation frames
- `tools/` — assembler and cycle-exact emulator (now with IM2 interrupts, the measured field length and a per-instruction cycle profiler)
