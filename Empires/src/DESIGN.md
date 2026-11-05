# EMPIRES : THE LIVING WORLD
*An original civilisation / city-building game for the Microbee Premium Plus — ViBED by BPM 2026*

Milestone 1 build. Launch from the DOS prompt: `A>EMPIRES`

---

## Playing

At start-up choose **C** (colour monitor) or **M** (monochrome monitor). Change any time in game with **C**.

| Key | Action |
|---|---|
| Mouse, arrows, W A S D, I J K L or joystick | Move the tile cursor (SHIFT = faster). The view scrolls at the edges. Left button builds, right button picks the next tool |
| SPACE / RETURN | Build the selected tool at the cursor |
| 1–9, 0 | Tools: 1 Road · 2 Hut · 3 Farm · 4 Woodcutter · 5 Quarry · 6 Well · 7 Market · 8 Windmill · 9 Watchtower · 0 Clear |
| TAB | Cycle tools |
| M | World map (W A S D moves the view, M/SPACE returns) |
| P | Pause / resume · `,` slower · `.` faster |
| H | How to play |
| ESC | Leave the world (asks Y/N) → title → ESC exits to DOS |

**How it plays.** You start with a town hall and six settlers in a fog-shrouded world. Each week the town works:
farms plough nearby grass into fields that yield most in autumn and nothing in winter; woodcutters and quarries
produce according to the forest or hills around them; everyone eats. Production buildings need workers.
Huts with a road beside them, a well nearby and happy people grow into houses; houses near a market grow into
manors. You may only build near your own buildings — watchtowers see far and extend your lands. Seasons recolour
the whole world (green spring, golden summer, red autumn, snow-white winter). Ruins hidden in the fog pay out
when discovered. Travelling traders, harvests, migrants, storms and wolves turn up from time to time. If food
runs out people leave, but the town hall's founders always stay and forage, so you can recover.

---

## Building

Requires only Python 3 with Pillow (for previews) and a C compiler (for the test emulator).

```
./build.sh                     # art -> src/art.inc, assembles build/EMPIRES.COM
gcc -O2 -w -o tools/beeemu tools/beeemu.c
python3 tools/playtest.py 4000 # automated play-test, screenshots in build/
```

| Path | Purpose |
|---|---|
| `src/main.asm` | Entry, memory check, exit to DOS; includes everything |
| `src/defs.inc` | Hardware ports, terrain/object ids, keys, colours |
| `src/video.asm` | Shadow planes, PCG upload, present, text, numbers |
| `src/input.asm` | 6545 light-pen keyboard scan, frame sync |
| `src/worldgen.asm` | Value-noise heights + moisture, falloff, rivers, biomes, ruins, start site |
| `src/render.asm` | Tile appearance (variants, coastlines, roads/bridges, seasons, fog), scrolling |
| `src/game.asm` | Tools, placement rules, weekly simulation, events, PCG animation, overview, main loop |
| `src/title.asm` | Display choice, title scene + menu, help |
| `art/mkart.py` | All PCG artwork (colour + derived mono) and tables |
| `tools/zasm.py` | Z80 assembler written for this project (with branch relaxation) |
| `tools/beeemu.c` | Headless Z80 + Premium video/keyboard test harness (`callt` profiler, screen dumps) |
| `tools/render.py` | Screen dump → PNG (colour, or amber luminance) |

---

## Hardware findings and design decisions

Sources: MAME `mbee` driver (video and machine), FPGABee "Colour and Extended PCG Graphics", z88dk Microbee platform notes,
Microbee Technology forum notes on 6545 keyboard scanning.

- **Colour RAM** (F800–FFFF when port 08h bit 6 = 1): one byte per cell, low nibble foreground RGBI, high nibble
  background RGBI — 16 colours, two per 8×11 cell.
- **Attribute RAM** (F000–F7FF when port 1Ch bit 4 = 1, extended graphics bit 7 = 1): bits 0–3 choose one of 16 PCG
  banks for character codes 80h–FFh; bit 6 inverse; bit 7 flash. Codes below 80h come from the character ROM, so text costs no PCG.
- **PCG**: 16 banks × 128 characters × 16 bytes = 32K. The CPU sees the bank selected by port 1Ch bits 0–3 at F800.
- **Keyboard**: R18/R19 = keycode×16, write R31, wait for status bit 7, status bit 6 = key down; port 0Bh = 1 during the scan, as the BIOS and The Lantern Deep do. Cursor keys 38h/3Ah/3Bh/3Eh.
- **CP/M video set-up** (read from the BIOS table in the system tracks): `6B 50 59 37 1B 05 18 1A 48 0A 2A 0A 20 00` — 80×24, 11-line characters, start address 2000h (MA13 selects the character ROM set). EMPIRES keeps this and only parks the cursor.
- **Serial port** (MAME driver comments): PIO port B bit 4 RS232 input (0 = mark), bit 5 output (1 = mark), bit 3 CTS, bit 2 clock/DTR. No UART.
- **Joystick**: PIO port A, active low, b0–b3 directions, b7 fire (reads 00 with none fitted) — as The Lantern Deep uses.
- **Frame sync**: 6545 status bit 5 (vertical blanking). **Speaker**: PIO port B (02h) bit 6.

