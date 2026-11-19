# CLAUDE.md — MZRAY (Sharp MZ-700 WolfenDoom project)

Handover from Claude chat to Claude Code, 19 Nov 2026. Read all of this before changing anything.

Credits line for anything user-facing: **VIBED BY BPM 2026** (the user's standing preference — not
"code by Claude" etc.).

---

## 1. Purpose and current status

**Goal:** a Wolfenstein/Doom-style first-person game ("WolfenDoom") for the **Sharp MZ-700**, made by
converting the user's VZ300 game **DROPBEAR 3D** in whole or in part, swapping VZ300-specific routines
and artwork for MZ-700 equivalents.

**Current stage:** benchmark only. `MZRAY BENCH v0.1` is a textured raycaster test program used to
measure real speed before any game design is committed. This is the same benchmark-first process
used for the sibling projects (RAYBENCH → DROPBEAR 3D on the VZ300, BEECAST → BUNYIP on the Microbee).

**No game code exists yet.** No enemies, objects, weapon, sound, title screen or level data.

### Completed functionality (what v0.1 does)
- Loads as `MZRAY.MZT` (load 1200h, exec 1200h, 10,096 bytes of data + 128-byte header).
- Runs 4 timed tests automatically, 32 frames each, rotating 8 angle units (of 256) per frame:
  1. 20 rays, 2-cell-wide columns, drawn direct to colour RAM
  2. 20 rays, drawn to RAM buffer then copied to colour RAM
  3. 40 rays, 1-cell columns, direct
  4. 40 rays, buffered
- Results screen: vblank fields per 32 frames and fps (to 0.1).
- Walk mode: keys **1–4** select a render mode, cursor keys move/turn, live FPS + frame counter,
  **B** restarts the benchmark.
- 16×16 test map, textured walls (6 wall types × 2 side shades = 12 textures, 8×8 each).

---

## 2. Verified vs unverified — read carefully

| Claim | Status |
|---|---|
| Source assembles with `src/tools/zasm.py` and output is reproducible (rebuilt binary byte-identical to release) | **Verified** (cloud build) |
| Runs in Claude's Python simulator: 51 / 58 / 94 / 102 fields (31.3 / 27.5 / 17.0 / 15.6 fps) | **Verified in simulator only** — simulator has NO VRAM wait states, so these are optimistic |
| Loads and renders correctly in **"MZ-700 Emulator For Win32"** on the user's PC (test 4 view correct, text correct, `V0.1` decimal point renders) | **Verified by user** (screenshots `screenshots/mz700win_test4.png`, `mz700win_results.png`) |
| MZ-700 Win32 emulator results: **76 / 85 / 125 / 134 fields = 21.0 / 18.8 / 12.8 / 11.9 fps** | **Verified by user, in emulator** |
| Runs on the **real MZ-700** via UniCMT | **NOT YET TESTED.** This is the next required step. |
| Keyboard matrix (cursor keys, 1–4, B) correct on real hardware | **Unverified.** Key positions come from the MAME-style MZ-700 matrix (see §6). Worked in the simulator by construction; not confirmed in the Win32 emulator or on hardware. |
| `E002h` bit 7 is the vblank signal | **Assumed** (8255 port C bit 7 /VBLK). Field counting works whichever polarity it is (see §5). The emulator figures look plausible, which suggests it works there. |
| European character ROM compatibility | The renderer uses no glyphs (colour cells only), so it's ROM-independent. Text uses display codes for A–Z, 0–9, space and `.` only, and those rendered correctly in the emulator. Which ROM the emulator used is unknown. |

**Interpretation of the emulator numbers (my inference, not proven):** the emulator is ~1.3–1.5×
slower than the simulator, consistent with it modelling the MZ-700 VRAM access waits (CPU is held
during display when touching D000–DFFF). **Buffered is slower than direct in every case**, so the
copy pass costs more than it saves; direct drawing is currently the better choice. Real hardware
may differ — get the real-machine photo before deciding.

---

## 3. Target hardware and constraints

- **Sharp MZ-700**, Z80A at ~3.5 MHz (3.546895 MHz PAL), **64K RAM**, PAL 50 Hz.
- Program files are **MZT** tape images loaded from USB through the user's **UniCMT** device.
  No disk, no SD, no bank-switched extra RAM. Everything must fit in one MZT, or a chain of MZTs
  (chain loading via UniCMT is **untested**).
