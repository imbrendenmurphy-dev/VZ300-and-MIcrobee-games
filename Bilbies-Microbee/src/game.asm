; ---------------------------------------------------------------------------
; The bilbies: one logic tick (12.5 a second)
; Level coordinates: x 0..511 (16 bits, DE), y = the row the feet are in
; (0..79, C). The ground under a bilby is row y+1.
; What's solid is the 1-bit MASK (main RAM); the picture is TERR (SRAM).
; ---------------------------------------------------------------------------

; ---- addressing --------------------------------------------------------------
; DE = x, C = y -> HL = MASK byte, A = bit
mask_addr:
        ld a,c
        and 3
        rrca
        rrca
        ld l,a
        ld a,e
        rrca
        rrca
        rrca
        and $1F
        bit 0,d
        jr z,.m0
        or $20
.m0:    or l
        ld l,a
        ld a,c
        rrca
        rrca
        and $3F
        add a,MASK>>8
        ld h,a
        ld a,e
        and 7
        push hl
        ld hl,BITT
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        ret
; DE = x, C = y -> HL = TERR byte, A = pixel mask
disp_addr:
        ld a,c
        rrca
        and $80
        ld l,a
        ld a,e
        rrca
        rrca
        and $3F
        bit 0,d
        jr z,.d0
        or $40
.d0:    or l
        ld l,a
        ld a,c
        srl a
        add a,TERR>>8
        ld h,a
        ld a,e
        and 3
        push hl
        ld hl,PMSK
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        ret
; background pattern byte at (DE, C) -> A
bg_byte:
        push hl
        ld a,c
        and 7
        add a,a
        ld l,a
        bit 2,e
        jr z,.b0
        inc l
.b0:    ld h,0
        push de
        ld de,(v_bgtex)
        add hl,de
        pop de
        ld a,(hl)
        pop hl
        ret

; NZ if (DE, C) is solid. Off the sides counts as solid, above/below as air.
solid:
        ld a,c
        push hl
        ld hl,v_lh
        cp (hl)
        jr nc,.air
        ld hl,(v_lw)
        or a
        sbc hl,de
        jr c,.wall
        jr z,.wall
        call mask_addr
        and (hl)
        pop hl
        ret
.wall:  pop hl
        or 1
        ret
.air:   pop hl
        xor a
        ret

; inside the level? (Z flag clear if not) - for writes
in_level:
        push hl
        ld a,c
        ld hl,v_lh
        cp (hl)
        jr nc,.no
        ld hl,(v_lw)
        or a
        sbc hl,de
        jr c,.no
        jr z,.no
        pop hl
        xor a
        ret
.no:    pop hl
        or 1
        ret

; NZ if (DE, C) is in a steel area (x0.w y0 x1.w y1)
is_steel:
        ld a,(v_nsteel)
        or a
        ret z
        push hl
        push bc
        ld b,a
        ld hl,v_steel
.l:     push hl
        ; x >= x0 ?
        push de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        or a
        sbc hl,de               ; x - x0
        pop de
        pop hl
        jr c,.n
        push hl
        inc hl
        inc hl
        ld a,c
        cp (hl)                 ; y >= y0
        jr c,.n1
        inc hl
        push de
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        or a
        sbc hl,de               ; x1 - x
        pop hl
        pop de
        jr c,.n1
        inc hl
        ld a,(hl)
        cp c                    ; y1 >= y
        jr c,.n1
        pop hl
        pop bc
        pop hl
        or 1
        ret
.n1:    pop hl
.n:     ld a,l
        add a,6
        ld l,a
        jr nc,.nc
        inc h
.nc:    djnz .l
        pop bc
        pop hl
        xor a
        ret

; remove the pixel at (DE, C): C flag if it's steel (left alone);
; v_dug counts solid pixels removed
clear_px:
        call in_level
        jr nz,.x
        call is_steel
        jr nz,.st
        push hl
        call mask_addr
        and (hl)
        jr z,.e
        xor (hl)
        ld (hl),a               ; clear the bit
        call disp_addr
        push bc
        ld b,a
        call bg_byte
        xor (hl)
        and b
        xor (hl)
        ld (hl),a
        pop bc
        ld hl,v_dug
        inc (hl)
