"""A stand-in for the Microbee boot ROM, for tests only.

The real boot ROM (bn60.rom) is not in the repository. All the ROM does to
start a disk is: read track 0, side 0, sector 1 to 0080h and jump to it;
that boot sector then calls one ROM routine (E039h: read BC bytes from
track D, sector E, side 0, to HL) twice to fetch CP/M, turns the ROMs off
and jumps to the BIOS. This does those two jobs in Python so that the
disk's own boot sector, CP/M BIOS, BDOS, CCP.SYS and the game's loader all
run for real in the emulator.
"""
from mbee import L

ROM_READ = 0xE039


def cold_boot(pp, disk, max_fields=3000):
    """boot `disk` (bytes) in the model `pp`; returns when A> is on screen"""
    pp.out(0x50, 0x04)                      # ROMs off, block 2 low, video at F000
    for i, b in enumerate(disk[:512]):
        pp.poke(0x80 + i, b)
    pp.cpu.pc = 0x80
    pp.cpu.sp = 0x80
    L.mb_set_bp(pp.h, ROM_READ, 1)
    reads = 0
    for _ in range(max_fields):
        hit = L.mb_run(pp.h, pp.tick + 67608)
        if hit and pp.cpu.pc == ROM_READ:
            d, e = pp.cpu.d, pp.cpu.e
            hl = (pp.cpu.h << 8) | pp.cpu.l
            bc = (pp.cpu.b << 8) | pp.cpu.c
            off = d * 2 * 5120 + (e - 1) * 512
            for i in range(bc):
                pp.poke(hl + i, disk[off + i])
            pp.cpu.a = 0
            pp.cpu.f = 0x40                 # Z: read ok
            sp = pp.cpu.sp
            pp.cpu.pc = pp.peekw(sp)
            pp.cpu.sp = sp + 2
            reads += 1
            if reads == 2:
                L.mb_set_bp(pp.h, ROM_READ, 0)
        if 'A>' in pp.text(64, 16):
            return True
    return False


def type_text(pp, text, hold=4, gap=4):
    for ch in text:
        k = 'RET' if ch == '\r' else ('SPACE' if ch == ' ' else ch)
        pp.keys = {k}
        pp.run_frames(hold)
        pp.keys = set()
        pp.run_frames(gap)