- User has the **European character ROM** (lowercase/symbols in place of katakana). A few
  characters differ from the Japanese ROM. Any future glyph-based graphics must be checked against
  the European set — ask the user for a dump or character chart rather than relying on memory.
- Video: 40×25 characters. Character VRAM at **D000h**, colour/attribute RAM at **D800h**.
  Attribute byte = `fg<<4 | bg` (bit 7 selects the alternate character set; it is always 0 here).
  8 colours: 0 black, 1 blue, 2 red, 3 magenta, 4 green, 5 cyan, 6 yellow, 7 white.
- **No PCG** on a stock MZ-700. Sprites and art must be made from fixed ROM glyphs and/or colour cells.
- **Sound:** one 8253 square-wave channel (E004–E007 timer, gate at E008). Multi-channel music
  must be faked with fast arpeggios. v0.1 only writes 0 to E008 (silence).
- **VRAM contention:** CPU access to D000–DFFF stalls during active display. This is the main
  performance unknown on real hardware.
- Usable RAM: the program owns 1200h–CFFFh (~48K). The monitor work area 1000h–11FFh is trampled
  by our stack (see §4); we never return to or call the monitor.

---

## 4. Memory map (v0.1, from `mzray.sym`)

```
1000-11FF  monitor work area – used by our stack (SP=1200h, grows down). Monitor never called.
1200       start (DI; SP=1200h; speaker gate off)
1200-1B17  code, strings, mode table, per-column tables, variables
1C00-2CFF  page-aligned lookup tables (one 256-byte page each):
           1C00 SGN   ray direction sign flags (bit0 = x negative, bit1 = y negative)
           1D00 DDXL  1E00 DDXH   |256/cos| (8.8), clamped 7FFFh
           1F00 DDYL  2000 DDYH   |256/sin|
           2100 SINM  2200 COSM   |sin|,|cos| ×256 (texture-u calc)
           2300 COS8  2400 SIN8   signed ×127 (movement)
           2500 MAP   16×16 map, 1 byte/cell (0 empty, 1–6 wall type)
           2600 HGT   2700 HGT2   wall height by corrected distance>>3 (512 entries)
           2800 TOPS  2900 ROWS  2A00 FLRS  2B00 VINIT  2C00 VSTEP   per-height column tables
2D00-34FF  TEX: 8 pages, one per texture ROW v; byte index = texture column (texl)
3500       VTAB: v (0–255) -> TEX page (TEX>>8)+(v>>5)
3600-396F  BUF: 880-byte (40×22) render buffer for the buffered modes
3970-CFFF  free (~38K) for the game
D000/D800  VRAM / colour RAM
E000-E008  8255 / 8253 / speaker gate
```

Note: `BUF` is declared with `ds` at the end, so 880 zero bytes are stored in the MZT. That's
harmless, but it's easy to save if load size matters later.

---

## 5. Rendering architecture (preserve these techniques)

### Colour-cell framebuffer
- The view is rows 1–22 (`VIEWH=22`) × 40 columns. **Each cell is one "pixel"**: character RAM is
  cleared to 00h (space), and the colour shows as the cell **background** colour in D800h.
- Texture bytes are stored as `c<<4 | c` (fg = bg) so a cell shows a solid colour whatever glyph
  is in it, which makes it ROM-independent.
- Ceiling = 00h (black), floor = 11h (blue). Text rows 0, 23 and 24 are status lines.
- Only colour RAM is written per frame. Character RAM is untouched after `cls`.

### Raycaster (`castray`)
- **256-unit angle system**, all trig from page-aligned tables. Indexing is `ld h,TABLE>>8 / ld l,angle`.
- Player position `px`/`py` is **8.8 fixed point** (high byte = map cell, low byte = fraction).
  `pxf`/`pxc` and `pyf`/`pyc` are byte aliases.
- **DDA with the map cell index held in A′** (`ex af,af'`). The map is 16 wide and page-aligned, so
  one byte addresses any cell (`y*16+x`). Steps are **self-modified** immediates:
  `sx_smc` = +1/−1, `sy_smc` = +16/−16. Delta distances are self-modified into `dx_smc`/`dy_smc`.
- sideDist X/Y live in **BC/DE** throughout the DDA loop. Comparison is `sbc hl,de` on a copy.
  No memory traffic inside the loop except the map read.
- Initial side distance = `frac × delta` through `mul8` (HL = DE×A>>8). Exact-zero fraction uses
  the full delta.
