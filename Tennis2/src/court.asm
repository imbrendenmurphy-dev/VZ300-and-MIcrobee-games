; =====================================================================
;  TENNIS II - surfaces, run-time sprite build, court backdrop,
;  scoreboard panel, umpire banners, crowd
; =====================================================================

; surface table, 16 bytes each:
; latch, bgmap[4] (court,line,surround,accent), sprmap[4] (dark,light,teamA,teamB),
; shadow colour, style (0 std / 1 classic), bounce rest, bounce keep, dw name, pad
SURF_GRASS   equ 0
SURF_CLAY    equ 1
SURF_HARD    equ 2
SURF_NIGHT   equ 3
SURF_CLASSIC equ 4
surftab:
        db MODE1,      0,1,0,2,  2,1,2,3,  2, 0, 140, 236 : dw sn_grass   : db 0
        db MODE1|CSS1, 3,0,3,2,  2,0,1,2,  2, 0, 196, 196 : dw sn_clay    : db 0
        db MODE1|CSS1, 1,0,1,3,  2,0,2,3,  2, 0, 172, 220 : dw sn_hard    : db 0
        db MODE1,      2,1,2,3,  0,1,3,0,  0, 0, 160, 232 : dw sn_night   : db 0
        db MODE1,      0,1,0,2,  1,1,2,3,  2, 1, 150, 236 : dw sn_classic : db 0
sn_grass:   db "GRASS",0
sn_clay:    db "CLAY",0
sn_hard:    db "HARD COURT",0
sn_night:   db "NIGHT INDOOR",0
sn_classic: db "CLASSIC 1984",0

; set_surface: A = surface. Copies its table, rebuilds the sprites in its colours.
set_surface:
        ld (surface),a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,surftab
        add hl,de
        ld de,s_latch
        ld bc,16
        ldir
        ; default colouring: team A at the far end, team B near
        ld hl,s_sprmap
        ld de,bmap
        ld bc,4
        ldir
        jp build_sprites

; recolour the player sprites for whoever is at each end now
sprites_for_ends:
        ld hl,s_sprmap
        ld de,bmap
        ld bc,4
        ldir
        ld a,(pl0+P_END)
        or a
        jp z,build_sprites      ; team A (pl0) is far: default colours (still rebuild!)
        ld a,(s_sprmap+3)
        ld (bmap+2),a
        ld a,(s_sprmap+2)
        ld (bmap+3),a
        jp build_sprites

; build a 256-byte recolour table at RMAP from the 4-entry map at HL
build_rmap:
        ld (mapptr),hl
        ld hl,RMAP
        ld c,0
.b:     ld b,4
        ld e,c
        ld d,0
.f:     ld a,e
        rlca
        rlca
        ld e,a
        and 3
        push hl
        push de
        ld hl,(mapptr)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        sla d
        sla d
        or d
        ld d,a
        djnz .f
        ld (hl),d
        inc l
        inc c
        jr nz,.b
        ret

; build_sprites: shift (4 positions) + recolour every sprite into SPRWORK,
; and fill shtab (dw base, db pw=3, db h, dw shiftsize, dw 0) for render.
build_sprites:
        ld hl,bmap
        call build_rmap
        ld ix,sprsrc
        ld iy,shtab
        ld de,SPRWORK
        ld b,NSPR
.spr:   push bc
        ld (iy+0),e
        ld (iy+1),d
        ld (iy+2),3
        ld a,(ix+2)
        ld (iy+3),a
        ld (rowcnt),a
        ; shift size = h*6
        ld l,a
        ld h,0
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        ld (iy+4),l
        ld (iy+5),h
        ld a,(ix+3)
        or a
        ld a,3
        jr z,.four
        ld (iy+4),0             ; single, byte-aligned copy
        ld (iy+5),0
        xor a
.four:  ld (lastsh),a
        xor a
.sh:    ld (shiftn),a
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(rowcnt)
        ld b,a