.e:     pop hl
.x:     or a
        ret
.st:    call solid
        ret z                   ; (empty steel area: nothing there; NC from xor)
        scf
        ret

; a brick pixel at (DE, C)
brick_px:
        call in_level
        ret nz
        push hl
        push bc
        call mask_addr
        or (hl)
        ld (hl),a
        call disp_addr
        ld b,a
        ld a,(v_brick)
        xor (hl)
        and b
        xor (hl)
        ld (hl),a
        pop bc
        pop hl
        ret

; ---- one game tick --------------------------------------------------------------
game_tick:
        ld a,(v_paused)
        or a
        ret nz
        ld hl,(v_gtick)
        inc hl
        ld (v_gtick),hl
        call release_tick
        call nuke_tick
        call count_blockers
        ld ix,CRT
        ld b,NCRT
.l:     push bc
        ld a,(ix+C_ST)
        or a
        jr z,.n
        cp ST_GONE
        jr nc,.n
        call bomb_tick
        ld a,(ix+C_ST)
        add a,a
        ld l,a
        ld h,0
        ld de,STJT
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call .jp
        call int_poll
.n:     ld de,CSZ
        add ix,de
        pop bc
        djnz .l
        call part_tick
        jp check_end
.jp:    jp (hl)

count_blockers:
        ld hl,CRT
        ld de,CSZ
        ld bc,NCRT*256
        IFNDEF LINEAR_BLOCKERS
        ld ix,v_blkptrs
        ENDIF
.l:     ld a,(hl)
        cp ST_BLOCK
        jr nz,.n
        inc c
        IFNDEF LINEAR_BLOCKERS
        ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        ENDIF
.n:     add hl,de
        djnz .l
        ld a,c
        ld (v_nblock),a
        ret

STJT:   dw st_nop,st_walk,st_fall,st_float,st_climb,st_hoist,st_block,st_build
        dw st_shrug,st_bash,st_mine,st_dig,st_splat,st_drown,st_exit,st_ohno
        dw st_nop,st_nop
st_nop: ret

; ---- small helpers on IX ----------------------------------------------------------
xy:     ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        ld c,(ix+C_Y)
        ret
setx:   ld (ix+C_XL),e
        ld (ix+C_XH),d
        ret
; B = direction step (+1 / -1)
dir_b:  ld b,1
        bit 0,(ix+C_DIR)
        ret z
        ld b,-1
        ret
; DE += B (+1 / -1)
stepx:  bit 7,b
        jr nz,.m
        inc de
        ret
.m:     dec de
        ret
turn:   ld a,(ix+C_DIR)
        xor 1
        ld (ix+C_DIR),a
        ret
set_st: ld (ix+C_ST),a
        ld (ix+C_AN),0
        ret
anim_wrap:
        ld c,a
        ld a,(ix+C_AN)
        inc a
        cp c
        jr c,.s
        xor a
.s:     ld (ix+C_AN),a
        or a
        ret
anim_once:
        ld c,a
        ld a,(ix+C_AN)
        inc a
        ld (ix+C_AN),a
        cp c
        ret
start_fall:
        ld (ix+C_CNT),0
        ld a,ST_FALL
        jp set_st
lose:   ld a,ST_GONE
        ld (ix+C_ST),a
        ld hl,v_lost
        inc (hl)
        ret

; the exit, water and the bottom after moving
after_move:
        ld a,(v_lh)
        add a,2
        ld c,a
        ld a,(ix+C_Y)
        cp c
        jp nc,lose              ; fell out of the level
        call in_water
        jr z,.nw
        ld a,ST_DROWN
        call set_st
        ld a,SFX_SPLASH
        jp sfx_play
.nw:    ld a,(ix+C_ST)
        cp ST_WALK
        ret nz
        ld a,(ix+C_Y)
        ld hl,v_ey
        sub (hl)
        add a,2
        cp 3
        ret nc
        call xy
        ld hl,(v_ex)
        inc hl
        or a
        sbc hl,de               ; ex + 1 - x in 0..2
        ld a,h
        or a
        ret nz
        ld a,l
        cp 3
        ret nc
        ld hl,(v_ex)
        ld (ix+C_XL),l
        ld (ix+C_XH),h
        ld a,ST_EXIT
        call set_st
        ld a,SFX_HOME
        jp sfx_play

