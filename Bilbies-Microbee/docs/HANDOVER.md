# Handover — 2026-11-02

Owner's goal remains unfinished. This branch contains a native, bootable
prototype, not a completed enhanced Microbee conversion. Do not present the
compatibility renderer as an acceptable final architecture.

Latest steering: the owner confirmed the ColdFire Premium Plus and wants
appropriate tasks offloaded. Read COLDFIRE.md before further renderer work.
An original SD-card/firmware/development-package path and firmware version
have been requested. Do not invent a CP/M-to-ColdFire API. The nominal CPU
and shared RAM are verified in manufacturer material; the worker-loading
interface and simultaneous execution remain unverified.

## Source authority

Owner confirmed OneDrive BILBIES.VZ is newer. The adjacent source archive is
preserved in src/ and original-tools/ (src/ now has native modifications).
Documents/Bilbies_VZ300 matches the older GitHub binary. SHA256s and account
repository inventory are in PROGRESS.md. Main source clone is in the local
outputs/Bilbies-Microbee folder, branch codex/bilbies-microbee-premium-plus.

## Local build environment

Working Python executable:
`C:\Users\Owner\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`

The `python` app alias and `py` launcher failed here, despite Python313 files
being present. Python 3.12.14 from the bundled runtime works. sjasmplus 1.24
fails in Windows filesystem canonicalization; 1.20.3 works.

From the port folder, use build.ps1 with -Python pointing to that executable.
The network bootstrap is optional if sjasmplus and zx0 are on PATH. Existing
downloaded tools for this session are in workspace work/tools/sjasm-old and
work/tools/ZX0/win. Native z80 dependency was extracted to
workspace work/python-libs; set PYTHONPATH there for this session's tests.
The pip --target installation in work/pydeps produced inaccessible directories;
do not depend on it. Bundled NumPy/Pillow work without that directory.

For the boot test an owner's local BN60 ROM was copied from
Documents/Codex/2026-10-29/p/work/ubee/bn60.rom into resources/ (Git ignored).
DOS comes from the repository's existing Lantern disk. No additional DOS
distribution was downloaded. All original project work remains intact.

## Important implementation details

Native engine retains the original logical framebuffer at 7000h and physics
mask at DE00h. Most original game routines are unchanged. microbee.asm
provides polled display/input and banking. level.asm was adapted so compressed
levels are unpacked from block9; scenery decodes into fixed upper scratch
before copying to the home bank. Scripts use the same bounce technique.
The loader stages the engine in block15 and tables in blocks8/9, then moves
the engine to 8000h. It passes the CP/M launch drive through home address
6FFEh. Do not map F000 video while using the normal upper stack.

save.asm uses bounded WD2793 status/DRQ waits. SAVE.DAT must be directory
entry zero and allocation block1. It verifies that entry and signature before
writing track2/side0/sector26, then reads back settings/progress. This format
is intentionally restricted; it cannot follow a moved save file. Recreate a
disk with disk.py rather than moving files around in a disk editor.

## Next engineering step

Read HARDWARE.md and the performance report. The next milestone is a shared
glyph renderer with genuinely measured fine scrolling, not more features on
the slow compatibility renderer. Preserve the original terrain/physics
oracle and all-level solution tests while changing presentation.

Keep test claims separate: map equality, headless solution wins, native first
level, ROM/model boot, settings/save roundtrip, independent emulator, hardware.
Only the first five categories have useful results from this session.
Independent uBee512 launch from this sandbox did not yield a usable test;
it must not be counted as a pass. Real hardware has not been tested.

Current build and test outputs are in build/ and test-output/. Release and
selected reports/screenshots are copied into release/ and docs/reports/ for
review. Check their manifests against final commit history before resuming.
