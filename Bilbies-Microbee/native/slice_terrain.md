# Slice terrain bridge

The simulation calls `st_mark` after a collision pixel write. The bridge keeps
an 8-by-16-native-pixel world-cell bitset in home-bank `6800h..689Fh` and
reconstructs visible edited cells from the current 512x80 collision mask.
It emits the renderer's 19-byte patch records. Fine scroll can make one world
cell affect two screen cells; repeated records are deduplicated. Dirty cells
remain marked across frames, scrolling and display changes.

Call `st_init` on level load. Call `st_jobs` with `HL=camera`, `DE=patch buffer`,
and `A=0` for colour or `1` for monochrome. A returns the job count; carry
signals that over 32 unique viewport cells need jobs. Do not present an
overflowed result as complete. The buffer is cached when camera, mode and
terrain do not change. Call `st_invalidate` if another routine overwrites the
patch buffer. The renderer may also run out of foreground PCG slots when
actors and edits overlap; its separate overflow status must be handled.

This is a bounded slice implementation, not the final artwork/terrain engine.
Touched cells use a high-contrast, collision-derived soil/sky silhouette, so
their original scenery is replaced; persistent edits exceeding 32 visible
cells require a different residency scheme. The tests execute real Z80
instructions and compare generated rows against an independent pixel oracle:
`python native/slice_terrain_test.py` with `sjasmplus` and `z80` available.
There are 38 camera/mode cases, including every fine-scroll phase, plus cache
invalidation, duplicate suppression, preserved registers and overflow checks.
The sample cost was up to 83,765 T-states for rebuilding eight sparse dirty
cells, and 438 T-states for reusing unchanged results. These are model costs,
not end-to-end gameplay or hardware timing measurements.
