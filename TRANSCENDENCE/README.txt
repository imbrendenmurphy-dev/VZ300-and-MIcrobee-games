VZ300  -  T R A N S C E N D E N C E
An atmospheric audiovisual journey.  BPM / ViBED 2026
Dick Smith VZ300 + BennVenn SD loader + 128K
=====================================================================

TO RUN
  Copy the three files in SD_CARD to the root of your SD card:
      TRANSCND.VZ    loader (304 bytes, loads at $F000)
      TRANSCN1.DAT   engine, music and scenes  -> $8000-$DF5E
      TRANSCN2.DAT   3D keyframes and sprites  -> SRAM bank 3 ($4000)
  Then:   LOAD"TRANSCND"
  Running time is about 7 minutes. It ends on a black screen in
  silence; reset to leave.

HOW THE SD LOADING WORKS (from the 13 Ghosts loader)
  - Opens each DAT with HL -> "NAME", A=1, CALL $5F00; checks
    ($FB03)=1 and ($FB05)<>1.
  - Reads sectors into the buffer at ($FB80) with CALL $5F03 (first)
    and CALL $5F09 (next), 512 bytes at a time.
  - Probes the DOS mapping at $5FFF, writes TRANSCN2 into bank 3 with
    OUT ($37),3 during each copy, then restores the DOS mapping.
  - At the end it maps bank 3 permanently and jumps to the demo.
  All SD access happens in the opening darkness. Sector reads stall
  the CPU, so loading mid-performance would stop the music.

THE JOURNEY  (158 bars at 93.75 bpm, 50 Hz)
  I    The Arrival      darkness, a pulse, a point of light becomes the
                        entity; drifting through 3D stars; a planet
                        rises; descent into a vast alien sunset
  II   The Search       night world seen only where the entity's light
                        falls: hills, standing stones, a mirror lake,
                        distant lights; it finds a resting figure
  III  The Encounter    real-time 3D human: the face fills the screen,
                        breathing; the camera pulls back and orbits
  IV   Awakening        filaments, the entity enters the forehead,
                        palette flash, eyes open, the figure rises and
                        performs a Tai Chi sequence (commencement, ward
                        off, roll back, press, push, single whip, cloud
                        hands, golden rooster, closing) under an orbiting
                        camera
  V    Separation       stillness; a luminous dithered form leaves the
                        body, converges and rises; expanding rings
  VI   Flight           perspective terrain racing below, banking,
                        climbing, diving, turning into terraced geometry
  VII  The Passage      an evolving tunnel: rings, breathing walls,
                        star lobes, twisting spirals, dissolving colour,
                        a wandering vanishing point
  VIII Rebirth          burst of plasma colour, a new sun, a planet's
                        curve, the entity transformed, then everything
                        slowly emptied away
  IX   Silence          a heartbeat light in the dark, then the title,
                        held for a while. Then the face returns as it
                        was at the start: asleep, breathing, two faint
                        heartbeats. It wakes with a startle: eyes snap
                        open, head jerks up, palette flash, a hit and a
                        racing pulse, two faint notes of the motif. Back
                        to the end screen, which fades into darkness.

MUSIC
  Two pulse voices plus percussion, generated continuously while the
  graphics draw. The build measures the timing before every sound call
  in an emulator and compensates each call site, so pitch stays true
  everywhere. The entity's motif (B F# E G) recurs throughout: high and
  quiet at its birth, merged with the human theme at the awakening,
  folded into the Tai Chi pattern, distant and ethereal at the
  separation, rising through the passage, and resolved to G# (E major)
  at the rebirth.

TECHNICAL
  - Mode(0) scenes: 64x32 chunky buffer, converted to 9-colour SG4
    cells, dissolve fades. Tunnel and plasma render per cell.
  - Mode(1) human: 16-joint skeleton, interpolated keyframes, camera
    matrix, perspective, about 35 depth-sorted shaded spheres (prebuilt
    shifted sprites; shaded span discs for close-ups), face features.
  - IM2 interrupt at field sync steps the music; the main code
    re-enables interrupts after sync, so no field is ever missed (checked
    over the whole run in emulation).
  - Never uses the ROM after loading. Stack $FDF0, IM2 table $FE00.

BUILD (source folder)
  python3 build.py     needs sjasmplus on the PATH
  ./run.sh 20500       runs the emulator; then python3 calib.py and
                       build.py again to recalibrate the sound timing
  python3 video.py out.mp4   renders a preview with emulated sound

NOT YET TESTED ON REAL HARDWARE
  Everything above was verified in an emulator written for this
  project, not on a VZ300. Please report:
   - whether the loader finds and loads both DATs
   - how the sound compares (1-bit, rendering-dependent grit is expected)
   - frame rates: about 12 fps in I-II, 4-5 fps for the 3D figure,
     6-7 fps for flight, tunnel and rebirth
