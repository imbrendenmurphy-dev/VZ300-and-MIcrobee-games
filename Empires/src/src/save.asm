; ===================================================================
;  save.asm - saving and loading a world (SAVE1-3.EMP)
;
;  The engine packs a 128-byte header, the game state and the map (RLE)
;  into staging blocks 21-24, then hands CP/M back the machine for a
;  moment: the loader's resident code writes the file with BDOS, then
;  restores the engine, which carries on from svc_resume.
;  Loading reads the file into the staging blocks and checks signature
;  and checksum before anything in the current world is touched.
; ===================================================================
BLK_SAVE  equ 21
SVC_DISK  equ 0106h
D_CMD     equ 010Bh             ; parameters in the loader (CP/M's block)
D_NAME    equ 010Ch
D_LEN     equ 0117h
D_RES     equ 011Ah
RLE_ESC   equ 0FEh

; ---- call a loader disk job: A = command, name in sv_name ----
disk_job:
        push af
        ld a,(p_cpm_block)
        call with_block
        pop af
        ld (D_CMD),a
        ld hl,sv_name
        ld de,D_NAME
        ld bc,11
        ldir
        ld hl,(st_total)
        ld (D_LEN),hl
        ld a,(st_total+2)
        ld (D_LEN+2),a
        call map_home
        ; swap: engine -> BLK_GAME, CP/M back, jump to the loader
        di
        ld (svc_sp),sp
        ld a,(lowport)
        or 8                    ; video window off: F000-FFFF is RAM
        out (P_MEM),a
        ld hl,svc_stub
        ld de,0F000h
        ld bc,svc_stub_end-svc_stub
        ldir
        ld a,(p_cpm_port)
        ld (0F000h+svc_cpm-svc_stub),a
        jp 0F000h
svc_stub:                       ; runs at F000h
        ld a,BLK_GAME
        call blk_port
        or 8
        out (P_MEM),a
        ld hl,8000h
        ld de,0
        ld bc,7000h
        ldir                    ; engine (with its stack) -> BLK_GAME
        ld a,BLK_CPM
        call blk_port
        or 8
        out (P_MEM),a
        ld hl,0
        ld de,8000h
        ld bc,7000h
        ldir                    ; CP/M's memory back
        db 3Eh
svc_cpm: db 0
        or 8
        out (P_MEM),a
        jp SVC_DISK
svc_stub_end:

; the loader comes back here (8006h) with the engine restored
svc_resume:
        ld sp,(svc_sp)
        call map_home           ; video window on, map band back
        ld a,(8005h)            ; result from the loader
        ld (sv_res),a
        ret

; ---- staging stream ----
st_begin:
        ld a,BLK_SAVE
        ld (st_blk),a
        ld hl,128               ; header goes in last
        ld (st_off),hl
        xor a
        ld (st_n),a
        ld (st_total+2),a
        ld hl,128
        ld (st_total),hl
        ld hl,0
        ld (st_sum),hl
        ret
st_put:                         ; A = byte
        push hl
        push de
        push bc
        ld c,a
        ld e,a
        ld d,0
        ld hl,(st_sum)
        add hl,de
        ld (st_sum),hl
        ld hl,(st_total)
        inc hl
        ld (st_total),hl
        ld a,h
        or l
        jr nz,.t
        ld hl,st_total+2
        inc (hl)
.t:     ld a,(st_n)
        ld l,a
        ld h,0
        ld de,st_buf
        add hl,de
        ld (hl),c
        inc a
        ld (st_n),a
        call z,st_flush
        pop bc
        pop de
        pop hl
        ret
st_flush:                       ; write st_buf (st_n bytes, 0 = 256) to the staging blocks
        push bc
        push de
        push hl
        ld a,(st_blk)
        cp BLK_SAVE+4
        jr nc,.full
        call with_block
        ld a,(st_n)
        ld c,a
        ld b,0
        or a
        jr nz,.n
        inc b
.n:     ld hl,st_buf
        ld de,(st_off)
        push bc
        ldir
        pop bc
        ld hl,(st_off)
        add hl,bc
        bit 7,h
        jr z,.s
        ld hl,0
        ld a,(st_blk)
        inc a
        ld (st_blk),a
.s:     ld (st_off),hl
        call map_home
.full:  xor a
        ld (st_n),a
        pop hl
        pop de
        pop bc
        ret

; reading back: st_get -> A (and adds to the checksum)
st_rbegin:
        ld a,BLK_SAVE
        ld (st_blk),a
        ld hl,128
        ld (st_off),hl
        ld hl,0
        ld (st_sum),hl
        xor a
        ld (st_n),a             ; buffer empty
        ld (st_rp),a
        ret
st_get: push hl
        push de
        push bc
        ld a,(st_n)
        or a
        jr nz,.have
        ; refill 256 bytes
        ld a,(st_blk)
        call with_block
        ld hl,(st_off)
        ld de,st_buf
        ld bc,256
        ldir
        call map_home
        ld hl,(st_off)
        inc h
        bit 7,h
        jr z,.s
        ld hl,0
        ld a,(st_blk)
        inc a
        ld (st_blk),a
.s:     ld (st_off),hl
        xor a
        ld (st_rp),a
        dec a
        ld (st_n),a             ; 255 left after this one
        jr .take
.have:  dec a
        ld (st_n),a
.take:  ld a,(st_rp)
        ld l,a
        inc a
        ld (st_rp),a
        ld h,0
        ld de,st_buf
        add hl,de
        ld a,(hl)
        ld e,a
        ld d,0
        ld hl,(st_sum)
        add hl,de
        ld (st_sum),hl
        ld a,e
        pop bc
        pop de
        pop hl
        ret

; ---- RLE: runs of 4+ (or any ESC) become ESC, count, value ----
rle_put:                        ; A = byte
        ld hl,rle_val
        cp (hl)
        jr nz,.new
        ld a,(rle_len)
        cp 255
        jr z,.new2
        inc a
        ld (rle_len),a
        ret
.new2:  ld a,(rle_val)
.new:   push af
        call rle_flush
        pop af
        ld (rle_val),a
        ld a,1
        ld (rle_len),a
        ret
rle_flush:
        ld a,(rle_len)
        or a
        ret z
        cp 4
        jr nc,.run
        ld a,(rle_val)
        cp RLE_ESC
        jr z,.run
        ld a,(rle_len)
        ld b,a
.lit:   ld a,(rle_val)
        call st_put
        djnz .lit
        jr .z
.run:   ld a,RLE_ESC
        call st_put
        ld a,(rle_len)
        call st_put
        ld a,(rle_val)
        call st_put
.z:     xor a
        ld (rle_len),a
        ret
rle_get:                        ; -> A, next decoded byte
        ld a,(rle_len)
        or a
        jr z,.next
        dec a
        ld (rle_len),a
        ld a,(rle_val)
        ret
.next:  call st_get
        cp RLE_ESC
        ret nz
        call st_get
        dec a
        ld (rle_len),a          ; count-1 still to come after this one
        call st_get
        ld (rle_val),a
        ret

; ---- build the save in the staging blocks ----
save_build:
        call st_begin
        ; game state
        ld hl,sv_start
        ld bc,sv_end-sv_start
.s:     ld a,(hl)
        call st_put
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.s
        ; map: per row, terrain then objects, RLE
        xor a
        ld (rle_len),a
        ld (rle_val),a
        ld b,0
.y:     push bc
        ld c,0
        call tile_addr          ; maps the band; HL = row start
        ld de,rowbuf
        ld a,(mapwm1)
        ld c,a
        ld b,0
        inc bc
        push bc
        push hl
        ldir                    ; terrain row
        pop hl
        set 6,h
        pop bc
        push bc
        ldir                    ; object row
        pop bc
        ld hl,rowbuf
        sla c
        rl b                    ; 2 * width bytes
.e:     push bc
        push hl
        ld a,(hl)
        call rle_put
        pop hl
        pop bc
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.e
        pop bc
        inc b
        ld a,(maphm1)
        inc a
        sub b
        jr nz,.y
        call rle_flush
        ld a,(st_n)
        or a
        call nz,st_flush
        ; header
        ld hl,sv_hdr
        ld de,sv_hdr+1
        ld bc,127
        ld (hl),0
        ldir
        ld hl,sv_sig
        ld de,sv_hdr
        ld bc,16
        ldir
        ld a,1
        ld (sv_hdr+16),a
        ld a,(worldsize)
        ld (sv_hdr+17),a
        ld a,(worldtype)
        ld (sv_hdr+18),a
        ld a,(season)
        ld (sv_hdr+19),a
        ld hl,(year)
        ld (sv_hdr+20),hl
        ld hl,(pop)
        ld (sv_hdr+22),hl
        ld hl,sv_end-sv_start
        ld (sv_hdr+24),hl
        ld hl,(st_total)
        ld (sv_hdr+26),hl
        ld a,(st_total+2)
        ld (sv_hdr+28),a
        ld hl,(st_sum)
        ld (sv_hdr+29),hl
        ld a,BLK_SAVE
        call with_block
        ld hl,sv_hdr
        ld de,0
        ld bc,128
        ldir
        jp map_home

sv_sig: db "EMPIRES SAVE 01",0

; slot name: A = slot 1..3
sv_setname:
        add a,'0'
        ld hl,sv_namet
        ld de,sv_name
        ld bc,11
        push af
        ldir
        pop af
        ld (sv_name+4),a
        ret
sv_namet: db "SAVE1   EMP"

; ---- save to slot A (1..3) -> A = result (0 ok) ----
save_game:
        push af
        call save_build
        pop af
        call sv_setname
        ld a,1
        call disk_job
        ld a,(sv_res)
        ret

; ---- read the three slot headers into sv_heads (3 x 32 bytes) ----
read_heads:
        ld a,1
        call sv_setname
        xor a
        ld (st_total),a
        ld (st_total+1),a
        ld (st_total+2),a
        ld a,3
        call disk_job
        ld a,BLK_SAVE
        call with_block
        ld hl,0
        ld de,sv_heads
        ld bc,32
        ldir
        ld hl,128
        ld bc,32
        ldir
        ld hl,256
        ld bc,32
        ldir
        jp map_home

; ---- load slot A -> A = 0 ok, else error code (5 = damaged or not a save) ----
load_game:
        call sv_setname
        ld a,2
        call disk_job
        ld a,(sv_res)
        or a
        ret nz
        ; header check
        ld a,BLK_SAVE
        call with_block
        ld hl,0
        ld de,sv_hdr
        ld bc,128
        ldir
        call map_home
        ld hl,sv_hdr
        ld de,sv_sig
        ld b,16
.c:     ld a,(de)
        cp (hl)
        jr nz,.bad
        inc hl
        inc de
        djnz .c
        ld hl,(sv_hdr+24)
        ld de,sv_end-sv_start
        or a
        sbc hl,de
        jr nz,.bad
        ; checksum over everything after the header
        call st_rbegin
        ld hl,(sv_hdr+26)
        ld a,(sv_hdr+28)
        ld de,-128
        add hl,de
        ccf                     ; carry from the add means no borrow
        sbc a,0
        ld (sv_cnt),hl
        ld (sv_cnt+2),a
.sum:   ld hl,(sv_cnt)
        ld a,(sv_cnt+2)
        or h
        or l
        jr z,.sumd
        call st_get
        ld hl,(sv_cnt)
        ld a,h
        or l
        dec hl
        ld (sv_cnt),hl
        jr nz,.sum
        ld hl,sv_cnt+2
        dec (hl)
        jr .sum
.sumd:  ld hl,(st_sum)
        ld de,(sv_hdr+29)
        or a
        sbc hl,de
        jr nz,.bad
        ; good: restore the state, then the map
        call st_rbegin
        ld hl,sv_start
        ld bc,sv_end-sv_start
.st:    call st_get
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.st
        call set_world_size
        call map_clear
        xor a
        ld (rle_len),a
        ld b,0
.y:     push bc
        ld a,(mapwm1)
        ld c,a
        ld b,0
        inc bc
        sla c
        rl b
        ld hl,rowbuf
.d:     push hl
        push bc
        call rle_get
        pop bc
        pop hl
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.d
        pop bc
        push bc
        ld c,0
        call tile_addr
        ex de,hl                ; DE = terrain row
        ld a,(mapwm1)
        ld c,a
        ld b,0
        inc bc
        ld hl,rowbuf
        push bc
        push de
        ldir
        pop de
        set 6,d
        pop bc
        ldir                    ; object row
        pop bc
        inc b
        ld a,(maphm1)
        inc a
        sub b
        jr nz,.y
        xor a
        ret
.bad:   ld a,5
        ret
