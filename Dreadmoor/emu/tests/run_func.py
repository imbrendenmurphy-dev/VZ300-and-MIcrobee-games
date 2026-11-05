#!/usr/bin/env python3
"""Functional tests: assemble small programs, wrap as .VZ, run in vzemu,
dump RAM results and compare with expected values."""
import subprocess, sys, os, struct, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
EMU = os.path.join(HERE, '..', 'vzemu')
ASM = os.path.join(HERE, '..', '..', 'tools', 'z80asm.py')
TMP = tempfile.mkdtemp(prefix='vzt')

def build(name, src, org=0x8000):
    a = os.path.join(TMP, name + '.asm'); b = os.path.join(TMP, name + '.bin'); v = os.path.join(TMP, name + '.vz')
    open(a, 'w').write('    org $%04X\n' % org + src)
    r = subprocess.run([sys.executable, ASM, a, b], capture_output=True, text=True)
    if r.returncode: print(r.stdout); raise SystemExit('asm failed: ' + name)
    data = open(b, 'rb').read()
    hdr = b'VZF0' + name.upper().encode()[:16].ljust(17, b'\0') + bytes([0xF1]) + struct.pack('<H', org)
    open(v, 'wb').write(hdr + data)
    return v

def run(vz, args=(), dump=(0x9000, 0x100)):
    d = os.path.join(TMP, 'dump.bin')
    r = subprocess.run([EMU, vz, '-d', '%X:%X:%s' % (dump[0], dump[1], d)] + list(args), capture_output=True, text=True)
    return open(d, 'rb').read(), r.stdout

fails = 0
def check(name, got, want):
    global fails
    if got == want: print('  ok   %s' % name)
    else:
        fails += 1; print('  FAIL %s: got %s want %s' % (name, got, want))

print('[basic regs / stack / exchange / index]')
def T(name, src, checks, args=(), dump=(0x9000, 0x100)):
    vz = build(name, src)
    mem, out = run(vz, args, dump)
    for desc, off, want in checks:
        if isinstance(want, int): want = [want]
        check(desc, list(mem[off:off + len(want)]), list(want))
    return mem, out

