# VZ300 & Microbee Originals

Original games and demos for the Dick Smith **VZ300** and the **Microbee Premium / Premium Plus**.

Vibed by BPM, 2026.

Each folder has:

| Folder | What's in it |
|---|---|
| `README.md` | What the game is, what hardware it needs, how to load it, controls |
| `release/` | The latest build, ready to copy to an SD card or boot as a disk |
| `src/` | Source code and build scripts |
| `screenshots/` | Pictures from the emulator |

## Hardware

- **VZ300 games** need a BennVenn SD loader with 128K RAM expansion. Copy the `.VZ` file (and any `.DAT` file next to it) to the SD card and run it from the loader.
- **Microbee games** run on a Premium / Premium Plus with PCG RAM. Boot the `.DS8` disk image, then type the program name at the prompt.

ROM images for the machines and emulators are not included.

## Third-party code

The test emulator in some `src/tools/` and `tools/` folders (Forgotten Depths, Megademo, Ghost Hunter 2, Asteroids II (VZ300 and Microbee), Circus 2, Killer Tomatoes, Penguin 2, Tennis II, Microbee Australian Open Tennis, Star Blaster II, Panik 2, Kamikaze Invaders 2, Duel II, Hamburger Sam II, Robogeddon, Zephyr Zone, Kaboomerang, Starhive, FrillSeeker, Rogue Muster, Southern Cross, Stormbell, Spindrift) uses a Z80 CPU core that looks like superzazu/z80 (MIT licence, https://github.com/superzazu/z80). It's used only for testing and isn't part of the games.
