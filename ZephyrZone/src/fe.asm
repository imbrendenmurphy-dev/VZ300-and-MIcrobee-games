; =====================================================================
;  fe.asm - front end and rarely-run code, in upper bank 0 ($B800-$C7FF,
;  loaded from ZZCOM.DAT). Runs with mapping 3; calls main routines that
;  change the mapping through "call fecall : dw routine".
; =====================================================================
            org FE_CODE
fe_start:
hudrow:     db $AA,$A6,$9A,$96,$6A,$66,$5A,$56

; draw text HL (0-terminated) at VRAM byte column E (rows 0-4)
hud_text:
            ld d,HIGH(VRAM)
.c:         ld a,(hl)
            or a
            ret z
            inc hl
            push hl
            push de
            call glyph_ptr          ; HL -> 5 glyph rows
            pop de
            push de
            ld b,5
.r:         ld a,(hl)
            inc hl
            push hl
            ld hl,hudrow
            add a,l
            ld l,a
            jr nc,.nc
            inc h
.nc:        ld a,(hl)
            ld (de),a
            ld a,e
            add a,32
            ld e,a
            jr nc,.nd
            inc d
.nd:        pop hl
            djnz .r
            pop de
            inc e
            pop hl
            jr .c

; A = ASCII -> HL = glyph rows
glyph_ptr:
            sub 32
            jr nc,.ok
            xor a
.ok:        cp 64
            jr c,.ok2
            xor a
.ok2:       ld e,a
            ld d,0
            ld hl,fontmap
            add hl,de
            ld a,(hl)
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,hl
            add hl,de               ; *5
            ld de,font35
            add hl,de
            ret

; redraw the whole HUD
hud_draw:
            xor a
            ld (hud_dirty),a
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,32*5-1
            ld (hl),HUD_BG
            ldir
            ld hl,VRAM+32*5         ; separator: dotted line, or the boss's life
            ld b,32
.sep:       ld (hl),$BB
            inc hl
            djnz .sep
            ld a,(boss_on)
            or a
            jr z,.nob
            ; red bar, boss_hp / boss_max of the width
            ld a,(boss_hp)
            ld e,a
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a                 ; *32
            ld l,a
            ld h,0
            ld a,e
            cp 8
            jr c,.bs
            ld l,e                  ; (hp * 32 overflowed: work in 16 bits)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
.bs:        ld a,(boss_max)
            ld c,a
            call fe_div
            ld b,l
            ld a,b
            or a
            jr z,.nob
            ld hl,VRAM+32*5
.bb:        ld (hl),$FF
            inc hl
            djnz .bb
.nob:
            ; score
            ld hl,score
            ld de,hud_buf
            call bcd6
            ld hl,hud_buf
            ld e,0
            call hud_text
            ; weapon level: arrows
            ld a,(wlevel)
            ld hl,s_w1
            or a
            jr z,.w
            ld hl,s_w2
            dec a
            jr z,.w
            ld hl,s_w3
.w:         ld e,8
            call hud_text
            ; shield marker
            ld a,(shield)
            or a
            jr z,.nsh
            ld hl,s_sh
            ld e,12
            call hud_text
.nsh:       ; lives
            ld a,(lives)
            add a,'0'
            ld (hud_buf+1),a
            ld a,'*'
            ld (hud_buf),a
            xor a
            ld (hud_buf+2),a
            ld hl,hud_buf
            ld e,15
            call hud_text
            ; health: red segments from column 19
            ld a,(maxhealth)
            ld b,a
            ld a,(health)
            ld c,a
            ld hl,VRAM+19+32
            ld e,0
.hb:        ld a,e
            cp c
            ld a,$FD                ; filled: red red red blue
            jr c,.hf
            ld a,$EE                ; empty: red frame
.hf:        ld (hl),a
            push hl
            ld a,32
            add a,l
            ld l,a
            ld a,(hl)
            pop hl
            ld a,e
            cp c
            ld a,$FD
            jr c,.hf2
            ld a,$AE
.hf2:       push hl
            ld de,32
            add hl,de
            ld (hl),a
            add hl,de
            ld (hl),a
            pop hl
            inc hl
            ld a,l
            sub LOW(VRAM+19+32)
            ld e,a
            cp b
            jr c,.hb
            ret

