"""Make the patched VZDOS.VZ that boots straight into VZ-DECK.

Usage:  python3 patchdos.py [VZDOS.VZ from your BennVenn card] [output file]

The input must be BennVenn VZDOS 2.31 or 2.32 (Ben Grimmett's DOS). One jump at
$4043 is redirected into a small stub in the unused space at $5BBA; the rest
of the DOS is left exactly as it was. The stub loads SHELL.VZ from the root of
the card (hold B at power-on for plain BASIC, SPACE for the DOS command line),
and $5BBD is the launcher VZ-DECK uses to run games.
"""
import sys,os
from asm import assemble
src=sys.argv[1] if len(sys.argv)>1 else os.path.join('..','testfiles','VZDOS.VZ')
dst=sys.argv[2] if len(sys.argv)>2 else os.path.join('out','VZDOS.VZ')
stock=bytearray(open(src,'rb').read()); H=24; off=lambda a:a-0x4000+H
if stock[off(0x4043):off(0x4046)]!=bytes([0xC3,0x4E,0x4C]) or any(stock[off(0x5BBA):off(0x5F00)]):
    sys.exit('That does not look like an unpatched VZDOS 2.31/2.32')
stub_src='''
        JP boot
        JP launch
boot:   CP 'B'
        JP Z,0x4C4E
        LD HL,name
        LD DE,0xFB28
        LD BC,11
        LDIR
launch: DI
        LD SP,0xFFFF
        XOR A
        LD (0xFE0A),A
        LD A,1
        LD (0xFB44),A
        CALL 0x4D48
        LD A,(0xFB03)
        OR A
        JP Z,0x4C4E
        CALL 0x4F1C
        LD A,(0xFB40)
        CP 0xF0
        JR Z,basic
        DI
        LD HL,0
        PUSH HL
        LD HL,(0xFA3D)
        JP (HL)
basic:  LD HL,(0xFB20)
        LD DE,(0xFA3D)
        ADD HL,DE
        LD DE,0xFFE8
        ADD HL,DE
        LD (0x78F9),HL
        JP 0x4C4E
name:   DB "SHELL   VZ "
'''
stub,sl=assemble(stub_src,0x5BBA)
assert sl['launch']==0x5BD0 and sl['boot']==0x5BC0, sl
dos=bytearray(stock); assert not any(dos[off(0x5BBA):off(0x5F00)])
dos[off(0x5BBA):off(0x5BBA)+len(stub)]=stub; dos[off(0x4044):off(0x4046)]=bytes([0xC0,0x5B])
os.makedirs(os.path.dirname(dst) or '.',exist_ok=True)
open(dst,'wb').write(dos)
print('wrote',dst)
