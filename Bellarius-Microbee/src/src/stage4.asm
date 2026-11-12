; =====================================================================
;  BELLARIUS stage 4 overlay: SPACE OPERA. Notes that play the riff when
;  you shoot them in order, plectrums, cymbals, more cowbell, and the
;  ONE-MAN BAND: it counts 1, 2, 3, 4 and attacks on the beat; it can
;  only be hurt while it takes a bow.   VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "../build/main.equ"
        ORG OVL
        jp wave_start
        jp boss_start
        jp boss_update
        jp shot_boss
        jp boss_area
        jp boss_touch
        jp draw_boss_objs
        jp on_kill
        dw warn1,warn2
        ds OVL+32-$

E_NOTE      equ 1
E_PICK      equ 2
E_CYMBAL    equ 3
E_COWBELL   equ 4
E_SPEAKER   equ 5
E_RNOTE     equ 6

etype_tab:
        dw 0 : db 0,1,0,1,8,8 : dw 0
        dw en_sine    : db SF_NOTE0,2,BCYAN,1,8,8 : dw $0010
        dw en_pick    : db SF_PICK0,2,YELLOW,1,8,5 : dw $0015
        dw en_cymbal  : db SF_CYMBAL0,2,YELLOW,3,14,5 : dw $0030
        dw en_balloon : db SF_COWBELL,1,GREY,1,10,8 : dw $0010
        dw en_turret  : db SF_SPEAKER0,2,GREY,5,12,8 : dw $0050
        dw en_line    : db SF_NOTE0,2,BRED,2,8,8 : dw $0020

wave_start:
        ld (wv_y),a
        ld a,c
        ld (wv_yv),a
        ld a,(wv_y)
        add a,a
        ld l,a
        ld h,0
        ld de,wave_jt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        xor a
        ld (cur_grp),a
        jp (hl)
wave_jt:
        dw wv_notes,wv_picks,wv_cymbals,wv_cowbell,wv_speaker,wv_rnote,wv_chord

; five notes in a wave: shoot them front to back and they play the riff
wv_notes:
        ld b,5
        call new_group
        ld b,5
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a                 ; 16 px apart
        ld l,a
        ld h,0
        ld de,312
        add hl,de
        ld a,(wv_yv)
        add a,32+16
        ld c,a
        ld a,E_NOTE
        call en_new
        jr c,.n
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FE
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        pop bc
        push bc
        ld a,b
        dec a
        ld (ix+E_P2),a          ; its note: 0 = the front one
        add a,a
        add a,a
        add a,a
        add a,a
        ld (ix+E_T),a
.n:     pop bc
        djnz .l
        ret

; a chord: three notes stacked, gliding
wv_chord:
        ld b,3
        call new_group
        ld b,3
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a                 ; 16 px apart up the stack
        ld c,a
        ld a,(wv_yv)
        add a,32
        add a,c
        ld c,a
        ld hl,328
        ld a,E_NOTE
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FE
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        pop bc
        push bc
        ld a,b
        inc a
        ld (ix+E_P2),a
.n:     pop bc
        djnz .l
        ret

; plectrums: fast, and they bend towards you
wv_picks:
        ld b,4
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; 32 px apart
        ld l,a
        ld h,0
        ld de,300
        add hl,de
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_PICK
        call en_new
        jr c,.n
        ld (ix+E_DXH),$FC
.n:     pop bc
        djnz .l
        ret

; cymbals: in, stop, CRASH (a ring of pellets), out
wv_cymbals:
        ld b,2
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; 64 px apart in height
        ld c,a
        ld a,(wv_yv)
        cp 60
        jr c,.y
        ld a,60
.y:     add a,32-16
        add a,c
        ld c,a
        ld hl,328
        ld a,E_CYMBAL
        call en_new
        jr c,.n
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,170
        ld (ix+E_P1),a
.n:     pop bc
        djnz .l
        ret

; more cowbell: there's a bell in it
wv_cowbell:
        ld hl,328
        ld a,(wv_yv)
        add a,32+40
        ld c,a
        ld a,E_COWBELL
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_BELL
        ld (ix+E_DXH),$FF
        ld (ix+E_DYL),$B0
        ld (ix+E_DYH),$FF
        ret

; a speaker on the floor: sound waves at you
wv_speaker:
        ld hl,332
        ld c,32+150
        ld a,E_SPEAKER
        call en_new
        ret c
        ld (ix+E_FIRE),30
        ret

; a red note: a capsule
wv_rnote:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_RNOTE
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_DXH),$FD
        ret

; ---------------------------------------------------------------------
en_pick:
        call en_move
        ld a,(py)
        add a,4
        cp (ix+E_Y)
        ret z
        jr c,.u
        inc (ix+E_Y)
        ret
