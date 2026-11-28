# Renderer optimisation checkpoint — 2026-11-03

The renderer is still over budget. Do not proceed on the assumption that a
build or a correct image proves gameplay throughput.

Implemented and executed in the Z80 model:

- Generated masked-column Z80 programs, with transparent runs omitted and
  separate opaque/masked instructions. Sixteen vertical alignments describe
  exactly which cells each column modifies. Transparent cells consume no PCG
  slots and do not recolour the background.
- A native column-major 640x224 CPU bitmap makes a column contiguous across
  vertical PCG boundaries. It is unrelated to the VZ BACK or screen format.
- Unrolled transfers, clearing only previously allocated cells, and three
  batched metadata passes. Address planes use ordinary registers; SP remains
  a real stack, including during transfer loops. Mouse IRQs are not yet enabled.
- Restore only previously dirty terrain rows when the camera/mode is unchanged.
  A pan or display change still redraws the full native terrain map.
- Exact unchanged-frame rejection, with explicit invalidation on PCG reload.
  Pause uses a debounced H key. A GFX counter reports nominal 50Hz frame edges
  spent presenting; it is not a CPU-cycle counter or a complete-game FPS meter.
- Correct partial-left clipping when another bilby overlaps the clipped one.

The original native harness cost 78,030 T-states for full terrain output and
652,032 including forty overlapping 16x16 bilbies. The current same scene
costs 61,567 + 405,625 = 467,192 T-states, about 28% less. With a stationary
camera, restoration takes 25,535 instead, giving 431,160 before presentation
bookkeeping. An unchanged presentation costs 10,136 and writes no video RAM.

The separately redrawn 12x8 experiment takes 254,053 for the ordinary forty-
actor pass, but a staggered alignment takes 536,865. Shrinking characters does
not solve the worst case. It remains optional; 16x16 is the default.

At 3.375MHz, a nominal 25Hz graphics budget is 135,000 T-states and a 12.5Hz
complete-game tick is 270,000. The preserved simulation alone measured about
67,000 walking and 79,000 falling with forty actors. Those are controlled
examples, not upper bounds for blockers, explosions or all working skills.
Neither renderer variant has passed the combined game budget.

`reports/large/` and `reports/compact/` contain actual captures, measurements
and asset statistics. Tests cover 24 camera cases, 80 sprite alignment cases,
all gait frames in both modes, independent glyph/ink/paper oracles, overlapping
and clipped actors, old-frame removal, patch changes, same-mode PCG reload,
pool exhaustion protection and ROM/CP-M launch. The profiler steps real Z80
instructions. No real-machine result is claimed.

Independent Windows emulator verification failed: uBee512's help launch hung
without output, including outside the sandbox. Only this task's two hung
instances were stopped. The computer-use runtime also failed after its reset
and retry sequence with `failed to write kernel assets: The system cannot find
the path specified. (os error 3)`. These failures are not emulator passes.

Next experiment: cache the native world pixels and colours for each horizontal
phase in expanded RAM, gather foreground work, and fetch backgrounds in a
batch. The current checkpoint still fetches each background from PCG. Longer
term, persistent glyph residency and changed-row transfers need investigation;
discarding every composite each frame remains expensive. Persistent world
terrain editing, native simulation/skills, remaining action art, mouse/joystick,
menus and saves remain unconnected. ColdFire worker loading is still unknown.

Additional experiment: `--compiled-actors` places generated actor routines in
RAM blocks 16-23. Compact art passes the full pixel oracle and real ROM/CP-M
model launch. Forty moving actors cost up to 233,112 T-states for steady
presentation; staggered actors cost 472,224 before terrain. These results do
not meet the graphics budget. The cache and raster alternatives were slower.
The compatibility physics blocker index reduced a controlled one-blocker case
from 265,407 to 83,115 T-states and passed equivalence and all 24 solutions.