; NZ if in the water
in_water:
        ld a,(v_wy)
        or a
        ret z
        ld c,a
        ld a,(ix+C_Y)
        cp c
        jr c,.no
        call xy
        ld hl,(v_wx0)
        or a
        sbc hl,de
        jr z,.in
        jr nc,.no               ; x < wx0
.in:    ld hl,(v_wx1)
        or a
        sbc hl,de
        jr c,.no
        jr z,.no                ; x >= wx1
        or 1
        ret
.no:    xor a
        ret

; NZ if a blocker stops a walker stepping to DE (direction B), row C
blocked:
        ld a,(v_nblock)
        or a
        ret z
        push ix
        push bc
        push de
        IFDEF LINEAR_BLOCKERS
        ld iy,CRT
        ld a,NCRT
        ELSE
        ld ix,v_blkptrs
        ld a,(v_nblock)
        ENDIF
.l:     push af
        IFNDEF LINEAR_BLOCKERS
        ld l,(ix+0)
        ld h,(ix+1)
        push hl
        pop iy
        ENDIF
        ld a,(iy+C_ST)
        cp ST_BLOCK
        jr nz,.n
        ld a,(iy+C_Y)
        sub c
        add a,3
        cp 7
        jr nc,.n
        ; t = nx - bx
        push de
        ex de,hl
        ld e,(iy+C_XL)
        ld d,(iy+C_XH)
        or a
        sbc hl,de
        pop de
        bit 7,b
        jr nz,.left
        inc hl
        inc hl                  ; moving right: nx in bx-2..bx
.left:  ld a,h                  ; moving left: nx in bx..bx+2
        or a
        jr nz,.n
        ld a,l
        cp 3
        jr nc,.n
        pop af
        pop de
        pop bc
        pop ix
        or 1
        ret
.n:
        IFDEF LINEAR_BLOCKERS
        push de
        ld de,CSZ
        add iy,de
        pop de
        ELSE
        inc ix
        inc ix
        ENDIF
        pop af
        dec a
        jr nz,.l
        pop de
        pop bc
        pop ix
        xor a
        ret

; ===========================================================================
; states
; ===========================================================================
st_walk:
        ld a,8
        call anim_wrap
        call xy
        call dir_b
        call stepx              ; DE = new x (off the sides is a wall)
        call blocked
        jp nz,turn
        call solid
        jr z,.free
        dec c                   ; a step up?
        call solid
        jr z,.up
        dec c
        call solid
        jr z,.up
        bit 0,(ix+C_FL)         ; a wall
        jp z,turn
        ld a,d                  ; the edges of the map are not for climbing
        inc a
        jp z,turn
        ld hl,(v_lw)
        or a
        sbc hl,de
        jp z,turn
        ld a,ST_CLIMB
        jp set_st
.up:    call setx
        ld (ix+C_Y),c
        jp after_move
.free:  call setx
        inc c
        call solid
        jr nz,.ok
        inc c
        call solid
        jr nz,.d1
        inc c
        call solid
        jr nz,.d2
        call start_fall
        jp after_move
.d2:    inc (ix+C_Y)
.d1:    inc (ix+C_Y)
.ok:    jp after_move

st_fall:
        ld a,4
        call anim_wrap
        ld a,2                  ; two rows a tick
.l:     push af
        call xy
        inc c
        call solid
        jr z,.down
        pop af
        ld a,(ix+C_CNT)
        cp DEATHFALL
        jr nc,.splat
        ld a,ST_WALK
        jp set_st
.splat: ld a,ST_SPLAT
        call set_st
        ld a,SFX_SPLAT
        jp sfx_play
.down:  inc (ix+C_Y)
        inc (ix+C_CNT)
        call after_move
        pop af
        ld c,a
        ld a,(ix+C_ST)
        cp ST_FALL
        ret nz
        bit 1,(ix+C_FL)
        jr z,.nf
        ld a,(ix+C_CNT)
        cp FLOATAT
        jr c,.nf
        ld a,ST_FLOAT
        jp set_st
.nf:    ld a,c
        dec a
        jr nz,.l
        ret