- **Fisheye correction:** the perpendicular distance is multiplied by a per-column cos factor
  (`cosoff20/40`, ×256) instead of doing a projection division. Height then comes from the `HGT`
  table indexed by `distance>>3` (1/32-cell resolution, clamped at 0FFFh). **No division anywhere
  in the per-column path.**
- Per-column ray angle offsets (`colang20/40`) are atan-correct, not linear, for a 60° FOV.
- Texture u = fraction of the hit position along the wall (`perp × |sin|` or `|cos|` added to or
  subtracted from the player fraction), top 3 bits → column 0–7.
  `texl = ((walltype−1)*2 + side)*8 + u` gives each wall type a darker/alternate shade on Y-sides.

### Column drawers (`drawcol1` 1-wide, `drawcol2` 2-wide)
- Called through a **self-modified CALL** (`dc_smc`), set by `setmode`. No per-column mode branch.
- All per-height values are **precomputed tables indexed by height** (`ld b,TABLE>>8 / ld a,(bc)`
  with C = height): ceiling rows, wall rows, floor rows, initial v, v-step. Clipping of tall walls
  is folded into `VINIT`.
- The wall loop uses the **alternate register set**: E′ = v accumulator, B′ = v step,
  D′ = VTAB page, L′ = texl. Per row: `exx / v+=step / ld a,(de) (page lookup) / ld h,a / ld a,(hl) / exx / store`.
  The main set keeps HL = screen pointer, DE = 40 (row stride), B = counter.
- 2-wide mode writes the cell pair with `inc hl / dec hl`, halving the ray count.

### Buffered modes
- Render to `BUF` with the same drawers (stride 40), then `copybuf` does **22 rows of 40 unrolled
  `LDI`** (generated by `build.py` via `;@@LDI40@@`), polling vblank between rows.
- Emulator results show this is **slower than direct**. Keep the code for real-hardware comparison,
  but don't assume buffering is needed.

### Timing — vblank field counting (`poll`)
- No interrupts are used (DI throughout). `poll` reads `E002h` bit 7 and counts each transition of
  that bit to 0, storing the last state in the **self-modified `cp` operand** at `pl_cmp+1`.
  It counts one per field whatever the polarity.
- `poll` is called after **every column** and **every copy row** so no vblank edge is missed. Any
  new long-running routine must also call `poll` often enough (well under one field, 20 ms),
  or the frame counts will be wrong. It only clobbers AF and preserves HL.
- FPS maths: bench fps×10 = 16000/fields (32 frames × 50 Hz × 10); walk fps×10 = 8000/fields per
  16 frames. `div16` is a 16/16 restoring divide used only for this display.

### Build-time table generation
`build.py` (Python) computes every table and the textures, injects them into `mzray.asm` at
`;@@TABLES@@`, `;@@SMALLTABLES@@` and `;@@LDI40@@`, writes `mzray_full.asm`, assembles, and writes
the MZT and `mzray.sym`. **Edit textures, map, FOV and VIEWH in `build.py`, not in the generated file.**

---

## 6. Input, text and other I/O details

- Keyboard: write the row to **E000h** (`or 0F0h`, low nibble = row), read columns at **E001h**,
  where 0 = pressed. Layout used (MAME mz700 matrix — **unverified on real hardware**):
  row 7: bit5 up, bit4 down, bit3 right, bit2 left; row 5: bits 7/6/5/4 = keys 1/2/3/4; row 4 bit 6 = B.
  If the user reports wrong keys, this table is the first suspect.
- Text strings use the `dsc "..."` assembler directive, which emits **MZ display codes**
  (A–Z = 01–1Ah, 0–9 = 20–29h, space = 00h, `.` = 2Eh) terminated by FFh. Only those characters
  are supported by `dispcode()` in `zasm.py`.
- MZT header: 128 bytes. Byte 0 = 01h (machine code); name at 1–17 terminated/padded with 0Dh;
  size at 18; load at 20; exec at 22 (little-endian).

---

## 7. Engineering decisions and why

1. **Benchmark before game:** the user's established process. Real-machine numbers decide the
   resolution and design (RAYBENCH and BEECAST did the same).
2. **Colour-cell rendering instead of glyph/block graphics:** ROM-independent (European ROM),
   8 colours per "pixel", one byte written per pixel. 2×2 block glyphs (80×50) were considered as
   a possible higher-resolution mode but are **not implemented or tested**. They would need
   char + attribute writes per cell and the European glyph codes.
