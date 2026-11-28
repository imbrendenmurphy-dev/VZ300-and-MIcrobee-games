# Bilbies! — bespoke Microbee renderer in development

The default build now uses **native/renderer.asm**, independently of the VZ
renderer and compatibility port. It displays 640x256, streams native PCG cell
maps from expanded RAM, and composes native masked bilbies into private PCG
slots. It never reads or writes the VZ framebuffer. Native artwork is compiled
for the Premium RGBI palette and two-colours-per-cell restriction.

**This is a renderer harness, not the completed game.** Original simulation,
levels and regression tests remain available in the baseline, but gameplay,
saves, menus and mouse are not connected to the new renderer yet. The forty-
bilby case still misses its performance budget. No ColdFire acceleration or
real-hardware success is claimed.

## Run the new renderer

Boot `release/BILBIES.DS8` to CP/M `A>`, then type `BILBIES`. No Microbee Shell
is included. Target: Premium Plus, 32K PCG, 1MB Z80 RAM.

| Key | Renderer-harness action |
|---|---|
| O / P | Pan left/right by one native pixel |
| C / M | Colour / deliberately patterned monochrome |
| 1 / 4 | Ten / forty animated bilbies |
| D | Apply a native terrain-patch demonstration |

Panning clears the demonstration patches: they exercise the viewport-cell
job interface, not persistent world editing. The harness does not simulate
movement, skills or collision. Its gait animation and stress layouts test
composition. See `native/README.md` for exact scope.

The earlier playable compatibility baseline is retained as `release/BILBASE.DS8`
for regression comparison. It is not the default renderer or proposed final
architecture. Its save/settings features do not imply those features are
already integrated into the new renderer.

## Rebuild

Python 3.12, NumPy and Pillow are needed for the native asset compiler. The
bootstrap obtains pinned, hash-verified assembler/compressor tools in `.tools`.

```powershell
.\build.ps1 -Python C:\path\to\python.exe -Bootstrap
```

Default output: `build/native/BILBIES-NATIVE.DS8`. The default DOS donor is
`../LanternDeep/release/LANTERN.DS8`; `-BaseDisk` selects another compatible
owner-supplied image. The builder keeps system track-sides and CCP.SYS and
creates a fresh directory without Shell. Source art is local; image generation
is not part of rebuilding. Install `requirements-test.txt` for dependencies.

## Tests

Supply the owner's BN60 ROM at `resources/bn60.rom` and character ROM at
`resources/charrom.bin` for boot/font capture. Neither ROM is distributed.

```powershell
python native/test_renderer.py
python native/profile_renderer.py
```

Tests execute the Z80 binary in the adapted Premium Plus model. They check
24 camera/phase cases across colour/mono, masked composition of ten and forty
overlapping bilbies, edge clipping, zero actors, native terrain patches,
keyboard panning/mode selection, unchanged static PCG on scroll, and a canary
proving 7000h-77FFh is untouched. Actual BN60/CP-M boot/launch is exercised.
Measurements exclude some bus waits and do not emulate ColdFire.

The baseline can still be rebuilt with `-CompatibilityBaseline` and tested
with `tools/verify_port.py --solutions`. Those original 24-level results are
physics/content regression coverage, not new-renderer gameplay coverage.

## Outstanding work

The bespoke renderer is a working component, not a finished engine. Sprite
composition is too expensive at forty actors. The dynamic tile pool is
bounded, persistent world edits are not connected, and larger dirty regions
need a residency policy. Next work: performance/residency and simulation
integration, remaining levels, native menus, mouse, audio, saved preferences
and progress, independent emulator and physical-machine testing.

The owner confirmed the ColdFire Premium Plus. Compositor work can be
offloaded only after a supported worker-loading/bus-ownership interface is
established; that remains unavailable. See `docs/COLDFIRE.md`.

Details: `native/README.md`, `docs/HANDOVER.md`, `docs/PROGRESS.md` and
`docs/ORIGINAL.md`. The repository's original `Bilbies/` folder is unchanged.
