# FRILLSEEKER — hardware investigation, design and plan

*An original mascot platform game for the Microbee Premium Plus. VIBED BY BPM 2026.*

This is the working document: what the machine can really do (with the
numbers), the directions considered, the one chosen and why, what the
prototype proves, and what comes next.

Where a figure says **measured**, it came from running the real program in
the raster-accurate Premium Plus model in `tools/emu` (the one built for the
megademo, which models the 6545 scanline by scanline, including the CPU being
held when it touches video RAM during a drawn line — behaviour first seen on
the real machine). **Nothing here has run on real hardware yet.**

---

## 1. What the hardware gives us

### 1.1 The display is one dot clock, and the 6545 decides the rest

| Fact | Consequence |
|---|---|
| 13.5 MHz dots, 3.375 MHz Z80: 4 dots a T-state, 216 T a scanline, 313 lines a frame (67 608 T) | Every cost below is in these units |
| The dot clock does not halve. 80-column mode fills the tube with 640 dots; 64 columns is 512 dots = 80 % of the width | **A 40-column mode is only 320 dots: a picture half the tube wide.** Investigated and rejected for the playfield. (It would buy CPU time — see 1.3 — but not a bigger pixel.) |
| A hardware pixel is about 0.55 wide to 1 tall on a 4:3 tube | **Two hardware pixels by one scanline is very nearly square** (≈1.1 : 1). That is the game's "logical pixel": 256 × 192 of them |
| R9 sets the scanlines in a character row, and the screen RAM is 2048 cells | Cells need not be 8 × 16. 64 columns × 32 rows × **6 lines** uses all 2048 cells exactly and gives 192 lines |

So the chosen mode: **64 × 32 cells of 8 × 6 hardware pixels = 4 × 6 logical
pixels.** A cell is 0.73 : 1 on the tube — far squarer than the stock 8 × 16
(0.28 : 1) — and it is also the *colour* cell: two colours per 4 × 6 pixels,
which is four times finer than a ZX Spectrum's 8 × 8.

CRTC table (`crtc_game` in `src/engine.asm`): R0=107, R1=64, R4=51, R5=1
(52 × 6 + 1 = 313 lines), R6=32, R7=43, R9=5. The picture sits where the
standard 64 × 16 picture's middle is.

Other geometries looked at:

| Mode | Cells | Verdict |
|---|---|---|
| 64 × 16 of 8 × 16 (stock) | 1024 a page, two pages | Page flipping for free, but colour cells 4 × 16 logical: tall stripes of colour clash |
| 64 × 32 of 8 × 8 | 2048 | 256 lines, but cells 0.55 : 1 and 33 % more bytes per cell for everything |
| **64 × 32 of 8 × 6** | **2048** | **Chosen.** Squarest cell that fills the screen RAM; cheapest per cell |
| 64 × 32 of 8 × 5 | 2048 | Squarer still (0.88 : 1) but only 160 lines: letterboxed |
| 40 × 48 of 8 × 4 | 1920 | Truly square cells, but half the tube wide |
| 80 columns | — | 2048 cells cannot cover it at a useful height |

### 1.2 Can the PCG be a bitmap? Yes — exactly

32K of PCG RAM is 16 banks × 128 glyphs = **2048 glyphs**. A cell picks its
glyph with 7 bits of screen code and 4 bits of attribute RAM (the bank). The
screen has **2048 cells**. So every cell on the screen can have a glyph of its
own: the Premium Plus is, if you want it to be, a 512 × 192 bitmap machine
with per-cell colour.

The game does not use it as a plain bitmap, because a bitmap must be erased
and redrawn and the CPU is slow. It uses the same fact more cleverly (§3):
*any cell can be re-pointed at any glyph, in three bytes.*

### 1.3 The catch that shapes everything: video RAM during a drawn line

On the Premium Plus the CPU is **held** when it touches screen, attribute,
colour or PCG RAM while a line is being displayed, until that line's
horizontal blanking. Measured effect: a tight copy into the PCG during the
picture gets about **5–6 bytes a scanline** instead of 13; in the vertical
blanking it runs at full speed.

With a 192-line picture, the vertical blanking is 121 lines = **26 000 T**.
That is the budget for everything that must not be seen happening. The engine
is built round it: all visible changes are small and happen there; all the
heavy work happens in ordinary RAM, where nothing is held. Measured: the
finished engine loses under **1 000 T a frame** to the 6545.

### 1.4 Memory

1 MB = 32 blocks of 32K, one mapped at 0000–7FFF, block 0 always at
8000–EFFF. Used so far: 3 blocks of sprite frames, 1 of font, 2 + 2 of rooms
(colour and monochrome art). The megabyte is what lets every sprite frame be
stored **eight times** (four pre-shifted copies × two facings) so that the
drawing loop never shifts a bit, and what will let each room carry its own
complete picture (12–16K a room).

---

## 2. Directions considered

Four genuinely different games were sketched against those facts.

