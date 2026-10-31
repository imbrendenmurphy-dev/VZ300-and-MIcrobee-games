; =====================================================================
;  speech.asm : 1-bit sampled speech streamed from DEPTHS.DAT
;
;  No extra RAM bank is used (port $37 stays 1 / 3 only: on this BennVenn
;  card bit 2 is not a separate bank). Each phrase is read from the SD
;  card one 512-byte sector at a time into SPBUF and played straight
;  away (15.5 kHz, one bit per ~228 T), with the same DOS calls the
;  chapter loader uses. The DOS bank is mapped (port $37 = 1) while
;  reading, and $FA00-$FFFF is left to the DOS.
; =====================================================================
SPBUF   EQU LVBUF-512
sp_left: dw 0

; A = phrase number: say it (music pauses). Silent if the file is missing.
speech_say:
        ld c,a
        ld a,(bank_cur)
        push af
        call bank0
        ld a,c
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,SPTAB
        add hl,de
        ld b,(hl)               ; start sector
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sp_left),de
        push bc
        ld hl,SPBUF
        ld (DOSDEST),hl
        ld hl,datname
        ld a,1
        call DOSOPEN
        di
        pop bc
        ld a,($FB03)
        cp 1
        jr nz,.done
        ld a,($FB05)
        cp 1
        jr z,.done
        ld hl,0
        ld (sd_count),hl
        ld a,b
        or a
        jr z,.go
.skip:  push bc
        ld hl,SPBUF
        call sd_sector_q
        pop bc
        djnz .skip
.go:    ld hl,SPBUF
        call sd_sector_q
        ld de,(sp_left)
        ld hl,512
        or a
        sbc hl,de
        jr c,.full
        ld (sp_left),hl         ; (any value: last chunk)
        ld hl,0
        ld (sp_left),hl
        jr .play
.full:  ex de,hl
        ld de,512
        or a
        sbc hl,de
        ld (sp_left),hl
.play:  ; DE = bytes in this chunk
        ld hl,SPBUF
        ld a,(lbase)
        ld c,a
        call sp_play
        ld hl,(sp_left)
        ld a,h
        or l
        jr nz,.go
.done:  ld a,(lbase)
        ld (LATCH),a
        pop af
        jp bank_set

; read the next sector quietly (no border flashes)
sd_sector_q:
        ld (DOSDEST),hl
        ld hl,(sd_count)
        ld a,h
        or l
        jr nz,.n
        ld a,1
        call DOSSEL
        jr .d
.n:     call DOSNEXT
.d:     di
        ld hl,(sd_count)
        inc hl
        ld (sd_count),hl
        ret

; play HL = bits, DE = bytes, C = latch base  (~228 T per bit)
sp_play:
.byte:  ld b,(hl)
        inc hl
        scf
        rl b                    ; bit 7 -> carry, sentinel into bit 0
.bit:   sbc a,a                 ; 4
        and $21                 ; 7
        xor c                   ; 4
        ld (LATCH),a            ; 13
        ld a,10                 ; 7
.d:     dec a                   ; 4
        jr nz,.d                ; 12/7
        ld r,a                  ; 9
        nop                     ; 4
        sla b                   ; 8
        jr nz,.bit              ; 12    -> 227
        dec de
        ld a,d
        or e
        jr nz,.byte
        ret
