mus_start:
        call snd_off
        ld hl,mus_order_tab
        ld (mus_order),hl
        ld a,1
        ld (mus_tmr),a
        ld a,6
        ld (mus_tempo),a
        call mus_next_pat
        ld hl,mus_tick
        ld (tick_hook),hl
        ret

mus_stop:
        ld hl,no_tick
        ld (tick_hook),hl
        jp snd_off

mus_next_pat:
        ld hl,(mus_order)
        ld a,(hl)
        cp $FF
        jr nz,.ok
        ld hl,mus_order_tab+MUS_LOOP
        ld a,(hl)
.ok:    inc hl
        ld (mus_order),hl
        add a,a
        ld e,a
        ld d,0
        ld hl,mus_pat_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (mus_ptr),hl
        ld a,16
        ld (mus_row),a
        ret

mus_tick:
        ld hl,mus_tmr
        dec (hl)
        jr nz,.env
        ld a,(mus_tempo)
        ld (hl),a
        call mus_do_row
.env:   jp sfx_tick

mus_do_row:
        ld hl,(mus_ptr)
        ld a,(hl)
        inc hl
        push hl
        ld ix,ch0
        ld iy,mprog0
        ld c,0
        call mus_event
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld ix,ch1
        ld iy,mprog1
        ld c,1
        call mus_event
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld ix,ch2
        ld iy,mprog2
        ld c,2
        call mus_event
        pop hl
        ld (mus_ptr),hl
        ld hl,mus_row
        dec (hl)
        ret nz
        jp mus_next_pat

; A = event byte, IX = channel, IY = program buffer, C = channel number
mus_event:
        or a
        ret z
        cp $FE
        jr nz,.n1
        xor a
        ld (ix+CH_PTR),a
        ld (ix+CH_PTR+1),a
        ret
.n1:    cp $F1
        jr c,.note
        ; drum: point channel at a fixed program
        sub $F1
        add a,a
        ld e,a
        ld d,0
        ld hl,drum_progs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp .set
.note:  ld b,0                  ; arp flag
        ld d,a
        ld a,c
        cp 2
        ld a,d
        jr nz,.plain
        ; ch2 chord: >100 major
        ld b,3                  ; minor third
        cp 101
        jr c,.arp
        sub 100
        ld b,4
.arp:   ; three 1-tick segments: root, third, fifth, looping
        ld (tmp1),a
        push iy
        pop hl
        ld e,a
        call .seg1
        ld a,(tmp1)
        add a,b
        ld e,a
        call .seg1
        ld a,(tmp1)
        add a,7
        ld e,a
        call .seg1
        ld (hl),$FF
        inc hl
        push iy
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        push iy
        pop hl
        jr .set
.seg1:  ; HL = buffer, E = note -> 8-byte segment, 1 tick, quiet pad
        ld (hl),1
        inc hl
        call .freq
        ld (hl),40
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ret
.freq:  ; write freq of note E (1-based), df = 0
        push hl
        ld d,0
        dec e
        ld hl,note_frq
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ret
.plain: ; ch0 bass / ch1 lead: gate then cut (notes stay separate)
        ld e,a
        push iy
        pop hl
        ld a,c
        or a
        jr nz,.lead
        ld (hl),5               ; bass: 5 ticks
        inc hl
        call .freq
        ld (hl),110
        inc hl
        ld (hl),-10
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0               ; end
        push iy
        pop hl
        jr .set
.lead:  ld (hl),9               ; lead: 9 ticks with decay
        inc hl
        call .freq
        ld (hl),96
        inc hl
        ld (hl),-7
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        push iy
        pop hl
.set:   ld (ix+CH_PTR),l
        ld (ix+CH_PTR+1),h
        ld (ix+CH_CNT),0
        ld (ix+CH_PRIO),0
        ret

drum_progs: dw dr_kick, dr_snare, dr_hat
dr_kick:  SEG 3, 900, -250, 128, -36, 0
          db 0
dr_snare: SEG 1, 1, 0, 120, 0, 1
          SEG 3, 2, 0, 100, -30, 1
          db 0
dr_hat:   SEG 1, 3, 0, 44, 0, 1
          db 0

; ======================= screen helpers =======================
; map ROWTAB to VRAM rows 6..63 so draw_spr / plot can XOR straight onto the screen
