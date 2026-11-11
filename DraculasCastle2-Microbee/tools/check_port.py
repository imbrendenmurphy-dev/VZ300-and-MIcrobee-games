"""Integration checks against the shared Microbee hardware model."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'tools'))
from mbee import Mbee

def syms():
    result={line.split()[1]:int(line.split()[0],16) for line in (ROOT/'build/game.sym').read_text().splitlines()}
    assert result['code_end']<0xE1F0,'Test return address overlaps game code'
    return result

def direct(mode='C'):
    p=Mbee(); p.out(0x50,7)
    code=(ROOT/'build/GAME.BIN').read_bytes()
    p.blocks[0][:len(code)]=list(code)
    for f in (ROOT/'build').glob('DATA*.BNK'):
        b=int(f.stem[4:]); data=f.read_bytes();p.blocks[b][:len(data)]=list(data)
    data=(ROOT/'build/PCG.BNK').read_bytes();p.blocks[14][:len(data)]=list(data)
    p.cpu.pc=0x8000
    s=syms()
    assert p.run_until(s['mb_mode_menu.wait'],300)==s['mb_mode_menu.wait']
    p.keys={mode}
    assert p.run_until(s['title_screen.loop'],300)==s['title_screen.loop']
    p.keys=set()
    return p

def invoke(p,s,name,a=None,frames=1000):
    if not name.startswith('native_') and p.peek(s['native_active']) and not p.peek(s['native_battle_active']):
        invoke(p,s,'native_leave')
    p.keys=set();p.out(0x0B,0);p.cpu.sp=0xEDFC
    p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1)
    p.cpu.pc=s[name]
    if a is not None:p.cpu.a=a
    assert p.run_until(0xE1F0,frames)==0xE1F0,(name,hex(p.cpu.pc))

def integration():
    s=syms()
    p=Mbee(rom=(ROOT/'resources/bn60.rom').read_bytes(),disk=(ROOT/'build/DRACULA.DS8').read_bytes())
    p.cpu.pc=0x8000;p.run_frames(200)
    assert 'A>' in p.text(),p.text()
    for c in ['D','R','A','C','U','L','A','RET']:
        p.keys={c};p.run_frames(4);p.keys=set();p.run_frames(4)
    assert p.run_until(s['mb_mode_menu.wait'],2500)==s['mb_mode_menu.wait']
    p.png(str(ROOT/'build/display-choice.png'))
    p.keys={'C'}
    assert p.run_until(s['title_screen.loop'],2500)==s['title_screen.loop']
    p.keys=set()
    p.png(str(ROOT/'build/title.png'),aspect=15/16)
    print('PASS real boot ROM -> CP/M prompt -> typed DRACULA -> title',flush=True)
    for key in ['SPACE']*3:
        p.keys={key};p.run_frames(50);p.keys=set();p.run_frames(100)
    assert (p.peek(s['px']),p.peek(s['py']))==(8,14)
    print('PASS keyboard title menu and story -> new game',flush=True)
    p.png(str(ROOT/'build/explore.png'))
    p.poke(s['show_intro'],0)
    for area in range(6):
        p.poke(s['cur_area'],area);p.poke(s['px'],255)
        invoke(p,s,'enter_area')
        assert p.peek(s['cur_area'])==area
        assert p.peek(s['px'])<16 and p.peek(s['py'])<16
        p.png(str(ROOT/f'build/area{area}.png'))
    print('PASS all six area packs, map decompression, relocated objects and display',flush=True)
    for monster in range(1,13):
        invoke(p,s,'battle_load',monster)
        invoke(p,s,'draw_scene')
        invoke(p,s,'draw_battle_ui')
        invoke(p,s,'set_css',p.peek(s['bt_css']))
        invoke(p,s,'present_full')
        assert p.peek(s['bt_mon'])==monster and p.peek(s['bt_mhp'])>0
        p.png(str(ROOT/f'build/monster{monster:02}.png'))
    print('PASS all twelve monsters and six battle backdrops',flush=True)
    p.poke(s['hp'],27);invoke(p,s,'save_game');p.poke(s['hp'],1)
    invoke(p,s,'load_game');assert p.peek(s['hp'])==27 and not p.cpu.f&1
    p.poke(0x6404,p.peek(0x6404)^1);invoke(p,s,'load_game');assert p.cpu.f&1
    print('PASS RAM checkpoint save/restore and corrupt-save rejection',flush=True)
    invoke(p,s,'set_latch',0)
    egg=(ROOT/'baseline-release/DC2EGG.DAT').read_bytes()
    for i in range(4):
        p.blocks[1][0x2000:0x2200]=list(egg[i*512:(i+1)*512])
        invoke(p,s,'m0_present');p.png(str(ROOT/f'build/egg{i}.png'))
    print('PASS four 1984 tribute screens',flush=True)
    assert bytes(p.pcg)==(ROOT/'build/PCG.BNK').read_bytes(), 'Static PCG data was overwritten'
    # Validate every control through actual CRTC keyboard scanning.
    for key,mask in [('W',1),('UP',1),('S',2),('DOWN',2),('A',4),('LEFT',4),('D',8),('RIGHT',8),('SPACE',16),('RET',16),('M',32),('P',64),('E',128)]:
        p.keys=set();invoke(p,s,'read_input')
        p.keys={key};p.cpu.sp=0xEDFC;p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1);p.cpu.pc=s['read_input']
        assert p.run_until(0xE1F0,10)==0xE1F0
        assert p.peek(s['keys_new'])==mask,(key,p.peek(s['keys_new']))
    p.keys=set();p.set_joy(0x7E);invoke(p,s,'read_input')
    assert p.peek(s['keys_now'])==17
    p.set_joy(255)
    print('PASS movement, arrows, action, map, pause, inventory and joystick',flush=True)
    report={'stage':'native 40x32 world, illustrated map, parchment text and combat','boot':'real ROM and CP/M, typed DRACULA','areas':6,'monsters':12,'tribute_screens':4,'checkpoint':'RAM only, as original','native_artwork':'Native maze, panels, map, story, ending, title, gallery and combat; colour and mono','hardware_tested':False}
    (ROOT/'build/validation.json').write_text(json.dumps(report,indent=2))

def main():
    s=syms();p=direct()
    for n in ('title_screen','new_game','explore_loop','sd_load'):
        if n in s:p.watch(s[n])
    p.run_frames(250)
    print('PC',hex(p.cpu.pc),'SP',hex(p.cpu.sp),'bank',p.regs(),'events',[(t//67500,hex(a)) for t,a in p.events()])
    p.png(str(ROOT/'build/title.png'))
    p.keys={'SPACE'};p.run_frames(100);p.keys=set();p.run_frames(200)
    print('after start',hex(p.cpu.pc),hex(p.cpu.sp),'area',p.peek(s['cur_area']),'xy',p.peek(s['px']),p.peek(s['py']))
    print('events',[(t//67500,hex(a)) for t,a in p.events()])
    p.png(str(ROOT/'build/explore.png'))
    assert p.cpu.sp>0xEA00

if __name__=='__main__':integration()
