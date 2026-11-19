# REDBACK (working title) - Microbee Premium Plus

Original Uridium-inspired horizontal shoot-'em-up, Z80 only, 40-column PAL, PCG-as-bitmap 1-pixel smooth scrolling at 50 Hz.
**VIBED BY BPM 2026**

**Status: Phase 1 technical demo.** Tested only in a home-made emulator model; not yet verified on uBee512 or real hardware.

* `release/REDBACK.DS8` - bootable disk, boots to CP/M, type `REDBACK`; ESC returns to CP/M. (`REDBACK.COM` alone needs the `.BNK`/`.BIN` files from `build/`.)
* `CLAUDE.md` - full handover notes (architecture, failed approaches, status, priorities).
* `docs/` - technical notes, test results. `./build.sh` rebuilds everything.
