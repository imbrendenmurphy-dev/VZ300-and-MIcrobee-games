# What changed from the Codex conversion, and why

Starting point: the Codex "maze-speed-test" candidate of 11 November 2026
(disk SHA256 `923976eb…`), rebuilt byte-for-byte from its source before
anything was touched. Everything below was measured on the same Premium Plus
model (3.375 MHz, 50 Hz) that Codex's own checks use. **None of it has been
run on a real Microbee yet.**

## Speed

| Measure (emulated) | Codex candidate | This build |
| --- | ---: | ---: |
| Turn on the spot, Grounds / Great Hall | 0.68 s average, up to 1.8 s on a new view | 0.09 s |
| Turn on the spot, other four areas | about 0.4 s, with the screen blanking each time | 0.09 s |
| Whole-screen redraw (entering an area, leaving a battle) | 0.24 to 1.8 s | 0.28 s |

- **The view is stamped, not composited pixel by pixel.** Codex's newer
  renderer (first two areas) merged masked pixel layers at run time, which is
  why a fresh view could take most of two seconds. The perspective is now laid
  out so every wall edge that matters sits on a character-cell boundary. A
  scene becomes a short list of block copies. Why: it is the difference between
  a game that feels sluggish and one that keeps up with the keys.
- **The screen no longer blanks on every step.** Each move was being treated
  as a change of screen, so the whole display was switched off and rebuilt.
  Now only the view is redrawn. Why: the flicker was the most visible flaw
  in the four older areas.
- **The side panel is only redrawn where it changed.** Each text row carries a
  small signature; a turn redraws the one "FACING" row instead of comparing
  the whole screen. Why: after the view was fast, this was two thirds of the
  remaining time.
- **Dead VZ work removed.** Every character printed was still being plotted in
  the VZ's 3x5 font into a buffer nobody sees. That, the unused VZ wall
  renderer and its tables are gone. Why: wasted time on every line of text,
  and the space was needed.
- **Music gaps are shorter.** The tune only plays while the game is waiting
  for the next frame, so a 1.8 s redraw was 1.8 s of silence. Redraws are now
  about three frames of work.

## Artwork

