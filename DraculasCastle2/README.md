# DRACULA'S CASTLE II — THE CASTLE AWAKENS
### Vertical slice v0.2 · ViBED by BPM · 2026
Dick Smith VZ300 · BennVenn SD + 128K · Mode 1 (128×64, 4 colours) · all Z80

## Running it
Copy `DRACULA2.VZ` **and all twelve `DC2*.DAT` files** from `release/` to the same place on
the SD card, then load `DRACULA2.VZ` like any other binary .VZ. It loads at $8000–$C30D
and runs from $8000. The game streams its artwork from the `.DAT` files through the
BennVenn DOS, the same way 13 Ghosts does. If a file is missing it stops with
`CAN'T LOAD GAME FILE:` and the file's name. If no 128K expansion is present, it prints
`NEEDS BENNVENN SD + 128K RAM`.

| File | Contents | Loaded into |
|---|---|---|
| DC2TITLE | title picture | back buffer |
| DC2A0P1 / DC2A1P1 | grounds / hall walls and backgrounds | SRAM bank 3 $4000 |
| DC2A0P2 / DC2A1P2 | grounds / hall decorations and objects | $C800 |
| DC2MON1–4 | bat, skeleton, ghost, gargoyle (3 frames each) | $C800 (during battles) |
| DC2BBG0 / DC2BBG1 | battle backdrops | SRAM bank 3 $5C00 |
| DC2EGG | the four 1984 mode 0 screens | $C800 |

## Controls
| Key | Exploration | Battle / menus |
|---|---|---|
| W or I | step forward (hold to keep walking) | cursor up |
| A or J / D or L | turn left / right | cursor left / right |
| S or K | turn around | cursor down |
| SPACE or RETURN | act: talk, open, search, read | select |
| M | automap | |
| E | status & inventory (1 = drink a potion) | |
| P | pause (N = music on/off, Q = quit to title) | |
| 1 / 2 | | potion / holy water in the ITEM menu |

The joystick is detected at boot and works on either port (fire = SPACE).

