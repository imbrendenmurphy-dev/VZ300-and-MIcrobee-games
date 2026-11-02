# Handover — 2026-11-02

## Latest milestone: bespoke renderer

Default build and release/BILBIES.DS8 now run native/renderer.asm: an independent
640x256 renderer harness. No VZ renderer, BACK buffer or 2-bpp frame conversion
is included. See native/README.md before resuming; it supersedes the earlier
compatibility-renderer architecture below. The old playable baseline is kept
as release/BILBASE.DS8 and behind build.ps1 -CompatibilityBaseline.

The new path has eight pixel scroll phases, banked native PCG maps, batched
masked sprite composition, native terrain-cell jobs and colour/mono artwork.
Source art includes an imagegen homestead; its original PNG and exact prompt
are in native/art. The compiler applies RGBI and per-cell colour restrictions.
Native tests prove the VZ framebuffer remains untouched.

It is NOT integrated gameplay. Forty-actor CPU composition is too expensive
(about 9.66 frames including terrain in the model), and edit-job residency is
bounded. No ColdFire execution is present. Do not use the older baseline's
24-level gameplay/save results as coverage for this new path. Next work is
compositor throughput, residency, then simulation/input/save integration.

Build from project with build.ps1 (sjasmplus on PATH, NumPy/Pillow available).
Run native/test_renderer.py and native/profile_renderer.py with the same
Python/PYTHONPATH described below. Local owner character ROM was copied into
resources/charrom.bin for captures; it is Git ignored. No ROM is distributed.

## Earlier compatibility milestone

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

## Publication

Draft PR: https://github.com/imbrendenmurphy-dev/VZ300-and-MIcrobee-games/pull/1

Remote branch: codex/bilbies-microbee-premium-plus. Git CLI push failed because
Windows Credential Manager could not persist credentials. The connected
GitHub service successfully published the committed source tree instead;
its Git tree SHA was checked against the local tree before publication.
Original local milestone history is preserved on codex/bilbies-local-milestones;
the bespoke renderer also has a normal local milestone commit. Publication
through the API creates a different commit ID with the same verified tree.
Keep both histories; do not force-push. If switching back to Git CLI publishing,
fetch and merge the remote branch once credentials are working.

The owner will request the outstanding external assembly examples later.
Do not repeatedly ask for that material. Those examples may help, but do not
assume they implement a ColdFire worker interface until they are inspected.
A SymbOS desktop alone is not evidence of ColdFire execution or concurrent
processing. No external person was contacted.