st_float:
        ld a,(ix+C_AN)
        inc a
        cp 8
        jr c,.s
        ld a,4
.s:     ld (ix+C_AN),a
        ld a,(v_gtick)
        rra
        ret c
        call xy
        inc c
        call solid
        jr z,.down
        ld a,ST_WALK
        jp set_st
.down:  inc (ix+C_Y)
        jp after_move

st_climb:
        ld a,8
        call anim_wrap
        ld a,(ix+C_AN)
        rra
        ret nc
        call xy
        ld a,c
        cp 4
        jr c,.off
        sub 4
        ld c,a
        call solid              ; ceiling over the head?
        jr nz,.off
        dec (ix+C_Y)
        call xy
        call dir_b
        call stepx
        call solid              ; still wall beside the feet?
        ret nz
        ld a,ST_HOIST
        jp set_st
.off:   call turn
        jp start_fall

st_hoist:
        ld a,8
        call anim_once
        ret nz
        call xy
        call dir_b
        call stepx
        call setx
        ld a,ST_WALK
        jp set_st

st_block:
        ld a,8
        call anim_wrap
        call xy
        inc c
        call solid
        ret nz
        jp start_fall

; builder: a stick on frame 9 of each 16; even sticks step up a row
st_build:
        ld a,16
        call anim_wrap
        ld a,(ix+C_AN)
        cp 9
        ret nz
        call xy
        call dir_b
        ; room for the head two ahead?
        push de
        push bc
        call stepx
        call stepx
        ld a,c
        sub 4
        ld c,a
        call solid
        pop bc
        pop de
        jr nz,.stop
        ; four pixels from x+d, row y (even sticks) or y+1 (odd)
        bit 0,(ix+C_CNT)
        jr z,.ev
        inc c
.ev:    push de
        ld a,4
.bl:    push af
        call stepx
        call brick_px
        pop af
        dec a
        jr nz,.bl
        pop de
        ; move on 2
        call stepx
        call stepx
        call setx
        bit 0,(ix+C_CNT)
        jr nz,.od
        dec (ix+C_Y)
.od:    ld a,(ix+C_CNT)
        inc a
        ld (ix+C_CNT),a
        cp NBRICK-2
        jr c,.nt
        push af
        ld a,SFX_TINK
        call sfx_play
        pop af
.nt:    cp NBRICK
        jr c,.wall
        ld a,ST_SHRUG
        jp set_st
.wall:  call xy                 ; a wall straight ahead at foot level: stop
        call dir_b
        call stepx
        call solid
        ret z
        dec c
        call solid
        ret z
.stop:  ld a,ST_WALK
        jp set_st

st_shrug:
        ld a,8
        call anim_once
        ret nz
        ld a,ST_WALK
        jp set_st

; is anything solid in rows y-3..y of column DE? NZ if so
col4:   push bc
        ld a,c
        sub 3
        ld c,a
        ld b,4
.r:     call solid
        jr nz,.y
        inc c
        djnz .r
        pop bc
        xor a
        ret
.y:     pop bc
        or 1
        ret
; clear rows (C-3 .. C-3+A-1) of column DE; C flag = steel met
clearcol:
        push bc
        ld b,a
        ld a,c
        sub 3
        ld c,a
.r:     call clear_px
        jr c,.st
        inc c
        djnz .r
        pop bc
        or a
        ret
.st:    pop bc
        scf
        ret

; basher: every 4th frame clears the next two columns (4 rows) and moves on
st_bash:
        ld a,32
        call anim_wrap
        call xy
        inc c
        call solid
        jp z,start_fall
        ld a,(ix+C_AN)
        and 3
        cp 2
        ret nz
        ; anything left to bash in the next 5 columns?
        call xy
        call dir_b
        ld a,5
.sc:    push af
        call stepx
        call col4
        jr nz,.some
        pop af
        dec a
        jr nz,.sc
        ld a,ST_WALK
        jp set_st
.some:  pop af
        call xy
        call dir_b
        xor a
        ld (v_dug),a
        call stepx
        ld a,4
        call clearcol
        jr c,.steel
        call stepx
        ld a,4
        call clearcol
        jr c,.steel
        call xy
        call stepx
        call setx
        ld a,(v_dug)
        or a
        ret z
        ld a,SFX_DIG
        jp sfx_play
