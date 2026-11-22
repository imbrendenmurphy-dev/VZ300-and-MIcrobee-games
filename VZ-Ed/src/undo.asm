; ===========================================================================
;  undo.asm (0.7) - undo history and bookmarks
;
;  The history lives in UBUF..UBEND (between the code and the text buffer).
;  Records are stacked upwards; each ends with a 5-byte trailer, so they are
;  read from the top down:
;      [data, len bytes (not for INS)] pos lo, pos hi, len lo, len hi, type
;  type: 1 INS   text typed / pasted at [pos, pos+len)           (no data)
;        2 DEL   text that was at [pos, pos+len), cursor stayed  (data in order)
;        3 BS    text deleted backwards from pos+len             (data reversed)
;        4 OVR   text typed over [pos, pos+len)                  (old characters)
;        bit 7 = JOIN: undo the record below it as part of the same step
;  When there's no room the oldest record is dropped; a single change bigger
;  than the whole history forgets it all.  Typing runs, BS runs, DEL runs and
;  overtyping runs grow their top record instead of adding one, unless the
;  history is sealed (useal: after a paste, block, replace or undo) or a group
;  is being built (ujoin = $80, replace).
;
;  Bookmarks: marks = 9 logical positions ($FFFF = not set), moved by every
;  insert (mk_ins) and delete (mk_del) so they stay on the same text.
; ===========================================================================

un_clr:                     ; a new / loaded text: no history, no marks
        ld hl,UBUF
        ld (utop),hl
        ld hl,marks
        ld b,18
uc_l:   ld (hl),$FF
        inc hl
        djnz uc_l
        xor a
        ld (ujoin),a
        ld (uovr),a
        ret

un_endg: xor a              ; end of a group (replace): sealed
        ld (ujoin),a
un_seal: ld a,1
        ld (useal),a
        ret

un_top:                     ; Z = empty.  Else A = type, DE = pos, BC = len
        ld hl,(utop)
        ld de,UBUF
        xor a
        sbc hl,de
        ret z
        ld hl,(utop)
        dec hl
        ld a,(hl)
        dec hl
        ld b,(hl)
        dec hl
        ld c,(hl)
        dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)
        ret

un_cango:                   ; like un_top, but A = 0 if the top may not grow
        ld a,(useal)
        ld hl,ujoin
        or (hl)
        ld a,0
        ret nz
        jp un_top

un_start:                   ; HL = end of a record -> HL = its start
        dec hl
        ld a,(hl)
        dec hl
        ld b,(hl)
        dec hl
        ld c,(hl)
        dec hl
        dec hl              ; the trailer starts here
        and 7
        dec a
        ret z               ; INS: no data
        or a
        sbc hl,bc
        ret

un_forget:                  ; drop the whole history (marks stay)
        ld hl,UBUF
        ld (utop),hl
        ret

un_drop:                    ; drop the oldest record (the one at UBUF)
        ld hl,(utop)
ud_l:   ld (uend),hl
        call un_start
        ld de,UBUF
        or a
        sbc hl,de
        add hl,de           ; (keeps Z)
        jr nz,ud_l
        ld hl,(utop)
        ld de,(uend)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(uend)
        ld de,UBUF
        ld a,b
        or c
        jr z,ud_e
        ldir
ud_e:   ld (utop),de
        ret

un_push:                    ; A = type, DE = pos, BC = len, HL = the data
        ld (upos),de
        ld (ulen),bc
        ld (usrc),hl
        ld hl,ujoin
        or (hl)
        ld (uty),a
        and 7
        dec a
        ld hl,0
        jr z,up_n           ; INS: no data
        ld h,b
        ld l,c
up_n:   ld (udsz),hl
        ld de,5
        add hl,de
        ex de,hl            ; DE = room needed
        ld hl,UBEND-UBUF
        or a
        sbc hl,de
        jr c,un_forget      ; bigger than the whole history
up_rm:  ld hl,(utop)
        add hl,de
        ld bc,UBEND+1
        or a
        sbc hl,bc
        jr c,up_put
        push de
        call un_drop
        pop de
        jr up_rm
up_put: ld de,(utop)
        ld bc,(udsz)
        ld a,b
        or c
        jr z,up_t
        ld hl,(usrc)
        ldir
up_t:   ex de,hl
        ld de,(upos)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld bc,(ulen)
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld a,(uty)
        ld (hl),a
        inc hl
        ld (utop),hl
        xor a
        ld (useal),a
        ret

