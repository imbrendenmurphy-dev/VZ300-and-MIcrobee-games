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

### 1.1 The display: the 40-column mode

> **Correction.** The first version of this document said the dot clock
> cannot be halved and that a 40-column mode would only be a picture half
> the tube wide, and the first prototype was built on a 64-column mode with
> doubled pixels. That was wrong. BPM's own MODES.COM test **on the real
> Premium Plus** shows the 40-column modes work, at half the dot clock, the
> full width of the tube. The game has been moved to it, and is better for
> it in every way that was measured (§4.3).

| Fact | Consequence |
|---|---|
| 3.375 MHz Z80; a scanline is 216 T, a frame 313 lines (67 608 T) | Every cost below is in these units |
| **40-column mode: 6545 R0–R3 = 35h, 28h, 2Ch, 34h** (MODES.COM's values, proven on the machine) | 320 pixels across the whole tube. A pixel is about 1.25 wide to 1 tall: chunky and near square |
| R9 sets the scanlines in a character row | **8-line rows: an 8 × 8 cell is very nearly square.** 40 × 25 of them = 320 × 200 |
| The screen RAM is 2048 cells; 40 × 25 uses 1000 | Room to spare (a second page, or a taller picture) |

So the game's mode: **40 × 25 cells of 8 × 8 pixels.** Rows 0–1 are the
status panel, rows 2–23 the playfield (320 × 176 = 20 × 11 tiles of 16 × 16).
The CRTC table is the one KABOOMERANG confirmed against MODES.COM:
`35 28 2C 34 26 01 19 21 48 07 20 07`.

One thing I could not settle from here: KABOOMERANG's notes say MODES.COM
selects the mode with the CRTC registers alone, while STARHIVE also reads
port 09h first. This game follows MODES.COM (registers only), because that
is the program that has actually run on the machine. If the picture does not
come up on the real Premium Plus, that is the first thing to look at.

Why not the alternatives:

| Mode | Verdict |
|---|---|
| 64 × 16 of 8 × 16 (stock) | Narrow tall pixels, colour cells 8 × 16, side borders |
| 64 × 32 of 8 × 6, art in doubled pixels (the first prototype) | Same pixel size as 40-column, but only 256 across, side borders, and **twice the bytes and cells for every sprite** |
| **40 × 25 of 8 × 8** | **Chosen.** Square cells, full width, half the work |
| 40 × 24 of 8 × 11, 40 × 32 of 8 × 8 | Also proven; kept in mind (a taller picture is possible later) |

### 1.2 Can the PCG be a bitmap? Yes, twice over

32K of PCG RAM is 16 banks × 128 glyphs = **2048 glyphs**; a cell picks its
glyph with 7 bits of screen code and 4 bits of attribute RAM. The 40 × 25
screen has **1000 cells**. So every cell can have a glyph of its own with
more than a thousand left over: the Premium Plus can be a 320 × 200 bitmap
with per-cell colour, double-buffered.

The game does not use it as a plain bitmap, because a bitmap must be erased
and redrawn and the CPU is slow. It uses the same fact more cleverly (§4):
*any cell can be re-pointed at any glyph, in three bytes.*

### 1.3 The catch that shapes everything: video RAM during a drawn line

On the Premium Plus the CPU is **held** when it touches screen, attribute,
colour or PCG RAM while a line is being displayed, until that line's
horizontal blanking (first seen on the real machine with the megademo). In
the vertical blanking it runs at full speed.

With a 200-line picture the vertical blanking is 113 lines = **24 400 T**.
That is the budget for everything that must not be seen happening. The engine
is built round it: all visible changes are small and happen there; all the
heavy work happens in ordinary RAM, where nothing is held. Measured: the
engine loses about **4 000 T a frame** to the 6545.

### 1.4 Memory

1 MB = 32 blocks of 32K, one mapped at 0000–7FFF, block 0 always at
8000–EFFF. Used so far: 3 blocks of sprite frames, 1 of font, 2 + 2 of rooms
(colour and monochrome art). The megabyte is what lets every sprite frame be
stored **sixteen times** (eight pre-shifted copies × two facings) so that the
drawing loop never shifts a bit, and what will let each room carry its own
complete picture.

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

* **Chunky and square:** 320 × 200 real pixels, each a little wider than
  tall; 16 × 16 tiles; Bluff is 24 pixels high.
* **Ink is light, paper is the world.** Every cell's ink is the lit detail
  and its paper the base colour. A monochrome monitor shows ink only — so the
  same patterns read as line art on amber, and colour is a second layer of
  richness rather than something the picture depends on. Each room is painted
  twice, once for each.
* **Flat bands of sky, detail in the solids.** Sprites are ink. Where a
  sprite crosses a cell the cell's ink becomes the sprite's colour; so the
  air the hero moves through is kept as plain paper, and the far range is
  *stepped on the cell grid* so that no cell mixes rock and sky. Cells that
  are busy with their own ink keep it. An 8 × 8 colour cell is the size of a
  Spectrum's, so this discipline matters; some scenery (the ledges, the
  branches) still wants redrawing for two colours a cell.