s_w1:       db ">",0
s_w2:       db ">>",0
s_w3:       db ">>>",0
s_sh:       db "+",0

; BCD (3 bytes at HL, high first) -> 6 ASCII digits at DE, 0-terminated
bcd6:
            ld b,3
.l:         ld a,(hl)
            rrca
            rrca
            rrca
            rrca
            and 15
            add a,'0'
            ld (de),a
            inc de
            ld a,(hl)
            and 15
            add a,'0'
            ld (de),a
            inc de
            inc hl
            djnz .l
            xor a
            ld (de),a
            ret


msg_tab:    dw stg_buf,wname_buf,ms2,ms3,ms4,bname_buf,ms6,ms7,ms8,ms9,ms10,ms11,ms12,ms13,ms14,ms15,ms16,from_buf,ms18
ms0:        equ stg_buf
ms1:        equ wname_buf
ms2:        db "GET READY!",0
ms3:        db "POWER UP!",0
ms4:        db "WARNING!",0
ms5:        equ bname_buf
ms6:        db "STAGE CLEAR!",0
ms7:        db "GAME OVER",0
ms8:        db "PAUSED",0
ms9:        db "CONTINUE?",0
ms10:       db "ROUND 2 - FASTER!",0
ms11:       db "SHIELD!",0
ms12:       db "PRESS FIRE",0
ms13:       db "MODE: CASUAL",0
ms14:       db "MODE: ARCADE",0
ms15:       db "MODE: EXPERT",0
ms18:       db "PUSH UP: MODE",0
ms16:       db "TO GET READY",0
ms17:       equ from_buf

; 2x-wide glyph row (3 bits -> 6 px + 2 px gap = 2 bytes), colour 1 on 0
; ---------------------------------------------------------------------
; big messages in the 70s display face (tools/font70.py): rendered as a
; 1-bit mask, outlined in colour 2, coloured (yellow, red lower rows) and
; cut into two trimmed key-0 sprite records (left / right of centre)
; ---------------------------------------------------------------------
MSGBASE     equ $C400
MB          equ MSGBASE             ; mask 16 x 10 (1 bit per pixel)
MF          equ MSGBASE+160         ; colour 32 x 10
MSG_ENT     equ MSGBASE+480         ; level entries: L rec,rec ; R rec,rec
MRECL       equ MSGBASE+488         ; 5 + 160
MRECR       equ MSGBASE+653         ; 5 + 160
HB          equ MSGBASE+818         ; dilated rows 16 x 10
MSGEND      equ MSGBASE+978

; nibble (4 pixels, bit 3 = left) -> 2-bit pixels in colour 1 / 3 / 2
txt1:       db $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
txt3:       db $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF
txt2:       db $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA

show_msg:
            ld (msg_id),a
            ld a,125
            ld (msg_t),a
            ld a,(msg_id)
            add a,a
            ld e,a
            ld d,0
            ld hl,msg_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            push hl
            ld b,0
.len:       ld a,(hl)
            or a
            jr z,.lend
            inc hl
            inc b
            ld a,b
            cp 14
            jr c,.len
.lend:      ld a,b
            ld (mt_n),a
            ; clear the mask
            ld hl,MB
            ld de,MB+1
            ld bc,159
            ld (hl),0
            ldir
            ; first char byte s = (16 - n) / 2
            ld a,(mt_n)
            neg
            add a,16
            srl a
            ld (mt_cw),a
            ld e,a
            ld d,0
            ld hl,MB+16
            add hl,de
            ex de,hl                ; DE -> row 1, byte s
            pop hl
            ld a,(mt_n)
            or a
            jp z,.empty
            ld b,a
.ch:        push bc
            ld a,(hl)
            inc hl
            push hl
            push de
            sub 32
            jr nc,.c1
            xor a
.c1:        cp 64
            jr c,.c2
            xor a
.c2:        ld e,a
            ld d,0
            ld hl,font70map
            add hl,de
            ld l,(hl)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,font70
            add hl,de
            pop de
            push de
            ld b,8
.gr:        ld a,(hl)
            add a,a                 ; 7 pixels + gap in bits 7..1
            ld (de),a
            inc hl
            ld a,e
            add a,16
            ld e,a
            jr nc,.g1
            inc d