un_app:                     ; A = char to add to the top record's data,
        ld hl,(utop)        ; DE = its new pos, BC = its new len
        dec hl
        push af
        ld a,(hl)
        ld (uty),a
        dec hl
        dec hl
        dec hl
        dec hl              ; the old trailer start: the char goes there
        pop af
        ld (hl),a
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld a,(uty)
        ld (hl),a
        inc hl
        ld (utop),hl
        ret

un_room:                    ; Z if the history is full to the last byte
        push de
        ld hl,(utop)
        ld de,UBEND
        or a
        sbc hl,de
        pop de
        ret

; ---- hooks, called by the editing code
un_ic:                      ; ins_char: the char is at gs-1 (keeps BC)
        push bc
        ld hl,(gs)
        dec hl
        ld de,BUFS
        or a
        sbc hl,de
        ld (upos),hl
        ld bc,1
        call mk_ins
        ld a,(uovr)
        or a
        jr nz,uic_o
        call un_cango
        cp 1
        jr nz,uic_n
        ex de,hl            ; top.pos + top.len = here?
        add hl,bc
        ld de,(upos)
        or a
        sbc hl,de
        jr nz,uic_n
        ld hl,(utop)        ; yes: one longer
        dec hl
        dec hl
        dec hl
        inc bc
        ld (hl),c
        inc hl
        ld (hl),b
        jr uic_x
uic_o:  xor a               ; overtyping: the OVR record has it
        ld (uovr),a
        jr uic_x
uic_n:  ld de,(upos)
        ld bc,1
        ld a,1
        call un_push
uic_x:  pop bc
        ret

un_bs:                      ; del_left: HL = gs, the char is at (HL) (keeps HL)
        push hl
        ld de,BUFS
        or a
        sbc hl,de
        ld (upos),hl
        ld bc,1
        call mk_del
        call un_cango
        cp 3
        jr nz,ubs_n
        ld hl,(upos)        ; the last BS left the cursor at top.pos?
        inc hl
        or a
        sbc hl,de
        jr nz,ubs_n
        call un_room
        jr z,ubs_n
        inc bc
        ld de,(upos)
        pop hl
        push hl
        ld a,(hl)
        call un_app
        pop hl
        ret
ubs_n:  pop hl
        push hl
        ld de,(upos)
        ld bc,1
        ld a,3
        call un_push
        pop hl
        ret

un_dl:                      ; del_right (and overtyping): HL = ge, the char at HL-1
        dec hl
        push hl
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        ld (upos),hl
        ld bc,1
        call mk_del
        ld a,(uovr)
        or a
        ld a,2
        jr z,udl_k
        ld a,4
udl_k:  ld (ukind),a
        call un_cango
        ld hl,ukind
        cp (hl)
        jr nz,udl_n
        ld hl,(upos)        ; DEL: same pos.  OVR: top.pos + top.len = here
        cp 4
        jr nz,udl_c
        or a
        sbc hl,bc
udl_c:  or a
        sbc hl,de
        jr nz,udl_n
        call un_room
        jr z,udl_n
        inc bc
        pop hl
        ld a,(hl)
        jp un_app
udl_n:  pop hl
        ld de,(upos)
        ld bc,1
        ld a,(ukind)
        jp un_push

un_pst:                     ; paste: HL = where it went, BC = length (keeps both)
        push hl
        push bc
        ld de,BUFS
        or a
        sbc hl,de
        ld (upos),hl
        call mk_ins
        pop bc
        push bc
        ld de,(upos)
        ld a,1
        call un_push
        call un_seal
        pop bc
        pop hl
        ret

un_blk:                     ; block removed: HL = new gs (the block is still
        push hl             ; there), BC = its length (keeps both)
        push bc
        ld de,BUFS
        or a
        sbc hl,de
        ld (upos),hl
        call mk_del
        pop bc
        pop hl
        push hl
        push bc
        ld de,(upos)
        ld a,2
        call un_push
        call un_seal
        pop bc
        pop hl
        ret

un_rpd:                     ; replace, the match went: HL = new ge, BC = its
        push hl             ; length (keeps both).  Starts / continues a group.
        push bc
        or a
        sbc hl,bc
        push hl
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        ld (upos),hl
        call mk_del
        pop hl
        pop bc
        push bc
        ld de,(upos)
        ld a,2
        call un_push
        ld a,$80
        ld (ujoin),a
        pop bc
        pop hl
        ret

un_rpi:                     ; replace, the new text went in before gs
        ld a,(rbuf)
        or a
        ret z
        ld c,a
        ld b,0
        ld hl,(gs)
        or a
        sbc hl,bc
        ld de,BUFS
        sbc hl,de
        push hl
        push bc
        call mk_ins
        pop bc
        pop de
        ld a,1
        jp un_push

