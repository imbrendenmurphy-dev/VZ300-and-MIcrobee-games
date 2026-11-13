# ROBOT RIOT 2086

An original single-screen robot-uprising arena shooter for the **Microbee Premium Plus**, in the spirit of Robotron: 2084.

2086. The robot factories have risen up and their machines swarm the city. One cyborg hero with a plasma gun stands between them and the last human family.

**VIBED BY BPM 2026**

![showcase](screenshots/showcase.gif)

## Status: build 0.2

- Re-themed from build 0.1 (ROGUE MUSTER) to a robot uprising, with all-new robots.
- New attract sequence, a thin rainbow border with a full-screen arena, and Robotron-style rectangles between waves.
- Tested in the Premium Plus emulator model:
  - It holds a steady 25 frames a second on every wave.
  - Long soak tests passed: random play across several games, and the attract sequence left to loop through every screen and the demo.
- Build 0.2.1 fixes a fault found on BPM's Premium Plus: the screen showed as four small copies. The 40-column dot clock was never selected, so the 6545 scanned at twice the rate.

## Play it

`release/RIOT.DS8` is a DS80 disk image with no shell. At the `A>` prompt type:

    RIOT

It needs a Premium Plus with 1MB RAM.

| Action | Keys |
|---|---|
| Move | **W A S D**, or a joystick |
| Fire | **I J K L** or the **arrow keys**. Hold to keep firing, in 8 directions. |
| Fire the way you face | **SPACE** or joystick fire. The aim stays locked while held, so you can retreat and keep shooting. |
| Pause / sound / title | **P**, **M** (music + effects → effects → off), **ESC** |

## The attract sequence

It loops until someone presses SPACE, RETURN, a fire key or joystick fire.

1. **Title.**
   - The ROBOT RIOT 2086 logo in rolling rainbow bands.
   - A train of spinning, colour-cycling balls orbits the screen edge.
   - The hero dances between a stomper and a crusher.
   - A squelchy, robotic title jingle plays.
2. **Story.** The story is typed out with typewriter clicks inside a glowing dithered border, then the last human family appears.
3. **Meet the Riot.** Each robot beams in, in a shower of sparkles with a beam-in sound, then dances at double size with its name, points and habits.
4. **Hall of Legends.** The top 8 scores with initials, in rolling colours, with a robot fanfare.
5. **Demo.** The machine plays wave 3 for 20 seconds.

The glowing borders are dithered cells whose ink and paper colour pairs chase round the screen edge. On an amber monitor they show as shimmering dither.

**Audio:** the title jingle is short and plays over the title, where the screen work is light (about 6% of each frame). The other attract screens use effects and jingles: typewriter clicks, beam-ins and the fanfare. That keeps the sound smooth rather than chopped up.

## The riot

| Robot | Points | What it does |
|---|---|---|
| **Stomper** (yellow/red box walker, goggle eyes) | 100 | Stomps straight for you, a step at a time. Stompers speed up the longer a wave lasts. |
| **Zapper** (cyan dome on a magenta tripod) | 200 | Keeps its distance and throws sparks where you are *going*, which cuts off escape routes. Sparks can be shot down. |
| **Crusher** (green gorilla-bot) | 500 | Takes 4 hits and is knocked back by each. It hunts the family and squashes them. |
| **Whirler** (colour-cycling saucer) | 150 | Swoops corner to corner, re-aiming at you. |
| **Shock node** | 25 | Pulsing rainbow shapes that change every two waves. Don't touch them. They fry any stomper that walks into one. |
| **The last human family** (dad, mum, kid) | 1000 → 5000 | Walk into them to save them. Each rescue in a wave is worth 1000 more. |

**Rescues are a decision.** The family starts near the edges, away from the safe middle, and the first shock nodes of each wave stand between them and you. When the last robot falls the wave ends, and anyone still out there is lost.

**Forgiving play:**
- Each life has 3 charge cells, and a hit costs one, followed by two seconds of flickering safety.
- After losing a life, the robots are scattered away from the middle.
- There's an extra life every 25,000 points.

**Between waves:**
- After WAVE CLEARED, rainbow rectangles grow out of the middle until the screen is filled, then wipe away.
- The next wave's robots beam in as sparkles before they move.

## Waves

| Wave | What's new |
|---|---|
| 1-2 | Stompers and shock nodes |
| 3 | Zappers |
| 4-5 | Crushers |
| 6 | Whirlers |
| 7-10 | Everything at once |
| 11+ | Waves 6-10 again, faster each time round |

## Under the hood

- **Display:** 40 × 25 cells of 8 × 8 pixels (320 × 200). This needs the 40-column dot clock (`IN A,(09h)` with A = 1) as well as the 6545 table. Two pages are flipped with the 6545 start address. The arena is rows 1-24, the whole screen below the score line.
- **Border:**
  - The arena border is one pixel thick. Its 8 glyphs sit at numbers 1-8 of every PCG bank, so a cell needs no bank change to show it.
  - When a sprite moves off a cell, that cell is restored from a 1K background map: blank, or border.
  - The border's colours run as a rainbow, with half the border recoloured each frame.
- **Sprites:**
  - Sprites are 12 × 12 on a 4-pixel grid, so each always covers 2 × 2 cells.
  - Each frame is stored as 16 ready-made PCG glyphs, and sprites are two-tone: top cells in one colour, bottom cells in another.
  - The gallery shows the same art at double size, using 3 × 3 cells.
- **Draw list:** each frame's cells go into a draw list, written in three passes (characters, PCG banks, colours) using stack pops.
- **Sound:**
  - Two-voice pin-pulse beeper.
  - The tunes are built frame by frame from squelchy bass drops (each note starts an octave up and dives), robotic arpeggios and pitch zips.

## Build

You need Python 3 with numpy and Pillow, and gcc for the emulator model. From `src/`:

    python3 tools/build.py

This writes `build/RIOT.DS8`. Tests:

| Script | What it does |
|---|---|
| `tools/shoot.py` | Takes screenshots of every screen |
| `tools/gif.py` | Records the showcase GIF |
| `tools/perf.py` | Measures the frame rate and profiles the code |
| `tools/frametime.py` | Shows the work per frame |
| `tools/soak.py` | Plays random input and checks for crashes |

## Files

| Path | What it is |
|---|---|
| `src/src/` | Z80 source: `main.asm`, `game.asm`, `actors.asm`, `attract.asm` (the attract sequence, Hall of Legends, demo AI), `fx.asm` (border, balls, glow, rectangles), `render.asm`, `sound.asm`, `loader.asm` |
| `src/tools/art.py` | All the artwork, as text |
| `src/tools/music.py` | The tunes |
| `src/tools/build.py` | Glyphs, tables and the disk |

The loader, the beeper engine, the assembler and the disk builder come from KABOOMERANG. The test emulator in `src/tools/emu` is only used for testing.
