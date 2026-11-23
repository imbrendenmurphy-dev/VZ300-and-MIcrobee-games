# VZ-ED 0.8

A full-screen text editor for the Dick Smith VZ300 / VZ200 with the BennVenn SD loader and 128K.
It reads and writes text files straight on the SD card and works hand in hand with VZ-DECK.

VIBED BY BPM 2026

## Installing

Copy the three files to the **root** of the SD card:

| File | What it does |
|---|---|
| `VZED.VZ` | Run it from VZ-DECK (or the DOS) to start a new document. Quitting restarts into VZ-DECK. |
| `VZED.OVL` | Help, the sheet view, the menu bar, PDF export, printing, BASIC programs, the hex viewer, bookmarks, go to line, word count, big files and quitting (see "Overlays" below). Without it the editor still works; those say `VZED.OVL MISSING OR OLD` (CTRL+Q then just restarts, without saving the settings). |
| `PLAYTXT.VZ` | VZ-DECK plug-in. Press RETURN on any `.TXT` file in VZ-DECK and it opens in VZ-ED. Quitting goes straight back to VZ-DECK, in the same folder. |

`VZED.VZ` and `PLAYTXT.VZ` are the same program; one byte tells them apart. Always copy all three
from the same release: an old `VZED.OVL` is refused rather than run. **Back up your card before you first save
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

## Menu bar (CTRL+I, or joystick fire)

The title bar becomes **FILE  EDIT  FIND  VIEW  HELP** and a menu drops down over the text, each item
with its CTRL key beside it, so you can learn the keys as you go.

* CTRL+M / CTRL+, (or plain M and ,) go to the next menu left / right; CTRL+. / CTRL+SPACE (or plain
  . and SPACE) move up and down the items. The joystick works too.
* RETURN (or fire) does the item. A letter does the item with that CTRL key straight away, from any
  menu (S saves, W turns word wrap on and off, ...).
* CTRL+Q or CTRL+I closes the menu without doing anything. VZ-ED remembers the last menu you used.

## Undo (CTRL+-)

CTRL+- (CTRL and the minus key) takes back the last change; press it again for the one before, and
so on. EDIT > UNDO does the same. A change is:

* a run of typing (moving the cursor away and typing somewhere else starts a new one),
* a run of CTRL+: (rubout) or CTRL+; (delete), a run of typing in overtype mode,
* a paste, a block deleted or cut, or a whole replace (Y / A, every match it changed).

The cursor goes back to where the change was. Undo remembers the last 1,157 bytes of changes (typed
text costs nothing to remember, deleted text costs what it deleted): older ones are forgotten as new
ones come in, and a single delete bigger than that can't be undone (cut it instead: CTRL+P brings it
back). NEW and OPEN start with an empty history. `NOTHING TO UNDO` when there is nothing left. There
is no redo.

## Big files (over 11K, up to 64K)

A text file too big for the text buffer opens **in parts** of about 6K, each ending at a line end
(`IN 6K PARTS` on the title bar). The rest of the file stays on the card.

* Cursor down or CTRL+C on the last line of a part goes to the next part; cursor up or CTRL+R on the
  first line goes to the part before (`NEXT PART`, `PART BEFORE`). The line number on the title bar
  counts from the start of the whole file.
* If you changed the part, VZ-ED first asks `SAVE CHANGES? Y/N  ^Q=STAY`: Y saves the whole file,
  N forgets the changes in this part, CTRL+Q stays.
* CTRL+S saves the **whole file**: VZ-ED writes it again as `VZEDTEMP.$$$` (the file before the part
  as it is on the card, your part, the file after it), then the old one becomes `NAME.BAK` and the new
  one takes its name, as for any save. So saving a big file takes a few seconds, and the card needs
  room for a second copy. Save As works too (the new file is then the one being edited).
* A part can grow to about 11K while you edit it. The whole file can't go over 65,535 bytes:
  saving then says `FILE TOO BIG FOR VZ-ED` and nothing is written.
* Find, replace, go to line (it takes the line numbers on the title bar), word count, the sheet view,
  PDF and print work on the part you are in. Undo and bookmarks start again in each part. A line
  longer than a part is split between two parts.
* Files over 64K, `.VZ` files and binary files (a 0 byte in the first 512) open in the hex viewer.

## Bookmarks, go to line, word count

