; SDTEST.VZ - tries to open 13GHOST1 and DC2TITLE through the BennVenn DOS
; exactly the way 13 Ghosts does, and prints what the DOS answered.
            org $D000
start:      di
            ld sp,$E400
            ld hl,$5FFF
            ld b,(hl)
            ld a,b
            cpl
            ld (hl),a
            ld a,(hl)
            xor b
            ld (hl),b
            and 1
            ld (map),a
            ld hl,n1
            call try
            ld hl,n2
            call try
            ld hl,n3
            call try
            ld hl,done
            call $28A7
.h:         jr .h
; HL -> quoted name
try:        push hl
            inc hl
            call $28A7              ; print the name (stops at the quote)
            ld a,(map)
            out ($37),a
            ld hl,$F800
            ld ($FB80),hl
            pop hl
            ld a,1
            call $5F00
            ld a,($FB03)
            ld (s1),a
            ld a,($FB05)
            ld (s2),a
            ld hl,ok
            ld a,(s1)
            cp 1
            jr nz,.bad
            ld a,(s2)
            cp 1
            jr nz,.pr
.bad:       ld hl,bad
.pr:        call $28A7
            ld a,(s1)
            call hex
            ld a,(s2)
            call hex
            ld a,(map)
            call hex
            ld hl,crlf
            jp $28A7
hex:        push af
            rrca
            rrca
            rrca
            rrca
            call nib
            pop af
            call nib
            ld a,' '
            jp $033A                ; ROM print char
nib:        and 15
            add a,'0'
            cp '9'+1
            jr c,.d
            add a,7
.d:         jp $033A
map:        db 0
s1:         db 0
s2:         db 0
n1:         db 34,"13GHOST1",34,0
n2:         db 34,"DC2TITLE",34,0
n3:         db 34,"DC2A0P1",34,0
ok:         db " OK   ",0
bad:        db " FAIL ",0
crlf:       db 13,0
done:       db 13,"SD TEST DONE",13,0
