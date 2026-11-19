; ---- the WD2793, driven directly (from the Australian Open Tennis disk code)
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

