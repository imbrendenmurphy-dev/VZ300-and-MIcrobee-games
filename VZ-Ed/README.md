# VZ-ED 0.1

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

The cursor is a blinking block: blue in insert mode, red in overtype mode. Lines longer than 32
columns scroll sideways.

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
| CTRL + H | help |
| CTRL + Q | quit (asks to save changes) |
| Joystick | moves the cursor (also up/down/fire in the file list) |

### Typing

* Letters type in **lower case**; **SHIFT + letter** gives a capital (CTRL+U for caps lock).
* SHIFT on the other keys: `1! 2" 3# 4$ 5% 6& 7' 8( 9) 0@  -= ;+ :* ,< .>`
* CTRL + SHIFT for the rest: `L ?  K /  O [  P ]  I {  U }  M \  N ^  J |  H ~  - _  7 ``

If the SHIFT symbols don't match the legends on your keyboard, tell me which and I'll change the
table.

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

## Limits in 0.1

* Files up to 12,544 bytes (larger files will be paged from the card in 0.6).
* No word wrap yet (0.2).
* Text files only (BASIC programs and a hex view come in 0.5).
* Sectors beyond the first 8 GB of a card can't be reached (the same limit as the DOS).

## Tech specs

| | |
|---|---|
| Needs | VZ300 / VZ200, BennVenn SD loader with 128K, VZDOS 2.31 or 2.32 |
| Program | `$A000`-`$C4BF`, 9,408 bytes |
| Text buffer | `$C500`-`$F5FF` (gap buffer) |
| Work RAM | `$8000`-`$9FFF`: screen shadow, folder list (200 entries), variables |
| Untouched | `$7C00`-`$7FFF` (VZ-DECK's variables) and `$FA00`-`$FFFF` (the DOS's RAM) |
| DOS calls | read sector `$575D`, write sector `$568C` (and VZ-DECK's reload routine on exit) |
| Screen | MC6847 text 32x16, or mode 1 128x64 4-colour with a 4x6 font |
| Speed | a keystroke redraws in 1.2 to 1.7 frames; key repeat every 3 frames |

## Building

Needs Python 3 only: `python3 src/build.py` writes `out/VZED.VZ` and `out/PLAYTXT.VZ`.
`tools/` has the assembler, the test emulator (runs the real VZDOS ROM and VZ-DECK; copy `VZDOS.VZ`
and `SHELL.VZ` from the VZ-DECK release into `tools/` first) and the tests:
`t2` editing and saving, `t3` the VZ-DECK round trip, `t4`/`t4b`/`t4c` card stress tests (MBR card,
32K and 512-byte clusters, fragmented files, a full folder, a full card), `t5` random editing checked
against a model, `t6` screenshots, `t7` timing.

## Coming next

* 0.2: word wrap, block copy / move / delete, find and replace
* 0.3: sheet view (a whole page at once), menu bar
* 0.4: printer port, PDF export, line ending choice
* 0.5: BASIC programs (edit a `.VZ` as text), hex viewer
* 0.6: big files paged from the card, undo, bookmarks, word count

## Credits

VZDOS and the SD loader are by Ben Grimmett (BennVenn). VZ-ED uses his DOS's sector routines.
