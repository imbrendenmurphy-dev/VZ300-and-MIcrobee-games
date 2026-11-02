# Native renderer milestone

This build is separate from the VZ/compatibility renderer. It includes no
legacy render.asm, gfx.asm, BACK composition or 2-bpp screen translation.
Only original level collision geometry is used when generating scenery.
The current harness uses Up the Bank as a representative scene.

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
- Overlapping bilbies compose into one CPU glyph per touched cell and upload
  once. No transparent-sprite hardware or packed framebuffer is assumed.
- Terrain jobs are viewport offset.word, sixteen PCG rows, colour.byte, up to
  32 jobs at home RAM 3000h. They compose before bilbies. A game/worker must
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
| Home 1000h-145Fh | Viewport-cell to dynamic-slot map |
| Home 1800h-19FFh | Dynamic-slot to screen-cell list |
| Home 1A00h-1AFFh | Composite colours |
| Home 3000h onward | Terrain job input |
| Fixed 8000h onward | Renderer, harness, preshifted atlas |
| Fixed C000h-CFFFh | Up to 256 composed native glyphs |
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
| Full terrain pan/output | 78,030 | 1.156 |
| Ten actors including terrain | 239,473 | 3.548 |
| Forty actors including terrain | 652,032 | 9.660 |

**The renderer does not meet the 25Hz target.** Graphics alone imply roughly
14 fps for ten actors and 5 fps for forty, before simulation and additional
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
