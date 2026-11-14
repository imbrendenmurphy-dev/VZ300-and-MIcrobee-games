STARHIVE - SOFTWARE SCROLL TEST       VIBED BY BPM 2026

Type SOFTSCRL at the A> prompt. Loading takes a little while (about
300K of level data); a dot is printed for every 4K.

Your monitor bounced when the frame length changed, so the picture
now never changes size: the frame is always 312 lines. The fine,
line-by-line scrolling is done in software instead, and the coarse
row-by-row step uses the start address, which tested clean (test 4).

You'll see space with far stars (moving at half speed) and near
stars, then space stations with girders, and asteroids.

Keys:  0-4   scroll speed (0 = stop, 2 = one line every frame)
       F     switch between 50 and 25 frames a second

What to look for:
 - Does it glide smoothly at speeds 1, 2, 3 and 4, with no bounce
   or jump every row?
 - Is the picture rock steady on the monitor (no shaking)?
 - Do the two text lines at the top stay perfectly still?
 - Any flicker, tearing or wrong colours on the stations?

At the end of the level it goes round again. Reset to leave.
