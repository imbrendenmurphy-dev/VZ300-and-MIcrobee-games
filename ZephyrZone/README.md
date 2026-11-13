# ZEPHYR ZONE
### v1.0.3: five worlds, the finale, the full attract sequence · VIBED BY BPM 2026
Dick Smith VZ300 · BennVenn SD + 128K · Mode 1 (128×64, 4 colours) · all Z80

An original pseudo-3D arcade shooter in the spirit of the Sharp MZ-700 Space Harrier conversion. It has
bold, chunky, saturated artwork, a racing checkerboard plain, and creatures that grow out of the horizon.
The engine was written from scratch for the VZ300. The hero, the creatures, the boss, the logo and the
music are all new designs, drawn and composed in the MZ-700 game's style rather than copied from it.

## Running it
Copy `ZEPHYR.VZ`, `ZZCOM.DAT`, `ZZTTL.DAT`, `ZZEND.DAT` and `ZZW1.DAT` to `ZZW5.DAT` from `release/` to the **root of the SD card**, the same
place as the Dracula's Castle II files. Then load `ZEPHYR.VZ` like any other .VZ. It loads at $8000
(9.3K) and streams everything else through the BennVenn DOS:

| File | Contents | Loaded into |
|---|---|---|
| `ZZCOM.DAT` | colour-key mask tables, projection tables, the hero (18 poses), the font-70 logo, sparks and flames, shots, explosions, shadows, power-up orb, title logo, the front-end code, the quarter-square multiply table | bank 3 $4000, upper bank 0 $B800-$EF19, upper bank 1 $FC00 |
| `ZZW1.DAT` | world 1 (CHECKER PLAINS): ground-strip library and row table, its creatures and scenery at 11 sizes × 2 phases, its boss code, timeline, tunes and panorama | bank 3 $4800, upper bank 1 $B800 |
| `ZZW2.DAT` | world 2 (SUNSET DUNES), same layout | same |
| `ZZW3.DAT` | world 3 (CRYSTAL NIGHT), same layout | same |
| `ZZW4.DAT` | world 4 (NEON CITY), same layout | same |
| `ZZW5.DAT` | world 5 (MUSHROOM MARSH), same layout | same |
| `ZZTTL.DAT` | the still title picture (2K) for the attract sequence | upper bank 1 $B800 |
| `ZZEND.DAT` | the finale: its code, tune and picture | upper bank 1 $B800 / $E000 |

If the expansion is missing it says `NEEDS BENNVENN SD + 128K RAM`. If a file can't be opened it says
`CAN'T LOAD ZZ*.DAT FILES`.

## Controls
| | Keyboard | Either joystick |
|---|---|---|
| Fly up / down | Q / A | up / down |
| Left / right | O / P (or Z / X) | left / right |
| Fire (hold for a stream) | SPACE or M | FIRE or ARM |
| Pause / resume | RETURN | |
| Music on/off | N | |
| Title: difficulty | 1 Casual · 2 Arcade · 3 Expert | |
| Title: autofire on/off | A | |
| Title: starting stage (trainer) | O / P | left / right |

The joystick is detected at boot and uses the Cybernoid v1.7 port map from Redline (fire $2E/$2B, arm
$2D/$27, directions $2C/$29).

## What's new in v1.0.3
- **The split screen copy is now standard.** Tested on hardware: the snow is gone, and the tear is
  only just noticeable, now and then when Zephyr is struck down.
- **No music in the finale.** The fireworks carry the scene on their own.

## What's new in v1.0.2 (test build: split screen copy)
- **Split screen copy, to get rid of the snow.** Writing to video RAM while the 6847 is drawing the
  picture makes snow, and copying the whole frame took longer than the gap between pictures (in the
  emulator it ended about line 148 of 312 after the field interrupt). Now rows above row 40 are copied
  in one gap and rows 40-63 in the next. In the emulator each half finishes by about line 100
  (top half, 95% of the time) and line 80 (bottom half). The game carries on with the next frame as
  soon as the top half is done, and waits only before drawing again, so the frame rate drops by just
  2%. The catch: for one field in three the bottom 24 rows show the previous frame, which may show as
  a faint tear on fast moves.
- **Copies always start on an even row.** The copy moves two rows at a time, and a start on an odd
  row would run 32 bytes past the end of video RAM.