.steel: ld a,SFX_CLINK
        call sfx_play
        ld a,ST_WALK
        jp set_st

; miner: on frames 4 and 16 clears ahead and below; 2 across, 1 down
st_mine:
        ld a,24
        call anim_wrap
        ld a,(ix+C_AN)
        cp 4
        jr z,.go
        cp 16
        ret nz
.go:    call xy
        call dir_b
        xor a
        ld (v_dug),a
        call stepx
        ld a,5
        call clearcol
        jr c,.steel
        call stepx
        ld a,5
        call clearcol
        jr c,.steel
        call xy
        inc c
        call clear_px
        jr c,.steel
        call xy
        call dir_b
        call stepx
        call stepx
        call setx
        inc (ix+C_Y)
        ld a,(v_dug)
        or a
        jr z,.nd
        ld a,SFX_DIG
        call sfx_play
.nd:    call xy
        inc c
        call solid
        jp z,start_fall
        jp after_move
.steel: ld a,SFX_CLINK
        call sfx_play
        ld a,ST_WALK
        jp set_st

; digger: on frames 4 and 12 clears the row under the feet (4 wide) and sinks
st_dig:
        ld a,16
        call anim_wrap
        ld a,(ix+C_AN)
        and 7
        cp 4
        ret nz
        call xy
        inc c
        xor a
        ld (v_dug),a
        dec de
        ld b,4
.l:     call clear_px
        jr c,.steel
        inc de
        djnz .l
        ld a,(v_dug)
        or a
        jp z,start_fall
        inc (ix+C_Y)
        ld a,SFX_DIG
        call sfx_play
        jp after_move
.steel: ld a,SFX_CLINK
        call sfx_play
        ld a,ST_WALK
        jp set_st

st_splat:
st_drown:
        ld a,16
        call anim_once
        ret nz
        jp lose

st_exit:
        ld a,8
        call anim_once
        ret nz
        ld a,ST_HOME
        ld (ix+C_ST),a
        ld hl,v_saved
        inc (hl)
        ret

st_ohno:
        call xy
        inc c
        call solid
        jr nz,.g
        inc (ix+C_Y)
        ld a,(v_lh)
        add a,2
        ld c,a
        ld a,(ix+C_Y)
        cp c
        jp nc,lose
.g:     ld a,16
        call anim_once
        ret nz
        jp explode

; ---- bombs ------------------------------------------------------------------------
bomb_tick:
        bit 2,(ix+C_FL)
        ret z
        dec (ix+C_BT)
        ret nz
        res 2,(ix+C_FL)
        ld a,(ix+C_ST)
        cp ST_FALL
        jr z,explode
        cp ST_FLOAT
        jr z,explode
        cp ST_CLIMB
        jr z,explode
        cp ST_HOIST
        jr z,explode
        cp ST_SPLAT
        ret nc
        ld a,SFX_OHNO
        call sfx_play
        ld a,ST_OHNO
        jp set_st

; blow a hole (9 wide x 7 rows round the body) and scatter sparks
explode:
        ld a,SFX_BOOM
        call sfx_play
        ld hl,EXPL
        call xy
        ld a,c
        sub 4
        ld c,a
        ld b,7
.r:     push bc
        push de
        ld a,(hl)               ; left offset
        inc hl
.o:     dec de
        dec a
        jr nz,.o
        ld b,(hl)               ; width
        inc hl
.p:     push hl
        call clear_px
        pop hl
        inc de
        djnz .p
        pop de
        pop bc
        inc c
        djnz .r
        call xy
        dec c
        dec c
        ld b,8
.s:     push bc
        call part_new
        pop bc
        djnz .s
        jp lose
EXPL:   db 2,5, 3,7, 4,9, 4,9, 4,9, 3,7, 2,5

; ---- sparks: x2.w (half pixels), y2 (half rows), vx, vy, life, colour -------------
PSZ         equ 7
part_new:
        ld hl,PART+5
        ld a,NPART
.f:     push af
        ld a,(hl)
        or a
        jr z,.got
        ld a,l
        add a,PSZ
        ld l,a
        jr nc,.nc
        inc h
