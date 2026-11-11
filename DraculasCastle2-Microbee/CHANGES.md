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

## Not changed

Gameplay, maps, monsters, stats, text, music, the battle screens and monster
art, the gallery, the map and story pages, and the 1984 Easter egg are as
Codex left them. Codex's own boot, battle (all twelve wins, colour and amber),
combat-path, animation, front-end and soak checks still pass.

## Known limits

- **Emulator only.** Pacing, music and readability on the real machine and on
  the amber monitor still need your eyes.
- The title screen was not redrawn; it is still the plain Codex one.
- Floor objects are the VZ drawings enlarged, not new illustrations, so they
  are chunkier than the walls around them.
- A floor object takes the colour of the cell it overlaps, so a little of the
  wall next to a figure can pick up that figure's colour.
- If two floor objects line up one behind the other, the nearer one's edge
  cells show black instead of the farther object.
- In the Great Hall and Clock Tower 26 of about 1,750 character shapes were
  merged with near-identical ones to fit the PCG; the difference is two or
  three pixels in a few views.
- On the amber screen the inventory page shows its text on dark bars. That is
  from the Codex build and was left alone.
