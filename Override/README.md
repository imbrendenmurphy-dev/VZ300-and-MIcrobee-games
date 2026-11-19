# OVERRIDE
### v0.3 · three ships, 19 decks, 19 droid types · VIBED BY BPM 2026

## What's new in v0.3: intro cinematic and a soundtrack in play
- **An intro cinematic opens every attract cycle** (`OVATT.DAT`, about 16 seconds; fire skips it):
  - a drifting starfield, with "2391. THE OUTER BELT." typed in;
  - the Kestrel freighter glides in from the right;
  - THE KESTREL FREIGHTERS / HAVE GONE DARK;
  - **red alert**: the palette flashes between the colour sets with a siren, under
    A ROGUE MIND RULES / EVERY DROID ABOARD;
  - the probe streaks from the corner to the freighter's hull (ONE PROBE. ONE CHANCE.);
  - a flash into the title.

  It has its own three-voice tune (bells, a pad and a heartbeat kick). The file loads into low
  bank 3, where the game's ring buffer lives between games, so it is read from the card at the
  start of each cycle. If it's missing, the attract sequence simply starts at the title.
- **A two-channel soundtrack during play**: bass on speaker line 5 and lead on line 0, with a tune
  for each ship:
  - **SV CORMORANT**: D minor, slow and uneasy;
  - **MV HALCYON**: E minor, pulsing;
  - **CV LEVIATHAN**: C minor, driving.

  Effects take the lead channel while they play. Loud ones (explosions, hits) take both lines and
  briefly mute the bass. N switches the music off and leaves the effects on.
- **How it works**: all sound in play now comes from a 256-sample ring. Once a frame, a mixer in
  upper bank 1 steps the tune and fills the ring about 232 samples ahead (132 T a sample, about
  2.5% of the CPU). Every sample site just plays the next byte: the interrupt copy (every four
  chunks), the window copy (every row, padded) and the idle wait, all about 875 T apart. The
  frame rate went *up*: in the emulator, 92% of play frames now hold 25 fps on ship 1, against 85%
  before, because the sites no longer work out samples themselves.
- **A briefing tune** (A minor, three voices) for the briefing, droid-file and high-score pages.
  The title theme now plays on the title only.
- **Fixed: the demo linking over and over.** After a duel, the droid was still touching you with
  fire still held, so a new duel began at once. Link mode now ends with the duel, a droid you have
  just duelled waits a moment before it can be linked again, and duels count towards the demo's
  length. The attract cycle is now about 70 seconds: intro, title, briefing, files, scores, demo,
  scores.
- Recordings from the emulator are in `screenshots/`: `attract_intro_and_title.wav`,
  `attract_briefing.wav`, `ingame_cormorant.wav` and `ingame_leviathan.wav`.

## What's new in v0.2 (polish)
- **The LINK PROBE has its own look**: a ringed red eye with four feelers, instead of a droid
  marked 000.
- **N switches the music on and off** anywhere. It doesn't count as "any key", so it won't skip an
  attract page.
- **LOW ENERGY**: the HUD warns once when your body drops below a quarter of its energy.
- **The link duel shows YOU** beside the timer on your side. Charge pips are capped at six so the
  label fits.
- **Console map**: droids show as blinking 2×2 dots, and you as a yellow / green dot.
- **The title draws PRESS FIRE TO START at once** (it used to appear only on the first blink).
- **More varied decks**: some rooms have studded or grated floors, and bigger rooms get an island of
  computer banks, reactor cores or cargo, kept only if every part of the deck can still be reached.
- **Front-end screens update at most 22 rows a field**, so their video RAM writes stay inside the
  sync gap and the music barely stops.
Dick Smith VZ300 · BennVenn SD + 128K · Mode 1 (128×64, 4 colours) · all Z80

An original top-down droid-transfer action game in the Paradroid tradition, written from scratch for
the VZ300. A rogue ship mind, the OVERMIND, has taken over every droid on the three Kestrel Line
freighters. You are the LINK PROBE (unit 000), a small unarmed unit that can take over any droid it
touches. Shoot droids, or link into them and win the circuit duel to take their bodies. Clear every
deck of every ship.

