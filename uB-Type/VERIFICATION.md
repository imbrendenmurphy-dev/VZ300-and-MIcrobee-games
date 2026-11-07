# μB-TYPE verification report

**BPM has played μB-TYPE on his Microbee Premium Plus, and his playtesting drove the later changes (thinning, turret bullets, the stage 1 blocks, the ship, round shapes, the bullet-glyph bug). The measurements and automated checks below come from an emulator.** The emulator is a Premium Plus model written for this project (`src/tools/emu/mbee.c` with its own Z80 core). It was checked by booting the real Microbee boot ROM (`bn60.rom`, not included) and The Lantern Deep's CP/M disk. The original VZ-TYPE ran in a VZ300 model (`src/tools/emu/vz.c`) for the comparisons.

## Gameplay fidelity

`tools/fidelity.py` runs the original VZ-TYPE and μB-TYPE side by side, one game frame at a time, on the same random input script and the same random seed. After every frame it compares the game state: player, pod, satellites, score, lives, scroll position, all 20 enemy slots, every shot and every enemy bullet.

- **Result:** over 1,500 frames, only the 7 frames where a life restarts differ. That difference comes from the harness lining the two machines up across a restart, not from the game.
- **Why it matches:** the movement, weapons, enemy patterns, spawn lists, collisions, scoring and difficulty are VZ-TYPE's own code, ported. The level data is the VZ's level data.
- **Thinning:** the shipped game thins enemies and bullets (see Performance). The fidelity test switches thinning off (`thin` = 0) and compares the unthinned game, which is VZ-TYPE's logic unchanged. It runs on stage 2, because stage 1's terrain is no longer the VZ's.
- **One quirk kept:** as on the VZ, the sound effects' noise generator shares the game's random seed. Exact gameplay therefore depends on timing. The test turns that sharing off on both machines so they can be compared; the game itself keeps it.

## Scrolling and display

- **Mode:** 64×16 characters of 8×16 PCG cells, 512×256 pixels, exactly 4× the VZ300's 128×64. Game logic stays in VZ coordinates.
- **Scrolling:** one VZ pixel (4 Microbee pixels) per game frame, as on the VZ. The game uses the 6545 start address over two screen pages, plus glyphs pre-shifted by 4 pixels, adding one new terrain column each frame.
- **No tearing (by design):** every frame is drawn into the page that is not on screen. The page flip (R12/R13) happens straight after the vertical-blank edge. Only the two HUD rows of the visible page are written after the flip, at the top of the frame while the beam is far above them. The emulator showed no tearing in the playfield.

## Performance under load

`tools/perfcmp.py` gives both machines the same scripted input (fire held in bursts, the ship weaving up, down, left and right) and the same random seed, with the noise/seed sharing turned off. Each stage is measured twice over 400 game frames: from the start of the stage, and in the boss fight. Both games cap at 25 frames per second (2 fields per frame). The Microbee runs as shipped, with thinning on.

