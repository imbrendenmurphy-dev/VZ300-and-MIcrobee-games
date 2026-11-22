# CLAUDE.md — VZ-ED (text editor / word processor for the VZ300)

Handover from Claude chat to Claude Code, 20 Nov 2026; 0.2 written in Claude Code the same day; 0.3 (overlays + sheet view) and 0.4 (menu bar) on 21 Nov 2026; 0.5 (PDF export, printing) on 22 Nov 2026; 0.6 (BASIC programs, hex viewer) on 23 Nov 2026.
Read all of this before changing anything.

Credits line for anything user-facing: **VIBED BY BPM 2026** (the user's standing preference — never
"code by Claude" or similar).

The user (BPM) is a retro collector, not a programmer (basic BASIC / Z80 knowledge). They test on their
real VZ300 and report back with photos. Explain results in plain words; keep them in the loop on
anything that writes to their SD card.

---

## 0. Quick facts

| | |
|---|---|
| Version | **0.6** (23 Nov 2026): 0.5 + BASIC `.VZ` programs edited as text and a hex viewer (overlay slots 5 and 6). 0.5 = SAVE AS PDF and PRINT (FILE menu, overlay slots 3 and 4). 0.4 = menu bar (CTRL+I / joystick fire, overlay slot 2). 0.3 = overlays (`VZED.OVL`, help moved there) + sheet view (CTRL+V). Older versions in `release/0.5/` ... `release/0.1/`. |
| Real hardware status | **NO VERSION HAS BEEN TESTED ON A REAL VZ YET** (the user tried 0.2 in VZonPC, which runs the real VZDOS). Everything below marked "verified" was verified in the emulators only. The user asked for 0.2 before reporting on 0.1. |
| Outputs | `out/VZED.VZ` (standalone) and `out/PLAYTXT.VZ` (VZ-DECK plug-in), same code, byte `$A003` = 0 / 1; `out/VZED.OVL` (overlays, root of the card, section 13). |
| Release copies | `release/` (0.6, identical to `out/`), `release/0.5/` ... `release/0.1/`, `dist/VZ-ED-0.6.zip` (`py tools\package.py`) |
| Build | `py src\build.py` (Windows) / `python3 src/build.py`. Python 3 only, no packages. |
| Code size | code `$A000`-`$C5BC`; "tail" (tables, font, all messages, the overlay loader) `$9803`-`$9F21`, stored after the code in the file and copied down at start-up; text buffer `$C600`-`$F5FF` (**12,288 bytes**; 0.2 had 12,032, 0.1 12,544). Room left: 67 bytes of code before `$C600`, 105 bytes of tail before `$A000` (careful: the messages before `tables.inc` must stay below KTAB `$9900`, see 12.6). New features go in overlays (section 13). |
| Handover check | `py src\build.py` must reproduce `release/VZED.VZ` MD5 `bf1be6cb21cbe0f8277ff7e446c81f97`, `release/PLAYTXT.VZ` `7b729e86a27ffa000ca902a36210191c` and `release/VZED.OVL` `80b612c51317326e6d7f235ac489beb7` (older versions are in `release/0.x/`) |
| Sister project | VZ-DECK (`../VZ-Deck`), the user's SD boot shell / file browser / music player. VZ-ED is its text plug-in. |

---

## 1. Purpose and status

The user wanted a "full-featured" general-purpose word processor for the VZ that reads and edits
files on the BennVenn SD card, returns to VZ-DECK, has display options, output options (printer
port / PDF), a "sheet view", and quality-of-life features. They picked the name **VZ-ED** and agreed a
staged plan. **0.1 (the core) and 0.2 (wrap, blocks, find/replace) are done**; the rest is the
roadmap in section 9. 0.2 is described in section 12.

### Done in 0.1 (verified in emulator unless stated)

- Gap-buffer editor: typing, RETURN, delete left/right, insert/overtype, caps lock, cursor keys
  with a remembered goal column, page up/down, top/bottom of file, start/end of line.
- Line number and column on the title bar, `*` when modified, INS/OVR, `^` for caps lock.
- Horizontal scrolling for lines longer than 32 columns.
- **Three display styles, switched live with CTRL+D** (the user specifically asked for this):
  0 = text 32x16 with capitals shown inverse; 1 = text 32x16 with lower case inverse (classic VZ);
  2 = graphics mode 1 (128x64, 4 colours) with a 4x6 font, 32x10, real lower case.
- Blinking block cursor (text mode: blue semigraphic block = insert, red = overtype).
- File list (CTRL+O): folders first then files, sorted, sizes, `..` to go up, folders navigable.
- Load `.TXT` (any file actually) up to 12,544 bytes; CR stripped on load; remembers whether the
  file used CR LF or LF and saves back the same way; new / empty files default to CR LF.
- Save (CTRL+S), Save As (CTRL+A, `NAME` defaults to `.TXT`, asks before replacing), New (CTRL+N),
  Quit (CTRL+Q) — all ask "SAVE CHANGES? Y/N  ^Q=STAY" when modified.
- **Safe save**: temp file, then old file renamed `.BAK`, then temp renamed (section 5.4).
- Settings file `VZED.CFG` in the root (display style, caps, insert mode), written on quit only
  if a setting changed; rewritten in place (one sector) if it already exists.
- Help pages (CTRL+H), adapting to 15 or 9 lines per page.
- Joystick moves the cursor (and up/down/fire in the file list).
- **VZ-DECK integration**: VZ-DECK runs `PLAY<ext>.VZ` from the root for unknown file types, so
  RETURN on a `.TXT` loads `PLAYTXT.VZ` at `$A000` with the file in the hand-over block. Quitting
  reloads `SHELL.VZ` and VZ-DECK comes back in the same folder with the cursor restored.
  `VZED.VZ` quits by restarting (`OUT ($37),0 : JP 0`), which reboots into VZ-DECK at the root.

### Done in 0.2 (verified in the Python emulator; details in section 12)

- Word wrap on screen (CTRL+W, `W` on the title bar); the file keeps one line per paragraph (the user
  chose this over hard wrap). Up/down/page move by screen row; CTRL+Z/X stay start/end of the
  whole line. Saved in `VZED.CFG` (bit 1 of byte 7; 0.1 reads only bit 0, so the file stays compatible).
- Blocks: CTRL+K mark (again = off), CTRL+J copy, CTRL+Y cut, CTRL+P paste, CTRL+: / CTRL+; delete
  the block. Shown inverse (text styles) / blue on yellow (graphics). Typing ends marking.
- Clipboard 10,240 bytes in the spare 10K SRAM bank (`OUT ($37),3`) if a careful start-up test finds
  it; otherwise 3,328 bytes in DIRBUF, emptied by CTRL+O.
- CTRL+F find (either case, wraps to the top), CTRL+G again, CTRL+E replace cursor to end with
  Y/N/A/^Q and "n REPLACED".

### Done in 0.3 (verified in the Python emulator and in vzemu/VZonPC with the real VZDOS; section 13)

- **Overlays**: `VZED.OVL` in the root of the card holds 3K slots loaded to `$8900` on demand. Slot 0 =
  help (moved out of `VZED.VZ`, which freed the room for the loader and gave the buffer 256 bytes back),
  slot 1 = sheet view. A build id stops a `VZED.OVL` from another build running. Missing / short /
  old file: `VZED.OVL MISSING OR OLD`, nothing else changes.
