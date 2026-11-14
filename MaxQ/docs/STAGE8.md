# MAX Q v0.11 — raster road (OutRun / Hang-On style)

The 3D polygon track is gone. The road is now drawn the way the mid-80s Sega racers did it:
a straight road whose rows are shifted sideways and squeezed vertically to fake curves and hills.

## How it works
- The 32 rows below the horizon are 32 fixed **depth slots** (slot 32 nearest, slot 1 at the horizon).
  Each slot has a fixed road width, a fixed distance ahead, and a rumble-strip width (tables, built once).
- Each frame, walking from the nearest slot to the farthest:
  - **Curves:** `dx += CURV[section]; x += dx` — each row's centre slides a little further sideways,
    so a bend ahead sweeps the road off to one side. Nothing is rotated or projected.
  - **Hills:** `dh += SLOPE[section] − SLOPE[here]; h += dh` — rows are pushed up (crest coming)
    or squashed down (dip). Rows that end up behind a crest are simply not drawn.
  - **Steering:** the road slides under the craft: full lateral offset at the bottom row,
    tapering to nothing at the horizon.
- The light/dark **bands** come from the section number at each row (two sections light, two dark),
  so they stream down the road as you move, like OutRun's colour-cycled stripes.
  Boost pads, jump ramps and the start line are just different band colours.
- Rivals and pickups sit on the depth slot that matches their distance, so they ride the same
  curves and hills as the road, are sized by slot, and hide behind crests.

## Speed
- Emulator, cycle-exact, 2-lap autopilot race: **16.7 fps** (v0.10 3D road: 10.6 fps).
- Byte-exact check: `build_race.py test` renders 20 camera states on the emulated Z80 and compares
  each frame with `road_ref.py` — 20/20 identical.

## Files
- `road_ref.py` — integer reference model of the road (and a standalone preview renderer).
- `road_new.asm` — the Z80 road build and sprite placement; `mkroad.py` joins it with the parts of
  the old engine still used (multiply, row composer, rectangles, sky, skyline) into `road.asm`.
- Track tables are now heading, climb, **curvature** and **slope** per section (in SRAM bank B).

## Tunables
- Road width per slot: `WT` in `road_ref.py`. Band length: `bit 1,c` in `road_new.asm` (2 sections).
- How hard bends look: `CURV` scale (`c * 420`) in `road_ref.build_track`; hills: `p * 95`.
- Track speed: `physics` in `race.asm` (`srl a` = half the speed figure).

## Possible next step
A faster row pass (fill each row directly instead of via run lists) is sketched; it should add a few
more fps once the narrow far-rumble edge case is handled.
