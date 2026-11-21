# VZURID - Phase 2 (combat engine) for the VZ300

Credits: ViBED by BPM 2026 (splash screen).  Status: Phase 2 of 5.  Everything below marked EMULATOR was measured in my own Z80 emulator, not on a VZ300.

## Run
Load `VZURID2.VZ` from the BennVenn SD loader as a normal machine-code .VZ (start $8000, 13 KB, no banking, no SD access while running).
Controls: M left, comma right, Q up, A down, full stop / SPACE fire. Joystick (IN $2C / $2E) is read but UNVERIFIED.

## What Phase 2 adds
- 48-row playfield + 16-row HUD (score, lives, wave, energy bar; SL/LT are the timing counters). Playfield shrank from 56 to 48 rows to buy frame time.
- Forgiving damage instead of insta-death: 5 energy pips, 3 lives. A hit costs one pip and gives ~1.2 s of blinking invulnerability; raised hull blocks hurt and knock the ship back; running out of energy blows the ship up and respawns it with full energy. Game over waits ~2 s, then FIRE restarts.
- Formation waves: line, V, divers (homing, fire aimed shots), staggered column. A new wave arrives about 1.2 s after the last one is cleared.
- 10 gun turrets built into the hull (armour: three hits). They fire aimed shots (8 directions) once on screen; destroyed turrets stay dead until the game restarts.
- Enemy bullets, explosions, scoring (drifter 10, diver 20, turret 50).
- Max flight speed is now 1.5 px/frame (was 2) so generation of new hull columns fits the frame.

## Measured (EMULATOR ONLY; field = 70,630 T as measured on the author's VZ300)
Bot that flies, hunts and fires continuously (tools/play_test.py), 3 x 3000 frames (= 3 min of play):
- work per frame: mean ~53.5K T, p99 ~68K T, max 72.8K T
- frames over the field budget: 12/3000, 9/3000 (seeds 1, 3), 16/3000 in an earlier build; roughly 0.3-0.5 %. Each is one dropped field (a one-frame hiccup, no tearing). They cluster when 4 enemies, a turret, bullets and full-speed scrolling coincide.
- no playfield row written after the beam passed; no VRAM write while the beam was inside the row being written (HUD drawn at the start of the frame for that reason)
- flip + scroll scenario (tools/run_tests.py): 2/400 frames over.

## NOT verified
- Anything on real hardware: timing (the model assumes the measured 70,630 T field and my reading of the FS timing), tearing, snow, joystick.
- No sound yet. 128K banking is not used. Game feel (difficulty, speeds, damage) has only been judged by a bot and screenshots.

## Known limitations / next
- The remaining overruns need a cheaper sprite pipeline (sprite handling is ~25K T/frame when busy) - candidate for Phase 3/4 work.
- Only one dreadnought exists (192 tiles wide, wraps). Phase 3: 15 dreadnoughts, landing, ship destruction, progression.

## Build / test
`python3 build.py`, `python3 tools/run_tests.py 400`, `python3 tools/play_test.py 3000 <seed>` (PROF=a,b for a profile, DBG=a,b for per-frame state).