BASIC = r'''
    di
    ld sp,$f000
    ld bc,$1234
    ld de,$5678
    ld hl,$9abc
    push bc
    push de
    pop bc
    pop de
    ld ($9000),bc
    ld ($9002),de
    ex de,hl
    ld ($9004),de
    ld ($9006),hl
    exx
    ld hl,$1111
    exx
    ld ($9008),hl
    exx
    ld ($900a),hl
    exx
    ld a,$55
    ex af,af'
    ld a,$aa
    ex af,af'
    ld ($900c),a
    ld hl,$4321
    push hl
    ld hl,$0000
    ex (sp),hl
    ld ($900e),hl
    pop hl
    ld ($9010),hl
    ld ix,$9080
    ld iy,$9080
    ld (ix+5),$11
    ld (ix-3),$22
    ld (iy+127),$33
    ld (iy-128),$44
    ld a,(ix+5)
    add a,(iy-3)
    ld ($9012),a
    ld b,(ix-3)
    ld a,b
    ld ($9013),a
    inc (ix+5)
    dec (iy-3)
    ld ix,$1234
    ld a,ixh
    ld ($9014),a
    ld a,ixl
    ld ($9015),a
    ld ixl,$77
    inc ixh
    ld ($9016),ix
    ld iyh,$80
    ld iyl,$01
    ld a,iyh
    add a,iyl
    ld ($9018),a
    ld ix,$9080
    ld b,(ix+5)
    ld a,b
    ld ($9019),a
    ld a,(ix-3)
    ld ($901a),a
    ld de,$0100
    add ix,de
    ld ($901b),ix
    ld hl,0
    add hl,sp
    ld ($901d),hl
    ld iy,$2000
    ld sp,iy
    ld hl,0
    add hl,sp
    ld sp,$f000
    ld ($901f),hl
    ld a,$3c
    ld i,a
    xor a
    ld a,i
    ld ($9021),a
    ld hl,$9022
    ld (hl),$a5
    ld a,(hl)
    cpl
    ld ($9023),a
    ld hl,$9024
    ld (hl),$f0
    ld a,$0c
    rld
    ld ($9025),a
    ld a,$0c
    ld hl,$9026
    ld (hl),$f0
    rrd
    ld ($9027),a
    ld hl,back
    push hl
    ld ix,tgt
    jp (ix)
back:
    ld a,$c3
    ld ($9029),a
    ld bc,$9030
    ld a,$77
    ld (bc),a
    ld de,$9031
    ld a,$88
    ld (de),a
    ld a,(bc)
    ld ($9032),a
    halt
tgt:
    ld a,$99
    ld ($9028),a
    ret
'''
T('basic', BASIC, [
    ('push/pop swap', 0x01, [0x56, 0x34, 0x12]),
    ('ex de,hl', 0x04, [0xbc, 0x9a, 0x34, 0x12]),
    ('exx keeps main', 0x08, [0x34, 0x12]),
    ('exx alt set', 0x0a, [0x11, 0x11]),
    ("ex af,af'", 0x0c, 0x55),
    ('ex (sp),hl', 0x0e, [0x21, 0x43, 0, 0]),
    ('(ix+5)+(iy-3)', 0x12, [0x33, 0x22]),
    ('ixh/ixl read', 0x14, [0x12, 0x34]),
    ('ixl write, inc ixh', 0x16, [0x77, 0x13]),
    ('iyh+iyl', 0x18, 0x81),
    ('inc/dec (ix+d)', 0x19, [0x12, 0x21]),
    ('add ix,de', 0x1b, [0x80, 0x91]),
    ('add hl,sp', 0x1d, [0x00, 0xf0]),
    ('ld sp,iy', 0x1f, [0x00, 0x20]),
    ('ld a,i', 0x21, 0x3c),
    ('cpl', 0x23, 0x5a),
    ('rld', 0x24, [0x0c, 0x0f]),
    ('rrd', 0x26, [0xcf, 0x00]),
    ('jp (ix)/ret', 0x28, [0x99, 0xc3]),
    ('ld (bc)/(de)', 0x30, [0x77, 0x88, 0x77]),
])
# check raw index addresses
mem, _ = T('idx', r'''
    di
    ld iy,$9080
    ld (iy+127),$33
    ld (iy-128),$44
    ld ix,$9010
    ld (ix-1),$ee
    halt
''', [('(iy+127)', 0xff, 0x33), ('(iy-128)', 0x00, 0x44), ('(ix-1)', 0x0f, 0xee)])

