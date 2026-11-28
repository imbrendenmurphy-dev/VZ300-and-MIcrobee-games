# Verification report

Most testing was done in an emulator model of the Premium Plus, written
for this project (`tools/emu/mbee.c`, `tools/emu/z80.c`). The model
follows uBee512's behaviour for the parts the game uses, but it is not
uBee512.

**Real hardware (7 Nov 2026).** The user's Premium Plus, loading the disk
image from SD, with an amber mono monitor:

- The disk boots, `BILBIES` loads, and the mono picture and HUD display
  correctly.
- The attract-mode gameplay ran fine.
- The title was very choppy. In the model, a third of the title frames
  took 3 fields instead of 2 while music played. This is fixed: with
  music on, the title now draws at a steady 12.5 frames a second.

## Tested in the model

| Area | Result | How |
|---|---|---|
| Rules | All 24 levels identical to the VZ300 original, every bilby every tick, to the end of each level | `compare.py 1..24` against the original `game.asm` assembled alone (`tools/vzref`) |
| Levels | 24 of 24 won by their original solutions | `test_levels.py` (`docs/level_results.txt`) |
| Disk boot | The Microbee boot ROM (the user's `bn60.rom`, not included) boots `BILBIES.DS8` to `A>`. `DIR` lists the files with no Shell; `BILBIES` loads in about 24 s; colour chosen, title, level select, briefing and play all run | `boottest.py` |
| Saving | Save then reload gives back levels open, last level, monitor, sound and music. A write-protected disk is reported as write protected and not written. A damaged record falls back to the defaults. A disk without `SAVE.DAT` gives the defaults, reports an error and is never written | `savetest.py` |
| Mouse | Microsoft serial packets through PIO B (uBee512's wiring): cursor moves, a panel click selects a skill, no lost bits during play | `mousetest.py` |
| Joystick, keyboard | Keys read through the 6545 light-pen scan; joystick on PIO A | used by the tests above |
| Mono | Renders with its own mono art (screenshots) | `run.boot(..., mono=True)` |
| Sound effects | All 11 effects sound. Tones from 180 Hz to 1.5 kHz are within about 10% of the VZ pitches; the highest (the 1.9 kHz clink) is about a third flat | `sndtest.py`, `sfxwav.py` (`build/sfx.wav`) |
| Music | Plays on the title about half the time (the scene runs in between, as on the VZ; the title draws at 12.5 fps while music plays), and in the menus and jingles | `build/title_music.wav` |

## Speed

The game is meant to run at 12.5 updates a second (4 fields each). In
the model, after the speed work of 7 Nov:

| Levels | Fields an update, colour | Fields an update, mono | Speed |
|---|---|---|---|
| 1–20 | 4.0–4.5 | about the same | 90–100% |
| 21–22 | 4.4–4.7 | 4.4–4.6 | about 87% |
| 23–24 (30–40 bilbies) | 5.2–5.4 | about 5.1 | about 77% |

The game logic never skips, so it plays correctly but slows down when
the screen is busy. When it falls behind, it draws fewer in-between
frames.

## Not tested

- On real hardware, not yet tried: saving (including write protect), the
  mouse, the joystick, sound, and colour monitors.
- A real DS80 drive. The image layout matches the Microbee's DS80 format
  used by the boot ROM in the model; the user loads images from SD.
- Joystick hardware variants.
- Mouse in the title and menus while music plays. The music stops when
  the mouse line changes, so the mouse should keep working, but this
  path has only been reasoned about, not tested.

## Known limits

- **Colour clash.** A cell has one ink and one paper. Where bilbies walk,
  the cells they touch are turned yellow, so a ledge under a stream of
  bilbies shows yellow cells.
- **Grass gaps.** Where the ground surface dips a row or two into a cell,
  that cell shows plain dirt, leaving small gaps in the grass line.
- **Scrolling.** 8 pixels a step.
- **Mouse during music.** Packets are lost while the music plays (it
  runs with interrupts off), until the music notices the mouse and
  stops for about a second.
