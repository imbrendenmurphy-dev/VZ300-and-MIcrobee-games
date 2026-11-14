# SPINDRIFT — design and technical notes

*Microbee Premium Plus. VIBED BY BPM 2026.*

## 1. The machine, and what it decided

| Fact (Premium Plus) | What it meant for the game |
|---|---|
| Z80 at 3.375 MHz; a scanline is 216 T, a field 313 lines = 67 608 T | Every cost below is in T-states. At 25 frames a second a frame has 135 216 T |
| The 40-column mode: dot clock select (`IN A,(09h)` with A = 1) plus BPM's MODES40 6545 table for 40 × 25 cells of 8 × 10: 35h 28h 2Ch 34h 1Eh 02h 19h 1Ch 48h 09h | 320 × 250, a full PAL picture (31 rows of 10 lines + 2 = 312 lines). The tallest picture whose 1000 cells still let the two screen pages fit 1K each. (1.0–1.3 used 8 × 8 cells, 320 × 200) |
| 32K PCG RAM = 2048 glyphs; the screen is 1000 cells | Every cell can show a glyph of its own: sprites are composed per cell, not built from tiles |
| The 6545 holds the CPU on any video RAM access while a line is drawn | All video writes go in the vertical blanking: 312 − 250 = 62 lines = 13 392 T (it was 113 lines with 8 × 8 cells). At 25 frames a second a frame has two blankings, and the commit uses both when it must |
| 1 MB RAM in 32K blocks | Art for six depth sizes, eight shifts each, without squeezing |
| One speaker bit, no sound chip | Music and effects are played in the time the frame waits for the blanking |

## 2. The game

**Theme.** Spindrift is the spray the wind tears off a wave. The player rides the rim of a vortex; the enemies are the spray it throws outward. Eight sectors run from the Oort cloud inward to the sun's corona and finally *The Eye*, the thing at the centre of the spiral.

**The orbit.** The ship's angle is 8.8 fixed point (256 to a turn). Z and X sweep; the stick or arrows choose a side of the vortex and the ship takes the short way round. The orbit is 115 lines high (the arena is all 25 rows of 10 lines: the HUD is in the corners) and, by default, 105 pixels wide: round on a CRT, where a 40-column pixel shows about 1.1 lines wide. (Version 1.0 stretched it to fill the width; it looked like an ellipse.) Because a screen that stretches the picture to fill 4:3 shows the pixel narrower, the width is a setting: the **screen shape** screen offers eight, 89 to 150 pixels (1.3's 71–136 scaled by 1.25 for the taller picture; the widest is held at 150 so the ship stays on screen). The position table's dx column is rebuilt from a pristine copy for a 150-pixel orbit (block 6) through a 256-entry scale map, in about 0.2 s. `polar` clips y: a point off the top or bottom comes back as FFh, and `draw_spr` skips a sprite whose centre is at or past line 250. Everything else works in angle and depth, so aiming, hits and formations follow the shape by themselves.

**8 × 10 cells (1.4).** Every glyph is 10 lines: sprite glyph buffers are 10 bytes, 25 to each 256-byte page (100 slots, D000–D3FF), copied to the PCG by an unrolled stack copy of five pops and five pushes (~141 T a glyph); 8-line glyphs (the font, icons) are loaded with two blank lines under them. Lines map to rows through page-aligned tables (`ysub`, `yrow2`, `ystar`), so `draw_spr` and `star_cell` never divide by 10. The logo and the Guardian's core were re-cut into 10-line cells (the core is now 4 × 4 cells, 16 glyphs a face); the star dots sit on lines 1, 3, 6 and 8 of a cell.

**The starfield fills the screen.** In 1.3 the stars are drawn at twice the vortex's scale (`star_polar`: x = 2x − CX, y = 2y − CY from the ring's own position table), so they stream past the ring and out into the side borders and corners at every screen shape; a star that leaves the screen is sent back to the centre at once instead of travelling on unseen.

**The HUD in the corners.** Version 1.1 kept rows 0 and 24 for the HUD; 1.2 moves it into the four corners (8 columns by rows 0-4 and 22-24), where even the widest ring never reaches, and the arena gets the whole screen height: the orbit grew from 80 to 92 lines. Top left: SCORE and HI. Top right: SECTOR n, its name a word a row, the lap after the first. Bottom left: SHIELD and its pips, the ships in reserve. Bottom right: WARPS and the count, or the Guardian's CORE and its eight-segment bar. The corner cells are marked as text, so sprites and stars pass behind them; HUD text in the queue carries a mark (bit 7 of its colour) so a flash never paints it, and the flash itself fills the whole screen except the corners (rows 24-22 and 4-0 in the middle 24 columns, rows 21-5 the full width), 4.8 K T by stack pushes.

**Warps.** "4 WARPS TO COMET LANES": two waves a sector, a Guardian every second sector, so the count runs 4, 3, 2, 1 to each Guardian, shown under the sector's name and between its waves, when nothing is on screen to hide.

