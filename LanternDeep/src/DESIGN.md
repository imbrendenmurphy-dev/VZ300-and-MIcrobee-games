# THE LANTERN DEEP: hardware findings, engine design, roadmap

*An original PCG dungeon crawler for the Microbee Premium Plus. VIBED BY BPM · 2026.*

This document records what was established about the hardware, how the
engine built for milestone 1 ("the showcase room") works, and how it scales
to the full game.

---

## 1. Hardware: what was verified, and how

| Topic | Finding | Source |
|---|---|---|
| CPU | Z80, 3.375 MHz; one 50 Hz frame = 67,500 T-states | prior Premium conversions, MAME |
| Display mode | 6545 set to **80 × 24 characters of 8 scan lines** (640 × 192). R0–R3 and R8 are the boot ROM's own 80-column values (`6B 50 58 37 … 48`); rows and sync are set for 8-line characters (39 × 8 = 312 lines, vsync row 31) | boot ROM table at 18B3h; earlier conversions |
| Pixel aspect | a pixel is about 1.8× taller than wide, so the 8 × 8 cells are tall. All art is drawn for that | timing arithmetic (13.5 MHz dot clock) |
| Video RAM | F000–F7FF screen (port 1Ch b4 = 0) or attribute RAM (b4 = 1); F800–FFFF PCG bank (1Ch b0–3) or colour RAM (port 08h b6). Port 1Ch b7 enables Premium graphics | MAME `mbee_v.cpp`, earlier conversions |
| **PCG capacity** | 32K = 16 banks × 128 glyphs × **16 bytes**. Each glyph slot is 16 bytes, so the real limit is **2,048 glyphs, not 4,096**. With 8-line cells, bytes 8–15 of each slot are unused. A screen code ≥ 80h picks a PCG glyph; attribute b0–3 picks its bank | MAME renderer (`chr += (attr & 15) << 7`; `pram[(chr<<4)|ra]`) |
| Colour | 16 RGBI colours; colour RAM low nibble = ink, high nibble = paper → exactly two colours per cell. MAME draws colour 3 as dark yellow; an RGBI monitor may show it as brown, and the art works either way | MAME `premium_palette` |
| **Banked RAM** | 1MB = 32 blocks of 32K. **Only the lower 32K is a window**; 8000–FFFF is always block 0. Port 50h: block = (b7 b6 b5) → block bits 4–2, (b1 b0) → bits 1–0, with b1 inverted while ROMs are off (b2 = 1); b3 = 1 removes the video window; b4 moves it to 8000 | ubee512 `memmap.c` (p1024k "pplus" model); consistent with MAME's 256TC-derived banking; confirmed by the earlier loaders' bank scan |
| Timing | no usable timer interrupt: the 6545 status b5 (vertical blanking) is polled. With 192 displayed lines, blanking lasts ~26,000 T, which is plenty for PCG and colour updates | 6545 status, model |
| Keyboard | 6545 light-pen scan (R18/R19 + R31 dummy write, status b6) | earlier conversions, boot ROM |
| Sound | speaker on PIO B bit 6, nothing else: all music, effects and speech are CPU-timed 1-bit | earlier conversions |
| Disk | DS8: 80 tracks × 2 sides × 10 × 512 = 800K; Microbee CP/M system in the first 4 track-sides, then the directory; 4K allocation blocks; 3:1 sector skew | earlier conversions; checked by booting the real ROM in the model |

**Not verified on hardware.** The 1MB decode follows ubee512's Premium Plus
model (MAME marks its Premium Plus driver "not working" and says it has no
technical information for it). To guard against that, `LANTERN.COM` writes a
test byte to blocks 0–15 and reads them back before it loads anything. If the
blocks alias, it refuses with a clear message instead of crashing.

---

## 2. Engine architecture (milestone 1)

### Memory map at run time
```
lower window = block 1 ("home")          upper 32K = block 0 (fixed)
0000-05FF  vectors, loader hand-off       8000-B0FF  engine core, tables, entities
0600-1E2x  game logic, title, menus       C000-CBFF  FLAGS map      (24 x 128)
2800-33FF  TILE map                       CC00-D7FF  LIGHT map      (24 x 128)
3400-3FFF  STAT map (static light|tint|zone)  D800-E3FF  two lit-cell lists
4000-4BFF  ENT map (entity per cell)      E400-E9FF  output queues (full / colour)
4C00-57FF  shadow: character              EA00-EEFF  bounce buffer, dirty queue
6400-6FFF  shadow: colour                 EF00-EFFF  stack
7000-7BFF  shadow: light key              F000-FFFF  video window
```
All map arrays share one layout (24 rows × 128, a one-cell border round the
80 × 22 play area). A cell pointer into FLAGS reaches every other array by
adding a constant to H.

