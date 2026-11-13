"""Generate the simulation bank sources from the untouched original VZ300
sources (orig/).  Only VZ drawing / hardware code is cut; game rules, hit
radii, enemies, waves, sound programs and music are kept as written.

Differences from the Codex port_logic.py it is based on:
  * hit radii are NOT shrunk (the Microbee art is now at true scale)
  * the music sequencer and drum programs are kept (title music)
"""
from pathlib import Path
import re

R = Path(__file__).resolve().parents[1]
O = R / 'orig'
S = R / 'src'


def region(s, start, end, replacement=''):
    a = s.index(start)
    b = s.index(end, a)
    return s[:a] + replacement + s[b:]


COLL_BR = """coll_bullets_rocks:
        xor a
        ld (coll_mx),a
        ld (coll_my),a
        call cbr_make
        ld ix,OBJ_PBUL
        ld b,N_PBUL
.b:     ld a,(ix+O_TYPE)
        or a
        jr z,.nb
        ld a,(cbr_n)
        or a
        ret z                   ; no rocks left to hit
        ld a,(ix+O_XH)
        ld (coll_x),a
        ld a,(ix+O_YH)
        ld (coll_y),a
        push bc
        call fs_poll
        ld hl,cbr_list
        ld a,(cbr_n)
        ld b,a
.r:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld iyl,e
        ld iyh,d
        ld a,(coll_x)
        sub (iy+O_XH)
        and 127
        cp 64
        jr c,.px
        neg
        and 127
.px:    cp (iy+O_RX)
        jr nc,.nr               ; quick reject on x
        ; hit_test with zero margins (coll_mx = coll_my = 0): the x test
        ; above is its x test, so only its y test is left
        ld a,(coll_y)
        sub (iy+O_YH)
        jr nc,.dy
        neg
.dy:    cp PF_ROWS/2
        jr c,.dy2
        ld c,a
        ld a,PF_ROWS
        sub c
.dy2:   cp (iy+O_RY)
        jr nc,.nr
        ld (ix+O_TYPE),0        ; bullet spent
        push ix
        call hit_rock
        pop ix
        call cbr_make
        jr .done
.nr:    djnz .r
.done:  pop bc
.nb:    ld de,OBJSZ
        add ix,de
        djnz .b
        ret
cbr_make:
        ld hl,cbr_list
        ld de,OBJ_ROCK
        ld bc,N_ROCK*256
.m:     ld a,(de)
        or a
        jr z,.mn
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc c
.mn:    ld a,e
        add a,OBJSZ
        ld e,a
        jr nc,.mc
        inc d
.mc:    djnz .m
        ld a,c
        ld (cbr_n),a
        ret
cbr_n:  db 0
cbr_list: ds N_ROCK*2

"""


MOVE_OBJ = """move_obj:
        push ix
        pop hl
        inc hl                  ; HL -> O_XL
        ld d,h
        ld e,l
        inc de
        inc de
        inc de
        inc de                  ; DE -> O_VXL
        ld a,(de)
        add a,(hl)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        adc a,(hl)
        and 127
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        add a,(hl)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        adc a,(hl)
        call wrap_y
        ld (hl),a
        ret

"""


