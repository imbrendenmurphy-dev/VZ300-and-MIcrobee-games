# Original solution workload sample

`python native/measure_workload.py 0 5 6 11 12 17 23` replays seven original
solution scripts in the compatibility Z80 model, with compatibility display
presentation disabled, and samples the creature records at every game_tick
entry. These are recorded scripted solutions, not a sample of human play or a
native game benchmark. Terminal saved/lost records are excluded; animated
exit, splat and drowning states are included.

Across these cases the maximum simultaneously active actors are 10, 15, 20,
15, 15, 30 and 40. THE LAST BURROW has 40 actors for 472 of 1,490 sampled
ticks and ends with 40 saved. NIGHT SHIFT has 30 actors for 424 of 1,323 ticks
and ends with 30 saved. Thus high counts are part of original scripted play,
not solely an invented stress test.

The recorded original camera shows at most 27 in THE LAST BURROW. The second
window figure searches all possible horizontal windows of 320 original logical
pixels plus sprite-edge allowance, corresponding to the native prototype's
640-pixel viewport at 2x world scaling. It ignores vertical clipping and is an
upper bound over camera positions, not a measurement of the scripted camera.
In these examples all active actors could fit horizontally in such a window.
The 17 other levels and alternative player strategies were not sampled. See
selected-solutions.json for per-level results. This model does not test real
hardware, native compositing timings, or mouse/joystick responsiveness.
