# VZ300 3D RACER — Stage 1 findings
*ViBED by BPM · working notes · 11 Nov 2026*

## Status of the numbers in this document

- **Measured:** per-frame *workload* (vertices, edges, rows, intervals, boundary bytes) — counted by the prototype `proto.py`, which performs the same work in the same order as the planned Z80 renderer, at true 128×64, 4-colour resolution.
- **Estimated:** the T-state cost of each operation, taken from the planned Z80 inner loops and standard Z80 instruction timings. These are *not* benchmarks. Stage 2 replaces every one of them with a cycle count measured on your real VZ300.
- **Verified on your machine (earlier projects):** 312 lines per field; IM2 frame interrupts; mid-frame mode switch with line hold; port $37 bank switching (bit 0 DOS RAM/ROM, bit 1 selects the 10K bank at $4000–$67FF, bit 2 swaps the 18K at $B800–$FFFF); the SD DOS needs $FA00–$FFFF left alone at run time.

## 1. The frame budget

| Quantity | Value |
|---|---|
| CPU clock | ≈3.5469 MHz |
| One TV field (312 lines × ~227 T) | ≈70,800 T |
| 25 fps (2 fields) | 141,600 T |
| 20 fps (2.5 fields avg) | 177,000 T |
| 16.7 fps (3 fields) | 212,500 T |
| 12.5 fps (4 fields) | 283,300 T |
| Mode(1) screen | 2,048 bytes ($7000–$77FF), 32 bytes/row, 4 px/byte |
| Beam time per mode(1) row (3 scanlines) | ≈681 T |

Mode(1) has no second video page, so classic page-flipping isn't available.

## 2. Renderers compared (same track, same 300-frame run)

| Renderer | How it works | Avg | 95th pct | Worst | Notes |
|---|---|---|---|---|---|
| **A** General polygon engine | Every face a polygon, painter's order, fill into back buffer, copy to VRAM | 4.18 fields (≈12 fps) | 4.62 | 4.76 | Works, but slow |
| **B/C** Row-claiming strips | Each row claimed once by the nearest section; rows composed straight into VRAM | 1.5 fields | — | 1.6 | Very fast, but **breaks on hard banking** |
| **D** Interval-painting hybrid | One quad per section painted far→near as *row intervals* (no pixels), then every row composed once | **2.24 fields (≈22 fps)** | 2.64 | 2.81 | Correct on banked bends — **recommended** |

### The key finding

At 128×64, **pixels are cheap; geometry bookkeeping is expensive.** In renderer A, filling pixels was only 11% of the frame. Polygon/edge setup (32%), vertex transforms (19%) and span setup (15%) dominated. The low resolution really is an advantage, but only if the renderer stops paying per-polygon overhead.

Renderer D gets its speed from three racing-specific tricks:

1. **Shared geometry.** Each cross-section is transformed once and shared by the quads either side of it. Rails and the slab underside are derived from the same edges rather than drawn as extra polygons.
2. **Intervals, not pixels.** Far-to-near painting only edits short per-row run lists; overdraw costs a list insert (~75 T), not pixel writes.
3. **Compose once.** Every one of the 2,048 screen bytes is written exactly once, from a run list. No clear pass, no back buffer, no copy. Composition (≈32k T) runs faster than the beam scans the screen (≈440–520 T per row against ≈681 T per row), so it can be started at the top of the field and **race the beam** for tear-free updates with no double buffer. This must be proven on hardware (see risks).

Why B/C failed: on a steeply banked bend the raised side climbs above eye level, so the left and right edges land on *different screen rows*. A row-by-row "left edge to right edge" model can't represent that. D handles it because each quad is scanned as a real polygon.

### Where renderer D's time goes (average frame)

| Component | T-states | Share |
|---|---|---|
| Vertex transform + project (46 vertices) | 45,080 | 28% |
| Row composition (all 2,048 bytes) | 31,928 | 20% |
| Strip + edge setup | 29,178 | 18% |
| Interval painting | 28,669 | 18% |
| Row stepping | 16,973 | 11% |
| Game logic, input, sound (budget) | 6,000 | 4% |
| Craft sprite | 988 | 1% |
| **Total** | **≈158,800** | 2.24 fields |

