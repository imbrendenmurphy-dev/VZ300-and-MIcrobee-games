; test harness: a court and two sprites moving (tools/run.py preloads blocks)
start:
        ld hl,0
        ld (lp_first),hl
        ld a,BLK_UNP
        ld hl,0
        call load_picture
        ld a,BLK_RT
        call map_blk
.loop:  call frame_begin
        ld hl,(t_x)
        inc hl
        inc hl
        inc hl
        ld (t_x),hl
        ld a,h
        cp 2
        jr c,.k
        ld hl,0
        ld (t_x),hl
.k:     ld (spr_x),hl
        ld hl,200
        ld (spr_y),hl
        ld a,WHITE
        ld (spr_ink),a
        ld a,(t_f)
        call spr_draw
        ld hl,(t_x)
        ex de,hl
        ld hl,512
        or a
        sbc hl,de
        ld (spr_x),hl
        ld hl,(t_x)
        srl h
        rr l
        srl h
        rr l
        ld de,40
        add hl,de
        ld (spr_y),hl
        ld a,YELLOW
        ld (spr_ink),a
        ld a,(t_f)
        inc a
        call spr_draw
        call frame_end
        jr .loop
