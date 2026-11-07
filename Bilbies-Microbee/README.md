# BILBIES! for the Microbee Premium Plus

BPM's original VZ300 game BILBIES! rebuilt for the Microbee Premium Plus.
It needs the Premium Plus's 32K of PCG RAM and 1 MB of memory.

The rules and the 24 levels are the VZ300 original's, unchanged: the
game logic is the original `game.asm`, and a test checks every bilby on
every level, tick by tick, against the VZ code. Everything else is new
Microbee code:

- **Real bitmap playfield.** The top ten rows of a 64 × 16 screen are
  512 × 160 pixels, and every cell has its own PCG glyph. Two pages are
  flipped with the 6545's start address.
- **Double-resolution levels.** Each level is drawn at twice the VZ
  size (1024 × 160) with its own colour map. The original 512 × 80
  collision mask drives the rules.
- **Smooth play.** The screen updates at 25 frames a second, with
  positions interpolated between the 12.5 Hz game updates. It scrolls
  8 pixels at a time.
- **Colour or amber/green mono.** Choose at start-up or in Settings; the
  choice is saved. Mono has its own art, not a colour picture made grey.
- **Controls.** Keyboard, joystick and the Microsoft serial mouse.
- **Sound.** The VZ's sound effects, plus its three-voice music: Grieg's
  "In the Hall of the Mountain King" on the title, and jingles.
- **Saves to its own disk.** Progress and settings go to `SAVE.DAT` on
  the game disk. Missing saves, write protection and disk errors are
  handled.

## Running it

`build/BILBIES.DS8` is a DS80 disk image (80 tracks, 2 sides, 10 × 512
sectors) that boots to CP/M's `A>` prompt, with no Shell. At the prompt type:

    BILBIES

and press RETURN. The game loads in about 24 seconds. Choose C (colour)
or M (mono) for your monitor.

| Action | Keys |
|---|---|
| Move the cursor | arrow keys, Q A O P, joystick, or the mouse |
| Give the skill to the bilby under the cursor | SPACE, RETURN, M, joystick fire, or left mouse button |
| Choose a skill | 1–8, Z / X (previous / next), right mouse button (next), or click a panel button |
| Release rate | , or - (slower), . (faster), or the panel's - + buttons |
| Pause | H |
| Bomb all (press twice) | N |
| Give up the level | ESC |

On the title, S opens Settings (monitor, sound effects, and K for music)
and T toggles the trainer (every level open).

## Building

You need Python 3 with numpy and a C compiler (gcc). From `tools/`:

    python3 build.py            # everything: art, levels, program, loader, disk
    python3 build.py --quick    # skip re-packing the levels

The output goes to `build/`. The assembler (`tools/zasm.py`) and the
Premium Plus emulator used for testing (`tools/emu`, `tools/mbee.py`) are
part of the project.

## Tests (in the emulator model)

| Script | What it checks |
|---|---|
| `test_levels.py` | All 24 levels played by their original solutions: every one won |
| `compare.py N` | Level N against the VZ300 rules (`tools/vzref`), every bilby, every tick |
| `boottest.py bn60.rom` | Boots the disk image from the Microbee ROM, runs `BILBIES`, and plays (needs your own ROM file) |
| `savetest.py` | Save and reload, write protection, a damaged record, no `SAVE.DAT` |
| `mousetest.py` | Mouse movement and panel clicks |
| `sndtest.py`, `sfxwav.py` | Sound pitch, and a WAV of every effect |

See `docs/VERIFICATION.md` for what was and wasn't tested, and
`docs/HANDOVER.md` for how it all works.

Microbee code and graphics by Claude (Anthropic), 2026, from BPM's
original game.
