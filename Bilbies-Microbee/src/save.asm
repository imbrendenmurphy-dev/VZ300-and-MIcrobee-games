; =====================================================================
;  SAVE: settings and progress in SAVE.DAT on the game's own disk.
;  build_disk.py puts SAVE.DAT first: directory entry 0, allocation block
;  1 = track 2, side 0, logical sector 8 (Microbee 3:1 skew: sector ID 26).
;  The directory (logical sector 0 of track 2, ID 22) is checked before
;  every write, so a disk without the file (or with it moved) is never
;  written. The WD2793 is driven directly (CP/M is gone); every wait is
;  bounded. Interrupts are off while the controller is busy.
; =====================================================================
FDC_CMD	equ $44
FDC_TRK	equ $45
FDC_SEC	equ $46
FDC_DAT	equ $47
FDC_DRV	equ $48
SVBUF	equ $7A00		; 512 bytes in the WORLD block
SV_TRACK	equ 2
SV_DIRSEC	equ 22
SV_DATSEC	equ 26

; record: "BILBIES!SAVE" (12), version, monitor, levels open, last level,
; sound, music, checksum
SV_VER	equ 12
SV_MONO	equ 13
SV_OPEN	equ 14
SV_LAST	equ 15
SV_SND	equ 16
SV_MUS	equ 17
SV_SUM	equ 18

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
sv_sig:	db "BILBIES!SAVE"

; the directory: entry 0 must be SAVE.DAT with block 1. NZ if not.
sv_dir:	ld a,SV_DIRSEC
	ld (sv_sec),a
	call sv_read
	ret nz
	ld hl,SVBUF
	ld de,sv_name
	ld b,12
.n:	ld a,(de)
	cp (hl)
	ret nz
	inc de
	inc hl
	djnz .n
	ld a,(SVBUF+16)
	cp 1
	ret
sv_sum:	ld hl,SVBUF+SV_VER
	ld b,SV_SUM-SV_VER
	xor a
.b:	add a,(hl)
	rlca
	inc hl
	djnz .b
	ret

; at start-up: settings and progress (defaults if there are none)
load_game:
	ld a,1
	ld (v_unlock),a
	ld (sfx_on),a
	ld (mus_en),a
	xor a
	ld (monomode),a
	MEMV BLK_WORLD
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
.s:	ld a,(de)
	cp (hl)
	jr nz,.x
	inc hl
	inc de
	djnz .s
	ld a,(SVBUF+SV_VER)
	cp 1
	jr nz,.x
	call sv_sum
	ld hl,SVBUF+SV_SUM
	cp (hl)
	jr nz,.x
	ld a,(SVBUF+SV_MONO)
	and 1
	ld (monomode),a
	ld a,(SVBUF+SV_SND)
	and 1
	ld (sfx_on),a
	ld a,(SVBUF+SV_MUS)
	and 1
	ld (mus_en),a
	ld a,(SVBUF+SV_OPEN)
	or a
	jr z,.x
	cp NLEVELS+1
	jr nc,.x
	ld (v_unlock),a
	ld a,(SVBUF+SV_LAST)
	cp NLEVELS
	jr nc,.x
	ld (v_lvl),a
.x:	ei
	ret

; write settings and progress: sv_error 0 ok, 1 disk error / no SAVE.DAT,
; 2 write protected
save_game:
	MEMV BLK_WORLD
	di
	call sv_dir
	jr nz,.bad
	ld hl,SVBUF
	ld b,0
.c:	ld (hl),0
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
	ld a,(monomode)
	ld (SVBUF+SV_MONO),a
	ld a,(v_unlock)
	ld (SVBUF+SV_OPEN),a
	ld a,(v_lvl)
	ld (SVBUF+SV_LAST),a
	ld a,(sfx_on)
	ld (SVBUF+SV_SND),a
	ld a,(mus_en)
	ld (SVBUF+SV_MUS),a
	call sv_sum
	ld (SVBUF+SV_SUM),a
	ld a,SV_DATSEC
	ld (sv_sec),a
	call sv_write
	jr nz,.err
	; read it back and check
	call sv_read
	jr nz,.bad
	call sv_sum
	ld hl,SVBUF+SV_SUM
	cp (hl)
	jr nz,.bad
	xor a
	jr .x
.err:	cp 2
	jr z,.x
.bad:	ld a,1
.x:	ld (sv_error),a
	ei
	ret
