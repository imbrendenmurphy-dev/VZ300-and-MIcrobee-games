# VZ300 3D RACER — Stage 4 (part 1): speed
*VIBED BY BPM 2026 · 12 Nov 2026*

## Result

| Build | Fields per frame | fps | Source |
|---|---|---|---|
| Stage 3 (v0.1) | 7.6 (emulator) / 6 shown on your VZ | ~6.6 | measured |
| **This build (v0.2)** | **6.5** | **~7.7** | measured, cycle-exact emulator at your field length |

Every change was checked against the Python reference: the picture is byte-for-byte identical to v0.1, apart from the deliberately coarser distant track.

## What changed

- **Row finishing:** background colours are precomputed once per frame and the rows are walked with a running pointer (680 → ~300 T per row).
- **Strip-row builder:** rewritten around registers and flag bits instead of a dozen memory temporaries.
- **Hidden rows skipped early:** about 30% of row-strips are completely behind nearer track and are now discarded before any runs are built.
- **Coverage:** inline run append and prepend, no per-run subroutine calls.
- **Projection:** inline log lookups, with the focal constant folded in once per point.
- **Edges:** register loop using the alternate register set, plus an unclamped fast path.
- **Distant track:** every section up to 6 ahead, every 2nd up to 12, every 4th beyond (was 8 and 16). Visually indistinguishable at this range (see `race/lod_compare.png`), and about 6% cheaper.

## Where the time goes now (~460,000 T per frame)

| Part | Share |
|---|---|
| Strip and row building (edges, rows, coverage, strip setup) | ~50% |
| Compose | ~10% |
| Transform and projection | ~10% |
| Row finishing | ~6% |
| Gates, craft, HUD, game logic, frame copy | rest |

The profile is now flat: no hot loop is left. Each track strip carries ~5,000 T of fixed setup (clipping, projection, four edge setups), and each visible row-strip ~1,000 T.

## Options to reach 3 fields (16.7 fps)

1. **Keep polishing at full detail.** Realistic ceiling: about 5 fields (10 fps).
2. **Drop the slab skirt** (the underside visible on bends). Measured saving about 6%.
3. **Half-rate rows in the lower screen.** Build the near track every second row and copy each row's runs to the row below, with the dither phase corrected. Distant rows near the horizon keep full detail. Estimated 30–40% saving on the builder; the cost is two-row stair-steps on near track edges.
4. **Palette split in-game** stays expensive (~45,000 T every field) until the field-sync window does useful fixed-length work. Recommended for title and menu screens only, for now.

**Recommendation:** build option 3 as a key you can toggle on the real machine, so you can compare the look and the frame rate side by side, then decide. Combined with continued polishing it should land around 3–4 fields.

---

# Stage 4 (part 2): half-rate rows and the whole-game profile

## v0.3

- **H key** toggles half-rate rows (on by default; the HUD shows `H` when on). Below screen row 36, every second row is built, and the row beneath copies it with the dither phase flipped, so the checker pattern stays intact.
- Both modes are byte-for-byte identical to the reference renderer.

| Mode | Fields per frame | fps | Source |
|---|---|---|---|
| Full rate | 6.52 | 7.7 | measured (cycle-exact emulator, 40 s autopilot) |
| Half rate (H) | 6.16 | 8.1 | measured |

The visual cost is two-row stair-steps on the near track edges (`race/half_compare.png`, bottom row). The saving is smaller than I estimated, because it only touches row building and coverage.

## Whole-game profile (measured, half-rate on)

| Subsystem | T-states per frame | Share |
|---|---|---|
| Transform + projection | 76,000 | 15% |
| Row building | 75,000 | 15% |
| Compose | 75,000 | 15% |
| Edges | 56,000 | 11% |
| Half-rate copy + finalise | 37,000 | 7.5% |
| Strip setup | 33,000 | 7% |
| Frame copy (interrupt) | 28,000 | 6% |
| Coverage | 24,000 | 5% |
| Gates, craft, HUD | 21,000 | 4% |
| Input + physics | 5,000 | 1% |

## What this means

No single routine dominates any more. Reaching 3 fields (16.7 fps) would need roughly halving *every* row of this table. That is a long grind with an uncertain end.

My honest estimate is that further work at full screen and full detail lands around **4.5–5 fields (10–11 fps)**. Bigger jumps need a visible design trade-off:

1. **Letterbox / cockpit panel.** Render 48 rows of 3D and use the bottom 16 rows for a static instrument panel (speed, energy, position), drawn once. That cuts compose, finalise, copy and row work by about a quarter: an estimated ~0.8–1 field. It fits Wipeout/F-Zero style HUDs, and the craft can sit just above the panel.
2. **Shorter draw distance with horizon fog** (a dithered haze band hides the cut-off). Fewer strips and fewer transforms: estimated ~0.5 field.
3. **Drop the slab underside skirt.** Measured ~6% of render.
4. **Keep grinding at full detail:** compose straight into video RAM behind the beam (saves most of the 28,000 T copy, but the overlays need care), shared edge setup between strips, a tighter finalise.

Combining 1–3 with some of 4 is the realistic path to about **3.5–4 fields (12.5–14 fps)**, which is inside the brief's 12–20 fps range. All of these figures except the measured table are estimates.

---

# Stage 4 (part 3): v0.4 — full-screen look and the speed pass

## Result

| Build | Fields per frame | fps | Source |
|---|---|---|---|
| v0.3, half-rate on | 6.16 | 8.1 | measured |
| **v0.4, half-rate on (default)** | **4.29** | **11.7** | measured (cycle-exact emulator, 40 s autopilot) |
| v0.4, half-rate off (H) | 4.78 | 10.5 | measured |

Both modes are still byte-for-byte identical to the Python reference renderer (16 of 16 test frames).

## Look

- **HUD on the sky.** No bezel: speed, frame rate and mode sit at the top of the screen, drawn as transparent text over the sky bands, so the 3D view fills the whole screen.
- **Lower horizon** (row 38) and a **shorter draw distance** (18 sections) ending in a two-row dithered haze band.
- **No slab underside** on bends.
- **F is now an average** over 16 frames with one decimal (for example `4.3F`), so it is easier to read on the real machine.

## Speed changes

- The top 16 sky rows are static. They are restored only after a gate has drawn over them, and the screen copy skips them when nothing changed there (about 6,500 T saved per frame).
- The HUD text is redrawn only when it changes, at most every 4th frame.
- Row finishing, track edges and the section stepper were rewritten around registers instead of memory temporaries (edges alone went from ~51,000 to ~39,000 T per frame).

## Where this leaves us

At 4.3 fields we are just inside the brief's 12–20 fps range on most frames (frames alternate between 4 and 5 fields). The frame rate dips to about 5 fields when a gate is close and draws over the sky. The profile is flat again: no routine takes more than about 7% of the frame.

**Next:** gameplay (boost pads, energy shield, rivals), keeping it forgiving. Further speed work continues alongside it.