.u:     dec (ix+E_Y)
        ret

en_cymbal:
        ld a,(ix+E_ST)
        or a
        jr nz,.h
        ld (ix+E_DXL),0
        ld (ix+E_DXH),$FD
        call en_move
        ld a,(ix+E_XH)
        or a
        ret nz
        ld a,(ix+E_XL)
        cp (ix+E_P1)
        ret nc
        ld (ix+E_ST),1
        ld (ix+E_T),0
        ret
.h:     cp 1
        jr nz,.leave
        ld a,(ix+E_T)
        cp 30
        ret nz
        ld (ix+E_ST),2
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,4
        add hl,de
        ld a,(ix+E_Y)
        ld c,a
        call ring6
        ld a,SFX_BOOM
        jp play_sfx
.leave: ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FD
        ld (ix+E_DYL),$00
        ld (ix+E_DYH),$01
        jp en_move

; ring6: six pellets out from HL, C
ring6:  ld b,6
        push hl
        ld hl,ring_dirs
.r:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ex (sp),hl
        push hl
        push bc
        call bullet_new
        pop bc
        pop hl
        ex (sp),hl
        djnz .r
        pop hl
        ret
ring_dirs:  db $E0,$00, $F0,$E4, $10,$E4, $20,$00, $10,$1C, $F0,$1C

; play note A (index into the notetab) on the effects channel
play_note:
        ld a,(sfxon)
        or a
        ret z
        add a,a
        ld l,a
        ld h,0
        ld de,notetab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sfxstep),de
        ld hl,0
        ld (sfxdelta),hl
        ld a,6
        ld (sfxleft),a
        xor a
        ld (sfxmode),a
        ld a,3
        ld (sfxprio),a
        ret

; on_kill: a note plays its pitch (the riff: A C D E A)
on_kill:
        ld a,(ix+E_TYPE)
        cp E_NOTE
        jr nz,.no
        ld a,(ix+E_P2)
        and 7
        ld e,a
        ld d,0
        ld hl,riff
        add hl,de
        ld a,(hl)
        call play_note
.no:    xor a
        ret
riff:   db 34,37,39,41,46,44,42,39

; =====================================================================
; THE ONE-MAN BAND
; =====================================================================
BS_ENTER    equ 0
BS_COUNT    equ 1
BS_SONG     equ 2
BS_BOW      equ 3
BS_DIE      equ 4
BC_WARN     equ 4
BEAT        equ 12

boss_start:
        ld a,1
        ld (boss_on),a
        ld a,GS_BOSS
        ld (gstate),a
        ld hl,336
        ld (boss_x),hl
        ld a,32+60
        ld (boss_y),a
        xor a
        ld (boss_var),a
        ld (boss_st),a
        ld (boss_jam),a
        ld (boss_n),a
        ld (boss_flash),a
        ld hl,0
        ld (boss_t),hl
        ld a,(difficulty)
        ld e,a
        ld d,0
        ld hl,boss_hps
        add hl,de
        ld a,(hl)
        ld l,a
        ld h,0
        ld (boss_hp),hl
        ld (boss_hpmax),hl
        ld a,1
        ld (hud_dirty),a
        call stop_music
        ld hl,mus_game4_0
        ld de,mus_game4_1
        call play_music
        ld a,SFX_ALARM
        jp play_sfx
boss_hps:   db 40,54,72

boss_update:
        ld a,(boss_on)
        or a
        ret z
        ld hl,(boss_t)
        inc hl
        ld (boss_t),hl
        ld a,(boss_flash)
        or a
        jr z,.f
        dec a
        ld (boss_flash),a
.f:     ld a,(boss_st)
        add a,a
        ld l,a
        ld h,0
        ld de,.jt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.jt:    dw cb_enter,cb_count,cb_song,cb_bow,cb_die

cb_next:
        ld (boss_st),a
        ld hl,0
        ld (boss_t),hl
        ret

cb_enter:
        ld hl,(boss_x)
        dec hl
        dec hl
        ld (boss_x),hl
        ld de,232
        or a
        sbc hl,de
        ret nz
        ld a,BS_COUNT
        jr cb_next

cb_bob: ld a,(py)
        sub 28
        jr nc,cb_to
        xor a
cb_to:  cp 32+4
        jr nc,.a
        ld a,32+4
.a:     cp 32+112
        jr c,.b
        ld a,32+112
.b:     ld hl,boss_y
        cp (hl)
        ret z
        jr c,.u
        inc (hl)                ; 2 px at a time (every fourth frame): each
        cp (hl)                 ; page keeps its boss glyphs every other frame
        ret z
        inc (hl)
        ret