3. **40×22 view, 60° FOV:** fills the screen width and leaves 3 text rows for a HUD.
4. **Everything table-driven and page-aligned:** the Z80 at 3.5 MHz can't afford divides or
   multiplies per pixel. The only multiplies per ray are 2–3 `mul8` calls.
5. **Self-modifying code** for DDA steps, deltas, the column-drawer call and the poll state:
   it removes branches and memory loads from the inner loops. Code runs from RAM, so this is safe.
6. **Polling vblank instead of interrupts:** simple, and accurate enough for benchmarking.
7. **Own Python toolchain** (`zasm.py` assembler, `z80.py` CPU, `mzemu.py` machine model), because
   the cloud session had no Z80 assembler or MZ-700 emulator and no package installs.
   On Windows, Claude Code may use a real assembler (e.g. sjasmplus or pasmo), **but must verify the
   output is byte-identical to `release/MZRAY.MZT` before switching**.

---

## 8. Failed or rejected approaches — do not reintroduce

- **Assuming buffered drawing is faster.** On the MZ-700 Win32 emulator it was slower in both ray
  counts (85 vs 76, 134 vs 125 fields). Don't make buffering the default unless real hardware disagrees.
- **Solid unpatterned wall fills.** On the sibling Microbee BUNYIP project, solid bright walls made
  the user's monitor dim near walls. Keep walls textured/patterned.
- **Doors that look like walls.** In BUNYIP the user couldn't see doors. Doors must have a clearly
  distinct texture. The v0.1 door texture (type 5, white/cyan panel with a yellow handle) is a start.
- **"System-looking" fonts, bleepy/bloopy sounds and a weedy little gun** were all rejected in BUNYIP.
  See §10.
- **Lessons from the simulator's own past bugs:** none recorded for this project yet.

---

## 9. Known bugs, limitations, unfinished

- Simulator (`mzemu.py`) doesn't model VRAM wait states, real keyboard ghosting, or 8253 sound.
  Its Z80 core supports only the instructions this program uses: no IN/OUT, IM2, RLD/RRD,
  CPI/CPIR/INI/OUTI etc. (it raises "ED op not implemented"). Extend it before using new instructions.
- `zasm.py` is a **subset assembler**: no macros, no IF/conditionals, no local labels,
  no IN/OUT, limited expressions (Python `eval` of symbols), and `DSC` supports only
  A–Z 0–9 space and `.`. A string containing other characters raises an error.
- Collision is a simple 0.16-cell probe per axis. There's no strafing.
- Texture u isn't mirrored per facing, so asymmetric textures appear mirrored on some faces
  (the current textures are mostly symmetric).
- The map is fixed at 16×16 (index math assumes stride 16, and the map is page-aligned).
- MZT includes 880 bytes of empty BUF.
- **DROPBEAR 3D source location not confirmed.** Memory says it was saved to the user's PC and
  GitHub as a "Dropbear3D" folder, but it is **not** in `vz300-and-microbee-games` and not in
  `Documents\Codex`. It may be in the private repo `imbrendenmurphy-dev/retro-conversions-PRIVATE`
  or elsewhere on the PC. **Ask the user before porting game content.**
  The sibling Microbee version BUNYIP is at `C:\Users\Owner\Documents\Codex\Bunyip-Microbee-Claude`
  (and `Bunyip-Microbee` in the repo). It's a useful reference for game structure.

---

## 10. Outstanding work and priorities (in order)

1. **Get real-MZ-700 results:** the user loads `release/MZRAY.MZT` through UniCMT and photographs the
   results screen. Also confirm that the cursor keys, 1–4 and B work. Compare with the emulator figures.
2. Decide the render mode from real figures. Likely candidates: 20 rays direct (~21 fps emulated)
   or 40 rays direct (~13 fps emulated).
   Possible optimisations to evaluate **only after measuring**:
   - write only changed cells / skip ceiling-floor writes when unchanged
   - draw during vblank / reduce VRAM touches
   - try 2×2 block-glyph mode for resolution
3. Design the game as a DROPBEAR 3D conversion. Features DROPBEAR 3D has (user-requested on VZ300):
   - nine connected areas with maze puzzles, colour schemes and room themes, and bosses
   - several enemy types per area, plus smaller varied ones
   - enemies exploding into pixels when killed (not vanishing)
   - incidental furniture and decorations that don't slow rendering
   - a stylised Doom-parody title font and a tense, ominous title jingle
   - an attract sequence: a humorous, self-deprecating monster gallery (brief jingle per monster),
     then an AI demo of a different level each cycle
