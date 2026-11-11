"""Generate the compatibility-stage Microbee engine from the archived VZ source.

Gameplay source remains upstream; hardware replacements live in mb_*.asm.
Run build.py, rather than this file directly.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent

def generate():
    dst = ROOT / 'src'
    for p in (ROOT / 'original/src').glob('*.asm'):
        s = p.read_text()
        if p.name == 'main.asm':
            s = s.replace('include "sys.asm"', 'include "sys.asm"\n            include "mb_hw.asm"')
            s = s.replace('assert code_end <= P2BASE', 'assert code_end <= VPBUF')
            s = s.replace('            include "gen/font.inc"\n', '')
        if p.name == 'vars.asm':
            s = s.replace('equ $F000', 'equ $2000').replace('equ $F800', 'equ $E300')
            s = s.replace('equ $C800', 'equ $0000').replace('equ $D900', 'equ $1100')
        if p.name == 'view.asm':
            s = s.replace('out ($37),a', '; assets stay in the Microbee work block')
            s = s.replace('render_view:\n','render_view:\n            call world_view\n            jp sample_view\nlegacy_render_view:\n')
            # Every Microbee area now uses world_maze. These private VZ wall
            # routines have no remaining callers; retain shared visibility and
            # masked blitters used by gameplay/compatibility screens.
            a=s.index('legacy_render_view:');b=s.index('lat_order:',a)
            s=s[:a]+s[b:]
            a=s.index('\ndraw_cell:')+1;b=s.index('\nblit_masked:',a)+1
            s=s[:a]+s[b:]
        if p.name == 'explore.asm':
            s=s.replace("ld a,'['", "ld a,' '").replace("ld a,'$'", "ld a,'G'")
            s = s.replace('            call present_panel_top\n','')
            s = s.replace('draw_explore_screen:\n','draw_explore_screen:\n            call world_reset\n')
            for old,new in (('@','H'),('%','M')):
                s=s.replace("ld a,'"+old+"'", "ld a,'"+new+"'\n            ld (de),a\n            inc de\n            ld a,'P'")
        if p.name == 'boot.asm':
            s = s[s.index('; load_area:'):]
            s = 'boot:       call mb_init\n            call mb_mode_menu\n            jp title_screen\n\n' + s
        if p.name == 'screens.asm':
            for old,new in (('@','H'),('%','M')):
                s=s.replace("ld a,'"+old+"'", "ld a,'"+new+"'\n            ld (de),a\n            inc de\n            ld a,'P'")
            s=s.replace("ld a,'$'", "ld a,'G'")
            s = s.replace('cutscene:\n','cutscene:\n            or a\n            ret z\n            jp world_cutscene\nlegacy_cutscene:\n')
            # Native cinematics replaced this private, end-of-file VZ renderer.
            s=s[:s.index('\nlegacy_cutscene:')+1]
            s = s.replace('call draw_player_arrow\n            call present_full','call draw_player_arrow\n            ld a,3\n            ld (world_screen),a\n            call present_full')
            a=s.index('pause_screen:');b=s.index('str_paused:',a)
            segment=s[a:b].replace('call read_input','call read_input\n            call mb_pause_display')
            s=s[:a]+segment+s[b:]
            s=s.replace(' N: MUSIC ON/OFF  Q: QUIT',' C:COLOUR M:MONO N:SOUND Q:QUIT')
        if p.name == 'title.asm':
            s=s.replace('title_screen:', 'legacy_title_screen:',1)
            a=s.index('legacy_title_screen:');b=s.index('\ntitle_note:',a)
            s=s[:a]+s[b:]  # mb_front.asm owns the active title/menu loop.
            s=s.replace('gallery_monster:\n','gallery_monster:\n            dec a\n            jp world_cinema\nlegacy_gallery_monster:\n')
        if p.name == 'text.asm':
            # Text lives in the native text layer. The VZ 3x5 glyph plot into the
            # unseen back buffer (and its font table) is dropped: less work per
            # character and room for the view buffer.
            a=s.index('draw_char:\n');b=s.index('; centred print',a)
            s=s[:a]+'draw_char:\n            call world_char\n            jp native_battle_char\n\n'+s[b:]
        if p.name == 'battle.asm':
            s=s.replace('ld (hl),18\n', 'ld (hl),18\n            call native_anim_tick\n')
            s=s.replace('ld a,(bt_frame)\n            ld (bt_dy),a', 'call native_anim_bob\n            ld (bt_dy),a')
            s=s.replace('call battle_wipe','call battle_wipe\n            call native_battle_enter')
            s=s.replace('battle_exit:\n            push af','battle_exit:\n            push af\n            call native_battle_leave')
            s=s.replace('clear_ui:\n','clear_ui:\n            call native_battle_clear\n')
            s=s.replace('draw_battle_ui_stats:\n','draw_battle_ui_stats:\n            call native_battle_clear_stats\n')
        if p.name == 'sd.asm':
            s = (ROOT / 'src/mb_files.asm').read_text()
        if p.name == 'music.asm':
            s = s.replace('ld a,$20', 'ld a,$40').replace('ld a,$21', 'ld a,$40')
        if p.name == 'sys.asm':
            s=s.replace('cls_back:   ; A = fill byte','cls_back:   call world_reset ; A = fill byte')
            s=s.replace('fill_rect:\n','fill_rect:\n            call world_erase\n')
            s = s.replace('VRAM        equ $7000', 'VRAM        equ $F000')
            s = s.replace('ld a,(FSREAD)\n            rla', 'in a,($0C)\n            and $20')
            s = s.replace('ld a,(FSREAD)           ; 13\n            rla', 'in a,($0C)\n            and $20')
            s = s.replace('ld a,$D2', 'ld a,$CA').replace('ld a,$DA', 'ld a,$C2')
            s = s.replace('jr nc,.low', 'jr z,.low').replace('cp $DA', 'cp $CA')
            s = s.replace('jr z,.done              ; was waiting for FS high->low: done\n            ld a,$C2', 'jr z,.done              ; entered vertical blank\n            ld a,$CA')
            s = s.replace('jp c,mloop', 'jp z,mloop')
            s = s.replace('and $20', 'and $40') if False else s
            s = s.replace('and $20                 ; 7   music', 'and $40                 ; 7   music')
            s = s.replace('and $20                 ; 7   $21', 'and $40                 ; 7   $21')
            s = s.replace('xor $09', 'xor $00')
            s = s.replace('ml_m3n:     and $20','ml_m3n:     and $40')
            s = s.replace('ld (LATCH),a', 'out ($02),a')
            s = s.replace('ld a,(latch_base)       ; leave speaker in neutral state', 'xor a                     ; speaker neutral')
            a = s.index('set_latch:\n'); b = s.index('; set CSS', a)
            s = s[:a] + 'set_latch:  ld (latch_base),a\n            jp native_battle_css\n\n' + s[b:]
            a = s.index('present_full:\n'); b = s.index('; quick present', a)
            s = s[:a] + 'present_full:\n            ld d,0\n            ld e,64\npresent_rect:\n            jp mb_present\n\n' + s[b:]
            a = s.index('read_joy:\n'); b = s.index('; wait for all keys', a)
            s = s[:a] + '''read_joy:   push bc
            in a,($00)
            cpl
            ld b,a
            and $0F
            cp $0F
            jr z,.none
            bit 7,b
            jr z,.done
            or $10
.done:      pop bc
            ret
.none:      xor a
            pop bc
            ret
detect_joy: ld a,1
            ld (joy_ok),a
            ret

''' + s[b:]
        for row in ('FE','FD','EF','BF','7F','F7'):
            s = s.replace('ld a,($68'+row+')', 'call mb_row_'+row)
        s = s.replace('ld a,($6800)', 'call mb_any')
        (dst / p.name).write_text(s)

if __name__ == '__main__':
    generate()
