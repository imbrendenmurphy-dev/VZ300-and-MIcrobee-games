# REDBACK - Phase 1 technical notes
VIBED BY BPM 2026 - Microbee Premium Plus, Z80 only, 40-column PAL, PCG-bitmap scrolling

## Status
Phase 1 (technical demo) is built and tested **in my own Z80 / Premium Plus C model only**.
Nothing has been run in uBee512 or on real hardware. See "Unverified" below.

Run: boot `REDBACK.DS8` (comes up at the CP/M prompt, no auto-launch), type `REDBACK`.
Keys: Q/A/O/P or cursor keys or joystick (PIO A); ESC returns to CP/M.

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
Program 8000h (4,352 bytes); SHC (screen shadow) C000, RES C800, PCOL C900, Y10 CA00, YM CB00,
commit lists D800-DCFF, load queue E700, HUD codes E800, vars E900, stack EFF0.
Blocks: 8 PAIRS (pair records + sprite index), 12 DECK, 13-15 SPR0-2, 16 saved CP/M video state.

## Loader / disk
`REDBACK.COM` (CP/M): finds CP/M's own RAM block by signature scan, checks 1MB RAM, saves CP/M's
screen/attribute/colour/font banks 0-1 to block 16, loads the `.BNK` files straight to their blocks,
stages the program in block 27, then a final stage at F000h copies it to 8000h and jumps.
On ESC the game restores the 80-column CRTC table, the saved video state and CP/M's lower block,
then `JP 0` (same method as MODES.COM). `REDBACK.DS8`: 80 tracks x 2 sides x 10 x 512, system tracks
from your Microbee boot disk, `CCP.SYS`, no `SHELL.SYS`, nothing auto-launches.

## Measured (model, see TEST_RESULTS.txt)
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

## Rebuild
`./build.sh` (needs only Python + numpy + Pillow; `tools/zasm.py` is the assembler; the C model in
`tools/emu` is built with gcc into `libmbee.so`; the .so shipped is a Linux build). Tests: `tools/scrolltest.py`, `sprtest.py`, `perf.py`, `boottest.py <bn60.rom>`.
