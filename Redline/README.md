# REDLINE — COAST TO COAST
### VZ300 + BennVenn SD loader + 128K · 2026 — ViBED by BPM · build v0.1 (engine prototype + first full content pass)

A pseudo-3D arcade racer across Australia in five stages: **Sunset Coast → Red Centre → Rainforest Ridge → Snowy Range → Harbour Lights**.
Mode 1 (128×64, four colours), race information in the sky, real curves and hills with crest occlusion,
tunnels, overhead gantries, traffic, and track sections streamed from the SD card mid-race.

---

## 1. Files (copy everything in `release/` to the SD card root)

| File | What |
|---|---|
| `REDLINE.VZ` | the program (18.2K, loads $8000–$C704, starts at $8000) |
| `RLCOM.DAT` | engine tables (→ $4000 bank 3), car sprites + title picture (→ upper bank 0) |
| `RLnA.DAT`…`RLnD.DAT` | stage *n*, track sections A, B, C… (track, scenery placement, gantries; section A also carries the panorama and scenery sprites) |
| `RLnP.DAT` | stage *n* intro picture (streamed straight into video RAM) |

Load with `LOAD"REDLINE"` or the SD menu. The DOS is kept alive (see §4), so **RESET returns to the SD loader**.

## 2. Controls
| | Keyboard | Either joystick |
|---|---|---|
| Steer | O / P (or Z / X) | left / right |
| Accelerate | SPACE, M or Q | FIRE, or up |
| Brake | A | ARM button, or down |
| Menus | O/P choose, SPACE start | left/right, FIRE |

Joysticks are auto-detected; the port map is Cybernoid v1.7's (fire $2E/$2B, arm $2D/$27, directions $2C / $29).

## 3. Game concept, race structure, handling
* **Grand Tour**: five stages back to back, score carried through; **Practice Stage**: any single stage.
* Each stage is 1,050–1,640 track segments (≈4–6.5 km of road) in 3–4 SD sections. You start under a START gantry
  after a 3-2-1 countdown. Each section ends at a **CHECKPOINT gantry**: passing under it adds time (sized to the
  next stretch) and streams the next section from SD with a "LOADING NEXT SECTION" banner (≈0.1 s). The last
  gantry is the FINISH → *Stage Clear* screen with time bonus tallied into the score.
* Out of time → the car rolls to a stop → Game Over / high score.
* **Forgiving handling**: steering rate grows with speed; bends push you outward (∝ curve × speed²) so you must
  hold a line; **off the tarmac** you slow towards 110 km/h with bounce, dust and rumble — no crash. **Brushing a
  car** drops you to its speed and nudges it aside — no crash. Only **substantial impacts** crash: rear-ending a car
  with a closing speed above 150 km/h, or hitting a solid roadside object (tree, rock, sign, lamp) while off-road
  above 90 km/h. A crash is a 1.8 s spin, then you rejoin in the nearer lane. Collision boxes are deliberately
  narrower than the sprites.
* 5-speed automatic gearbox (engine pitch climbs and drops through the gears).

## 4. Hardware plan (verified against your earlier projects)
**Banking** — reused from BIX (`bank.asm`: the `bank` macro, bounce-buffer `farcopy`, memcmp test) and its MAME
`sdloader.cpp` model confirmed on your machine by the BIX v0.6.x probes: port $37 bit0 = DOS RAM at $4000,
bit1 = which 10K bank at $4000-$67FF, bit2 = which 18K bank at $B800-$FFFF.
**Change from BIX:** BIX overwrites the DOS. REDLINE must call the DOS during play, so the allocation is:

| Mapping | Low $4000-$67FF | High $B800-$FFFF | Used for |
|---|---|---|---|
| 1 (or 0) | DOS (untouched) | upper bank 0 | SD calls only |
| 3 | bank 3 | upper bank 0 | front end |
| 7 | bank 3 | upper bank 1 | racing |

**SD loading** — the "13 Ghosts" DOS calls as proven by your New Zealand Story conversion (NZTEST on real
hardware): DOS mapping detected at boot by the $5FFF write test, `$5F00` open / `$5F03` first / `$5F09` next sector,
IM 1 with interrupts off, sector buffer $F800, DOS workspace $FA00-$FFFF of upper bank 0 never touched. Each sector
is passed through main RAM (the back buffer) and copied to its destination with that chunk's mapping. File format:
`db map, dw dest, dw length, data…` chunks, `map 0` ends.

