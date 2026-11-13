STAR BLASTER II - "THE ENERMY RETURNS"   v1.2.2
for the Dick Smith VZ300 / VZ200
VIBED BY BPM 2026 - free to share, full source on GitHub:
https://github.com/imbrendenmurphy-dev/VZ300-and-MIcrobee-games/tree/main/StarBlaster2

The sequel to the 1984 VZ cockpit shooter STAR BLASTER. Scan 360 degrees of
space, bring the Enermy into your sights and blast them. Energy is your life:
it drains all the time, firing costs energy and so does every hit you take.
Clear each sector's FRT TRP TNK FHT quota to warp to the next.

NEEDS
  BennVenn SD loader with 128K RAM. Without it the game shows
  NEEDS BENNVENN SD + 128K RAM and stops.

LOADING
  Copy STARBLS2.VZ to the SD card and run it from the BennVenn loader.
  (Single type F1 file, 20,950 bytes, loads at $8000-$D1BD, runs at $8000.)

CONTROLS
  Scan left / right .. M / ,      (or either joystick)
  Scan up / down ..... Q / A
  Fire lasers ........ Z or SPACE (or fire)
  NOVA smart bomb .... N
  Pause .............. P   (X while paused quits to the title)
  Sound .............. S: music+FX -> FX only -> off
  Start .............. SPACE, Z, RETURN or fire; keys 1-5 pick the skill
  Trainer mode ....... T on the title (energy never runs out, no high score)
  Initials ........... Q/A change the letter, SPACE/fire next, RETURN done

SCORING & EXTRAS
  TNK 100   FRT 150   TRP 200   FHT 250   ACE 500   ROCK 50   MINE 100
  Mothership turret 1000, core 5000, mission complete 50000
  Quick successive kills chain x2, x3, x4.
  Supply pods: shoot them for ENERGY +150 or NOVA +1.
  Each troop carrier that lands in sector 4 costs 60 energy.
  After each sector your energy is topped up, and the refuel scores points.
  The bezel round the dashboard flashes when you're hit and blinks on the
  side a fighter, ace, mine or plasma bolt is coming from.
  8 sectors: Outer Rim, Rock Belt, Minefield, Invasion, Nebula X,
  Ace Squadron, Gauntlet, Mothership. Then lap 2 runs faster.

TECH SPECS
  Display ... Mode 1, 128x64, 4 colours, no snow (video RAM is only written
              during vertical blank, by code generated each frame)
  Timing .... 25 game steps a second; picture at 25 fps, about 22 fps in
              the busiest play, with catch-up so the speed never changes
  Sprites ... 10 types at up to 8 distance sizes, pre-shifted and masked at
              start-up (14.5 KB), clipped POP blitter
  Sound ..... 1-bit speaker, two-voice pin-pulse engine, 9 tunes, 14 effects
  Memory .... code/data $8000-$D1BD; sprites, buffers and tables in the rest
              of the 64K and in SRAM bank 3 ($4000-$67FF, port $37 = 3).
              No ROM calls, and the DOS isn't needed once the game has loaded.
  Tested in a headless VZ300 emulator only (snow detector, two full laps
  soak-tested). Not yet run on real hardware.

CHANGES
  v1.2.2 (13 Nov 2026)  The attract demo pilot no longer runs out of energy,
                        and the bezel no longer flashes on the title screen.
  v1.2.1                Original sound effects restored, exactly as designed.
  v1.2                  Fixed the sound-effect table (9-byte entries were
                        read 8 bytes apart, so effects played the wrong sound).
  v1.1                  Easier, dithered bezel round the dashboard instead of
                        the cracked canopy, directional threat warnings, logo
                        reads STAR / BLASTER II.
  v1.0                  First release.

The original STAR BLASTER (Dubois & McNamara, 1984) is not included.
Everything here is new code, graphics and music.