**Display mode.** The game runs in the 80×24 mode CP/M leaves it in (11-scanline characters, 640×264). A map tile
is two characters (16×11 pixels, almost square on screen) with two colour pairs, so each tile can show four colours.
The view is 40×20 tiles with a status row, a message row and a two-row toolbar. I chose not to reprogram CRTC timing
registers because I could not verify the Premium Plus values; only R12/R13 (start = 0) and R14/R15 (cursor parked off-screen) are written.

**Colour and monochrome.** Both art sets are loaded once: colour in PCG banks 0–7, monochrome in 8–15. Monochrome
patterns are derived per character by luminance (the brighter of its two colours becomes the lit pixel), with
overrides (unexplored land is solid black). Switching mode only changes attribute bank and colour bytes, so it is
instant, and the simulation is identical in both. Monochrome cells use white-on-black so they are maximum contrast
whatever the composite output does with colour.

**Animation.** Water (shore, river and sea — 20 characters, 4 frames), windmill sails, chimney smoke and the town
hall flag animate by redefining PCG characters, so every copy on screen animates for one write.

**Memory (1MB banked).** Port 50h follows The Lantern Deep (from ubee512's Premium Plus model, confirmed there by a RAM test on real hardware): only the lower 32K (0000–7FFF) is a window onto one of 32 blocks of 32K; 8000–FFFF is always block 0.

| Where | Contents |
|---|---|
| block 0, 8000–EFFF | Engine: all code that touches the map, screen shadow planes, variables, stack (22K used of 28K) |
| blocks 8–11 (lower window) | World map, banded: row stride 256, 64 rows per block, terrain at 0000h, objects at 4000h. 128×128 uses 2 blocks, 256×256 uses 4 |
| block 16 at 4000h | PCG patterns (colour + mono) and animation frames |
| block 17 at 0000h | Overlay code: start-up choice, title logo and menu, help |
| block 18 | Snapshot of CP/M's 8000–EFFF, so EMPIRES can return to `A>` |
| block 19 | Snapshot of the engine while CP/M does a disk job |
| block 20 | Loader staging for the engine image |
| blocks 21–24 | Save-file staging (header + state + RLE map) |

`EMPIRES.COM` (the loader) finds CP/M's own block by a signature scan and its video window by a probe (both from The Lantern Deep's loader), checks that blocks 0–20 exist and are distinct, loads `EMPIRES.UP`, `EMPIRES.OVL` and `EMPIRES.ART` into their blocks through BDOS, snapshots CP/M's upper memory, copies the engine to 8000h and starts it, all from a final stage at F000h with the video window off. The first part of the loader stays resident in CP/M's block. To leave, the engine restores the screen, copies a small stub to F000h (video off), the stub copies CP/M's memory back from block 18 and jumps to the loader's resident exit, which restores CP/M's port 50h value, re-enables interrupts and warm-boots to `A>`. In the test harness CP/M's upper memory comes back byte for byte.

**Saving.** F in the game opens a Save / Load panel with three slots (`SAVE1-3.EMP` on the current disk); the title's 7 loads. The engine writes a 128-byte header (signature, world size, year, season, population, lengths, 16-bit checksum), the saved-state block (918 bytes: resources, calendar, view, building list, world parameters, random seed) and the map (terrain + objects, row by row, run-length coded) into blocks 21–24. Then it swaps CP/M back in (engine → block 19, CP/M ← block 18, via a stub at F000h with the video window off) and jumps to the loader's resident disk service, which checks the disk isn't write-protected (BDOS 29), writes the file with ordinary BDOS calls, refreshes CP/M's snapshot, restores the engine and returns through 8006h. Loading reads the file the same way and checks the signature and checksum before anything in the current world changes. A 128×128 world saves in about 7K, a 256×256 world in about 24K. In the harness a 256×256 world comes back byte for byte (all four 32K bands and the state block).

**Performance (3.375 MHz, measured in the harness).** Scrolling redraws only the exposed strip (~4 frames). Full view redraw ~9 frames (season change, mode switch). World map ~10 frames. Simulation tick < 0.1 frame. World generation: 128×128 about 5 s, 256×256 about 18 s, with a progress bar (unrolled noise interpolation, incremental vertical steps, table-driven falloff).

---

## Status — what is and isn't verified

**Verified in the test harness (not on real hardware):** start-up, title, all five world types generate,
placement rules, construction, weekly economy, house growth, seasons, events, fog/ruins, world map, colour/mono
switch, quit to menu and exit to DOS.

**Not yet verified on a real Premium Plus — please check:**
1. That CP/M leaves the screen in 80×24 at F000 with colour RAM enabled.
2. The key matrix codes (A=1…Z=26, 0–9 = 32–41, ESC 48, TAB 50, RETURN 52, SPACE 55, SHIFT 63).
3. The loader needs a TPA reaching past B000h and a 1MB Premium Plus (it checks both).
4. Speaker pitch and the feel of the tunes.

**Mouse.** A Microsoft serial mouse (1200 baud, 7N1, 3-byte packets) is read in software from PIO B bit 4. The game polls the line during the idle part of every frame and between key tests; a start bit triggers a cycle-counted receive of the whole packet, with a stop-bit check so a mid-byte lock-on is rejected. The idle level is measured at start-up, so either line polarity works. Packets arriving during a full redraw or a tune are dropped and the next one resyncs. Tested bit-for-bit with an emulated serial line at both polarities; `MOUSE.COM` on the disk shows the raw packets on real hardware.

**Not in this milestone (planned):**
- Joystick — port not yet confirmed.
- Technology tree, rival civilisations, diplomacy, scenarios, victory conditions, regional view, terrain shaping, harbours/ships.
