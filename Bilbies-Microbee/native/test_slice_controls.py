"""Standalone execution test of slice keyboard selection, skill and marker.

Needs sjasmplus, z80 and a freshly built native simulation bank. The fake
single-key source stands in for the CRTC scanner, but original can_take and
apply_skill execute from their real bank vectors.
"""
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/control-test'; OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'tools'))
from ppmodel import PP


def main():
    # Input and banking are minimal test stubs; the code under test and the
    # original banked skill logic are the real assembly sources.
    src=f'''        DEVICE NOSLOT64K
        ORG $8000
n_bank: push bc : ld b,a : and 3 : xor 2 : ld c,a
        ld a,b : and $1C : rlca : rlca : rlca : or c : or 4
        out ($50),a : pop bc : ret
n_home: ld a,$0F : out ($50),a : ret
n_input: ret
n_hud: ret
slice_init: ld hl,test_init_calls : inc (hl) : ret
n_invalidate: ld hl,test_invalidate_calls : inc (hl) : ret
n_key: ld hl,test_key : cp (hl) : jr z,.pressed
        xor a : ret
.pressed: ld a,$40 : or a : ret
n_camera: dw 0
n_count: db 2
n_paused: db 0
n_anim: db 0
n_patch_count: db 0
slice_half_tick: db 0
slice_saved: db 0
slice_quota: db 5
slice_seconds: dw 120
slice_goal_end: db 0
test_init_calls: db 0
test_invalidate_calls: db 0
n_entities: ds 160
slice_slots: ds 40
test_key: db 0
        ORG $9C00
        INCLUDE "{(ROOT/'native/slice_controls.asm').as_posix()}"
control_end:
        SAVEBIN "{(OUT/'CONTROL.BIN').as_posix()}",$8000,control_end-$8000
'''
    (OUT/'harness.asm').write_text(src)
    subprocess.run(['sjasmplus','--nologo',f'--sym={OUT / "control.sym"}',str(OUT/'harness.asm')],check=True)
    sym={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',(OUT/'control.sym').read_text())}
    ss={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',(ROOT/'build/native-simulation/simulation.sym').read_text())}
    p=PP();p.set_p50(0x0F);p.blocks[27][:]=(ROOT/'build/native-simulation/SIM.BNK').read_bytes()
    code=(OUT/'CONTROL.BIN').read_bytes();p.mem[0x8000:0x8000+len(code)]=code
    def call(label):
        p.m.sp=0xEFF0;p.mem[0xEFF0:0xEFF2]=(0xEFC0).to_bytes(2,'little');p.m.pc=sym[label]
        assert p.run_until(0xEFC0,200),label
    def press(key):
        p.mem[sym['test_key']]=key;call('slice_input')
    # Directly seed two live walkers and a finite blocker inventory.
    p.blocks[27][0x7B00]=1;p.blocks[27][0x7B10]=1
    p.blocks[27][ss['v_skill']+3]=2
    p.mem[sym['slice_slots']:sym['slice_slots']+2]=bytes([0,1])
    p.mem[sym['n_entities']:sym['n_entities']+8]=bytes([32,0,64,0,48,0,64,0])
    p.mem[sym['slice_saved']]=4
    call('slice_hud_update')
    assert bytes(p.scr[1120+33:1120+38])==b'04\x0005'
    assert bytes(p.scr[1120+42:1120+45])==b'120'
    p.mem[sym['slice_goal_end']]=1
    call('slice_hud_update');assert bytes(p.scr[1120+48:1120+54])==b'FAILED'
    p.mem[sym['slice_saved']]=5
    call('slice_hud_update');assert bytes(p.scr[1120+48:1120+54])==b'SAVED!'
    p.mem[sym['slice_goal_end']]=0
    press(0x24);assert p.peek(sym['slice_skill'])==3
    press(0x37);assert p.blocks[27][0x7B00]==6 and p.blocks[27][ss['v_skill']+3]==1
    p.blocks[27][0x7B00]=1;press(0x37)
    assert p.blocks[27][0x7B00]==1 and p.blocks[27][ss['v_skill']+3]==1, 'held key repeated'
    press(0);press(0x3E);assert p.peek(sym['slice_selected'])==1
    press(0);press(0x37);assert p.blocks[27][0x7B10]==6 and p.blocks[27][ss['v_skill']+3]==0
    p.blocks[27][0x7B10]=1;press(0);press(0x37)
    assert p.blocks[27][0x7B10]==1, 'empty inventory assigned skill'
    p.blocks[27][ss['v_skill']+4]=1
    press(0);press(0x25);press(0x37)
    assert p.blocks[27][0x7B10]==7 and p.blocks[27][ss['v_skill']+4]==0
    # A falling creature cannot dig, and inventory must remain unchanged.
    p.blocks[27][ss['v_skill']+7]=1;p.blocks[27][0x7B10]=2
    press(0);press(0x28);press(0x37)
    assert p.blocks[27][0x7B10]==2 and p.blocks[27][ss['v_skill']+7]==1
    p.blocks[27][0x7B10]=1;press(0);press(0x37)
    assert p.blocks[27][0x7B10]==11 and p.blocks[27][ss['v_skill']+7]==0
    p.col[:1120]=bytes([0x12])*1120
    old=bytes(p.col[:1120]);call('slice_mark')
    assert sum(a!=b for a,b in zip(old,p.col[:1120]))==1
    call('slice_unmark');assert bytes(p.col[:1120])==old
    # The restart key resets fixed render state and calls both hooks once.
    for name in ['n_paused','n_anim','slice_half_tick','n_patch_count','slice_selected']:
        p.mem[sym[name]]=1
    p.mem[sym['n_camera']:sym['n_camera']+2]=bytes([7,0])
    press(0);press(18)
    assert all(p.peek(sym[name])==0 for name in ['n_paused','n_anim','slice_half_tick','n_patch_count','slice_selected'])
    assert bytes(p.mem[sym['n_camera']:sym['n_camera']+2])==bytes(2)
    assert p.peek(sym['slice_skill'])==4
    assert p.peek(sym['test_init_calls'])==p.peek(sym['test_invalidate_calls'])==1
    press(18)
    assert p.peek(sym['test_init_calls'])==1, 'held restart repeated'
    print('PASS keyboard selection, debouncing, original skill/inventory and reversible selection marker')

if __name__=='__main__':main()