The name, ships, droids, numbers, art, board design and music are all new. The genre's ideas are
kept: numbered droid classes, link duels, lifts between decks, consoles, and decks going dark when
cleared.

## Running it
Copy **all 25 files** from `release/` to the root of the SD card: `OVERRIDE.VZ`, `OVCOM.DAT`, `OVATT.DAT` (the intro),
`OV1.DAT`-`OV3.DAT` (ship headers) and `OV1D0.DAT`-`OV3D5.DAT` (one file per deck). Load
`OVERRIDE.VZ` like any other .VZ. It loads at $8000 (10.6K), loads `OVCOM.DAT` at boot, and reads each
deck from the card when you ride a lift to it (well under a second).

| File | Contents | Loaded into |
|---|---|---|
| `OVERRIDE.VZ` | the engine: renderer, droids, player, shots, HUD, SD loader, autopilot | main RAM $8000 |
| `OVCOM.DAT` | the screen-copy code, tiles (normal and lights-out), droid images, explosions; and the front end: title, attract, link duel, lift, console, cards, music and songs, title picture | upper bank 1 $CA00 / upper bank 0 $B800 |
| `OVn.DAT` | ship n: name, deck sizes, lift shafts, droid counts | main RAM |
| `OVnDd.DAT` | deck d of ship n: map, deck info, droid spawn list, waypoint graph | upper bank 1 / main RAM |

If the expansion is missing you get `NEEDS BENNVENN SD + 128K RAM`. If a file is missing you get
`CAN'T LOAD OV*.DAT FILES`. If the files come from different builds you get
`OV*.DAT FILES DON'T MATCH`, so always copy all the files together.

## Controls
| | Keyboard | Joystick (either) |
|---|---|---|
| Move (8 ways, with momentum) | Q A O P (or Z X for left/right) | stick |
| Shoot where you face | SPACE or M (tap or hold) | fire |
| Link mode | hold fire and stand still for half a second (your droid pulses red), then touch a droid | |
| Lift | fire while standing on a lift pad | |
| Console | push into a terminal | |
| Pause | RETURN | |
| Music on/off | N | |
| Link duel | up/down choose a lane, fire sends a pulse; left/right picks your side at the start | |

## Playing
- **Droids**: each droid has a three-digit number, and the first digit is its class (1-9). Higher
  classes are tougher, faster, better armed and harder to take over. Hostile droids are red with
  yellow numbers. Yours is yellow with blue numbers.
- **Linking**: touching a droid in link mode starts the link duel. Win it and you take that droid's
  body, its weapon and its energy, and the body you were using burns out. Lose it and your current
  body is destroyed (as the bare probe, you lose a life). A tie is a deadlock and nothing changes.
- **Burnout**: a borrowed body wears out slowly (faster for higher classes), so keep moving up. The
  bare probe never burns out but has no gun.
- **Energizers** (the red and yellow coils) recharge the body you're in while you stand on them.
- **Lifts** show the ship in side view: ride the shaft to any deck it serves. Cleared decks show
  as blue.
- **Consoles** show the deck map with every droid on it, then the droid files for every class up
  to your own.
- **Deck cleared**: when the last droid on a deck goes, the lights go out (the floor turns blue) and
  you score a 1,000-point bonus. Clear every deck for SHIP SECURED (a 5,000 bonus), then the next
  ship loads. Free all three ships for the ending.
- Three probes (lives). Scores: 125 points for a class 1 droid, up to 725 for class 9.

### The link duel
Twelve lanes on each side run from the edge to a central column of twelve nodes, which start split
6-6. Move to a lane and fire to send a pulse down it. When the pulse arrives, its node turns your
colour and **locks** for a moment (a solid node is locked; a striped one can be taken). Lanes can be:
- **plain**
- **broken** (the wire stops halfway, with a cap)
- **forked** (a riser feeds two nodes)
- **boosted** (a yellow and blue block: locks for twice as long)
- **reversed** (a green block: hands the node to the *other* side, so avoid it)

You get 5 + your class pulses and the droid gets 4 + its class. After ten seconds, whoever holds more
nodes wins. The droid's AI thinks faster the higher its class.