### Expanded RAM banks (filled by the loader)
| Block | Contents |
|---|---|
| 8 | GFX: the game's PCG library (16 banks × 128 × 8 rows) |
| 9 | WORLD: room maps + the four torch ray-trees + the fire-bolt tree; 7000–7BFF is all FFh (cast markers, see below) |
| 10 | TITLE: title illustration glyphs, maps and animation tables |
| 11 | AUDIO: sampled speech |
| 14, 15 | staging for the program halves during loading |

### Lighting: the defining feature
* **Ray-trees, precomputed.** For each facing, `tools/world.py` traces Bresenham
  rays to every cell the lantern can reach, giving each cell a level (0–7)
  from a directional model: a strong cone (~32°, soft shoulder to ~55°) plus
  a small ambient pool, measured in screen distance, so horizontal reach
  allows for the tall cells. The rays are merged into a prefix tree and stored
  pre-order with "skip subtree" pointers.
* **Cast in place from expanded RAM.** FLAGS and LIGHT live in the fixed upper
  block, so the engine maps the WORLD bank into the lower window and walks the
  tree with `POP` (SP = node pointer). A transparent cell is lit and walking
  continues; an opaque cell is lit and its subtree skipped. That is the
  shadow: light stops at walls, pillars and the statue, and passes through
  doorways. Turning swaps nothing: all four trees stay in the bank.
* **Zero-cost markers.** End-of-tree and timing checkpoints are nodes whose
  offset lands in the bank's all-FFh region, so they take the rare "edge"
  path. The common path never tests for them.
* **Architectural light.** A lit wall face also lights the face above it;
  multi-cell pieces (statue, pillars) are lit as one object.
* **Static lights** (crystal, braziers, pool glow) are cast offline with the
  same tracer into the STAT map, with a tint (warm, cool, magic, lava). A
  cell shows max(torch, static); the brighter source chooses the tint.
* **Regions reveal themselves.** Each region's static lights appear in a wave
  spreading from the doorway as you enter, and fade from view when you leave.
* **Three kinds of darkness.** Lit, remembered (explored cells drawn as a faint
  blue lattice; enemies are never shown there) and never seen (black).
* **Flicker.** The flame wavers by redrawing only the fringe cells (levels 1–3).

### Rendering
* Each tile has 4 light variants (full; dimmed 75% ink; remembered 25%
  lattice; faint) and a **light ramp**: for each tint × level, a variant plus
  an ink/paper pair. Light falls off through colour (white → yellow → ochre →
  grey) and ink density, with black paper almost everywhere, so pools of light
  have soft edges rather than coloured rectangles.
* A per-cell **light key** (tint × 8 + level) lets unchanged cells be skipped
  at once. Changed cells are compared with the shadow arrays and sent to two
  queues: **colour-only** (most lighting changes, one byte) and **full**
  (glyph + bank + colour). Both are flushed at the start of vertical blanking.
* **Animation is PCG rewriting.** Water, flames, crystal shimmer and puddle
  drips rewrite their glyphs' rows (all four light variants) in blanking, so
  every cell using them animates at no cost per cell.
* Verified: the Z80 output matches the Python reference renderer cell for cell
  (`tools/compare.py`).

### Measured cost (in the model)
* A relight after a step is about 2 frames in the corridor and 4–5 frames in
  the open hall. Movement is paced to match (horizontal step every 3 frames,
  vertical every 5, because the cells are tall).
* While standing still, a frame costs well under one frame.

### Entities, combat, ambience
Records of 16 bytes (player, bats, skeleton warden, fire bolt, sword arc,
burst, sparks, dust, motes, embers, beetles). The sword arc hits the front cell
and both side cells. The fire bolt is a moving light source (the omni tree is
cast at its cell), lights the corridor as it flies, and bursts with sparks
and a light flash. Dust motes appear in the torch beam, glints over the
pool, embers over the braziers, and beetles scuttle away from the light.

### Sound
* **The wait for vertical blanking is the tone generator.** A pulse wave
  (40 T per count; pulse width = volume, narrowing for decay), noise from the
  refresh register, or silence.
* Two music channels alternate frame by frame (melody over arpeggio). The
  title theme and the hall theme are in `tools/audio.py`. 14 effects.
* **Speech:** flite (built from source) speaks the lines; ffmpeg deepens them
  and adds a stone echo. They are encoded as a 2nd-order delta-sigma 1-bit
  stream at 52.7 kHz (one speaker state every 64 T, cycle-counted code), about
  19 dB in-band SNR. The title speaks "The Lantern Deep"; entering the hall for
  the first time, a voice warns you.

