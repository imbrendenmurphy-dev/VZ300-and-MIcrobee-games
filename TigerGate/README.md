# TIGER GATE

A martial arts adventure for the Dick Smith VZ300, in the spirit of Karateka.
Target: VZ300 + BennVenn SD loader + 128K SRAM. Mode 1 (128x64, 4 colours) throughout.
VIBED BY BPM 2026

Kurokage's raiders burned the dojo at Three Pines and dragged old Master Hoshi to the
fortress beyond the Tiger Gate. Ren, his last student, follows. Alone. Barehanded.

## The campaign

| # | Stage | Opponents | What it teaches |
|---|---|---|---|
| 1 | The Rope Bridge | two Bridge Keepers (straw hats) | spacing: kicks reach one step further |
| 2 | The Outer Court | three Court Guards in turn (horned helmets) | strike during the wind-up |
| 3 | The Lantern Hall | the Lantern Monk, kneeling until you come close | he guards and counters: make him move first |
| 4 | The Cliff Path | falling boulders, then the Cliff Scout (flying-kick entrance, hit and run) | stop when a green shadow appears |
| 5 | The Inner Gate | two guards then the Gate Oni (slow, heavy, long wind-ups) back to back | endurance |
| 6 | The Tiger Throne | Kurokage: feints, flurries, gets faster when hurt | wait for the real blow |

Story scenes: the opening (the dojo burns), Kurokage before the Lantern Hall, Master Hoshi
caged before the final duel, the ending at sunrise, a cast roll and the credits.

## Presentation

- Layered scenery: far layer (sky, sun, mountains, pagodas) scrolls at quarter speed,
  mid layer (walls, railings, pillars, trees) at full speed, and a perspective floor
  (planks, tiles, boards, rock, stone slabs, chequerboard) whose lines converge and slide.
- Animated details: waterfall (bridge), stone-lantern flames (court), hanging lanterns
  (hall), torches and waving banners (inner gate). Petals, leaves and embers drift through
  the fight band.
- Fighters have blue outlines so they read against any background; each opponent has its
  own silhouette (straw hat, horned helmet, monk's robe, hood, oni mask, crested helmet and cape).
- Hit pauses, recoil, knock-back, a screen flash on counters and knockouts, beeper effects
  for swishes, blocks, hits, counters, gongs, heavy footsteps, rumbles and knockouts.

## Controls

| | High | Mid | Low |
|---|---|---|---|
| Punch | Q | A | Z |
| Kick | W | S | X |

M back, comma forward (hold forward to run when the way is clear), N guard, B bow,
SPACE stance. Joystick: fire punch, arm kick, both guard, up/down aims high/low.
Title: D difficulty, M music, E effects, S starting stage (stages you have reached this session).

Catching an opponent during his wind-up or recovery is a counter (extra damage, flash).
A clean duel (no hits taken) doubles the points; a stage with no retries earns a bonus.
Health creeps back while you go unhit. A knockdown offers an instant retry of that duel.

## SD card files (all in one folder)

    TIGRGATE.VZ      launcher, engine, Ren's frames, font, music  (loads at $8000)
    TGFRONT.DAT      title picture and opening scene
    TGFOES1-6.DAT    each stage's opponent frames (copied into SRAM bank B at $4000)
    TGSTAGE1-6.DAT   each stage's scenery layers, floor, animations, AI levels, script, scene
    TGEND.DAT        ending picture and cast portraits

Every data file carries a "T?" header, number and checksum. If one is missing or damaged
the screen shows its name: fire retries, Q returns to the title.

High scores and stage unlocks are kept for the session only (SD writes are not used).

## Real VZ300 checklist

1. Boots to the title; tune plays; D / M / E / S change the option line.
2. Opening scene and story, then each stage card shows the opponent while it loads.
3. Scrolling: far layer moves slower than the walls; the floor lines slide; no tearing in
   the top half when running (the top is redrawn in the blanking only when it changes).
4. Joystick directions and both buttons together for guard.
5. Stage 4: boulders fall where the green shadow appears.
6. Rename a .DAT file and check the error screen.
7. Sound during play (short blips, hits, gongs) and how long each stage takes to load.

## Technical

- No interrupts; the loop syncs to field sync on the latch: 25 game ticks a second.
- Memory: vars/stack $7800-$7FFF, resident $8000-$B9BF, pack $C800-$E7FF, buffers
  $E800-$EE5F, DOS stack $F7F0 during loads, sector buffer $F800. Nothing at $FA00+.
- SD loading calls the DOS exactly as Graves 'n' Gargoyles does ($5F00/$5F03/$5F09).
- Screen rows 0-19 come straight from the far layer, rows 20-31 are far and mid layers
  composited (blue in the mid layer is see-through), rows 32-57 are a 48-byte-wide work
  band with masked sprites, rows 58-63 the health bars and score.

## Build

    python3 tools/build.py           ->  build/sd/   (release)
    python3 tools/build.py 1 N       ->  build/AUTON.VZ  (autoplay test build starting at stage N)

tools/z80asm.py, tools/mkvz.py and emu/vzemu.c come from Graves 'n' Gargoyles.
