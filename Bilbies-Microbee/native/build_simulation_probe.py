"""Build original-rule Z80 simulation and terrain jobs for RAM bank 27.

The simulation records changed collision cells for the native renderer; it
does not draw directly to video. Sound is not yet implemented. The collision
mask remains authoritative and is modified by the original skills.
"""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build' / 'native-simulation'
OUT.mkdir(parents=True, exist_ok=True)
equ = (ROOT / 'src/equ.asm').read_text()
equ = equ.replace('MASK        equ $DE00', 'MASK        equ $4000')
(OUT / 'equ.asm').write_text(equ)
game = (ROOT / 'src/game.asm').read_text()
start = game.index('        call disp_addr', game.index('clear_px:'))
end = game.index('        ld hl,v_dug', start)
game = game[:start] + game[end:]
start = game.index('        call disp_addr', game.index('brick_px:'))
end = game.index('        pop bc', start)
game = game[:start] + game[end:]
start=game.index('clear_px:');end=game.index('brick_px:')
part=game[start:end]
part=part.replace('        ld (hl),a               ; clear the bit',
                  '        ld (hl),a               ; clear the bit\n        call st_mark')
game=game[:start]+part+game[end:]
start=game.index('brick_px:');end=game.index('game_tick:',start)
part=game[start:end]
part=part.replace('        ld (hl),a\n', '        ld (hl),a\n        call st_mark\n',1)
game=game[:start]+part+game[end:]
(OUT / 'game-probe.asm').write_text(game)
core = (ROOT / 'src/core.asm').read_text().split('; ---- controls')[0]
(OUT / 'rand.asm').write_text(core)
sound = (ROOT / 'src/microbee.asm').read_text()
(OUT / 'sound-equ.asm').write_text('\n'.join(line for line in sound.splitlines() if line.startswith('SFX_'))+'\n')
play = (ROOT / 'src/play.asm').read_text()
(OUT / 'skill-probe.asm').write_text(play[play.index('can_take:'):play.index('; ---- controls',play.index('can_take:'))])
(OUT / 'clock-probe.asm').write_text(play[play.index('clock:'):play.index('; ---- what\'s under the cursor',play.index('clock:'))])
subprocess.run(['sjasmplus', '--nologo', '--sym=../build/native-simulation/simulation.sym',
                'simulation_probe.asm'], cwd=ROOT / 'native', check=True)

# The bank's four fixed JP vectors make its ABI independent of assembly size.
symbols={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',
           (OUT/'simulation.sym').read_text())}
exports=('v_saved','v_tosave','v_released','v_ncrt','v_skill','v_end','v_tleft')
(OUT/'simvars.inc').write_text(''.join(f'{name} EQU ${symbols[name]:04X}\n' for name in exports))
bank=bytearray(32768)
for i,label in enumerate(('sim_init','game_tick','can_take','apply_skill','st_jobs','clock','sim_status')):
    addr=symbols[label]
    bank[3*i:3*i+3]=bytes([0xC3,addr&255,addr>>8])
code=(OUT/'SIM.BIN').read_bytes()
bank[0x600:0x600+len(code)]=code
native=ROOT/'build/native'
params=(native/'parameters.bin').read_bytes()
mask=(native/'collision.bin').read_bytes()
assert len(params)<=512 and len(mask)==5120
bank[0x2E00:0x2E00+len(params)]=params
bank[0x4000:0x5400]=mask
bank[0x5400:0x6800]=mask  # immutable original for an in-memory level restart
(OUT/'SIM.BNK').write_bytes(bank)