## What's in the slice
- **Title screen**: castle silhouette against the moon, dripping logo, lightning flashes with
  thunder, an organ title theme (Bach's Toccata, which is public domain), and a menu with
  NEW GAME / CONTINUE / MUSIC.
- **Attract mode**, after about 20 seconds idle: the story, a tour of locations, then the
  "Groovy Ghoulies" gallery of animated monsters.
- **Two areas**, each with its own wall textures, decorations, music, battle backdrop and
  monsters:
  - *The Grounds*: hedge garden, graveyard, courtyard and castle gates.
  - *The Great Hall*: stone corridors, a red damask hall, portraits, torches, windows,
    suits of armour.
- **First-person renderer**: three cells of depth, five cells wide, perspective-correct
  pre-rendered wall pieces, decorations (doors, gates, torches, portraits, windows, a
  plaque), floor objects visible ahead and to the sides, and per-direction skies (the
  castle is on the horizon when you face north).
- **Battle screen**: full-width backdrop, a large 64×44 monster with three animation frames,
  and ATTACK / MAGIC / ITEM / DEFEND / RUN. Effects include sword slash, fireball and burst,
  holy-water sparkles, hit flash and shake, monster lunge, a dissolve on death, a palette
  flash, and a blinds transition into battle.
- **Bestiary**: Bat (flying, sometimes flutters instead of attacking), Skeleton (undead; the
  silver dagger does 1.5× damage), Ghost (a spirit that halves physical damage and is weak to
  FIRE; drawn in the alternate cyan/magenta palette), and the Gargoyle boss (telegraphs a
  double-damage dive, so DEFEND halves it; you can't run from it).
- **Scripted encounters in the view**:
  - Bones rattle, then a skeleton rises out of the floor and swings its sword.
  - The gargoyle statue's eyes flash, then it drops from the ceiling.
- **NPC**: Grigor the groundskeeper. Paged dialogue, he gives potions, and his hint changes
  after you've spoken to him.
- **Items and progression**: potions, holy water, the iron key, the silver dagger and the
  FIRE scroll, plus XP, levels (with a jingle), gold and full heals on level-up.
- **Secrets**: a hidden hedge leads to the Stone Angel. A secret wall in the hall leads to a
  brass plaque and…
- **Easter egg, THE FORGOTTEN MAZE – 1984**: switches to mode 0 and shows the original
  game's actual corridor pictures and Dracula portrait. These were extracted from the
  original DRACULA.VZ's BASIC PRINT data. After five moves you die instantly, then get
  "THAT WASN'T MUCH FUN, WAS IT?" and land back in the hall with nothing lost.
- **Save and continue**: Stone Angel shrines heal you, set your checkpoint and save. Defeat
  returns you to the last shrine with half your gold, and no other progress is lost.
- **Chapter end**: completion summary showing time, ghoulies defeated, secrets, treasure and
  level.
- **Music**: 10 tunes on a 3-voice pulse engine (grounds, hall, battle, boss, victory,
  level-up, death, title, the 1984 beeps, ending), plus 21 sound effects on a fourth channel
  that takes over voice 3.

## Architecture
```
$0000-$3FFF  ROM (never called by the game)
$4000-$67FF  SRAM bank 1  BennVenn DOS - left untouched so files can be loaded at any time
             SRAM bank 3  area walls/backgrounds; battle backdrop @ $5C00; save slot @ $6400
$6800        latch / keyboard / field sync
$7000-$77FF  VRAM (written only during field sync)
$7800-$7AE7  ROM/DOS system variables - left alone
$7B00        flip table          $7C00-$7EFF  runtime maps, seen-bits, event flags
$8000-$C7FF  code + text + music + maps (the .VZ image, 17K)
$C800-$E7FF  streamed assets: area decorations/objects, or monster frames + view cache
$E800-$E9FF  variables           $EA00-$EDFF  stack
$EE00-$EFFF  SD sector buffer    $F000-$F7FF  back buffer
$FA00-$FFFF  DOS workspace - left alone
```
- **SD loading** (`src/sd.asm`). This is the protocol read from the 13 Ghosts loader:
  1. Set `(FB80)` to the sector buffer, point HL at `"NAME"`, set `A=1` and `CALL $5F00`
     to open the file. It opened successfully if `(FB03)=1` and `(FB05)≠1`.
  2. `CALL $5F03` reads the first 512-byte sector into the buffer.
  3. Then, for each further sector, set `(FB80)` again and `CALL $5F09`.

  Sectors bound for SRAM bank 3 are copied with `OUT ($37),3`, and the DOS mapping is
  restored before the next DOS call. Areas load in about a third of a second; battle
  graphics load in about a tenth.
- **Frame engine.** `wait_frame` plays the music sample loop (17.4 kHz, 204 T per sample,
  three pulse-width voices plus an LFSR noise variant) until field sync falls. `present_rect`
  then copies dirty rows from the back buffer to VRAM inside the 56-line field-sync window,
  with the rows per frame worked out from a cycle budget. As a result, every VRAM write lands
  in vertical blank. Music keeps playing whenever the game waits.
- **Renderer.** Walls are drawn back to front from byte-aligned pre-rendered pieces. Front
  faces are plain rectangles, clipped for the side cells. Side faces are masked sprites,
  mirrored at runtime through a pixel-pair flip table. Occlusion culling skips depths that
  are fully hidden.
- **Assets.** These are generated in Python (`tools/`): procedural tone-ramp materials,
  perspective projection, hand-drawn objects, monsters drawn with vector primitives, and
  the title. Everything is compressed with an optimal-parse LZ (4K window). The Z80
  decompressor is in `sys.asm`.

## Verification (headless emulator, `tools/vzemu.c`)
- The emulator models the BennVenn DOS calls. It runs the real 13 Ghosts loader correctly:
  3 files opened and 66 sectors read. With `-s DIR` it serves `NAME.DAT` from a folder.
- It also flags any write to the DOS's RAM ($FA00+), to the system area ($7800–$7AE7) or
  to the DOS SRAM bank. Every run shows none, apart from the boot probe that writes and
  restores $5FFF, exactly as 13 Ghosts does.
- The renderer output is compared pixel by pixel against the Python reference at many map
  positions.
- Scripted playthroughs cover: the dialogue, the skeleton cutscene and battle, the key and
  door, the hall chests, the shrine save, CONTINUE, the boss, the chapter end, the Easter egg,
  the automap, pause, and attract mode.
- Four random-input runs of 60,000 frames each: no crashes, no stack leak, no snow.

## Known limits / next steps
- **Saves stay in SRAM bank 3**, so they survive reloading but not power-off. The DOS calls
  used here only read files. A save file on SD needs a DOS write call, if the BennVenn DOS
  has one.
- **Real-hardware checks still to do**: SD load timing, joystick detection with your
  interface (it reads ports $2E/$2D/$2B/$27/$2C/$29), and music volume.
- **Next**: with assets on SD, the .VZ has room for the full castle. Next up are more areas
  (library, dungeons, catacombs, clock tower, Dracula's tower), more monsters, a merchant, and
  the remaining story.

## Building
```
gcc -O2 -o tools/vzemu tools/vzemu.c
python3 tools/build.py            # -> build/DRACULA2.VZ + build/sd/DC2*.DAT
python3 tools/build.py --debug    # no random battles, strong hero (testing)
tools/vzemu build/DRACULA2.VZ -s build/sd -f 600 -d 300 -o out   # run headless with SD files
```
`tools/egg.py` reads `orig/lines.pkl`, which `tools/detok.py` creates from the original
DRACULA.VZ.
