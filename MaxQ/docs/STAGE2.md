# VZ300 3D RACER — Stage 2: real Z80 code, real cycle counts
*VIBED BY BPM 2026 · working notes · 11 Nov 2026*

## What was built

- **`tools/z80asm.py`** — two-pass Z80 assembler (full documented instruction set, IX/IY, local `.labels`), writes `.VZ` files (`VZF0` header, type $F1).
- **`tools/vzemu.c`** — cycle-exact Z80 emulator with the VZ300 bits we need: the $6800 output latch (mode/colour set), field sync on bit 7 of $6800 (312 lines × 227 T, sync low for 56 lines, as measured on your machine), snapshots, and a profiler that reports exact T-states per routine call. It decodes instructions independently of the assembler, so it cross-checks it.
- **`BENCH.VZ`** — the benchmark for your VZ300 (details below).
- **`bench/build_opt.py`** — optimised composer and transform, profiled and checked against the reference.

## Measured T-states (cycle-exact emulator)

These are exact counts for the real Z80 code. They ignore any video-RAM wait states, which only your hardware can reveal.

| Routine | Stage 1 assumption | First version | Optimised | Correctness |
|---|---|---|---|---|
| Signed 8×8 multiply (quarter squares) | 70–100 | 145 + CALL/RET | inlined (saves the 27 T CALL/RET) | ✓ grid checksum |
| Vertex transform + project | 980 | 2,434 | **1,325** | ✓ matches Python |
| Edge step, per row | ~26 | **26** | — | ✓ |
| Composite run-list insert (merge) | ~300 | 1,020 | (redesign below) | ✓ byte-exact |
| Compose full frame (64 rows) | 32,000 | 139,575 | **103,884** | ✓ byte-exact frame |
| Fill 2,048 bytes by PUSH | 11,600 | 12,162 | — | — |
| One field | 70,824 | 70,805 measured by the bench itself | — | — |

The bench's own on-screen measurements agree with the profiler to within a few T-states. That validates the method, so the figures your VZ300 shows will be trustworthy.

## What the numbers say

1. **The composer is the bottleneck, and it isn't the pixels.** Filling 2,048 bytes costs ~22,500 T. The rest of the 103,884 is about **283 T per run break** (this frame has 254 breaks). Every break needs its position worked out, a jump computed and a boundary byte mixed.
2. **Transforms were too generous with multiplies.** Ten multiplies per vertex became six by applying pitch and roll as screen-space offsets. That's accurate for the small angles a chase camera uses.
3. **Run-list merging is too slow** (1,020 T per composite insert) for 150+ inserts a frame. The fix is the front-to-back outward-growth builder: each new strip only extends a row's covered span to the left or right, so it's an append, never a merge.

## Frame-time projection (renderer D)

| Component | T-states | Source |
|---|---|---|
| Vertex transforms (46 × 1,325) | 60,950 | measured |
| Row composition (this frame) | 103,884 | measured |
| Edge stepping (154 row-strips × 26) | 4,004 | measured |
| Edge setup (108 × ~230) | 24,840 | estimate |
| Row builder, outward append (154 × ~200) | 30,800 | estimate |
| Game logic, sprites, sound | 10,000 | estimate |
| **Total** | **≈234,500** | **3.31 fields ≈ 15 fps** |

**Planned fixes, not yet measured:**

- **Composer to ~65,000 T.** The outward-growing builder knows both neighbours of every break when it creates it, so it can store each run's fill-entry address and finished boundary byte. The composer then just streams them (~100 T per break instead of ~283).
- **Transforms to ~40,000 T.** Transform each section's centre plus one half-width vector (shared by both edges), and use cheaper level of detail on the farthest sections.

Together those bring the projection to **≈175,000 T ≈ 2.47 fields ≈ 20 fps**.

**Honest verdict:** the first measured implementation would run at about **15 fps**. The Stage 1 promise of a **locked 16.7 fps** needs the composer fix; **20 fps** needs both fixes. Both are specific, understood changes, not hopes.

## `BENCH.VZ` — please run on your VZ300

- Loads at $8000–$A537 (9.5 KB), no mapper writes, no ROM or DOS calls, interrupts off — the same loading rules as Xevious v1.2, which boots on your machine.
- About 1 second of "MEASURING...", then it alternates every ~4 seconds between:
  - **Results screen** (yellow on blue): T-states for each routine, plus CHECK OK/BAD for the multiply, insert and compose correctness tests.
  - **Track frame**: a genuine renderer-D frame composed by the Z80 from row run lists, with the sky switched to the second colour set mid-frame.

**Please photograph both screens.** Emulator values for comparison:

| Line | Emulator value | What a difference on your VZ would mean |
|---|---|---|
| FIELD | 70805 | Different = CPU clock or line count differs |
| SYNC | 12670 | ≈56 lines. ~58,000 would mean the sync bit is inverted |
| FILL V / FILL R | 12180 / 12162 | **FILL V much bigger than FILL R = video RAM stalls the CPU** |
| MUL8, XFORM, EDGE64, INSERT | 144 / 2421 / 1662 / 1010 | Should match closely (RAM only) |
| COMP RAM / COMP VRM | 141225 / 141225 | Same contention test, on real composition |
| CHECK flags | all OK | BAD = a table or routine misbehaves on real hardware |

**On the track screen:** the palette change should fall exactly where the sky meets the gate's horizon (row 27). If it lands higher or lower, tell me roughly how many rows — that calibrates the raster timing. It currently assumes the picture starts 64 lines after field sync ends.

## Stage 3 plan (after your photos)

1. Choose compose-to-video-RAM (beam-racing) or compose-to-buffer + copy, based on FILL V vs FILL R.
2. Build the front-to-back outward-growth row builder with byte-ready runs, and the streaming composer.
3. Per-section shared transforms and far-section level of detail.
4. First moving track on your VZ300: forward motion, curves, hills and banking, with an on-screen frame counter.