# ---------------------------------------------------------------- 2 flags in context
print('[flags / branches / 16-bit]')
T('flags', r'''
    di
    ld sp,$f000
    ; 16-bit SBC/ADC
    ld hl,$8000
    ld de,$0001
    or a
    sbc hl,de        ; 7fff, P/V set (overflow), N set
    push af
    pop bc
    ld ($9000),hl
    ld a,c
    ld ($9002),a
    ld hl,$7fff
    scf
    adc hl,de        ; 7fff+1+1 = 8001, overflow, S
    push af
    pop bc
    ld ($9003),hl
    ld a,c
    ld ($9005),a
    ld hl,$0001
    ld de,$0001
    or a
    sbc hl,de        ; 0 Z
    push af
    pop bc
    ld a,c
    ld ($9006),a
    ; DAA BCD add 0x19+0x28=0x47
    ld a,$19
    add a,$28
    daa
    ld ($9007),a
    ld a,$47
    sub $19
    daa              ; 28
    ld ($9008),a
    ld a,$99
    add a,$01
    daa              ; 00 carry
    push af
    pop bc
    ld ($9009),bc    ; c=flags b=a
    ; BIT on (hl) and (ix+d)
    ld hl,$9080
    ld (hl),$80
    bit 7,(hl)
    ld a,0
    jr z,b1
    ld a,1
b1: ld ($900b),a     ; 1
    bit 6,(hl)
    ld a,0
    jr nz,b2
    ld a,1
b2: ld ($900c),a     ; 1
    ld ix,$9070
    ld (ix+16),$01
    bit 0,(ix+16)
    ld a,0
    jr z,b3
    ld a,1
b3: ld ($900d),a     ; 1
    set 4,(ix+16)
    res 0,(ix+16)
    ld a,(ix+16)
    ld ($900e),a     ; 10
    ; DDCB undocumented: rlc (ix+d),b -> result also in b
    ld (ix+17),$81
    db $dd,$cb,17,$00   ; rlc (ix+17),b
    ld a,b
    ld ($900f),a        ; 03
    ld a,(ix+17)
    ld ($9010),a        ; 03
    ; SLL
    ld c,$40
    sll c               ; 81
    ld a,c
    ld ($9011),a
    ; rr (ix-1)
    ld ix,$9081
    scf
    rr (ix-1)           ; 9080 holds 80 -> c0, carry 0
    ld a,(ix-1)
    ld ($9012),a
    ; conditional ops: JP PE/PO, CALL M, RET cc
    ld a,$7f
    inc a               ; overflow -> PE, M
    ld b,0
    jp po,nope
    ld b,1
    call m,sub1
    call p,sub2
    ld a,b
    ld ($9013),a        ; 1+10 = 11
    ; DJNZ count
    ld b,200
    ld hl,0
dj: inc hl
    djnz dj
    ld ($9014),hl       ; 200
    ; NEG
    ld a,$80
    neg
    push af
    pop bc
    ld ($9016),bc       ; c flags, b=80
    ; CP sets 5/3 from operand
    ld a,$00
    cp $28
    push af
    pop bc
    ld a,c
    ld ($9018),a
    ; IN r,(c) flags and ld a,r non-zero
    ld a,r
    ld ($9019),a
    ; 16-bit inc/dec don't touch flags
    xor a               ; Z set
    ld bc,$ffff
    inc bc
    push af
    pop de
    ld a,e
    ld ($901a),a        ; 44
    ld ($901b),bc       ; 0000
nope:
    halt
sub1: ld b,11
    ret
sub2: ld b,$ee
    ret
''', [
    ('sbc hl 8000-1', 0x00, [0xff, 0x7f, 0x3e]),
    ('adc hl 7fff+1+c', 0x03, [0x01, 0x80, 0x94]),
    ('sbc hl -> 0', 0x06, 0x42),
    ('daa add', 0x07, 0x47),
    ('daa sub', 0x08, 0x28),
    ('daa 99+1', 0x09, [0x55, 0x00]),
    ('bit 7,(hl) / bit 6', 0x0b, [1, 1]),
    ('bit (ix+d)', 0x0d, 1),
    ('set/res (ix+d)', 0x0e, 0x10),
    ('ddcb rlc (ix+d),b', 0x0f, [0x03, 0x03]),
    ('sll', 0x11, 0x81),
    ('rr (ix-1)', 0x12, 0x88),
    ('cc jumps/calls', 0x13, 11),
    ('djnz 200', 0x14, [200, 0]),
    ('neg 80', 0x16, [0x87, 0x80]),
    ('cp undoc 5/3', 0x18, 0xbb),
    ('inc bc no flags', 0x1a, [0x44, 0, 0]),
])

# ---------------------------------------------------------------- 3 block ops
print('[block ops]')
T('block', r'''
    di
    ld sp,$f000
    ld hl,src
    ld de,$9000
    ld bc,8
    ldir
    push af
    pop bc
    ld a,c
    and $16
    ld ($9010),a        ; flags after ldir: H,P/V,N=0
    ld ($9011),hl
    ld ($9013),de
    ld hl,src+7
    ld de,$9027
    ld bc,8
    lddr                ; copies to 9020..9027
    ld hl,src
    ld de,$9030
    ld bc,3
    ldi                 ; bc=2, P/V=1
    push af
    pop bc
    ld a,c
    and $04
    ld ($9038),a        ; 4
    ; cpir find 5 in src
    ld hl,src
    ld bc,8
    ld a,5
    cpir                ; found at src+4, hl=src+5, bc=3, Z, P/V=1
    push af
    pop de
    ld a,e
    and $c4
    ld ($9039),a        ; 44
    ld ($903a),bc       ; 3
    ld de,src
    or a
    sbc hl,de
    ld a,l
    ld ($903c),a        ; 5
    ; cpir not found
    ld hl,src
    ld bc,8
    ld a,$77
    cpir                ; bc=0, NZ, P/V=0
    push af
    pop de
    ld a,e
    and $c4
    ld ($903d),a        ; 0? S could be set: 77-(last=8)=6f -> 0
    ld ($903e),bc
    ; cpdr
    ld hl,src+7
    ld bc,8
    ld a,2
    cpdr                ; found at src+1, hl=src, bc=1
    ld ($9040),bc
    ld de,src
    or a
    sbc hl,de
    ld a,l
    ld ($9042),a        ; 0
    halt
src: db 1,2,3,4,5,6,7,8
''', [
    ('ldir copy', 0x00, [1, 2, 3, 4, 5, 6, 7, 8]),
    ('ldir P/V clear', 0x10, 0x00),
    ('lddr copy', 0x20, [1, 2, 3, 4, 5, 6, 7, 8]),
    ('ldi P/V set', 0x38, 4),
    ('cpir found flags', 0x39, 0x44),
    ('cpir found bc', 0x3a, [3, 0]),
    ('cpir found hl', 0x3c, 5),
    ('cpir not found flags', 0x3d, 0x00),
    ('cpir not found bc', 0x3e, [0, 0]),
    ('cpdr bc', 0x40, [1, 0]),
    ('cpdr hl', 0x42, 0),
])

