# SPINDRIFT — what was tested, and how

All testing so far is in the **raster-accurate Premium Plus model** in `tools/emu` (the one built for the Microbee megademo). It models the 6545 scanline by scanline, including the CPU being held on video RAM access during a drawn line, the 40-column dot clock select, the keyboard's light-pen scan, PIO A (joystick), the speaker, the WD2793 and the 1 MB memory map.

**Not yet run on a real Premium Plus.**

## Configurations tested

| Configuration | How | Result |
|---|---|---|
| Premium Plus, 1 MB, 32K PCG, colour monitor | every test below | pass |
| Same, **monochrome** (M at start-up or on the title) | front-end test, screenshots with the amber monitor | pass |
| **Keyboard** only | all tests | pass |
| **Joystick** on PIO A | start on fire, steering (front-end test) | pass |
| Disk: `SPINDRIFT.DS8` (DS80) | loader test | pass, apart from the ROM boot (below) |

## The tests

| Test | What it checks | Result (final build) |
|---|---|---|
| `tools/fronttest.py` | Monitor question, the screen-shape screen (Z widens the ring), title, the title playing SWIRL, the attract cycle (hall of fame, how to play, demo), joystick start, joystick steering, pause shows and freezes everything, unpause, R restarts with a fresh score, a real game over with no help, initials into the table, back to the title, M for monochrome and the shape screen again | **20 of 20** |
| `tools/playtest.py --god` | A scripted pilot flies the whole campaign: 8 sectors, 4 Guardians, 4 Chance Stages, into the second lap, with no hang | pass (900 s of play) |
| `tools/loadertest.py` | The disk's directory and every file byte for byte; `SPIN.COM` run off the image with a stand-in for CP/M's file calls; the loader finds CP/M's bank, passes its 1 MB check, stages every file, copies the program to 8000h intact and starts the game | pass |
| `tools/perf2.py` | Frame rate, commit length and cells in the busiest wave of every sector and every Guardian | 24.6 fps, 97.0% of frames on time |
| Sound timing | SWIRL: 59.3 ticks a second, the title's gap 2.1% of a tick. In the game: 263.5 T a sample (pitch within 0.2% of the tables), 91 samples a typical frame | as designed |
| Sound checks | Silence between effects measured at -170 dB or below (no frame-rate buzz); spectrograms of every effect (dives fall, wuckas swing, the warp climbs) | pass |
| Warp countdown | 4, 3, 2, 1 WARPS TO COMET LANES, then 4 WARPS TO CINDER GATE | pass |
| Flash checks | 9 flashes in a Guardian fight with real damage: no HUD corner cell is ever on flash paper (even mid-flash); the sides of the middle rows do flash; messages and the core get their colours back | pass |
| HUD | Read back as text: SCORE / HI top left; SECTOR n, the name a word a row, LAP 2 top right; SHIELD bottom left; WARPS and the count (CORE and its bar in a Guardian fight) bottom right | pass |

## Not tested here

- **The boot itself.** The Microbee boot ROM isn't included, so the step from the boot ROM to CP/M's `A>` couldn't be run. The system tracks and `CCP.SYS` are the same as on the earlier Premium Plus disks (Kaboomerang, Australian Open Tennis, FrillSeeker), and the loader is the same one those use.
- **Real hardware**: picture position, the 40-column mode on BPM's monitors, the joystick interface, how the sound sounds through the real speaker.

## Worth checking on the real machine

1. The disk boots and `SPIN` loads (dots while loading, then the monitor question).
2. The picture is full width and steady in both colour and on the amber monitor.
3. Sweeping feels tight on Z / X and on the stick.
4. A Guardian fight (sector 2) stays smooth.
5. Tapping H, R and S always registers.
6. The screen shape: which of the eight settings makes the ring round on each of your monitors (and whether the default, the third, suits the amber CRT).
7. How "Spiral Arms" and the new effects sound through the real speaker.
