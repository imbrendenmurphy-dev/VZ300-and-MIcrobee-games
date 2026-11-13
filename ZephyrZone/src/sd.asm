; =====================================================================
;  sd.asm - load a .DAT file through the BennVenn DOS (13 Ghosts / DC2
;  protocol, proven on the user's VZ300):
;    (FB80) = sector buffer, HL -> '"NAME"', A = 1, CALL $5F00  open
;    (FB03) must be 1 and (FB05) must not be 1
;    A = 1, CALL $5F03  first 512-byte sector ; then (FB80)=buf, CALL $5F09
;  DOS mapping only during DOS calls, interrupts off and IM 1, a 3K stack
;  in upper bank 0 ($EC00-$F7FF), DI after every call.
;  File format: chunks  db map ; dw dest ; dw length ; data   (map 0 = end)
;  Each sector goes SECBUF -> BB (bounce, main RAM) -> its chunk's mapping.
; =====================================================================
DOS_OPEN    equ $5F00
DOS_FIRST   equ $5F03
DOS_NEXT    equ $5F09
DOS_BUFPTR  equ $FB80
DOS_STAT1   equ $FB03
DOS_STAT2   equ $FB05

; sd_load: HL = '"NAME"',0 . Returns NC = ok, C = could not open.
sd_load:
            push hl
            call bb_wait            ; (the bounce buffer is the back buffer)
            pop hl
            di
            ld (sd_name),hl
            ld hl,0
            ld (dat_id),hl          ; every file carries the build's id
            ld a,(cur_map)          ; (kept in main RAM: the DOS stack sits in
            ld (sd_map),a           ; upper bank 0, which may not be mapped yet)
            ld a,(dos_map)
            out (BANKPORT),a
            ld (sd_savesp),sp
            ld sp,DOS_SP
            im 1
            ld a,3
            ld (sd_try),a
.open:      ld a,(dos_map)
            out (BANKPORT),a
            ld hl,SECBUF
            ld (DOS_BUFPTR),hl
            ld hl,(sd_name)
            ld a,1
            call DOS_OPEN
            di
            ld a,(DOS_STAT1)
            cp 1
            jr nz,.retry
            ld a,(DOS_STAT2)
            cp 1
            jr nz,.opened
.retry:     ld hl,sd_try
            dec (hl)
            jr nz,.open
            ld a,(sd_map)
            call .restore
            scf
            ret
.opened:    ld a,1
            call DOS_FIRST
            di
            call sd_bounce
            ; ---- chunks
.chunk:     call sd_getb
            or a
            jr z,.done
            ld (sd_cmap),a
            call sd_getb
            ld (sd_dst),a
            call sd_getb
            ld (sd_dst+1),a
            call sd_getb
            ld (sd_len),a
            call sd_getb
            ld (sd_len+1),a
.data:      ld hl,(sd_len)
            ld a,h
            or l
            jr z,.chunk
            ld a,(sd_left)
            or a
            jr nz,.have
            ld a,(sd_left+1)
            or a
            jr nz,.have
            call sd_next
.have:      ; n = min(len, left)
            ld hl,(sd_len)
            ld de,(sd_left)
            or a
            sbc hl,de
            jr c,.uselen
            ld b,d
            ld c,e
            jr .cp
.uselen:    ld bc,(sd_len)
.cp:        ; copy BC bytes from (sd_rd) to (sd_dst) under the chunk mapping
            push bc
            ld hl,(sd_len)
            or a
            sbc hl,bc
            ld (sd_len),hl
            ld hl,(sd_left)
            or a
            sbc hl,bc
            ld (sd_left),hl
            ld hl,(sd_rd)
            ld de,(sd_dst)
            ld a,(sd_cmap)
            out (BANKPORT),a
            ldir
            ld a,(dos_map)
            out (BANKPORT),a
            ld (sd_rd),hl
            ld (sd_dst),de
            pop bc
            jr .data
.done:      ld a,(sd_map)
            call .restore
            ld hl,(dat_id)          ; from the same build as ZEPHYR.VZ?
            ld de,BUILD_ID
            or a
            sbc hl,de
            ret z                   ; (NC: loaded)
            ld hl,str_ver
            jp fatal
.restore:   ld hl,(sd_savesp)
            pop de                  ; our return address (on the DOS stack: take it
            ld sp,hl                ; before the mapping changes under it)
            push de
            ld (cur_map),a
            out (BANKPORT),a
            im 2
            ret

; next byte of the file -> A
sd_getb:
            ld a,(sd_left)
            ld l,a
            ld a,(sd_left+1)
            or l
            call z,sd_next
            ld hl,(sd_left)
            dec hl
            ld (sd_left),hl
            ld hl,(sd_rd)
            ld a,(hl)
            inc hl
            ld (sd_rd),hl
            ret

; read the next sector and bounce it
sd_next:
            ld hl,SECBUF
            ld (DOS_BUFPTR),hl
            call DOS_NEXT
            di
; copy the sector buffer to the bounce buffer (main RAM)
sd_bounce:
            ld hl,SECBUF
            ld de,BB
            ld bc,512
            ldir
            ld hl,BB
            ld (sd_rd),hl
            ld hl,512
            ld (sd_left),hl
            ret
