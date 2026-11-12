; =====================================================================
;  SOUND: one speaker bit. The game makes no sound while it works: the
;  tone is played in the time left over, while the frame waits for the
;  vertical blanking. Effects are lists of (pitch, ticks); the tune is
;  slow, separate blips, so the gaps the frame's work leaves in it do
;  not matter.
;  pitch = half-period loop count (42 T a count + 37), $FF = noise, 0 = rest
; =====================================================================
; HL = effect
play_sfx:
        ld (sfx_ptr),hl
        xor a
        ld (sfx_left),a
        inc a
        ld (sfx_on),a
        ret

snd_tick:
        ld a,(sfx_on)
        or a
        jr z,.music
        ld a,(sfx_left)
        or a
        jr nz,.dec
        ld hl,(sfx_ptr)
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (sfx_ptr),hl
        inc b
        dec b
        jr z,.end
        ld (snd_per),a
        ld a,b
.dec:   dec a
        ld (sfx_left),a
        jr .mtime
.end:   xor a
        ld (sfx_on),a
.music: xor a
        ld (snd_per),a
.mtime: ; the tune keeps time under the effects
        ld a,(mus_on)
        or a
        ret z
        ld a,(mus_left)
        or a
        jr nz,.mdec
        ld hl,(mus_ptr)
        ld a,(hl)
        cp $FE
        jr nz,.note
        ld hl,tune
        ld a,(hl)
.note:  ld (mus_note),a
        inc hl
        ld a,(hl)
        inc hl
        ld (mus_ptr),hl
        ld (mus_left),a
        ld a,3                  ; each note sounds in the next three waits
        ld (mus_gate),a
        ld a,(mus_left)
.mdec:  dec a
        ld (mus_left),a
        ret

; wait for the vertical blanking to begin, playing the current pitch
snd_wait:
        ld a,(sfx_on)
        or a
        jr nz,.go               ; an effect: the pitch the tick set
        ld a,(mus_gate)
        or a
        jr z,.q
        dec a
        ld (mus_gate),a
        ld a,(mus_note)
.q:     ld (snd_per),a
.go:    in a,(P_CRTCA)
        and $20
        jr z,.p2
        ld e,0
        call snd_until
.p2:    ld e,$20
        call snd_until
        ld a,$20
        ld (vlast),a
        ld hl,fields
        inc (hl)
        ret

; play until (6545 status & $20) = E
snd_until:
        ld a,(snd_per)
        or a
        jr z,.silent
        cp $FF
        jr z,.noise
        ld d,a
        ld a,(spk)
        ld c,a
.cyc:   ld b,d
.h:     in a,(P_CRTCA)
        and $20
        cp e
        jr z,.out
        djnz .h
        ld a,c
        xor $40
        ld c,a
        out (P_PIOB),a
        jr .cyc
.out:   ld a,c
        ld (spk),a
        ret
.silent:
        in a,(P_CRTCA)
        and $20
        cp e
        jr nz,.silent
        ret
.noise: ld hl,(rseed)
.n:     in a,(P_CRTCA)
        and $20
        cp e
        jr z,.nout
        add hl,hl
        jr nc,.n1
        ld a,l
        xor $2D
        ld l,a
.n1:    ld a,h
        and $40
        out (P_PIOB),a
        ld b,6
.nd:    djnz .nd
        jr .n
.nout:  ld a,h
        or l
        jr nz,.ns
        inc l
.ns:    ld (rseed),hl
        ret

; =====================================================================
;  TWO VOICES, for the title and the jingles, when the CPU has nothing
;  else to do. Each voice is a square wave counted down in a fixed 89 T
;  loop; the speaker plays the two XORed. A rest is a voice whose
;  toggle has been patched to do nothing.
;  HL = song: events (p1, p2, len): p = half-period in loops (0 = rest),
;  len in fiftieths, b7 set = run straight on (no gap). $FF = from the
;  top, $FE = the end. tw_hook is called before each event.
;  -> Z: the song ended; NZ: SPACE/fire or ESC was pressed (A = $10 / $80)
; =====================================================================
TW_ITER     EQU 760         ; 89 T loops in a fiftieth of a second
TW_GAP      EQU 2600        ; 26 T loops in a fiftieth

tw_song:
        ld (tw_start),hl
        ld (tw_ptr),hl
tws_ev: ld hl,(tw_hook)
        call jp_hl
        ld hl,(tw_ptr)
        ld a,(hl)
        cp $FF
        jr nz,tws_1
        ld hl,(tw_start)
        ld (tw_ptr),hl
        ld a,(hl)
tws_1:  cp $FE
        ret z
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (tw_ptr),hl
        ld (tw_len),a
        push de
        call read_menu
        pop de
        ld a,(padnew)
        and $90                 ; SPACE (or fire), or ESC
        ret nz
        ld a,d
        or a
        ld a,$40
        jr nz,tws_2
        xor a
        dec d                   ; a rest counts from 255: the loop keeps its time
tws_2:  ld (tws_x1+1),a
        ld a,e
        or a
        ld a,$40
        jr nz,tws_3
        xor a
        dec e
tws_3:  ld (tws_x2+1),a
        ld a,(tw_len)
        ld c,a
        and $7F
        bit 7,c
        jr nz,tws_4
        dec a                   ; the last fiftieth is a gap
tws_4:  or a
        jr z,tws_gap
        ld (tw_cnt),a
        ld b,d
        ld c,e
        ld hl,0
tws_u:  ld ix,TW_ITER
tws_l:  dec b
        jr nz,tws_a
        ld b,d
        ld a,l
tws_x1: xor $40
        ld l,a
tws_a:  dec c
        jr nz,tws_b
        ld c,e
        ld a,h
tws_x2: xor $40
        ld h,a
tws_b:  ld a,l
        xor h
        out (P_PIOB),a
        dec ix
        ld a,ixh
        or ixl
        jr nz,tws_l
        ld a,(tw_cnt)
        dec a
        ld (tw_cnt),a
        jr nz,tws_u
        ld a,(tw_len)
        bit 7,a
        jp nz,tws_ev
tws_gap:
        xor a
        out (P_PIOB),a
        ld bc,TW_GAP
tws_g:  dec bc
        ld a,b
        or c
        jr nz,tws_g
        jp tws_ev

jp_hl:  jp (hl)
hook_none:
        ret
