# Bilbies Microbee vertical slice

`release/BILSLICE.DS8` is an experimental DS80 image for the 1MB/32K-PCG
Premium Plus. In the supplied Z80 hardware model it boots the bundled CP/M to
`A>`; type `BILBIES` and press Enter. It is one unfinished level, UP THE BANK.
Save 9 of 12 bilbies using the six builders available in the original level.

- Left/right arrows select a bilby; a reversed-colour cell marks the selection.
- Press 5 to select builder and Space to assign it. 4 and 8 select blocker and
  digger, but this level's original inventory has none.
- O/P pan the view one pixel; C selects colour, M monochrome, H pauses, and R
  restarts the level. The saved/quota count and remaining seconds appear above.

The keyboard and gameplay sequence were tested in ppmodel using the actual Z80
code, BN60 ROM and CP/M disk loader. A builder was assigned using the emulated
keyboard and changed both collision and visible terrain; edits survived a pan
and monochrome switch. Pause and restart were checked. This does not constitute
an independent emulator pass, a real-time human playthrough, or hardware test.

Build with Python, NumPy, Pillow, sjasmplus and the `z80` Python package:

```
python native/build.py --slice --compact-bilbies
python native/test_slice.py
python native/test_slice_bridge.py
python native/test_slice_controls.py
python native/slice_terrain_test.py
python native/test_simulation_probe.py
python native/measure_slice.py
```

The slice compiles original game physics into RAM block 27, preserving CP/M's
home bank. Collision edits are persistent for the level and produce native
viewport-cell patches; R restores the original map. The renderer and art are
bespoke Microbee work. It uses simple 12x8 walking artwork for all states and
one global gait; direction/action art, full cursor selection, mouse, joystick,
sound, settings/progress saving, more levels and campaign progression remain
unimplemented. Changing mode is temporary. Completed-level success and failure
are indicated in the HUD; the original solution was replayed automatically.

Terrain edits currently replace touched scenery with simple soil/sky shapes.
More than 32 visible edited cells, or exhaustion of the 255 dynamic glyphs,
pauses with a terrain-limit message; an exhausted render can be incomplete.
This guard is a prototype limitation, not a suitable final gameplay rule.

Measured integrated update costs include the real keyboard scan, simulation,
terrain patch generation, rendering and marker, excluding intentional waiting.
The 17-frame synthetic walking sample in colour gave maxima of 133,549,
212,056 and 362,349 T-states at 10, 20 and 40 actors with a stationary camera;
scrolling gave 175,917, 257,458 and 404,271. The 25Hz interval at 3.375MHz is
135,000 T-states. Costs alternate because simulation and animation update
on alternate loops. This sample has no deliberate terrain edits; generating
edit patches adds work. The renderer therefore still misses the timing target
for sustained crowds and scroll. The scheduler counts rendering work toward
its frame deadline, but overloaded frames can slow simulation; vblank polling,
real input latency and hardware timing need independent verification.

The ColdFire is not used: its supported worker interface and bus arbitration
remain unverified. The current engine still needs a better crowded-scene draw
strategy and a real-time complete level run before its viability is established.
See `native/reports/slice/` for measurements and a model capture.

The original two-event UP THE BANK solution has now been replayed through the
slice simulation and skill-assignment bridge: all 12 were saved, quota 9.
Rendering was sampled 59 times during that automated run. It is not a full
real-time or human-input playthrough; keyboard assignment is tested separately.
Reproduce with `python native/test_slice_solution.py` after the slice build.
