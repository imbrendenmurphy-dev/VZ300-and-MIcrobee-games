SOUTHERN CROSS - Stage 1: flight engine test
Microbee Premium Plus (32K PCG)          VIBED BY BPM 2026
===========================================================

RUNNING
  Copy SCROSS.COM onto one of your Microbee DOS disk images,
  boot it and type SCROSS at the prompt. Press RESET to exit.

CONTROLS
  Q / A    nose down / nose up
  O / P    bank left / right (steer when on the ground)
  T / G    throttle up / down (throttle 0 = brakes on ground)
  SPACE    level the wings
  R        restart on the runway
  F        restart on final approach (1.5 km out, 100 m)
  D        detail level 1-3 (for the benchmark)

DETAIL LEVELS
  1  horizon + runway outline
  2  + centreline, threshold bars, hangar
  3  + ground grid (default)

FLYING TIPS
  Full throttle, rotate with A at about 52 kt, climb at
  60-70 kt. Stall is about 43 kt: the nose drops by itself.
  Land at under ~700 ft/min sink with wings level.

BENCHMARK (emulated at 3.375 MHz, on the runway)
  Detail 1  about 15 fps
  Detail 2  about 8 fps
  Detail 3  about 5.5 fps
  The panel shows the real FPS, timed by counting the 6545's
  vertical blanks (50 per second). Game speed follows the
  same count, so the plane flies at the right pace whatever
  the frame rate.

TECH
  64x16 screen, 8x16 cells. Top half: 512x128 bitmap made of
  512 PCG characters arranged as 4 vertical strips (one 2K
  PCG bank each), double buffered (banks 1-4 / 5-8, flipped
  with the 6545 start address). Bottom half: text panel.
  Wireframe 3D: 8-bit camera matrix, frustum culling, near
  plane clipping, midpoint 2D clipping, shared-vertex objects.
  Flight model runs at 50 ticks per second of game time.

  tools/ has the source, the Python assembler used to build
  it and the emulator used for testing.
