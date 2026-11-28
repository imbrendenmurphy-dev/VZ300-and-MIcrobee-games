# Confirmed target: ColdFire Premium Plus

The owner confirmed the Microbee Technology Premium Plus with ColdFire on
2026-11-02 and requested offloading suitable work. This takes priority over
further investment in the slow Z80 compatibility renderer. Existing DS8 is
a Z80 baseline for that machine, with no ColdFire acceleration implemented.

## Established from primary material

[Manufacturer specifications](https://microbeetechnology.com.au/previous-releases.html)
list MCF52259 ColdFire V2 at 80MHz, Z80 at 3.375MHz, 1MB shared SRAM plus
1MB ColdFire-exclusive SRAM, and 32K PCG. Shared memory is real; a usable
application offload API has not yet been established.

[Designer explanation of bus ownership](https://microbeetechnology.com.au/forum/post-1416.html)
states that BUSREQ/BUSACK stops the Z80 while the ColdFire handles trapped
disk-controller accesses or accesses mainboard memory/I/O. Therefore a
speed calculation cannot assume both CPUs freely access PCG simultaneously.

The manufacturer's ECO20120714-2 explains extra FPGA synchronization for
ColdFire screen-memory accesses because its external bus cannot use the
Z80 WAIT mechanism. ECO20121031-1 concerns bus relinquishment. Board ECO
status matters for real-hardware validation. These documents were located
through indexed manufacturer text; full local copies were not obtained.

The [Microbee uClinux console driver](https://github.com/kuroneko/uclinux-4.4-microbeepp/blob/master/linux/drivers/video/console/mbee_console.c)
and [hardware header](https://github.com/kuroneko/uclinux-4.4-microbeepp/blob/master/linux/arch/m68k/include/asm/microbeepp.h)
demonstrate memory-mapped access to the CRTC, PCG/colour and screen/attribute
windows through the FPGA/mini-FlexBus. They explicitly warn about slow
arbitration, chip-select timing and interrupt/preemption exclusion.
The repository is marked INCOMPLETE. Its addresses/timing values are
evidence to investigate, not a verified firmware ABI for this owner's board.

[uBee512's documentation](https://github.com/snakebyte69/uBee512/blob/main/doc/README)
states that its Premium Plus implementation covers the Z80 side, not the
ColdFire or a coprocessor API. The current ppmodel also models only the Z80
side. Neither can establish that an accelerated build works.

Do not transplant API details from the manufacturer's 2025 development
machines: those posts describe a different MC68SZ328 platform. Their
three-I/O-port service convention is not evidence of an MCF52259 ABI.

## Work split to evaluate

1. ColdFire: terrain viewport composition, per-pixel phase generation,
   sprite compositing, monochrome pattern generation, decompression and
   cache preparation in private RAM. These are candidates, not implemented
   accelerated features.
2. Z80 initially: original simulation, input and CP/M launch/save semantics,
   maintaining the validated original rules and solution oracle.
3. Batch display transfer: publish a completed frame/dirty-cell list, acquire
   mainboard bus ownership, update PCG/screen/attributes/colour, then release.
   Measure arbitration, synchronization and worst-case Z80 stall time.
4. Preserve the resident firmware's SD/floppy emulation and saving services.
   A worker must not replace or starve them. A full ColdFire takeover into
   uClinux is not equivalent to the requested CP/M-prompt launch workflow.

Whether the resident firmware can schedule application code while the Z80
runs remains unknown. A custom firmware extension may be necessary; no
firmware changes or flash operations have been performed or proposed as an
already-supported installation step.

## Precise missing material

Need the owner's Premium Plus ColdFire/FPGA firmware versions and original
SD-card/development package, or documented application-service entry points:
worker loading/execution, reserved shared/private RAM, bus acquisition and
release, cache/coherency rules, and coexistence with disk emulation. Searched
public owner repositories, manufacturer pages, public uClinux source and
local Microbee game folders; no supported CP/M-to-ColdFire worker interface
was found. Asked the owner for the local package path/version.

Next probe should be a tiny round-trip job with a known buffer and checksum,
followed by a bounded video-transfer benchmark and concurrent disk read/write
test. Assign no mailbox addresses or I/O ports until firmware establishes
them. Do not infer acceleration from the nominal 80MHz CPU speed.