### Title
Painted in full colour (`tools/title.py`), then each 8 × 8 cell takes the best
pair of the 16 colours with ordered dithering: 641 unique glyphs. The torch
flames have 4 frames with private glyphs; a glint sweeps the lettering (only
the columns entering and leaving the band are rewritten); the glow from the
depths breathes. The menu offers New Game, Continue (greyed until saving
exists), Instructions and Credits; 30 s idle starts the attract demo.

### PCG budget
| Use | Glyphs |
|---|---|
| Game tiles × 4 variants (6 banks) | 732 |
| Sprites, effects | 46 |
| Font + status bar | 76 |
| **Free for more regions** | **~1,190** |
| Title illustration (banks 0–14, swapped in) | 641 of 1,920 |

---

## 3. Toolchain
`build.sh` regenerates everything: `tools/world.py`/`art.py` (art, auto-tiling,
lighting and the reference renderer), `build_data.py` (PCG banks, tables,
ray-trees), `audio.py`, `title.py`, `speech.py`, then sjasmplus for
`src/main.asm` and `src/loader.asm`, then `build_disk.py` for `LANTERN.DS8`.

`tools/ppmodel.py` models the Premium Plus (1MB banking, video/attribute/
colour/PCG RAM, 6545 status and keyboard, speaker capture to WAV, FD2793).
`tools/boottest.py` boots the real Microbee boot ROM from `LANTERN.DS8` into
CP/M, types `LANTERN`, and lets the loader run through real BDOS calls into
the game. `play.py` (route-finding tours), `compare.py` and `prof.py` (an
instruction-level profiler) are the test tools.

---

## 4. The full game (this build)

### World
Five regions, twenty rooms (`tools/levels.py`), each 80 x 22 cells. East and
west exits are always rows 10-12 and north/south exits columns 38-41, so
neighbouring rooms line up; stairs join the regions.

| Region | Rooms | Gate to the next |
|---|---|---|
| The Drowned Temple | Drowned Hall, Flooded Cloister, Shrine of the Keeper, Iron Gate | Iron Key opens the gate |
| The Ossuary | Bone Stair, Hall of Tombs, Charnel Way, Colossus Crypt, Sealed Stair | beat the Bone Colossus for the Glimmer Lantern; its light finds the cracked false wall |
| The Crystal Caverns | Glittering Descent, Prism Grotto, Mushroom Hollow, River Crossing | the Moonsilver Blade cuts the singing crystal barrier |
| The Ember Halls | Ash Stair, Magma Bridge, Forge of the Vaunar, Fissure Walk | the Ember Ring lets you cross the burning rock |
| The Heart of the Deep | Threshold, Hall of Echoes, Heart of the Deep | beat the Hollow King, touch the Heart: the ending |

`tools/gen.py` compiles the world. It auto-tiles every room with the
region's own art (`art.py`, `art2.py`), casts its static lights offline (5
tints: warm, cool, magic, lava, green), packs the PCG and tables per region,
and checks the whole world: exits match, every room is reachable, and the
item chain can be completed (`validate`).

### Memory at run time
* Upper block: 8000-99FF engine code; **9A00-B5FF the current region's
  tables** (tile glyphs per light variant, banks, flags, classes, light
  ramps, animation list and frames); **B600-BEFF the current room's
  record** (objects, spawns, groups, cyclers, ambience lists, names,
  messages); BF00 entities.
* Lower home block: game logic 0600-33FF; maps 3400-7BFF.

