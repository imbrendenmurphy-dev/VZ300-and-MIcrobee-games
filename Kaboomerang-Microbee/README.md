# KABOOMERANG

An original Bomberman-inspired arcade game for the **Microbee Premium Plus** (1MB RAM, 32K PCG). Wally the demolition wombat takes his gumnut bombs and his lucky boomerang across the outback to stop Baron Von Croak, the cane toad tycoon paving the bush into car parks.

**ViBED by BPM 2026**

![title](screenshots/01_title.png)

## Status: engine build 0.1

The first Z80 build, running in the 40 × 25 mode with 8 × 8 cells that BPM's mode test proved on the Premium Plus. World 1, Red Centre, is playable stage after stage.

- **The 40-column mode:** the CRTC table matches BPM's MODES.COM test exactly, apart from the row count. MODES.COM needs no extra clock switch; the CRTC registers alone give the 40-column mode.
- Tested in the emulator model only so far. The first real-hardware run is next.

![explosion](screenshots/02_explosion.png)

## What's in this build

- **The display:** 40 × 25 cells of 8 × 8 pixels, 320 × 200, near-square pixels. The arena is 19 × 11 tiles of 2 × 2 cells, each cell with its own ink and paper.
- **The engine** (from HULLBREACH and AUSOPEN):
  - Two screen pages flipped in vertical blanking, with a sprite-glyph bank per page.
  - Sprites are pre-shifted, masked and composited into private glyphs. They move smoothly in 2-pixel steps at 25 frames a second.
- **Wally:**
  - walks in four directions
  - blinks, looks around and taps a foot when idle
  - crouches to set a bomb, and his hat jumps at a nearby blast
  - hops on a power-up, goes dizzy when hit, does a victory dance and gets flattened
- **Bombs:**
  - Fuses pulse, then flash red in the last second.
  - Flames have centre, arm and tip shapes in three phases plus smoke.
  - Bombs set each other off in chain reactions.
  - Termite mounds crumble in nine stages with debris.
  - **Blast preview:** floor in a bomb's path is hatched red during its last second.
- **The Kaboomerang:** flies four tiles and comes back. It stuns wildlife and fetches power-ups, and it picks up a lit bomb and drops it at the end of its flight.
- **Burrows:** stand in one and blasts pass over you.
- **Wildlife:**
  - **Cane toads** hop and squat.
  - **Frill-necks** flare up and sprint when they see Wally down a lane.
  - **Bin chickens** go for power-ups, steal them and run away. Blast one and the item drops back.
- **Power-ups:** gumnuts (more bombs), fire (bigger blasts), hearts, thongs (speed). Find the hollow log to clear the stage.
- **Forgiving play:**
  - three hearts out of five
  - flashing safety after a hit
  - corner sliding and remembered taps
  - unlimited continues that keep your power-ups
- **Monochrome:** choose C or M at start-up. Mono uses inverted patterns where needed, and the HUD shows empty hearts and missing power-ups by shape, not colour.
- **Sound:** a two-voice beeper engine with an original title tune, slow in-game blips, jingles and effects.

![amber mono](screenshots/05_amber_mono.png)

## Play it

`release/KABOOM.DS8` is a DS80 disk image (80 tracks, 2 sides, 10 × 512 sectors). It boots to CP/M's `A>` prompt with no shell. Type:

    KABOOM

Press **C** for a colour monitor or **M** for monochrome.

| Action | Keys |
|---|---|
| Move | arrow keys or Q A O P, or a joystick |
| Gumnut bomb | SPACE / fire |
| Throw the Kaboomerang | X (or Z, B), or fire when no bomb can go down |
| Pause, sound, back to the title | H, S, ESC |

## Build

Python 3 with numpy and Pillow, and gcc (for the emulator model). From `src/`:

    python3 tools/build.py

This writes `build/KABOOM.DS8`. Tests:

| Script | What it does |
|---|---|
| `tools/soak.py` | Plays random inputs and checks for crashes |
| `tools/mechtest.py` | Checks that a bomb beats a toad and the boomerang carries a bomb |
| `tools/stagetest.py` | Clears stages one after another |
| `tools/perf.py` | Measures the frame rate and profiles the code |
| `tools/shoot.py` | Takes screenshots |

## Files

| Path | What it is |
|---|---|
| `src/` | Z80 source (`src/src`), art and build tools (`src/tools`) |
| `mockup/kaboomerang.html` | The browser design mockup |
| `docs/DESIGN.md` | Game design and technical plan |
| `docs/BRIEF.md` | BPM's brief |

The test emulator in `src/tools/emu` uses a Z80 core that looks like superzazu/z80 (MIT). It is only used for testing.
