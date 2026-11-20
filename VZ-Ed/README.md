# VZ-ED 0.2

A full-screen text editor for the Dick Smith VZ300 / VZ200 with the BennVenn SD loader and 128K.
It reads and writes text files straight on the SD card and works hand in hand with VZ-DECK.

VIBED BY BPM 2026

## Installing

Copy both files to the **root** of the SD card:

| File | What it does |
|---|---|
| `VZED.VZ` | Run it from VZ-DECK (or the DOS) to start a new document. Quitting restarts into VZ-DECK. |
| `PLAYTXT.VZ` | VZ-DECK plug-in. Press RETURN on any `.TXT` file in VZ-DECK and it opens in VZ-ED. Quitting goes straight back to VZ-DECK, in the same folder. |

They are the same program; one byte tells them apart. **Back up your card before you first save
with it on real hardware.**

## Display styles (CTRL+D)

| Style | Screen | Notes |
|---|---|---|
| Text, capitals inverse | 32 x 16 | Lower case reads normally; capitals show inverse. Best for prose. |
| Text, lower case inverse | 32 x 16 | The classic VZ way. |
| Graphics | 32 x 10 | 128x64 four-colour mode with a 4x6 font: real lower case, blue on green, red title bar. |

The style you choose is remembered in `VZED.CFG` in the root folder (written only when you quit
after changing a setting).

The cursor is a blinking block: blue in insert mode, red in overtype mode.

## Word wrap (CTRL+W)

With word wrap on (a `W` at the right of the title bar), long lines are shown folded onto the next
screen rows at a space, the way a word processor does. **The file is not changed**: each paragraph is
still one line in the file, so it looks normal on a PC, and editing a paragraph re-folds it as you
type. A word longer than the screen is split at 32 characters.

* Cursor up / down and page up / down move by screen row.
* CTRL+Z / X still go to the start / end of the whole line (the paragraph).
* The `L` and `C` on the title bar count lines and columns in the file, not on the screen.

With word wrap off, lines longer than 32 columns scroll sideways as before. Word wrap is remembered
in `VZED.CFG` with the display style.

## Keys

All commands are CTRL + a key. CTRL+H shows these on screen.

| Key | Action |
|---|---|
| CTRL + M  ,  .  SPACE | cursor left, right, up, down (the VZ arrow keys) |
| CTRL + R / C | page up / page down |
| CTRL + T / B | top / end of file |
| CTRL + Z / X | start / end of line |
| CTRL + : | delete left (rubout) |
| CTRL + ; | delete right |
| CTRL + L | insert / overtype |
| CTRL + U | caps lock |
| CTRL + O | open a file (folders work; `..` goes up) |
| CTRL + S | save |
| CTRL + A | save as (type `NAME` or `NAME.EXT`; no extension means `.TXT`) |
| CTRL + N | new file |
| CTRL + D | display style |
| CTRL + W | word wrap on / off |
| CTRL + K | mark a block (press again to stop marking) |
| CTRL + J | copy the block |
| CTRL + Y | cut the block |
| CTRL + P | paste |
| CTRL + F | find |
| CTRL + G | find again |
| CTRL + E | replace (from the cursor to the end) |
| CTRL + H | help |
| CTRL + Q | quit (asks to save changes) |
| Joystick | moves the cursor (also up/down/fire in the file list) |

### Typing