def generate():
    front = (O / 'front.asm').read_text()
    ai = front[front.index('ai_input:'):front.index('; ---------------- high score entry')]
    music = front[front.index('mus_start:'):front.index('rowtab_vram:')]
    (S / 'sim-ai.inc').write_text(ai)
    (S / 'sim-music.inc').write_text(music)
    sound = (O / 'sound.asm').read_text()
    snd = sound[sound.index('snd_off:'):]
    # the attract-mode demo plays silently under the title music
    snd = snd.replace('sfx_play:\n        push hl', 'sfx_play:\n        push af\n        ld a,(demo_mode) : or a : jr z,.loud\n        pop af : ret\n.loud:  pop af\n        push hl', 1)
    assert '.loud' in snd
    (S / 'sim-sound.inc').write_text(snd)
    hw = (O / 'hw.inc').read_text()
    for key, value in {'VARS': '$6000', 'ROWTAB': '$6200', 'PARTS': '$6300', 'OBJS': '$6800',
                       'BUF': '$7200', 'VRAM': '$7400', 'PF_ROWS': '64', 'STACK_TOP': '$7FF0',
                       'N_PART': '24'}.items():   # thinner explosions: 24 particles (VZ: 40)
        hw, n = re.subn(r'(?m)^' + key + r'\s+equ[^\n]*', f'{key} equ {value}', hw)
        assert n == 1, key
    game = (O / 'game.asm').read_text()
    game = region(game, 'read_input:\n', 'set_input:\n',
                  'read_input:\n        ld a,(demo_mode) : or a : jp nz,ai_input\n        ld a,(INPUT_BITS) : ld c,a\n')
    game = region(game, 'detect_joy:\n', 'move_obj:\n', 'detect_joy: ret\n')
    game = region(game, 'update_parts:\n', 'rock_par:\n',
                  '        INCLUDE "sim-particles.inc"\ninit_stars: ret\nupdate_stars: ret\n'
                  'PC_FIRE equ 0\nPC_ROCK equ 1\nPC_SPARK equ 2\nPC_RED equ 3\nPC_GEM equ 4\nPC_EXH equ 5\n')
    game = region(game, 'draw_rocks:\n', 'hit_rock:\n')
    game = region(game, 'draw_bullets:\n', 'hit_test:\n')
    game = region(game, 'hud_update:\n', 'game_update:\n')
    game = region(game, 'game_draw:\n', 'bcd_to_str:\n')
    game = region(game, 'draw_ring:\n', 'new_game:\n')
    game = game[:game.index('play_game:\n')]
    game = game.replace('new_game:\n', 'new_game:\n        call snd_off\n', 1)
    game = region(game, '        ld hl,VRAM+32*5+20\n', '.nw:    ld a,(chain_tmr)\n')
    # the Microbee counts vertical blanks by polling: give the longest loop
    # (each bullet against every rock) a poll per bullet, as the VZ code does
    # elsewhere with fs_poll
    # bullets vs rocks: the same tests in the same order, but each bullet
    # walks a list of the live rocks (rebuilt after a hit, since a hit splits
    # the rock) instead of all 24 slots.  A poll per bullet, as before.
    game = region(game, 'coll_bullets_rocks:\n', '; ship vs rocks\n', COLL_BR)
    # the object mover: same arithmetic, walking the record with HL/DE
    # instead of eight IX loads and stores
    game = region(game, 'move_obj:\n', '; wrap A (row', MOVE_OBJ)
    # explosions spawn many particles in one go: poll per particle
    game = game.replace('        ld (burst_mask),a       ; shift count 0..2\n.l:     push bc\n',
                        '        ld (burst_mask),a       ; shift count 0..2\n.l:     push bc\n        call fs_poll\n', 1)
    assert 'shift count 0..2\n.l:     push bc\n        call fs_poll' in game
    # ---- gentler opening (the user's request): waves 1-2 have fewer, slower
    # rocks; wave 1 has no enemies.  From wave 3 on the original rules apply
    # (wave 3 = the original wave 1 rock count).
    old = '        ld a,(wave)\n        add a,3\n        cp 8\n        jr c,.n\n        ld a,7\n'
    assert old in game
    game = game.replace(old, '        ld a,(wave)\n        inc a\n        cp 8\n        jr c,.n\n        ld a,7\n', 1)
    old = '.ls:    ld (level_speed),a\n'
    assert old in game
    game = game.replace(old, old + '        ld a,(wave) : cp 3 : jr nc,.ls2\n        ld a,$FF : ld (level_speed),a     ; slower rocks\n.ls2:\n', 1)
    # shortest wrapped vertical distance on the 64-row field (original: 58)
    game = game.replace('cp 30\n        jr c,.dy2', 'cp PF_ROWS/2\n        jr c,.dy2')
    enemy = (O / 'enemies.asm').read_text()
    enemy = enemy.replace('cp -29', 'cp -(PF_ROWS/2)').replace('cp 30', 'cp PF_ROWS/2')
    old = 'enemy_spawner:\n        ld a,(ship_state)\n        or a\n        ret nz\n'
    assert old in enemy
    enemy = enemy.replace(old, old + '        ld a,(wave) : cp 2 : ret c         ; no enemies on wave 1\n', 1)
    enemy = region(enemy, 'draw_enemies:\n', 'enemy_pts:')
    enemy = region(enemy, 'draw_items:\n', 'jewel_pts:')
    data = (O / 'data.asm').read_text().replace('        INCLUDE "assets.inc"', '')
    data = data.replace('"tables.inc"', '"sim-tables.inc"').replace('"burst.inc"', '"sim-burst.inc"')
    data = data.replace('"music.inc"', '"sim-musicdata.inc"')
    equ = (O / 'assets.inc').read_text().split('    MACRO SPRITE_SOURCE')[0]
    (S / 'sim-hw.inc').write_text(hw)
    (S / 'sim-logic.inc').write_text(game)
    (S / 'sim-enemies.inc').write_text(enemy)
    (S / 'sim-data.inc').write_text(data)
    (S / 'sim-sprites.inc').write_text(equ)
    (S / 'sim-tables.inc').write_text((O / 'tables.inc').read_text())
    (S / 'sim-burst.inc').write_text((O / 'burst.inc').read_text())
    (S / 'sim-musicdata.inc').write_text((O / 'music.inc').read_text())
    (S / 'sim-vars.inc').write_text((O / 'vars.asm').read_text())


if __name__ == '__main__':
    generate()