.g1:        djnz .gr
            pop de
            inc de
            pop hl
            pop bc
            djnz .ch
            ; ---- horizontal dilation H = M | M<<1 | M>>1 across bytes (the
            ; first and last byte of every row are always empty, so the rows
            ; can be treated as one stream)
            ld hl,MB
            ld de,HB
            ld b,160
            ld c,0                  ; previous byte
.hb:        ld a,(hl)
            ld (mt_b1),a
            srl a
            bit 0,c
            jr z,.h1
            or $80
.h1:        ld c,a
            ld a,(mt_b1)
            add a,a
            or c
            ld c,a
            inc hl
            ld a,(hl)               ; next byte's left pixel
            rlca
            and 1
            or c
            ld c,a
            ld a,(mt_b1)
            or c
            ld (de),a
            inc de
            ld c,a
            ld a,(mt_b1)
            ld c,a
            djnz .hb
            ; ---- outline O = (H above | H | H below) & ~M, then colour
            ld de,0                 ; i
.ob:        ld hl,HB
            add hl,de
            ld a,(hl)
            ld c,a
            ld a,e
            cp 16
            jr c,.nu
            push hl
            ld bc,-16
            add hl,bc
            ld a,(hl)
            pop hl
            ld b,a
            ld a,(hl)
            or b
            ld c,a
.nu:        ld a,e
            cp 144
            jr nc,.nd
            push hl
            ld a,c
            ld bc,16
            add hl,bc
            or (hl)
            ld c,a
            pop hl
.nd:        ld hl,MB
            add hl,de
            ld a,(hl)
            ld b,a                  ; M
            cpl
            and c
            ld c,a                  ; O
            ; text colour: glyph rows 0-4 yellow, 5-7 red
            push de
            ld hl,txt1
            ld a,e
            cp 6*16
            jr c,.ty
            ld hl,txt3
.ty:        ld (mt_tab),hl
            ; destination MF + 2i
            ld hl,MF
            add hl,de
            add hl,de
            ld a,b
            rrca
            rrca
            rrca
            rrca
            ld d,a
            ld a,c
            rrca
            rrca
            rrca
            rrca
            call .px                ; high nibbles
            inc hl
            ld d,b
            ld a,c
            call .px                ; low nibbles
            pop de
            inc de
            ld a,e
            cp 160
            jr nz,.ob
            ; ---- cut the left and right records
            ld a,(mt_cw)
            add a,a
            dec a                   ; first used output byte (outline)
            ld (mt_b0),a
            ld a,(mt_cw)
            ld b,a
            ld a,(mt_n)
            add a,b
            add a,a                 ; last used output byte
            ld (mt_b1),a
            ; left: bytes cL..15, anchor 64 - 4*cL
            ld a,(mt_b0)
            ld c,a                  ; start
            ld a,16
            sub c
            ld b,a                  ; width
            ld a,c
            add a,a
            add a,a
            neg
            add a,64                ; ax
            ld de,MRECL
            call .cut
            ld (MSG_ENT),hl
            ld (MSG_ENT+2),hl
            ; right: bytes 16..cR, anchor 0
            ld a,(mt_b1)
            sub 15
            ld b,a                  ; width
            ld c,16
            xor a
            ld de,MRECR
            call .cut
            ld (MSG_ENT+4),hl
            ld (MSG_ENT+6),hl
            ret
.empty:     ld hl,0
            ld (MSG_ENT),hl
            ld (MSG_ENT+4),hl
            ret
; (HL) = text[D & 15] | outline[A & 15]
.px:        push hl
            push bc
            and 15
            ld c,a
            ld b,0
            ld hl,txt2
            add hl,bc
            ld c,(hl)
            ld a,d
            and 15
            ld hl,(mt_tab)
            add a,l
            ld l,a
            jr nc,.p1
            inc h
.p1:        ld a,(hl)
            or c
            pop bc
            pop hl
            ld (hl),a
            ret
