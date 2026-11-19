key_test:
 push bc
 ld c,a
 ld a,1
 out ($0B),a
 ld a,16
 out ($0C),a
 in a,($0D)
 ld a,17
 out ($0C),a
 in a,($0D)
 ld a,18
 out ($0C),a
 ld a,c
 rrca
 rrca
 rrca
 rrca
 and 3
 out ($0D),a
 ld a,19
 out ($0C),a
 ld a,c
 rlca
 rlca
 rlca
 rlca
 and $F0
 out ($0D),a
 ld a,31
 out ($0C),a
 xor a
 out ($0D),a
 in a,($0C)
 and $40
 ld c,a
 xor a
 out ($0B),a
 ld a,c
 pop bc
 or a
 ret
readinput:
 ld d,0
 ld hl,key_table
 ld b,7
.loop: ld a,(hl)
 inc hl
 push hl
 call key_test
 pop hl
 jr z,.next
 ld a,(hl)
 or d
 ld d,a
.next: inc hl
 djnz .loop
 in a,(0)
 cpl
 ld c,a
 bit 2,c
 jr z,.jr
 set 0,d
.jr: bit 3,c
 jr z,.ju
 set 1,d
.ju: bit 0,c
 jr z,.jd
 set 2,d
.jd: bit 1,c
 jr z,.jf
 set 3,d
.jf: bit 7,c
 jr z,.done
 set 4,d
.done:
 ld a,d
 ret
key_table: db 26,1,24,2,13,1,$2C,2,$3B,1,$3E,2,$37,16
anykey:
 push bc
 push de
 push hl
 ld b,64
 ld e,0
.loop: ld a,e
 call key_test
 jr nz,.done
 inc e
 djnz .loop
 xor a
.done: pop hl
 pop de
 pop bc
 ret
wait_release:
 call rearm
 call anykey
 jr nz,wait_release
 ret
