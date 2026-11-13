"""One-off: lift the game logic routines out of the VZ300 source (they work
in VZ pixels and know nothing about the display) into src/logic.asm."""
import re, sys
from pathlib import Path
VZ = Path(__file__).resolve().parent.parent.parent / 'Bix' / 'src' / 'src'

def blocks(name):
    out, cur, order = {}, None, []
    for line in (VZ / name).read_text().split('\n'):
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)', line)
        if m:
            cur = m.group(1)
            if cur not in out:
                out[cur] = []
                order.append(cur)
        if cur:
            out[cur].append(line)
    return out, order

G, go = blocks('game.asm')
E, eo = blocks('ents.asm')
F, fo = blocks('fx.asm')
want_g = ['getpos', 'setposx', 'setposy', 'tile_at', 'div16_8', 'camxmax', 'pxmax16', 'onplat', 'ridedy',
          'player_update', 'wings', 'dblused', 'wasground', 'dec_nz', 'add_px', 'p_horiz', 'get_acc',
          'do_jump', 'abs_a', 'p_collide_x', 'col3', 'p_collide_y', 'slope_land', 'sl_x', 'sl_f', 'sl_p',
          'feet_probe', 'plat_probe', 'p_checks', 'body_tile', 'got_star', 'player_hurt', 'safex', 'safey',
          'player_die', 'win_update', 'burrow_update', 'bpoint_ok', 'p_anim']
want_e = ['platix', 'spawnpend', 'spawn_scan', 'svlo', 'svhi', 'spawnall', 'spawn_rec', 'free_slot',
          'reveal_bonus', 'ents_update', 'jp_hl', 'ent_nop', 'ent_release', 'ent_far', 'ent_tile', 'anim2',
          'ant_upd', 'mag_upd', 'drop_upd', 'toad_upd', 'plath_upd', 'ridedx_tmp', 'plat_ride', 'platv_upd',
          'glow_upd', 'oneup_upd', 'worm_upd', 'boom_upd', 'dx_player', 'ent_touch', 'mark_dead']
want_f = ['random', 'add_score_a']
L = ['; =====================================================================',
     ';  logic.asm - Bix, the enemies and the items: the VZ300 game\'s own',
     ';  routines, lifted from its source. They work in VZ pixels (a tile is',
     ';  8 x 8 of them) and sixteenths, 25 frames a second, and never touch',
     ';  the display.',
     '; =====================================================================']
for src, want in ((G, want_g), (E, want_e), (F, want_f)):
    for w in want:
        L += src[w]
s = '\n'.join(L) + '\n'
s = s.replace('high tattr', 'tattr >> 8')
s = s.replace('call maybe_ei\n', '')
def rep(a, b, n=1):
    global s
    assert s.count(a) == n, (a, s.count(a))
    s = s.replace(a, b)
rep('\nplath_upd:', '\nplath_move:')
rep('\nplatv_upd:', '\nplatv_move:')
rep('\nent_release:', '\nent_release0:')
# the screen is 20 tiles wide here, not 16
rep('        ld de,20\n        add hl,de\n        ld (tmp2),hl', '        ld de,24\n        add hl,de\n        ld (tmp2),hl')
rep('        ld de,16\n        add hl,de\n        ld (svhi),hl', '        ld de,20\n        add hl,de\n        ld (svhi),hl')
rep('        cp 224\n        ccf\n        ret', '        or a                    ; within 48 pixels of a 160 pixel screen\n        ret')
rep('.nm:    cp E_BOSS\n        jp z,boss_init\n        cp E_PLATH\n        jr nz,.n1\n        ld (ix+9),0\n.n1:    cp E_PLATV\n        ret nz\n        ld (ix+9),1\n        ret',
    '.nm:    cp E_PLATH\n        jr nz,.n1\n        ld (ix+9),0\n        jp plat_new\n.n1:    cp E_PLATV\n        ret nz\n        ld (ix+9),1\n        jp plat_new')
Path(sys.argv[1]).write_text(s)
print(len(s.split('\n')), 'lines')