; record at DE: B bytes wide from MF column C, anchor A -> HL = record
.cut:       push de
            push af
            ld a,b
            ld (de),a               ; wb
            inc de
            ld a,10
            ld (de),a               ; h
            inc de
            pop af
            ld (de),a               ; ax
            inc de
            xor a
            ld (de),a               ; ay
            inc de
            ld (de),a               ; key 0
            inc de
            ld a,b
            or a
            jr z,.cz
            ld hl,MF
            ld a,c
            add a,l
            ld l,a
            jr nc,.cu
            inc h
.cu:        ld a,10
.cr:        push af
            push bc
            push hl
            ld c,b
            ld b,0
            ldir
            pop hl
            ld bc,32
            add hl,bc
            pop bc
            pop af
            dec a
            jr nz,.cr
            pop hl
            ret
.cz:        pop hl
            ld hl,0                 ; nothing on this side
            ret

; ---------------------------------------------------------------------
; a whole game: stages until the lives (and continues) run out
; ---------------------------------------------------------------------
new_game:
            ld a,(demo)             ; (the demo always plays stage 1)
            or a
            ld a,1
            jr nz,.w1
            ld a,(startw)
.w1:        ld (world),a
            ld hl,world_ld
            cp (hl)
            call nz,fecall_lw
            xor a
            ld (score),a
            ld (score+1),a
            ld (score+2),a
            ld (round),a
            ld (wlevel),a
            ld (shield),a
            ld a,3
            ld (lives),a
            ld a,(diff)
            ld e,a
            ld d,0
            ld hl,diff_hp
            add hl,de
            ld a,(hl)
            ld (maxhealth),a
            ld (health),a
stage_loop:
            call stage_init
.f:         call fecall
            dw game_frame
            ; pause
            ld a,(in_new)
            and K_PAUSE
            call nz,pause
            ld a,(in_new)
            and K_MUSIC
            call nz,toggle_music
            ld a,(demo)
            or a
            jr z,.nd
            ld a,(in_new)           ; any key ends the demo
            and $9F
            ret nz
            ld hl,(clock)
            ld de,1500
            or a
            sbc hl,de
            ret nc
.nd:        ; struck down?
            ld a,(dead)
            or a
            jr z,.alive
            call dying
            ret c                   ; game over
            jp .f
.alive:     ld a,(stage_done)
            or a
            jr z,.f
            call stage_clear
            jr stage_loop

diff_hp:    db 6,4,3

stage_init:
            call game_init
            xor a
            ld (stage_done),a
            ld (boss_on),a
            ld (dead),a
            ld (nbolts),a
            ld (fire_cd),a
            ld (msg_t),a
            ld hl,0
            ld (clock),hl
            ld a,50
            ld (scen_gap),a
            ld a,3
            ld (scen_mix),a
            ld a,(round)
            add a,a
            add a,13
            cp 21
            jr c,.s
            ld a,21
.s:         ld (speed),a
            ld a,100
            ld (inv),a
            ld a,1
            ld (hud_dirty),a
            call fecall
            dw world_begin
            ld a,SFX_START
            jp sfx

; struck down: the world stops, Zephyr is thrown back ("AAARGH!"),
; topples to the ground and lies there; then a fresh life or game over.
; C = game over
dying:
            ld a,1
            ld (frozen),a
            ld hl,0
            call music
            ld a,P_HURT
            ld (force_pose),a
            call fecall
            dw game_frame
            call fecall
            dw game_frame
            call fecall
            dw say_argh             ; the scream (everything waits for it)
            ; topple: height falls under gravity
            ld a,P_FALL1
            ld (force_pose),a
            xor a
            ld (fall_v),a
.fl:        ld a,(fall_v)
            add a,6
            ld (fall_v),a
            ld e,a
            ld d,0
            ld hl,(py8)
            or a
            sbc hl,de
            jr nc,.f1
            ld hl,0
.f1:        ld (py8),hl
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a,l
            ld (py),a
            cp 24
            jr nc,.f2
            ld a,P_FALL2
            ld (force_pose),a
