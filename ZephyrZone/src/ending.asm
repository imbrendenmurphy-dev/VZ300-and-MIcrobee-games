; =====================================================================
;  ending.asm - the finale after SUN.. after stage 5 (ZZEND.DAT, loaded into
;  upper bank 1 at $B800 over the world; the next world is loaded after).
;  A still dawn picture (tools/endpic.py) with fireworks bursting over it,
;  the finale theme, and the closing lines one by one.
; =====================================================================
            include "../build/mainsym.inc"
            org $B800
END_PIC     equ $E000
NPART       equ 64              ; particles: four bursts of 16 in the air at once
PSIZE       equ 7               ; x (8.8), y (8.8), vx, vy (1/16 px a frame), life

finale:
            ld a,L_MODE|L_SPK0      ; (CSS0 palette)
            ld (latchv),a
            ld (LATCH),a
            call map_game
            ld hl,END_PIC           ; rows 0-5 aren't re-copied: set them now
            ld de,VRAM
            ld bc,6*32
            ldir
            ld hl,parts
            ld de,parts+1
            ld bc,NPART*PSIZE-1
            ld (hl),0
            ldir
            xor a
            ld (e_line),a
            ld (e_burst),a
            ld (e_lt),a
            ld hl,0                 ; no music: the fireworks carry the scene
            call music
            ld a,3
            ld (minfields),a
.f:         call read_input
            ld a,(dtf)
            or a
            jr nz,.d
            ld a,3
.d:         ld (dt),a
            call sound_tick
            call bb_wait
            call map_game
            ld hl,END_PIC
            ld de,BB
            ld bc,2048
            ldir
            call fireworks
            call lines
            jr c,.done
            ld a,200
            ld (msg_t),a
            ld a,50
            call msg_blit
            call map_game
            xor a
            ld (dirty_top),a
            call present
            ld a,(e_line)           ; fire skips to the end, once a few lines are up
            cp 4
            jr c,.f
            ld a,(in_new)
            and K_FIRE
            jr z,.f
.done:      ld hl,0
            jp music

; the closing lines: a new one every 100 fields; C when they've all been shown
lines:
            ld a,(e_lt)
            ld hl,dt
            sub (hl)
            jr nc,.w
            ld a,(e_line)
            cp NLINES
            ccf
            ret c                   ; all shown: finished
            inc a
            ld (e_line),a
            dec a
            add a,a
            ld e,a
            ld d,0
            ld hl,line_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld de,wname_buf
            ld bc,17
            ldir
            ld a,M_NAME1
            call to_fe
            dw show_msg
            call map_game
            ld a,100
.w:         ld (e_lt),a
            or a
            ret
line_tab:   dw l0,l1,l2,l3,l4,l5,l6,l7,l8,l9,l9
NLINES      equ 11
l0:         db "WELL DONE!",0
l1:         db "THE FIVE ZONES",0
l2:         db "ARE FREE AGAIN",0
l3:         db "THANK YOU",0
l4:         db "ZEPHYR!",0
l5:         db "ZEPHYR ZONE",0
l6:         db "VIBED BY BPM",0
l7:         db "2026",0
l8:         db "NOW TRY",0
l9:         db "ROUND TWO!",0

; launch bursts, move and draw the sparks
fireworks:
            ld a,(e_burst)
            ld hl,dt
            sub (hl)
            jr nc,.nb
            call burst
            call random
            and 15
            add a,12                ; next burst in 12-27 fields
.nb:        ld (e_burst),a
            ld ix,parts
            ld b,NPART
.p:         push bc
            ld a,(ix+6)
            or a
            jr z,.n
            dec (ix+6)
            ; x += vx/16, y += vy/16 (8.8)
            ld a,(ix+4)
            call .ext
            ld a,(ix+0)
            add a,e
            ld (ix+0),a
            ld a,(ix+1)
            adc a,d
            ld (ix+1),a
            ld a,(ix+5)
            call .ext
            ld a,(ix+2)
            add a,e
            ld (ix+2),a
            ld a,(ix+3)
            adc a,d
            ld (ix+3),a
            inc (ix+5)              ; gravity
            ; draw: colour by age
            ld a,(ix+6)
            ld c,1                  ; young: yellow
            cp 14
            jr nc,.c
            ld c,3                  ; then red
            cp 6
            jr nc,.c
            ld c,0                  ; then green embers
.c:         ld a,(ix+1)
            cp 128
            jr nc,.n
            ld d,a
            ld a,(ix+3)
            cp 6
            jr c,.n
            cp 64
            jr nc,.n
            ld e,a
            push de
            push bc
            call plot
            pop bc
            pop de
            inc d                   ; two pixels wide
            bit 7,d
            call z,plot
.n:         ld de,PSIZE
            add ix,de
            pop bc
            djnz .p
            ret
.ext:       ; A (signed, 1/16 px) -> DE (8.8)
            ld e,a
            rla
            sbc a,a
            ld d,a
            ex de,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ex de,hl
            ret

; a burst of 12 sparks at a random spot in the sky
burst:
            call random
            and 127
            add a,0                 ; x anywhere
            ld (b_x),a
            call random
            and 15
            add a,9                 ; y 9-24
            ld (b_y),a
            ld ix,parts
            ld hl,dirs
            ld c,16
            ld b,NPART
.f:         ld a,(ix+6)
            or a
            jr nz,.nx
            ld (ix+0),0
            ld a,(b_x)
            ld (ix+1),a
            ld (ix+2),0
            ld a,(b_y)
            ld (ix+3),a
            ld a,(hl)
            inc hl
            ld (ix+4),a
            ld a,(hl)
            inc hl
            ld (ix+5),a
            ld (ix+6),26
            dec c
            jr z,.snd
.nx:        ld de,PSIZE
            add ix,de
            djnz .f
.snd:       ld a,SFX_BOOM
            jp sfx
; 16 directions: an outer ring (fast) and an inner ring (slow); y squashed for the tall pixels
dirs:       db 30,0,21,-14,0,-20,-21,-14,-30,0,-21,14,0,20,21,14
            db 15,-4,6,-10,-6,-10,-15,-4,-15,4,-6,10,6,10,15,4

; plot colour C at x D, y E into the back buffer
plot:
            ld l,e
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,d
            srl a
            srl a
            add a,l
            ld l,a
            ld a,h
            add a,HIGH(BB)
            ld h,a
            ld a,d
            and 3
            ld e,a
            ld d,0
            push hl
            ld hl,pmask
            add hl,de
            ld b,(hl)               ; keep-mask
            ld a,c
            ld hl,pcol
            ld e,a
            add hl,de
            ld a,(hl)               ; colour in every pixel
            pop hl
            ld e,a
            ld a,b
            cpl
            and e
            ld e,a
            ld a,(hl)
            and b
            or e
            ld (hl),a
            ret
pmask:      db $3F,$CF,$F3,$FC
pcol:       db $00,$55,$AA,$FF

e_line:     db 0
e_lt:       db 0
e_burst:    db 0
b_x:        db 0
b_y:        db 0
parts:      ds NPART*PSIZE
end_code:
            assert end_code < END_PIC