## The cast
| No. | Name | Class | Weapon |
|---|---|---|---|
| 000 | LINK PROBE | 0 | none |
| 104 | DUSTER | 1 | none |
| 152 | COURIER | 1 | none |
| 218 | STEWARD | 2 | arc zapper |
| 263 | WELDER | 2 | arc zapper |
| 307 | PORTER | 3 | none (heavy) |
| 355 | TECHNICIAN | 3 | laser |
| 408 | MEDIC | 4 | arc zapper |
| 461 | SENTRY | 4 | laser |
| 524 | SURVEYOR | 5 | laser (fast) |
| 587 | WARDEN | 5 | twin laser |
| 632 | ENFORCER | 6 | twin laser |
| 668 | BULWARK | 6 | laser (very tough) |
| 705 | TROOPER | 7 | pulse gun |
| 773 | HUNTER | 7 | pulse gun (fast, hunts you) |
| 817 | MARSHAL | 8 | plasma cannon |
| 856 | DREADNOUGHT | 8 | plasma cannon (slow, huge energy) |
| 908 | PREFECT | 9 | plasma cannon |
| 960 | OVERMIND | 9 | plasma cannon (the final droid, in the CORE of the Leviathan) |

## The ships
1. **SV CORMORANT**: Bridge, Quarters, Galley, Cargo Hold, Machine Shop, Engines (classes 1-4)
2. **MV HALCYON**: Observatory, Bridge, Sickbay, Labs, Brig, Stores, Reactor (classes 2-6)
3. **CV LEVIATHAN**: Command, Armoury, Barracks, Hangar, Foundry, Core (classes 1-9)

## Attract sequence
Leave the title alone and the game shows itself off:
1. The title: the OVERRIDE logo, a parade of droids, the high score, a scrolling ticker and the
   three-voice title theme ("Override", A minor, 150 bpm, 30 bars with bass, lead and drums).
2. A typewriter briefing, then the controls.
3. Three pages of droid files.
4. The high-score table.
5. **The AI demo**: the autopilot plays the real game for about 45 seconds. It finds the nearest
   droid, plans a route over the deck's waypoint graph (BFS), shoots weaker droids and links into
   stronger ones, plays the link duel (choosing a side and firing pulses by itself) and rides the
   lifts. Each demo visits the next ship.
6. The high scores again, then back to the title. Fire starts a game from any of these screens.

## Engine
- **Display**: mode 1, colour set 0. Rows 0-9 are the HUD; rows 10-63 show the deck as 16×9 tiles
  of 8×6 pixels.
- **Four-phase ring buffer** (low bank 3, 8K): the deck around the camera is kept pre-rendered at
  all four pixel phases, 64 rows × 32 byte columns each. Moving the camera only renders the new byte
  column (about 18K T) or pixel row (about 8K T), so scrolling is pixel smooth in all eight
  directions. Each frame the right phase is copied into the back buffer with an LDI chain
  (two runs a row for the wrap).
- **Back buffer** (upper bank 1): 40-byte rows with 4 guard bytes on each side, so sprites need no
  horizontal clipping. The IM 2 field interrupt copies it to video RAM with an unrolled stack copy
  (12.75 T a byte), starting at field sync and outrunning the beam. The HUD rows are copied only
  when they change.
- **Sprites**: 13×8 droids with the number drawn in a 3×5 font. They are pre-shifted into a
  4-phase (mask, data) cache when you enter a deck, and drawn with a POP blitter. A silhouette mode
  gives the hit flash and the link-mode pulse.
- **Droid AI**: each deck has a waypoint graph (made by the deck generator and checked for clear
  2×2 paths). Droids wander it, hunters (aggression 3) pick the waypoint nearest you, and armed
  droids check line of sight (one droid a frame, a 16-step ray march) and fire in 8 directions.
- **Player**: momentum movement in 16ths of a pixel, a 9-point box test, and corner-sliding so you
  slip through doorways.
- **Doors** slide open in two steps when anything comes near and close behind it; only the changed
  tiles are re-rendered into the ring.
- **Sound**: in play, one effects voice (pitch, volume, noise) sampled about every 800 T. It
  plays during the window copy, the idle wait and, through a table built once a frame, the
  interrupt's screen copy. The front end uses the three-voice pulse player from Dracula's Castle II
  (211 T a sample, decaying pulse widths, noise drums) in each field's idle time. Screens there
  update only their changed rows, at most 22 rows a field, so the music barely stops.