**A. INK & PAPER.** A blot of ink in a paper world. The attribute RAM has an
*inverse* bit per cell: one byte flips a cell's solid and empty. The mechanic
is turning the world inside out around you. *For:* the most hardware-native
idea of the four; identical on an amber monitor. *Against:* a puzzle game
wearing a platformer's clothes; the mascot is a blob, hard to love; and it
leans on a hardware bit I have only seen documented, not run.

**B. THE COLOUR THIEF.** The world has been drained to grey; a chameleon
restores colour to every cell it touches (one colour-RAM byte each — nearly
free, and spectacular). *For:* a strong reason to explore every corner.
*Against:* **the core mechanic is invisible on an amber monitor**, which is
what this game will mostly be played on. Fatal.

**C. SWING.** A grappling, swinging hero; rope physics drawn into the cell
bitmap. *For:* swinging is a joy. *Against:* a line drawn through arbitrary
background costs a private glyph per cell it crosses, every frame; and the
hero is defined by a tool, not a personality.

**D. FRILLSEEKER.** A frilled-neck lizard whose whole power is *bluffing*.
One button, read by context: on the ground the frill snaps open and everything
nearby takes fright; in the air the same frill is a parachute. *For:* the
mascot **is** the mechanic, and the mechanic is a change of *silhouette* —
which is exactly what a 1-bit-per-cell machine shows best, in colour or amber;
it needs big, expressive, shape-changing animation, which is what the
megabyte and the cell renderer are for; it is funny; and it is Australian
without being another bee or bilby. *Against:* less of a "new idea in game
design" than A.

### Recommendation: D

A is the cleverest use of one hardware bit; D is the best *game*, the best
*character*, and the best fit for the whole machine. D was built.

---

## 3. The game

### 3.1 Bluff

**Bluff** is the smallest dragon in the Top End with the biggest act. A
frilled-neck lizard: upright on his hind legs, tail out behind for balance,
a spiky collar folded round his neck — until he opens it.

* **Silhouette:** two of them. Folded, a small cheeky dinosaur. Flared, a
  scalloped disc nearly twice his width with a hissing mouth in the middle.
  You can tell which from across the room on an amber screen.
* **Animation:** Bluff is a *puppet*, not a sheet of drawings
  (`tools/hero.py`): a torso, a tail, two-link legs and arms solved by
  inverse kinematics, a hand-drawn head, and a parametric frill, posed and
  rasterised to 1-bit pixels with outlines cut where parts overlap. Every
  frame is computed, so in-betweens are free: the run is 8 frames, the frill
  opens through 4. 21 frames so far, 50K of sprite data.
* **Personality:** he runs like he is late, blinks, flicks his tail when
  bored, and looks genuinely pleased with himself when the bluff works.

### 3.2 What makes it its own game

1. **The bluff.** Hold FRILL on the ground: the frill pops and he hisses.
   Cane toads within reach leap in fright and land on their backs, legs
   kicking, for five seconds. He never hurts anything — he just scares it.
2. **A toad on its back is a trampoline.** Land on its belly and you go
   half as high again as a jump. So enemies are not obstacles to remove but
   *furniture to arrange*: the way up to a high ledge is to frighten the
   right toad in the right place. (The third prototype room is built on it.)
3. **The frill is a parachute.** Hold FRILL in the air and he sinks at a
   fifth of falling speed, steering. Bounce + glide is the game's long jump.
4. *Planned:* **the sprint.** Run without stopping and he rears up and
   bolts — faster, longer jumps, and across water for a few steps.

### 3.3 The world and the story

King Bufo's cane toads have marched into the Top End and pinched every last
bug for a feast. Bluff wants his dinner back. Five regions, flip-screen rooms
joined into a map, each room a painting:

1. **The Red Dirt** — savanna at dusk: ghost gums, termite mounds, spinifex
2. **The Billabong** — lily pads, reeds, something with eyes in the water
3. **Stone Country** — the escarpment: ledges, waterfalls, rock-art caves
4. **The Diggings** — an opal mine: dark, glittering, minecart rails
5. **The Wet** — the storm breaks: lightning, wind that carries a glider,
   rising water, and King Bufo

Forgiving by design: hearts not instant death, a fall puts you back on the
last solid ground you stood on, every room is a checkpoint, progress saves to
disk.

### 3.4 Art direction

* **Chunky and square:** everything is drawn in 2 × 1 logical pixels.
* **Ink is light, paper is the world.** Every cell's ink is the lit detail
  and its paper the base colour. A monochrome monitor shows ink only — so the
  same patterns read as line art on amber, and colour is a second layer of
  richness rather than something the picture depends on. Each room is painted
  twice, once for each.
* **Flat bands of sky, detail in the solids.** Sprites are ink. Where a
  sprite crosses a cell the cell's ink becomes the sprite's colour; so the
  air the hero moves through is kept as plain paper, and the far range is
  *stepped on the cell grid* so that no cell mixes rock and sky. Cells that
  are busy with their own ink keep it. Result: almost no colour clash, at a
  quarter of the Spectrum's cell size.