.row:   push bc
        ld a,(hl)
        ld (rowd),a
        inc hl
        ld a,(hl)
        ld (rowd+1),a
        inc hl
        ld a,(hl)
        ld (rowd+3),a
        inc hl
        ld a,(hl)
        ld (rowd+4),a
        inc hl
        xor a
        ld (rowd+2),a
        dec a
        ld (rowd+5),a
        ld a,(shiftn)
        add a,a
        jr z,.ns
        ld b,a
        push hl
.sb:    ld hl,rowd
        or a
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        scf
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        rr (hl)
        djnz .sb
        pop hl
.ns:    push hl
        ld hl,rowd
        ld b,3
.pr:    push bc
        ld a,(hl)               ; data
        inc hl
        inc hl
        inc hl
        ld c,(hl)               ; mask
        dec hl
        dec hl
        push hl
        ld h,RMAP/256
        ld l,a
        ld a,c
        cpl
        and (hl)
        pop hl
        ex de,hl
        ld (hl),c
        inc hl
        ld (hl),a
        inc hl
        ex de,hl
        pop bc
        djnz .pr
        pop hl
        pop bc
        djnz .row
        ld a,(lastsh)
        ld b,a
        ld a,(shiftn)
        cp b
        jr z,.sd
        inc a
        jr .sh
.sd:
        ld bc,4
        add ix,bc
        ld bc,8
        add iy,bc
        pop bc
        dec b
        jp nz,.spr
        ld (sprend),de
        ret

; ---------------------------------------------------------------------
; court_to_bg: unpack this surface's court into BG (recoloured). No queueing.
court_to_bg:
        ld hl,court_std
        ld a,(s_style)
        or a
        jr z,.s
        ld hl,court_classic
.s:     ld de,BGBUF
        call unpack
        ld hl,s_bgmap
        call build_rmap
        ld hl,BGBUF
        ld d,RMAP/256
.r:     ld e,(hl)
        ld a,(de)
        ld (hl),a
        inc hl
        ld a,h
        or a
        jr nz,.r
        ; the crowd's own colours: 0 = the stand (surround), 1-3 = the other three
        ld a,(s_bgmap+2)
        ld (crowdmap),a
        ld c,a
        ld hl,crowdmap+1
        ld b,0
.m:     ld a,b
        cp c
        jr z,.m1
        ld (hl),a
        inc hl
.m1:    inc b
        ld a,b
        cp 4
        jr nz,.m
        ld hl,crowdmap
        call build_rmap
        ld hl,crowd_a
        ld de,crowdbuf_a
        ld bc,CROWD_H*27*2
.c:     push bc
        push de
        ld e,(hl)
        ld d,RMAP/256
        ld a,(de)
        pop de
        ld (de),a
        inc hl
        inc de
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.c
        ld hl,crowd_up_none     ; everyone seated, straight into the backdrop
        call crowd_fill
        jp tex_off

; court_show: full court + panel, revealed with blinds
court_show:
        ld a,(s_latch)
        ld (palbase),a
        call dl_reset
        call do_frame
        call court_to_bg
        ld a,1
        ld (noq),a
        call hud_draw
        xor a
        ld (noq),a
        jp wipe_show

; restore the banner box area from a fresh court copy (keeps HUD)
court_restore:
        call court_to_bg
        ld a,(mode)
        cp MODE_PRACTICE
        call z,stamp_machine
        ld a,1
        ld (noq),a
        call hud_draw
        xor a
        ld (noq),a
        ld de,$0712
        ld bc,$1805
        call queue_rect
        ld de,$0717
        ld bc,$1805
        call queue_rect
        ld de,$071C
        ld bc,$1805
        jp queue_rect

; ---------------------------------------------------------------------
; banner: HL = line 1, DE = line 2 (or 0). Box over the far court.
banner:
        push de
        push hl
        ld a,1
        ld (noq),a
        ld a,(s_bgmap+1)
        call colbyte_a
        ld de,$0712
        ld bc,$180F
        call fill_rect
        ld a,(s_bgmap)
        call colbyte_a
        ld de,$0813
        ld bc,$160D
        call fill_rect
        ld a,(s_bgmap+1)
        ld b,a
        ld a,(s_bgmap)
        ld c,a
        ld a,b
        ld b,c
        call set_ink
        pop hl
        ld e,21
        call print_court_c
        pop hl
        ld a,h
        or l
        jr z,.q
        ld e,27
        call print_court_c
