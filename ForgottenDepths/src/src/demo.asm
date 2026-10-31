; =====================================================================
;  demo.asm : attract-mode demo. The game's input stream from a recorded
;  run is replayed (RLE: count, input byte; 0 ends). The game logic is
;  deterministic, so the replay repeats the run exactly.
; =====================================================================
demo_on:   db 0
demo_ptr:  dw 0
demo_cnt:  db 0
demo_val:  db 0
demo_iter: dw 0
demo_chk:  ds 4             ; state snapshot at iteration DEMO_CHKAT (testing)
DEMO_CHKAT EQU 1500

; identical start state for recording and playback
demo_setup:
        ld hl,p_x
        ld de,p_x+1
        ld bc,game_over-p_x
        ld (hl),0
        ldir
        ld a,6
        ld (p_hpmax),a
        ld a,4
        ld (p_mpmax),a
        ld a,1
        ld (p_lvl),a
        ld (lv_num),a
        ld hl,$ACE1
        ld (rnd_seed),hl
        xor a
        ld (frame),a
        ld (light_var),a
        ld (in_now),a
        ld (in_last),a
        ld (in_new),a
        ld (demo_cnt),a
        ld hl,0
        ld (frame_w),hl
        ld (demo_iter),hl
        ld hl,DEMO_DATA
        ld (demo_ptr),hl
        ld a,1
        call level_load
        ret c
        call level_begin
        call chapter_start
        or a
        ret

; title attract slot: play the demo. Carry = a key was pressed (start game)
demo_run:
        ld a,(DEMO_DATA)
        or a
        ret z
        call bank0
        call demo_setup
        jr c,.out
        ld a,1
        ld (demo_on),a
        xor a
        ld (demo_abort),a
        call game_loop
.out:   xor a
        ld (demo_on),a
        call music_stop
        ld a,M0O
        ld (lbase),a
        ld (LATCH),a
        call bank1
        ld a,TR_TITLE
        call music_play
        ld a,(demo_abort)
        rrca                    ; carry = aborted by a key
        ret
demo_abort: db 0

; called by read_input while the demo plays: C = recorded input
demo_input:
        call kb_pressed
        jr z,.play
        ld a,1
        ld (demo_abort),a
        ld (game_over),a
        ld a,3
        ld (game_over),a
        ld c,0
        jp ri_store
.play:  ld a,(demo_cnt)
        or a
        jr nz,.have
        ld hl,(demo_ptr)
        ld a,(hl)
        or a
        jr nz,.nx
        ld a,3                  ; end of the recording
        ld (game_over),a
        ld c,0
        jp ri_store
.nx:    ld (demo_cnt),a
        inc hl
        ld a,(hl)
        ld (demo_val),a
        inc hl
        ld (demo_ptr),hl
.have:  ld hl,demo_cnt
        dec (hl)
        ld a,(demo_val)
        ld c,a
        call demo_tick
        jp ri_store

; count game iterations; take a state snapshot at DEMO_CHKAT
demo_tick:
        ld hl,(demo_iter)
        inc hl
        ld (demo_iter),hl
        ld de,DEMO_CHKAT
        or a
        sbc hl,de
        ret nz
        ld a,(p_x)
        ld (demo_chk),a
        ld a,(p_y)
        ld (demo_chk+1),a
        ld a,(p_hp)
        ld (demo_chk+2),a
        ld a,(p_xp)
        ld (demo_chk+3),a
        ret

; any key or joystick fire held? NZ = yes (does not touch the input state)
kb_pressed:
        ld hl,$68FE
        ld b,8
.k:     ld a,(hl)
        and $3F
        cp $3F
        ret nz
        rlc l
        djnz .k
        ld a,(joy_ok)
        or a
        ret z
        in a,($2E)
        and $10
        xor $10
        ret nz
        in a,($2B)
        and $10
        xor $10
        ret

        IFDEF DEMOREC
; ---------------------------------------------------------------------
; recording build: RLE input log at $C200-$C7FF
; ---------------------------------------------------------------------
REC     EQU $C200
rec_on:  db 0
rec_ptr: dw REC
rec_cnt: db 0
rec_val: db 0
rec_input:
        push bc
        call demo_tick
        pop bc
        ld a,(rec_cnt)
        or a
        jr z,.new
        cp 255
        jr z,.flush
        ld a,(rec_val)
        cp c
        jr nz,.flush
        ld hl,rec_cnt
        inc (hl)
        ret
.flush: ld hl,(rec_ptr)
        ld a,h
        cp $C8
        ret nc                  ; buffer full
        ld a,(rec_cnt)
        ld (hl),a
        inc hl
        ld a,(rec_val)
        ld (hl),a
        inc hl
        ld (rec_ptr),hl
.new:   ld a,c
        ld (rec_val),a
        ld a,1
        ld (rec_cnt),a
        ret

demo_record:
        call bank0
        call demo_setup
        ld a,1
        ld (rec_on),a
        call game_loop
.h:     jr .h
        ENDIF
