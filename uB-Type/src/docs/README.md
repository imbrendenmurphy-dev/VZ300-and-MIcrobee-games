# μB-TYPE (work in progress)

μB-TYPE is the Microbee Premium Plus conversion of **VZ-TYPE**, BPM's original R-Type-inspired horizontal shooter for the VZ300.

Directed and playtested by BPM. Code, graphics and music by Claude (Anthropic).

**Status: in development, no playable disk yet.** This folder is updated as work goes on.

## Done so far

- **Engine prototype, measured.** The game runs on the Premium Plus at 64×16 characters of 8×16 PCG cells (512×256 pixels, exactly 4× the VZ300's 128×64). Scrolling uses the 6545 start address with two screen pages and pre-shifted glyphs: one VZ pixel (4 Microbee pixels) per frame, as on the VZ. Pages flip in vertical blank, so there is no tearing. In the emulator's measurements under the same firing script, it averages 21.7 frames per second against the VZ300 original's 21.4.
- **VZ-TYPE game logic ported.** Player, pod, weapons, enemies, bosses, scoring and level data come from the VZ source. A frame-by-frame comparison against the original running in a VZ300 model shows the same game state on every frame checked (4,000 frames).
- **New artwork.** All eight stages have new terrain, sprites, capsules, explosions and boss bodies drawn for the PCG display.
- **Monochrome mode.** Each stage has a second glyph set drawn for a monochrome monitor (outlined shapes, patterned shading instead of colour).

## Still to do

- Title screen, attract sequence with a gameplay demo, information pages, stage intro, game over, name entry and congratulations screens
- Music (the VZ tunes, retimed for the Microbee)
- CP/M loader and the DS8 boot disk (boots to the CP/M prompt, no shell)
- Full verification report

## Screenshots (emulator)

- `screenshots/wip_colour_stages.png`: six stages in colour
- `screenshots/wip_mono_stages.png`: the same in monochrome mode
- `screenshots/wip_colour_vs_mono.png`: colour and mono side by side

Testing so far is in an emulator only (the Premium Plus model in `src/tools/emu`), not on real hardware.

## Building

Needs Python 3 with numpy and Pillow, plus a C compiler for the test emulator. Run `./build.sh` from `src/`. The outputs go to `src/build/`.