4. Fit it in 64K. The area data probably needs compression. If it doesn't fit, split it into
   episode MZTs (test chain-loading with UniCMT first).

### User preferences to honour (from their other projects)
- Forgiving difficulty: they hate insta-death. Use health bars with several hits per life.
- Humorous, self-deprecating tone. Difficulty names in the style of "Hurt me plenty".
- Sound: gritty and satisfying (spurts, squelches, wuckas), not bleepy. In-game music is slow
  and sparse ("dink, dink-dink-dink") so it doesn't steal CPU. Title music should have a phat
  multi-channel feel (arpeggios on the single MZ-700 channel). Write an original player.
- The gun should be stylised and chunky, filling its cells. No plain system fonts on titles.
- Credits: **VIBED BY BPM 2026**.
- Keep progress saved to the PC folder **and** GitHub as work goes on.
- The user isn't a coder: give them a file to load and tell them what to test and photograph.

---

## 11. File structure and build

```
MZRay-MZ700/
  CLAUDE.md                this file
  README.md                user-facing description
  release/MZRAY.MZT        current build (copy to UniCMT USB stick)
  src/mzray.asm            Z80 source (with ;@@ placeholders filled by build.py)
  src/build.py             table/texture generator + assembles + writes MZT/sym
  src/tools/zasm.py        subset Z80 assembler (two-pass; DSC display-code strings)
  src/tools/z80.py         Python Z80 CPU core with approximate T-states
  src/tools/mzemu.py       minimal MZ-700 model: RAM, VRAM, 8255 keys, vblank, PNG screenshots
  src/tools/runtest.py     runs the 4-test benchmark, prints field counts, saves screenshots
  src/tools/walktest.py    renders walk-mode views, tests keys/mode switch/B restart
  screenshots/             simulator and Win32-emulator screenshots
```

### Build (Windows, from `src`)
Needs Python 3. Pillow is needed only for the test scripts' screenshots.
```
cd src
set PYTHONPATH=tools           (PowerShell: $env:PYTHONPATH="tools")
python build.py                -> MZRAY.MZT, mzray.sym, mzray_full.asm in src/
fc /b MZRAY.MZT ..\release\MZRAY.MZT   (should match until code changes)
python tools\runtest.py        -> prints fields per test; writes shot_*.png
python tools\walktest.py       -> walk*.png, key/mode tests
```
Generated files (`MZRAY.MZT`, `mzray.sym`, `mzray_full.asm`, `*.png` in src) aren't committed.
Copy a release build to `release/`. The test scripts look for `MZRAY.MZT` and `mzray.sym` in the
current directory, so run them from `src` after building.
Expected simulator output for v0.1: `fields per 32 frames: [51, 58, 94, 102]`.

### Testing procedure
1. Build, and run `runtest.py` (a regression check against the numbers above, unless the change is intended).
2. Load in the user's **MZ-700 Emulator For Win32** to check visuals and approximate speed
   (v0.1 reference: 76/85/125/134 fields).
3. The user tests on the real MZ-700 via UniCMT and sends photos. Real-hardware numbers are the
   only ones that decide design.

---

## 12. Repositories and locations

- GitHub: **https://github.com/imbrendenmurphy-dev/VZ300-and-MIcrobee-games** (public, branch `main`),
  folder **`MZRay-MZ700/`**. This repo holds the user's *original* games. The top-level README
  was updated to mention the Sharp MZ-700. Copyrighted conversions go in the separate private repo
  `retro-conversions-PRIVATE`, never in this public one.
- Repo convention per game: `README.md`, `release/`, `src/`, `screenshots/`.
  `.gitignore` excludes ROMs and tape dumps (`*.rom *.mzf *.tap *.z80 ...`). Never commit ROMs.
- PC copy: `C:\Users\Owner\Documents\Codex\MZRay-MZ700-Claude\` (same layout; plain copy, not a git
  clone). Recommended: clone the repo to e.g. `C:\Users\Owner\Documents\Codex\vz300-and-microbee-games`
  and work there, keeping `MZRay-MZ700-Claude` in sync, or ask the user which they prefer.
- Commit author used so far: "BPM".
- Related projects: VZ300 DROPBEAR 3D (source location TBC, see §9);
  Microbee BUNYIP (`Bunyip-Microbee` in repo, `Bunyip-Microbee-Claude` on PC).
  Measured BUNYIP speed on the real Premium Plus: ~25 fps at 80 rays, 31 fps at 40 rays.