### Expanded RAM
| Block | Contents |
|---|---|
| 8 | GFX: sprites and font |
| 9 / 12 | ray-trees for the plain lantern / the Glimmer Lantern (longer beam) |
| 10 | title illustration |
| 11, 26, 27 | sampled speech (title, the hall's warning, the five region names, the Hollow King, the ending) |
| 13 | explored cells of every room (one bit per cell) |
| 16 + 2n | region n: 14 PCG banks of tiles + its tables |
| 17 + 2n | region n: its rooms, PackBits-packed (about 2K each) |

Changing room: the explored bits are saved, the room is unpacked from its
bank, FLAGS are derived from the tiles, objects already opened are
re-applied, the explored cells are drawn as remembered, foes spawn, and the
static lights sweep in from where you stand. A new region also reloads 14
PCG banks and the tables, starts the region's music and speaks its name.

### Objects and progression
Chests, tablets, gates (several bars share one state bit), cracked walls,
crystal barriers, pedestals (guarded until the boss falls), stairs, bosses
and the Heart. Each room keeps 32 state bits, so what you opened or beat
stays that way. CONTINUE (RAM checkpoint at every room entry) returns you
there after death or ESC while the machine stays on.

### Foes and bosses
Bats, skeleton wardens, ghosts (drift through the dark), spiders (fast),
slimes (slow and tough), imps (fly over lava), shades (the Unlight: they
will not stand in the lantern light). The Bone Colossus and the Hollow King
are PCG set pieces: their cells take sword and fire-bolt hits; they hurl
bolts of unlight and raise servants. When they fall they crumble into
rubble tiles.

### Journal (M)
A map of the visited rooms of the current region (the room you are in is
highlighted) and what you carry.

### Title music: a three-voice player
The title tune (`tools/tmusic.py`, an original tune in E minor) plays on a
new three-voice beeper player in `src/title.asm`. Three voices (16-bit
phase accumulators, each a narrow pulse: 1/8, 3/16 and 1/4 of its period)
are OR-ed into a single speaker write per pass of a loop of exactly 176
T-states, so the speaker only moves at the voices' own pulse edges: thin,
clean, with no time-slicing hiss. Every 64 passes (2.75 ms) a
step gates the notes (they stay separate), drops the kick drum's pitch on
the bass voice, and throws the chord voice about at random for the snare.
So that the tune never stops, each step also does one small piece of the
title screen's work: one key of the menu keys (every other step), one
flame cell, four cells of the breathing glow, or the glint. Between
sixteenth-note rows the player is silent for only about 0.5 ms. The tune is
stored in the TITLE bank (11 bytes per row).

In the game the one-voice engine stays: the lighting needs the CPU, and the
three-voice loop cannot share it.

### Monochrome mode
At boot the game asks which monitor is attached (C colour, M monochrome;
RETURN means colour). A mono monitor shows a character's pixels whatever
its colour, so the colour ramps' brightness steps vanish on it. In mono mode
`region_load` replaces the region's light ramps (RAMPTAB, 2K) with a second
set compiled by `tools/gen.py` and stored after the region tables in each
region's bank (MONO_RAMPS, 5400h): light is told by the glyph variant alone.
The lantern's beam runs full pattern, two-thirds, one-third; other light
(crystals, lava, water, glows) is never full, so the beam stays the
brightest thing. The colours are kept, so a colour monitor still looks
right. In good light (level 4 and up, `MONO_LIT`) sprites are drawn from
inverted copies (PCG slot + 64 in the sprite bank, built by `build_gfx`),
so the bearer, foes and pickups are solid blocks that cannot vanish into a
patterned floor; in the faint fringe of the light they stay plain outlines,
half-seen. Level 4 is above the flame flicker (which only dims levels 1-3),
so a creature never blinks between the two. The engine cost is one
extra 2K bank copy on entering a region and one flag test per entity cell.

### Lives
Three. A fall wakes the bearer at the start of the current region
(`REGION_START` from `tools/gen.py`: the first room's door or stair
arrival), keeping items and every room's state; progression is
item-gated and rooms remember, so a lost life costs only the walk back.
With none left, the title returns; CONTINUE resumes at the region start
with three more. Lives are part of the saved journey.

### Speech
The sampled lines play at one bit every 42 T-states (80.4 kHz, up from
52.7 kHz), which pushes the 1-bit stream's noise further above the voice:
about 7 dB less noise in the 5-15 kHz band where it is heard as hiss. In
the pauses the speaker is simply left off.

### Attract tour
Leave the title alone for about 30 seconds (with no journey in memory) and
the demo plays: the Lanternless Way into the Drowned Hall, then a scripted
clip in each region in turn (the Bone Colossus fight, the Prism Grotto, the
Magma Bridge, the Forge of the Vaunar, the Hollow King's hall), about a
minute in all, then back to the title. The clips run through the normal
game (`src/demo.asm`: room, door, facing, items, and a list of key
presses); the bearer cannot be hurt in the demo, and any key ends it.

### Saving to disk
CP/M is gone once the game owns the machine, so `src/disk.asm` drives the
WD2793 itself, using exactly the commands, ports and timing of the Microbee
CP/M BIOS on the disk (found by disassembling it in the model): port 48h =
drive | side<<2 | 08h, read sector 88h, write sector A8h, seek 1Ch, restore
0Bh, DRQ/INTRQ on port 48h bit 7, ten retries. The journey goes into
SAVE.DAT, always the first file on the disk (blocks 1-2, sector list from
`tools/savemap.py`). The game first reads the file's first sector and only
writes if it carries the file's signature, so a wrong disk or drive can
never be written to. Sector 0 holds the journey (items, hearts, gold,
checkpoint room and door, every room's 32 state bits and visited flag, a
checksum); sectors 1-10 hold every room's explored cells. The model's disk
controller was extended to accept writes (and write protection) to test
it end to end: save, then a fresh machine boots the saved disk and
CONTINUE restores the journey.

### Measured in the model
A relight after a step costs about 4-5 frames in the large open rooms (5-6
with the Glimmer Lantern's longer beam), less in corridors.
