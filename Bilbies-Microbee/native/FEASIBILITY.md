# Feasibility checkpoint — 2026-11-03

The current 640x256 engine is not yet viable at the original 25 Hz graphics
and 12.5 Hz simulation targets across the full campaign. This is not a verdict
on the hardware or on a different engine. The native gameplay slice has not
been integrated, so no combined benchmark or playable game is claimed.

`feasibility.py` samples 17 moving frames for 10, 20, 30 and 40 actors in
both display modes, with stationary camera and one-pixel pan per update.
Independent scene oracles run on selected frames. The actors follow synthetic
trajectories and use a shared walking gait; these are not captured game frames.
At the model's 3.375 MHz, two 25 Hz graphics updates and one 12.5 Hz game tick
must share 270,000 T-states, including input and all other work.

Colour, maximum presentation costs (T-states):

| Actors | 12x8, still | 12x8, pan | 16x16, still | 16x16, pan |
|---:|---:|---:|---:|---:|
| 10 | 69,133 | 118,659 | 111,167 | 156,270 |
| 20 | 127,712 | 172,972 | 197,121 | 244,849 |
| 30 | 174,862 | 221,183 | 282,667 | 331,525 |
| 40 | 232,110 | 276,453 | 374,815 | 417,927 |

The standalone compatibility simulation cost 25,581 T-states for ten walking
actors with one blocker and 44,744 for twenty. Illustrative arithmetic only:
two compact still-camera presentations at 20 actors plus one such tick total
300,168 before input or integration. These are separate artificial workloads,
not a measured frame. At ten actors even the compact pan leaves little room.

The model lacks physical timing, mouse interrupt handling and ColdFire. The
Z80 programs use palette-specific blank glyph zero, enforced by the build.
The revised compact renderer passes the full oracle and ROM/CP/M launch; the
16x16 variant also passes. A 40-actor six-cell alignment still takes 445,606
T-states (compact) or 477,283 (large) for sprites alone.

`simulation_probe.asm` relocates original gameplay logic and collision mask to
a lower RAM bank. The probe matched the original on 96 ticks across blocker,
bomb, builder and digger scenarios. It omits visual terrain edits, sound,
input, rendering and game integration. Next build a complete playable slice,
connecting the simulation to native terrain edits and state-specific artwork;
benchmark actual combined frame and input costs before choosing a final mode.
A new actor residency/redraw strategy or verified ColdFire worker remains
necessary for sustained crowded scenes. The Z80-only model cannot settle
ColdFire viability or real monitor/snow-free behaviour.

Reproduce with `python native/build.py --compact-bilbies --compiled-actors`,
`python native/feasibility.py --output test-output/native/feasibility-compact.json`,
and `python native/build_simulation_probe.py` followed by
`python native/test_simulation_probe.py`; sjasmplus and z80 are required.
Remove `--compact-bilbies` for the larger art. See JSON for monochrome cases.
