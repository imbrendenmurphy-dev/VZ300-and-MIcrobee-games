; All data files are preloaded by DRACULA.COM into expanded RAM.
; Entry: length (word), physical block (byte), offset (word).
; Copy through an upper-memory buffer: the destination can be in work RAM.
sd_load:
            push ix
            ld (sd_dst),de
            ld l,(ix+0)
            ld h,(ix+1)
            ld (sd_left),hl
            ld a,(ix+2)
            ld (mb_filebank),a
            ld l,(ix+3)
            ld h,(ix+4)
            ld (mb_filesrc),hl
.chunk:     ld hl,(sd_left)
            ld bc,128
            ld a,h
            or a
            jr nz,.full
            ld a,l
            cp 128
            jr nc,.full
            ld c,a
.full:      push bc
            push bc
            ld a,(mb_filebank)
            call mb_bank
            ld hl,(mb_filesrc)
            ld de,SECBUF
            ldir
            ld (mb_filesrc),hl
            ld a,1
            call mb_bank
            pop bc
            ld hl,SECBUF
            ld de,(sd_dst)
            ldir
            ld (sd_dst),de
            pop bc
            ld hl,(sd_left)
            or a
            sbc hl,bc
            ld (sd_left),hl
            ld a,h
            or l
            jr nz,.chunk
            pop ix
            ret