- **All six areas redrawn at the Microbee's own resolution.** Four areas
  (Library, Dungeons, Clock Tower, Dracula's Tower) were flat yellow slabs and
  outline symbols; the Grounds and Great Hall were the VZ picture enlarged.
  Every area now has its own materials: hedges and mossy graveyard stone,
  ashlar and red damask over panelling, bookshelves with individual spines,
  dripping dungeon blocks and cell bars, timber framing and brass clockwork,
  veined marble and velvet drapes. Floors and ceilings are in perspective
  (chequered tiles, carpet runners, planks, beams).
- **Doors, gates, torches, portraits, windows, stairs, candles, the clock and
  plaques are drawn on the walls again, including on side walls.** The older
  renderer only showed them head-on, so you could walk past a door without
  seeing it. Why: that is a gameplay cue, not decoration.
- **People, chests, graves and statues are proper cut-outs.** They are the
  original characters enlarged with smoothed edges and a dark keyline, and are
  merged with whatever is behind them rather than sitting in black boxes.
- **The Grounds have a night sky**: stars, a crescent moon, and the castle on
  the skyline when you face north.
- **Black is black.** The VZ had to use blue as its dark colour. Shading is now
  done with dither density on a black ground, so distance fades to darkness.
  Why: it reads as gothic rather than as a blue room, and it means the amber
  screen gets the same picture with the same shading instead of a second set
  of art.
- **Lettering fixed.** In the display alphabet D looked like O, L like C,
  A like R and I like T ("ORACULA'S", "CEVEL", "FRCING"). Those four letters
  were redrawn.
- **Panel frame** is now a gold double rule with studs.

## Housekeeping

- 69K of VZ wall and object bitmaps that the Microbee never draws were taken
  off the disk to make room for the new art. The disk is still one 819,200-byte
  DS80 image.
- One atlas per area now serves both colour and one-colour screens.
- New checks: `tools/check_maze.py` compares 789 views from the running game,
  pixel for pixel, against an independent drawing of the same scene;
  `tools/check_speed.py` times real key presses.

## Second pass (12 November 2026)

- **Title screen redrawn.** Moonrise behind the castle on its crag, bats,
  bare trees, blood running from the lettering. Why: the old one was a few
  rectangles and a moon that looked bitten. The moon is slightly flattened
  because Microbee pixels are taller than wide. Credit reads VIBED BY BPM 2026.
- **Battle rooms redrawn in the areas' own materials.** Five of the six rooms
  were one brick template recoloured solid blue, cyan, brown or magenta, and
  the bright fill fought with the monster. Each fight now happens in front of
  the wall and floor of the area you are in, with a pool of shadow behind the
  monster. Monster drawings and animation are unchanged.
- **Graveyard room redrawn too** (the bat and skeleton fights). It now matches
  the Grounds: starry sky, crescent moon, the castle on the skyline, the mossy
  wall, headstones and grass. Those two monsters always fought here, whichever
  area you met them in (changed in the fourth pass: they now fight in the
  room you are in).
- **On one-colour screens the battle room sits back.** With no colour to
  separate them, monster and wall were the same brightness. The room is now
  dimmed there so the monster stands out.
- **Story, inventory and message pages are light text on a dark leaf** with a
  gold rule, and text keeps its own colours. Why: solid yellow was harsh in
  colour, and on a one-colour screen every line of text sat in a dark bar.
- **Coming back from the map or a fight is quick.** The area's art now stays
  in memory (RAM blocks 28 and 31) instead of being unpacked again each time:
  about 0.6 s of blank screen instead of 2.3 s.
- **Music keeps time while you move.** Pitch was measured and is exactly in
  tune (E5 = 659.2 Hz), and tempo is exact standing still. While turning
  constantly the tune was running at 62% speed because drawing skipped its
  beats; it now holds 87%.
- **Checked and left alone:** gameplay, maps, monster stats and text are the
  VZ300 game, by choice. The 1984 Easter egg keeps its authentic look. The
  map page and the gallery layout did not need changes (the gallery shows the
  new rooms).

## Third pass (12 November 2026): the Groovy Ghoulies

- **All twelve monsters redrawn as cartoon characters** (`tools/ghoulies.py`),
  following the art brief: bold black ink lines, flat colour with dithered
  shading, big expressive eyes and a personality each. The bat is a round,
  furry pup with yellow eyes and scalloped wings; the skeleton grins with a
  missing tooth behind a dented shield; the ghost blushes; the gargoyle
  crouches on its plinth with glowing red eyes; the grell is a glossy eyeball
  on wriggling tentacles; the zombie has mismatched eyes, a stitched head and
  a bone poking out; the slime has eyes on stalks and a bone inside; the Ghoul
  King has a jewelled crown and ermine robes; the knight has a plumed helm
  with eyes glowing in the slit; the Bat Lord scowls under his crown; Dracula
  opens a crimson-lined cape; the bride smirks under a drifting veil. Each
  still has its idle, idle-variation and attack frames, and the ghost keeps
  its eight-pose idle animation.
- **The art is made for the Microbee's cells, not converted to them.** Each
  monster is painted cell by cell: any 8x8 cell it touches gets a black
  halo, and cells that would hold three colours keep the two that matter,
  protecting eyes, teeth and mouths. The encoder now changes almost nothing
  (0 to 14 cells per frame, down from 200 to 300), so what you see in the
  previews is what the machine shows. Dracula's and the bride's faces were
  laid out on the cell grid by hand so their eyes survive.
- **Title screen redone.** The logo sits on a dripping crimson banner, with
  the subtitle under it and the cast lined up in front: ghost, skeleton,
  Dracula, zombie and slime, drawn from the new monster art. The amber
  version used a black banner with a dotted border so the letters stayed
  readable (replaced in the fourth pass).
- **All 21 maze floor objects redrawn** (`tools/maze_objects.py`) in the same
  style, replacing the enlarged VZ sprites: chests open and shut, graves,
  bones, the stone angel, the suit of armour, the gargoyle statue, lecterns,
  the eye-orb, the bell, the workbench, the coffin, the portrait on its easel,
  both thrones, the sleeping Bat Lord, and the characters Grigor, Vesper, the
  bookseller, Kaspar behind his bars and Otto with his monocle. Each cell is
  one ink plus black, which is exactly what the run-time merge can show, so
  objects no longer tint the wall beside them. The 128 object glyph slots
  are split 80 / 30 / 18 across the three distances to fit.

## Fourth pass (13 November 2026): fast battles, fights in your room

Measured in the emulator on a one-hit skeleton fight with the keys mashed:

| Battle moment (emulated) | Before | Now |
| --- | ---: | ---: |
| Sword slash until the damage shows | 0.90 s | 0.19 s |
| Hit flash and shake | about 1.2 s | 0.47 s |
| Monster vanishing when it dies | 3.6 s | 0.54 s |
| Whole fight, encounter to back in the maze | 11.0 s | 3.8 s |

- **The battle screen is redrawn in one pass.** Codex's battle code rebuilt
  the whole 40x32 screen for every animation step, compared all 3,840 bytes
  with the previous frame, and waited for the next frame up to eight times
  along the way so the tune would keep playing. A sword stroke of five steps
  took 45 frames. Now each step recomposes only the monster's window (or just
  the cells an effect stroke touches), then writes those rows straight to the
  screen right after the frame sync. A still pose or a stroke costs one to two
  frames; a moved, flashing or dissolving monster about three. Why: you asked
  for the VZ's quick, aggressive fights back, and the waiting was the whole
  problem.
