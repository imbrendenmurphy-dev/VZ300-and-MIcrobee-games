"""Execute bank-switch and record conversion bridge against the PP model."""
from pathlib import Path
import re
import subprocess
import sys

R=Path(__file__).resolve().parents[1]
B=R/'build/native-simulation'
sys.path.insert(0,str(R/'tools'))
import ppmodel

asm='''        DEVICE NOSLOT64K
        INCLUDE "../build/native/config.inc"
        ORG $8000
n_bank: push bc
        ld b,a : and 3 : xor 2 : ld c,a
        ld a,b : and $1C : rlca : rlca : rlca : or c : or 4
        out ($50),a : pop bc : ret
n_home: ld a,$0F : out ($50),a : ret
n_count: db 0
n_paused: db 0
n_anim: db 0
n_mono: db 0
n_camera: dw 0
n_patch_count: db 0
n_patch_buffer EQU $E600
n_entities: ds 160
        ORG $9C00
        INCLUDE "slice_bridge.asm"
        ASSERT $ < $A000
        SAVEBIN "../build/native-simulation/bridge.bin",$8000,$-8000h
'''
(B/'bridge-test.asm').write_text(asm)
subprocess.run(['sjasmplus','--nologo','--sym=../build/native-simulation/bridge.sym',
                '../build/native-simulation/bridge-test.asm'],cwd=R/'native',check=True)
syms={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',(B/'bridge.sym').read_text())}
sim={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',(B/'simulation.sym').read_text())}
p=ppmodel.PP();p.set_p50(0x0F)
p.blocks[27][:]=(B/'SIM.BNK').read_bytes()
binary=(B/'bridge.bin').read_bytes();p.mem[0x8000:0x8000+len(binary)]=binary
original_home=bytes(p.mem[:0x8000])
def call(label):
    p.m.sp=0xEFF0;p.mem[0xEFF0:0xEFF2]=b'\xC0\xEF';p.m.pc=syms[label]
    assert p.run_until(0xEFC0,500),label
def vector(address):
    p.m.sp=0xEFF0;p.mem[0xEFF0:0xEFF2]=b'\xC0\xEF';p.m.pc=address
    assert p.run_until(0xEFC0,500),hex(address)

call('slice_init')
call('slice_patches')
assert not (p.m.f&1) and p.mem[syms['n_patch_count']]==0
assert p.lower==1 and bytes(p.mem[:0x8000])==original_home
bank=p.blocks[27]
assert bank[sim['v_ncrt']]==12 and bank[sim['v_rate']]==50
assert int.from_bytes(bank[sim['v_tleft']:sim['v_tleft']+2],'little')==300
assert p.mem[syms['slice_quota']]==9 and p.mem[syms['slice_goal_end']]==0
assert bank[0x4000:0x5400]==(R/'build/native/collision.bin').read_bytes()
assert p.mem[syms['n_count']]==0
for i,state,x,y in [(2,1,100,45),(5,16,150,40),(9,2,200,30)]:
    at=0x7B00+i*16
    bank[at:at+4]=bytes([state,x&255,x>>8,y])
p.m.a=27;call('n_bank');call('slice_convert');call('n_home')
assert p.mem[syms['n_count']]==2
assert bytes(p.mem[syms['slice_slots']:syms['slice_slots']+2])==bytes([2,9])
height=int(re.search(r'N_SPRITE_H EQU (\d+)',(R/'build/native/config.inc').read_text())[1])
assert bytes(p.mem[syms['n_entities']:syms['n_entities']+8])==bytes([194,0,64+90-height,1,138,1,64+60-height,2])
assert not any(p.mem[syms['n_entities']+8:syms['n_entities']+160])
p.m.a=27;call('n_bank')
p.m.ix=0x7B20;p.m.a=4;vector(6)  # original can_take for builder
assert p.m.f&0x40
p.m.a=4;vector(9)                  # original apply_skill
assert p.mem[0x7B20]==7 and p.mem[sim['v_skill']+4]==5
# A real collision edit must mark a visible terrain cell.
address=0x4000+60*64+100//8
p.mem[address] |= 0x80>>(100%8)
p.m.de=100;p.m.bc=60;vector(sim['clear_px'])
assert not (p.mem[address] & (0x80>>(100%8)))
call('n_home')
call('slice_patches')
assert not (p.m.f&1) and p.mem[syms['n_patch_count']]==1
assert int.from_bytes(p.mem[0xE600:0xE602],'little')==(7+4)*80+25
# More than 32 changed viewport cells is reported and pauses the slice.
bank=p.blocks[27];bank[0x6800:0x6805]=b'\xff\xff\xff\xff\x80';bank[sim['st_any']]=1;bank[sim['st_changed']]=1
call('slice_patches')
assert p.m.f&1 and p.mem[syms['n_patch_count']]==0 and p.mem[syms['n_paused']]==1
bank=p.blocks[27];bank[0x6800:0x68A0]=bytes(160);bank[sim['st_any']]=0
p.mem[syms['n_paused']]=0
bank[sim['v_secfr']]=48
call('slice_tick');call('slice_tick')
assert p.lower==1 and int.from_bytes(p.blocks[27][sim['v_gtick']:sim['v_gtick']+2],'little')==1
assert int.from_bytes(p.blocks[27][sim['v_tleft']:sim['v_tleft']+2],'little')==299
assert int.from_bytes(p.mem[syms['slice_seconds']:syms['slice_seconds']+2],'little')==299
p.mem[syms['n_paused']]=1
before=bytes(p.blocks[27]);call('slice_tick');call('slice_tick')
assert bytes(p.blocks[27])==before,'pause advanced original simulation or clock'
p.mem[syms['n_paused']]=0
bank=p.blocks[27]
bank[0x7B00:0x7B00+640]=bytes(640)
bank[sim['v_released']]=bank[sim['v_ncrt']]
bank[sim['v_saved']]=9
call('slice_tick');call('slice_tick')
assert p.mem[syms['slice_goal_end']]==1 and p.mem[syms['slice_saved']]==9
bank=p.blocks[27]
bank[0x4000] ^= 0x80  # Simulate a persistent collision edit before restart.
assert bytes(bank[0x4000:0x5400]) != bytes(bank[0x5400:0x6800]), 'test did not edit collision'
call('slice_init')
bank=p.blocks[27]
assert bytes(bank[0x4000:0x5400])==(R/'build/native/collision.bin').read_bytes()
assert bytes(bank[0x6800:0x68A0])==bytes(160),'restart retained terrain dirty flags'
assert p.mem[syms['n_count']]==0 and p.mem[syms['slice_goal_end']]==0
assert bank[sim['v_skill']+4]==6,'restart failed to restore skill supply'
assert bytes(p.mem[:0x8000])==original_home
print('PASS bank-27 init, skills, mapping, edits, restart, clock, completion and DOS-bank preservation')