# ---------------------------------------------------------------- 4 interrupts
print('[interrupts / halt / timing]')
mem, out = T('im2', r'''
    di
    ld sp,$f000
    ld a,$a0
    ld i,a
    ld hl,isr
    ld ($a0ff),hl
    im 2
    xor a
    ld ($9000),a
    ld ($9001),a
    ei
loop:
    halt
    ld a,($9001)
    inc a
    ld ($9001),a
    jr loop
isr:
    push af
    ld a,($9000)
    inc a
    ld ($9000),a
    pop af
    ei
    reti
''', [('IM2 isr count 50 fields', 0x00, 50), ('main loop wakes', 0x01, 50)], args=['-f', '50'])
print('    ' + [l for l in out.split('\n') if 'interrupts' in l][0])
print('    ' + [l for l in out.split('\n') if 'busy' in l][0])
# EI delay: ei;di must not take the pending IRQ; ei;nop;di must.
T('eidelay', r'''
    di
    ld sp,$f000
    ld a,$a0
    ld i,a
    ld hl,isr
    ld ($a0ff),hl
    im 2
    ld a,1
    ei
    di
    ld ($9000),a        ; stays 1 if no irq
    ld a,2
    ei
    nop
    di
    ld ($9001),a
    halt
isr:
    ld a,$99
    ret                 ; leaves interrupts disabled
''', [('ei;di no irq', 0x00, 1), ('ei;nop;di takes irq', 0x01, 0x99)], args=['-f', '2'])
# Only once per field; level held 56 lines
T('oncefield', r'''
    di
    ld sp,$f000
    ld a,$a0
    ld i,a
    ld hl,isr
    ld ($a0ff),hl
    im 2
    ei
lp: jr lp
isr:
    push af
    ld a,($9000)
    inc a
    ld ($9000),a
    pop af
    ei
    ret                 ; reenable immediately, still in FS lines
''', [('one irq per field (10)', 0x00, 10)], args=['-f', '10'])
# IM1 -> 0038 (no ROM) detection
mem, out = T('im1', r'''
    di
    ld sp,$f000
    im 1
    ei
lp: jr lp
''', [], args=['-f', '3'])
line = [l for l in out.split('\n') if 'ROM' in l][0]
check('IM1 -> ROM 0038 detected', '0038' in line and 'interrupt' in line, True)
# DI HALT hang detection
mem, out = T('hang', 'di\n halt\n', [], args=['-f', '2'])
check('DI/HALT hang reported', 'HANG' in out, True)

# Frame timing: count instructions between interrupts: busy loop of known T
# Loop: dec de (6) ; ld a,d (4) ; or e (4) ; jp nz (10) = 24T per iteration.
# Measure iterations per field via ISR snapshot.
mem, out = T('tframe', r'''
    di
    ld sp,$f000
    ld a,$a0
    ld i,a
    ld hl,isr
    ld ($a0ff),hl
    im 2
    ld de,0
    ei
    halt                ; sync to irq
lp: inc de              ; 6
    jp lp               ; 10  -> 16T per iter
isr:                    ; isr: ack 19
    ld ($9000),de       ; 20
    ld de,0             ; 10
    ei                  ; 4
    reti                ; 14
''', [], args=['-f', '5'])
iters = mem[0] | mem[1] << 8
# per field: 71136 = 19+20+10+4+14 + 16*k (+ partial)
k = (71136 - 67) / 16
check('iterations/field ~ %.1f' % k, abs(iters - k) <= 1, True)