- **The VZ's bitmap scene is no longer drawn.** Every animation step still
  copied the VZ backdrop, masked the VZ monster into it, drew the VZ effect
  strokes and the VZ health bar into a buffer the Microbee never shows, and
  each battle started by rebuilding VZ sprite masks. All gone. Why: pure
  waste, and the space was needed for the new code.
- **Death is a quick ordered dissolve into the room**, eight steps on a 4x4
  pattern, instead of twelve slow random-pixel steps that redrew the whole
  screen each time. A monster you kill with one blow no longer disappears
  during its hit flash and then pops back to dissolve; it stays until it
  dissolves.
- **A hit shows the monster in negative** in colour (it used to turn the
  fill white, which did nothing to the white skeleton or ghost), and makes it
  blink on the amber screen, where colours do not show.
- **Ordinary monsters fight in the room you are standing in.** The bat,
  skeleton, ghost, zombie, slime, knight and bride now appear in front of the
  Grounds, Great Hall, Library, Dungeons, Clock Tower or Dracula's Tower,
  whichever you are in; a skeleton in the Library fights among the
  bookshelves. Bosses keep their own lairs. This works because the ghoulies
  are drawn cell-exact: every cell a monster touches holds only the monster
  and black, so its cells can be laid over any room when the battle loads
  (`tools/battle_rooms.py`). The rooms use PCG banks 0 to 4 and the monster
  banks 5 to 13. The six rooms and seven monsters take less disk than the
  fourteen baked-in fights they replace. The ghost's eight-pose float is
  composed into the room too.
- **The last room and monster stay unpacked** (RAM blocks 27 and 29), so a
  second fight in the same area loads about a quarter faster.
- **No flash back to the maze when a fight starts.** Black blinds now close
  over the maze in eight frames and the screen stays black until the battle
  is drawn. Before, the maze stayed up while the art unpacked, then showed
  scrambled for a few frames as the new character shapes arrived. Leaving a
  fight also clears to black first, instead of showing a scrambled 64-column
  screen for a fifth of a second.
- **The selected battle command has a pointer** (and yellow lettering in
  colour) instead of reverse video. In the emulator's amber mode reverse
  video did not show at all, and in colour the bold letters ran together.
- **Story pages are centred.** The text was placed at the VZ's fixed rows, so
  the last line sat on the bottom rule while the top had room to spare. The
  page now measures its text, keeps each paragraph's line spacing, closes the
  paragraph gaps a little and centres the whole block. The ending page gets
  the same treatment.
- **The amber title is its own picture.** The colour banner was simply
  swapped for black on one-colour screens, so the blood drips vanished. On
  amber the banner now glows solid with the lettering cut out of it in black
  and the drips hanging lit beneath; the bats are solid and the cast use
  clean even tones.
- **Music volume.** Press - and + (the ;+ key) anywhere to set the music
  from 1 to 4; N still turns it off and on. The setting shows on the title.
  It works the way 1-bit machines do it: each step halves the width of the
  speaker pulses, so the notes stay in tune and only get quieter. Sound
  effects stay at full strength so they still cut through. The game starts at
  3, a notch below the VZ's full swing, because the Microbee's speaker is
  louder than the VZ's piezo.
- **Smaller things:** byte fetches in the decompressor have a fast path
  (about a fifth quicker); the disk's own README now has the controls; about
  1.4K of unused VZ title and sprite code was removed to make room.
- New and rewritten checks: `tools/check_native_combat.py` composes 26
  monster-and-room pairs in both modes and compares every pose, movement,
  effect, hit flash and dissolve with an independent Python drawing;
  `tools/check_animation.py` checks the ghost's eight poses in two rooms.

## Fifth pass (13 November 2026): after the first hardware test

- **Battle effects drawn for the Microbee** (`tools/battle_fx.py`). The VZ
  drew its effects with font characters (`/` for the sword, `*` for fire,
  `+` for holy water) and flickered the panel colours for hits. Now: a
  curved white and cyan sword arc; a fireball that rises with a flame trail,
  flares and bursts into a ring of embers; holy water that falls as drops,
  then a gold cross with sparkles; three red claw rakes when you are hit;
  rising gold and white sparkles on a level up; and red streaks running down
  when the hero falls. The pixels are merged into a spare PCG bank over
  whatever is in each cell, so the monster and the room show through. The
  VZ's panel-colour flicker on hits and level ups is gone.
