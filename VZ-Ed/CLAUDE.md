# CLAUDE.md — VZ-ED (text editor / word processor for the VZ300)

Handover from Claude chat to Claude Code, 20 Nov 2026. Read all of this before changing anything.

Credits line for anything user-facing: **VIBED BY BPM 2026** (the user's standing preference — never
"code by Claude" or similar).

The user (BPM) is a retro collector, not a programmer (basic BASIC / Z80 knowledge). He tests on his
real VZ300 and reports back with photos. Explain results in plain words; keep him in the loop on
anything that writes to his SD card.

---

## 0. Quick facts

| | |
|---|---|
| Version | **0.1** (first build, released 20 Nov 2026) |
| Real hardware status | **NOT YET TESTED ON A REAL VZ.** Everything below marked "verified" was verified in the emulator only. |
| Outputs | `out/VZED.VZ` (standalone) and `out/PLAYTXT.VZ` (VZ-DECK plug-in). Same code; byte `$A003` = 0 / 1. |
| Release copies | `release/` (identical to `out/` at handover) and `dist/VZ-ED-0.1.zip` |
| Build | `py src\build.py` (Windows) / `python3 src/build.py`. Python 3 only, no packages. |
| Code size | `$A000`-`$C4BF` (9,408 bytes); text buffer `$C500`-`$F5FF` (12,544 bytes) |
| Handover check | `py src\build.py` must reproduce `release/VZED.VZ` MD5 `b245d89f2b2a311b3940654a2f884b93` and `release/PLAYTXT.VZ` MD5 `f17ac5c142eac6e91eaddfb49afff4c0` |
| Sister project | VZ-DECK (`../VZ-Deck`), the user's SD boot shell / file browser / music player. VZ-ED is its text plug-in. |

---

## 1. Purpose and status

The user wanted a "full-featured" general-purpose word processor for the VZ that reads and edits
files on the BennVenn SD card, returns to VZ-DECK, has display options, output options (printer
port / PDF), a "sheet view", and quality-of-life features. He picked the name **VZ-ED** and agreed a
staged plan. **0.1 (the core) is done**; the rest is the roadmap in section 9.

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

### Not done (planned): see section 9.

---

## 2. Target hardware and constraints

- Dick Smith **VZ300** (VZ200 compatible), Z80 at 3.54 MHz, MC6847 video, composite colour, 4:3 screen.
- **BennVenn SD loader + 128K**, running **VZDOS 2.31** on the user's card (he also has 2.32).
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
| `$4000`-`$5FFF` | VZDOS in card SRAM (mapper `$37` = 1). Never write. |
| `$6800` | latch: write bit 3 = graphics mode, bit 4 = CSS (kept 0); read = keyboard rows + bit 7 field sync |
| `$7000`-`$71FF` / `$77FF` | video RAM (text 512 bytes / mode 1 2048 bytes) |
| `$7600`-`$76xx` | the SHELL.VZ reloader is copied here at exit (plug-in mode only; screen is in text mode then) |
| `$7C00`-`$7FBF` | **VZ-DECK's variables — never touch** (VZ-DECK needs them when it comes back) |
| `$7FC0`-`$7FDF` | VZ-DECK hand-over block `HO` (see 5.6) |
| `$8000`-`$81FF` | `SCR` shadow screen, 16x32 |
| `$8200`-`$83FF` | `OLD` = what is on the display now (must stay exactly `SCR+$200`) |
| `$8400` | `ROWATTR`, 16 bytes (bit 0 document row, bit 1 title bar) — must be page-aligned |
| `$8410` | `CLIST`, up to 128 clusters x 3 bytes for a file being written |
| `$8600` | `DIRBUF`, folder records 20 bytes each, 200 max |
| `$9600` | `DPTR`, sorted pointers to the records |
| `$97A0`-`$97EF` | `INBUF`, `PNAME`, `CFGBUF`, `NAMEBUF`, `NEWNAME` |
| `$9800`-... | variables (`src/vars.inc`, generated by `gen.py`; zeroed at start) |
| `$A000`-`$C4BF` | code + tables (KTAB, CTAB, TTAB page-aligned) |
| `$C500`-`$F5FF` | text gap buffer (`BUFS` = code end rounded up to a page; `BUFE` = `$F600`) |
| `$F600`-`$F7FF` | stack (`SP` = `$F800`) |
| `$F800`-`$F9FF` | DOS sector buffer `SECBUF` — all card I/O goes through it |
| `$FA00`-`$FFFF` | **the DOS's own RAM — never write**, except `$FB06`-`$FB09` (cache tag) and `$FB80` (read buffer pointer). Confirmed on the user's VZ in earlier projects that scrambling `$FA00`+ hangs the DOS. |