* **No two rooms share art.** A room is not built from a tile library: it is
  *painted* procedurally as one 320 × 176 picture — every dirt tile, mound
  and branch with its own random texture — then cut into cells and
  de-duplicated. A room uses about 200 of the 768 glyphs it may: there is a
  lot of room for richer pictures.

---

## 4. The engine (what the prototype proves)

### 4.1 Sprites without tiles, erasing or tearing

For each cell a sprite touches, a **private glyph** is composed in ordinary
RAM: the background's own glyph for that cell, with the sprite masked over
it. The cell is then pointed at that glyph.

* **Two glyph pools take turns** (PCG banks 14 and 15). The new
  frame's glyphs are written while the old frame's are still on show, so
  nothing is ever erased or half-drawn in view.
* The only thing done in the vertical blanking is a **flip list**: for each
  changed cell, three bytes (screen code, bank, colour). Typically 20–40
  cells: ~3 000 T of a 24 400 T blanking.
* Sprites move in single pixels in both directions and change shape freely
  between frames; they cross cell boundaries without snapping, because the
  eight horizontal alignments are stored pre-shifted and the eight vertical
  ones are just where a column's bytes fall.
* Sprite columns are stored trimmed to their used lines, so the empty corners
  of a big frame (under a raised tail, beside a head) touch no cells at all.

### 4.2 The living background

Glyphs 768–1023 (banks 6–7) are **rewritten while a room is on show.** When
a room is built, it is painted in four phases; any cell that differs between
phases gets a glyph of its own and its frames go in the room's record. In the
game, one small set (≤10 glyphs, 80 bytes) is rewritten in each vertical
blanking: water drifts, spinifex and reeds sway, stars twinkle. Cost in a
frame: about 5 000 T, and no cell changes.

**The bugs are not sprites.** Each is a few cells of living background that
flutter through four frames worked out at build time against the scenery
behind them. A room can hold as many as you like for nothing; the hero
composites over them like any other background; eating one just puts the
scenery's own cells back.

### 4.3 The frame

Game logic runs in fixed 50 Hz ticks; a frame runs as many ticks as fields
it took, so speed never changes.

| Measured, T-states a frame | 64-column prototype | **40-column** |
|---|---|---|
| Cells Bluff + a toad touch | 56 | **22** |
| Composing sprite glyphs | 58 000 | **26 000** |
| Writing them to the PCG | 8 600 | **4 100** |
| Flip list, restoring uncovered cells | 11 000 | **4 000** |
| Living background | 6 000 | **5 000** |
| Game logic, keys, the rest | 12 000 | **12 000** |
| **Work** | ≈ 103 000 | **≈ 58 000** |
| **Frame rate, Bluff running + a toad** | 25 fps | **49–50 fps** |

In the 40-column mode Bluff and a toad run at **50 frames a second** (98 %
of frames in one field, measured). That leaves about 10 000 T a frame for
sound at 50, and the option of locking to 25 with three or four creatures
on screen and far more time for sound. Which to prefer is a choice to make
by ear and eye on the real machine.

### 4.4 Sound

One speaker bit and no interrupt. The game makes no sound while it works: the
tone is played in the time left while the frame waits for the vertical
blanking, by a loop that watches the 6545's blanking bit. Effects are short
pitch lists (jump, land, hiss, bug, hurt, boing, croak). The walking tune is
slow, separate notes, each sounded in three successive waits (~90 ms),
measured in tune to within a few cents at this register.

### 4.5 Disk

`FRILL.DS8` boots to the A> prompt; `FRILL` loads the program and its data
files into the RAM blocks through CP/M, then takes over the machine. It is
the same loader as the Australian Open Tennis disk. **I could not run the
boot in the emulator this time** (the boot ROM is not in the repository), so
the disk path is built but unproven for this title; the program itself is
tested by loading the blocks directly.

---

## 5. Status

**Working in the prototype:** the 40-column mode; the cell renderer;
the living background; Bluff's 21 frames (idle, blink, run, jump, fall, glide,
flare, hurt) facing both ways; cane toads (sit, hop, fright, on their back);
the bluff, the trampoline, the glide; three linked rooms; hearts; falls
return you to solid ground; sound effects and a walking tune; colour or
monochrome art chosen at the start; a bootable disk image.

**Not yet:** a title sequence, the sprint, the world map and its other four
regions, more creatures, bosses, the save, configurable keys, music for the
title, an ending.

**Not verified:** real hardware. The things most worth checking on the real
machine first: that the 40-column picture comes up and is centred (§1.1),
that it is clean when Bluff moves, and how the sound comes across.

---

## 6. Next

1. **Re-plumb for size.** The engine and game logic share 10K at 8000h.
   Move game logic into its own 32K block; keep only the renderer upstairs.
   A per-cell table of pattern addresses would save a further ~90 T a cell.
2. **The sprint**, then tune the feel on real keys.
3. **A proper front end:** title picture with Bluff, title music with the
   whole CPU to itself (two voices), attract mode, key set-up.
4. **The Red Dirt complete:** ~12 rooms on a map, two more creatures, a
   checkpoint/save, the first boss. That is the "is this a game?" milestone.
5. Then the other four regions, the ending, and a release package.
