# Blackout Protocol (Microbee Premium Plus)

An original action-puzzle game in the style of *Impossible Mission*, for the
**Microbee Premium Plus** (1 MB RAM, 32 KB PCG RAM). It runs in a full-screen
PAL mode of 42×24 cells (336×288 pixels) and comes on four double-sided
80-track disks.

MERIDIAN, the AI of the HALCYON ARRAY station, will cut the planet's power in
eight hours. Agent Wren must search six wings of the station for 18 cipher
shards. Three shards are spliced into each wing's key, and all six keys open
MERIDIAN's core.

![Title](screenshots/01_title.png)

## Running it

1. Put the four disks in drives A to D: `release/BA.DS8` in A, `BB.DS8` in B,
   `BC.DS8` in C and `BD.DS8` in D.
2. Boot drive A. The game starts by itself.

At start-up the game reads all four disks through CP/M into the 1 MB of RAM,
so nothing is loaded from disk during play. Disk A carries a small loader of
its own in place of the CP/M command processor (see *Auto-boot* below), so it
boots straight into the game. If disk D is missing, the game still runs, but
the title shows "NO VOICE: DISK D NOT FOUND".

`BT.DS8` is a test disk to use in drive A instead of `BA`. It boots to the
ordinary `A>` prompt, and holds the game (type `BLACKOUT`) and `FDCTEST`, which
reports how the machine answers direct floppy-controller reads on drives A–D.

In the uBonPC emulator, `src/play.bat` boots the four disks.

## Controls

| Key | Action |
|---|---|
| `O` / `P` or ← / → | run left / right |
| `Q` / `A` or ↑ / ↓ | ride a lift; search or use (`Q` / ↑) |
| `SPACE` | vault (a forward somersault over robots and gaps) |
| `W` | wrist-deck: map, keys, shards, codes, time; `S` there to save |
| `S` / `R` at a security terminal | use a SLEEP code (robots off 20 s) / a RESET code (lift pads back) |
| `ESC` | quit to the title (Y/N) |
| `L` (title) | load a saved game |

## The game

- **47 rooms in six wings**: Docking, Hydroponics, Cryo Labs, Reactor Deck,
  Observatory and the MERIDIAN Core. They're joined by twelve smoothly
  scrolling lift shafts, and each wing has its own architecture, so they look
  different even on a mono screen.
- **Searching**: stand at a piece of furniture and hold `Q`. It might hide a
  shard, a SLEEP or RESET code, or nothing. Searched furniture is half-toned.
- **Robots**: patrols, shooters, hunters and sentries, plus steam vents and
  laser gates. Watch their patterns, vault them, change floors, or put them
  to sleep from a security terminal.
- **Splice terminals**: in each wing, turn the three shards until they match
  the pattern, and that wing's key comes online.
- **The clock**: a death costs game time, and when it reaches zero, it's dark.
- **Three levels** (*Story*, *Agent*, *Ghost*): they change the clock speed,
  the death penalty, robot speed and guns, and how long you're safe on entering
  a room.
- **Saves**: four slots on disk A. Slot 0 is an autosave made each time a key
  comes online.
- **MERIDIAN speaks**, with nine original lines, and there's an original
  sectioned title tune plus wing stings.
- **Attract mode**: if the title is left alone, Wren plays a demo by herself.

| | |
|---|---|
| ![](screenshots/05_wings_rooms_1.png) | ![](screenshots/06_wings_rooms_2.png) |
| ![](screenshots/07_wing_styles_colour.png) | ![](screenshots/08_wing_styles_mono.png) |
| ![](screenshots/03_attract_demo.gif) | ![](screenshots/02_clearance.png) |

## Wren's animation

Wren's run and somersault are rotoscoped from Eadweard Muybridge's *Animal
Locomotion* (1887, public domain): Plate 60 (a man running) and Plate 363
(a running somersault). The joint angles were read off each photograph and
drive a skeleton that renders a clean 24×24 sprite.

![](screenshots/04_wren_rotoscoped.gif)

## Technical notes

- **Display**: the 6545 is set to 42×24 cells of 8×12. Each cell is its own
  PCG character, on two double-buffered pages. Video RAM can only be reached
  in horizontal blanking, so the game draws into a software copy of the screen
  and sends across only the cells that changed. Logic runs once per 50 Hz
  field, so the game keeps time when a busy room draws at 25 fps.
- **Memory**: rooms, sprites (pre-shifted and pre-mirrored), speech and music
  live in the 1 MB banks. The information screens are overlays loaded only
  while they're up.
- **Sound**: two-channel music on the 1-bit speaker. Speech is "clipped
  speech" (the speaker flips where the voice crosses zero), so it plays at
  full volume on a real Microbee speaker.
- **Auto-boot**: the Microbee CP/M boot code loads `SHELL.SYS` if a disk has
  one, otherwise `CCP.SYS`. Disk A has no `SHELL.SYS` (**the Microbee shell is
  not used**). Its `CCP.SYS` is a 384-byte loader (`src/src/autoboot.asm`) that
  reads `BLACKOUT.COM` and runs it. The disk works write-protected and is still
  an ordinary CP/M disk.
- **Disks B–D** are read through CP/M at start-up. On a Premium Plus with SD-card
  disk images, the game's own direct WD2793 reads don't reach those drives.

## Building

`src/` holds everything: the Z80 source (`src/src`), the Python generators
(`src/tools`: rooms, art, font, music, speech, disks), the Muybridge reference
plates (`src/ref`) and the emulator test scripts (`src/test`). Put
`sjasmplus.exe` in `src/tools/` and run `src/build.ps1`. The disks come out in
`src/outputs/`. `src/DESIGN.md` is the full design and development log.

Blackout Protocol is an original game: its names, art, music and speech are
its own, made in the style of *Impossible Mission*, not copied from it.
