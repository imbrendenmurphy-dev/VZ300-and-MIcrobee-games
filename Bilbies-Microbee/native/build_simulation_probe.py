"""Build isolated original-rule Z80 simulation in the native home RAM bank.

This integration probe deliberately omits visual terrain edits and sound. It
is not a playable game and cannot validate build/dig graphics. The collision
mask itself remains authoritative and is modified by all original skills.
"""
from pathlib import Path
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
(OUT / 'game-probe.asm').write_text(game)
core = (ROOT / 'src/core.asm').read_text().split('; ---- controls')[0]
(OUT / 'rand.asm').write_text(core)
sound = (ROOT / 'src/microbee.asm').read_text()
(OUT / 'sound-equ.asm').write_text('\n'.join(line for line in sound.splitlines() if line.startswith('SFX_'))+'\n')
subprocess.run(['sjasmplus', '--nologo', '--sym=../build/native-simulation/simulation.sym',
                'simulation_probe.asm'], cwd=ROOT / 'native', check=True)