# ---------------------------------------------------------------- 5 machine
print('[machine: keyboard, joystick, SRAM, snow, video, audio]')
keyscr = os.path.join(TMP, 'keys.txt')
open(keyscr, 'w').write('1 Q SPACE J1FIRE J1LEFT J2UP J1ARM\n')
T('keys', r'''
    di
    ld a,($68fe)        ; row A0 (R Q E - W T): Q = bit1 low
    ld ($9000),a
    ld a,($68ef)        ; row A4: SPACE bit1
    ld ($9001),a
    ld a,($68ff)        ; no rows
    ld ($9002),a
    ld a,($6800)        ; all rows
    ld ($9003),a
    in a,($2e)          ; joy1
    ld ($9004),a
    in a,($2b)          ; joy2
    ld ($9005),a
    in a,($2d)          ; arm
    ld ($9006),a
    in a,($10)
    ld ($9007),a
    halt
''', [
    ('kbd row A0 Q (in FS: bit7=0)', 0x00, 0x7d),
    ('kbd row A4 SPACE', 0x01, 0x7d),
    ('kbd no row', 0x02, 0x7f),
    ('kbd all rows', 0x03, 0x7d),
    ('joy1 fire+left', 0x04, 0xeb),
    ('joy2 up', 0x05, 0xfe),
    ('joy arm', 0x06, 0xef),
    ('other port', 0x07, 0xff),
], args=['-i', keyscr, '-f', '1'])

T('fsbit', r'''
    di
    ld hl,0
w1: ld a,($68ff)
    rla
    jr nc,w1            ; wait for bit7=1 (end of FS, line 56)
w2: inc hl              ; count until FS again
    ld a,($68ff)
    rla
    jr c,w2
    ld ($9000),hl
    halt
''', [], args=['-f', '2'])
mem, _ = run(os.path.join(TMP, 'fsbit.vz'), ['-f', '2'])
n = mem[0] | mem[1] << 8
# loop is 6+13+4+12 = 35T; FS-off period = (312-56)*228 = 58368 T
check('FS bit high for %d iters (~1668)' % n, abs(n - 58368 / 35) <= 2, True)

T('sram', r'''
    di
    ld a,1
    out ($37),a
    ld a,$aa
    ld ($4000),a
    ld ($67ff),a
    ld a,3
    out ($37),a
    ld a,$bb
    ld ($4000),a
    ld a,($67ff)        ; bank B fresh: 00
    ld ($9000),a
    ld a,1
    out ($37),a
    ld a,($4000)
    ld ($9001),a        ; aa
    ld a,3
    out ($37),a
    ld a,($4000)
    ld ($9002),a        ; bb
    ld a,0
    out ($37),a
    ld a,$cc
    ld ($4000),a        ; ignored
    ld a,($4000)
    ld ($9003),a        ; ff
    ld a,3
    out ($37),a
    ld a,($4000)
    ld ($9004),a        ; bb
    ld a,($0000)
    ld ($9005),a        ; ROM ff
    ld a,$12
    ld ($1000),a
    ld a,($1000)
    ld ($9006),a        ; ff
    halt
''', [('bank B separate', 0x00, 0x00), ('bank A', 0x01, 0xaa), ('bank B', 0x02, 0xbb),
      ('unmapped ff', 0x03, 0xff), ('bank B kept', 0x04, 0xbb), ('ROM reads ff', 0x05, [0xff, 0xff])])

# snow: write 32 bytes to VRAM starting near line 0 (no snow), then wait into display & write 10
mem, out = T('snow', r'''
    di
    ld hl,$7000
    ld b,32
s1: ld (hl),$55
    inc hl
    djnz s1             ; during FS: no snow
    ; wait until line ~100: 100*228 = 22800 T; delay loop 26T/iter -> 877
    ld bc,877
d1: dec bc
    ld a,b
    or c
    jr nz,d1
    ld hl,$7000
    ld b,10
s2: ld a,(hl)           ; 10 reads
    djnz s2
    halt
''', [], args=['-f', '1'])
sl = [l for l in out.split('\n') if l.startswith('snow')][0]
print('    ' + sl)
check('snow counted 10', 'total 10,' in sl, True)

