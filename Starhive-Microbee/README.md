# STARHIVE (Microbee Premium Plus)

An original vertically scrolling shoot-'em-up for the Microbee Premium Plus (1MB). You fly the **Hornet** up through the Hive across five levels, and each level ends with a boss. VIBED BY BPM 2026.

## Status: version 0.3

The disk is `release/STARHIVE.DS8`. Boot it, then type `STARHIVE` at the `A>` prompt. `docs/STARHIVE_README.TXT` has the controls and scoring.

- **Levels:** five levels, each with its own boss.
- **Scrolling:** smooth software scrolling, one line at a time, using PCG phase banks. The video timing never changes.
- **Frame rate:** 25 fps. In the heaviest scenes it drops to a steady 16.7 fps rather than stuttering.
- **Sound:** a two-voice 1-bit title tune and in-game sound effects.
- **Extras:** high-score table and a monochrome option.

Version 0.3 is the speed pass:

- Levels 1 and 2 now hold 25 fps almost all the time.
- Levels 3–5 average about 18–19 fps, up from about 17.

## Building

Python 3 with numpy and Pillow.

```
python3 tools/mklevels.py        # levels, sprites, tables -> build/
python3 tools/mkwaves.py         # enemy waves and bosses
python3 tools/mkmusic.py         # title tune
python3 tools/mk_starhive_disk.py   # assembles the game and loader -> build/STARHIVE.DS8
```

## Testing tools

- `tools/starhive_run.py` runs the game in a Premium Plus model.
- `tools/bench.py` plays each level and reports the frame rate and where the time goes.

The earlier test disks in `release/` cover the scrolling and sprite engine:

- `SCRLTEST` and `SCRLDIAG` test the scroll.
- `SOFTSCRL` tests software scrolling.
- `SHIPTEST` tests the ship and sprites.