**Depth.** An enemy's position is (angle, depth). Screen radius is `(depth / rim) ^ 1.5`: things crawl in the distance and rush at the end, which is what makes the approach readable. A table in block 4 turns (angle, depth) into a screen position and a size class. Each enemy is a vector drawing rasterised at six sizes (3 to 16 lines) and stored pre-shifted eight ways, and drawn dim when far, bright when near.

**Paths.** Enemies run small path programs (data.asm): move by (angle, depth) over n frames, aim at the player, move along the orbit, home, fire, warn, go back to the centre, join the formation. Seven entry paths and seven attack runs, mixed differently in each sector. `P_WARN` makes an attacker flash and sound the warning before it leaves the formation.

**Fairness.** Three ships with three shield hits each; a moment of safety after a hit; the first wave never fires; enemy bullets are bright, few and visible at all sizes.

## 2a. Sound

### SWIRL, the title engine (src/mus.asm)

All of the CPU, three voices in time slots:

| Voice | What | Holds the speaker |
|---|---|---|
| BASS | pulse; step + duty per tick | 80 T |
| PHASE | two oscillators, joined by XOR (or OR / AND) | 62 T |
| ARP | pulse; step + duty per tick | 76 T |

218 T a sample, 15 482 samples a second. Each voice's output is held until the next voice's turn, so the speaker averages them: they add, where OR-ing pulses (the usual two-voice trick) mostly masks one with the other. A tick is 255 samples, about 59 a second. Each tick a mask byte says which settings change (two phaser steps, the bass step and duty, the arp step and duty, a drum, the phaser's join), so a held note costs one byte a tick. Drums are 1-bit pulse trains made in Python (a kick sweeping from 1.5 kHz to about 150 Hz, a snare's shell and decaying noise, hats, toms); a drum stops the voices for its length and the tick is shortened by as much, so the tempo holds.

The title and the hall of fame run on SWIRL's ticks. A hook each tick reads SPACE (every tick), one of C / M / S (in turn) and the stick's fire; only when the beam is in the vertical blanking does it paint a column of the logo, a letter of the prompt and a star. In the picture the 6545 would hold the CPU on each video write and the music would gap; measured, the gap is 2.1% of a tick.

"Spiral Arms" (tools/song.py): A minor, 7 ticks a sixteenth (about 125 BPM), Am – G – F – E. 32 bars: intro (phaser pad fading in, hats creeping in), groove A (16th-note squelch bass, four-on-the-floor kick, snare on 2 and 4, tick-rate arpeggios), groove B (the lead: a scoop into each note, vibrato after 10 ticks), breakdown (the phaser plays the hook with a wandering detune, kick only, a snare build), groove A' (arps, then the lead's answer). It loops back to groove A. 20 543 bytes in block 7.

### In the game (src/sound.asm)

The frame's work is silent; the voices sound while it waits for the blanking (a typical frame: 91 samples, about 7 ms). Three voices, 264 T a sample with the glide (12 800 a second):

| Voice | What |
|---|---|
| MELODY | the note and twice its step plus 3, XOR'd: the phaser's shimmer, a note an octave down from a bare square's "bleep" |
| BASS | a pulse; its duty plucks (120, 88, 64, 48 … over the note's first frames) |
| FX | the effects' own voice: a pulse with a duty and a pitch that glides every 16 samples, or pitched noise (a new random bit each time its rate counter wraps) |

An effect is a list of frames; each frame sets a start pitch, duty (or noise) and a glide sized to reach its end pitch in a typical frame's idle time. Starting each frame afresh means a busy frame can never run a glide out of range, and the frame rhythm itself becomes part of the wuckas. When the melody is silent its counters are zeroed, so their XOR can't hold the speaker high (that was a 25 Hz buzz in the first try). Tunes, effects and the pitch table are in block 7 at 6000h; snd_tick maps the block in to read them, once a frame.

## 3. The renderer

Two screen pages (0000h and 0400h of screen RAM) and two PCG banks (14 and 15) take turns. While one page is shown, the next frame is built for the other:

1. **Compose (ordinary RAM, any time).** For each sprite, each cell it touches is given a private glyph buffer (`alloc`) and the sprite's pre-shifted bytes are ORed in (`col_draw`). Sprites overlap freely.
2. **Commit (the vertical blanking).** The new glyphs are copied into the back page's PCG bank by an unrolled stack copy, the cells the back page showed last time are blanked and text is written. Then the new cells get their codes and colours and the 6545's start address is switched, either straight away or, when the estimate says the 62-line blanking won't hold it, at the next blanking (`commit_rest`, run from the blanking poll or the frame's wait). Everything the deferred part reads (its cell list, its page) is left alone by the next frame's compose, so nothing is shared.

Nothing on the page being shown is ever touched, so the picture never tears.