.q:     xor a
        ld (noq),a
        ld de,$0712
        ld bc,$1805
        call queue_rect
        ld de,$0717
        ld bc,$1805
        call queue_rect
        ld de,$071C
        ld bc,$1805
        jp queue_rect

; A = colour 0..3 -> A = full byte of it
colbyte_a:
        push hl
        ld hl,colbyte
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        pop hl
        ret

; print HL centred on the court (centre column 19), row E
print_court_c:
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc b
        inc hl
        jr .l
.d:     ld a,b
        inc a
        srl a
        ld b,a
        ld a,19
        sub b
        ld d,a
        pop hl
        jp print

; ---------------------------------------------------------------------
; scoreboard panel (columns 0-3). The player at the far end is shown at the top.
hud_draw:
        ld a,(noq)
        push af
        ld a,1
        ld (noq),a
        call hud_draw2
        call hud_centre
        call hud_bezel
        pop af
        ld (noq),a
        or a
        ret nz
        ; copy the panel to the screen in four slices
        ld de,$0000
        ld bc,$0510
        call queue_rect
        ld de,$0010
        ld bc,$0510
        call queue_rect
        ld de,$0020
        ld bc,$0510
        call queue_rect
        ld de,$0030
        ld bc,$0510
        jp queue_rect

; hud_centre: the panel is drawn in columns 0-3 (x 0-15); slide it 2 pixels right
; (x 2-17) so it sits centred between the screen border and the divider at x 19,
; and never touches the border colour. RRD shifts a nibble (2 pixels) per byte.
hud_centre:
        ld a,(s_bgmap)
        call colbyte_a
        and $0F
        ld d,a                  ; 2 pixels of panel background to feed in on the left
        ld hl,BGBUF
        ld c,64
.r:     ld a,d
        rrd
        inc hl
        rrd
        inc hl
        rrd
        inc hl
        rrd
        inc hl
        add a,a                 ; last 2 pixels of column 3 -> left half of column 4
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(hl)
        and $0F                 ; keep x 18 and the divider at x 19
        or b
        ld (hl),a
        ld a,l
        add a,28
        ld l,a
        jr nc,.n
        inc h
.n:     dec c
        jr nz,.r
        ret
; hud_bezel: a 1-pixel frame in the court-line colour: left edge at x 0, the
; divider at x 19 is the right edge, lines along rows 0 and 63, and a middle
; line at row 31 between the two players (not in practice, which is one box).
hud_bezel:
        ld a,(s_bgmap+1)
        call colbyte_a
        ld e,a                  ; a full byte of line colour
        and $C0
        ld d,a                  ; just x 0
        ld hl,BGBUF
        ld b,64
.v:     ld a,(hl)
        and $3F
        or d
        ld (hl),a
        ld a,l
        add a,32
        ld l,a
        jr nc,.n
        inc h
.n:     djnz .v
        ld hl,BGBUF
        call .h
        ld hl,BGBUF+63*32
        call .h
        ld a,(mode)
        cp MODE_PRACTICE
        ret z
        ld hl,BGBUF+31*32
.h:     ld b,5                  ; x 0-19 (x 19 is the divider, same colour)
.hb:    ld (hl),e
        inc l
        djnz .hb
        ret
hud_draw2:
        ld a,(s_bgmap)
        call colbyte_a
        ld de,$0000
        ld bc,$0440
        call fill_rect
        ld a,(mode)
        cp MODE_PRACTICE
        jp z,hud_practice
        ; top = player at end 0
        call top_player         ; IX = top, IY = bottom
        push iy
        ld a,0
        call hud_one_top
        pop ix
        jp hud_one_bottom

; IX = player at the far end, IY = near
top_player:
        ld ix,pl0
        ld iy,pl1
        ld a,(ix+P_END)
        or a
        ret z
        ld ix,pl1
        ld iy,pl0
        ret