Plug-in constraint: VZ-DECK loads plug-ins at `$9FE8` (24-byte header) so code lands at `$A000`, and
it loads them into `$A000`-`$F7FF`. That is why the code is at `$A000` and the buffer is above it.

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
    files.asm        FAT32 layer: sectors, FAT, folders, allocation, safe save, load, folder list, config
    ui.asm           file list, prompts, help, open/save/new/quit, exit/reload, all strings + help text
    gen.py           generates vars.inc (variable addresses) and tables.inc (KTAB, CTAB, TTAB, FONT)
    build.py         runs gen.py, assembles with tools/zasm.py, writes out/VZED.VZ and out/PLAYTXT.VZ
    vars.inc, tables.inc   GENERATED — edit gen.py, not these
  tools/
    zasm.py          the assembler (from the user's Galahxy project): local labels, include, align, assert
    z80.py, vz.py    Z80 core and BennVenn SD/SPI model (from VZ-DECK's tools)
    dz.py            disassembler (used to read the VZDOS ROM)
    harness.py       VZ-ED test machine: multi-key keyboard, joystick, FAT32 image builder (optional MBR),
                     FAT32 checker
    shot.py, vzrender.py   PNG screenshots (text and graphics mode)
    t1..t8.py, prof.py      tests (section 10)
    package.py       makes dist/VZ-ED-0.1 and the zip
    VZDOS.VZ, SHELL.VZ      VZ-DECK 0.9 release files, needed by the tests
  out/               build output (VZED.VZ, PLAYTXT.VZ, vzed.bin/.sym/.lst)
  release/           the released 0.1 files
  screenshots/       emulator screenshots of 0.1
```

Build: `py src\build.py` from the project folder (or `cd src` then `py build.py`). It prints the code
range and buffer size. `assert BUFS+12000 <= BUFE` at the end of vzed.asm guards the buffer size.

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
  everything he has done so far, but files that span several clusters on a partitioned card would
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
- Stack at `$F600`-`$F7FF`, not in the DOS area.

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

---

## 8. Known issues, limitations, and what is NOT verified

### Not verified on real hardware (everything in this list is an assumption until the user reports)
- **Nothing has run on a real VZ yet.** The user was asked to back up his card before the first save.
- Writing sectors through `$568C` on the real BennVenn card (the emulator's SD model accepts CMD24;
  no program has written to the card outside the DOS before).
- The SHIFT and CTRL+SHIFT symbol legends; CTRL+: as rubout. The user was asked to report mismatches.
- Joystick cursor movement on his interface.
- Readability of the 4x6 graphics font on his CRT/LCD. Known weak glyph: lower-case `w` looks like
  `H`. `a`, `S`, `w` were redrawn once already.
- Whether his card is MBR-partitioned or unpartitioned (both work in the emulator).
- That `VZED.VZ`'s restart (`OUT ($37),0 : JP 0`) returns to VZ-DECK — this is the documented VZ-DECK
  way and the "Q quit test" in VZ-DECK's history worked on his machine, so it is likely fine.

### Limitations in 0.1 (by design / not yet built)
- Max file 12,544 bytes (raw size checked before loading).
- No word wrap, no blocks, no find/replace, no undo, no printing, no PDF, no sheet view, no menus,
  no BASIC or hex view, no big-file paging.
- 8.3 names only; dates fixed; folder list shows at most 200 entries.
- Cards: FAT32 only, sectors below 8 GB only (same as the DOS).

### Code notes
- `getc` and `peek_r` remain; `getc` is now dead code (kept to avoid unnecessary changes).
- Lists use raw `.`/SPACE as well as CTRL versions for up/down; `Q`/`q` also backs out of the list.

---

## 9. Outstanding work and priorities (agreed staged plan)

0. **First: wait for the user's real-hardware report on 0.1** and fix what he finds (keyboard
   legends, font glyphs, anything about saving). Don't start 0.2 features before that unless he says so.
1. **0.2**: word wrap (display wrap and/or hard wrap — ask him), block mark/copy/move/delete (the
   10K free SRAM bank 3 at `$4000`-`$67FF` via mapper `$37`=3 could hold a clipboard, but the DOS needs
   `$37`=1 for every card call — switch back before any DOS call), find and replace.
2. **0.3**: "sheet view" — a whole page as a 1-pixel-per-character thumbnail in mode 1 with a box to
   jump around (the user liked this idea a lot); menu bar alongside the CTRL keys.
3. **0.4**: output — printer port (Centronics, port `$0E` data / strobe; plain text and Epson
   bold/underline), **PDF export** to the card (text-only PDF with built-in Courier/Helvetica: just
   text objects plus an xref table of byte offsets), choice of line endings.
4. **0.5**: other file types — BASIC programs (detokenise a BASIC `.VZ` to text, edit, retokenise on
   save) and a read-only hex/ASCII viewer.
5. **0.6**: big files paged from the card (VZDOS seek reaches into large files; VZ-DECK's MIDI
   streaming is prior art), undo, bookmarks, word count.
6. Later: spell check with a dictionary file on the card.

When adding features: keep the editor hot path (typing → render → flush) under ~2 frames; measure
with `tools/t7.py` and `tools/prof.py` before and after.

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

`harness.FS(card.sec).check()` verifies a card image: FAT copies identical, every chain valid, cluster
counts match sizes, no cross-links, **no lost clusters**, nothing past the end of the volume.

Test-script gotchas: keys pressed while the editor is busy are lost (as on the real VZ) — add
`('WAIT', n)` after open/save; the file list is sorted folders-first then by name, so count entries
(e.g. `SHELL.VZ` sorts before `T.TXT`; after a save a `.BAK` appears and shifts positions).

The emulator traps any call into the BASIC ROM (`$0000`-`$3FFF`) and stops with "ROM xxxx", except a
few known ones; `JP 0` is treated as a restart. VZ-ED never calls the ROM.

---

## 11. Repository and locations

- GitHub: `https://github.com/imbrendenmurphy-dev/vz300-and-microbee-games` (public), folder
  **`VZ-Ed/`**. Account `imbrendenmurphy-dev`. Copyrighted conversions are kept out of this repo by
  the user's choice; original projects only. The repo `.gitignore` excludes `__pycache__`, ROMs and
  tape images.
- User's PC (Windows): working clone `C:\Users\Owner\Documents\Codex\vz300-and-microbee-games`
  (pull to get `VZ-Ed/`); standalone copy saved at `C:\Users\Owner\Documents\VZEd_VZ300` at handover
  (if the save to the PC succeeded — see the chat). VZ-DECK lives in the repo at `VZ-Deck/` and on the
  PC at `C:\Users\Owner\Documents\VZDeck_VZ300`.
- On that PC use `py` (not `python`). Git is the copy bundled with GitHub Desktop:
  `%LOCALAPPDATA%\GitHubDesktop\app-*\resources\app\git\cmd\git.exe`. Commit as BPM.
- After each step: rebuild, run the relevant tests, update `release/`, README and this file, commit
  and push, and copy to the PC folder. The user likes releases as: blurb with tech specs, separate
  screenshots, a zip, and a plain-text blurb for Facebook/YouTube.