## 4. Measuring and protecting the frame rate

`tools/perf2.py` flies the busiest wave of every sector and every Guardian with the scripted pilot and records each frame: fields taken, commit length, cells and glyphs. The first measurement found:

| Scene | fps | Problem |
|---|---|---|
| Sector waves | 24.3 – 25.0 | fine |
| Guardians | **17.6 – 22.9** | the core (26 × 32) recomposed every frame, eight 13-line pods, all 24 stars |
| Phase changes | — | commits of up to **69 000 T** against a 24 408 T blanking |

What was done:

| Change | Effect |
|---|---|
| The Guardian's core became 60 fixed glyphs (3 faces × 20) in PCG bank 12, placed through the text queue and re-queued only when its face or colour changes | ~24 000 T a frame less in Guardian fights |
| `alloc` trimmed; glyph buffers cleared after the commit by a stack fill instead of one by one | ~100 T less per cell |
| Half the stars during a Guardian; pods drawn at 10 lines near the rim | fewer cells |
| A late frame commits only at the start of a fresh blanking | the commit always gets the whole window (A/B-tested: slightly better than committing late). In 1.4 a frame that arrives later in the blanking commits anyway and leaves its new cells and flip for the next blanking |
| The HUD redraw split over two frames, and it waits a frame when messages are being written | no text burst over ~44 cells |
| A new message only blanks the old cells it does not cover | fewer text cells |
| The flash fill by stack pushes | 15 000 T → 5 400 T |

Result, final build:

| Scene | fps | frames on time |
|---|---|---|
| Sector 1–8, wave 2 | 23.4 – 24.9 | 86 – 99% |
| Guardian, sectors 2/4/6/8 | 24.6 / 24.6 / 24.3 / 23.5 | 97 / 97 / 94 / 87% |
| **All play** | **24.3** | **94.5%** |

(Measured for 1.3, 8 × 8 cells: 1.2's stars stopped at the ring and measured 24.6 fps, 97.0%; 24 stars over the wider field measured 23.0 fps, so it stays at 18.)

**1.4, 8 × 10 cells, 320 × 250.** The blanking fell from 113 lines to 62. Measured again:

| Scene | fps | frames on time |
|---|---|---|
| Sector 1–8, wave 2 | 22.7 – 25.0 | 79 – 100% |
| Guardian, sectors 2/4/6/8 | 23.4 / 23.7 / 23.8 / 22.8 | 85 / 88 / 89 / 80% |
| **All play** | **23.9** | **90.5%** |

What it took: (1) the commit's last part can wait for the next blanking (above); (2) **more blanking polls.** The game counts fields by polling the 6545's blanking bit, and the first 8 × 10 build missed whole blankings in long stretches without a poll (the star draw, the shots' hit tests, the enemy updates ran up to 25K T), so frames waited a field for nothing: 22.5 fps, and only 59% on time even in sector 1. Polls inside those loops (`vbpoll_q`, which sees a blanking begin but doesn't age it, so the late-commit guard isn't fooled) brought the longest gap to 10K T; (3) the commit estimate calibrated against the model (~55 T a unit). The busiest scenes lose a frame in five because the bigger 1.4 arena keeps more enemies on screen at once and the shorter blanking leaves less slack.

Controls are read once a frame (at most 40 ms old), and every key is scanned every frame.

## 5. Bugs found along the way

- **Key taps missed.** ESC, H, S, C, M and R were scanned every fourth frame, so a quick tap could fall between scans. Now every key is scanned every frame (≈1 200 T).
- **Flashes wiped colours.** The full-screen flash rewrote every cell's colour and restored plain white, losing the colour of messages and the core; sprite cells kept black paper, so bullets and stars wore black boxes during a red flash. Now the flash is filled first and everything written after it takes the flash's paper, messages and the core are shown again as the flash ends, and the HUD rows are never given flash paper.
- **The HUD kept "CORE" after a Guardian.** It now goes back to the sector's name.
- **Overprinted text** on the title and the initials screen (adjacent rows with a tall font).

## 6. Memory

| Where | What |
|---|---|
| Block 0, 8000h–C175h | The program (16 757 bytes) |
| C800h–D3FFh | Cell tables and glyph buffers |
| D500h–D7FFh | Game objects: 16 enemies, shots, bullets, effects |
| D800h–EBFFh | Three cell lists and two text queues |
| EC00h | Variables; stack below F000h |
| Block 4 | Position table, row pointers, font, ship, shots, bullets |
| Block 5 | Enemies (9 kinds × 2 frames × 6 sizes × 8 shifts), explosions, score popups |
| Block 6 | The title logo, the Guardian's core glyphs, the pristine dx column for the screen shape |
| Block 7 | SWIRL's title music (0000h), the in-game music, effects and pitch table (6000h) |
| PCG banks | 0 font and icons, 2 logo, 12 core, 14/15 sprite pools |