.f2:        call fecall
            dw game_frame
            ld hl,(py8)
            ld a,h
            or l
            jr nz,.fl
            ; flat on the ground with a thump and a puff of dust
            ld a,P_DOWN
            ld (force_pose),a
            ld a,SFX_THUD
            call sfx
            call obj_alloc
            jr c,.nd
            ld (ix+O_KIND),K_BOOM
            ld (ix+O_SPR),T_BOOM
            ld (ix+O_FLAGS),0
            ld hl,(px)
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ld (ix+O_Y),0
            ld hl,ZP+4
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
.nd:        ld b,45
.ly:        push bc
            call fecall
            dw game_frame
            pop bc
            djnz .ly
            xor a
            ld (dead),a
            ld (force_pose),a
            ld (frozen),a
            ld a,(lives)
            or a
            jr z,.over
            dec a
            ld (lives),a
            ld a,(maxhealth)
            ld (health),a
            ld a,120
            ld (inv),a
            ld a,1
            ld (hud_dirty),a
            ; up on his feet, running again: "GET READY!"
            ld hl,0
            ld (py8),hl
            ld (pvy),hl
            ld a,M_READY
            call show_msg
            call fecall
            dw game_frame
            call fecall
            dw say_ready
            call fecall
            dw cur_tune
            or a
            ret
.over:      ; continue?
            ld a,M_CONT
            call show_msg
            ld hl,tune_over
            call music
            ld b,0
.cw:        push bc
            call fecall
            dw game_frame
            pop bc
            ld a,(in_new)
            and K_FIRE
            jr nz,.cont
            ld a,(demo)
            or a
            jr nz,.go
            ld a,(msg_t)
            cp 2
            jr nc,.cw
.go:        ld a,M_OVER
            call show_msg
            ld b,60
.gw:        push bc
            call fecall
            dw game_frame
            pop bc
            djnz .gw
            scf
            ret
.cont:      ; continue where we were (score starts again)
            xor a
            ld (score),a
            ld (score+1),a
            ld (score+2),a
            ld (msg_t),a
            ld a,3
            ld (lives),a
            ld a,(maxhealth)
            ld (health),a
            ld a,120
            ld (inv),a
            xor a
            ld (dead),a
            ld a,1
            ld (hud_dirty),a
            call fecall
            dw cur_tune
            or a
            ret

stage_clear:
            ld a,M_CLEAR
            call show_msg
            ld a,SFX_CLEAR
            call sfx
            ld hl,0
            call music
            ld b,110
.w:         push bc
            ld a,P_CHEER
            call fecall
            dw game_frame_pose
            pop bc
            djnz .w
            ; on to the next world (after the last, round 2 begins - faster)
            ld a,(world)
            inc a
            cp NWORLDS+1
            jr c,.nw
            call fecall             ; all five cleared: the finale
            dw run_ending
            ld a,(round)
            inc a
            ld (round),a
            ld a,1
.nw:        ld (world),a
            ld hl,maxw
            cp (hl)
            jr c,.nm
            ld (hl),a
.nm:
            call fecall
            dw load_world
            ld a,(world)
            dec a
            ret nz
            ld a,M_LOOP
            jp show_msg


; HL = HL / C
fe_div:     xor a
            ld b,16
.l:         add hl,hl
            rla
            cp c
            jr c,.n
            sub c
            inc l
.n:         djnz .l
            ret

fecall_ax:  call fecall
            dw attract_extra
            ret
fecall_lw:  call fecall
            dw load_world
            ret

pause:
            ld a,M_PAUSE
            call show_msg
            ld a,(dt)
            push af
.p:         call fecall
            dw pause_frame
            ld a,(in_new)
            and K_PAUSE|K_FIRE
            jr z,.p
            xor a
            ld (msg_t),a
            pop af
            ld (dt),a
            ret

toggle_music:
            ld a,(mus_off)
            xor 1
            ld (mus_off),a
            call fecall
            dw cur_tune
            ret


; ---------------------------------------------------------------------
; title: the world rolls on behind the logo; 1/2/3 choose difficulty,
; FIRE starts, A toggles autofire; after a while a demo plays
; ---------------------------------------------------------------------
title_screen:
            ld a,(world_ld)         ; the title flies over world 1
            cp 1
            ld a,1
            call nz,fecall_lw
            ld a,1
            ld (demo),a             ; the hero flies himself behind the title
            call game_init
            ld a,4                  ; the title runs a field slower: more speaker
            ld (minfields),a        ; time for its theme
            xor a
            ld (dead),a
            ld (boss_on),a
            ld (stage_done),a
            ld (msg_t),a
            ld (title_t),a
            ld (title_t+1),a
            ld hl,title_events
            ld (ev_ptr),hl
            ld hl,0
            ld (clock),hl
            ld a,50
            ld (scen_gap),a
            ld a,3
            ld (scen_mix),a
            ld a,1
            ld (hud_dirty),a
            ld hl,tune_title
            call music
