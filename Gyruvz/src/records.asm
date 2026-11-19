; ---------------------------------------------------------------------
; records: high scores, skill and sound kept in the BennVenn SRAM's second
; bank, so they last through a reload while the machine stays on.  Same
; bank probe as DUEL II and ROBOGEDDON, at an address of its own.
; save_records goes back to (home_bank) afterwards: 1 in the game, 3 in the
; front end (which lives in bank 3).
; ---------------------------------------------------------------------
SAVEADR equ $67A0                   ; (bank 3, above the front end; below the probe byte)
REC_LEN equ 4+64+2

; (called once at start-up, with the interrupt off; it leaves it off)
load_records:
        xor     a
        ld      (srok),a
        di
        ld      a,1
        out     ($37),a
        ld      a,($67FF)
        ld      (probe1),a
        ld      a,3
        out     ($37),a
        ld      a,($67FF)
        ld      (probe3),a
        ld      a,(probe1)
        cpl
        ld      ($67FF),a
        ld      a,1
        out     ($37),a
        ld      a,($67FF)
        ld      b,a
        ld      a,(probe1)
        cp      b
        jr      nz,.restore         ; bank 1 changed: no banking here, undo
        ld      a,3
        out     ($37),a
        ld      a,($67FF)
        ld      b,a
        ld      a,(probe1)
        cpl
        cp      b
        jr      nz,.nosram
        ld      a,(probe3)
        ld      ($67FF),a
        ld      a,1
        ld      (srok),a
        ld      hl,SAVEADR
        ld      de,recbuf
        ld      bc,REC_LEN+1
        ldir
        ld      a,1
        out     ($37),a
        ld      hl,recbuf
        ld      de,rec_sig
        ld      b,4
.sg:    ld      a,(de)
        cp      (hl)
        ret     nz
        inc     hl
        inc     de
        djnz    .sg
        call    rec_sum
        ld      hl,recbuf+REC_LEN
        cp      (hl)
        ret     nz
        ld      hl,recbuf+4
        ld      de,HISC
        ld      bc,64
        ldir
        ld      a,(hl)
        cp      3
        jr      nc,.s
        ld      (skill),a
.s:     inc     hl
        ld      a,(hl)
        cp      3
        ret     nc
        ld      (snd_mode),a
        ret
.restore:
        ld      a,(probe1)
        ld      ($67FF),a
.nosram:
        ld      a,1
        out     ($37),a
        ret

rec_sig: db "GYR1"

rec_sum:        ; A = sum of recbuf[0..REC_LEN-1] + $5A
        ld      hl,recbuf
        ld      b,REC_LEN
        ld      a,$5A
.l:     add     a,(hl)
        inc     hl
        djnz    .l
        ret

save_records:
        ld      a,(srok)
        or      a
        ret     z
        ld      hl,rec_sig
        ld      de,recbuf
        ld      bc,4
        ldir
        ld      hl,HISC
        ld      bc,64
        ldir
        ld      a,(skill)
        ld      (de),a
        inc     de
        ld      a,(snd_mode)
        ld      (de),a
        call    rec_sum
        ld      (recbuf+REC_LEN),a
        di
        ld      a,3
        out     ($37),a
        ld      hl,recbuf
        ld      de,SAVEADR
        ld      bc,REC_LEN+1
        ldir
        ld      a,(home_bank)
        out     ($37),a
        cp      3                   ; (the front end runs with the interrupt off)
        ret     z
        ei
        ret

