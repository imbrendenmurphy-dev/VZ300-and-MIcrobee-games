# VZ FLIGHT SIMULATOR

An FS1-style wireframe flight simulator for the Dick Smith **VZ300** with the **BennVenn SD loader + 128K**.
Mode 1 (128 × 64, four colours). VIBED BY BPM 2026.

## Status: v0.1 engine prototype (work in progress)

- Full 3D view: rolled horizon fill, ground grid, clipped wireframe scenery (runways, hangars, mountains, a lake, a town)
- Light-aircraft flight model: throttle, pitch, bank-to-turn, stall, takeoff and landing, crash detection
- Instrument panel: speed (knots), altitude (feet), heading, throttle, vertical speed, status
- About 4 frames per second in the emulator (FS1 ran at about 3–5)

v0.2 (in progress) adds locales, missions, a helicopter, the attract sequence and a tribute to Dick Smith the aviator.

## Loading

Copy `release/VZFLIGHT.VZ` to the SD card and run it. It loads at $8000, makes no mapper writes and doesn't call the DOS.

## Controls (v0.1)

| Key | |
|---|---|
| Q / A | nose up / down |
| M / , | bank left / right |
| W / S | throttle up / down |
| SPACE | wheel brakes |
| R | restart |

Joystick 1 works too (fire = throttle up, second fire = throttle down).

## Building

`python3 src/build.py` (pure Python: it includes its own Z80 assembler). `src/cmp.py` renders test views with the Z80 code and with a floating-point reference renderer side by side.
