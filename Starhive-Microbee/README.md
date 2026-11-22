# STARHIVE (Microbee Premium Plus)

An original vertically scrolling shoot-'em-up for the Microbee Premium Plus (1MB). You fly the **Hornet** up through the Hive across five levels, and each level ends with a boss. VIBED BY BPM 2026.

## Status: version 0.6

The disk is `release/STARHIVE.DS8`. Boot it, then type `STARHIVE` at the `A>` prompt. `docs/STARHIVE_README.TXT` has the controls and scoring.

- **Levels:** five levels, each with its own boss.
- **Scrolling:** smooth software scrolling, one line at a time, using PCG phase banks. The video timing never changes.
- **Frame rate:** 25 fps. In the heaviest scenes it drops to a steady 16.7 fps rather than stuttering.
- **Sound:** a two-voice 1-bit title tune and in-game sound effects.
- **Extras:** high-score table and a monochrome option.

Version 0.6 allows at most six enemies at once on levels 3–5, one fewer than before, to ease the load where the scenery is busiest.

Version 0.5 reworks the sprite drawer. It now goes column by column, visiting only the cells a sprite's pixels touch. Each sprite draws about 12% faster.

Version 0.4 draws bullets and shots properly over the scenery. A sprite over the scenery now keeps the scenery's main colour as its paper, and only the thin detail takes the sprite's colour. Before, cells over the scenery could turn into solid blocks.

Version 0.3 was the speed pass:

- Levels 1 and 2 now hold 25 fps almost all the time.
- Levels 3–5 average about 18–19 fps, up from about 17.

## Building

You need Python 3 with numpy and Pillow, plus gcc for the emulator.

```
python tools/build_all.py      # -> build/STARHIVE.DS8
```

`CLAUDE.md` has the full developer notes: architecture, tools, and hardware rules.

## Testing tools

- `tools/starhive_run.py` runs the game in a Premium Plus model.
- `tools/bench.py` plays each level and reports the frame rate and where the time goes.

The earlier test disks in `release/` cover the scrolling and sprite engine:

- `SCRLTEST` and `SCRLDIAG` test the scroll.
- `SOFTSCRL` tests software scrolling.
- `SHIPTEST` tests the ship and sprites.