## 3. Frame-rate verdict (provisional)

- **16.7 fps locked (3 fields): comfortably achievable.** Even the worst frame (2.81 fields) fits, though with only ~6% headroom, so Stage 4 savings matter before adding rivals.
- **20 fps (2.5 fields): within reach after Stage 4 optimisation.** About 90% of frames already fit; the transform stage is the obvious target (below).
- **Recommendation:** lock to a fixed 3-field cadence first. A steady 16.7 fps feels smoother than an average of 20 that alternates between 2 and 3 fields, and gives headroom for rivals and scenery. Push to 2.5 or 2 fields only once Stage 4 frees enough time.

## 4. Optimisation targets for Stage 4 (in order)

1. **Track-relative transforms (biggest win, ~28% of the frame).** The camera always faces nearly along the track. Store each cross-section in track-local coordinates and precompute per-section deltas in expanded RAM; then most vertices need a small-angle correction (2 table multiplies) instead of a full 3-axis rotation (8–10 multiplies).
2. **Cheaper silhouettes.** The slab outline currently uses a general 8-point hull; it can be read from a small per-orientation table.
3. **Distance LOD.** The farthest 6–8 sections cover only a few rows. Merge them in pairs and skip their rails and skirt.
4. **Run-list inserts in self-modifying code,** with the row composer as an unrolled jump-into byte writer (`LD (HL),A : INC L`, 11 T per byte).

## 5. Look and colour (from your reference shots)

- **Checker dithers are free extra shades.** In the row composer a checker run is just a different byte value, with the pattern phase flipped every row. Solid/checker bands down the road give the rushing-forward feel at zero extra cost.
- **No black in VZ 4-colour mode.** Blue (the darkest) stands in for the void and for vehicle bodies.
- **Two palettes per frame.** The sky uses the buff/cyan/magenta/orange set (a magenta→orange sunset with dithered transition bands); the track uses green/yellow/blue/red. A mid-frame CSS switch at the topmost track row, moved each frame by the line-counting interrupt, makes this work. Mid-frame switching is proven on your machine; doing it at a row that moves every frame still needs testing.
- **Gates and pylons** use colour index 3, so they read red below the split and orange where they poke into the sky — correct in both palettes.
- **Vehicles as bold silhouettes** (dark body, bright tail-light bars), as in your shots. Cheap pre-shifted sprites; scaled rivals use a handful of precomputed sizes.

## 6. Risks and unknowns — Stage 2 must measure these on real hardware

1. **CPU access to video RAM during active display.** Whether VZ300 VRAM writes stall the CPU, cause snow, or are free during the picture decides whether beam-racing composition works. Fallback: compose into a 2K buffer and copy (adds ≈22,500 T; D then averages ≈2.56 fields, so 16.7 fps locked still holds).
2. **True T-state costs of each inner loop** (multiply, reciprocal lookup, edge step, interval insert, composer).
3. **Moving CSS split row timing** — interrupt latency and line-hold jitter at different rows.
4. **Bank-switch overhead** if track tables live in the switched 10K/18K banks.

## 7. Stage 2 plan — `BENCH.VZ`

A single benchmark program for your VZ300, loading low ($8000, no mapper writes at load, like Xevious v1.2). It uses the IM2 field counter to time each routine over many repetitions and prints T-states per operation on screen, so a photo of the screen gives us real numbers:

1. Table multiply (8×8 signed, quarter-square) and reciprocal-table projection.
2. Full vertex transform, and the track-relative fast path.
3. Edge setup and edge stepping.
4. Interval insert into a run list.
5. Row composer: 64 rows, with typical and worst-case run counts.
6. VRAM write speed during active display versus during field sync (answers risk 1).
7. CSS switch at a moving row (answers risk 3).

After that, Stage 3 is the first moving track on real hardware.

## Files

- `proto.py` — prototype; `python3 proto.py` runs A, `B`/`C`/`D` run the others
- `vzrace_D.gif` — renderer D preview (recommended architecture)
- `vzrace_C.gif` — row-claiming version (fast, shows the banking failure)
- `vzrace_preview.gif` — renderer A
- `frames_*.csv` — per-frame workload counts and estimated T-states