.u:     dec (hl)
        cp (hl)
        ret z
        dec (hl)
        ret

; the count-in: "1, 2, 3, 4!" - a click on each beat
cb_count:
        xor a
        ld (boss_var),a
        ld a,1
        ld (warn_msg),a
        ld a,(boss_t)
        and 3
        call z,cb_bob
        ld a,(boss_t)
        ld c,BEAT
        call mod_c
        or a
        jr nz,.t
        ld a,46                 ; A5 click
        call play_note
.t:     ld a,(boss_t)
        cp BEAT*4
        ret c
        xor a
        ld (warn_msg),a
        ld a,1
        ld (hud_dirty),a
        ld a,BS_SONG
        jp cb_next
; A mod C
mod_c:  sub c
        jr nc,mod_c
        add a,c
        ret

; eight beats: drum, cymbals, harmonica, guitar - twice
cb_song:
        ld a,(boss_t)
        ld c,BEAT
        call mod_c
        ld b,a                  ; frame within the beat
        ld a,(boss_t)
        srl a
        srl a                   ; beat = t / 12: t/4 then /3
        ld c,3
        ld d,0
.dv:    sub c
        jr c,.dd
        inc d
        jr .dv
.dd:    ld a,d
        and 3                   ; which instrument
        ld c,a
        ld a,b
        or a
        jr nz,.hold             ; act on the first frame of each beat
        ld a,c
        or a
        jr z,.drum
        dec a
        jr z,.cym
        dec a
        jr z,.harm
        ; guitar: a power chord - three pellets spread from the guitar
        xor a
        ld (boss_var),a
        ld hl,(boss_x)
        ld de,8
        add hl,de
        ld a,(boss_y)
        add a,40
        ld c,a
        push hl
        push bc
        ld de,$F0E0
        call bullet_new
        pop bc
        pop hl
        push hl
        push bc
        ld de,$00E0
        call bullet_new
        pop bc
        pop hl
        ld de,$10E0
        call bullet_new
        ld a,34
        jp play_note
.drum:  ld a,1
        ld (boss_var),a
        ld hl,(boss_x)
        ld de,30
        add hl,de
        ld a,(boss_y)
        add a,34
        ld c,a
        call bullet_aimed
        ld a,SFX_BOOM
        jp play_sfx
.cym:   xor a
        ld (boss_var),a
        ld hl,(boss_x)
        ld de,26
        add hl,de
        ld a,(boss_y)
        add a,52
        ld c,a
        call ring6
        ld a,SFX_POP
        jp play_sfx
.harm:  ld a,2
        ld (boss_var),a
        ld a,SFX_BEAM
        call play_sfx
        jr .hb
.hold:  ld a,c
        cp 2
        jr nz,.end
.hb:    ; the harmonica blast: a band at the mouth for the beat
        ld a,(pdead)
        or a
        jr nz,.end
        ld a,(boss_y)
        add a,16
        ld b,a
        ld a,(py)
        add a,9
        cp b
        jr c,.end
        ld a,b
        add a,4
        ld c,a
        ld a,(py)
        add a,4
        cp c
        jr nc,.end
        call hit_player
.end:   ld a,(boss_t)
        cp BEAT*8
        ret c
        xor a
        ld (boss_var),a
        ld a,SFX_DONG
        call play_sfx
        ld a,BS_BOW
        jp cb_next

; taking a bow: the bass drum is open to fire
cb_bow: ld a,3
        ld (boss_var),a
        ld a,2
        ld (warn_msg),a
        ld a,(boss_t)
        cp 90
        ret c
        xor a
        ld (warn_msg),a
        ld a,1
        ld (hud_dirty),a
        ld a,BS_COUNT
        jp cb_next

cb_die: ld a,(boss_t)
        and 3
        jr nz,.t
        call random
        and 63
        ld e,a
        ld d,0
        ld hl,(boss_x)
        add hl,de
        push hl
        call random
        and 63
        ld c,a
        ld a,(boss_y)
        add a,c
        sub 8
        ld c,a
        pop hl
        call fx_boom
        ld a,SFX_BOOM
        call play_sfx
        ld a,(boss_t)
        and 8
        ld a,1
        jr z,.k
        xor a
.k:     ld (shake_off),a
.t:     ld a,(boss_t)
        cp 75
        ret c
        xor a
        ld (boss_on),a
        ld (shake_off),a
        ld a,GS_CLEAR
        ld (gstate),a
        ret

; boss_hurt: E = damage
boss_hurt:
        ld a,(boss_st)
        cp BS_DIE
        ret z
        cp BS_ENTER
        ret z
        ld hl,(boss_hp)
        ld d,0
        or a
        sbc hl,de
        jr z,.dead
        jr c,.dead
        ld (boss_hp),hl
        ld a,3
        ld (boss_flash),a
        ld a,1
        ld (hud_dirty),a
        ld a,SFX_BOSSHIT
        jp play_sfx
