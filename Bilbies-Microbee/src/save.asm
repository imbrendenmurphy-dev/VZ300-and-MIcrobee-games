; SAVE.DAT is preallocated as allocation block 1 on this build's disk.
; Check its signature before every write. Never create/extend files in-game.
; FDC polling has bounded timeouts, including each byte's DRQ wait.
SVBUF equ $3000
mb_drive: db 0
sv_error: db 0
sv_sector: db 26
sv_cmd:
        out ($44),a
        ld a,16
.delay: dec a : jr nz,.delay
        ret
sv_wait:
        ld de,0
.w:     in a,($44) : bit 0,a : ret z
        dec de : ld a,d : or e : jr nz,.w
        ld a,$D0 : out ($44),a
        ld a,$FF : ret
sv_drq:
        ld de,0
.w:     in a,($44) : bit 1,a : jr nz,.ok
        bit 0,a : jr z,.error
        dec de : ld a,d : or e : jr nz,.w
.error: ld a,$D0 : out ($44),a
        scf : ret
.ok:    or a : ret
sv_locate:
        ld a,(mb_drive) : or 8 : out ($48),a
        ld a,$0B : call sv_cmd : call sv_wait
        cp $FF : ret z
        ld a,2 : out ($47),a
        ld a,$1C : call sv_cmd : call sv_wait
        cp $FF : ret z
        ld bc,8000
.settle: dec bc : ld a,b : or c : jr nz,.settle
        ld a,(sv_sector) : out ($46),a
        xor a : ret
sv_read:
        call sv_locate : or a : ret nz
        ld a,$88 : call sv_cmd
        ld hl,SVBUF : ld bc,512
.byte:  call sv_drq : jr c,sv_failed
        in a,($47) : ld (hl),a : inc hl
        dec bc : ld a,b : or c : jr nz,.byte
        call sv_wait : and $9C : ret
sv_write:
        call sv_locate : or a : ret nz
        ld a,$A8 : call sv_cmd
        ld hl,SVBUF : ld bc,512
.byte:  call sv_drq : jr c,sv_failed
        ld a,(hl) : out ($47),a : inc hl
        dec bc : ld a,b : or c : jr nz,.byte
        call sv_wait : and $FC : ret
sv_failed:
        ld a,1 : or a : ret
sv_signature: db "BILBIES-BEE-SAVE"
sv_filename: db "SAVE    DAT"
sv_read_header:
        ld a,22 : ld (sv_sector),a
        call sv_read : ret nz
        ld a,(SVBUF) : or a : ret nz
        ld hl,SVBUF+1 : ld de,sv_filename : ld b,11
.name:  ld a,(de) : cp (hl) : ret nz
        inc de : inc hl : djnz .name
        ld a,(SVBUF+16) : cp 1 : ret nz
        ld a,26 : ld (sv_sector),a
        jp sv_read
sv_check_signature:
        ld hl,SVBUF : ld de,sv_signature : ld b,16
.b:     ld a,(de) : cp (hl) : ret nz
        inc de : inc hl : djnz .b
        xor a : ret
sv_sum:
        ld hl,SVBUF+16 : ld b,5 : xor a
.b:     add a,(hl) : rlca : inc hl : djnz .b
        ret
load_game:
        call sv_read_header : ret nz
        call sv_check_signature : ret nz
        ld a,(SVBUF+16) : cp 1 : ret nz
        call sv_sum : ld hl,SVBUF+21 : cp (hl) : ret nz
        ld a,(SVBUF+17) : cp 2 : ret nc
        ld (mb_mono),a
        ld a,(SVBUF+18) : or a : ret z : cp 25 : ret nc
        ld (v_unlock),a
        ld a,(SVBUF+19) : cp 24 : ret nc
        ld (v_lvl),a
        ret
save_game:
        call sv_read_header : jr nz,.bad
        call sv_check_signature : jr nz,.bad
        ld a,1 : ld (SVBUF+16),a
        ld a,(mb_mono) : ld (SVBUF+17),a
        ld a,(v_unlock) : ld (SVBUF+18),a
        ld a,(v_lvl) : ld (SVBUF+19),a
        xor a : ld (SVBUF+20),a
        call sv_sum : ld (SVBUF+21),a
        call sv_write : jr nz,.bad
        call sv_read : jr nz,.bad
        call sv_sum : ld hl,SVBUF+21 : cp (hl) : jr nz,.bad
        ld a,(mb_mono) : ld hl,SVBUF+17 : cp (hl) : jr nz,.bad
        ld a,(v_unlock) : inc hl : cp (hl) : jr nz,.bad
        ld a,(v_lvl) : inc hl : cp (hl) : jr nz,.bad
        xor a : ld (sv_error),a : ret
.bad:   ld a,1 : ld (sv_error),a : ret

; Startup and G settings menu. Preserve the logical screen while open.
mb_settings:
        push af : push bc : push de : push hl
        ld hl,VRAM : ld de,$3400 : ld bc,2048 : ldir
        call cls_blue
        ld a,C_YEL : ld b,C_BLU : call txt_colour
        ld hl,mb_set_title : ld a,8 : call print_c
        ld hl,mb_set_choices : ld a,22 : call print_c
        ld hl,mb_set_return : ld a,50 : call print_c
        ld a,1 : ld (mb_force),a
.loop:  call mb_present
        ld a,1 : out ($0B),a
        ld a,3 : call mb_keytest : jr nz,.colour
        ld a,13 : call mb_keytest : jr nz,.mono
        ld a,$37 : call mb_keytest : jr nz,.end
        jr .loop
.colour:xor a : jr .set
.mono:  ld a,1
.set:   ld (mb_mono),a
        ld a,1 : ld (mb_force),a
        xor a : out ($0B),a
        call save_game
        ld a,(sv_error) : or a
        ld hl,mb_saved : jr z,.message
        ld hl,mb_save_error
.message:ld a,36 : call print_c
        call mb_present
.release:
        ld a,1 : out ($0B),a
        ld a,3 : call mb_keytest : jr nz,.release
        ld a,13 : call mb_keytest : jr nz,.release
        xor a : out ($0B),a
        jr .loop
.end:   xor a : out ($0B),a
        ld hl,$3400 : ld de,VRAM : ld bc,2048 : ldir
        ld a,1 : ld (mb_force),a
        pop hl : pop de : pop bc : pop af : ret
mb_set_title: db "DISPLAY SETTINGS",0
mb_set_choices: db "C COLOUR   M MONO",0
mb_set_return: db "SPACE RETURN   G SETTINGS",0
mb_saved: db "SAVED TO GAME DISK",0
mb_save_error: db "SAVE FAILED - CHECK DISK",0
mb_g_old: db 0
mb_settings_key:
        ld a,1 : out ($0B),a
        ld a,7 : call mb_keytest : ld c,a
        xor a : out ($0B),a
        ld a,(mb_g_old) : ld b,a
        ld a,c : ld (mb_g_old),a : or a : ret z
        ld a,b : or a : ret nz
        jp mb_settings