- **The likely monsters are preloaded.** Entering an area now also unpacks
  that area's room and the two or three monsters you can meet there (RAM
  blocks 26, 27 and 29). A fight with one of them starts after 0.36 s of
  black (0.63 s for the ghost) instead of 0.7 to 1.3 s. A one-hit skeleton
  fight, start to finish, is now 3.1 s.
- **Faster unpacking everywhere.** The decompressor reads its input through
  a 1K buffer instead of fetching byte by byte, about a quarter quicker. That
  paid for the preloading: entering an area takes about as long as before
  (2.2 to 2.7 s) while now also preparing its monsters.
- **More VZ leftovers removed.** Each fight still loaded the VZ monster and
  backdrop pictures from disk before the native art; those loads (and the
  files) are gone. The combat code now lives in an overlay that is copied
  into the maze's work buffer when a fight starts, which freed the room for
  all of the above. Assets are packed first-fit, so the disk holds 23 files
  instead of 26.
- **No blank parchment between areas.** Leaving an area used the VZ's
  "clear the screen" page, which on the Microbee is the empty story leaf. It
  now closes the black blinds instead.
- **No card before scripted fights.** Before a story fight (the gargoyle,
  for example) the game flashed the monster's bestiary card, with its
  "SPACE: NEXT" footer, and then the battle started. The story text now leads
  straight into the blinds and the fight. The blinds also blank the
  characters, not just their colours, so nothing of the maze shows through
  on an amber screen while the battle art loads.
- **Music voicing instead of volume.** Narrowing the pulses only made the
  tune thinner and scratchier, as you heard. The Microbee's cone speaker
  reproduces the very thin, decaying pulses the VZ's piezo smoothed over, and
  that is the grating edge. `-` now picks **SOFT**: every note keeps a pulse
  at least about a tenth of the cycle wide (the envelope still decays), and
  the tune runs at 15/16 speed. `+` picks **VZ**, exactly as the VZ300 played
  it. SOFT is the default. In the emulator SOFT moves the sound's centre of
  brightness from 2,320 Hz down to 2,060 Hz and cuts the share above 3 kHz
  from 27% to 23%. Pitch is unchanged. `music-soft.wav` and `music-vz.wav`
  are recordings of the Grounds tune in each voicing.

## Sixth pass (13 November 2026): the map

- **Redrawn map page.** The map was still Codex's picture: blue stippled
  masonry, gargoyles and yellow parchment panels. It now matches the story
  pages: a dark leaf inside a gold rule, the title, the area's name centred
  in gold, the 16 x 16 map in a double gold frame, a compass rose, a framed
  legend and an M: BACK tab, with candles and a skull at the foot. The map
  symbols are new too: walls are grey masonry that joins into solid runs,
  explored floor a faint green stipple, doors gold, finds a magenta gem, and
  you a white arrow.
- **The music no longer stutters on the map.** Each blink of the "you are
  here" arrow (every 16 frames) rebuilt and compared the whole screen, which
  stopped the tune for about five frames each time. The blink now rewrites
  just that one cell.
- **Faster in and out.** The map and story pages stay unpacked in RAM blocks
  24 and 25 after their first use, the map grid is worked out in one pass
  and then drawn in another (instead of switching memory twice per cell),
  and the maze's own background stays in place while you look at the map.
  Opening the map now takes 0.44 s (0.54 s the first time) instead of about
  0.7 s, and closing it 0.44 s instead of 0.66 s.

## Known limits

- **Emulator only.** Pacing, music and readability on the real machine and on
  the amber monitor still need your eyes.
- Entering a new area still blanks the screen for about 2.3 s while its art
  unpacks.
- A fight with a monster from outside the area's usual three, or a boss,
  still takes 0.6 to 1.0 s of black screen to load.
- When a message and a monster movement change in the same step, the lower
  rows can be written just after the beam passes them, so that one frame may
  show a tear. Movement alone and messages alone stay ahead of the beam.
- Floor objects stand in a black halo one cell deep. On the dark floors it is
  barely visible; against a bright wall at a distance it can show.
- If two floor objects line up one behind the other, the nearer one's halo
  hides the edge of the farther one.
- In the Great Hall and Clock Tower 26 of about 1,750 character shapes were
  merged with near-identical ones to fit the PCG; the difference is two or
  three pixels in a few views.