.dead:  ld hl,0
        ld (boss_hp),hl
        ld a,1
        ld (hud_dirty),a
        ld de,$2500
        call add_score
        xor a
        ld (warn_msg),a
        ld a,BS_DIE
        jp cb_next

; half x of HL (biased +16 by the caller) -> A (255 off the right)
hx:     ld a,h
        cp 2
        ld a,255
        ret nc
        srl h
        rr l
        ld a,l
        ret

; the box x+o0..x+o1 (half x), y+v0..y+v1 against the shot box: C if it touches
; (bx0, bx1, by0, by1 set by the caller)
sbox:   ld a,(bx0)
        ld c,a
        ld a,(sx1)
        cp c
        jr c,.miss              ; shot right edge < box left
        ld a,(bx1)
        ld c,a
        ld a,(sx0)
        cp c
        jr nc,.miss
        ld a,(by0)
        ld c,a
        ld a,(sy1)
        cp c
        jr c,.miss
        ld a,(by1)
        ld c,a
        ld a,(sy0)
        cp c
        jr nc,.miss
        scf
        ret
.miss:  or a
        ret
; set bx0/bx1 from boss_x + D .. + E pixels, by0/by1 from boss_y + B .. + C
setbox: push bc
        ld hl,(boss_x)
        ld a,d
        add a,16
        ld c,a
        ld b,0
        add hl,bc
        push de
        call hx
        pop de
        ld (bx0),a
        ld a,e
        sub d
        srl a
        ld hl,bx0
        add a,(hl)
        ld (bx1),a
        pop bc
        ld a,(boss_y)
        add a,b
        ld (by0),a
        ld a,(boss_y)
        add a,c
        ld (by1),a
        ret
bx0:    db 0
bx1:    db 0
by0:    db 0
by1:    db 0

; shot IX against the band: the drum while it bows; otherwise BOOM (no harm)
shot_boss:
        ld a,(boss_st)
        cp BS_ENTER
        ret z
        cp BS_DIE
        ret z
        ld de,26*256+54
        ld bc,22*256+50
        call setbox
        call sbox
        jr nc,.body
        ld a,(boss_st)
        cp BS_BOW
        jr z,.hot
        ld a,SFX_BOOM           ; you're only playing its drum
        call play_sfx
        jr .spend
.tk:    ld a,SFX_TINK
        call play_sfx
        jr .spend
.body:  ld de,4*256+70
        ld bc,0*256+64
        call setbox
        call sbox
        ret nc
        jr .tk
.hot:   ld a,(ix+0)
        cp ST_BEAM
        jr nz,.nb
        ld a,(ix+6)
        and 3
        ret nz
        jr .d
.nb:    cp ST_BOMB
        jr nz,.d
        jp bomb_burst
.d:     ld e,(ix+7)
        call boss_hurt
        ld a,(ix+0)
        cp ST_BEAM
        ret z
        cp ST_RING
        ret z
.spend: ld a,(ix+0)
        cp ST_BEAM
        ret z
        ld (ix+0),0
        ret

boss_area:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_BOW
        jr z,.f
        srl e
        ret z
.f:     jp boss_hurt

boss_touch:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_DIE
        ret z
        ld hl,(boss_x)
        ld de,28+16
        add hl,de
        call hx
        ld c,a
        ld a,(hx1)
        cp c
        ret c
        ld a,(boss_y)
        add a,4
        ld c,a
        ld a,(hy1)
        cp c
        ret c
        ld a,(boss_y)
        add a,62
        ld c,a
        ld a,(hy0)
        cp c
        ret nc
        jp hit_player

; the harmonica blast, drawn with the small objects
draw_boss_objs:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_var)
        cp 2
        ret nz
        ld a,(boss_y)
        add a,17-24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(ticks)
        and 2
        ld a,BCYAN
        jr z,.c
        ld a,WHITE
.c:     ld (spr_ink),a
        ld hl,(boss_x)
        ld de,32
        add hl,de
        ld a,l
        and $F8
        ld l,a
.l:     ld (spr_x),hl
        push hl
        ld a,K_TONER
        call obj_draw
        pop hl
        ld de,-8
        add hl,de
        bit 7,h
        jr z,.l
        ret

warn1:      db "1.. 2.. 3.. 4!  ",0
warn2:      db "* TAKES A BOW * ",0
ovl_end:
        ASSERT ovl_end <= OVL_END
        SAVEBIN "../build/OVL4.BIN",OVL,ovl_end-OVL
        DISPLAY "stage 4 overlay end: ",ovl_end