- **Fixed: the SD loader saved its mapping on the DOS stack before switching to the DOS mapping.**
  Called from code running with the world bank mapped (the picture title, the storyboard, the
  finale), that write went into the world's bank and the mapping it later restored was garbage. It
  survived so far by luck. It now keeps the mapping in main RAM and switches banks only after
  getting its own return address back.

## What's new in v1.0.1
- **Serpent bosses parade whole in the storyboard.** COILWYRM, SHARDWYRM and BOGAPEDE now pass by as
  head, four body segments and tail in one chain. Before, only the head was shown, because the body
  and tail have no names of their own. The parade code moved out of main RAM into the world modules
  (`src/gallery.inc`) to make room, which leaves main RAM with 261 bytes free.

## What's new in v1.0
- **The finale.** Beat MUSHROOM MARSH and the game loads `ZZEND.DAT`. It shows a dawn picture with
  CONGRATULATIONS over Zephyr on a golden podium, surrounded by friends from all five worlds. Fireworks
  burst across the sky (64 sparks, two rings per burst, fading yellow to red to green) to a ringing
  finale theme, while the closing lines come up one by one: WELL DONE! / THE FIVE ZONES / ARE FREE
  AGAIN / THANK YOU / ZEPHYR! / ZEPHYR ZONE / VIBED BY BPM / 2026 / NOW TRY / ROUND TWO! Fire skips to
  the end once the first few lines are up. Then round two starts at stage 1.
- **The storyboard's music now plays properly.** The storyboard never advanced the title theme, so it
  sat on one note.
- See `BLURB.md` for the tech specs and RAM use.

## What's new in v0.3.12
- **Enemy orbs are aimed at you properly.** Each orb was aimed to reach you after 110 fields, but its
  forward speed is a whole number of units per field, so it really took longer, sometimes far longer
  (from close up the speed rounded down to 1). It reached your spot early and sailed past, so sitting
  still was safe. The forward speed is now rounded up and the aim worked out over the orb's real
  flight time, so orbs arrive where you were when they were fired. Keep moving!
- **Every formation shoots.** Waves that never fired now fire every 4 seconds or so each, and bosses
  keep their own rates. At most six orbs are in the air at once. In the emulator, a hero who sat still
  was hit regularly, both by the waves in stage 1 and by the SUN TOTEM.

## What's new in v0.3.11
- **Fixed: Zephyr breaking up at the right of the screen.** The blitter steps along each sprite row
  with `INC E`. When a sprite reached the last column on one of the rows that ends a 256-byte page
  (every eighth row), the carry into D was lost and the rest of the sprite was drawn eight rows higher.
  Zephyr sits against the right edge whenever you fly right, so he flickered and broke up there, and
  other creatures and scenery could glitch the same way. The end of each row now puts the carry back.

## What's new in v0.3.10
- **The title theme gets all the speaker time there is.** Each note now sounds right up to the next
  one, with no gaps. The title and the storyboard run one field slower (12.5 frames a second instead
  of 16.7), which gives the speaker about a quarter more time. In the emulator the theme now sounds in
  63% of 20 ms slices, up from 53%. The rest is the time spent drawing the live landscape, when
  nothing can play. Play itself is unchanged at 16.7 frames a second.

## What's new in v0.3.9
- **Enemy orbs fly again.** A creature only fires when enough object slots are free for your bolts,
  and with whole formations now staying on screen the slots ran out, so nothing fired. There are now
  36 slots instead of 28, and only 4 are held back.
- **No more creatures out of reach.** Zephyr can only fly 150 units either side of the middle, but a
  formation spawned while he was off to one side could settle further out than that (the CACTOIDs
  bunched up on the left in SUNSET DUNES). Creatures now always stay within 140 of the middle.
- **Title theme notes last longer** than the old fixed short blip (from v0.3.10, right up to the next note).

## What's new in v0.3.8
- **No in-game music** (since v0.3.7): stages and bosses play with the effects alone.
- **A fresh title theme, written for the engine.** The speaker only sounds while the screen copy runs
  and while a frame waits for the next field, never during the game logic. So every note is a short
  "pluck": a bass note on the beat with the tune dancing above it, so one voice implies two. It's
  eight bars in A minor that turn to E major at the end, and it plays behind the title and the
  storyboard. The picture title stays silent.