**Why sections stream at checkpoints, not continuously**: your RASTEST measured 32 sectors in 20 fields
(≈44,000 T-states per 512-byte sector) and the DOS needs its own mapping, IM 1 and interrupts off. A sector per
frame would cost ~30 % of a frame and break the field-locked display, so data loads at natural transitions with
a brief on-screen notice (as you OK'd).

### Memory map
| Range | Contents |
|---|---|
| $4000-$60FF (bank 3) | log/exp multiply tables, z→scale/width, rumble & line widths, pixel index/masks, colour-2 transparency tables, scale-level table |
| $6100-$67FF (bank 3) | free (1.8K) |
| $7000-$77FF | video RAM (rows 0-11 = HUD, drawn directly) |
| $7800-$7BFF | variables, projection arrays, draw list |
| $7C00-$7DFF | stack |
| $7E00-$7F81 | IM2 table (I=$7E) + vector; $7F84 bounce buffer |
| $8000-$A7FF | engine + game code (≈10.2K, 2.5K free) |
| $B180-$B7FF | back buffer: rows 12-63 (1,664 bytes); also the SD sector staging buffer |
| upper 0 $B800-$C703 | front end: menus, music player, sequencer + songs |
| upper 0 $CBFF / $CC00 | picture colour-set byte / title picture (2K) |
| upper 0 $D400-$F39A | traffic cars (3 types × 12 sizes × 2 frames), player car (18 frames + overlays) |
| upper 0 $F800-$FFFF | DOS sector buffer + DOS workspace (untouched) |
| upper 1 $B800-$BFFF | current section: curve / altitude lo / hi / flags × 512 segments |
| upper 1 $C000-$C3FF | roadside objects (≤208), gantries, section header (palette, colours, timing) |
| upper 1 $C400-$CBFF | panorama, 256×16, 2 pre-shifted phases |
| upper 1 $CC00-$DFFF | stage scenery sprites (≤8 types × 12 scale levels × 2 phases) |
| upper 1 $E000-$FBxx | far-road strip cache (built per section) |

## 5. Renderer
* **Segment projection** (Jake Gordon / Lou's pseudo-3D): track = segments 256 units long, each with curve,
  altitude and flags. Boundaries are projected near→far with **logarithm tables** (`EXP[L(v)+LS(z)]`, ~1 %
  accurate, ~150 T instead of ~400 T for a shift-add multiply). Curves accumulate `x += dx; dx += curve`.
* **Crests**: every segment is clipped against the highest line drawn so far — the road beyond a crest vanishes and
  objects behind it are cut off; a rise ahead climbs into the sky over the panorama.
* **Level of detail**: 1–2 segments per boundary near, 4 then 8 near the horizon (≤3 rows there); boundaries sit on
  even segments so each stripe pair is one span.
* **Scanline writer** (`tools/gen_rline.py`, generated): one pass per row, six boundaries
  (grass|rumble|road|line|road|rumble|grass), a pending byte collects the sub-byte mixes, full runs come from an
  unrolled fill chain. Fast paths: whole-row road (bottom rows) = one PUSH fill; **narrow far rows copy a
  pre-rendered strip** from a per-section cache (stripe × width × pixel phase), ~3× cheaper.
* **Sprites**: 12 distance levels (0.7× steps), 2 pre-shifted phases (2-px placement), scenery uses colour 2 as
  transparent via mask tables, cars/player use explicit masks; unrolled blitters. Draw list bucket-sorted far→near.
* **Gantries** are procedural (pillars + rimmed beam + banner text when close) and scale continuously.
* **Tunnels**: wall palette for the road, a roof that mirrors the road boundaries about the horizon in stripes
  (bands rushing towards you), panorama showing through as the light at the end.
* **Display**: back buffer copied to VRAM by the field ISR racing ahead of the beam (BIX technique), tear-free;
  the ISR returns with interrupts off when it has nothing to copy so the 56 sync lines aren't burnt.

### Frame budget and measurements (emulator: 3.5469 MHz, 312 lines × 228 T, 56-line sync — your RASTEST values)
Target: **locked 3 fields per frame = 16.7 fps** (212,800 T). A first naive build took ~5 fields; profiling drove
the optimisations above. Typical frame now (stage 1, autopilot, T-states):

| Part | T-states |
|---|---|
| VRAM copy (ISR, incl. engine sound samples) | 29,400 |
| projection (≈9 boundaries) | ~38,000 |
| road rows (≈36) | ~45,000 |
| sprites (scenery, traffic, gantry, player car) | ~40,000 |
| panorama | ~8,000 |
| game logic, HUD, sound control | ~18,000 |
| **total active** | **≈ 195,000–210,000** |

Measured over ~80 s autopilot runs per stage (frames hitting 3 fields / 4 fields):
**Stage 1** 85 % / 15 % · **Stage 2** 94 % / 6 % · **Stage 3** 75 % / 25 % · **Stage 4** 75 % / 25 % (tunnels, sweeping
bends) · **Stage 5** 85 % / 15 %. Worst case 5 fields: ≤3 frames in 1,200.
Physics runs in fixed 3-field steps from an accumulator, so **game speed and control response are the same whether
a frame takes 3 or 4 fields**; adaptive detail trims the scenery draw distance after a slow frame and restores it
after 25 on-time frames.

## 6. Reused code (required foundations)
* **Cybernoid three-voice player** (`src/music.asm`): `vz_mstep`, `.voice`, `vz_pinc`, `VOLTAB`, the noise-burst
  drums and the 183-T interleaved sample loop are Cybernoid's, unchanged. Its supported format is the AY register
  shadow; in Cybernoid Hewson's AY driver filled it. Here an **original sequencer** (`seq_step`) fills the same
  registers, so the tunes (`tools/music.py`: title theme, race-start, stage-clear and game-over jingles) are
  original — no Hewson driver or Dave Rogers tunes are included. Style per your notes: gritty, notes kept separate,
  not screechy.
* **BIX banking** (`src/bank.asm`): `bank` macro, `farcopy`, `memcmp`; the ISR/back-buffer scheme and
  `maybe_ei` are also from BIX. Changed: allocation keeps the DOS alive (above).
* **NZ Story SD loader** for the DOS calls; **Cybernoid joystick map**.

## 7. Tools (`tools/`) — `./build.sh` rebuilds everything (Python 3 + Pillow, sjasmplus, zx0 not needed)
| Tool | Purpose |
|---|---|
| `track.py` | track language: `S` straight, `C` eased bend, `H` eased hill (with optional bend), `T` tunnel, `G` gantry, object placement |
| `legs.py` | the five stages: palettes, colours, layouts, scenery placement rules; cuts into ≤512-segment SD sections at checkpoints and sizes each checkpoint's time from the stretch ahead; writes `RLnX.DAT` |
| `art.py` | all sprite art as ASCII pixel grids (player car steering/wheel/spin frames, brake & dust overlays, traffic, scenery) |
| `sprites.py` | scales art to 12 levels, pre-shifts 2 phases, packs scenery / common sets |
| `pano.py`, `scenes.py`, `title.py` | panoramas, stage locality pictures, title picture |
| `tables.py`, `gen_rline.py`, `font.py`, `music.py` | engine tables, generated scanline writer, HUD fonts, songs |
| `bench.sh`, `racebench.sh`, `gprof.py`, `sheet.py` | emulator benchmark, per-subsystem profiler, contact sheets |
| `emu/vzemu.c` | test harness (from NZ Story/Cybernoid) + frame-time marker, interrupt-off detector |

Player car frames: 5 steering angles × 2 wheel phases, 8-view crash spin, brake-light overlay, 4 dust puffs;
traffic: 3 car types × 2 animation frames near, 12 sizes.

## 8. Awaiting real-hardware testing
1. **Mid-race SD loading** using mapping 7 ↔ DOS mapping per sector (the NZ Story method did this with mapping 3).
2. **Upper-bank switching during play** (BIX did it only between levels; here every frame switches 7 ↔ 3 for car sprites).
3. Writing $7800-$7FFF (system variables) and keeping the DOS usable afterwards (NZ Story did the same).
4. Frame timing — measured in the emulator with your RASTEST field values.
5. Engine sound and music volume/character — unheard.
If anything fails, the boot shows `REDLINE: CANNOT READ RLCOM.DAT` when the first file load fails; please tell me
what you see.

## 9. Next steps
* More engine speed to make 3 fields universal (stack-based VRAM copy, cheaper projection bookkeeping).
* Bigger, richer scenery art and landmarks (current masters are small), tunnel portal faces, road trains in the outback.
* High-score table with initials, saving to SD; per-stage best times; demo/attract polish.

---
**About this repo copy:** `release/` holds everything that goes on the SD card. `src/` is the v0.1 source. `src/emu/z80.c` is the third-party superzazu/z80 CPU core (MIT licence), used only by the test emulator. The 6847 font header the emulator also needs isn't included.