.f:         call fecall
            dw title_frame
            ld a,(in_new)
            and K_FIRE
            jp nz,.start
            ld a,(in_new)
            and K_MUSIC
            call nz,toggle_mus_title
            ; up (joystick or Q) steps the mode round
            ld a,(in_new)
            and K_UP
            jr z,.nu
            ld a,(diff)
            inc a
            cp 3
            jr c,.sd
            xor a
            jr .sd
.nu:        ; difficulty keys 1/2/3 and A (autofire)
            ld a,($68F7)            ; 5 2 - 3 1 4 : 1 = bit4, 2 = bit1, 3 = bit3
            ld c,a
            bit 4,c
            jr nz,.k2
            xor a
            jr .sd
.k2:        bit 1,c
            jr nz,.k3
            ld a,1
            jr .sd
.k3:        bit 3,c
            jr nz,.ka
            ld a,2
.sd:        ld hl,diff
            cp (hl)
            jr z,.ka
            ld (hl),a
            add a,M_CASUAL
            ld (tsel_m),a
            ld a,120
            ld (tsel_t),a
            ld a,$FF                ; (redraw the line)
            ld (msg_id),a
            ld a,SFX_MENU
            call sfx
.ka:        ld a,(in_new)
            and K_LEFT|K_RIGHT
            jr z,.ka0
            and K_RIGHT
            ld a,(startw)
            jr z,.kl
            inc a
            ld hl,maxw
            cp (hl)
            jr z,.ks
            jr c,.ks
            ld a,1
            jr .ks
.kl:        dec a
            jr nz,.ks
            ld a,(maxw)
.ks:        ld (startw),a
            add a,'0'
            ld (from_buf+11),a
            ld a,M_FROM
            ld (tsel_m),a
            ld a,120
            ld (tsel_t),a
            ld a,$FF                ; (redraw the line)
            ld (msg_id),a
            ld a,SFX_MENU
            call sfx
.ka0:       ld a,($68FD)
            bit 4,a
            ld hl,akey
            jr nz,.kar
            ld a,(hl)
            or a
            jr nz,.kt
            ld (hl),1
            ld a,(autofire)
            xor 1
            ld (autofire),a
            ld a,SFX_MENU
            call sfx
            jr .kt
.kar:       ld (hl),0
.kt:        ; demo after ~25 s
            ld hl,(title_t)
            inc hl
            ld (title_t),hl
            ld de,400
            or a
            sbc hl,de
            jp c,.f
            ; attract: a real game with the autopilot
            ld a,1
            ld (demo),a
            ld hl,0
            call music
            call new_game
            ld a,(in_new)           ; (a key ended the demo: straight back)
            and $9F
            call z,fecall_ax
            jp title_screen
.start:     xor a
            ld (demo),a
            call new_game
            ; high score
            ld hl,score
            ld de,hiscore
            ld b,3
.hc:        ld a,(de)
            cp (hl)
            jr c,.new
            jr nz,.old
            inc hl
            inc de
            djnz .hc
            jr .old
.new:       ld hl,score
            ld de,hiscore
            ld bc,3
            ldir
.old:       jp title_screen

toggle_mus_title:
            ld a,(mus_off)
            xor 1
            ld (mus_off),a
            ld hl,0
            jp nz,music
            ld hl,tune_title
            jp music


; title HUD: high score and the chosen difficulty
title_hud:
            call hud_draw
            ld hl,s_hi
            ld e,0
            call hud_text
            ld hl,hiscore
            ld de,hud_buf
            call bcd6
            ld hl,hud_buf
            ld e,3
            call hud_text
            ret


s_hi:       db "HI",0

            include "gen/font.inc"
            include "gen/font70.inc"
fe_end:
            assert fe_end <= MSGBASE
            assert MSGEND <= $C800