- **Fixed: wrong pitches.** Since v0.2 the screen-copy interrupt has played one sample per two rows
  (3,233 a second), but the note table still assumed one per row, so every tune came out nearly an
  octave flat. The note table now uses the real rate. The idle wait in `present()` now plays samples
  too, paced to the same rate, so notes and effects sound for more of each frame at no cost.
  The effects keep exactly the sound they had.

## What's new in v0.3.6
- **Fixed the v0.3.4 and v0.3.5 downloads.** They paired a new `ZEPHYR.VZ` with `.DAT` files from an
  earlier build. The front end in `ZZCOM.DAT` and the world modules call into the main program at
  fixed addresses, so they must all come from the same build. The mismatch gave a garbled screen and
  a crash.
- **A safety check**: every `.DAT` file now carries the id of the build it came from. If one doesn't
  match `ZEPHYR.VZ`, the game stops with `ZZ*.DAT FILES DON'T MATCH` instead of crashing. **Always copy
  all nine files together.**

## What's new in v0.3.5
- **The storyboard now follows every attract demo** (after the picture title), showing the next world's
  scenery, creatures and boss each time: Checker Plains, Sunset Dunes, Crystal Night, Neon City,
  Mushroom Marsh, then round again.

## What's new in v0.3.4
- **Fixed: waves stalling.** Creatures could decide they had reached their hover depth while still
  out at the horizon (past 2048 units, z/8 no longer fits in a byte and wrapped round). They sat there,
  tiny and out of reach, and counted towards the "wait for this wave" limit, so no new waves came. Now
  they hover only once they're really close, settle exactly at their depth, and anything that ends up
  level with you or behind you (out of your line of fire) leaves the stage.

## What's new in v0.3.3
- **A proper "got him!" sound.** Shooting down a creature gives a bright crack, a burst of noise, and a
  falling whistle as it drops in flames (about 1/6 second). A hit that doesn't kill (tough creatures,
  scenery) gives a sharp knock. The blaster's own zap no longer cuts these short when you hold fire.

## What's new in v0.3.2
- **Formations stay until you shoot them down**, then drop in flames. The next wave waits while nine or
  more creatures are still up there, so the stage moves on as you clear it.
