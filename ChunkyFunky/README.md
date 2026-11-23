# CHUNKY FUNKY
### v0.1 · a demo for the Dick Smith VZ300 · VIBED BY BPM 2026

A 2-minute demo in seven parts. The parts change on the bar lines of an original three-voice funk tune
played on the 1-bit speaker. It needs a standard VZ300 (16K) and no expansion; it also runs from the
BennVenn SD. It loops forever. **SPACE** skips to the next part.

| # | Part | Mode | Bars |
|---|---|---|---|
| 1 | Title: the CHUNKY / FUNKY logo dissolves in, colour-cycles and dissolves out | text + semigraphics | 8 |
| 2 | Plasma, 32×15 cells in 8 colours + half-tones, with a text crawl | semigraphics | 8 |
| 3 | Starfield, 56 stars, speeding up to warp | 128×64, colour set 0 | 8 |
| 4 | Wireframe cube with perspective (double-buffered, 25 Hz) | 128×64, colour set 1 | 8 |
| 5 | Sine scroller over three bouncing bars | 128×64, colour set 0 | 12 |
| 6 | Spiral tunnel | semigraphics | 8 |
| 7 | Credits rolling between colour pillars | orange text | 12 |

## Files
- `release/CHUNKY.VZ`: the demo (12.3K, loads and runs at $8000).
- `screenshots/CHUNKY_parts.png`: one screenshot per part.
- `release/CHUNKY_music_preview.wav`: the whole loop's audio, recorded in vzemu.

## Building
`py tools\build.py` makes `out\CHUNKY.VZ` (plus `chunky.sym` / `chunky.lst`). Python 3, no packages.

- `src/tools/songs.py`: the tune (64 bars; the build checks the length). `tools/music.py` is the Crownfall compiler.
- `src/tools/gfx.py`: font, logo, sine, plasma palette, tunnel tables.
- `src/src/main.asm`: the part sequencer and helpers. `src/src/music.asm`: the Crownfall player (music only).
  `src/src/parts.asm`: the seven parts.

## How it works
- Every field: the music engine ticks, then the part draws from the start of field sync. The 3-voice
  sample loop plays in the time that is left, until the next sync. **Each part must finish inside one
  field (about 45K T at most)**, because the music only ticks once per frame. The build was measured in
  vzemu with `tmark ptime` + `tstats`: every part is 1 field a frame. There are 1-2 field hiccups at
  some part changes.
- Memory: code and data $8000-$B11D, variables to $B53A, stack below $B800. WORK ($7800-$7FFF, BASIC's
  area, which is safe because the demo never returns) is shared: the title's logo buffer, the
  starfield's projection table (built during the plasma's last 40 fields) and the cube's back buffer.
- Tests: `vzemu test\full.txt` (whole loop, crash check, audio), `test\parts.txt` (each part's timing),
  `test\gallery.txt`. `spok fill_row fill_end_sp` tells vzemu's crash check that the PUSH fills are meant.

## Not yet done / ideas
- Not tried on a real VZ300 yet.
- The music pauses for a field or two at some part changes, while the part sets up.