.nc:    pop af
        dec a
        jr nz,.f
        ret
.got:   pop af
        ld a,l
        sub 5
        ld l,a
        jr nc,.n2
        dec h
.n2:    push de
        ex de,hl
        add hl,hl               ; x2 = 2x
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop de
        ld a,c
        add a,a
        ld (hl),a               ; y2
        inc hl
        call rand
        and 7
        sub 4
        ld (hl),a               ; vx
        inc hl
        call rand
        and 3
        add a,3
        neg
        ld (hl),a               ; vy
        inc hl
        call rand
        and 7
        add a,10
        ld (hl),a               ; life
        inc hl
        call rand
        and 1
        ld a,C_YEL
        jr z,.cs
        ld a,C_RED
.cs:    ld (hl),a
        ret

part_tick:
        ld ix,PART
        ld b,NPART
.l:     ld a,(ix+5)
        or a
        jr z,.n
        dec (ix+5)
        inc (ix+4)              ; gravity
        ld a,(ix+2)
        add a,(ix+4)
        ld (ix+2),a
        cp 200
        jr c,.ok
        ld (ix+5),0             ; off the top or bottom
.ok:    ld a,(ix+3)
        ld e,a
        rla
        sbc a,a
        ld d,a                  ; sign-extended vx
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
.n:     ld de,PSZ
        add ix,de
        djnz .l
        ret

; ---- release from the hatch -----------------------------------------------------
release_tick:
        ld a,(v_hatch)
        cp 16
        jr nc,.open
        inc a
        ld (v_hatch),a
        cp 2
        ret nz
        ld a,SFX_LETSGO
        jp sfx_play
.open:  ld a,(v_nuke)
        or a
        ret nz
        ld a,(v_released)
        ld hl,v_ncrt
        cp (hl)
        ret nc
        ld hl,v_reltimer
        ld a,(hl)
        or a
        jr z,.go
        dec (hl)
        ret
.go:    ld a,(v_rate)
        ld c,a
        ld a,100
        sub c
        srl a
        srl a
        add a,2
        ld (hl),a
        ld a,(v_released)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,CRT
        add hl,de
        push hl
        pop iy
        ld (iy+C_ST),ST_FALL
        ld hl,(v_hx)
        ld de,5
        add hl,de
        ld (iy+C_XL),l
        ld (iy+C_XH),h
        ld a,(v_hy)
        add a,5
        ld (iy+C_Y),a
        ld (iy+C_DIR),0
        ld (iy+C_AN),0
        ld (iy+C_CNT),0
        ld a,(v_spawnfl)
        ld (iy+C_FL),a
        ld hl,v_released
        inc (hl)
        ret

; ---- nuke: a bomb for everyone, one a tick ------------------------------------------
nuke_tick:
        ld a,(v_nuke)
        or a
        ret z
        ld a,(v_nukeidx)
        cp NCRT
        ret nc
        inc a
        ld (v_nukeidx),a
        dec a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,CRT
        add hl,de
        push hl
        pop iy
        ld a,(iy+C_ST)
        or a
        ret z
        cp ST_SPLAT
        ret nc
        bit 2,(iy+C_FL)
        ret nz
        set 2,(iy+C_FL)
        ld (iy+C_BT),BOMBTICKS
        ret

; ---- the end? -----------------------------------------------------------------------
check_end:
        ld a,(v_tleft+1)
        ld hl,v_tleft
        or (hl)
        jr z,.end
        ld a,(v_nuke)
        or a
        jr nz,.all
        ld a,(v_released)
        ld hl,v_ncrt
        cp (hl)
        ret c
.all:   ld ix,CRT
        ld b,NCRT
.l:     ld a,(ix+C_ST)
        or a
        jr z,.n
        cp ST_GONE
        ret c
.n:     ld de,CSZ
        add ix,de
        djnz .l
        ld a,(v_nuke)
        or a
        jr z,.end
        ld a,(v_nukeidx)
        cp NCRT
        ret c
.end:   ld a,1
        ld (v_end),a
        ret

count_out:
        ld a,(v_released)
        ld hl,v_saved
        sub (hl)
        ld hl,v_lost
        sub (hl)
        ret
