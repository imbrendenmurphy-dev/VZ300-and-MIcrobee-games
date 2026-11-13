; =====================================================================
;  hiscore.asm - the high-score table and name entry (main RAM)
; =====================================================================
hi_init:
            ld a,(HISCORES)
            cp 'G'
            jr nz,.new
            ld a,(HISCORES+1)
            cp 'X'
            jr z,.ok
.new:       ld hl,hi_default
            ld de,HISCORES
            ld bc,2+HI_N*HI_SZ
            ldir
.ok:        ld hl,HISCORES+2
            ld de,hiscore
            ld bc,3
            ldir
            ret

; ---------------------------------------------------------------------
; a new high score? enter three letters
; ---------------------------------------------------------------------
hi_enter:
            ; find the rank: first entry with a lower score
            ld hl,HISCORES+2
            ld b,0
.f:         push hl
            ld de,score
            ld a,(de)
            cp (hl)
            jr nz,.cmp
            inc hl
            inc de
            ld a,(de)
            cp (hl)
            jr nz,.cmp
            inc hl
            inc de
            ld a,(de)
            cp (hl)
.cmp:       pop hl
            jr z,.nx
            jr nc,.got              ; ours is higher
.nx:        ld de,HI_SZ
            add hl,de
            inc b
            ld a,b
            cp HI_N
            jr nz,.f
            ret                     ; not good enough
.got:       ld a,b
            ld (ent_rank),a
            ; shift the lower entries down
            push hl
            ld a,HI_N-1
            sub b
            jr z,.ns
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,de
            add hl,hl               ; *6
            ld b,h
            ld c,l
            ld hl,HISCORES+2+(HI_N-1)*HI_SZ-1
            ld de,HISCORES+2+HI_N*HI_SZ-1
            lddr
.ns:        pop hl
            push hl
            ex de,hl
            ld hl,score
            ld bc,3
            ldir
            ld a,'A'
            ld (de),a
            ld (ent_name),a
            inc de
            ld (de),a
            ld (ent_name+1),a
            inc de
            ld (de),a
            ld (ent_name+2),a
            xor a
            ld (ent_pos),a
            pop hl
            inc hl
            inc hl
            inc hl
            push hl                 ; where the name goes
            ld hl,str_ent3
            call bar_msg
            call silence
            ld hl,tune_title
            call music
.loop:      call read_input
            call sound_tick
            ld a,(ent_pos)
            ld e,a
            ld d,0
            ld hl,ent_name
            add hl,de
            ld a,(in_new)
            bit 0,a
            jr z,.nu
            ld a,(hl)
            inc a
            cp 'Z'+1
            jr c,.u
            ld a,' '
            jr .u
.u:         cp ' '+1
            jr nz,.u2
            ld a,'A'
.u2:        ld (hl),a
            ld a,SFX_MENU
            call sfx
.nu:        ld a,(in_new)
            bit 1,a
            jr z,.nd
            ld a,(hl)
            cp 'A'
            jr nz,.d1
            ld a,' '
            jr .d2
.d1:        cp ' '
            jr nz,.d3
            ld a,'Z'
            jr .d2
.d3:        dec a
.d2:        ld (hl),a
            ld a,SFX_MENU
            call sfx
.nd:        ld a,(in_new)
            and K_FIRE|K_ARM|K_RIGHT
            jr z,.nf
            ld a,SFX_COIN
            call sfx
            ld hl,ent_pos
            inc (hl)
            ld a,(hl)
            cp 3
            jp nc,.done
.nf:        ld a,(in_new)
            bit 2,a
            jr z,.dr
            ld hl,ent_pos
            ld a,(hl)
            or a
            jr z,.dr
            dec (hl)
.dr:        ; draw
            call bb_wait
            ld a,$AA
            call cls_bb
            ld a,10
            ld b,10
            ld c,$FF
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,str_ent1
            ld a,10
            call big_centre
            ld a,1
            ld c,2
            call text_col
            ld hl,str_ent2
            ld a,26
            call small_centre
            ld hl,ent_name
            ld de,34*32+13
            call bbde
            ld b,3
            ld c,0
.ch:        push bc
            ld a,(ent_pos)
            cp c
            ld a,1
            jr nz,.ci
            ld a,(frames)
            and 4
            ld a,3
            jr z,.ci
            ld a,1
.ci:        push hl
            push de
            ld c,2
            call text_col
            pop de
            pop hl
            ld a,(hl)
            push hl
            call putc2
            pop hl
            inc hl
            inc de
            inc de
            pop bc
            inc c
            djnz .ch
            call present
            jp .loop
.done:      pop de
            ld hl,ent_name
            ld bc,3
            ldir
            ld hl,HISCORES+2
            ld de,hiscore
            ld bc,3
            ldir
            ld a,SFX_LIFE
            call sfx
            ld a,30
            call wait_fields
            call hi_table
            ld a,1
            ld (bar_dirty),a
            ret
str_ent1:   db "BONZER!",0
str_ent2:   db "ENTER YOUR NAME",0
str_ent3:   db "^ v LETTER   FIRE NEXT",0
