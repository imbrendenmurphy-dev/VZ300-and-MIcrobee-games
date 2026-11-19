# REDBACK - technical notes (Phase 2: combat)
VIBED BY BPM 2026 - Microbee Premium Plus, Z80 only, 40-column PAL, PCG-bitmap scrolling

## Status
Phase 1 (technical demo) and Phase 2 (combat engine) are built and tested **in my own Z80 / Premium Plus
C model only**. Nothing has been run in uBee512 or on real hardware. See "Unverified" below.

Run: boot `REDBACK.DS8` (comes up at the CP/M prompt, no auto-launch), type `REDBACK`.
Keys: Q/A/O/P or cursor keys or joystick (PIO A); SPACE or the joystick button fires (hold = auto-fire);
ESC returns to CP/M.

## Combat (Phase 2, `src/combat.asm`)
* Objects: 4 enemy slots, 2 player shots, 2 enemy bullets, one 16-byte record each (layout at the top of
  `combat.asm`): world x, line, velocity, frame, screen x, timers, collision box.
* Waves (`spawn_update`): 3 in 4 are 4 drones entering one behind the other on the same sine path; 1 in 4 are
  2 interceptors that climb/dive towards the ship's height and fire a bullet every 0.9 s while on screen.
  Waves enter ahead of the ship (the side it faces), 14 frames apart, the next wave 1.0-2.3 s later.
  Enemies are removed once 48 px off screen. Random numbers: 16-bit LFSR (repeatable for the tests).
* Shots: 12 px/frame plus the ship's own speed, from the nose; one every 7 frames while fire is held,
  not while turning; gone at the screen edge or after 24 frames.
* Collisions: box against box in screen coordinates (`hitc`); the ship's box is 3 px narrower on each side and
  2 lines shorter top and bottom than its sprite. Shot hits enemy: 4-frame explosion (X_0..X_3, 16 frames),
  drone 100, interceptor 250. Enemy or bullet hits ship: the ship explodes (32 frames of X_0..X_3, no control,
  it drifts to a stop), 60 frames later the next ship arrives blinking and cannot be hit for 2 s; the screen
  is cleared of enemies. After 3 ships: GAME OVER on the bottom HUD row for 5 s, then a new game.