- **Speed**: in the emulator about 85% of play frames take two fields (25 fps) and the rest three.

### Memory map (mapping 7 = low bank 3 + upper bank 1)
| Range | Contents |
|---|---|
| $4000-$5FFF low bank 3 | ring buffer, 4 phases × 2K |
| $6000-$67FF low bank 3 | pre-shifted droid sprites (8 slots) |
| $7000-$77FF | video RAM |
| $7800-$7BFF | left alone (ROM/DOS system area) |
| $7C00-$7D7F / $7D80-$7FFF | IM 2 table / stack |
| $8000-$AA84 | main code (379 bytes free) |
| $AC00-$B4FF | variables, droid and shot tables, ship and deck info |
| $B500 / $B600-$B7FF | y/6 table / SD bounce buffer |
| upper 1 $B800-$C1FF | back buffer (64 × 40) |
| upper 1 $C200-$C9FF | deck map (64 × 32 tiles) |
| upper 1 $CA00-$EC63 | screen copy, tilesets, explosion, droid images, names |
| upper 1 $F600-$F87F | the deck's waypoints |
| upper 0 $B800-$E49F | front end (mapping 3): title, attract, duel, lift, console, cards, music |
| upper 0 $E800-$EFFF | front-end screen buffer |
| upper 0 $F000-$FFFF | DOS stack, sector buffer, DOS RAM (never touched) |

SD loading uses the 13 Ghosts / Dracula's Castle II / Zephyr Zone DOS calls ($5F00/$5F03/$5F09),
with the DOS mapping only during calls, interrupts off and IM 1, and a 2K DOS stack in upper bank 0.
The file format is chunks (`db map, dw dest, dw length, data`), each with the build id.

## Verification
**Only run in the emulator so far, not yet on a real VZ300.**
- The harness is `emu/vzemu.exe`, a C# rewrite of the vzemu.c harness used by the other VZ games,
  built with the `csc` that ships with Windows. It has its own Z80 core, the BennVenn banking and DOS
  traps, field-sync INT, a snow counter, PNG screenshots, WAV capture and a profiler. As a check, it
  runs the released Zephyr Zone correctly.
- Tested:
  - the whole attract loop several times over (title, briefing, files, scores, demos on ships 1 and 2
    with lift rides and link duels);
  - a real game from the title (ship card, movement, link mode, the lift, a forced link duel played
    with the keys);
  - the console;
  - deck cleared (lights out) and ship secured, then loading ship 2;
  - an 18,000-frame random-input soak with random power-on RAM: no crash and no stack creep.
- The title theme was recorded to `screenshots/title_theme.wav`; its pitch checks out (the bass
  measures A2).

**Please check on hardware**:
- Snow. In play, the interrupt's copy ends about 118 lines after field sync. Zephyr Zone's hardware
  reports suggest the picture starts around line 120, and Galahxy found no snow from writes during
  the picture, but please look.
- How the effects and the three-voice title music sound through the speaker.
- Loading every deck file from the card.
- The joystick.

## Building
```
py tools/build.py        # -> build/sd/OVERRIDE.VZ, OVCOM.DAT, OV1-3.DAT, OV1D0..OV3D5.DAT
py tools/fixjr.py src/main.asm   # (if an edit pushes a JR out of range)
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /optimize+ /out:emu\vzemu.exe /r:System.Drawing.dll emu\Z80.cs emu\VzEmu.cs emu\Font6847.cs
emu\vzemu.exe script.txt   # scripted runs: vz, sd, frames, tap, down/up, screen, wav, rand, crash, snow, tmark, prof ...
```
You need Python 3 with Pillow. The assembler is `tools/zasm.py` (from Dracula's Castle II / Zephyr
Zone). Decks are generated from seeds in `tools/ships.py` (hull, spine corridor, rooms, doors, props,
consoles, energizers, lifts, waypoint graph, connectivity checks). `py tools/ships.py` writes a
preview PNG of every deck to `build/`. The music is in `tools/music.py`, the roster in
`tools/roster.py`, and the art in `tools/gfx.py` and `tools/fedata.py`.