# video: mode 1, fill rows with colours, screenshot, check pixels
ppm_prefix = os.path.join(TMP, 'v')
T('video', r'''
    di
    ld a,$08
    ld ($6800),a        ; mode 1, css 0
    ld hl,$7000
    ld de,$7001
    ld (hl),$1b         ; pixels 0,1,2,3
    ld bc,$03ff
    ldir
    ld hl,$7400
    ld (hl),$ff
    ld de,$7401
    ld bc,$03ff
    ldir                ; lower half red
    halt
''', [], args=['-f', '3', '-s', '2', '-p', ppm_prefix])
img = open(ppm_prefix + '_0002.ppm', 'rb').read()
hdr = b'P6\n512 192\n255\n'
check('ppm header', img[:len(hdr)], hdr)
px = lambda x, y: tuple(img[len(hdr) + (y * 512 + x) * 3:][:3])
check('px(0,0) green', px(0, 0), (0, 255, 0))
check('px(4,0) yellow', px(4, 0), (255, 255, 0))
check('px(8,0) blue', px(8, 0), (0, 0, 255))
check('px(12,2) red', px(12, 2), (255, 0, 0))
check('px(100,150) red (lower half)', px(100, 150), (255, 0, 0))
subprocess.run([EMU, os.path.join(TMP, 'video.vz'), '-f', '3', '-s', '2', '-m', '-p', ppm_prefix + 'm'], capture_output=True)
img = open(ppm_prefix + 'm_0002.ppm', 'rb').read()
check('mono yellow lum', tuple(img[len(hdr) + 12:][:3]), (166, 166, 166))

# tearing: change VRAM mid-display; top rows show old, bottom rows new
T('tear', r'''
    di
    ld a,$08
    ld ($6800),a
w1: ld a,($68ff)
    rla
    jr nc,w1            ; field 1 line 56
w2: ld a,($68ff)
    rla
    jr c,w2             ; field 2 line 0
    ld bc,877           ; ~line 100
w3: dec bc
    ld a,b
    or c
    jr nz,w3
    ld a,$ff
    ld ($7000),a        ; row 0 already scanned this field
    ld ($77e0),a        ; row 63 not yet scanned
    halt
''', [], args=['-f', '3', '-s', '2,3', '-p', ppm_prefix + 't'])
img = open(ppm_prefix + 't_0002.ppm', 'rb').read()
top, bot = px(0, 0), px(0, 191)
check('tearing: field 2 row0 old, row63 new', (top, bot), ((0, 255, 0), (255, 0, 0)))
img = open(ppm_prefix + 't_0003.ppm', 'rb').read()
check('field 3 both new', (px(0, 0), px(0, 191)), ((255, 0, 0), (255, 0, 0)))

# audio: toggle speaker 1000 times with fixed period, write WAV
wav = os.path.join(TMP, 'a.wav')
mem, out = T('audio', r'''
    di
    ld c,0
    ld de,1000
lp: ld a,c
    xor 1
    ld c,a
    ld ($6800),a        ; 13
    ld b,100
dl: djnz dl             ; 99*13+8
    dec de
    ld a,d
    or e
    jr nz,lp
    halt
''', [], args=['-f', '20', '-w', wav])
sp = [l for l in out.split('\n') if 'speaker' in l][0]
check('speaker transitions 1000', 'transitions: 1000' in sp, True)
w = open(wav, 'rb').read()
check('wav RIFF/44100', (w[:4], struct.unpack('<I', w[24:28])[0]), (b'RIFF', 44100))
samples = struct.unpack('<%dh' % ((len(w) - 44) // 2), w[44:])
check('wav has +/- levels', (max(samples) > 15000, min(samples) < -15000), (True, True))

print()
print('FUNCTIONAL TESTS', 'PASS' if fails == 0 else 'FAIL (%d)' % fails)
sys.exit(1 if fails else 0)
