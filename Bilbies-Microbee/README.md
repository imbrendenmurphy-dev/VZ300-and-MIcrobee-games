# Bilbies! — Microbee Premium Plus prototype

**Work in progress, not the requested completed conversion.** Native Z80
bring-up retains the newer owner's Bilbies simulation, all 24 original
levels and scenery, title/trainer, skills, terrain destruction and solution
scripts. The compatibility renderer runs too slowly. This is a reviewable
milestone and a starting point for the replacement renderer.

The owner has confirmed the **ColdFire Premium Plus**. Acceleration is now
the next architecture investigation; see `docs/COLDFIRE.md`. This prototype
does not yet run code on ColdFire, and the test model does not emulate it.

## Run

Use `release/BILBIES.DS8` on a Premium Plus configured for 1MB RAM and 32K
PCG. Boot to `A>`, then type `BILBIES`. No Microbee Shell is included.
Choose **C** colour or **M** monochrome, then **SPACE** to leave settings.
**G** opens settings during the game. The mode choice is saved to disk.

QAOP or arrows move the cursor; Space/M or joystick fire assigns the skill
or activates the panel. X/Z cycle skills, 1–8 choose directly, comma/period
change release rate, H pauses, NN nukes, Ctrl-Q abandons. Use the cursor on
the skill panel and minimap to play with one joystick button. Edge scrolling
is still the original four-logical-pixel horizontal step, not per-pixel.

Progress and mode use preallocated `SAVE.DAT` on the launch drive, with a
signature, checksum and read-back verification. Missing/deleted save files
and write protection return failure. Runtime saving does not allocate space;
the file is reserved during disk construction. Do not relocate SAVE.DAT in
this prototype. A failed automatic progress save is currently only recorded
in `sv_error`; the settings screen shows explicit save failures. Saves use
one sector and are not power-failure atomic.

## Build on Windows

Python 3.12 was used. Assembly/compression needs sjasmplus 1.20.3 and ZX0.
The bootstrap downloads pinned tools into `.tools` and verifies their hashes.

```powershell
.\build.ps1 -Python C:\path\to\python.exe -Bootstrap
```

The default DOS donor is the repository's `LanternDeep/release/LANTERN.DS8`.
To use an owner's compatible CP/M disk, supply `-BaseDisk C:\path\BASE.DS8`.
The builder copies system track-sides and CCP.SYS, creates a fresh directory,
and validates file extraction and exact 819200-byte DS80 size. It does not
copy the donor's game or Shell. Build output is `build/BILBIES.DS8`.

## Tests

Install `requirements-test.txt` in your selected Python environment. Supply
your BN60 boot ROM at `resources/bn60.rom` for the boot test; it is not in Git.

```powershell
python tools/verify_port.py --solutions
python tools/boot_test.py
python tools/smoke.py
python tools/measure.py
python tools/native_solution.py
```

Tests execute Z80 instructions in the repository's adapted `ppmodel.py`
(non-cycle-exact Premium Plus model, z80 1.2.0 CPU core). `verify_port.py`
checks every terrain and collision pixel against the original Python builder.
Its solution tests explicitly replace only `mb_present` with RET, so those
results establish simulation regression coverage, not display performance.
`native_solution.py` keeps rendering enabled for the first level.

The boot test uses the actual owner's BN60 ROM and executes CP/M/BDOS from
the disk. It verifies prompt and takeover and captures screens. It does not
establish uBee512 or real-hardware compatibility. An attempted local uBee512
launch did not provide a usable verification result.

## Still required

- Replace the renderer; restore original real-time pace and implement smooth
  per-pixel scrolling. See measured rejection of this architecture in
  `docs/HARDWARE.md`.
- Substantial new Australiana artwork, larger sprites, enhanced animations
  and expanded layouts. Current art is the original, converted to PCG cells.
- Microbee mouse interrupt driver. Interface researched, not implemented.
- Audio driver: prototype sound/music calls are stubs.
- More extensive keyboard/joystick interaction tests and independent emulator
  testing. Monochrome patterns need human readability review.
- Better save resilience, moved-file handling, and visible automatic-save
  error notification; disk-full/error-injection tests.
- Full 1MB asset/cache architecture; most RAM is presently unused.
- Real hardware: banking, monitor timing, input interfaces, disk writes and
  sustained performance all remain to be verified.

See `docs/HANDOVER.md`, `docs/ORIGINAL.md`, `docs/PROGRESS.md` and
`docs/HARDWARE.md`. The original `Bilbies/` repository folder is unchanged.
