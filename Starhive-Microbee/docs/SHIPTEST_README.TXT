STARHIVE - SHIP TEST       VIBED BY BPM 2026

Type SHIPTEST at the A> prompt (loading takes a little while).

The smooth software scroll from SOFTSCRL, now with sprites: your ship,
a formation of drones, their bullets and your shots. Sprites are drawn
into spare character cells and written to the screen row by row, just
ahead of the picture, so nothing should flicker or tear.

Controls: joystick, or the cursor keys and SPACE to fire.
Keys:  0-4   scroll speed (0 = stop)
       W     drones: 0, 2, 4, 6, 8 (starts at 4)
       F     switch between 25 and 50 frames a second

The game runs at 25 frames a second. With 4 drones it holds that; with
6 or 8 drones and plenty of firing it drops to about 16-18 a second
(the scroll keeps its speed but steps more coarsely). Speeding that up
is the next job.

What to look for:
 - Do the ship, drones, shots and bullets move cleanly, with no
   flicker, tearing, or bits left behind?
 - Does the scroll stay smooth with sprites on screen?
 - Does anything look wrong where sprites cross the space stations?
   (A sprite takes over its cells' colour there - that's expected.)