hud_ink:        ; ink in IX's team colour on the court colour
        ld a,(s_bgmap)
        ld b,a
        ld a,(ix+P_TEAM)
        or a
        ld a,(s_sprmap+2)
        jr z,.a
        ld a,(s_sprmap+3)
.a:     jp set_ink

; Rows are centred inside each half of the bezel (top interior rows 1-30,
; bottom 32-62). With sets shown the block is 28 rows tall, without it 22.
hud_one_top:
        call hud_ink
        ld a,(setsneed)
        cp 2
        jr nc,.sets
        call hud_name_at
        db 5
        ld e,11
        call hud_points
        ld e,22
        jp hud_games
.sets:  call hud_name_at
        db 2
        ld e,8
        call hud_points
        ld e,19
        call hud_games
        ld e,25
        jp hud_sets
hud_one_bottom:
        call hud_ink
        ld a,(setsneed)
        cp 2
        jr nc,.sets
        ld e,36
        call hud_games
        ld e,42
        call hud_points
        call hud_name_at
        db 53
        ret
.sets:  ld e,33
        call hud_sets
        ld e,39
        call hud_games
        ld e,45
        call hud_points
        call hud_name_at
        db 56
        ret

; name + serve marker; the row follows the call as an inline byte
hud_name_at:
        pop hl
        ld e,(hl)
        inc hl
        push hl
        push de
        ld l,(ix+P_NAME)
        ld h,(ix+P_NAME+1)
        ld d,0
        call print
        pop de
        ld hl,s_serve
        ld a,(server)
        cp (ix+P_IDX)
        jr z,.s
        ld hl,s_noserve
.s:     ld d,3
        jp print
s_serve:   db "@",0
s_noserve: db " ",0

hud_points:     ; E = row (big digits)
        push de
        call points_text        ; HL = 2-char string for IX
        pop de
        ld d,0
        jp print2

hud_games:
        push de
        ld hl,s_g
        ld d,0
        call print
        pop de
        ld a,(ix+P_IDX)
        ld hl,games
        call idx_byte
        ld d,2
        jp print_dec2
hud_sets:
        ld a,(setsneed)
        cp 2
        ret c
        push de
        ld hl,s_s
        ld d,0
        call print
        pop de
        ld a,(ix+P_IDX)
        ld hl,sets
        call idx_byte
        ld d,2
        jp print_dec2
s_g: db "G",0
s_s: db "S",0

; A = (HL + A)
idx_byte:
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ret

; points_text: IX = player -> HL = "00"/"15"/"30"/"40"/"AD"/tiebreak count
points_text:
        ld a,(ix+P_IDX)
        ld e,a
        xor 1
        ld hl,pts
        call idx_byte
        ld d,a                  ; opponent's points
        ld a,e
        ld hl,pts
        call idx_byte           ; mine
        ld e,a
        ld a,(tiebreak)
        or a
        jr nz,.tb
        ld a,e
        cp 3
        jr c,.plain
        ld a,d
        cp 3
        jr c,.plain3
        ld a,e
        cp d
        jr z,.forty
        jr c,.forty
        ld hl,s_ad
        ret
.plain3:
.forty: ld hl,s_40
        ret
.plain: ld a,e
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,ptnames
        add hl,de
        ret
.tb:    ld a,e
        ld hl,tbuf
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,tbuf
        ret
ptnames: db "00",0,0,"15",0,0,"30",0,0
s_40:    db "40",0
s_ad:    db "AD",0

hud_practice:
        ld a,(s_sprmap+3)
        ld b,a
        ld a,(s_bgmap)
        ld c,a
        ld a,b
        ld b,c
        call set_ink
        ld hl,s_balls
        ld de,$0006
        call print
        ld a,(pr_balls)
        ld de,$000C
        call print2_dec
        ld hl,s_hits
        ld de,$001A
        call print
        ld a,(pr_hits)
        ld de,$0020
        call print2_dec
        ld hl,s_pts
        ld de,$002E
        call print
        ld hl,pr_score
        ld b,2
        ld de,$0034
        jp print_bcd