; ---- bookmarks
mk_ins:                     ; HL = pos, BC = n inserted there: marks after it move
        ld (mkp),hl
        ld (mkn),bc
        ld hl,marks
        ld b,9
mi_l:   ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld a,d
        and e
        inc a
        jr z,mi_n
        ld hl,(mkp)
        or a
        sbc hl,de
        jr nc,mi_n          ; mark <= pos: stays
        ld hl,(mkn)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
        push hl
mi_n:   pop hl
        inc hl
        djnz mi_l
        ret

mk_del:                     ; HL = pos, BC = n deleted from there
        ld (mkp),hl
        ld (mkn),bc
        ld hl,marks
        ld b,9
md_l:   ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld a,d
        and e
        inc a
        jr z,md_n
        ld hl,(mkp)
        or a
        sbc hl,de
        jr nc,md_n          ; mark <= pos: stays
        ex de,hl
        ld de,(mkn)
        or a
        sbc hl,de           ; mark - n
        ld de,(mkp)
        jr c,md_p
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,md_s
md_p:   ex de,hl            ; it was inside the deleted text: to pos
md_s:   ex de,hl
        pop hl
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
        push hl
md_n:   pop hl
        inc hl
        djnz md_l
        ret

; ---- CTRL+- : undo
c_undo: xor a
        ld (selon),a
        ld (ujoin),a
        call un_top
        ld hl,m_noundo
        jp z,set_msg
cu_l:   ld (uty),a
        ld (upos),de
        ld (ulen),bc
        ld hl,(utop)
        call un_start
        ld (utop),hl        ; taken off; its data is still at HL
        ld (usrc),hl
        call textlen        ; check it fits the text (it always should)
        ld de,(upos)
        or a
        sbc hl,de
        jp c,cu_bad
        ld a,(uty)
        and 7
        cp 2
        jr z,cu_room
        cp 3
        jr z,cu_room
        ld de,(ulen)        ; INS / OVR: pos + len <= length
        or a
        sbc hl,de
        jp c,cu_bad
        dec a
        jp z,cu_ins
        ld hl,(upos)        ; OVR: the old characters back over the new
        call gap_to
        ld hl,(usrc)
        ld de,(ge)
        ld bc,(ulen)
        ldir
        jp cu_nx
cu_room: ld hl,(ge)         ; DEL / BS: the gap must have room
        ld de,(gs)
        or a
        sbc hl,de
        ld de,(ulen)
        sbc hl,de
        jp c,cu_bad
        cp 3
        jr z,cu_bs
        ld hl,(upos)        ; DEL: back after the cursor
        call gap_to
        ld bc,(ulen)
        ld hl,(ge)
        or a
        sbc hl,bc
        ld (ge),hl
        ex de,hl
        ld hl,(usrc)
        ldir
        jr cu_mk
cu_bs:  ld hl,(upos)        ; BS: back before the cursor, reversed
        call gap_to
        ld hl,(usrc)
        ld bc,(ulen)
        add hl,bc
        ld de,(gs)
        push de
cb_l:   dec hl
        ld a,(hl)
        ld (de),a
        inc de
        dec bc
        ld a,b
        or c
        jr nz,cb_l
        ld (gs),de
        pop hl
        ld bc,(ulen)
        call count_lf
        ld hl,(curln)
        add hl,de
        ld (curln),hl
cu_mk:  ld hl,(upos)
        ld bc,(ulen)
        call mk_ins
        jr cu_nx
cu_ins: ld hl,(upos)        ; INS: take it out again
        ld bc,(ulen)
        add hl,bc
        call gap_to
        ld bc,(ulen)
        ld hl,(gs)
        or a
        sbc hl,bc
        push hl
        call count_lf
        ld hl,(curln)
        or a
        sbc hl,de
        ld (curln),hl
        pop hl
        ld (gs),hl
        ld hl,(upos)
        ld bc,(ulen)
        call mk_del
cu_nx:  ld a,(uty)
        rla                 ; joined to the one below?
        jr nc,cu_end
        call un_top
        jp nz,cu_l
cu_end: ld a,1
        ld (modified),a
        ld (useal),a
        ld hl,m_undone
        call set_msg
        jp reset_goal
cu_bad: call un_forget      ; doesn't fit the text: never guess
        ld hl,m_noundo
        jp set_msg

; (messages here: the tail is full)
m_noundo: db "NOTHING TO UNDO",0
m_undone: db "UNDONE",0
