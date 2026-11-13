; =====================================================================
;  SAVE: settings, the Hall of Fame and the Summer Tour in SAVE.DAT on
;  the game's own disk (from BILBIES! for the Microbee).
;  build_disk.py puts SAVE.DAT first: directory entry 0, allocation block
;  1 = track 2, side 0, logical sector 8 (Microbee 3:1 skew: sector ID 26).
;  The directory (logical sector 0 of track 2, ID 22) is checked before
;  every write, so a disk without the file (or with it moved) is never
;  written. The WD2793 is driven directly; every wait is bounded.
; =====================================================================
SVBUF   equ $3800               ; 512 bytes in the RT block
FDC_CMD	equ $44
FDC_TRK	equ $45
FDC_SEC	equ $46
FDC_DAT	equ $47
FDC_DRV	equ $48

SV_TRACK	equ 2
SV_DIRSEC	equ 22
SV_DATSEC	equ 26


sv_cmd:	out (FDC_CMD),a
	ld a,16
.d:	dec a
	jr nz,.d
	ret
; wait while busy: A = status, Z clear on timeout ($FF)
sv_wait:
	ld de,0
.w:	in a,(FDC_CMD)
	bit 0,a
	ret z
	dec de
	ld a,d
	or e
	jr nz,.w
	ld a,$D0
	out (FDC_CMD),a
	ld a,$FF
	ret
sv_drq:	ld de,0
.w:	in a,(FDC_CMD)
	bit 1,a
	jr nz,.ok
	bit 0,a
	jr z,.err
	dec de
	ld a,d
	or e
	jr nz,.w
.err:	ld (sv_st),a		; (keep the write-protect bit)
	ld a,$D0
	out (FDC_CMD),a
	scf
	ret
.ok:	or a
	ret
; drive 0, double density; to track 2; sector (sv_sec): NZ on failure
sv_locate:
	ld a,8			; drive 0, side 0, double density
	out (FDC_DRV),a
	ld a,$0B		; restore
	call sv_cmd
	call sv_wait
	cp $FF
	ret z
	ld a,SV_TRACK
	out (FDC_DAT),a
	ld a,$1C		; seek, verify
	call sv_cmd
	call sv_wait
	cp $FF
	ret z
	and $18			; seek error / CRC
	ret nz
	ld bc,8000
.s:	dec bc
	ld a,b
	or c
	jr nz,.s
	ld a,(sv_sec)
	out (FDC_SEC),a
	xor a
	ret
; read sector (sv_sec) of track 2 into SVBUF: NZ on failure
sv_read:
	call sv_locate
	ret nz
	ld a,$88
	call sv_cmd
	ld hl,SVBUF
	ld bc,512
.b:	call sv_drq
	jr c,sv_fail
	in a,(FDC_DAT)
	ld (hl),a
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.b
	call sv_wait
	and $9C
	ret
sv_write:
	call sv_locate
	ret nz
	ld a,$A8
	call sv_cmd
	ld hl,SVBUF
	ld bc,512
.b:	call sv_drq
	jr c,sv_wfail
	ld a,(hl)
	out (FDC_DAT),a
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.b
	call sv_wait
	bit 6,a
	jr nz,sv_wp
	and $FC
	ret
sv_wp:	ld a,2
	or a
	ret
sv_wfail:
	ld a,(sv_st)
	bit 6,a			; write protected
	ld a,2
	ret nz
sv_fail:
	ld a,1
	or a
	ret

sv_name:	db 0,"SAVE    DAT"

; the directory: entry 0 must be SAVE.DAT with block 1. NZ if not.
sv_dir: ld a,SV_DIRSEC
        ld (sv_sec),a
        call sv_read
        ret nz
        ld hl,SVBUF
        ld de,sv_name
        ld b,12
.n:     ld a,(de)
        cp (hl)
        ret nz
        inc de
        inc hl
        djnz .n
        ld a,(SVBUF+16)
        cp 1
        ret

; the record
SV_VER  equ 12
SV_DATA equ 13
SV_LEN  equ sv_end-sv_first
sv_sig: db "AOTENNIS-SAV"
sv_sum: ld hl,SVBUF+SV_VER
        ld b,SV_LEN+1
        xor a
.b:     add a,(hl)
        rlca
        inc hl
        djnz .b
        ret

; at start-up: settings, records and the tour (defaults if there are none)
load_game:
        ld hl,hitab_init
        ld de,hitab
        ld bc,30
        ldir
        ld a,2
        ld (soundmode),a
        ld a,4
        ld (gamesper_d),a
        ld a,BLK_RT
        call map_blk
        di
        call sv_dir
        jr nz,.x
        ld a,SV_DATSEC
        ld (sv_sec),a
        call sv_read
        jr nz,.x
        ld hl,SVBUF
        ld de,sv_sig
        ld b,12
.s:     ld a,(de)
        cp (hl)
        jr nz,.x
        inc hl
        inc de
        djnz .s
        ld a,(SVBUF+SV_VER)
        cp 1
        jr nz,.x
        call sv_sum
        ld hl,SVBUF+SV_DATA+SV_LEN
        cp (hl)
        jr nz,.x
        ld hl,SVBUF+SV_DATA
        ld de,sv_first
        ld bc,SV_LEN
        ldir
        ; sanity
        ld a,(monomode)
        and 1
        ld (monomode),a
        ld a,(soundmode)
        cp 3
        jr c,.k1
        ld a,2
        ld (soundmode),a
.k1:    ld a,(tour_t)
        cp 4
        jr c,.k2
        xor a
        ld (tour_saved),a
.k2:
.x:     ret

; write everything: sv_error 0 ok, 1 disk error / no SAVE.DAT, 2 write protected
save_game:
        ld a,BLK_RT
        call map_blk
        di
        call sv_dir
        jr nz,.bad
        ld hl,SVBUF
        ld b,0
.c:     ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        djnz .c
        ld hl,sv_sig
        ld de,SVBUF
        ld bc,12
        ldir
        ld a,1
        ld (SVBUF+SV_VER),a
        ld hl,sv_first
        ld de,SVBUF+SV_DATA
        ld bc,SV_LEN
        ldir
        call sv_sum
        ld (SVBUF+SV_DATA+SV_LEN),a
        ld a,SV_DATSEC
        ld (sv_sec),a
        call sv_write
        jr nz,.err
        call sv_read
        jr nz,.bad
        call sv_sum
        ld hl,SVBUF+SV_DATA+SV_LEN
        cp (hl)
        jr nz,.bad
        xor a
        jr .x
.err:   cp 2
        jr z,.x
.bad:   ld a,1
.x:     ld (sv_error),a
        ret

hitab_init:
        db $03,$00,$00,"BPM"
        db $02,$00,$00,"MBE"
        db $01,$00,$00,"ACE"
        db $00,$50,$00,"LOB"
        db $00,$25,$00,"NET"
