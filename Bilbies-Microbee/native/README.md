# Native renderer milestone

This build is separate from the VZ/compatibility renderer. It includes no
legacy render.asm, gfx.asm, BACK composition or 2-bpp screen translation.
Only original level collision geometry is used when generating scenery.
The current harness uses Up the Bank as a representative scene.

Latest measurements and architecture changes are in `OPTIMISATION.md`. The
renderer remains over budget. H pauses the harness; GFX counts nominal 50Hz
frame edges spent presenting. `--compact-bilbies` selects a separate 12x8
comparison drawing. The default remains 16x16.

## Representation

- 80x16 cells, 8x16 pixels each: 640x256. Fourteen rows form the scene;
  two fixed rows use the machine's font ROM for the harness UI.
- Premium RGBI palette, not the VZ four-colour palette. Each cell encodes
  one real ink/paper pair. More than two colours in a cell must be approximated.
- Native scene width 1024 pixels. Eight horizontal phases are compiled
  together, deduplicating glyphs across cells/phases. A pan selects a map
  and coarse source column; it does not rewrite terrain PCG.
- 1792 static PCG slots and 256 physical foreground slots. The byte-indexed
  foreground allocator exposes 255 slots and uses FFh as its missing-entry
  sentinel. It signals n_overflow and refuses further cells rather than
  overwriting terrain. Larger edit sets need a better residency policy.
- Native 16x16 bilbies, eight gait frames, both directions in the atlas,
  all eight horizontal subpixel phases, and an outline/ink mask. The harness
  currently displays the right-facing gait. Other actions remain to be drawn.
- Generated column programs draw into a native column-major CPU bitmap,
  contiguous across vertical PCG boundaries. Overlaps share pixels; each
  touched cell uploads once. Sixteen vertical phases identify nontransparent
  cells. No transparent-sprite hardware or PCG framebuffer is assumed.
- Terrain jobs are viewport offset.word, sixteen PCG rows, colour.byte, up to
  32 jobs at fixed RAM 9C00h. They compose before bilbies. A game/worker must
  produce them from world changes/camera state; this is not a digging simulation.

## Artwork

`art/homestead-source.png` is a new imagegen source, not an emulator capture
or promise of attainable hardware detail. `art/PROMPT.md` records the prompt
and method. The compiler crops alpha bounds, sizes for tall display pixels,
maps to RGBI, then encodes two colours per cell. Source remains unchanged.

Collision-bearing glyphs are preserved exactly. To fit eight colour phases,
65 scenery-only entries share an immutable glyph differing by one pixel;
no chained error is allowed. Current libraries: 1792 colour glyphs and 1651
monochrome glyphs. Mono uses silhouettes and striped earth, not desaturation.

Further pixel-art refinement is needed after hardware quantisation. The other
Australiana scenes and full bilby action atlas have not been redrawn yet.

## RAM and banks

| Location | Use |
|---|---|
| Expanded block 8 / 9 | Colour / mono 32K PCG image |
| Blocks 10/11 | Colour phase maps 0-3 / 4-7 |
| Blocks 12/13 | Mono phase maps 0-3 / 4-7 |
| Block 15 | Temporary engine staging by loader |
| Block 14 0000h / 0800h | CPU glyph-address low/high planes |
| Block 14 1000h-145Fh | Viewport-cell to dynamic-slot map |
| Block 14 14F0h-17F5h | Exact unchanged-frame history |
| Block 14 1800h / 1900h | Slot to screen-cell low/high planes |
| Block 14 1A00h / 1C00h / 1D00h | Colours and CPU glyph-address planes |
| Block 14 2000h onward | 32-byte column records and drawing programs |
| Fixed 8000h onward | Renderer and harness; ordinary stack throughout |
| Fixed 9C00h onward | Terrain job input |
| Fixed A000h-E5FFh | Native 80-column x 224-row CPU bitmap |
| EFF0h downward | Stack outside video window |
| F000h-FFFFh | Video/attribute/PCG/colour access window |

## Executed results

Z80 instructions execute in adapted ppmodel with z80 1.2.0. Tests compare
output planes and glyph bits with an independent masked-sprite oracle.
Colour/mono pass 24 camera cases, patches plus forty actors, both horizontal
clipping edges, zero actors, keyboard controls and ROM/CP-M launch.

See reports/results.json and reports/profile.json. Most recent costs:

| Operation | T-states | 50Hz frames |
|---|---:|---:|
| Full terrain pan/output | 61,567 | 0.912 |
| Ten actors including full terrain | 164,698 | 2.440 |
| Forty actors including full terrain | 467,192 | 6.921 |

**The renderer does not meet the 25Hz target.** Graphics alone imply roughly
20 fps for ten actors and 7 fps for forty, before simulation and additional
hardware waits. Profiling identifies masking, background acquisition and
per-cell work as major costs. No ColdFire speedup has been measured.

Physical monitor timing, snow-free output, input interrupts, coprocessor
execution and firmware coexistence remain unverified. Successful pixel tests
are not a performance pass or a completed conversion.

## Reproduce

With sjasmplus on PATH, from the project folder:

```powershell
python native/build.py
python native/test_renderer.py
python native/profile_renderer.py
```

`--reuse-assets` is for assembler-only iteration after an unchanged asset
build. Default builds regenerate native tables from the local source art.

`--compact-bilbies` builds the optional 12x8 comparison. The separate
`measure_simulation.py` requires the compatibility build; its original-rule
measurements do not prove native gameplay integration.