* HUD row 0: `SCORE:000000 SHIPS:3 X:0000 IDLE:00%`; row 24: credits + `PHASE 2 COMBAT TEST` / `GAME OVER`.
* New sprites: S_R/S_L (shots), B_0 (bullet), X_0..X_3 (explosion), J_0/J_1 (interceptor nose right).
  Sprite streams are now 125,914 bytes in 4 blocks: 13, 14, 15 and **17** (16 holds CP/M's saved screen).
  The loader's file list for them is generated (`build/sprfiles.inc`).

### Engine changes made for Phase 2 (all measured, see TEST_RESULTS.txt)
* **Commit order**: the sprite cells are now committed per list, top rows completely (attribute+colour, then
  codes) before the rest (`commit_list`). Before, all attributes were written before any code, so with ~30 cells
  the top rows' codes came after the beam (20 tear frames in a sprite-test scenario). The routines restore1/
  new1/restore2/new2 are unchanged.
* On a coarse-step frame the **bottom HUD row** (row 24) is written after the sprite cells (`hudlate`): it is
  the last row the beam draws. That freed ~850 T for the top rows (fixed tears in fast leftward flight).
* **Pair loads after the sprites**, with a budget that shrinks with the sprite cell count: 6 loads (< 16 cells),
  4 (16-23), 3 (24+), but always 6 when more than 6 loads are queued (so a load spike is never starved). The
  loads are for columns two ahead of the screen, so moving them later in the frame changes nothing visible
  (the sprite test, which compares every frame including scenery, stays exact).
* M / Z (smoke bomb, not implemented) are no longer scanned: ~560 T a frame.

## Display
* 6545 table `35 28 2C 34 1E 03 19 1C 48 09 20 09` (the table verified on your hardware with
  MODES.COM): 40 x 25 cells of 8 x 10 px, 313 lines, PAL 50 Hz. 40-column dot clock = `LD A,1 / IN A,(09h)`.
* Row 0 and row 24 are the HUD (fixed font bank 12); rows 1..23 are the 230-line playfield.

## Scroll technique (all Z80)
* PCG RAM is the bitmap. The deck is built from "pair glyphs": for two adjacent 8-pixel deck cells
  A,B the glyph for scroll phase k (0..7) is `((A<<8|B) >> (8-k))` (8 bits). Phase k of every pair
  lives in PCG **bank k** (same code in every bank, 128 slots, code = 80h|slot).
* One pixel of scroll = rewriting the *attribute byte* (the bank number k) of the 920 playfield cells.
  Done with a PUSH fill (~5.6K T-states), once per frame, in the vertical blanking.
* Every 8 pixels the CRTC start address (R12/R13) moves by one cell in a 2K ring and one new column
  of codes is written at the entering edge (forward: ring cell +39, reverse: +0). R5 fine scroll is
  not used. Both directions are pixel-exact, up to 7 px/frame (350 px/s).
* Residency: a static slot allocation (`tools/deckpack.py`, window 46 columns) means a column's pairs
  are loaded (8 phases x 10 bytes, LDI) only when the column enters the residency window
  [S-2, S+41]. 163 pairs for the 200-column demo deck; mean 1.0 loads per column, max 15.
  Loads are budgeted (6 per frame) and spread by the 2-column look-ahead.
* Colour: one colour per pair slot (PCOL); a sprite cell takes the scenery's paper plus its own ink.

## Sprites
* The craft, drones and interceptor are pre-rendered for all 8 x-shifts x 10 line offsets
  (`tools/sprites.py`): each variant is a list of non-empty 8x10 cells (dcol, ring delta, row, 10 bytes),
  87,886 bytes in 3 RAM blocks (13..15); an index in the PAIRS block points to them.
* `sprites_build` allocates glyphs in a pool PCG bank (8/9, alternating per frame), copies the cell
  bytes (LDI) and builds 4-byte commit entries `[addr lo, addr hi|F0, code, colour]`, split into a
  top list (playfield rows 0-3) and a bottom list. The commit restores last frame's cells and writes
  the new ones, top rows first so the writes stay ahead of the raster.
* **Known visual trade-off:** a sprite cell *replaces* the scenery cell (paper + sprite ink), so scenery
  detail under a touched 8x10 cell disappears. Overlapping sprites replace each other's shared cell.

## Player craft
Thrust/drag horizontal (6.5 px/frame max), vertical movement, banking frames (up/down), and a
10-frame 180-degree reversal (nose-right -> 30/60/90/120/150 -> nose-left) with the scroll lead
shifting from 80 to 212 px as the ship turns.

## Memory map
Program 8000h (5,632 bytes; the loader copies at most 8K); SHC (screen shadow) C000, RES C800, PCOL C900, Y10 CA00, YM CB00,
commit lists D800-DCFF, load queue E700, HUD codes E800, vars E900 (objects at the end), stack EFF0.
Blocks: 8 PAIRS (pair records + sprite index), 12 DECK, 13-15 and 17 SPR0-3, 16 saved CP/M video state.

## Loader / disk
`REDBACK.COM` (CP/M): finds CP/M's own RAM block by signature scan, checks 1MB RAM, saves CP/M's
screen/attribute/colour/font banks 0-1 to block 16, loads the `.BNK` files straight to their blocks,
stages the program in block 27, then a final stage at F000h copies it to 8000h and jumps.
On ESC the game restores the 80-column CRTC table, the saved video state and CP/M's lower block,
then `JP 0` (same method as MODES.COM). `REDBACK.DS8`: 80 tracks x 2 sides x 10 x 512, system tracks
from your Microbee boot disk, `CCP.SYS`, no `SHELL.SYS`, nothing auto-launches.

## Measured, Phase 2 (model, see TEST_RESULTS.txt)
| scenario | frame period | dropped frames | CPU busy |
|---|---|---|---|
| perf.py still / right / left / right+up / left+down | 1.00 | 0 in all 1,150 frames | 51-59% |
| combattest.py, 60 s scripted fight | 1.004 | 12 / 3000 (0.4%) | 59% avg |
Pixel-exact (sprtest, incl. a 600-frame combat flight): all frames; tears 0 except the old 'still' one.

## Measured, Phase 1 (model)
| scenario (player + 4 enemies) | frame period | dropped frames | CPU busy |
|---|---|---|---|
| still | 1.00 | 0 / 150 | 53% |
| right (7 px/f) | 1.01 | 3 / 300 | 42% avg |
| left | 1.00 | 0 / 300 | 30% |
| right+up | 1.01 | 3 / 200 | 50% |
| left+down | 1.00 | 0 / 200 | 34% |
Dropped frames (period 2.0) occur when a load spike coincides with many sprite cells (about 1%
forward). Pixel-exactness: all frames equal the reference in both directions, zero display-time writes.
One 'tear' frame was counted in the still scenario (model beam check) - not yet explained.

## Unverified / risks
* Everything above is from my own emulator model. uBee512 and real hardware are **untested**.
* Timing assumes 67,500 T per frame and the blanking/raster model of that emulator.
* Exit to CP/M restores video as MODES.COM does; the PIO setup (joystick port) is not restored.
* Boot-ROM -> CP/M -> REDBACK -> ESC cycle works in the model only (with your bn60.rom).
* Keyboard scan uses the 6545 light-pen method (as the ROM does).
* Phase 2: the boot test (ROM -> CP/M -> loader -> game) was **not re-run** - the ROM is not on the PC
  used. The loader now loads a 4th sprite file into block 17; its file list was checked in the assembled
  `REDBACK.COM`, but the full CP/M load of the new disk has not been run anywhere yet.

## Rebuild
`./build.sh` (needs only Python + numpy + Pillow; `tools/zasm.py` is the assembler). On Windows run
`build_win.cmd`: it runs the same `build.sh` with GitHub Desktop's bundled bash (`tools/win/python3` maps
`python3` to `py`). The C model in `tools/emu` is built on first use: Linux/macOS with gcc into `libmbee.so`,
Windows with TinyCC (`tools/tcc/tcc/tcc.exe -shared -rdynamic`, not in git: unpack
`tcc-0.9.27-win64-bin.zip` from download.savannah.gnu.org/releases/tinycc/ into `tools/tcc`) into `mbee.dll`.
Tests (from `tools/`): `scrolltest.py`, `sprtest.py`, `perf.py`, `combattest.py [outdir] [frames]`,
`dropprof.py [frames]`, `boottest.py <bn60.rom>`.
