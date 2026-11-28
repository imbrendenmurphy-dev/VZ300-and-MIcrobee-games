# RUNE AMOK — The Vault of the Hollow King

*Run amok in the Runedeep.*

The Wardens are dust and the seal is cracking. The only one left to hold it is you: a half-trained apprentice with a short sword, one potion and a map you'll have to fill in as you go.

Go down through four depths beneath the old gatehouse:

- **The Gatehouse:** torchlit corridors where rats and restless bones keep watch.
- **The Fungal Grotto:** a cave that drops spiders on careless feet.
- **The Drowned Archive:** wailing wisps and a rune puzzle among the bookshelves.
- **The Ember Throne:** red halls where ash hounds prowl and the Hollow King waits on his throne.

Along the way you pull levers and press hidden buttons, haggle with a shifty trader, and find the three sigils. Then break the seal, and keep the oath.

It's a step-and-turn first-person crawl made for the **Microbee Premium Plus** from the ground up, not ported from another machine:
- woodcut-style art pre-rendered into the PCG;
- torches, runes and water that flicker by colour cycling;
- a three-voice beeper score with its own theme for every depth;
- turn-based fights where every blow lands on screen.

(The name is a pun on "run amok". The dungeon is still called the Runedeep.)

VIBED BY BPM 2026

![Rune Amok in play](docs/showcase.gif)

![Title](screenshots/01_title.png)

| | |
|---|---|
| ![The Gatehouse](screenshots/02_gatehouse.png) | ![A blow lands on a rat](screenshots/03_rat.png) |
| ![Fungal Grotto](screenshots/04_grotto.png) | ![Drowned Archive runes](screenshots/05_archive.png) |
| ![The Ember Throne](screenshots/06_ember.png) | ![The Hollow King](screenshots/07_king.png) |
| ![An ambush beyond the seal](screenshots/09_ambush.png) | ![Victory](screenshots/08_victory.png) |
| ![The gate seen from the side, the lever's wall marked on the map](screenshots/10_side_gate.png) | |

## Status

Version 1.2. It has been played on a real Microbee Premium Plus, and tested in the emulator model (`tools/emu`, the Spindrift/REDBACK Premium Plus model) and in uBonPC. It loads and plays in uBee512, but there the sound crackles, which uBonPC doesn't reproduce.

It plays on a **colour or a monochrome monitor**. Nothing is shown by colour alone:
- Keys, sigils and spells you don't have yet are dots in the panel.
- A lit rune has rays round it, and a pressed button sits sunk in its socket.
- A struck foe blinks out before it flashes red under the blade.
- When you are struck, the view's frame turns to thick red bars.

What has been checked:

- **Disk**: `release/RUNEAMOK.DS8` boots with the bn60 ROM to the CP/M prompt. Typing `RUNEAMOK` loads all files in about 16 seconds and starts the game. ESC then Y leaves to the title, and ESC on the title returns cleanly to `A>`, and `DIR` works afterwards (`tools/boottest.py`).
- **Solvability**: every build checks that all four depths can be finished (`tools/mklevel.py`).
- **Bot playthrough**: a bot plays through the keyboard (`tools/bot.py`): fighting, keys, levers, buttons, hidden walls, the trader, rune puzzle, stairs and the seal.
- **Speed**: composing a view costs about 1.1 frames of CPU (`tools/perf.py`). It is copied to the hidden screen page in the blanking, and then the page flips.

## Playing

Needs a Premium Plus with 1MB RAM. Boot `release/RUNEAMOK.DS8` and type `RUNEAMOK` at the `A>` prompt.

| Key | Action |
|---|---|
| Arrows or W A S D | Walk forward and back, turn left and right |
| Q E (or Z X) | Step aside |
| SPACE or RETURN | Fight, open, pull, read, drink, trade |
| 1 / 2 | FIREBOLT / MEND, once learnt |
| 3 or P | Drink a potion |
| H | Help |
| T | Music and effects, effects only, or silence |
| ESC | Leave to the title (asks first); on the title, back to CP/M |

A joystick on the parallel port also works.

Turning is free. Every other action takes a turn, and then the awake creatures step or strike.

Find the **three sigils** on depths 1–3. They break the seal on the Ember Throne, where the Hollow King waits.

| Depth | Look | What's there |
|---|---|---|
| The Gatehouse | Torchlit grey stone, mossy walls | Rats and skeletons; a bronze key, a lever and gate, a hidden wall and its button, a treasure alcove |
| The Fungal Grotto | Green cave rock | Cave spiders and fungoids; illusory walls, a gate button, a lever, a pit, a trap plate, the silver key, the trader |
| The Drowned Archive | Cyan stone and bookshelves | Ghouls and grave wisps; a four-rune sequence puzzle, portals, a spinner, the golden key, the FIREBOLT scroll |
| The Ember Throne | Red brick | Ember imps and ash hounds; the sealed door, an ambush, and the Hollow King, who calls his hounds when wounded |

## How it suits the Microbee

The full design and style guide is in [`docs/DESIGN.md`](docs/DESIGN.md). In short:

- **Cell-aligned perspective.** The square boundaries are 96, 48, 32, 24 and 16 pixels wide, so every vertical edge of the 3D view falls on an 8-pixel cell boundary.
- **One ink on black.** Inside the view the paper is always black. Depth is shown by a colour ramp per level plus dithered density, so attribute clash cannot happen.
- **No pixel drawn at run time.** Every wall, floor, door, creature, item and decoration cell is pre-rendered into a per-level PCG tile dictionary of up to 1,856 glyphs. The Z80 composes each view from tile lists.
- **Writes only in the blanking.** The Premium stalls the CPU on video access during a displayed line, so every video write happens in the vertical blanking, with two screen pages flipped by the 6545 start address.
- **Colour is the animation.** Torches, runes, fountains, portals and wisps cycle their ink at almost no cost.
- **Woodcut creatures.** Monsters are solid silhouettes, one ink per cell with black-cut detail, and each has an attack pose close up.
- **Sound in the idle time.** In the time each frame waits for the blanking, three voices share the speaker: a soft-attack melody, a plucked bass, and effects and drums. Each depth has an original theme in its own mode:
  - title: D minor march
  - Gatehouse: A aeolian
  - Grotto: E phrygian drips
  - Archive: D dorian waltz
  - Ember Throne: driving C minor

## Building

`py tools/build.py` builds everything; add `--nodata` to skip the art and levels. It needs Python 3 with numpy and Pillow. The emulator model (`tools/emu`) compiles with gcc, or on Windows with TinyCC 0.9.27 unpacked into `tools/tcc/tcc` (not in the repo; from download.savannah.gnu.org/releases/tinycc/). The boot test needs the Microbee boot ROM `bn60.rom`, which is not in the repo.

| Command | What it does |
|---|---|
| `py tools/rd.py OUT "w150 SPACE w60 UP sname"` | Scripted run with screenshots |
| `py tools/bot.py OUT` | The whole-game bot |
| `py tools/perf.py` | Step timing |
| `py tools/showcase.py` | Records `docs/showcase.gif` |
| `py tools/sheet.py OUT [names]` | Contact sheet of the creatures as the Microbee draws them |
| `py tools/boottest.py resources/bn60.rom OUT` | Real boot from the disk image |

## Not verified

- Sound in uBee512 (it crackles there; uBonPC plays it cleanly).
- The model's CPU-hold behaviour is the one the owner measured on real hardware for Spindrift. The commit writes only in the vertical blanking, so it should be safe.
