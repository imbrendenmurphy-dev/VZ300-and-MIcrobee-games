; hs_line, letter_up/dn, scan_letter (front end, bank 3)
; hs_line: B = entry -> txtbuf "1  BPM  050000  S5"
hs_line:
        push    bc
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,HISC
        add     hl,de
        push    hl
        ld      de,txtbuf
        ld      a,b
        add     a,'1'
        ld      (de),a
        inc     de
        ld      a,' '
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        pop     hl
        push    hl
        inc     hl
        inc     hl
        inc     hl
        ld      bc,3
        ldir
        ld      a,' '
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        pop     hl
        push    hl
        push    de
        call    bcd_to_str
        pop     de
        call    strcpy
        ld      a,' '
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      a,'S'
        ld      (de),a
        inc     de
        pop     hl
        ld      bc,6
        add     hl,bc
        ld      a,(hl)
        add     a,'0'
        ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        pop     bc
        ret

; letter_up / letter_dn: A = letter -> next / previous (A-Z, space)
letter_up:
        cp      ' '
        jr      z,.a
        inc     a
        cp      'Z'+1
        ret     c
        ld      a,' '
        ret
.a:     ld      a,'A'
        ret
letter_dn:
        cp      ' '
        jr      z,.z
        dec     a
        cp      'A'
        ret     nc
        ld      a,' '
        ret
.z:     ld      a,'Z'
        ret

; scan_letter -> A = a newly pressed letter key (0 = none)
scan_letter:
        ld      hl,$68FE
        ld      de,key_letters
        ld      c,0                 ; found
.r:     ld      a,(hl)
        cpl
        and     $3F
        add     a,a
        add     a,a
        ld      b,6
.b:     add     a,a                 ; bit 5 first
        push    af
        jr      nc,.nk
        ld      a,(de)
        or      a
        jr      z,.nk
        ld      c,a
.nk:    pop     af
        inc     de
        djnz    .b
        ld      a,l                 ; next row
        rlca
        ld      l,a
        cp      $FE
        jr      nz,.r
        ; only report it on the press
        ld      a,(last_letter)
        cp      c
        ld      a,c
        ld      (last_letter),a
        ret     nz
        xor     a
        ret

key_letters:    ; rows 0..7, bit 5 down to bit 0
        db      "RQE",0,"WT"
        db      "FAD",0,"SG"
        db      "VZC",0,"XB"
        db      0,0,0,0,0,0
        db      "M",0,0,0,0,"N"
        db      0,0,0,0,0,0
        db      "UPI",0,"OY"
        db      "J",0,"K",0,"LH"

