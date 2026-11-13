; =====================================================================
;  FRONT END (stub in the main program). The front end itself - monitor
;  choice, title, hall of fame, how to play, pilot select, name entry,
;  the ending and saving - is an overlay (src/front.asm) loaded at OVL
;  from BLK_FRONT whenever it's needed. The attract demo's pilot lives
;  here, because the demo plays the real game (with stage 1's overlay).
; =====================================================================
demo:       db 0
demo_t:     dw 0

load_front:
        ld a,BLK_FRONT
        call map_blk
        ld hl,0
        ld de,OVL
        ld bc,OVL_END-OVL
        ldir
        ret

front_boot:
        call load_front
        jp OVL+0
front_main:
        ld sp,STACK
        call load_front
        jp OVL+3
ending:
        ld sp,STACK
        call load_front
        jp OVL+6
game_end:
        ld sp,STACK
        call load_front
        jp OVL+9

; the font and ready-made glyphs from the common store (block BLK_SPR)
front_glyphs:
        ld a,BLK_SPR
        call map_blk
        ld hl,0
        ld de,0
        ld bc,128
        jp glyphs_in

; wait one frame (two fields), read the keys
wait_frame:
        call input_used
        call sound_tick
        ld a,2
        call frame_wait
        jp read_input

; show page 0 (front-end screens draw on both pages anyway)
page_show0:
        ld a,12
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld (rpage),a
        ret

; ---------------------------------------------------------------------
; the attract demo's pilot: always firing, after the nearest enemy's
; height, keeping to the left third; takes upgrades now and then.
; A real fire press, or the time running out, ends the demo.
demo_input:
        ld a,(pad)
        and $10
        jr nz,demo_quit
        ld hl,(demo_t)
        inc hl
        ld (demo_t),hl
        ld a,h
        cp 5                    ; 1280 frames: about 50 seconds
        jr nc,demo_quit
        ld b,$10                ; fire
        call nearest_enemy      ; C = its y (+4), 0 if none
        jr z,.x
        ld a,(py)
        add a,6
        sub c
        jr z,.x
        jr c,.dn
        cp 3
        jr c,.x
        set 2,b                 ; up
        jr .x
.dn:    cp -3
        jr nc,.x
        set 3,b                 ; down
.x:     ld hl,(px)
        ld de,-40
        add hl,de
        bit 7,h
        jr z,.r
        set 0,b                 ; too far left: right
        jr .y
.r:     ld de,-60
        add hl,de
        bit 7,h
        jr nz,.y
        set 1,b                 ; too far right: left
.y:     ld a,(demo_t)
        and 63
        jr nz,.p
        set 5,b                 ; take whatever upgrade is lit
.p:     ld a,b
        ld (pad),a
        and $20
        ld (padnew),a
        xor a
        ld (keys),a
        ret
demo_quit:
        xor a
        ld (demo),a
        jp front_main