* CTRL+0 sets a bookmark at the cursor: VZ-ED asks `BOOKMARK: PRESS 1-9`, and says `MARK n SET`.
* CTRL+1 ... CTRL+9 go to that bookmark (`NO MARK n` if it isn't set). Bookmarks stay on the same
  text while you type and delete before them; one inside a deleted block moves to where the block
  was. They are not saved with the file (NEW and OPEN clear them).
* FIND > GO TO LINE asks for a line number (past the end goes to the last line).
* VIEW > WORD COUNT shows `n WORDS n LINES n CHARS` on the title bar until you press a key; with a
  block marked it counts just the block (`BLOCK n WORDS ...`). A word is anything between spaces or
  line ends.

## BASIC programs (.VZ)

Open a BASIC program saved as a `.VZ` file (CTRL+O) and VZ-ED lists it as text, exactly as the VZ's
own `LIST` shows it, one line per program line:

    10 PRINT "HELLO"
    20 GOTO 10

Edit it like any text: change lines, add lines (each needs its line number, in order), delete lines.
CTRL+S saves it back as a real BASIC program that the VZ loads and runs; the old version is kept as
`NAME.BAK` as usual. VZ-ED turns the keywords back into BASIC's tokens the same way the VZ does when you
type a line (it was checked against the VZ's own ROM), so a program opened and saved unchanged gives
back exactly the same file.

* Caps lock goes on when a BASIC program is opened, so you type capitals as on the VZ (CTRL+U turns it
  off). Keywords are found in capitals or lower case either way.
* If a line has no line number, or the numbers don't go up, or a line is too long, saving stops with
  `NO LINE NO.`, `LINE ORDER` or `LONG LINE` and the cursor goes to that line. Nothing is written.
* Save As with a `.TXT` name saves the listing as plain text instead.
* A `.VZ` with machine code after the BASIC program (loaders often have this) can't be edited safely:
  it opens in the hex viewer.

## Hex viewer

`.VZ` machine code programs, and any file too big for VZ-ED (over 12,288 bytes), open in a read-only
hex viewer: 8 bytes a row as hex and as characters, read straight from the card, so any size works.
Cursor keys move a row, CTRL+R / C a screen, CTRL+T / B the start / end; Q, CTRL+Q or RETURN go back
to your text, which is left as it was.

## Save as PDF and Print (FILE menu)

Both lay the text out the same way: lines of up to 80 characters, a long line broken after its last
space (or at 80 if there is none), 64 lines a page.

* **SAVE AS PDF** writes `NAME.PDF` next to the document (`UNTITLED.PDF` for a new one): Courier 10 pt
  on A4, readable by any PDF reader on a PC or phone. If the PDF is already there it asks first. It is
  written with the same care as saving (a temporary file, then renamed), so a full card or a power cut
  leaves the old PDF as it was. The largest PDF is 64K (about 12K of ordinary text; a file of only
  empty lines can be too big: `PDF TOO BIG`).
* **PRINT** sends the lines to a printer on the VZ printer interface (the one BASIC's `LPRINT` uses),
  each ending with CR LF, and a form feed at the end. CTRL+Q stops it. If the printer is off or not
  there it says `PRINTER NOT READY` and waits (CTRL+Q stops). In VZonPC the printout goes to
  `printer\printout.txt`.

These two have no CTRL key (every letter is taken): use the menu (CTRL+I, FILE).

## Sheet view (CTRL+V)

A whole page at once, one dot for each character: blue for a letter, green for a space. The yellow
box is the part the editor shows. Move it with the cursor keys, CTRL+R / C (a screen at a time) and
CTRL+T / B (top / end), then press RETURN to go there. Q, CTRL+Q or CTRL+V go back without moving.

* Word wrap off: one dot row per line, 64 lines and the first 128 columns (the sheet scrolls when the
  box goes past an edge).
* Word wrap on: one dot row per screen row, in four strips of 64 rows side by side (256 rows, about 7K
  of text).

## Overlays

Help, the sheet view, the menu bar, PDF export, printing, BASIC, the hex viewer, bookmarks, go to line, word
count, big files and quitting live in `VZED.OVL`, not in `VZED.VZ`: they are loaded from the card only when
you use them (the sheet view is up in under half a second), so the editor keeps its room for text. Later features will be added the same way. `VZED.OVL` is only read, never
written. On a machine without the spare 10K SRAM bank, the small clipboard is parked in the free part
of the text buffer while an overlay runs; if the file leaves no room for it, it is emptied and VZ-ED
says `SMALL CLIPBOARD EMPTIED`.

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
| CTRL + V | sheet view (needs `VZED.OVL`) |
| CTRL + I | menu bar (needs `VZED.OVL`); joystick fire opens it too |
| CTRL + K | mark a block (press again to stop marking) |
| CTRL + J | copy the block |
| CTRL + Y | cut the block |
| CTRL + P | paste |
| CTRL + F | find |
| CTRL + G | find again |
| CTRL + E | replace (from the cursor to the end) |
| CTRL + - | undo (again: the change before) |
| CTRL + 0 | set a bookmark (then 1-9) |
| CTRL + 1 ... 9 | go to that bookmark |
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

## Limits in 0.8

* Text files up to 11,264 bytes are edited whole (0.7 gave 1K of the text buffer to the undo history;
  0.3-0.6: 12,288); text files up to 65,535 bytes in parts (see "Big files"); anything bigger only in
  the hex viewer.
* Fixed in 0.2: in 0.1 the screen went blank when a long line scrolled sideways.
* Fixed in 0.6: the Save As prompt didn't take a `.`, so you couldn't give a file your own extension.
* Undo remembers about 1.1K of changes, and no redo.
* Sectors beyond the first 8 GB of a card can't be reached (the same limit as the DOS).

## Tech specs

| | |
|---|---|
| Needs | VZ300 / VZ200, BennVenn SD loader with 128K, VZDOS 2.31 or 2.32 |
| Program | `$A000`-`$C5F4`, plus tables, font, messages and the overlay loader copied at start-up to `$984F`-`$9FF0`; the start-up code runs once from the empty text buffer (`$F200`) |
| Undo history | `$C5F5`-`$C9FF` (1,035 bytes) |
| Text buffer | `$CA00`-`$F5FF` (11,264 bytes, gap buffer) |
| Overlays | `VZED.OVL`: 3K slots (0 help, 1 sheet view, 2 menu bar, 3 PDF, 4 print, 5 open .VZ / hex view, 6 save BASIC, 7 bookmarks / go to line / word count, 8 quit, 9 big files in parts) loaded to `$8900` |
| Printer | VZ printer interface: busy = bit 0 of `IN ($00)`, data `OUT ($0E)`, strobe `OUT ($0D)` (as the ROM) |
| Work RAM | `$8000`-`$9FFF`: screen shadow, folder list (200 entries), variables |
| Clipboard | spare 10K SRAM bank at `$4000`-`$67FF` (`OUT ($37),3`), or 3,328 bytes at `$8900` |
| Untouched | `$7800`-`$7FFF` (BASIC's and VZ-DECK's variables) and `$FA00`-`$FFFF` (the DOS's RAM) |
| DOS calls | read sector `$575D`, write sector `$568C` (and VZ-DECK's reload routine on exit) |
| Screen | MC6847 text 32x16, or mode 1 128x64 4-colour with a 4x6 font |
| Speed | a keystroke redraws in 1.2 to 1.7 frames (word wrap: 1.4 to 2.1); key repeat every 3 frames |

## Building

Needs Python 3 only: `python3 src/build.py` writes `out/VZED.VZ`, `out/PLAYTXT.VZ` and `out/VZED.OVL`.
`tools/` has the assembler, the test emulator (runs the real VZDOS ROM and VZ-DECK; copy `VZDOS.VZ`
and `SHELL.VZ` from the VZ-DECK release into `tools/` first) and the tests:
`t2` editing and saving, `t3` the VZ-DECK round trip, `t4`/`t4b`/`t4c` card stress tests (MBR card,
32K and 512-byte clusters, fragmented files, a full folder, a full card), `t5` random editing checked
against a model, `t6` screenshots, `t7` timing, `t9` the 0.2 features (word wrap checked against a
model, blocks, find / replace), `t10` word wrap timing, `t11` overlays, the sheet view (checked
dot for dot against a model) and the menu bar, `t12` PDF export (checked as a PDF and line by line)
and printing, `t13` BASIC programs (against lines typed into the real ROM) and the hex viewer, `t14` undo (random edits undone all the way back), bookmarks, go to line, word count, `t15` big files in parts (every part, saves checked against
the file edited in Python).
`tools/basic.py` is a Python model of the ROM's tokeniser and LIST.

## Coming next

* Ideas (not planned yet): find across all the parts of a big file, Epson bold / underline when
  printing, page size and margins, a choice of line endings when saving, spell check

## Credits

VZDOS and the SD loader are by Ben Grimmett (BennVenn). VZ-ED uses the DOS's sector routines.