s_balls: db "BALL",0
s_hits:  db "HITS",0
s_pts:   db "PTS",0

; big two-digit number A at D/E
print2_dec:
        ld hl,tbuf
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,tbuf
        jp print2

; ---------------------------------------------------------------------
; crowd: 54 little spectators in two staggered tiers, a front and a back one per screen byte.
; Two frames (sitting / jumping with arms up), recoloured per surface into
; crowdbuf_a / crowdbuf_b by court_to_bg.
;   crowd_cheer: everyone bobs up and down (alternate spectators out of step)
;   crowd_wave:  a Mexican wave sweeps across the stand and back
crowd_cheer:    ; A = frames
        ld (crowdtim),a
        xor a
        ld (crowdmode),a
        ret
crowd_wave:     ; A = frames
        ld (crowdtim),a
        ld a,1
        ld (crowdmode),a
        xor a
        ld (crowdph),a
        ret
crowd_tick:
        ld a,(crowdtim)
        or a
        ret z
        dec a
        ld (crowdtim),a
        jr z,crowd_idle         ; finished: everyone sits down
        and 1
        ret nz                  ; animate every other frame
        ld a,(q_head)           ; and only when nothing else is waiting to be copied
        ld b,a
        ld a,(q_tail)
        cp b
        ret nz
        ld hl,crowdph
        inc (hl)
        ld a,(crowdmode)
        or a
        jr nz,.wave
        ; bobbing: spectator c is up when (c + phase/2) is odd
        ld a,(crowdph)
        srl a
        ld (crowdsel),a
        ld hl,crowd_up_bob
        jr crowd_draw
.wave:  ; wave crest moves 1 spectator per step, there and back (0..26..0)
        ld a,(crowdph)
        cp 27
        jr c,.w1
        ld b,a
        ld a,53
        sub b
        jr nc,.w1
        xor a
        ld (crowdph),a
.w1:    ld (crowdsel),a
        ld hl,crowd_up_wave
        jr crowd_draw
crowd_idle:
        ld hl,crowd_up_none
; crowd_draw: HL = test routine (C = spectator 0..26 -> NZ if standing)
crowd_draw:
        call crowd_fill
        ld de,$0500             ; in two slices, no bigger than the old one-row stand,
        ld bc,$1B04             ; so a crowd step never crowds out the vblank budget
        call queue_rect
        ld de,$0504
        ld bc,$1B00+CROWD_H-4
        jp queue_rect
; crowd_fill: the crowd into the backdrop only
crowd_fill:
        ld (crowdfn),hl
        ld de,BGBUF+5
        ld hl,crowdbuf_a
        ld c,0
.col:   push hl
        push de
        call .test
        pop de
        pop hl
        push hl
        jr z,.down
        ld a,CROWD_H*27
        add a,l
        ld l,a
        jr nc,.down
        inc h
.down:  push de
        ld b,CROWD_H
.r:     ld a,(hl)
        ld (de),a
        ld a,27
        add a,l
        ld l,a
        jr nc,.r1
        inc h
.r1:    ld a,32
        add a,e
        ld e,a
        jr nc,.r2
        inc d
.r2:    djnz .r
        pop de
        pop hl
        inc hl
        inc de
        inc c
        ld a,c
        cp 27
        jr nz,.col
        ret
.test:  ld hl,(crowdfn)
        jp (hl)
crowd_up_none:
        xor a
        ret
crowd_up_bob:
        ld a,(crowdsel)
        add a,c
        and 1
        ret
crowd_up_wave:  ; within 2 of the crest
        ld a,(crowdsel)
        sub c
        call abs_a
        cp 3
        ld a,1
        jr c,.y
        xor a
.y:     or a
        ret
crowd_reset:
        xor a
        ld (crowdtim),a
        ret
crowd_settle:   ; make sure everyone is sitting
        ld a,(crowdtim)
        or a
        ret z
        xor a
        ld (crowdtim),a
        jp crowd_idle