- **SUN TOTEM fixed**: enemy orbs could fill every object slot, so your bolts had nowhere to go. That's
  why it looked as if it stopped taking hits, and its orbs couldn't spawn either. Now there are never
  more than six enemy orbs at once, and slots are always left free for your bolts. The face also flies
  higher (and MEGAMECH's a little), so you can hit it from normal flying height. Its pods fire a little
  less often.
- **Clearer mode choice** on the title: the line under the logo reads MODE: CASUAL / ARCADE / EXPERT,
  then PUSH UP: MODE. Pushing up (joystick or Q) steps through the modes, and 1/2/3 still work.
- **Picture title**: the GUNMECH is bigger and Zephyr smaller, a little figure perched on its shoulder.

- **Formations really hold station now.** In v0.2 the hover set-up was missing, so creatures flew
  straight through. Now each formation flies in (at three-quarters of its old speed), stops 300-700
  units in front of you and weaves there for about five seconds, firing slow orbs. Then it drifts past.
  The waves are spaced 35% further apart to suit.
- **Every piece of scenery can be shot**, as long as your shot is anywhere up its height (or a little
  above):
  - trees, saguaros, spires, towers and toadstools: 3 hits, 300 points;
  - columns, obelisks, gem rocks, neon signs and moss stones: 4 hits, 500 points;
  - small things: 1 hit, 200 points.

  In v0.2 only shots at ground level counted, so trees and poles never seemed to take a hit.
- **No scenery during boss fights.**
- **Fixed: the boss's head vanishing** while its body hung in the air. The spark effect added in v0.2
  overwrote the register holding your bolt, so the game removed the boss's head instead of the bolt.
- **Fixed: STAGE n and the world and boss names** sometimes showed blank or as the wrong text (an
  assembler pass-order slip in the message table).
- **"GET READY!"**: after "AAARGH!", Zephyr gets up running along the ground and shouts "GET READY!"
  (a second sampled phrase, formant-synthesised and played the same warble-free way) as control comes
  back.
- **Title text**: the line under the logo now cycles PRESS FIRE / TO GET READY / ARCADE MODE (or CASUAL
  or EXPERT). A changed setting stays up for a couple of seconds.
- **Trainer**: once you have reached a stage in this session, left/right on the title (or O/P) selects
  FROM STAGE n, and the next game starts there. The attract demo always plays stage 1.
- **Picture title** (after each attract demo, silent): a cheerful scene in the spirit of the arcade
  title. A chibi Zephyr sits on a GUNMECH's shoulder, waving, beside a big SNAILOPS, a BLOBBIT and a
  lolly tree. The one-line ZEPHYR ZONE logo rolls in from the right and settles over the sky, and
  VIBED BY BPM 2026 runs along the bottom.
- **Storyboard**: after every attract demo (every third one, until v0.3.5), one world's scenery, creatures and boss
  parade slowly sideways across its stilled landscape, each named as it reaches the middle. Each
  storyboard shows the next world in turn.
- **A VZ cast for the MZ-700 one** (original designs, not copies of Sega's characters):

  | MZ-700 / arcade | Zephyr Zone |
  |---|---|
  | three-legged robot (title screen) | **GUNMECH**, a neo-city walker with an arm cannon (big, 6 hits, fires) |
  | one-eyed woolly mammoth | **SNAILOPS**, a huge cyclops snail (big, 6 hits) |
  | floating stone heads | **STONEFACE**, carved heads with glowing eyes that spit orbs |
  | jet fighters | **DARTJET** delta fighters |
  | spinning formation craft | SPINDLE, PRISM, SUNDISC |
  | round flying creatures | BLOBBIT, GLOWMOTH, COPSAUCER, BUZZWING (a giant dragonfly) |
  | giant mushrooms | **TOADSTOOLs** and puffballs |
  | stone columns | candy columns, obelisks, moss stones, neon signs |
  | trees and bushes | lolly trees, bushes, saguaros, rocks, glowcaps |
  | serpent dragons | COILWYRM, SHARDWYRM, **BOGAPEDE** (a twelve-segment centipede) |
  | stone-head boss | SUN TOTEM and **MEGAMECH**, faces ringed by orbiting pods |

- **Two more worlds**:
  - **NEON CITY** (CSS1): an orange dusk over a lit skyline, a cyan and magenta tile road with buff
    seams, and skyscrapers, neon signs and barriers. DARTJETs, COPSAUCERs and stomping GUNMECHs. Boss:
    **MEGAMECH**, a colossal horned robot head with six gun pods wheeling round it.
  - **MUSHROOM MARSH**: a yellow sky over toadstool silhouettes, and a green and blue plain of giant
    toadstools, moss stones and puffballs. STONEFACEs, BUZZWINGs and SNAILOPS. Boss: **BOGAPEDE**.

  Each has its own stage and boss tunes. Clearing MUSHROOM MARSH starts round 2.

## What's new in v0.2
Changes made after the first run on real hardware:
- **Readable big text**: the title, STAGE, world and boss names, WARNING!, GAME OVER and the menu line
  use a new '70s retro-future face with the heavy lower-left leg. It has a solid outline, so it stands
  clear of the checkerboard. The logo is ZEPHYR over ZONE in the same face.
- **Formations you can see and shoot**: creatures fly in, *hold station* in their formation in front of
  you for a few seconds, and then charge. Two new set pieces have been added, CROSS (pairs sweeping in
  from both sides through each other) and SPIRAL (a tight ring that opens out as it turns). The set
  pieces are now LINE, SNAKE, RING, HOP, SWOOP, DIVE, CROSS and SPIRAL, and each world's timeline
  sequences them in the MZ-700 manner.
- **Shot down in flames**: a creature you hit tumbles to the ground on fire and burns there for a
  moment.
- **Slow orbs**: enemy shots are big, slow orbs (about 2 seconds to reach you) so you can dodge them.
- **Shootable scenery**, as in the MZ-700 game. The second obstacle type (candy column, obelisk, gem
  rock) takes 4 hits for 500 points. Small scenery (bushes, rocks, glowcaps) pops with one shot for 200.
  The tall first obstacle (tree, saguaro, crystal spire) is solid, so dodge it.
- **Boss feedback**: every hit flashes the boss white-hot, knocks it back, throws sparks and makes a
  thud. A boss life bar sits in the HUD.
- **Struck down**: the ground stops dead, Zephyr is thrown back and falls to the ground under gravity
  with an "AAARGH!". That is a 1-bit sampled voice played with the CPU to itself, so it doesn't warble.
  He lands with a thud and a puff of dust, lies there a moment, then gets back up.
- **Less snow**: the field interrupt now plays one sound sample per two copied rows, which shortens the
  copy. Some snow at the top of the play area may remain on real hardware (see below).
- **Two new worlds**, each loaded from its own file when you clear the one before:
  - **SUNSET DUNES** (CSS1 palette): a cyan sky, a sinking striped sun, pyramids, and sand with
    staggered ripples. Creatures: SANDRAY (a gliding manta), SUNDISC (a spinning sun-faced saucer that
    shoots) and CACTOID (a stomping one-eyed cactus). Scenery: saguaros, carved obelisks and rocks.
    Boss: **SUN TOTEM**, a great carved face with a flaming crown. Six fire pods wheel round it on a
    tilted ring that breathes in and out and lob orbs at you. The pods are armoured, so hit the face.
  - **CRYSTAL NIGHT**: a red night sky with a pale moon over jagged crystal ranges, and a seamed
    crystal-tile floor. Creatures: GLOWMOTH, PRISM (a spinning shard that shoots) and JELLYBELL (a
    bobbing jellyfish). Scenery: crystal spires, gem rocks and glowing mushrooms. Boss: **SHARDWYRM**, a
    ten-segment crystal serpent, faster and wider-ranging than COILWYRM.
  - Each world has its own stage tune and boss tune. Clearing CRYSTAL NIGHT starts round 2 back on the
    Checker Plains, faster.

## Also in the game (from v0.1)
- **Title screen** with the live world rolling behind the logo, a flying hero, the high score, a
  difficulty and PRESS FIRE prompt, a fanfare, and an **attract demo** (the autopilot plays the real game)
  after about 25 seconds.
- **The perspective ground**: a 44-row checkerboard with tiles that narrow towards the horizon. A
  stripe-and-dither haze band (rows 1-10) stops the far rows shimmering. The ground moves with the hero:
  sideways with the camera, and the horizon dips as he climbs.
- **Panorama**: rolling hills, round trees and candy towers on a 256-pixel wrap. They scroll at a quarter
  of the camera's speed for parallax.
- **Scenery** growing out of the horizon at 11 precomputed sizes: lolly trees, striped candy columns
  (obstacles) and bushes.
- **ZEPHYR**, the hero: a bubble helmet, a red scarf in the wind and a twin-nozzle jet-pack, with 15
  poses (flying with flame flicker, two levels of banking each way, climbing, diving, a 4-frame run on the
  ground, firing, thrown back when hit, and a cheer). He has a ground shadow and flickers while invulnerable.
- **Creatures**: BLOBBIT (a fluffy one-eyed puff with flapping wings), SPINDLE (a spinning-top drone)
  and HOPCAP (a bouncing toadstool with a shadow). They fly in six formation patterns: line, snake, ring,
  hop, swoop (they fly out past you, turn round and come back) and dive. Some aim fireballs at you.
- **Weapons**: single, twin and triple-spread blasters. Shooting down a whole formation of three or more
  drops a power-up orb. A maxed weapon heals you and gives a one-hit **shield** instead. A hit costs one
  weapon level, never the ordinary blaster.
- **Boss (world 1): COILWYRM**, a horned sky serpent. Its head weaves a figure-of-eight in front of you, and eight
  armoured body segments and a tail follow its recorded path (shots clink off them). It opens its jaw,
  then spits a fan of three fireballs. The segments blow up one by one when it dies. It has its own
  tune, a WARNING lead-in, and a STAGE CLEAR celebration. Clearing the stage starts round 2, which is
  faster.
- **Forgiving play**: a health bar (6 hits on Casual, 4 on Arcade, 3 on Expert) on top of 3 lives,
  invulnerability after a hit, continues that carry on where you are, generous hit boxes for your shots
  and smaller ones for theirs.
- **HUD**: score, weapon level, shield, lives and health segments, plus big centred messages with a drop
  shadow.
- **Sound**: blaster, hit, explosion (noise), clink, fireball spit, hurt, death, power-up, warning siren,
  start and stage-clear jingles, and slow "blip" music (Checker Plains theme, boss theme, title fanfare,
  game over). All the tunes are original.

## The MZ-700 game: what was taken and what was replaced
I looked through the attached tape image (`SPACEHARRIER`, loaded at $1200, 43K):
- **Graphics**: the sprites are colour-attribute data. Each byte is two stacked pixels (foreground over
  background, 8 colours), drawn in 11-byte-wide rows. That gives the game its look: chunky, saturated
  primaries, bold dark outlines, horizontal-stripe shading, bushy trees, striped columns, round
  orb-like enemies and odd creatures. That look is what Zephyr Zone keeps. Its own sprites are drawn as
  posable vector puppets (`tools/draw.py`, `hero.py`, `creatures.py`) with automatic bold outlines.
  Each size is rendered at its own resolution, so small sprites stay clean instead of being shrunk
  pixel art.
- **Structure**: there are 18 stages with two bonus stages, a timeline of enemy waves, a boss per stage,
  MML-style music data, and a character-cell playfield. Zephyr Zone keeps the timeline-and-boss shape,
  so stages are data in `src/play.asm`.
- **Replaced**: the character-cell renderer, the block scaling and the cell-sized movement. Here
  everything is placed with sub-pixel projection, a 2-pixel phase and 11 scale levels, on a true
  perspective plane.

## Engine
- **Display**: the whole scene is drawn into a 2K back buffer at $B000. The field interrupt (IM 2, table
  $7C00) copies it to video RAM ahead of the beam (the BIX / Redline technique). It starts from the
  highest row that changed this frame or last, and plays a sound sample per row. Frames are locked to 3
  fields (16.7 per second). Measured in the emulator during busy play, 75% of frames finish inside 3
  fields and the rest take 4. Motion is scaled by the fields elapsed, so speed doesn't change.
- **Ground** (`ground.asm`, `tools/tables.py`): each row d below the horizon copies 32 bytes out of a
  precomputed strip, at an offset
  `o = (floor(d · frac(camx/64)) + K_d) mod d`, plus half a period when bit 6 of `(Z_d + scroll)`
  is set (the checker's depth parity). The strips come in 4 pre-shifted versions, so every pixel offset
  is a single copy. That is 7K of strips for 44 rows, about 600 T-states per row.
- **Projection** (`obj.asm`): 1/z is tabled as an 8-bit mantissa and a shift per z bucket. A
  quarter-square multiply (1K table in upper bank 1) gives sx, sy and the ground row with about 1%
  error. Objects that are near and wide are culled before the multiply.
- **Sprites** (`sprite.asm`): colour-key records (one byte per 4 pixels, with colour 0 or colour 2 as
  transparent) halve the memory against mask+data. Two phases give 2-pixel placement. The blitter reads
  with POP under DI, is unrolled, clips on all sides, and skips the source-remainder step for unclipped
  sprites.
- **Depth order**: projection files each visible object into one of 56 depth buckets (16 units apart
  near the hero, 64 far away). The buckets are drawn far to near, with each shadow drawn just before its
  object.
- **Front end**: the title, menus, messages, HUD and game flow live in upper bank 0 ($B800). Main code
  calls them with `call to_fe : dw routine`, and they call back with `call fecall : dw routine`, so the
  mapping is always right.

### Memory map
| Range | Contents |
|---|---|
| $4000-$47FF bank 3 | colour-key tables, projection tables (x/y mantissa, shift, level, ground row) |
| $4800-$66AB bank 3 | ground row table + strip library (per world) |
| $66AC-$67FF bank 3 | "AAARGH!" sample |
| $7000-$77FF | video RAM (rows 0-5 = HUD, drawn directly) |
| $7800-$7BFF | left alone (ROM/DOS) |
| $7C00-$7D7F | IM 2 table + vector |
| $7D80-$7FFF | stack |
| $8000-$A6F3 | main code incl. the "GET READY!" sample (12 bytes free) |
| $A700-$AEE2 | variables, 36 objects (40 bytes each), boss path history |
| $B000-$B7FF | back buffer (also the SD bounce buffer) |
| upper 0 $B800-$C310 | front end code · $C400-$C7D2 message renderer |
| upper 0 $C800-$EEA2 | common sprites |
| upper 0 $F000-$F7FF | stack for DOS calls (2K) · $F800 sector buffer · $FA00+ DOS |
| upper 1 $B800-$FBFF | world: header, sprite directory, world module (boss code, timeline, tunes, names) at $B848, sprites, panorama |
| upper 1 $FC00-$FFFF | quarter-square table |

Banking (port $37): the DOS's own mapping is used only during DOS calls. Mapping 3 (bank 3 + upper 0) is
the front end and common sprites; mapping 7 (bank 3 + upper 1) is the world. SD loading uses the
13 Ghosts / Dracula's Castle II calls ($5F00 / $5F03 / $5F09). Interrupts are off and IM 1 is set during
DOS calls, with DI after each one, and the DOS gets a 2K stack. Each sector bounces through main RAM to
its chunk's mapping (file format: `db map, dw dest, dw length, data…`, `map 0` ends).

## Verification
v0.1 has run on a real VZ300 (the user's report: speed, perspective, sound, music and joystick all good,
with a little snow below the HUD). v0.2's three worlds, sound and joystick were played on the real
machine. v0.3 has **only been run in the emulator so far**.
- Headless emulator `emu/vzemu` (Redline's z80.c core with the BennVenn bank and DOS model, IM 2 at
  field sync, using your RASTEST timings).
- Scripted runs: title, start, stage 1 waves, power-ups, deaths and continue, the boss fight through to
  STAGE CLEAR.
- v0.3: a soak through all five worlds and their bosses (lives topped up, random input, the DOS
  scribbling below its stack, random power-on RAM). Also tested: three full attract cycles including
  the picture title and the storyboard; a 1,500-frame COILWYRM fight confirming the head stays and its
  hit points count down; scenery taking hits; the trainer selecting stage 3 and loading it; and
  "GET READY!" after a death.
- v0.2: a scripted run through all three worlds and both new bosses (with stage clear and world loading),
  a death sequence, and a 15,000-frame random soak across worlds 2 and 3, their bosses and the wrap back to
  world 1, all with no crash. The DOS-stack-scribble and random-RAM run passes too.
- Soak tests: 24,000 frames of random input (title, attract, games, game over, continues) with no crash,
  no stray stack, and no execution outside code. The same run passes with the DOS scribbling 1.5K below
  its stack, clobbering $7AF8-$7BFF on every call, and random power-on RAM.
- Bugs found and fixed by these runs:
  - an assembler-operator slip (SQ page), a lost `xor a` in the blitter set-up, and IX clobbered by
    the blitter;
  - IY lost when a power-up spawned, a frame index past a sprite's set, the boss failing to spawn when
    every object slot was in use, and an off-by-two self-modified jump.

**Still to check on real hardware**: whether "GET READY!" is intelligible, the frame rate with two
GUNMECHs or SNAILOPS on screen, NEON CITY's colours, and the picture title. From v0.2: whether the
remaining snow is acceptable, how "AAARGH!" sounds
through the VZ speaker, the CSS1 colours of SUNSET DUNES on a real TV, and loading worlds 2 and 3 from
the SD card.

## Building
```
gcc -O2 -o emu/vzemu emu/vzemu.c emu/z80.c
python3 tools/build.py            # -> build/sd/ZEPHYR.VZ, ZZCOM.DAT, ZZTTL.DAT, ZZW1-5.DAT
emu/vzemu build/sheet.scr         # scripted run with screenshots
```
Python 3 + Pillow. The assembler is `tools/zasm.py`, from Dracula's Castle II, now with REPT.

## Adding a world
A world is a `WORLDS` entry in `tools/build.py` (palette, sky, ground colours and style: `checker`,
`bands` or `grid`; panorama; nine sprite names in a fixed order), a panorama function in `tools/pano.py`,
two tunes in `tools/sound.py`, and `src/wN.asm`. That file holds the header, the boss parameters, a boss
engine (`serpent.inc` or `totem.inc`) and the timeline. The header also carries the hit radii of the three creature types and the storyboard names. Raise
`NWORLDS` in `src/defs.asm`.

## Next
Planned: more worlds (volcanic fields, an alien ocean, the final fortress), rolling boulders, a bonus
stage, high-score saving, a mode 0 colour title card, a stack-based copy to cut the remaining snow, and a
proper ending.
