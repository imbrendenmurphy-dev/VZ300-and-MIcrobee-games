; ============================================================================
;  SD LOADING and the banked memory
;  The DOS is called the way the working games call it: mapping 1, sector
;  buffer at $F800, its own 2.5K stack below that, interrupts allowed during
;  the call and switched off straight after.
; ============================================================================
B_NFR    equ 6              ; fighter block header (see tools/fighters.py)
B_PTRS   equ 20
NPTRS    equ 8

h0_on:  push af                 ; stage bank in (normal high memory)
        ld a,MAP_H0
        out ($37),a
        pop af
        ret
h0_off: push af                 ; back to the game's high bank
        ld a,MAP_H1
        out ($37),a
        pop af
        ret

; init2: the rest of start-up, from always-visible memory
init2:
        call refresh_h1
        xor a
        ld (want_a),a
        ld (want_stage),a
        inc a
        ld (want_b),a
        call load_match
        ei
        jp front_main

; refresh_h1: copy the banked code into the second high bank (through the
; shadow screen) and rebuild the draw tables.  Interrupts off.
refresh_h1:
        ld hl,H1IMG
        ld de,H1CODE
        ld b,H1LEN/$800
.l:     push bc
        ld a,MAP_H0
        out ($37),a
        push de
        ld de,SB
        ld bc,$800
        ldir
        pop de
        ld a,MAP_H1
        out ($37),a
        push hl
        ld hl,SB
        ld bc,$800
        ldir
        pop hl
        pop bc
        djnz .l
        jp build_tables

; load_match: bring in want_stage, want_a and want_b if they are not already
; loaded.  The screen is left as it is while the card is read.
load_match:
        ld a,(want_stage)
        ld hl,stage_cur
        cp (hl)
        jr nz,.go
        ld a,(want_a)
        ld hl,slot_a
        cp (hl)
        jr nz,.go
        ld a,(want_b)
        ld hl,slot_b
        cp (hl)
        ret z
.go:    call stop_sfx
        di
        ld a,1
        ld (in_dos),a
        xor a
        ld (frame_ready),a
        ; ---- the stage
        ld a,(want_stage)
        ld hl,stage_cur
        cp (hl)
        jr z,.fa
        ld (hl),$FF
        call file_name
        ld (ld_skip),a          ; skip the fighter in that file
        ld de,STAGE0
        ld bc,STAGELEN
        xor a
        call load_file
        jp c,.fail
        call h0_on
        ld hl,STAGE0+STAGEROWS*STAGEW
        ld de,PATCH
        ld bc,PATCHLEN
        ldir
        call build_stage2_i
        call h0_off
        ld a,(want_stage)
        ld (stage_cur),a
        xor a
        ld (anim_ph),a
        ld (anim_t),a
        ; ---- fighter A
.fa:    ld a,(want_a)
        ld hl,slot_a
        cp (hl)
        jr z,.fb
        ld (hl),$FF
        call file_name
        ld b,a                  ; sectors -> bytes
        sla b
        ld c,0
        xor a
        ld (ld_skip),a
        ld de,SLOT_A
        ld a,1
        call load_file
        jp c,.fail
        ; ---- fighter B (last: nothing else is read after it)
.fb:    ld a,(want_b)
        ld hl,slot_b
        cp (hl)
        jr z,.done
        ld (hl),$FF
        call file_name
        ld b,a
        sla b
        ld c,0
        xor a
        ld (ld_skip),a
        ld de,SLOT_B
        ld a,2
        call load_file
        jp c,.fail
.done:  call refresh_h1         ; leaves the game's bank in
        ; ---- check and relocate what was loaded
        ld a,(slot_a)
        inc a
        jr nz,.cb
        ld hl,SLOT_A
        call fix_block
        ld a,2
        jr c,.bad
        ld a,(want_a)
        ld (slot_a),a
.cb:    ld a,(slot_b)
        inc a
        jr nz,.ok
        ld hl,SLOT_B
        call fix_block
        ld a,3
        jr c,.bad
        ld a,(want_b)
        ld (slot_b),a
.ok:    xor a
        ld (in_dos),a
        ld (frame_ready),a
        ld (fieldcnt),a
        ei
        ret
.fail:  ld a,1
.bad:   ; could not read (1) or the data is damaged (2 fighter A, 3 fighter B)
        ld (err_code),a
        ld a,MAP_H1
        out ($37),a
        call sd_error
        jp .go

; file_name: A = fighter/stage number 0-8 -> HL = DOS name, A = sectors of
; fighter data at the start of that file
file_name:
        ld e,a
        ld d,0
        add a,$31
        ld (fname_n),a
        ld hl,fsecs
        add hl,de
        ld a,(hl)
        ld hl,fname
        ret
fname:  db 34,"RDRUMBL"
fname_n: db "1",34,0
fname0: db 34,"RDRUMBL0",34,0
; (a copy of the table in the banked code, which is not visible during loads)
fsecs:
        include "gen/fsecs.asm"

; load_file: HL = name, DE = destination, BC = length, A = where it goes
; (0 normal high memory, 1 SRAM bank 1, 2 the second high bank),
; (ld_skip) = sectors to pass over first.  Carry = failed.  Interrupts off.
load_file:
        ld (ld_kind),a
        ld (ld_dest),de
        ld (ld_left),bc
        ld (ld_name),hl
        ld (ld_sp),sp
        ld sp,DOSSTACK
        ld a,(dos_map)
        out ($37),a
        ld hl,SECBUF
        ld ($FB80),hl
        ld hl,(ld_name)
        ld a,1
        call $5F00              ; open
        di
        ld a,($FB03)
        cp 1
        jr nz,.err
        ld a,($FB05)
        cp 1
        jr z,.err
        ld a,1
        call $5F03              ; first sector
        di