- **Sheet view (CTRL+V)**: mode 1, one pixel per character (letters blue, spaces green), the editor's
  screen as a yellow box (letters red). Wrap off: a line per pixel row, 64 rows x 128 columns; wrap
  on: screen rows, four strips of 64 (256 rows). Cursor keys / R C / T B move the box, RETURN goes
  there (top = that row, cursor at the box's top-left), Q / CTRL+Q / CTRL+V back.
- Help text gained CTRL+V and sheet view lines; versions read 0.3.

### Done in 0.4 (verified in the Python emulator and vzemu; section 13.6)

- **Menu bar** (overlay slot 2): CTRL+I (new key code `K_MENU` = 128) or joystick fire in the editor
  (`K_FIRE` was unused there). FILE EDIT FIND VIEW HELP, items show their CTRL key. Cursor keys (or plain
  M , . SPACE, or the joystick) move, RETURN / fire pick, a letter picks that CTRL key's item from any
  menu, CTRL+Q / CTRL+I close. The chosen item's key code goes to `dispatch`, so a menu item behaves
  exactly like its CTRL key (including starting another overlay). Last menu kept in `menusel`.
- Overlay return protocol extended: NC + A = key code to dispatch (0 = none). Help and sheet view now
  return A = 0 (`xor a`).

### Done in 0.5 (verified in the Python emulator, vzemu and poppler's pdftotext; section 13.7)

- **SAVE AS PDF** (slot 3, key code `K_PDF` = 129) and **PRINT** (slot 4, `K_PRINT` = 130): menu only
  (FILE), no CTRL letter is free. `dispatch`: codes >= 129 -> `ovl_run` slot code-126 (`c_ovl`).
- Shared layout `out_lay.inc`: 80-column lines, break after the last space in 80 (else at 80), a final
  LF makes no empty line; 64 lines a page.

### Done in 0.6 (verified in the Python emulator, and the saved program in the real ROM via vzemu; section 13.8)

- **BASIC programs**: opening a `.VZ` of type `$F0` that fits lists it as text (as the ROM's LIST);
  CTRL+S as `.VZ` tokenises it again exactly as the ROM does (`tools/basic.py`, checked against lines
  typed into the ROM), safe save with `.BAK`. A program opened and saved unchanged is byte-identical.
  Bad line -> NO LINE NO. / LINE ORDER / LONG LINE, cursor on it, nothing written. Caps lock goes on.
- **Hex viewer**: other `.VZ` files, BASIC with code after the program, and files over the buffer size
  open read-only in hex (any size, 24-bit offsets), the old text untouched (except BASIC-with-code, which
  is only found after loading: the editor is then empty and untitled).
- `open_file` (tail) replaces `load_file` in the file list; `bas_save` (tail) hooks `save_doc`.
- **Fixed (bug since 0.1)**: `.` wasn't in `s_namechr`, so the Save As prompt never took an extension.

### Not done (planned): see section 9.

---

## 2. Target hardware and constraints

- Dick Smith **VZ300** (VZ200 compatible), Z80 at 3.54 MHz, MC6847 video, composite colour, 4:3 screen.
- **BennVenn SD loader + 128K**, running **VZDOS 2.31** on the user's card (they also have 2.32).
  VZ-DECK ships a patched VZDOS 2.32 (Ben Grimmett approved redistribution). The emulator tests use
  that patched 2.32 (`tools/VZDOS.VZ`).
- One field = **70,630 T-states** (312 lines, 50 Hz). Field sync = bit 7 of `$6800` low for the
  first ~12,740 T. Writing video RAM has no wait states and no snow (measured on the user's VZ in
  an earlier project, BENCH.VZ).
- The stock VZ has **no reset button** — never design anything that needs one.
- No real-time clock: saved files are dated 20-11-2026 12:00 (`FDATE`/`FTIME` in vzed.asm).

### Memory map used by VZ-ED

| Range | Use |
|---|---|
| `$4000`-`$67FF` | the DOS's view (port `$37` = "home", worked out at start-up, see 12.3). Never write. With `$37` = 3: the spare 10K SRAM bank = clipboard (0.2). |
| `$6800` | latch: write bit 3 = graphics mode, bit 4 = CSS (kept 0); read = keyboard rows + bit 7 field sync |
| `$7000`-`$71FF` / `$77FF` | video RAM (text 512 bytes / mode 1 2048 bytes) |
| `$7600`-`$76xx` | the SHELL.VZ reloader is copied here at exit (plug-in mode only; screen is in text mode then) |
| `$7C00`-`$7FBF` | **VZ-DECK's variables — never touch** (VZ-DECK needs them when it comes back) |
| `$7FC0`-`$7FDF` | VZ-DECK hand-over block `HO` (see 5.6) |
| `$8000`-`$81FF` | `SCR` shadow screen, 16x32 |
| `$8200`-`$83FF` | `OLD` = what is on the display now (must stay exactly `SCR+$200`) |
| `$8400` | `ROWATTR`, 16 bytes (bit 0 document row, bit 1 title bar) — must be page-aligned |
| `$8410`-`$858F` | `CLIST`, up to 128 clusters x 3 bytes for a file being written |
| `$8590`-`$85DA` | `INBUF`, `PNAME`, `CFGBUF`, `NAMEBUF`, `NEWNAME` (moved here in 0.2) |
| `$85DB`-`$85F1` | `fbuf` find text (length + 22), kept; emptied at start-up |
| `$8900`-`$96FF` | **0.3: the overlay area** (`OVLA`; code from the file up to `$94FF`, work RAM after it up to `OVLEND` `$9700`). Shared with the fallback clipboard (parked in the gap while an overlay runs, section 13) and DIRBUF/DPTR (only used by the file list). |
| `$8600`-`$959F` | `DIRBUF`, folder records 20 bytes each, 200 max. **Outside the file list it is 0.2 scratch:** `LIN` `$8600` (wrap layout, 481 bytes), `RING` `$8800`, `WRS` `$8820`, `SRS` `$8850`, `SRP` `$8870`, `FFOLD` `$8880`, scratch variables `$88A0`-`$88D7`, `rbuf` `$88D8` (replace text, emptied by CTRL+O), fallback clipboard `CLIPF` `$8900`-`$95FF` |
| `$95A0`-`$972F` | `DPTR`, sorted pointers to the records (moved in 0.2) |
| `$9730`-`$9801` | variables (`src/vars.inc`, generated by `gen.py`; zeroed at start) |
| `$9802`-`$9F1B` | the "tail": messages, KTAB `$9900`, TTAB `$9A00` + CTAB `$9A80`, FONT, more messages, `strmain.asm`, the overlay loader `ovl.asm`. Copied from the end of the file at start-up (the first thing `start` does). |
| `$A000`-`$C5A0` | code |
| `$C600`-`$F5FF` | text gap buffer (`BUFS` = code end rounded up to a page; `BUFE` = `$F600`) |
| `$F600`-`$F7FF` | stack (`SP` = `$F800`) |
| `$F800`-`$F9FF` | DOS sector buffer `SECBUF` — all card I/O goes through it |
| `$FA00`-`$FFFF` | **the DOS's own RAM — never write**, except `$FB06`-`$FB09` (cache tag) and `$FB80` (read buffer pointer). Confirmed on the user's VZ in earlier projects that scrambling `$FA00`+ hangs the DOS. |

Plug-in constraint: VZ-DECK loads plug-ins at `$9FE8` (24-byte header) so code lands at `$A000`, and
it loads them into `$A000`-`$F7FF`. That is why the code is at `$A000` and the buffer is above it.
The header bytes at `$9FE8` are only needed while loading, so the tail may overwrite them afterwards.

`$7800`-`$7AE8` is BASIC's system-variable area and VZ-DECK relies on it (it writes `$783B` and
launches BASIC programs), so it is **not** free RAM, even though nothing in VZ-ED uses it.

### Keyboard (VZ matrix, bits 0..5 per row; verified layout from the user's earlier reports)

```
row $68FE: T W - E Q R        row $68EF: N . - , SPACE M
row $68FD: G S CTRL D A F     row $68DF: 6 9 - 8 0 7      ('-' key is bit 2)
row $68FB: B X SHIFT C Z V    row $68BF: Y O RET I P U
row $68F7: 5 2 - 3 1 4        row $687F: H L : K ; J
```
bit 0 is the LAST key listed (user confirmed: `$68EF` = M SPACE , - . N as bit5..bit0, listed here
bit0-first). Keys are active low.

### Joystick (user's own interface)
J1 directions on port `$2C` bits 0-3 (up, down, left, right, active low), fire on `$2E` bit 4.
Detection as in VZ-DECK: `$2C AND $0F = $0F` and `$2E` bit 4 high. (The user's joystick 2 has an
intermittent fault; VZ-ED only uses J1.)

### Display facts
- Text mode byte: bit 7 = semigraphics, bit 6 = inverse, bits 0-5 = 6847 code (0-31 = `@A..Z[\]↑←`,
  32-63 = ` !"#..?`). No lower case in the 6847 font — hence the inverse styles.
- Semigraphics 4 cursor block: `$80 | colour<<4 | $0F` (`$AF` blue, `$BF` red).
- Mode 1 (CSS 0) colours: 0 green, 1 yellow, 2 blue, 3 red, 2 bits per pixel, MSB pixel first,
  32 bytes per line, 64 lines.
- CSS 1 (buff/cyan/magenta/orange) is hard to read over composite on the user's screens — avoid it
  for text.

---

## 3. Files and building

```
VZ-Ed/
  CLAUDE.md          this file
  README.md          user manual (keys, safety, limits, specs)
  src/
    vzed.asm         main: start-up, editor loop, gap buffer, rendering, display, keyboard
    edit2.asm        0.2: word wrap, blocks + clipboard (incl. the bank test), find / replace
    files.asm        FAT32 layer: sectors, FAT, folders, allocation, safe save, load, folder list, config
    ui.asm           file list, prompts, open/save/new/quit, exit/reload
    strings.asm      the tail: messages, include tables.inc, more messages (runs below $A000)
    strmain.asm      more messages (0.3: also in the tail now)
    ovl.asm          0.3: the overlay loader (in the tail): ovl_run, clipboard parking
    ovl_help.asm     0.3: overlay slot 0, help pages + help text
    ovl_sheet.asm    0.3: overlay slot 1, the sheet view
    mainsym.inc      GENERATED by build.py from out/vzed.sym (main symbols for the overlays)
    gen.py           generates vars.inc (variable addresses) and tables.inc (KTAB, TTAB+CTAB, FONT)
    build.py         runs gen.py, assembles with tools/zasm.py, writes out/VZED.VZ and out/PLAYTXT.VZ
                     (file = code $A000..code_end, then the tail bytes), then each overlay (own zasm
                     run at OVLA) into out/VZED.OVL, and patches the build id into ovl_id and each slot
    vars.inc, tables.inc   GENERATED — edit gen.py, not these
  tools/
    zasm.py          the assembler (from the user's Galahxy project): local labels, include, align, assert
    z80.py, vz.py    Z80 core and BennVenn SD/SPI model (from VZ-DECK's tools)
    dz.py            disassembler (used to read the VZDOS ROM)
    harness.py       VZ-ED test machine: multi-key keyboard, joystick, FAT32 image builder (optional MBR),
                     FAT32 checker; port $37 bank model: VZ(..., bank=True/False) (0.2)
    shot.py, vzrender.py   PNG screenshots (text and graphics mode)
    t1..t11.py, prof.py     tests (section 10; t9/t10 are 0.2, t11 is 0.3)
    package.py       makes dist/VZ-ED-0.3 and the zip
    VZDOS.VZ, SHELL.VZ      VZ-DECK 1.0 release files (VZSHELL=path runs t3 with another SHELL.VZ), needed by the tests
  out/               build output (VZED.VZ, PLAYTXT.VZ, VZED.OVL, vzed.bin/.sym/.lst, ovl_*.bin/.sym/.lst)
  release/           the 0.3 files (release/0.2/, release/0.1/ = older versions)
  screenshots/       emulator screenshots (0.1, plus 0.2 ones named 2x-*)
  testout/           test scratch output (git-ignored)
```

Build: `py src\build.py` from the project folder (or `cd src` then `py build.py`). It prints the code
range, tail range and buffer size. `assert BUFS+12000 <= BUFE` and `assert tail_end <= $A000` at the
end of vzed.asm guard the sizes. If the tail overflows you get "overlapping output at A000": move a
message out of the tail into the code (see 12.6), or better, move something into an overlay.

`.VZ` header: `VZF0` + 17-byte name ("VZ-ED") + type `$F1` + load address `$A000`.

**zasm quirks:** `jr`/`djnz` out of range is an error with a line number — change that one `jr`
to `jp` (or `djnz` to `dec b : jp nz`). Local labels (`.x`) exist, but this project uses unique
global labels throughout. `include` paths are relative to `src/`.

---

## 4. Editor architecture

### 4.1 Gap buffer
Text = `[BUFS, gs)` + `[ge, BUFE)`. The cursor is at the gap. "Logical offset" = position in the
text ignoring the gap. Rules relied on everywhere:
- `top` (logical offset of the first displayed line) is always **before the gap** (`top` ≤ cursor
  line start ≤ `gs`), so `BUFS+top` is a valid physical pointer. Anything that could break this
  (e.g. backspace at the start of the top line) is fixed by `ensure_vis` before `top` is used as a
  pointer. Keep it that way.
- `curln` (current line, 1-based) is maintained **incrementally**: `gap_left`/`gap_right` count LFs
  they move across; `ins_char`/`del_left` adjust on LF. Never recount the whole file per keystroke.
- `goal` = remembered column for up/down; `$FFFF` = "use the current column". Every horizontal move
  or edit calls `reset_goal`; up/down/page call `setgoal` first.
- `gap_to_start` / `gap_to_end` use **LDDR / LDIR block moves** (plus one `count_lf` CPIR pass for
  `curln` going to the end). Character-by-character moves (`gap_left`/`gap_right`) are for short
  distances only.

### 4.2 Rendering pipeline (shadow screen + diff)
1. `render` builds the whole screen into `SCR` (32 bytes/row, ASCII, **bit 7 = highlight**:
   cursor or selection) — `render_doc` (rows 1..docrows), `build_status` (row 0), then sets bit 7 on
   the cursor cell if the blink phase is on.
2. `flush` compares `SCR` with `OLD` and calls `draw_cell` only for changed cells, then copies.
   `invalidate` fills `OLD` with `$FE` to force a full redraw (after a display style change).
3. `draw_cell` (BC = cell index, A = byte) draws one cell for the current style:
   - text: `TTAB[char]` gives the 6847 code plus flags (bit 6 = capital, bit 7 = lower case);
     inverse when `TTAB & tinvm` (tinvm = `$40` style 0, `$80` style 1) on document rows; title bar
     rows are all inverse; highlighted document cell = coloured block; highlighted title-bar cell =
     plain (a "hole", used as the prompt cursor); other highlighted cells inverse.
   - graphics: glyph = `FONT + (ch-32)*6` (96 glyphs, 95 = solid block for unprintables), one byte
     per glyph row holding a 4-pixel nibble; colour pair p (0 text, 16 title bar, 32
     cursor/selection, 48 overtype cursor) is ORed with the nibble and looked up in the page-aligned
     `CTAB` to give the finished 2bpp byte. `ROWBASE` = start of each 6-line text row.
4. Cursor blink: `frame` toggles bit 7 of the cursor cell every 16 frames and calls `flush`, which
   redraws just that cell. After a key, `blinkon` = 1 so the cursor shows immediately.

### 4.3 Hard-won speed-ups — DO NOT UNDO
Measured in the emulator (`tools/t7.py`, `tools/prof.py`). The original straightforward version took
**264,000 T = 3.7 frames per typed letter**, slower than the 3-frame key repeat. After the changes
below: **1.2 frames (text) / 1.7 frames (graphics) per letter**, cursor down 0.8-1.2, page down 4-5,
end of an 11K file 10-12, top 7-8.

- **Inline fetch loops in `render_doc` with a one-byte boundary test.** The text pointer only needs
  checking against one "boundary" at a time: first `gs` (the gap = the cursor), then `BUFE` (the
  end). The low byte of the boundary sits in register C; each character costs `ld a,l : cp c :
  jr z,...` and only on a match is H compared with `(bnd+1)` (`rd_vb`, `rd_bnd`). Reaching the gap
  both marks the cursor cell and jumps to `ge`. The old per-character `getc` call (two 16-bit
  compares) was 41% of all time — `getc` is still in the source but **no longer called**; don't put
  it back in the hot path.
- **`flush` loop**: `HL = SCR`, `DE = OLD`, `ld a,(de) : cp (hl) : jr nz` with a `djnz` inner loop.
  `ncells` is packed for `ld bc,(ncells)`: **C = number of passes, B = first-pass count (0 = 256)**:
  text = `0*256+2` (2 x 256 = 512 cells), graphics = `64*256+2` (64 then 256 = 320 cells). Getting
  the byte order wrong silently draws the wrong number of cells.
- **`ensure_vis` walks backwards from the cursor line** (at most `docrows-1` lines, using CPDR)
  instead of stepping `top` forward line by line — a jump to the end of a big file used to scroll
  through every line.
- **Diffed drawing**: only changed cells are drawn, which is what makes the graphics mode usable
  (a full graphics redraw is ~130K T).
- KTAB/CTAB/TTAB are page-aligned so lookups are `ld l,a : ld h,TAB/256 : ld a,(hl)`.

### 4.4 Keyboard
`kscan` reads all 8 rows, masks SHIFT/CTRL out of their rows, takes the first pressed key
(B = row*8+bit, C = 1 shift / 2 ctrl), or the joystick (indexes 64-68). `getkey` adds auto-repeat
(`REP1` = 18 frames, `REP2` = 3) and looks up `KTAB[mods*64 + index]` (4 tables: plain, shift,
ctrl, ctrl+shift). Caps lock flips letter case after lookup.

**`waitrel`**: after anything that changes context (start-up, display change, prompts, file list,
help) keys are ignored until everything is released. Without it the RETURN that opened a file
auto-repeats into the document (and the RETURN held from VZ-DECK at start-up). Keep it.

There is **no keyboard buffer** (the VZ has none): keys pressed while the card is busy are lost.
Test scripts must wait after slow operations (`('WAIT', n)` in `harness.type_keys`).

Event codes 1-23 (`K_*` in vzed.asm, same numbers in gen.py) dispatch through `cmdtab`;
32-126 type themselves; 13 = newline.

---

## 5. Card / filesystem layer (files.asm) — read before touching saving

### 5.1 Principle
VZ-ED uses **only two DOS routines**: read sector `$575D` (into `(FB80)`, E:HL = sector) and write
sector `$568C` (writes `$F800`, E:HL = sector). Everything else (FAT chains, folders, allocation,
directory entries) is VZ-ED's own code following the FAT32 rules. All numbers are **24-bit (E:HL)**
because the DOS only addresses sectors below 2^24 (8 GB) anyway. Addresses were found by
disassembling the patched VZDOS 2.32 (`tools/dz.py`).

### 5.2 Why not use the DOS's own save/FAT routines (failed / rejected approach)
The DOS has a BASIC SAVE path (`$42xx`-`$45xx`: free-cluster scan `$441F`, FAT read `$4918`, FAT
write `$4990`, directory search `$4D48`, next cluster `$49F8`). They were studied and **rejected**:
- FAT sectors are addressed as `FA16 + n` where `FA16` = reserved sectors **without the partition
  start**. On an MBR-partitioned card that reads/writes the wrong sectors. (The DOS's data-area
  start `FA0A` *does* include the partition start.) The user's card evidently works with the DOS for
  everything they have done so far, but files that span several clusters on a partitioned card would
  break. VZ-ED adds the partition start (`FB0A`) itself.
- `$4990` updates **only FAT 1**; VZ-ED updates both copies.
- The DOS writes the directory entry **before** the data and forces a 24-byte VZ header and `VZ`
  extension.
- `$4D48` only matches entries whose attribute is exactly `$20` (files) or `$10` (folders).
- The DOS sector cache (`FB06`-`FB09` = last LBA read, regardless of which buffer it went into) can
  make a FAT read return stale buffer contents. **VZ-ED invalidates it (`dos_nocache`) before every
  read and after every write.** Never rely on the DOS cache.

### 5.3 Rules inside VZ-ED's FAT code
- `fs_init` reads the boot sector at the partition start and checks: 512-byte sectors, FAT32
  (`fatsz16 = 0`), power-of-two cluster size, 1-2 FATs, values within 24 bits, and that its computed
  data start equals the DOS's `FA0A..FA0C` exactly. **Any mismatch → `fs_ok = 0` → no loading or
  saving at all** ("CARD FORMAT NOT SUPPORTED"). This refusal is deliberate; keep it.
- `clend` = one past the last valid cluster: from total sectors (capped at the DOS's 2^24-sector
  reach) and also capped by FAT size x 128. Valid clusters: `2 <= c < clend` (`clvalid`).
- Free-space hint from FSInfo next-free if valid, else 2. FSInfo is **never written** (counts go
  stale; harmless — DOS SAVE doesn't update it either).
- `SECBUF` (`$F800`) is shared by everything. One FAT sector may be cached there (`fatcache`,
  `fatdirty`). **Call `fat_sync` (flush + forget) before using `SECBUF` for anything else** — the
  directory walker and loader do. A FAT flush writes FAT 1 and FAT 2.
- `alloc_chain(n)`: scans from the hint, wrapping once, looking at **exactly `clend-2` clusters**,
  records free ones in `CLIST`, and only marks them (chain + EOC) once all n are found. **Bug fixed
  during 0.1:** the budget was `clend`, so on a nearly full card the wrap could find the same free
  cluster twice and build a self-referencing chain (data loss). Do not change the budget back.
- Directory walker `dw_start/dw_next/dw_load`, `dir_find` (skips LFN `$0F`, volume labels, deleted),
  `dir_slot` (first `$E5` or `$00` entry; if the folder is full it allocates a new zeroed cluster and
  links it), `del_entry` (marks `$E5`, writes the sector, **then** frees the chain), `rename_entry`.

### 5.4 Safe save order (`save_doc`) — keep this order
1. Delete any stale `VZEDTEMP.$$$`.
2. `write_new`: count clusters, `alloc_chain` (FAT chain written first), write the data sectors
   (LF → CR LF if `crlf`), **then** create the directory entry (so a crash leaves at worst lost
   clusters, never a directory entry pointing at garbage). If no directory slot can be made, the
   chain is freed again.
3. If the original exists: if it is itself `.BAK`, delete it; otherwise delete any old `NAME.BAK` and
   rename the original to `NAME.BAK`.
4. Rename the temp to the real name.
Card full → "CARD FULL - NOT SAVED", nothing changed (verified). Zero-length text → cluster 0,
size 0 entry (verified).

Known side effects (documented in README): saved names are 8.3 only; if the original had a long
name, its LFN entries are orphaned in front of the renamed `.BAK` (Windows ignores them because the
checksum no longer matches; a PC disk check may tidy them).

### 5.5 Loading
`load_file` (cluster `ldcl`, size `ldsz`): refuses files bigger than the buffer before touching
anything; follows the chain with VZ-ED's own FAT code; strips CR, sets `crlf` if any CR was seen; a
file with no CR but no LF either (or empty) gets `crlf = 1`. Text is loaded at `BUFS` and moved to the
end of the buffer with LDDR so the cursor starts at the top. Broken chain → "FILE ENDED EARLY ON
THE CARD" with the part that was read.

### 5.6 VZ-DECK hand-over (plug-in mode)
`HO` = `$7FC0`: `+0` marker (VZ-DECK sets 0 when launching a plug-in; `$4456` "VD" when coming back),
`+2` joystick on, `+3..6` file cluster, `+7..9` size, `+11..21` name (8+3), `+22..25` SHELL.VZ cluster,
`+26..27` SHELL.VZ size, `+28` temp, `+29..31` player settings.

**`verify_ho`**: running `PLAYTXT.VZ` directly from VZ-DECK (RETURN on the .VZ itself) leaves stale
hand-over data. So the hand-over is trusted only if `HO+0 = 0` and the named file exists in the
current folder (`$FB45`/`$FB47`) with exactly that cluster and size. Otherwise VZ-ED starts with a new
file and quits by restarting. (Found in testing: before this, it showed a garbage name.)

Exit in plug-in mode (`exit` in ui.asm): look up `SHELL   VZ ` in the root with VZ-ED's own code,
write its cluster/size to `HO+22..27`, then copy `rl_src` (the same reloader VZ-DECK's players use:
`D_C2S $480D`, `D_READ $578E`, `D_NEXT $48BF`) to `$7600` and jump there; it sets `HO = $4456`,
loads SHELL.VZ to `$7FE8` and jumps to `$8000`. If SHELL.VZ isn't found: restart instead.

VZ-ED never changes the DOS's current folder (`FB45`/`FB47`); it keeps its own `cwd`, because
VZ-DECK re-reads the DOS's folder when it comes back.

---

## 6. Other engineering decisions (and why)

- **One binary, two names** (`$A003` flag): the user wanted both "open from VZ-DECK" and a standalone
  editor; a separate build would drift.
- **Letters type lower case; SHIFT+letter = capital** — it's a word processor. The VZ's own SHIFT
  symbols on letter keys therefore moved to **CTRL+SHIFT** (L ? K / O [ P ] I { U } M \ N ^ J | H ~
  -_ 7`). These legends are a **best guess** (see 8).
- **Commands are CTRL+letter**; cursor keys are CTRL + M , . SPACE as printed on the VZ; delete left
  = CTRL+: (the VZ's RUBOUT position, assumed), insert = CTRL+L.
- **Default display style 0** (capitals inverse) because prose reads better with normal-looking lower
  case. Graphics style gives true lower case but only 9 text rows.
- **Config written on quit only, and only if changed** — minimises card writes.
- **Interrupts stay disabled** (`DI` after every DOS call — the DOS can enable them). Timing comes
  from polling field sync in `vsync`.
- Stack at `$F600`-`$F7FF`, not in the DOS area. (Considered and rejected for 0.2: shrinking it to
  win buffer space. Real stack use with DOS calls and the ROM interrupt handler isn't measured.)

---

## 7. Failed approaches — do not reintroduce

| Approach | Why it failed |
|---|---|
| Rendering with a `getc` call per character (gap-aware, two 16-bit compares) | 3.7 frames per keystroke; keys lost. Replaced by the boundary-byte loops (4.3). |
| `flush` with a 16-bit counter and `push/pop` compare per cell | ~90 T per cell; replaced by DE/HL + djnz. |
| Scrolling the view forward one line at a time to reach the cursor | 22 frames to jump to the end of an 11K file. Replaced by the backward walk. |
| Allocation scan budget = `clend` | Wraps onto the same free cluster twice on a nearly full card → self-linked chain. Budget = `clend-2`. |
| Trusting the VZ-DECK hand-over without checking | Garbage file name when PLAYTXT.VZ is run directly. |
| Using the DOS's SAVE/FAT/search routines | Partition offset missing, FAT 1 only, wrong write order, attribute filter (5.2). |
| Relying on the DOS sector cache | Stale data after writes / other buffers. Always `dos_nocache`. |
| Calling `curcol` after setting DE in `build_status` | `curcol` clobbers DE (column number vanished from the title bar). Compute first, then set DE. |
| Using a variable name twice (`lcur` for both list cursor and load cluster) | Renamed load cluster to `ldcur`. Variables are all in gen.py's list — check before adding. |
| (0.2) Assuming port `$37` = 1 when VZ-ED starts | In the test harness VZ-ED starts with `$37` = 0 (DOS in flash). A bank test that "restored" 1 switched the DOS away: crash on the first card read. Never write `$37` without going back to `clhome` (12.3). |
| (0.2) Gap-aware row scanner one character at a time for every row | ~89 T per character, walked several times per key: 2.7 frames per letter at the end of a 600-character paragraph. Now CPIR/CPDR when the 32 characters are on one side of the gap (12.1). |
| 0.1 bug, fixed in 0.2: `call z,rd_bnd` followed by `jr c` in `render_doc`'s skip loop | When the call is skipped, the carry from `cp c` reaches the `jr c`: with a line scrolled sideways (`hs` > 0) the screen went blank and the cursor vanished (seen by the user in VZonPC). Now `jr nz` over the call. **0.1 in `release/0.1/` still has this bug.** Lesson: t5 checked only text + cursor, never the screen; t9 `hscroll` now checks every row with wrap off too. |
| (0.2) Using `$7800`-`$7BFF` as free RAM | It's BASIC's / VZ-DECK's area (see the memory map). |

---

## 8. Known issues, limitations, and what is NOT verified

### Not verified on real hardware (everything in this list is an assumption until the user reports)
- **Nothing has run on a real VZ yet** (0.1 or 0.2). The user was asked to back up their card before the first save.
- (0.2) The spare SRAM bank: the port `$37` behaviour comes from MAME's sdloader (via VZonPC), not
  from the user's machine. The start-up test (12.3) is designed so that if the guess is wrong VZ-ED
  just uses the small clipboard; the one test write is put back at once. Which "home" setting the
  real loader leaves (VZonPC says 1, the Python harness 0) is also unverified; the code works it out.
- (0.2) The CTRL key choices (K J Y P F G E W, 0.3's V, 0.4's I) were picked by Claude, not by the user.
- (0.5) Printing: ports from the VZ ROM's LPRINT (`$3AC4`: busy = bit 0 of `IN ($00)`, `OUT ($0E)` data,
  `OUT ($0D)` strobe) and VZonPC/MAME; never tried with a real printer. With no interface the port
  probably reads `$FF` = busy: VZ-ED then says PRINTER NOT READY and CTRL+Q gets out.
- (0.6) BASIC: the tokeniser follows the VZ V2.1 ROM (checked in vzemu, which runs the real ROM);
  programs saved by VZ-ED load, LIST and RUN there. Not yet on the real machine. Load address and name
  come from the file's own header (`bashdr`).
- (0.5) PDFs open in poppler (`pdftotext`, no warnings); not yet tried in Acrobat or on a phone.
- (0.3) Overlays read `VZED.OVL` with the same sector code as file loading; checked in the Python
  emulator and in vzemu/VZonPC (real VZDOS over SPI), not yet on the real card. Colours of the sheet
  view on a real CRT (blue/green and red/yellow) are unchecked.
- Writing sectors through `$568C` on the real BennVenn card (the emulator's SD model accepts CMD24;
  no program has written to the card outside the DOS before).
- The SHIFT and CTRL+SHIFT symbol legends; CTRL+: as rubout. The user was asked to report mismatches.
- Joystick cursor movement on their interface.
- Readability of the 4x6 graphics font on their CRT/LCD. Known weak glyph: lower-case `w` looks like
  `H`. `a`, `S`, `w` were redrawn once already.
- Whether their card is MBR-partitioned or unpartitioned (both work in the emulator).
- That `VZED.VZ`'s restart (`OUT ($37),0 : JP 0`) returns to VZ-DECK — this is the documented VZ-DECK
  way and the "Q quit test" in VZ-DECK's history worked on their machine, so it is likely fine.

### Limitations in 0.2 (by design / not yet built)
- Max file 12,288 bytes (raw size checked before loading). 0.2 took 12,032, 0.1 12,544.
- Help and the sheet view need `VZED.OVL` in the root folder (like `VZED.CFG`), not next to `VZED.VZ`.
- Sheet view shows 64 lines x 128 columns (wrap off) or 256 screen rows (wrap on) at a time and scrolls
  with the box; letters only as dots (no shapes). In wrap mode the box can't move sideways.
- No undo (cut / block delete / replace can't be taken back), no printing, no PDF,
  no menus, no BASIC or hex view, no big-file paging.
- Wrap edge case: a 32-character word (no spaces) right before a line end leaves an empty screen
  row holding just the line end. Matches the model; harmless.
- Replace only runs from the cursor to the end of the file (no wrap-around); find does wrap.
- The fallback clipboard (no spare bank) is emptied by CTRL+O; so is the replace text.
- 8.3 names only; dates fixed; folder list shows at most 200 entries.
- Cards: FAT32 only, sectors below 8 GB only (same as the DOS).

### Code notes
- `getc` (dead since 0.1) was removed in 0.2 to make room.
- Lists use raw `.`/SPACE as well as CTRL versions for up/down; `Q`/`q` also backs out of the list.

---

## 9. Outstanding work and priorities (agreed staged plan)

0. **First: the user's real-hardware report on 0.1 / 0.2**, and fixing what they find (keyboard
   legends, font glyphs, anything about saving, and whether the clipboard holds 10K or 3K, see 12.3).
1. 0.2 and 0.3 are done (sections 12, 13). 0.3 = overlays + sheet view (the user asked for these two;
   the menu bar from the old 0.3 plan is still to do). **Every new feature should be an overlay**
   (section 13.4); the main code has ~95 bytes and the tail ~228 bytes left.
2. 0.4 = the menu bar, 0.5 = PDF + print, 0.6 = BASIC + hex viewer (done). **Next**: big files paged
   from the card, undo, bookmarks, word count. Options not built yet: Epson bold/underline, page size / margins,
   line-ending choice for saving.
3. **0.4**: output — printer port (Centronics, port `$0E` data / strobe; plain text and Epson
   bold/underline), **PDF export** to the card (text-only PDF with built-in Courier/Helvetica: just
   text objects plus an xref table of byte offsets), choice of line endings.
4. **0.5**: other file types — BASIC programs (detokenise a BASIC `.VZ` to text, edit, retokenise on
   save) and a read-only hex/ASCII viewer.
5. **0.6**: big files paged from the card (VZDOS seek reaches into large files; VZ-DECK's MIDI
   streaming is prior art), undo, bookmarks, word count.
6. Later: spell check with a dictionary file on the card.

When adding features: keep the editor hot path (typing → render → flush) under ~2 frames; measure
with `tools/t7.py`, `tools/t10.py` (wrap) and `tools/prof.py` before and after.

---

## 10. Testing

All tests run the **real VZDOS 2.32 ROM** (`tools/VZDOS.VZ`) as the flash ROM on the SPI-level SD
model, booting exactly as the card does (the flash loader finds VZDOS.VZ, which loads SHELL.VZ). Run
from `tools/`: `py t2.py` etc. They read `../out/VZED.VZ` / `PLAYTXT.VZ`, so build first.

| Test | What it covers | Result at handover |
|---|---|---|
| `t1.py` | first boot (VZED as SHELL.VZ) | boots, title bar shown |
| `t2.py` | type, Save As, file list, open, horizontal scroll, edit, save with .BAK, folders, display styles, quit prompt, restart, VZED.CFG | all pass, card clean after every step |
| `t3.py` | **VZ-DECK round trip**: real SHELL.VZ, PLAYTXT.VZ run directly (new file + restart), RETURN on README.TXT, edit, save, quit back to VZ-DECK, same in a subfolder | all pass, VZ-DECK returns to the right folder |
| `t4.py` | MBR card with 32K clusters + 11K multi-cluster file; 512-byte clusters with a fragmented file; full root folder that must be extended | all pass, contents exact, card clean |
| `t4b.py`/`t4c.py` | stale and out-of-range FSInfo hint; file too big; **card full** (1 free cluster, 2 needed) | pass; card full → nothing written, still clean |
| `t5.py <seed>` | 144 random keystrokes (typing, all movement, page, top/bottom, delete, overtype) compared with a Python model of the editor: text, cursor position and line number | 19 seeds passed (7-9, 11-18, 21-25) |
| `t6.py` | screenshots of every style + **write guard** (any write from VZ-ED code into `$FA00`+ except the cache tag/`FB80`, or into `$7800`-`$7FFF` except the reloader) | 0 guard hits |
| `t7.py` | T-states per keystroke for each style (section 4.3 figures) | as listed |
| `t8.py` | LF-only file stays LF-only, empty file gets CR LF, saving an empty new file | pass |
| `prof.py` | per-routine time profile of typing | — |
| `t9.py` (0.2) | **wrap**: 6 seeds x 120 random keys (typing incl. spaces, all moves, page, top/bottom, delete) in all 3 styles against a Python model of the wrap rule: text, cursor, line, *every screen row*, top is a real row start, cursor cell. **Blocks** with and without the spare bank, wrap on/off: copy, paste, cut marked backwards, delete, typing ends marking, CTRL+O keeps/empties the clipboard, a 9,280-byte block, too big for the fallback. **Highlighting** checked cell by cell while moving. **Find / again / not found / replace Y-N-A, with nothing, stop**, save, card clean. **VZED.CFG** wrap bit written and read, 0.1 file compatible. `py t9.py wrap <seed> [style]` = one long random run | all pass (20 Nov 2026); extra seeds 7, 8, 9, 10, 12, 13 x 240 keys (styles 0, 2, 1, 0, 2, 0) all pass |
| `t9.py hscroll` (0.2) | wrap **off**, 3 seeds x 120 random keys on long lines: every screen row and the cursor cell checked, including sideways scrolling (catches the 0.1 blank-screen bug) | pass |
| `t10.py` (0.2) | T-states per key in wrap mode, 600-character paragraphs | see 12.5 |
| (0.6 note) | t4b's "file too big" case now says VZED.OVL MISSING OR OLD: big files go to the hex viewer, and that card has no VZED.OVL |
| `t13.py` (0.6) | **basic**: a program typed into the real ROM opens as its LIST and saves back byte-identical (and its .BAK); edits (lower case keywords, ?, ELSE, ', a new line) save = `basic.py`; reopened lists the same; no number / order / too long -> message, nothing written, cursor on the line; save as .TXT = the listing with CR LF; a 2nd ROM program round-trips; STARBLAS.VZ (code after the program) -> hex view, editor emptied. **hex**: 16K text, 70,000-byte binary (24-bit offsets) and SHELL.VZ in text and graphics styles: every row after down / page down / up / end / page up / top, Q keeps the text; no VZED.OVL -> message | all pass (23 Nov 2026) |
| `t12.py` (0.5) | **pdf**: 7 texts (long lines, brackets and backslashes, empty, no LF, 3000 empty lines, exactly 64 lines, 80/81 columns): header, every xref offset, startxref, trailer, page tree, stream lengths, 64 lines a page, text line by line against a Python model, pdftotext reads it without warnings; asks before replacing (N keeps, Y replaces), UNTITLED.PDF, over 64K refused with the card untouched, the document is a .PDF itself refused, card full -> CARD FULL and a clean card. **print**: bytes = model lines + CR LF + FF, busy -> PRINTER NOT READY, CTRL+Q stops, busy then ready completes, CTRL+Q mid-print with a slow printer. The harness has a printer now (`m.prn`, `m.prn_busy`) | all pass (22 Nov 2026) |
| `t11.py` (0.3/0.4) | **ovl**: help from VZED.OVL (all pages, back in the text), no VZED.OVL / short / other build -> message and nothing else, the other slot still loads, the small clipboard parked across help + sheet view, and emptied with a message when the gap is too small, card unchanged. **sheet**: wrap off/on x 3 styles: video RAM compared byte for byte with a Python model at entry and after 14 random + 7 fixed moves, RETURN lands on the right cursor / top / hs (screen_check), Q leaves the cursor, text and card unchanged; empty / one-line / `a\n` texts. **menu**: SCR cell for cell (bar, cut-out menu, drop-down, text under it) after 16 moves in text and graphics styles, CTRL+Q closes with the screen as before, RETURN / letters (also with caps lock) / joystick fire + down pick items, CTRL+I closes, HELP and V start other overlays, find / mark / copy / paste from the bar. `py t11.py sheet` / `ovl` / `menu` | all pass (21 Nov 2026) |

**Re-run on the PC by Claude Code, 20 Nov 2026** (after moving test scratch output from the chat
sandbox's `/tmp/...` path to `testout/`): build matches both MD5s; t1, t2, t3, t4b, t4c, t6, t8, t5
seeds 7 and 21 pass; t7 timings match the table. **t4.py** passes its first three cases (MBR/32K,
fragmented 512 B, folder extension) but then stops: its last cases are an older copy of the
t4b/t4c cases, still passing `nf=` to `Card()`, which the harness no longer takes, and its "card
nearly full" case doesn't save. Use t4b/t4c for those cases; t4.py still needs tidying.
**0.2 build, same day:** t2, t3, t4 (first three cases), t4b, t4c, t6 (0 guard hits), t8, t5 seeds
7, 11, 21, 25 all pass as before; t7 in 12.5.
**VZ-DECK 1.0 (2026-11-21):** t3 passes with VZ-DECK 1.0's SHELL.VZ (now in tools/; VZDOS.VZ
unchanged): output identical to 0.9 apart from the version line and SHELL.VZ's size, card clean.

`harness.FS(card.sec).check()` verifies a card image: FAT copies identical, every chain valid, cluster
counts match sizes, no cross-links, **no lost clusters**, nothing past the end of the volume.

Test-script gotchas: keys pressed while the editor is busy are lost (as on the real VZ) — add
`('WAIT', n)` after open/save; the file list is sorted folders-first then by name, so count entries
(e.g. `SHELL.VZ` sorts before `T.TXT`; after a save a `.BAK` appears and shifts positions).

**VZonPC (`C:\Users\Owner\Documents\VZonPC\vzemu.exe`), the user's shared emulator:** VZ-ED boots,
types, and all three display styles work there (checked 20 Nov 2026). 0.2 checked there too: wrap,
mark, copy, paste. VZ-ED found home = 1 and chose the *fallback* clipboard, correctly: VZonPC's
stand-in DOS leaves both 10K banks empty, so they look the same. Put `sym out/vzed.sym` in a vzemu
script to `peek` VZ-ED variables by name (plain addresses need a `$`). But VZonPC's DOS is a
high-level stand-in: it doesn't run the real VZDOS ROM and doesn't emulate raw sector reads/writes
(`$575D`/`$568C`), so **file list, load and save can only be tested with the Python suite above**.
Use VZonPC for screen/keyboard checks; extending VZonPC with a sector-level SD model would let it run
everything (see its README, "Not emulated").

The emulator traps any call into the BASIC ROM (`$0000`-`$3FFF`) and stops with "ROM xxxx", except a
few known ones; `JP 0` is treated as a restart. VZ-ED never calls the ROM.

---

## 11. Repository and locations

- GitHub: `https://github.com/imbrendenmurphy-dev/vz300-and-microbee-games` (public), folder
  **`VZ-Ed/`**. Account `imbrendenmurphy-dev`. Copyrighted conversions are kept out of this repo by
  the user's choice; original projects only. The repo `.gitignore` excludes `__pycache__`, ROMs and
  tape images.
- User's PC (Windows), set up by Claude Code on 20 Nov 2026:
  - **Working copy: `C:\Users\Owner\Documents\VZEd_VZ300`** (standalone, VZ-DECK convention). Develop here.
  - Git clone: `C:\Users\Owner\Documents\Codex\vz300-and-microbee-games\VZ-Ed` — copy changed files
    there, then commit and push from that clone. (The other clone at `Documents\GitHub\VZ300 and
    MIcrobee games` has the user's own uncommitted Microbee work in it — don't commit or pull there.)
  - VZ-DECK lives in the repo at `VZ-Deck/` and on the PC at `C:\Users\Owner\Documents\VZDeck_VZ300`.
- Test scratch output (screenshots, `g1.vram`) goes to `testout/` (git-ignored).
- On that PC use `py` (not `python`). Git is the copy bundled with GitHub Desktop:
  `%LOCALAPPDATA%\GitHubDesktop\app-*\resources\app\git\cmd\git.exe`. Commit as BPM.
- After each step: rebuild, run the relevant tests, update `release/`, README and this file, commit
  and push, and copy to the PC folder. The user likes releases as: blurb with tech specs, separate
  screenshots, a zip, and a plain-text blurb for Facebook/YouTube.

---

## 12. 0.2 architecture (edit2.asm) — read before touching wrap, blocks or the clipboard

Positions are **logical** offsets (0 = start of the text, the gap ignored); the cursor is
`c = gs - BUFS`. Helpers: `curpos`, `textlen`, `log2phys` (a position at or after the cursor maps
after the gap), `phys2log`, `ls_of` (line start of a position <= c), `prevls`, `next_line`, and
`gap_to` (move the cursor anywhere with LDIR/LDDR, keeping `curln` right with `count_lf`).

### 12.1 Word wrap (`wrap` = 1)
**The rule** (must be identical in `wrow`, `wlay` and the Python model in t9): a screen row holds at
most 32 positions. From the row start, look at up to 32 characters: a line feed among them ends the
row (the line end is its last position); the end of the text ends the last row; 32 characters with
no line end: break after the last space among them, or straight after the 32nd if there is none.
Rows never look past a line feed, so editing one paragraph never changes the rows of another.

- `wrow` (gap-aware, used for moving around): fast path when the 32 characters are all before the
  gap (limit `gs`) or all after it (limit `BUFE`): **CPIR** for a line feed, then **CPDR** back from
  the 32nd for a space. Otherwise `wrow_s`, one character at a time with the boundary-byte checks.
  Returns HL = next row start, A = 1 if it ended with LF, C = last row (HL = BUFE). Pointer `gs`
  means "the character at `ge`" (`phys2log(gs)` = c).
- `wline` walks a line's rows keeping the last 16 starts in `RING` (`rpush`/`rget`), stopping at the
  row containing `wlim`; `wcur` = the cursor's line, giving `wcrs` (cursor row start), `wnext`, `wlast`.
- `wmv_up`/`wmv_down` (hooked into `mv_up`/`mv_down`): target row + `min(goal, positions-1)`;
  `setgoal` in wrap mode = column on the screen row. `top_up1`/`top_down1` do nothing in wrap mode.
- Drawing (`render_doc` jumps to `render_wrap`): `wvis` keeps `top` a real row start and not below
  the cursor (it re-snaps `top` to a `RING` entry when `top` is in the cursor's line, because editing
  can pull a word back onto an earlier row of the same paragraph); `wlin` copies up to `WIN` = 480
  characters from `top` into `LIN` with two LDIRs (the gap jumped) plus an LF end mark; `wlay` lays
  `LIN` out into `SCR` (fast: no gap), storing each row's start in `WRS`, then finds the cursor
  cell. If the cursor isn't on screen, `wback` sets `top` docrows-1 rows above the cursor's row
  (rows from `RING`, then from the lines above) and it is laid out again. 15 rows x 32 = 480, so the
  window always covers the screen.
- CTRL+W restarts `top` at its line start and sets `hs` = 0.

### 12.2 Blocks
`selon`: 0 none, 1 marking (anchor in `anchor`), 2 a find match shown until the next key
(`dispatch` clears 2 first). `sel_range` = (min, max) of anchor and cursor; the cursor is always at
one end, so the block is contiguous on one side of the gap: copy reads it from `BUFS+s0` or from
`ge` without moving the gap; cut/delete (`blk_rm`) moves the gap to the end of the block and drops
it from `gs` (counting its LFs off `curln`). Paste LDIRs from the clipboard to `gs`.
**Highlighting:** `sel_show` (called by `render` after `render_doc`) sets bit 7 in `SCR` for block
cells, using per-row logical start `SRS` and positions `SRP` from `srows_w` (from `WRS`) or
`srows_nw` (lines from `top`, scrolled by `hs`). `draw_cell` tells the cursor from selected text by
comparing the cell index with `curcell` (`dsel`): selected text = the opposite inverse of normal
(text styles) or colour pair `$C0` = blue on yellow (graphics).

### 12.3 The clipboard bank: safety rules, keep them
Port `$37` (BennVenn, MAME sdloader semantics): bit 0 ROM/RAM at `$4000`-`$67FF`, bit 1 which 10K
RAM bank, bit 2 which 18K bank at `$B800` (**never set bit 2**: VZ-ED's code and text are there).
It can't be read back. `clip_init` (start-up, before any DOS call): copy `$4000`-`$67FF` to the empty
text buffer, find which of 1 / 0 shows *exactly* the same (`ci_cmp`, CPI over all 10K) = `clhome`;
then compare setting 3 with that copy: identical = no spare bank (fallback); otherwise write one
complemented byte at `$4040` with setting 3, check the home view is unchanged (if not: put it back
and use the fallback), restore the bank byte, and check it read back. `clip_on` = `OUT ($37),3` only
if `clipbank`; `clip_off` = `OUT ($37),(clhome)`. No DOS call ever happens between them.

### 12.4 Find / replace
`input_line` (prompt on the title bar, 22 characters, kept for next time), `fold_pat` makes
`FFOLD` lower case, `search` (HL from, DE end, physical, no gap inside): letters compare either case.
Find searches `[ge (+1 for CTRL+G), BUFE)`; if nothing, `gap_to_end` and search the whole text,
putting the cursor back if still nothing. Replace searches from `ge` only (cursor to end). Neither
text can hold a line feed, so `curln` never changes while replacing.

### 12.5 Speed (Python emulator, frames of 70,630 T-states)
| | text style 0 | graphics |
|---|---|---|
| no wrap, type a letter (t7) | ~1.4 (0.1: ~1.2) | 1.80 (0.1: 1.66; the packed font) |
| wrap, type at the start / end of a 600-char paragraph (t10) | 1.50 / 2.09 | 1.44 / 1.75 |
| wrap, cursor up / down inside a paragraph | 2.2-3.5 / 2.2 | 2.8-3.2 / 1.9 |
| wrap, page down / up | 10.7 / 8.8 | 8.2 / 6.4 |
| wrap, end / top of a 9.6K file | 9.5 / 5.3 | 9.8 / 6.3 |

Profile of wrap typing at the end of a long paragraph: `wlay` ~24%, two backward scans to the line
start (`line_start`, one of them from `curcol` for the title bar) ~17%, the row walk ~13%, flush ~16%.
The VZ has no key buffer and the repeat counts loop passes, so slower keys repeat more slowly but
none is lost.

### 12.6 Making room (where the 0.2 bytes came from, and what's left)
Done for 0.2: tables + font + most messages + help text moved to the tail below `$A000`
(`build.py` appends it to the file; `start` copies it first thing), so the code no longer needs
page-alignment padding; **CTAB merged into the upper half of TTAB's page** (colour pair index
`$80`+16p, same speed); **font packed two rows per byte** (288 bytes; `gc_row`); INBUF..NEWNAME and
`fbuf` moved into the gap after `CLIST`; DPTR moved down to right after DIRBUF; scratch variables
moved into DIRBUF; `getc` and 11 unreachable bytes after `jp 0` in `exit` removed; one `clr_title`
shared by three callers.
Ideas for 0.3: move more code (not only data) into the tail and shrink the tail (e.g. shorter help
text); simplify `srows_nw`/`next_line`; ask the user before trading buffer size (each 256 bytes of
code past `$C700` costs 256 bytes of maximum file size).

---

## 13. 0.3 overlays (ovl.asm, ovl_help.asm, ovl_sheet.asm) — read before adding a feature

### 13.1 Why
The main program was full (16 bytes left in 0.2). Of the 128K, VZ-ED uses `$8000`-`$FFFF` of the main
map and the spare 10K bank (clipboard). The second 18K bank at `$B800` (port `$37` bit 2, MAME model,
unverified) is unused, but it hides the code, the text, the stack and the DOS's RAM while switched in,
so it can only ever be a store. The user agreed: overlays from the card.

### 13.2 The file and the loader
`VZED.OVL` (root folder, found like `VZED.CFG`): slot n = sectors 6n..6n+5 (3,072 bytes), loaded to
`OVLA` = `$8900`. Slot bytes 0-1 = the build id, code from `OVLA+2`. `build.py` assembles each overlay
in its own zasm run against `mainsym.inc` (every main symbol as an `equ`), pads it to 3K, and puts the
same id (CRC-32 of the program, low 16 bits, never 0) into `ovl_id` and each slot. `ovl_run` (A = slot,
in the tail): `dir_find` in the root, walk the cluster chain (skip 6n sectors, copy 6), compare the id,
`call OVLA+2`. On return: NC = nothing, C = move the cursor to logical HL (`gap_to` + `reset_goal`;
the overlay may already have set `top` / `hs`). Errors: `VZED.OVL MISSING OR OLD`.

### 13.3 Rules for overlay code
- **Never move the gap** while it runs (the small clipboard may be parked there): read the text with
  `log2phys`, `wrow`, `next_line`, `curpos`, `textlen`; return C + a position to move the cursor.
- RAM: `OVLA`..`OVLEND` (`$9700`): code first, work variables after (as `equ`s past the end of the
  code, so they are not in the file). Don't touch `$8600`-`$88FF` (wrap scratch used by `wrow` etc.).
- `edmode` is 0 while an overlay runs (no cursor blink); `waitrel` = 1 on entry and on return.
- An overlay that changes the screen mode calls `set_display` + `invalidate` before returning.
- Labels: prefix them per overlay (`zh_`, `zs_`): they share one namespace with `mainsym.inc`.
- Adding one: `src/ovl_x.asm` like the others (`include "mainsym.inc"`, `org OVLA`, `dw 0`), add it to
  `OVERLAYS` in `build.py` (its index is the slot), a stub `ld a,slot : jp ovl_run` in the main code,
  and copy the new `VZED.OVL` with the program (the id changes with every build).

### 13.4 Parking the small clipboard
With no spare bank (VZonPC, the Python harness with `bank=False`) the clipboard is `CLIPF` `$8900`,
inside the overlay area. `ov_stash` copies it to the start of the gap if `ge-gs >= cliplen`
(`ovst` = 1), and `ov_unstash` copies it back after the overlay; otherwise `cliplen` = 0 and
`SMALL CLIPBOARD EMPTIED` (`ovst` = 2). With the spare bank nothing is parked.

### 13.5 Sheet view internals
Rows = lines (wrap off, `next_line`) or screen rows (wrap on, `wrow`). One pass at entry fills
`zAT[k]` = start of row 64k (194 entries = 12,289 rows max), the row count `zNR` and the box row `zB`
(the row that equals `top`). `zS0` = first row shown, `zH0` = first column shown (multiple of 4, as
is the box column `zBH`); when the box leaves the sheet it is re-centred (`zs_fix`), and `zRT` (the
starts of rows `zS0`..`zS0`+SH) is rebuilt from `zAT`. A row: the characters (around the gap, `zs_get`)
into `zLB`, packed four to a byte (`cp 33 : ccf : rl c : sla c` = 10 for a letter), the rest of the row
zeroed, then `OR $55` over the box's 8 bytes. Only the rows of the old and new box are redrawn unless
`zS0`/`zH0` change. Video address of row i: `$7000 + (i&63)*32 + (i>>6)*8` (strips in wrap mode).
Speed (vzemu/Python, frames): entry with load 16-24; box move 1.5-3; T/B with a scroll 9-11.

### 13.6 The menu bar (ovl_menu.asm, slot 2)
On entry: SCR is copied to `zBK` (cursor bit cleared), all rows made plain (`set_rows` 0) so the menu
looks the same in every style, `curcell` = `$FFFF`, `invalidate`. Each redraw: `zBK` back into SCR, the
bar (`zm_bar`) over row 0 with the open menu's 6 cells bit 7 (a "hole" in the title bar), the drop-down
(15 cells: space, 13-character item, space) at column `zm_x[menu]`, bit 7 except the chosen item;
then `flush`. Items: `db K_code,"LABEL      ^X"` (the last character is the hotkey letter), generated
in the source from a table; lists `zm_l0`..`zm_l4`, at most 6 items (graphics style has 9 rows). On
leaving: `zBK` back, `invalidate` (render redraws everything with the right row attributes), NC with A
= the item's key code or 0. `ovl_run` then `jp dispatch`es it.

### 13.7 PDF and print (ovl_pdf.asm, ovl_print.asm, out_lay.inc; slots 3 and 4)
**PDF**: objects 1 catalog, 3 font (Courier), per page p 4+2p page / 5+2p contents, 2 the page tree
written last; xref with 20-byte entries, trailer, startxref. The card code needs the length first, so
`zp_pass` runs twice: `zPass` 0 only counts (`zCnt`, 16 bit; wrapping past 64K sets `zOvf` -> PDF TOO
BIG), `zPass` 1 sends every byte through `wputb`. Stream `/Length` is written as 5 digits, so the
counting run (which doesn't know them yet) makes a file of the same size; it stores each page's length
in `zLEN` for the writing run. Offsets go into `zOFF` (both runs). Writing copies `write_new`: clusters
from `outlen`, `alloc_chain`, `wci`/`wsec`/`wpos`, the pass, then `jp wn_z`/`wn_ent` (the end of
`write_new`) with NAMEBUF = `VZEDTEMP.$$$`; then the old NAME.PDF is deleted and the temp renamed
(NEWNAME). Messages after the overlay go through `msgbuf` (11 characters, `zl_msg`) because the overlay
area can be overwritten by the parked clipboard before the editor redraws.
**Print**: per byte wait for bit 0 of `IN ($00)` = 0, then `OUT ($0E)`, `OUT ($0D)`; the byte is kept in
`zBy` (getkey / show_status use BC). Busy for ~16K polls -> PRINTER NOT READY; CTRL+Q checked every 16
polls and between lines.

### 13.8 BASIC and the hex viewer (ovl_vzopen.asm slot 5, ovl_bsave.asm slot 6, basic_kw.inc)
**Rules** (checked by typing lines into the real ROM in vzemu; `tools/basic.py` is the model and its
`py basic.py` re-checks against `tools/basicrom/`: lines typed into the ROM and the program bytes it made): one space after the line number is dropped;
the first keyword in ROM-table order at each place (TOTAL -> TO TAL, FORMAT -> FOR MAT); ? = PRINT;
ELSE gets a ':' in front even after a ':' (1:ELSE -> 1::ELSE); ' = ':' REM $FB; after REM / ' the rest is
kept, after DATA up to ':'; quotes kept. LIST hides one ':' before ELSE / REM'. Table: `gen.py`
`BASIC_KW` -> `basic_kw.inc` (first char | $80, unused = $FF, end $80); index k = token - $80.
**Open** (`open_file` -> slot 5): header from the first sector ("VZF", type at +21 = $F0); the whole file
is read raw to BUFE-size (no CR stripping!), the listing written from BUFS (`zd_wr` refuses to overtake
the read pointer: zOv -> FILE TOO BIG), then moved to the top of the buffer like `load_file`. Name and
load address -> `bashdr`. Bytes after the program's 0 0 -> not editable -> hex view.
**Save** (`bas_save` -> slot 6 when basmode and the name ends .VZ): keyword index built first (`zFirst`
by first character, `zNext` chains in table order, `zEnt` pointers) so each character tries only the
keywords starting with it; lines read around the gap (`zt_get`, never moves it); two runs like the PDF
(count, then `wputb`), then `call sv_3` (save_doc's .BAK + rename). Errors return C + HL = line start.
**Hex**: offsets 24 bit (`zOff`, `zRo`), `zx_byte` keeps the last sector in SECBUF (`zSec`) and walks
the cluster chain from the last cluster it reached (`zCi`/`zCl`), from the start only when going back.
