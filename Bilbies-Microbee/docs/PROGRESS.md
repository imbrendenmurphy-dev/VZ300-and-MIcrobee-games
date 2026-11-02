# Bilbies! Premium Plus progress

2026-11-02: Cloned the main repository on branch `codex/bilbies-microbee-premium-plus`.
Inspected Bilbies source, generators, original manual, and Lantern Deep's
banking, PCG, input, loader, disk builder and emulator. The account's other
public repository, Microbee, is empty.

The user selected the OneDrive BILBIES.VZ as the newer baseline. SHA256:
`a9c3ef95898f5bd57e73b3705db2f4a7a2fe60f3595cc19cd5c5f63e602afa98`.
The Documents/Bilbies_VZ300 binary matches GitHub instead:
`960f43fdf0ad17a319690db66e1b05c59685937311c6365f079ec933f8da8127`.
The OneDrive source ZIP differs in front.asm and tools/levels.py after
normalizing line endings. It is the source used in this separate port folder.
Original repository source is left unchanged.

Downloaded sjasmplus 1.24.0 fails in std::filesystem::canonical in this Windows
sandbox. Version 1.20.3 runs successfully. ZX0 upstream supplies a Windows
binary. A repository-baseline assembly succeeded at DBBAh; this is an assembly
check, not a gameplay test.

Status: implementation in progress; no completed Microbee conversion claimed.

2026-11-02, native bring-up milestone: assembled a Premium Plus Z80 engine,
adapted the banked level/stamp/script access, added PCG conversion patterns,
keyboard/joystick translation, startup and G display settings, and same-disk
progress/preference saving. Built a fresh DS8 that boots to CP/M A> and runs
BILBIES without Shell in the actual-ROM/software-model test.

All 24 maps plus title match the reference, all 24 solution scripts pass
with presentation bypassed, and the first level also completes with native
presentation enabled. Save/restart, write protection and deleted-save
refusal pass in the model. See TESTING.md for scope and final-build coverage.
Performance measurements reject this renderer as final: 4.235 frames for an
unchanged presentation, 9.791 for a sample scroll. Full upgrade remains open.

Owner confirmed the ColdFire Premium Plus and requested appropriate work
offloading. Researched manufacturer specs, bus arbitration/ECO notes and
the public Microbee uClinux console driver. No supported CP/M worker-loading
API identified. Firmware/software package path requested. A further lead for
external assembly tests has not yet produced a confirmed public repository;
a project URL has been requested. See COLDFIRE.md.

Published the prototype through the connected GitHub service after CLI
credential storage failed; draft PR #1 records the unfinished scope and
test limitations. The remote Git tree was verified identical to local.
The owner will seek the outstanding assembly examples later. Explained that
small assembly probes measure specific memory/bus/timing behaviour; they do
not establish a missing coprocessor launch interface by themselves.
