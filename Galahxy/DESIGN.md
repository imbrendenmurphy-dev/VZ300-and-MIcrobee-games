# GALAHXY: design and technical notes

## The idea

A bright, silly, Parodius / Fantasy Zone-style shooter. Each stage is a themed world with its own
joke, its own mechanic, a midboss and a big boss whose entrance is funny for a second and then
dangerous. The cast is absurd (a galah, a teapot, a toaster), the enemies are toys and food, and
the scenery joins in.

Two systems for powering up, both lifted in spirit from the two inspirations:

- **Parodius**: PAV capsules move a cursor along a power bar, and you choose when to cash in.
- **Fantasy Zone**: enemies drop coins, and a floating SHOP balloon lets you spend them between
  fights. Coins are saved across stages, so you can bank for an extra life.

### Palettes: alternating, like Fantasy Zone's changing worlds

The 6847 has two mode-1 palettes. **CSS0** (green, yellow, blue, red) is the most readable on
composite, so it is the default and is used for the title and every other stage. **CSS1** (buff,
cyan, magenta, orange) gives a pastel look, but it is harder to read over composite, so it is
kept for alternate stages. Each stage pack sets its own palette in `STG_INIT` (`latchv`). The
common sprites (cast, shots, bullets, pickups) are drawn so they read in both palettes. For
example, the player has a one-pixel outline, and enemy bullets are a ring around a core, so they
show against any background.

## The full game

Six stages, alternating palettes: 1 PARTY PLANET (CSS0), 2 BATH-TIME NEBULA (CSS1), 3 TOY BOX
TOWERS (CSS0), 4 SHERBET SEA (CSS1), 5 BACKYARD BLITZ (CSS0), 6 THE GALAH GALAXY (CSS1). The
README has the table of jokes, secrets and bosses.

**Packs.** The resident program (`GALAHXY.VZ` + `GLXCOM.DAT`) holds the engine, the cast, the
shop and a stage toolkit (`boss.asm`). Everything else is an 11K pack loaded into $B800-$E3FF:

- `GLXS0.DAT` is the front end: title, cast select, high scores, name entry and the ending.
- `GLXS1.DAT` to `GLXS6.DAT` are the stages: scenery, sprites, tunes, enemy type table,
  timeline, and the midboss and boss scripts.

A pack starts with a jump table (init, per-frame, special objects, hit, kill, segment, draw),
so the engine never needs to know which stage is loaded. The build assembles the program once
per pack and checks the resident code comes out byte-identical every time.

**Stage toolkit.** A stage is mostly data. The timeline spawns formations at scroll columns.
The segment table strings ground maps together (with forks and loops for boss arenas). A boss
is a definition (HP, entry style, messages, phase thresholds) plus one script per phase, a list
of timed actions: show a frame, flash (the tell), lob, fan of aimed shots, shoot out an arm,
rain from above, spawn a helper, line up with the player. Only stage-specific tricks (geysers,
meteors, block walls, secrets) need code.

## Hardware facts this is built on

These all come from tests on your machine (BENCH, RASTEST, BIX, XVTEST, Graves 'n' Gargoyles,
VZ-DECK) or from the MAME `sdloader` model they matched:

- **BennVenn mapper, port $37:** bit 0 = SRAM (not the DOS ROM) at $4000-$67FF, bit 1 = low bank 1
  or 3, bit 2 = the upper 18K ($B800-$FFFF) bank 0 or 1. Only two separate banks each way.
- **The DOS** runs from SRAM in mapping 1 and needs its RAM at $FA00+ in upper bank 0. File calls
  are $5F00/$5F03/$5F09. They are made exactly the way Graves 'n' Gargoyles does (sector buffer
  $F800, 2.5K stack at $F000 in upper bank 0, interrupts off afterwards).
- **Video:** mode 1, 128x64, 4 colours, 2K at $7000. Writing video RAM during the picture is the
  same speed as RAM and leaves no snow. A field is 70,630 T-states over 312 lines.
- **Input:** keyboard matrix at $68xx (bit 0 = the last key of each row). The joystick reads
  directions on $2C and fire/arm on $2E/$2D, and is detected automatically.
- **Sound:** the 1-bit speaker on the latch at $6800 (bits 0 and 5).

## Memory map

