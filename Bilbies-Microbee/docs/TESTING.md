# Executed tests — 2026-11-02

Environment: Windows, Python 3.12.14, sjasmplus 1.20.3, upstream ZX0 Windows
compressor; z80 1.2.0 CPU core with adapted repository ppmodel. 3.375MHz
Z80, 32 x 32K RAM blocks, 16 x 2K PCG banks. No ColdFire modeled.

## Results

- Native engine and CP/M loader assemble with zero errors. Six inherited
  generated empty-string warnings remain.
- All 24 level maps plus title: zero terrain-colour or collision-mask pixel
  differences against original lvlkit.raster. Repeated after final input/save
  edits; report in reports/verification.json.
- All 24 original solution scripts reached completion and met quota with
  only mb_present replaced by RET. This run preceded the final key mapping,
  interrupt-disable and save read-back checks. Original game.asm and renderer
  logic were unchanged by those final edits. Results below record actual
  console output; these are not performance or input-interaction tests.
- First original solution with native presentation enabled: level 0 saved
  6, quota 5, reached completion. 945680389 modeled T-states including startup.
  This preceded the same final minor edits. Screenshot and JSON captured.
- Actual owner BN60 ROM + CP/M system from the disk: booted to A>, typed
  BILBIES, reached startup settings, then native title. Repeated on final DS8.
- Disk save/restart restored mono=1, unlock=8, level=7. Write-protected disk
  returned failure and changed no disk bytes. Deleted SAVE.DAT entry was
  refused despite old signature bytes remaining. Repeated on final build.
- QAOP, arrows, Space, keys 1–8 and PIO A joystick direction/fire translation
  checked by executing native routines and asserting results on final build.
- Raw DS8 size, file round-trip extraction and no Shell entry checked by
  disk builder. Format compatibility is established only for this ROM/model
  path, not an independent emulator or physical media.

| Level index | Name | Saved | Required |
|---|---|---:|---:|
| 0 | Burrow Down | 6 | 5 |
| 1 | Up the Bank | 12 | 9 |
| 2 | Red Rock Wall | 15 | 10 |
| 3 | Gum Tree Gully | 10 | 7 |
| 4 | Wait Here | 19 | 15 |
| 5 | Sloping Off | 15 | 10 |
| 6 | Dripstone Hall | 20 | 14 |
| 7 | Crystal Ladder | 20 | 16 |
| 8 | Underground Creek | 15 | 11 |
| 9 | Boom Gate | 19 | 15 |
| 10 | Echo Chamber | 20 | 15 |
| 11 | Long Way Down | 15 | 11 |
| 12 | Moonlit Ruins | 12 | 10 |
| 13 | The Jetty | 19 | 15 |
| 14 | Stone Tower | 20 | 16 |
| 15 | Two Ways Home | 22 | 18 |
| 16 | Sinking Feeling | 20 | 15 |
| 17 | Night Shift | 30 | 24 |
| 18 | Red Centre | 30 | 27 |
| 19 | Termite Towers | 30 | 25 |
| 20 | Billabong | 30 | 24 |
| 21 | Crystal Caverns | 25 | 20 |
| 22 | Thunder Gorge | 29 | 26 |
| 23 | The Last Burrow | 40 | 34 |

## Limits

The renderer misses the frame budget by a large margin: see HARDWARE.md.
The game clock still counts logical loop frames, so wall-clock timing is
not preserved. Prototype sound is stubbed. A uBee512 CLI launch attempt did
not produce a usable test and was stopped; it is not a pass. No hardware,
ColdFire execution, mouse, enhanced art, genuine per-pixel scrolling,
disk-full injection or sustained real-input gameplay has been verified.

The monochrome title capture shows meaningful contrast patterns but also
faint patterned lettering; the final artist/renderer must address that.