.skip:  ld a,(ld_skip)
        or a
        jr z,.lp
        dec a
        ld (ld_skip),a
        call .next
        jr .skip
.lp:    ; ---- this sector: up to 512 bytes
        ld hl,(ld_left)
        ld bc,512
        or a
        sbc hl,bc
        jr nc,.full
        add hl,bc
        ld b,h
        ld c,l                  ; the last part
        ld hl,0
.full:  ld (ld_left),hl
        ld (ld_n),bc
        ld a,b
        or c
        jr z,.ok
        ld hl,SECBUF
        ld de,(ld_dest)
        ld a,(ld_kind)
        or a
        jr z,.k0
        dec a
        jr z,.k1
        ; the second high bank: through the shadow screen.  The stack is in
        ; normal high memory, so nothing is pushed while the bank is in.
        ld de,SB
        ldir
        ld a,(dos_map)
        or 4
        out ($37),a
        ld hl,SB
        ld de,(ld_dest)
        ld bc,(ld_n)
        ldir
        ld a,(dos_map)
        out ($37),a
        jr .adv
.k1:    ld a,MAP_H0
        out ($37),a
        ldir
        ld a,(dos_map)
        out ($37),a
        jr .adv
.k0:    ldir
.adv:   ld (ld_dest),de
        ld hl,(ld_left)
        ld a,h
        or l
        jr z,.ok
        call .next
        jr .lp
.ok:    or a
.out:   ld sp,(ld_sp)
        ret
.err:   scf
        jr .out
.next:  ld hl,SECBUF
        ld ($FB80),hl
        call $5F09
        di
        ret

; load_screen: A = picture number in file 0 -> the clean view (2K)
load_screen:
        push af
        call stop_sfx
        pop af
        di
        add a,a
        add a,a
        ld (ld_skip),a
        ld a,1
        ld (in_dos),a
        xor a
        ld (frame_ready),a
        ld hl,fname0
        ld de,BG
        ld bc,$800
        xor a
        call load_file
        push af
        call refresh_h1
        xor a
        ld (in_dos),a
        ld (fieldcnt),a
        pop af
        ei
        ret

; fix_block: HL = a fighter block just loaded.  Checks it, then turns its
; offsets into addresses.  Carry = damaged.
fix_block:
        ld a,(hl)
        cp $52
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp $44
        scf
        ret nz
        dec hl
        push hl
        pop ix                  ; IX = block
        ; checksum of bytes 6..length-1
        ld c,(ix+2)
        ld b,(ix+3)
        ld a,b
        cp SLOTLEN/256+1
        ccf
        ret c
        push hl
        ld de,6
        add hl,de
        ex de,hl                ; DE = pointer
        ld h,b
        ld l,c
        ld bc,-6
        add hl,bc
        ld b,h
        ld c,l                  ; BC = count
        ld hl,0
.sum:   ld a,(de)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.sum
        ld a,l
        cp (ix+4)
        jr nz,.badp
        ld a,h
        cp (ix+5)
        jr nz,.badp
        pop de                  ; DE = block base
        ; the header pointers
        push ix
        pop hl
        ld bc,B_PTRS
        add hl,bc
        ld b,NPTRS
        call .rel
        ; the frame directory: two pointers and six bytes per frame
        ld l,(ix+B_PTRS+4)
        ld h,(ix+B_PTRS+5)
        ld c,(ix+B_NFR)
.fr:    ld b,2
        call .rel
        push de
        ld de,6
        add hl,de
        pop de
        dec c
        jr nz,.fr
        or a
        ret
.badp:  pop hl
        scf
        ret
.rel:   ; B words at HL: add DE to each that is not zero
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,b
        or c
        jr z,.z
        ex de,hl
        push hl
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        ex de,hl
        ld (hl),b
        dec hl
        ld (hl),c
        inc hl
.z:     inc hl
        pop bc
        djnz .rel
        ret

; sd_error: say what went wrong, wait for a button, and let the caller retry
sd_error:
        ld a,$28
        ld (latch),a
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$AA
        ldir
        ld a,VRAM>>8
        ld (txt_page),a
        ld a,(err_code)
        dec a
        ld hl,se_read
        jr z,.t
        ld hl,se_bad
.t:     ld bc,$0312
        ld a,1
        call text
        ld hl,fname+1
        ld de,namebuf
        ld bc,8
        ldir
        xor a
        ld (de),a
        ld hl,namebuf
        ld bc,$0A1C
        ld a,1
        call text
        ld hl,se_dat
        ld bc,$121C
        ld a,1
        call text
        ld hl,se_retry
        ld bc,$042A
        ld a,1
        call text
        ld a,SB>>8
        ld (txt_page),a
        xor a
        ld (in_dos),a
        ld (frame_ready),a
        call clear_keys
        ei
.w:     halt
        call menu_keys
        and $30
        jr z,.w
        call clear_keys
        ret
se_read:  db "CANNOT READ FROM THE SD CARD",0
se_bad:   db "A GAME FILE IS DAMAGED:",0
se_dat:   db ".DAT",0
se_retry: db "PRESS FIRE TO TRY AGAIN",0