| Range | Mapping 7 (game) | Contents |
|---|---|---|
| $4000-$51FF | SRAM low bank 3 | ground band rings (4 pre-shifted copies, 64 columns) |
| $5200-$5DFF | SRAM low bank 3 | skyline band rings |
| $5E00-$67BF | SRAM low bank 3 | **GLXCOM.DAT**: font, colour tables, sound engine data, shop text, some sprites |
| $67C0-$67FF | SRAM low bank 3 | high-score table (kept until power-off) |
| $7000-$77FF | video RAM | |
| $7C00-$7D7F | main RAM | IM2 table and vector |
| $7D80-$7FFF | main RAM | stack |
| $8000-$AB9F | main RAM | **GALAHXY.VZ**: the engine, game flow, shop |
| $ABA0-$AFFF | main RAM | variables and object tables |
| $B000-$B7FF | main RAM | back buffer 0 (also the SD bounce buffer) |
| $B800-$E3FF | SRAM upper bank 1 | **GLXSn.DAT**: the front end (pack 0) or the current stage (header and jump table, sprites, types, code, timeline, scenery) |
| $E400-$F7FF | SRAM upper bank 1 | **GLXCOM.DAT**: common sprites, the stage toolkit and boss engine |
| $F800-$FFFF | SRAM upper bank 1 | back buffer 1 |

Low bank 1 (the DOS) and upper bank 0 (DOS RAM and stack) are left untouched, so the DOS stays
usable for loading the next stage between stages.

**What stays resident:** the engine, the common sprites, the boss engine, sound and the high
scores. **What is banked:** the front end, or a stage's art, enemies, timeline and bosses (11K).
**What loads between stages:** the next `GLXSn.DAT`, behind a LOADING card. The `.VZ` checks the
SRAM is there before anything else.

Space is the tight resource. Main RAM has about 480 bytes spare and the common area about 860
high and 680 low. The stage packs have between 1K and 3.6K spare each. Moving the front end out
of the resident code into pack 0 is what made room for the boss engine.

## Frame budget: what was measured

The game runs at a target **25 frames a second** (two fields a frame). The busiest scene is the
KING WOBBLE fight with the autopilot firing all the time: about 20 sprites, a dozen shots, enemy
bullets, two scrolling bands, collisions and music all at once.

Measured in the emulator (T-state accurate, 70,630 T a field):

| Scene | 2 fields (25 fps) | 3 fields | 4+ fields |
|---|---|---|---|
| Whole stage 1 (autopilot) | 76% | 15% | 3% |
| Boss fight | 80% | 12% | 2% |

So the game holds 25 fps most of the time and dips to 16.7 fps for moments in the busiest spots.
Input is read every frame, and the game logic runs once per drawn frame, so a dip slows the game
slightly (as in the arcade) instead of skipping, and the controls never lag.

Where the time goes in the boss fight: the sprite blitter ~24%, the screen copy interrupt ~17%,
scrolling-band copies ~14%, collisions ~8%, the rest spread thin.

What got it there from the first build (which mostly ran at 16.7 fps):

1. **Double buffering.** Back buffer 1 in SRAM at $F800. The interrupt copies one buffer to video
   RAM while the game draws into the other, so drawing never waits for the copy.
2. **The power bar is drawn straight into video RAM** only when it changes, and the copy stops at
   row 56. That saves about 6K T a frame.
3. **A fast blitter path** for sprites wholly on screen (most of them). The source runs on
   contiguously under the stack pointer, the phase offset is precomputed, and the clipping path is
   only used at the edges. This cut the per-sprite setup from about 1,000 to about 400 T.
4. **Messages are drawn once** into a buffer and then copied. Text colours come from lookup
   tables. The HUD is redrawn at most every fourth frame, and boss damage only updates the bar.

**When something has to give,** the order is: responsiveness first (input every frame, the
player's movement and shots never skipped), then readability (bullets and the player are always
drawn, not flickered), then smoothness.

## Sound and music

The speaker plays one short blip per note at a slow, deliberate tempo during play, so the game
code gets on with things between notes. The title, select and clear tunes can be busier. Tunes:
title, cast select, stage, midboss, boss, stage clear and game over. Sound effects cover shots,
hits, kills, PAVs, coins, buying, the warning siren, tells (creak, sizzle, whirr) and the big
explosions. N toggles the music.
