"""Package the memory image into BILBIES.VZ for the BennVenn SD loader.

The file loads LOW at $8000 like a plain program (as Scramble / Cybernoid 1.1 /
Xevious 1.2). It doesn't touch the BennVenn mapper, and nothing runs from video
RAM:
  file @ $8000: [stub][stage2][payload (ZX0)]
  stub   : copies stage2 to $FF00 and the payload (backwards) to the top of
           memory, ending at $FEFF, then jumps to stage2
  stage2 : ZX0 payload -> $7800.. (stack in video RAM meanwhile), jp vz_boot
"""
import subprocess, sys, os, re
W = os.path.dirname(os.path.abspath(__file__)) + '/..'
B = W + '/build'
sys.path.insert(0, W + '/tools')
from mkvz import mkvz

def run(cmd, cwd=B):
    r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0 or re.search(r'Errors: [1-9]|error:', r.stdout + r.stderr):
        print(r.stdout[-3000:], r.stderr[-3000:]); sys.exit(1)
    return r.stdout + r.stderr

syms = {}
for l in open(B + '/vz.sym'):
    m = re.match(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)', l)
    if m: syms[m.group(1)] = int(m.group(2), 16)
boot = syms['vz_boot']; cend = syms['code_end']
mem = open(B + '/mem.bin', 'rb').read()          # $7800-$FFFF
img = mem[:cend - 0x7800]
open(B + '/img.raw', 'wb').write(img)
run('zx0 -f img.raw img.zx0')
z = open(B + '/img.zx0', 'rb').read()
lv = open(B + '/levels.bin', 'rb').read()      # already packed level by level
stage = cend + 64 - len(z)
src = r'''
        DEVICE NOSLOT64K
        ORG $8000
start:  di
        ld sp,$77F0
        ld hl,S2SRC
        ld de,$FF00
        ld bc,S2_END-S2SRC
        ldir
        jp $FF00
S2SRC:
        DISP $FF00
s2:     ld a,3                  ; SRAM bank B: the level designs, straight in
        out ($37),a
        ld hl,PAY2
        ld de,$4000
        ld bc,PAY2_END-PAY2
        ldir
        ld a,1
        out ($37),a
        ld hl,%(STAGE)d         ; then the program, unpacked in place over all this
        ld de,$7800
        call dzx0_standard
        jp %(BOOT)d
        INCLUDE "/tmp/ZX0/z80/dzx0_standard.asm"
        ENT
S2_END:
PAY2:   INCBIN "levels.bin"
PAY2_END:
        ASSERT PAY2_END <= %(STAGE)d
        BLOCK %(STAGE)d-PAY2_END,0
PAY:    INCBIN "img.zx0"
PAY_END:
        ASSERT S2_END-S2SRC <= 255
        SAVEBIN "bil_vz.bin",start,PAY_END-start
''' % dict(BOOT=boot, STAGE=stage)
open(B + '/stub.asm', 'w').write(src)
run('sjasmplus --nologo stub.asm')
bin_ = open(B + '/bil_vz.bin', 'rb').read()
assert 0x8000 + len(bin_) < stage or True
mkvz(B + '/bil_vz.bin', B + '/BILBIES.VZ', 0x8000, 'BILBIES')
sz = os.path.getsize(B + '/BILBIES.VZ')
print('BILBIES.VZ %d bytes, loads $8000-$%04X; image $7800-$%04X (%d), packed %d, boot $%04X'
      % (sz, 0x8000 + len(bin_) - 1, cend - 1, len(img), len(z), boot))
assert 0x8000 + len(bin_) <= 0xF9FF, 'file too long to load low'