* Letters type in **lower case**; **SHIFT + letter** gives a capital (CTRL+U for caps lock).
* SHIFT on the other keys: `1! 2" 3# 4$ 5% 6& 7' 8( 9) 0@  -= ;+ :* ,< .>`
* CTRL + SHIFT for the rest: `L ?  K /  O [  P ]  I {  U }  M \  N ^  J |  H ~  - _  7 ``

If the SHIFT symbols don't match the legends on your keyboard, tell me which and I'll change the
table.

### Blocks

Press CTRL+K, then move the cursor: the block shows highlighted (inverse in the text styles,
blue on yellow in graphics) and the title bar says `BLOCK`. Then:

* CTRL+J copies it, CTRL+Y cuts it, CTRL+P pastes at the cursor (as often as you like).
  Moving text = cut, move the cursor, paste.
* CTRL+: or CTRL+; deletes the block (without copying it).
* Typing anything ends marking and leaves the text as it was.

The clipboard holds up to **10,240 characters** in the spare 10K memory bank of the BennVenn
card, and keeps them when you open another file. If that bank can't be found (VZ-ED checks it
carefully at start-up without touching the DOS), it holds up to **3,328 characters** in normal
memory instead, and is emptied when the file list is opened.

### Find and replace

* CTRL+F asks `FIND:` (up to 22 characters, the last one is offered again). Capitals and lower case
  match each other. The match is shown highlighted with the cursor on it; if there is none after
  the cursor, the search carries on from the top of the file. `NOT FOUND` leaves the cursor where it was.
* CTRL+G finds the next one.
* CTRL+E asks `FIND:` and `REPLACE:` (which may be empty, to delete), then stops at each match from
  the cursor to the end of the file: **Y** replace, **N** skip, **A** replace all the rest,
  **CTRL+Q** stop. It then says how many it replaced.

In the file list: CTRL+. / CTRL+SPACE (or plain `.` / SPACE) move, CTRL+R / C page, RETURN opens,
CTRL+Q or Q goes back.

## Saving, and keeping the card safe

Saving never overwrites your file in place:

1. The text is written to a new file, `VZEDTEMP.$$$`.
2. Only when that is complete, the old file is renamed `NAME.BAK` (an older `.BAK` is removed).
3. The new file is renamed to `NAME.EXT`.

If the power goes or the VZ crashes during a save, you still have either the old file or the new
one (possibly as `.BAK` or `.$$$`). Clusters are always linked before data is written and the folder
entry comes last, so the worst a crash can leave is some unused space that a PC's disk check
tidies up.

Other details:

* Both copies of the FAT are updated (the DOS's own SAVE only updates the first).
* Line endings are kept: a file with CR LF is saved with CR LF, a file with LF only stays LF only.
  New files use CR LF, so they open cleanly on a PC.
* Files are saved with 8.3 names. A file that had a long name on the PC is shown by its short name
  afterwards.
* The VZ has no clock, so saved files are dated 20-11-2026.
* On a full card, the save stops with `CARD FULL - NOT SAVED` and nothing on the card changes.
* VZ-ED does its own FAT32 work and only uses the DOS to read and write sectors. It checks the card's
  layout against the DOS first and refuses to save (`CARD FORMAT NOT SUPPORTED`) if anything doesn't
  match, rather than guess.

## Limits in 0.2

* Files up to 12,032 bytes (larger files will be paged from the card in 0.6). This is 512 bytes less
  than 0.1 because of the new features.
* No undo yet: cut, delete and replace can't be taken back (save often; the `.BAK` keeps the last
  saved version).
* Text files only (BASIC programs and a hex view come in 0.5).
* Sectors beyond the first 8 GB of a card can't be reached (the same limit as the DOS).

## Tech specs

| | |
|---|---|
| Needs | VZ300 / VZ200, BennVenn SD loader with 128K, VZDOS 2.31 or 2.32 |
| Program | `$A000`-`$C6ED` (9,966 bytes), plus tables, font and messages copied at start-up to `$97FE`-`$9FFB` |
| Text buffer | `$C700`-`$F5FF` (12,032 bytes, gap buffer) |
| Work RAM | `$8000`-`$9FFF`: screen shadow, folder list (200 entries), variables |
| Clipboard | spare 10K SRAM bank at `$4000`-`$67FF` (`OUT ($37),3`), or 3,328 bytes at `$8900` |
| Untouched | `$7800`-`$7FFF` (BASIC's and VZ-DECK's variables) and `$FA00`-`$FFFF` (the DOS's RAM) |
| DOS calls | read sector `$575D`, write sector `$568C` (and VZ-DECK's reload routine on exit) |
| Screen | MC6847 text 32x16, or mode 1 128x64 4-colour with a 4x6 font |
| Speed | a keystroke redraws in 1.2 to 1.7 frames (word wrap: 1.4 to 2.1); key repeat every 3 frames |

## Building

Needs Python 3 only: `python3 src/build.py` writes `out/VZED.VZ` and `out/PLAYTXT.VZ`.
`tools/` has the assembler, the test emulator (runs the real VZDOS ROM and VZ-DECK; copy `VZDOS.VZ`
and `SHELL.VZ` from the VZ-DECK release into `tools/` first) and the tests:
`t2` editing and saving, `t3` the VZ-DECK round trip, `t4`/`t4b`/`t4c` card stress tests (MBR card,
32K and 512-byte clusters, fragmented files, a full folder, a full card), `t5` random editing checked
against a model, `t6` screenshots, `t7` timing, `t9` the 0.2 features (word wrap checked against a
model, blocks, find / replace), `t10` word wrap timing.

## Coming next

* 0.3: sheet view (a whole page at once), menu bar
* 0.4: printer port, PDF export, line ending choice
* 0.5: BASIC programs (edit a `.VZ` as text), hex viewer
* 0.6: big files paged from the card, undo, bookmarks, word count

## Credits

VZDOS and the SD loader are by Ben Grimmett (BennVenn). VZ-ED uses his DOS's sector routines.