* **No two rooms share art.** A room is not built from a tile library: it is
  *painted* procedurally as one 256 × 180 picture — every dirt tile, mound
  and branch with its own random texture — then cut into cells and
  de-duplicated. A room loads its own glyph set when you walk in.

---

## 4. The engine (what the prototype proves)

### 4.1 Sprites without tiles, erasing or tearing

For each cell a sprite touches, a **private glyph** is composed in ordinary
RAM: the background's own glyph for that cell, with the sprite masked over
it. The cell is then pointed at that glyph.

* **Two glyph pools take turns** (PCG banks 12–13 and 14–15). The new
  frame's glyphs are written while the old frame's are still on show, so
  nothing is ever erased or half-drawn in view.
* The only thing done in the vertical blanking is a **flip list**: for each
  changed cell, three bytes (screen code, bank, colour). Typically 60–90
  cells: ~8 000 T of a 26 000 T blanking.
* Sprites move in single logical pixels in both directions and change shape
  freely between frames; they cross cell boundaries without snapping, because
  the four horizontal alignments are stored pre-shifted and the six vertical
  ones are just where a column's bytes fall.
* Sprite columns are stored trimmed to their used lines, so the empty corners
  of a big frame (under a raised tail, beside a head) touch no cells at all.

### 4.2 The living background

Glyphs 768–1023 (banks 6–7) are **rewritten while a room is on show.** When
a room is built, it is painted in four phases; any cell that differs between
phases gets a glyph of its own and its frames go in the room's record. In the
game, one small set (≤10 glyphs, 60 bytes) is rewritten in each vertical
blanking: water drifts, spinifex and reeds sway, stars twinkle. Cost in a
frame: about 4 000 T, and no cell changes.

**The bugs are not sprites.** Each is a few cells of living background that
flutter through four frames worked out at build time against the scenery
behind them. A room can hold as many as you like for nothing; the hero
composites over them like any other background; eating one just puts the
scenery's own cells back.

### 4.3 The frame

Game logic runs in fixed 50 Hz ticks; a frame runs as many ticks as fields
it took, so speed never changes.

| Measured, T-states a frame | Bluff running + 1 toad |
|---|---|
| Composing sprite glyphs (56 cells) | 58 000 |
| Writing them to the PCG | 8 600 |
| Flip list, restoring uncovered cells | 11 000 |
| Living background | 6 000 |
| Game logic, keys | 12 000 |
| **Work** | **≈ 103 000** |
| Left over — spent making sound | ≈ 32 000 |
| **Frame** | **135 216 = 2 fields = 25.0 fps** |

Bluff standing alone runs at 50 fps; running alone, or with a toad, 25. The
plan is a locked 25 with room for three or four enemies: see §6.

### 4.4 Sound

One speaker bit and no interrupt. The game makes no sound while it works: the
tone is played in the time left while the frame waits for the vertical
blanking, by a loop that watches the 6545's blanking bit. Effects are short
pitch lists (jump, land, hiss, bug, hurt, boing, croak). The walking tune is
slow, separate notes, each sounded in three successive waits (~90 ms),
measured in tune to within a few cents at this register.

### 4.5 Disk

`FRILL.DS8` boots to the A> prompt; `FRILL` loads the program and seven data
files into the RAM blocks through CP/M, then takes over the machine. It is
the same loader as the Australian Open Tennis disk. **I could not run the
boot in the emulator this time** (the boot ROM is not in the repository), so
the disk path is built but unproven for this title; the program itself is
tested by loading the blocks directly.

---

## 5. Status

**Working in the prototype:** the 64 × 32 × 6-line mode; the cell renderer;
the living background; Bluff's 21 frames (idle, blink, run, jump, fall, glide,
flare, hurt) facing both ways; cane toads (sit, hop, fright, on their back);
the bluff, the trampoline, the glide; three linked rooms; hearts; falls
return you to solid ground; sound effects and a walking tune; colour or
monochrome art chosen at the start; a bootable disk image.

**Not yet:** a title sequence, the sprint, the world map and its other four
regions, more creatures, bosses, the save, configurable keys, music for the
title, an ending.

**Not verified:** real hardware. The things most worth checking on the real
machine first are the 6-line CRTC mode (does the monitor hold it, is it
centred) and whether the picture is clean when Bluff moves.

---

## 6. Next

1. **Re-plumb for size.** The engine and game logic share 8K at 8000h with
   the room shadows. Move game logic into its own 32K block; keep only the
   renderer upstairs. That also frees room for a per-cell table of pattern
   addresses, worth ~90 T a cell (≈ 5 000 T a frame).
2. **The sprint**, then tune the feel on real keys.
3. **A proper front end:** title picture with Bluff, title music with the
   whole CPU to itself (two voices), attract mode, key set-up.
4. **The Red Dirt complete:** ~12 rooms on a map, two more creatures, a
   checkpoint/save, the first boss. That is the "is this a game?" milestone.
5. Then the other four regions, the ending, and a release package.
