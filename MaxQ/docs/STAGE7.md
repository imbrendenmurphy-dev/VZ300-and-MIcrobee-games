# MAX Q v0.10 — speed stripes, calmer track, attract fix

## Attract sequence garbled on hardware (fixed)
The interrupt routine writes the latch at $6800 every field from a variable, LATBASE.
LATBASE started at 0 at boot, so during the attract sequence the ISR kept putting the VZ
back into mode 0 (text) — the stripes and characters in the hardware photo. It is now set
to $08 (mode 1) in `init_vars` and in `demo_reset`. The emulator previews missed this because
the GIF tool ignored the mode bit; `racesim.py` now counts frames with mode(1) off
(old build: 262 of 299; new build: 0).

## Speed from the road surface, not the geometry
Before: the light/dark road bands were tied to the track sections, so bands and curves
moved together and every frame jumped a long way along the track — jerky.

Now the bands are drawn separately from the geometry:
- Each road row has a depth (ZBTAB). The row uses the normal or the swapped pattern page
  (colour 0 ↔ 4) depending on `(depth + PHASE) & 128`. That's one table lookup per row,
  built once per frame into ROWPG; no extra cost per pixel.
- PHASE advances at about 1.5× the track speed, capped so a band moves less than half its
  own length per frame (any faster and, at ~10 fps, the bands would appear to stall or run
  backwards).
- The track geometry (and the rivals) now advance at **half** speed, so curves and hills
  sweep past gently while the surface rushes underneath — the OutRun trick.
- A band now spans 4 track sections (ZB halved).

Side effects: a lap takes longer, so races are now **2 laps** (HUD "LAP 1/2").

## Numbers (emulator, cycle-exact)
- Renderer tests: 20/20 frames byte-identical with ref3.py.
- Race sim (autopilot): about 10.6 fps; a 2-lap race completes; 0 frames out of mode(1).

## Tunables
- Stripe speed: `race.asm`, physics advance (speed × 3/16, cap 22).
- Track speed: same place (`srl a` = half) and `rv_one` in `game.asm` for the rivals.
- Band length: `ZB` in `ref3.py`.
- Laps: `NLAPS` in `game.asm`.