**Thinned for the Microbee.** To cut slowdown and suit keyboard play (BPM's call), μB-TYPE: keeps about 9 in 16 ordinary enemies, and 9/16 of each swimming formation; lets each gun turret have only one bullet in the air, fired faster (5/4 of the table speed instead of 5/8) so it leaves the turret instead of scrolling along with it; fires one enemy shot in three less; allows at most 5 enemy bullets at once (the VZ allows 12); keeps boss minion waves smaller; and aims the kamikaze darts one or two compass points off. Power-up carriers, reactor nodes and bosses are never thinned. Stage 1 also loses its round floating blocks, which sat in the flight path.

| Stage | Part | VZ300 fps | Microbee fps |
|---|---|---|---|
| 1 Outer Hull | start | 22.5 | 22.5 |
| 1 Outer Hull | boss | 22.2 | 19.3 |
| 2 The Hive | start | 21.0 | 23.2 |
| 2 The Hive | boss | 21.7 | 18.2 |
| 3 Rock Belt | start | 22.9 | 22.5 |
| 3 Rock Belt | boss | 20.8 | 17.4 |
| 4 Crystal Vein | start | 22.4 | 22.9 |
| 4 Crystal Vein | boss | 21.9 | 19.2 |
| 5 Dreadnought | start | 20.6 | 19.5 |
| 5 Dreadnought | boss | 20.7 | 16.0 |
| 6 Gut Caverns | start | 22.7 | 22.8 |
| 6 Gut Caverns | boss | 22.1 | 18.6 |
| 7 Deep Field | start | 22.8 | 21.8 |
| 7 Deep Field | boss | 21.9 | 19.1 |
| 8 The Core | start | 22.8 | 22.9 |
| 8 The Core | boss | 21.2 | 17.7 |

**Conclusion: μB-TYPE is not yet as fast as the VZ original in busy scenes.**

- Lighter scenes run at the VZ's speed: stages 1, 4, 6 and 8 from the start.
- Every stage runs at or near the VZ's speed from the start; stage 5 (Dreadnought), the busiest, at about 95%.
- The bosses run at about 75–90%: the boss bodies themselves are the cost.
- The thinning made the biggest difference where enemy bullets piled up. Turret bullets are slow and long-lived, and each turret used to keep about four in the air; with one each, stage 5 went from about 7.7 enemy bullets on screen to under 1, and its start from 15.4 to 19.5 fps.
- When the game is busy it slows down evenly; it doesn't skip frames, and the scrolling stays smooth and tear-free at the lower frame rate.

**Why the gap remains:** the new sprites are drawn at full PCG resolution, so each one is 4× the VZ's size in both directions. Every sprite cell is rebuilt as a PCG glyph each frame, which costs about 1,500–2,000 T-states per cell all in. A screen with 90+ sprite cells therefore costs more than the VZ's fixed-cost full-screen redraw.

**Speed-ups already made:**
- an unrolled sprite compositor
- a cache that keeps boss parts' glyphs while the scenery is still
- the sprite-drawing bug fix
- a faster path for sprite cells over open space
- sprites over scenery drawn straight into their glyphs, with the sprite data read two lines at a time from the stack
- self-modifying sprite set-up, a one-pass colour write, and a shorter restore list

- enemy bullets over open space drawn from ready-made glyphs in the font bank, with no composing

Together with thinning these took the slowest scenes from 9.5–13 fps to 16–19 fps (the full history is in `perf_v1.txt` to `perf_v6.txt`).

## Sound

- **Effects:** VZ-TYPE's effect engine and effect tables, unchanged. The Microbee's idle loop takes 180 T-states, the same 53.3 µs as one pass of the VZ's loop, so every effect plays at the VZ's pitch. Effects are also kept going during sprite drawing, as on the VZ.
- **Music:** VZ-TYPE's two-voice player and its tunes (title, stage start, game over, stage clear), retimed for 3.375 MHz.
  - The loop has the same 122 T-state structure as the VZ's, with new pitch tables, so the notes and intervals match. Even a quirk survives: melody notes over a resting bass play slightly flat, as on the VZ.
  - The tempo is 2.5% slower: a tick is 2 frames (40 ms) against the VZ's 38 ms.
  - The music stops for a moment every 50 Hz frame while the title animation runs, silent for about 19% of the time. The VZ pauses every 38 ms tick, silent for about 33% of the time. So the Microbee's music has a little less chop than the original.
- **Interference:** none was seen in the emulator, in either direction.
  - Sound doesn't slow the scrolling: the speaker is driven while waiting for the next field, and in spare moments during drawing.
  - Sound doesn't delay input: input is read once per game frame, as on the VZ.

## Disk and loading

- **Image:** `UBTYPE.DS8`, 819,200 bytes: 80 tracks × 2 sides × 10 sectors × 512 bytes, Microbee 3:1 sector skew, 4K allocation blocks. The first 4 track-sides hold the Microbee CP/M system.
  - The system tracks and `CCP.SYS` come from The Lantern Deep's disk.
  - 147 of 196 blocks are used, by 23 files. There is no `SHELL.SYS`, so the disk boots to the plain `A>` prompt.
- **Boot test** (`tools/boottest.py`): the real boot ROM booted the image to `A>` in 118 frames, and `DIR` listed all 23 files. Typing `UBTYPE` ran the loader, and the game took over the display after about 38 seconds (emulated disk speed). After that, colour mode was chosen, the title ran and a game started on stage 1 with 3 lives.
- **Loader** (`UBTYPE.COM`, adapted from The Lantern Deep's):
  - finds CP/M's memory bank by a signature scan
  - checks that the blocks it needs are present and separate (a 1MB Premium Plus)
  - loads each file through BDOS into its memory block
  - copies everything into place with CP/M switched off, then starts the game
  - refuses with a message if CP/M lives in a block the game needs

## Monochrome mode

Chosen at start-up (**M**). A monochrome monitor lights every set pixel whatever its colour, so brightness has to come from the pixel patterns:

- each stage carries a second set of terrain, band and boss glyphs with outlines and patterned shading
- the title, the big lettering and the sprites read the same in both modes
- on a colour monitor the mode shows white on black

This was checked in the emulator's monochrome render, not on your amber monitor.

## A bug the emulator missed

The first version of the fast bullet drawing put screen codes 96–125 on the page. On a Microbee, codes below 128 come from the character ROM, so BPM saw lowercase letters around the bullets on his machine; the test emulator draws those codes blank, so the screenshots looked clean. The codes are now 224–253 (the same programmable characters), and the emulator now shows any character-ROM code as a checker pattern so this can't hide again. Scans of the title, pages, attract mode and play found none.

## A restore-list bug in the busiest boss fights

While capturing the showcase, the stage 8 boss fight showed leftover pieces of sprites on alternate frames. Each screen page keeps a list of the cells its sprites covered, to be put back next time it is drawn, and the list's count was one byte. That boss fight lists up to 270 cells, so the count wrapped past 255 and some cells were never put back. The count is now 16 bits and the lists hold 400 cells each; a check over 1,500 frames of that fight saw counts above 255 on 11 frames, all restored.

## Known limitations

- Busy scenes and bosses are slower than the VZ (see above).
- Loading takes about 40 seconds in the emulator. Your SD setup may be faster or slower.
- High scores are not saved to disk.
