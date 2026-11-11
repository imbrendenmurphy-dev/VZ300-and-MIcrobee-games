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
  monster. The graveyard was already good and is unchanged. Monster drawings
  and animation are unchanged.
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

## Known limits

- **Emulator only.** Pacing, music and readability on the real machine and on
  the amber monitor still need your eyes.
- Entering a new area still blanks the screen for about 2.3 s while its art
  unpacks, and opening the map for about 0.9 s.
- Floor objects are the VZ drawings enlarged, not new illustrations, so they
  are chunkier than the walls around them.
- A floor object takes the colour of the cell it overlaps, so a little of the
  wall next to a figure can pick up that figure's colour.
- If two floor objects line up one behind the other, the nearer one's edge
  cells show black instead of the farther object.
- In the Great Hall and Clock Tower 26 of about 1,750 character shapes were
  merged with near-identical ones to fit the PCG; the difference is two or
  three pixels in a few views.
- The spires on the title castle are faint against the sky.
