# CLAUDE.md - REDBACK (working title) handover

Original Uridium-inspired horizontal shoot-'em-up for the **Microbee Premium Plus**, Z80 only.
Credits line must read **"VIBED BY BPM 2026"** (the owner's wording; do not change it to "directed by..." etc.).
The owner is a retro-computer enthusiast, not a coder: explain choices briefly, report honestly, and never
claim hardware verification that has not happened.

## 1. Purpose and the original brief
* Phases: **1 technical demo (DONE in model)**, **2 combat engine (DONE in model, 2026-11-19)**, 3 complete game, 4 presentation/polish, 5 disk integration/testing.
* Brief requirements: Z80-only (no ColdFire); full-screen 40-column PAL; PCG RAM used as a bitmap; **1-pixel smooth
  scrolling both ways at 50 Hz**; detailed capital-ship decks; fast agile craft with banking and an animated 180-degree
  reversal; enemies, collisions, explosions, capital-ship destruction sequence and an escape run; sound and music
  (distinct music, effects, jingles); title, attract mode, HUD, joystick + keyboard.
* **5 capital ships** (owner decided 5 is enough, the brief said 8).
* Deliverable disk: bootable double-sided 80-track `.DS8` that boots to the CP/M prompt and does **NOT** auto-launch;
  the game is a `.COM` started by hand and returns cleanly to CP/M. Must work on uBee512 AND real hardware.
* Also wanted: documented source, build scripts, technical docs, uBee512 test results, a list of what is unverified on hardware.
* Owner has not yet commented on the working title REDBACK.

## 2. Status (read this first)
**Everything below was tested only in my own C Z80/Premium-Plus model (`tools/emu`). Nothing has been run in uBee512 or on real hardware.**
The owner looked at the emulator build and said it "looks good" (which emulator they used is not recorded - ask).

| Item | State |
|---|---|
| 40-col PAL CRTC table, 313 lines | model OK; table itself is the one verified earlier on the owner's hardware (MODES.COM) |
| 1-px scroll both directions, up to 7 px/frame | model: pixel-exact, zero display-time writes (`scrolltest.py`) |
| Pair-glyph residency + load queue | model OK |
| Sprite compositor (player + 4 demo enemies) | model: pixel-exact vs Python model (`sprtest.py`) |
| Player: thrust/drag, vertical, banking, 10-frame 180-degree turn | implemented, visually checked in screenshots only |
| HUD (rows 0 and 24): score, ships, X, idle %; credits + PHASE 2 / GAME OVER | works; letters touch (font spacing) |
| ESC -> restore CP/M screen/font -> `JP 0` | model OK |
| Loader `REDBACK.COM` + `REDBACK.DS8` | Phase 1 disk: cold boot in model OK (bn60.rom -> CP/M -> `REDBACK` -> fly -> ESC -> A>). **Phase 2 disk (4th sprite file, block 17): boot test NOT re-run** (ROM not on the Windows PC) |
| Phase 2 combat (`src/combat.asm`): shots, drone waves, interceptors (home + fire), box collisions, explosions, score, 3 ships, invulnerable respawn, GAME OVER -> new game | model: works (`combattest.py`), every frame pixel-exact (`sprtest.py` combat flight); gameplay feel unreviewed by the owner |
| Sound/music, deck-structure collisions, capital-ship destruction, escape run, title, attract, levels | **NOT STARTED** |

Measured Phase 2 (model; frame period 1.00 = 50 Hz): perf.py still/right/left/right+up/left+down all 1.00, **0 dropped** in 1,150
frames, 51-59% busy; 60 s scripted fight (`combattest.py 3000`): 12/3000 dropped (0.4%), 0 tears. Phase 1 was 3/300 dropped right.
A "dropped" frame = period 2.0 (a load spike or 30+ sprite cells). Full output: `docs/TEST_RESULTS.txt`.

**Windows (the owner's PC, Win10)**: build with `build_win.cmd` (GitHub Desktop's bash + `tools/win/python3` -> `py`). The model is built
with TinyCC into `tools/emu/mbee.dll` (`tools/mbee.py`, `tcc -shared -rdynamic`); TinyCC 0.9.27 win64 is unpacked in `tools/tcc/tcc`
(not in git; from download.savannah.gnu.org/releases/tinycc/). No gcc/WSL there, and C: is nearly full (Zig did not fit).
Local git repo in the folder (author BPM), not yet pushed to GitHub.

## 3. Target hardware and constraints
* Microbee Premium Plus, 1 MB RAM (32 blocks x 32K), 6545 CRTC, 32K PCG RAM, colour + attribute RAM, Z80 (~3.375 MHz).
* 40x25 cells of **8x10 px**. CRTC table `35 28 2C 34 1E 03 19 1C 48 09 20 09 00 00 00 00` (regs 0-15). 40-col clock: `ld a,1 / in a,(09h)`
  (restore with A=0). 313 lines at 50 Hz; the model uses 67,500 T per frame, a 312-line model, vblank at line >= 250.
* Ports: `50h` memory map (block select into the lower 32K window, ROM off, video window at F000); `1Ch` video select
  (`$80` screen at F000 / PCG bank n at F800 via low bits, `$90` attribute RAM); port `08h` bit 6 = colour RAM at F800;
  6545 status bit 5 = vblank; port `09h` dot clock.
* `mv(blk) = ((blk&$1C)<<3) | ((blk&3)^2) | 4` is the port-50h value for block `blk` with ROM off + video window.
* **Monitor constraint (from Starhive work):** the monitor will not accept a changing frame length, so CRTC **R5 fine scroll must not be used**.
* Z80 only. Real-hardware limits matter: avoid undocumented instructions (IXH/IXL...) - see section 7.

### Memory map (program in block 0 upper half; lower 32K window is switchable)
* Program `ORG $8000`, currently 5,632 bytes (`build/REDBACK.BIN`); the loader copies only 8K (`PROG_LEN`), asserted in `redback.asm`.
* `SHC=$C000` (screen shadow), `RES=$C800`, `PCOL=$C900`, `Y10=$CA00`, `YM=$CB00` (line -> row / line-in-row),
  commit lists `TOPA=$D800 TOPB=$D980 BOTA=$DB00 BOTB=$DC80`, load queue `LDQ=$E700`, `HUDC=$E800`,
  `EXIT_VID=$E8FE`, `EXIT_PORT=$E8FF` (written by the loader), `VARS=$E900`, `STACK=$EFF0`.
* Blocks: **8 PAIRS** (pair records at 0, sprite index at `$4000`), **12 DECK** (deck columns), **13, 14, 15, 17 = SPR0-3** (sprite cell streams;
  `SPR_BLOCKS` in `sprites.py` skips 16; the loader's list is generated into `build/sprfiles.inc`, `mkdisk.py`/`rbtest.py` glob `SPR*.BNK`),
  16 = CP/M's saved video state, 27 = program staging in the loader. Blocks 8..27 are "ours"; CP/M lives in a block < 8 (it was block 2 in the model).
* PCG banks: 0-7 = scroll phase banks k, 8/9 = sprite glyph pool (alternate per frame), 12 = HUD font. 128 slots per bank, code = `$80|slot`.
* Screen RAM is a 2K ring: cell address = `S_phys + 40*row + col`, `S_phys = RING0($100) + S`, so it never wraps.

## 4. Source layout and build
```
build.sh                 builds everything (python3 + numpy + Pillow only; no network needed)
src/hw.inc               ports, memory map, block constants
src/redback.asm          the engine (ORG $8000) + ESC quit
src/combat.asm           Phase 2: waves, enemies, shots, bullets, collisions, explosions, score/ships/GAME OVER
src/input.asm            keyboard (6545 light-pen matrix scan) + joystick (PIO), from Starhive
build_win.cmd            Windows build (runs build.sh with GitHub Desktop's bash; tools/win/python3 -> py)
src/loader.asm           REDBACK.COM CP/M loader (from Starhive's, adapted)
tools/zasm.py            our assembler (own dialect: MACRO/ENDM, REPT/ENDR, INCLUDE, ASSERT, SAVEBIN; NO FUNC/ENDF)
tools/makedata.py        deck + pairs + sprites + font + sine -> build/*.BNK, data.inc, font.inc, sine.inc
tools/deckart.py deckpack.py   capital-ship deck art and static pair-slot allocation (WINDOW columns)
tools/sprites.py         sprite art + 8-shift x 10-line-offset prerender into cell streams
tools/font.py            HUD font (includes '+')
tools/build_disk.py mkdisk.py  CP/M DS8 writer (80 trk x 2 sides x 10 x 512, skewed) -> build/REDBACK.DS8
tools/mbee.py emu/       ctypes wrapper + C model of the Premium Plus (mbee.c, z80.c; libmbee.so is a Linux build, rebuild with gcc elsewhere)
tools/rbtest.py scrolltest.py sprtest.py perf.py spike.py boottest.py prof.py run.py   tests / profilers
tools/combattest.py dropprof.py   Phase 2: scripted fight (keys_at), dropped-frame profile
resources/               boot_tracks.bin (system tracks from the owner's Microbee boot disk), CCP.SYS
build/                   outputs: REDBACK.DS8, REDBACK.COM, REDBACK.BIN, *.BNK, redback.sym
docs/                    TECHNICAL.md, TEST_RESULTS.txt, DISK_README.TXT
```
Build: `./build.sh`. The assembler must be run **from `src/`** (SAVEBIN paths are relative); `build.sh` does that and writes `build/redback.sym`
(tests need the symbols - a stale `.sym` mislabels profiles).
Windows: needs Python 3 + numpy + Pillow; run the steps of `build.sh` by hand or via Git Bash. The model needs gcc to rebuild `libmbee.so`
(`tools/emu`, check `tools/mbee.py` for the expected output name) - the shipped `.so` will NOT load on Windows. For Windows, build `mbee.dll`/adjust `SO` in `mbee.py`.
Tests (run from `tools/`): `python3 scrolltest.py`, `sprtest.py`, `perf.py`, `boottest.py <path to bn60.rom>` (the ROM is the owner's, NOT in the repo:
`Codex\2026-11-16\i\work\emu\roms\bn60.rom` on their PC).

## 5. Rendering architecture (hard-won - preserve)
### 5.1 Scroll: phase-bank pair glyphs
* Deck is a grid of 8-px-wide cells. For adjacent deck cells A,B a **pair glyph at phase k = `((A<<8|B) >> (8-k))` & 0xFF** (10 lines).
  Phase k of every pair slot lives in **PCG bank k**; code = `$80|slot` is identical in all banks.
* **1 pixel of scroll = rewrite the attribute byte (= bank number k) of the 920 playfield cells (rows 1..23)** with a **PUSH fill**
  (~5.5K T, handles odd/even start parity). Screen codes are untouched between coarse steps.
* Every 8 px (k wraps): move CRTC start address R12/R13 by 1 (written in the blanking) and write **one new column**
  (forward: ring cell `S_phys+40r+39`; reverse: `S_phys+40r`). HUD rows 0/24 are rewritten per coarse step (LDIR codes, edge attr/colour).
* X is 24-bit; `S = X>>3`, `k = X&7`; `stepd` in {0,1,255} is the coarse step this frame; `ea0` = ring address of the entering row-1 cell.
### 5.2 Residency of pair glyphs
* `tools/deckpack.py` statically assigns pair slots so any WINDOW (46) consecutive columns have distinct slots (163 pairs for the 200-col demo deck, 128 slots/bank).
* `RES[slot]` holds the ref word of what's resident. `scan_col` compares the entering column and queues loads in `LDQ`;
  `do_loads` (budget `LOADMAX`=6/frame; `flush_loads` for the preload) calls `load_pair` = 8 phases x 10 bytes by LDI and sets `PCOL[slot]`
  from the record's 81st byte. Window [S-2, S+41]; mean 1.0 loads/column, max 15. A column is scanned 2 columns before it is visible, so a spike spreads over frames.
* **`do_loads` must always map PAIRS (`MV_PAIRS`) first, even when the queue is empty** - `sprites_build` reads the sprite index from the PAIRS block (a bug when it did not).
### 5.3 Colour
One colour per pair slot (`PCOL`). A sprite cell takes the scenery cell's **paper** nibble plus the sprite's **ink**.
### 5.4 Sprites: prerendered cell stacks (current design)
* `sprites.py` renders each frame (lit pixels only, cropped per family P_/D_/I_/J_/S_/B_/X_; family = text before the first `_`) for all 8 x-shifts x 10 line offsets, as a list of
  **non-empty 8x10 cells**: record `[N]` then `N x [dcol, ring delta (r*40+c), row, 10 bytes]`. Index in PAIRS block at `$4000`:
  4 bytes per (frame, shift, yo) at `SPRIDX + 4*(80*f + 10*s + yo)` = [port value of the sprite block, ptr lo, ptr hi, ink].
* `spr_draw`: clamp y to 199, `cx` = arithmetic `x>>3` (reject if cx+4 >= 44), `r0=Y10[y]`, `yo=YM[y]`, `a0 = S_phys + 40*(r0+1) + cx`, look up index, `out (50h)` to the sprite block, then per cell
  (`sp_cell`): column clip (`cx+dcol` unsigned < 40), pool glyph allocation (`poolcnt`/`poolptr`, `POOLMAX`=80), scenery paper lookup via `SHC`/`PCOL`,
  4-byte commit entry `[addr lo, addr hi|F0, code, colour]` appended to the T list (playfield row < 4) or B list, then 10x LDI of the cell into the pool glyph.
  Cell counter lives in **A'** (`ex af,af'`), restored to `MV_PAIRS` at the end.
* **Commit** (`commit` in the main loop after `frame_wait`): `set_crtc` on a step, `fill` of attributes, HUD edge, `commit_ent` (entering column from SHC/PCOL),
  then restore last frame's sprite cells (attr = k, code/colour from SHC/PCOL) and write the new ones (attr = pool bank), in two windows
  (`LV_ATTR`+`COL_ON`, then `LV_SCREEN`). **Phase 2: `commit_list` does the top list completely (both windows) before the bottom list**
  (before, all attributes went first and ~30 cells tore the top rows), and on a step the bottom HUD row is written last (`hudlate`).
  Writes stay ahead of the raster beam (beam-aware tear counter in the model).
* Pool banks 8/9 alternate each frame; the pool bank stays selected while compositing, glyphs allocated sequentially (`F800 + 16n`).
### 5.5 Player
Thrust AX=90, DRAG=40, VMAX=$680 (6.5 px/frame); vertical AY=110, DRAGY=60, VYMAX=$300. Turn state machine (`tcount` 1..10 through frames P_T30..P_T150),
scroll lead targets TXR=80 / TXL=212 px, banking frames P_RU/P_RD/P_LU/P_LD. `player_update` reads `pinp` (= `inp`, or 0 while exploding / GAME OVER).
### 5.6 Frame loop
`main`: `frame_wait` (counts idle iterations at 36 T each - the idle % shown on the HUD is inflated if frames are skipped, so measure real periods via ticks with `perf.py`)
-> `commit` -> `logic` (`readinp`, ESC check, `player_update`, `scroll_update`, `combat` (skipped when `nospr`), map PAIRS, `sprites_build`,
**then** the pair loads (`dl0`) with a budget of 6 / 4 / 3 for < 16 / 16-23 / 24+ sprite cells, always 6 if more than 6 are queued, then `hud_update`).
### 5.7 Combat (Phase 2, `src/combat.asm`)
16-byte object records (layout documented at the top of the file): 4 enemies, 2 shots, 2 bullets contiguous at `objs`, plus `pobj` (the ship's box).
Positions are world x (screen x = wx - xpos, recomputed every frame into +8/9). `objs_draw` draws every live object between screen x -32 and 319,
then the player last. Waves: 4 drones on one sine path, or 2 interceptors (home on the ship's height, fire every 45 frames); random = LFSR (no R
register, so tests repeat). Box collisions in `hitc`. Score BCD (`add_score`), `lives`, `pstate` 0 fly / 1 exploding (`ptimer`) / 2 GAME OVER.
Sprite sizes for the boxes come from `data.inc` (`W_x`/`H_x` per family, written by `makedata.py`).

## 6. Important engineering decisions (and why)
* **PCG bitmap via phase banks**, not CRTC R5, not per-frame glyph rewrite: only attribute bytes change per pixel => ~5.5K T per frame, leaving ~60% of a frame for logic. Pixel-exact both ways.
* **Static slot allocation + 2-column look-ahead** instead of dynamic caching: constant, bounded load work (mean 1/column).
* **Sprites replace the whole scenery cell** (lit pixels only, scenery paper kept): avoids reading/merging background bytes. Cost: scenery detail disappears under a sprite cell (visual trade-off, see section 8).
* **Prerendered cell stacks (87,886 bytes in 3 blocks)** trade RAM (we have 1 MB) for CPU: no shifting at runtime.
* **Shadow screen `SHC`** lets restores/lookups avoid reading video RAM through the window.
* Commit lists are split T/B and double-buffered so top rows are written first; the beam never overtakes the writes.
* Loader finds CP/M's block by signature scan and saves/restores CP/M's screen, attr, colour and font banks 0-1 (block 16) exactly like MODES.COM, so ESC can return cleanly.
* Credits text and the "no auto-launch, no SHELL" disk policy come from the owner's brief/house style (no `SHELL.SYS` on the disk; asserted in `mkdisk.py`).

## 7. Failed approaches / do NOT reintroduce
* **CRTC R5 fine scroll / varying frame length** - monitor rejects it.
* **First sprite compositor** (column strips with keep/data mask, per-cell shifting, DOCELL with jump into an unrolled LDI sequence, 3-segment vertical placement): ~1.4K T per cell, 25 fps when moving. Replaced by prerendered cell stacks. Don't go back.
* **Undocumented `IXH/IXL` registers** (used once as a loop counter): avoided for real-hardware safety. Use `ex af,af'` counters instead.
* **`exx` as a spare-register trick**: `exx` swaps BC, DE **and** HL - it does not give a free B. It silently corrupted `ent_col` (the game restarted when scrolling). Use `ex af,af'` only for a counter.
* Missing `jp` conversions: many `jr` branches are out of range in this engine; use `jp` where the assembler complains (`jp nz,.col` etc.).
* Signed 16-bit clamps: use `jp m`, not a carry compare; the player vertical clamp must use the signed value, not `bit 7,h`.
* `FUNC/ENDF` in include files is unsupported by `zasm.py`; HUD template strings must be exactly 40 characters (ASSERT); don't leave a duplicate `sine` label.
* Don't start the test before `init_vars` has cleared state (`wait for start_addr`); the program needs ~23 frames to start.
* Don't trust the HUD idle % when frames are dropped (see 5.6).
* Don't commit scenery restores before new sprite writes, and don't write bottom rows first (tears).

## 8. Known bugs, limitations, unfinished
* **Unverified on uBee512 and hardware** - the biggest risk; timing assumes the model's raster/blanking numbers (67,500 T/frame, ~13.4K T blanking, row 1 starts ~15.5K T after blanking begins).
* ~0.4% dropped frames in a 60 s fight (period 2.0): ~21+ sprite cells together with pair loads, or 30+ cells alone. Possible fixes: cap cells per
  frame for enemies (keep the player's), cheaper `restore`, cheaper `readinp` (keytest ~280 T per key, 10 keys), snap shot y so a shot never spans 2 rows.
* Combat gameplay values (speeds, wave mix, fire rate, invulnerability) are first guesses, not tuned with the owner. No sound yet. Enemies
  ignore deck structures (no deck collisions yet: Phase 3 needs "tall" deck cells for Uridium-style crashes). Waves stop at the deck ends only
  because the ship does; enemies can fly over space.
* `smoke bomb` keys M/Z are no longer scanned (saves ~560 T); re-add them to `keymap` in `input.asm` when the feature exists.
* One "tear" frame in the 'still' scenario (beam model), unexplained.
* Sprite cell clearing hides scenery detail; overlapping sprites replace each other's shared cell.
* HUD font letters touch (8-px glyphs without gap) - looks cramped; "REDBACK"/"VIBED" first letters look odd. Not clipping.
* After ESC the PIO/joystick setup is not restored; text-mode screenshot rendering in the model after exit looked garbled although `text()` and a byte comparison show video RAM/font restored exactly (model renderer artefact suspected, unverified).
* `src/redback.asm` still contains leftover unused variables (`sp_cc`, `sp_cols`, `sp_h`, `sp_n1..`), harmless.
* Keyboard uses the 6545 light-pen matrix scan like the ROM; joystick via PIO A; neither verified on hardware here.
* Title/attract, music, SFX, 5 capital ships, deck collisions, destruction sequence, escape run, levels: not built.

## 9. Outstanding work and priorities
1. **Verify on uBee512 and on the real Premium Plus** (owner to run `REDBACK.DS8`, now the Phase 2 disk; also re-run `boottest.py` with bn60.rom
   since the loader loads a 4th sprite file); fix whatever differs (blanking timing, PIO, keyboard). Record results in `docs/`.
2. Decide the working title with the owner; get the owner's feel for the combat (speeds, difficulty).
3. Phase 2 is done in the model. Re-run `scrolltest/sprtest/perf/combattest` after every change; keep the 50 Hz budget (51-59% busy now).
4. Phase 3: 5 capital ships (more deck art, longer decks, per-ship colours - mind the 128-slot / WINDOW=46 packing), ship destruction + escape run, levels, music/SFX (Z80 PSG-less: Microbee beeper/PIO speaker; owner likes VZ-style beeper music).
5. Phase 4: title/attract, polish (HUD font spacing, sprite look, optional cell-merge to keep scenery under sprites).
6. Phase 5: finalise disk, docs, uBee512 + hardware test notes.
Do not make drive-by rewrites of working systems (scroll, commit, compositor).

## 10. Testing procedures
Run from `tools/` after `./build.sh`:
* `python3 scrolltest.py` - pixel-exact scroll vs reference over accelerate/coast/reverse/again; expects "ALL EXACT".
* `python3 sprtest.py` - every committed frame vs a Python deck+sprite model; expects "ALL EXACT"; also counts writes ahead of/behind beam.
* `python3 perf.py` - frame period/busy % for still/right/left/right+up/left+down; `spike.py` shows the per-routine profile of dropped frames; `prof.py` T-state profiler.
* `python3 combattest.py [outdir] [frames]` - scripted fight: score/kills/deaths/GAME OVER, dropped frames, tears, pc check, screenshots
  (incl. first enemy explosion, ship explosion, GAME OVER). `dropprof.py [frames]` - dropped frames of the same flight with a profile.
  `sprtest.py` now ends with a 600-frame "combat flight" scenario. (On Windows use `py` instead of `python3`; in PowerShell don't pass "" as an argument.)
* `python3 boottest.py <bn60.rom> [outdir]` - boot ROM -> CP/M -> `REDBACK` -> fly -> ESC -> A>.
Verified (model only): see section 2 and `docs/TEST_RESULTS.txt`. The model is my own C emulator, not uBee512.

## 11. Repository and delivery
* GitHub account `imbrendenmurphy-dev`. Original games live in the public repo **`VZ300-and-MIcrobee-games`** (one folder per game); this project is in folder `Redback-Microbee/`.
  No separate REDBACK repo exists. Existing `Microbee` repo is for the earlier ports.
* Owner wants progress saved to their PC and GitHub as work continues. PC copy: `C:\Users\Owner\Documents\Codex\Redback-Microbee-Claude` (DS8 + source zip).
* The test emulator's Z80 core resembles superzazu/z80 (MIT) - testing only, not part of the game (the games repo README mentions this).
* Related: Starhive (`Starhive-Microbee`, source of the toolchain, loader and soft-scroll ideas) and Hullbreach (MODES.COM in `modetest/`, the CP/M video save/restore model).
