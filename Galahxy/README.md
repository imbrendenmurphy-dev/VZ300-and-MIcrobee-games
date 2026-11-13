# GALAHXY

An original Parodius / Fantasy Zone-style horizontal shoot 'em up for the **Dick Smith VZ300**
with the **BennVenn SD loader + 128K SRAM** expansion.

VIBED BY BPM 2026

This is the **vertical slice**: one complete stage, PARTY PLANET, with the title, attract demo,
cast select, power-ups, a shop, both routes, the midboss, the boss, the stage-clear tally and the
high-score table. [DESIGN.md](DESIGN.md) covers how the full game is planned and why.

![GALAHXY screens](shots/contact-sheet.png)

## Running it

1. Copy the three files from `release/` to the **root of the SD card**:
   `GALAHXY.VZ`, `GLXCOM.DAT`, `GLXS1.DAT`.
2. Load `GALAHXY.VZ` the way you load any other .VZ (from VZ-DECK or the DOS).
   It loads at $8000, then loads `GLXCOM.DAT` and `GLXS1.DAT` itself.
3. Always copy all three files together. Each build stamps its files, and a mismatched set stops
   with `GLX*.DAT FILES DON'T MATCH` instead of crashing.

If the expansion isn't there, the game says `NEEDS BENNVENN SD + 128K RAM`.

## Controls

| | Keyboard | Joystick |
|---|---|---|
| Move | Q up, A down, O left, P right (Z and X also go left and right) | stick |
| Fire (hold) | SPACE | fire |
| Power up / buy | M (or B) | arm button |
| Pause | RETURN | |
| Music on/off | N | |

On the cast-select screen: left/right picks a flyer, up/down sets the skill level, and **T**
toggles TRAINER (endless lives, no high score). The joystick is found automatically.

## How it plays

**The cast**: three flyers, three weapons.

- **GAZZA THE GALAH**: spreading seeds that fan wider as SHOT goes up. Bomb: macadamias that drop
  and roll along the ground.
- **CAPTAIN CUPPA** (a flying teapot): a steam beam that passes through small fry. Bomb: tea bags
  thrown up and down.
- **TOASTIE** (a flying toaster): heavy toast fired forward *and* backward. Bomb: Vegemite seekers.

**Powering up, Parodius style.** Shooting a red balloon, or a whole formation, drops a **PAV**
(pavlova). Each PAV moves the cursor along the bar at the bottom: SPEED, BOMB, SHOT, BUDDY,
SHIELD. Press M (or the arm button) to take the lit power, or save up PAVs for a bigger one.
Maxed slots go dark.

**Shopping, Fantasy Zone style.** Enemies drop **coins**: every ground enemy drops one, and
flyers drop one now and then. Touch the floating **S balloon** to open the shop. It sells speed,
bombs, a bigger shot, buddy chicks, a bubble shield, cupcakes (hearts) and extra lives.

**Forgiving by design.** Each life has three hearts. Losing a life costs one level of SHOT, BUDDY
and SPEED (not everything), and two PAVs float out so you can power straight back up. Continues
pick up from where you fell.

**Scoring.** Quick kills build a chain (up to x8). Wiping out a whole formation pays a bonus.
Coins are worth 200 x chain. The stage-clear tally adds a no-hit bonus, best chain, coins and
secrets.

## Stage 1: PARTY PLANET

The party snacks have come alive. You fly past candy-cane railings, lollipops, mushroom houses
and floating cake islands, fighting jellybeans, party poppers, party penguins, beach balls and
candy cannons.

- **Midboss, THE CAROUSEL**: a runaway merry-go-round drops in and flings streamers and wooden
  horses. When it's hurt it spins faster, swings wider and *flashes and creaks* before each
  three-way volley. Hit the hub.
- **The fork**: a sign at the balloon arch. Be **high** as the arch passes to take the
  **CLOUD TOPS** (coin trails, hopping party bunnies, penguins). Be **low** for the
  **LOLLY GARDEN** (candy cannons, gift boxes with cupcakes, gingerbread men). Shoot three
  gingerbread men there and a **golden one** turns up, worth a 5,000 secret bonus.
- **Boss, KING WOBBLE**: a giant jelly in a crown, who arrives with "PARDON ME. IS THIS THE
  PARTY?" and then gets serious.
  - Phase 1: he lifts his crown (the tell), then lobs three jelly blobs.
  - Phase 2: his eyes go angry and he lines up with you (the tell), then fires a giant spoon
    across the screen.
  - Phase 3: he loses his crown and rains jelly blobs, firing fans of shots.

Clear the stage and the next round begins, hotter.

## Building

You need Python 3 (with Pillow, for the preview tools only) and a C compiler for the emulator.

```
python3 tools/build.py              # -> build/sd/GALAHXY.VZ, GLXCOM.DAT, GLXS1.DAT
gcc -O2 -o emu/vzemu emu/vzemu.c emu/z80.c
python3 tools/mkscr.py demo && emu/vzemu emu/demo.scr   # scripted emulator run
```

The assembler is `tools/zasm.py`, a two-pass Z80 assembler in Python. The art, scenery, logo, font
and music are all generated from the Python files in `tools/`.

| File | What |
|---|---|
| `src/main.asm` | boot, memory checks, and the layout of all three output files |
| `src/sys.asm` | IM2 interrupt, double-buffered split screen copy, input, joystick |
| `src/blit.asm` | masked pre-shifted sprite blitter (fast path, plus a clipping path) |
| `src/scroll.asm` | 1-pixel scrolling ground band and half-speed skyline from 4-phase rings |
| `src/objects.asm` | enemies, bullets, collisions, timeline, scoring |
| `src/player.asm` | the three flyers, weapons, buddies, power bar |
| `src/game.asm` | game flow, stage cards, tally, continue, attract-mode autopilot |
| `src/fe.asm` `src/hiscore.asm` `src/shop.asm` | title, cast select, high scores, name entry, shop |
| `src/stage1.asm` | PARTY PLANET: types, timeline, routes, CAROUSEL and KING WOBBLE |
| `tools/sprites.py` `scenery.py` `sound.py` `logo.py` | the art, scenery, music and logo |
| `emu/` | the test emulator (VZ300 + BennVenn mapper + DOS file calls) and test scripts |

## What has been tested

All testing so far is in the emulator in `emu/`: a VZ300 model with the BennVenn mapper (port $37),
the DOS file calls trapped, a 312-line PAL field and the 6847 timing measured on your machine.
Scripted runs covered:

- boot, title, attract demo and high-score cycle
- cast select, trainer toggle, a full stage with the autopilot (both routes), the shop and buying
- midboss and boss kills, the stage-clear tally, round 2
- game over, continue countdown and name entry
- a 32,000-frame random-input soak with the DOS RAM scrambled and RAM randomised, with no crash

**It has not been run on a real VZ300 yet.** The memory map, mapper settings and DOS calls follow
what your machine has already confirmed (see DESIGN.md), but the first hardware run is the real
test. Please check: does it boot and load both .DAT files, does the joystick work, and is the
speed and sound OK.

## Saved scores

The high-score table lives in the expansion's SRAM. It survives going back to VZ-DECK and
reloading the game, but not a power-off. Writing to the SD card hasn't been proven reliable on your
DOS, so the game doesn't write to the card.
