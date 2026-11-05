; =====================================================================
; EMPIRES.COM - CP/M loader and DOS services for EMPIRES (Premium Plus)
;
; Runs under the Premium's own CP/M.  Finds which 32K block is CP/M's
; lower memory and where its video window is (method and code after The
; Lantern Deep's loader), checks the 1MB RAM, loads the engine, overlay
; and art into expanded RAM blocks through the lower 32K window, then
; saves a snapshot of CP/M's upper memory (8000-EFFF) and starts the
; engine.  The first part of this program stays resident in CP/M's block:
; the engine comes back to it to return to the A> prompt.
; =====================================================================
BDOS      equ 0005h
P_MEM     equ 50h
P_LV      equ 1Ch
BLK_MAP   equ 8
BLK_ART   equ 16
BLK_OVL   equ 17
BLK_CPM   equ 18
BLK_GAME  equ 19
BLK_STAGE equ 20
BLK_SAVE  equ 21                ; 21-24: save-file staging
N_BLOCKS  equ 25                ; blocks 0..24 must all exist
DMA       equ 0A800h            ; record buffer in upper TPA
UP_LEN    equ 7000h             ; engine image 8000-EFFF

        org 0100h
        jp start
; ---- resident services (fixed addresses, used by the engine) ----
        jp svc_exit             ; 0103: CP/M upper restored, video off -> A>
        jp svc_disk             ; 0106: CP/M upper restored, video off -> disk job
cpm_port: db 0                  ; 0109: CP/M's port 50h value
cpm_block: db 0                 ; 010A
d_cmd:   db 0                   ; 010B: 1 save, 2 load, 3 read slot headers
d_name:  ds 11                  ; 010C: file name (8+3, CP/M FCB form)
d_len:   ds 3                   ; 0117: bytes (save: to write; load: read)
d_res:   db 0                   ; 011A: 0 ok, 1 no file, 2 write-protected, 3 no room, 4 disk full

svc_disk:
        ld sp,0400h
        ld a,(cpm_port)
        out (P_MEM),a
        ei
        ld hl,reloc
        ld de,0A000h
        ld bc,reloc_end-reloc_start
        ldir
        jp disk_main

svc_exit:
        ld sp,0400h
        ld a,(cpm_port)
        out (P_MEM),a           ; CP/M's lower block and video window back
        ei
        ld de,m_bye
        ld c,9
        call BDOS
        jp 0                    ; warm boot to the A> prompt
m_bye:  db 26,"Thanks for playing EMPIRES : THE LIVING WORLD - ViBED by BPM",13,10,"$"

start:  ld sp,0A7F0h            ; upper TPA: the lower window switches under us
        ld de,m_title
        ld c,9
        call BDOS
        ld a,(BDOS+2)           ; upper TPA must reach past B000h (DMA, loader)
        cp 0B0h
        jr nc,.tpa
        ld de,m_tpa
        ld c,9
        jp BDOS
.tpa:   ld hl,reloc
        ld de,0A000h
        ld bc,reloc_end-reloc_start
        ldir
        ld hl,sig
        ld de,sig_copy
        ld bc,16
        ldir
        jp main

m_title: db 13,10,"EMPIRES : THE LIVING WORLD",13,10
         db "ViBED by BPM - 2026",13,10,"$"
m_tpa:   db "Needs a CP/M with a TPA above B000h.",13,10,"$"

reloc:
; ---------------------------------------------------------------------
; Runs at A000h (upper TPA) so it can switch the lower 32K window.
; ---------------------------------------------------------------------
        disp 0A000h
reloc_start:
main:   di
        call find_cpm
        jp c,fail_bank
        call ram_check
        jp c,fail_ram
        ; keep CP/M's port value in the resident part (CP/M block mapped)
        ld a,(r_cpm_port)
        ld (cpm_port),a
        ld a,(r_cpm_block)
        ld (cpm_block),a
        ei
        ld de,m_load
        ld c,9
        call BDOS
        ld hl,files
.f:     ld a,(hl)
        or a
        jr z,.done
        ld (cur_blk),a
        inc hl
        ld a,(hl)               ; destination high byte (00h or 40h)
        ld (dest+1),a
        xor a
        ld (dest),a
        inc hl
        ld (cur_name),hl
        push hl
        call load_file
        pop hl
        jp c,fail_file
        ld de,11
        add hl,de
        jr .f
.done:  ld de,m_go
        ld c,9
        call BDOS
        di
        ; final stage runs at F000h in block 0 with the video window off
        ld a,(r_cpm_port)
        or 8
        out (P_MEM),a
        ld hl,final_src
        ld de,0F000h
        ld bc,final_end-final_start
        ldir
        ld a,(r_cpm_port)
        ld (f_cpm),a
        ld a,(r_cpm_block)
        ld (f_blk),a
        jp 0F000h

files:  db BLK_STAGE,00h,"EMPIRES UP "
        db BLK_OVL,  00h,"EMPIRES OVL"
        db BLK_ART,  40h,"EMPIRES ART"
        db 0

fail_bank:
        ei
        ld de,m_bank
        jr fail
fail_ram:
        ei
        ld de,m_ram
        jr fail
fail_file:
        ld de,m_file
fail:   ld c,9
        call BDOS
        rst 0
m_load: db "Loading$"
m_go:   db 13,10,"$"
m_bank: db 13,10,"Cannot find the CP/M memory bank.",13,10,"$"
m_ram:  db 13,10,"EMPIRES needs a Microbee Premium Plus with 1MB RAM.",13,10,"$"
m_file: db 13,10,"A game file is missing from this disk.",13,10,"$"

; A = block -> A = port 50h value: ROMs off, no video window
blk_port:
        push bc
        ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and 1Ch
        rlca
        rlca
        rlca
        or c
        or 0Ch
        pop bc
        ret

; Which block is CP/M's lower 32K?  The loader's own signature at 0F00h
; is looked for in every block.  Also: where is CP/M's video window?
find_cpm:
        in a,(P_LV)
        ld (lv_save),a
        ld hl,8000h
        call vid_probe
        or a
        ld a,10h
        jr nz,.v
        ld hl,0F000h
        call vid_probe
        or a
        ld a,00h
        jr nz,.v
        ld a,08h
.v:     ld (vid_bits),a
        ld c,0
.scan:  ld a,c
        call blk_port
        out (P_MEM),a
        ld hl,0F00h
        ld de,sig_copy
        ld b,16
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.next
        inc hl
        inc de
        djnz .cmp
        ld a,c
        call blk_port
        and 0F7h
        ld b,a
        ld a,(vid_bits)
        or b
        ld (r_cpm_port),a
        out (P_MEM),a
        ld a,c
        ld (r_cpm_block),a
        or a
        jr z,.bad               ; block 0 is the fixed upper half
        cp BLK_MAP
        jr nc,.hi
        or a                    ; 1..7: fine (carry clear)
        ret
.hi:    cp N_BLOCKS
        jr c,.bad               ; 8..20 are ours
        or a
        ret
.bad:   scf
        ret
.next:  inc c
        ld a,c
        cp 32
        jr nz,.scan
        scf
        ret

; HL = address: is it video RAM (attribute vs screen RAM differ)?
vid_probe:
        ld a,90h
        out (P_LV),a
        ld a,(hl)
        ld (pb_save),a
        ld a,0AAh
        ld (hl),a
        ld a,80h
        out (P_LV),a
        ld b,(hl)
        ld a,90h
        out (P_LV),a
        ld a,55h
        ld (hl),a
        ld a,80h
        out (P_LV),a
        ld a,(hl)
        cp b
        ld a,0
        jr nz,.n
        inc a
.n:     ld (pb_res),a
        ld a,90h
        out (P_LV),a
        ld a,(pb_save)
        ld (hl),a
        ld a,(lv_save)
        out (P_LV),a
        ld a,(pb_res)
        ret

; Do blocks 0..N_BLOCKS-1 all exist, apart from each other?
ram_check:
        ld c,0
.w:     ld a,c
        call blk_port
        out (P_MEM),a
        ld a,(1F00h)
        ld hl,saved
        ld e,c
        ld d,0
        add hl,de
        ld (hl),a
        ld a,c
        xor 0A5h
        ld (1F00h),a
        inc c
        ld a,c
        cp N_BLOCKS
        jr nz,.w
        ld c,0
        ld b,0
.r:     ld a,c
        call blk_port
        out (P_MEM),a
        ld a,c
        xor 0A5h
        ld hl,1F00h
        cp (hl)
        jr z,.ok
        inc b
.ok:    inc c
        ld a,c
        cp N_BLOCKS
        jr nz,.r
        ld c,N_BLOCKS-1
.rs:    ld a,c
        call blk_port
        out (P_MEM),a
        ld hl,saved
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        ld (1F00h),a
        dec c
        jp p,.rs
        ld a,(r_cpm_port)
        out (P_MEM),a
        ld a,b
        or a
        ret z
        scf
        ret

; Load the file named at (cur_name) into block (cur_blk) at (dest).
load_file:
        ld hl,fcb
        ld (hl),0
        inc hl
        ex de,hl
        ld hl,(cur_name)
        ld bc,11
        ldir
        ld hl,fcb+12
        ld b,24
.z:     ld (hl),0
        inc hl
        djnz .z
        ld de,fcb
        ld c,15
        call BDOS
        inc a
        scf
        ret z
.rec:   ld de,DMA
        ld c,26
        call BDOS
        ld de,fcb
        ld c,20
        call BDOS
        or a
        jr nz,.eof
        di
        ld a,(cur_blk)
        call blk_port
        out (P_MEM),a
        ld hl,DMA
        ld de,(dest)
        ld bc,128
        ldir
        ld (dest),de
        ld a,(r_cpm_port)
        out (P_MEM),a
        ei
        ld a,(dest)
        or a
        jr nz,.rec
        ld a,(dest+1)
        and 0Fh
        jr nz,.rec
        ld e,'.'
        ld c,2
        call BDOS
        jr .rec
.eof:   or a
        ret

; ---------------------------------------------------------------------
; Disk jobs for the engine (CP/M fully restored, running at A000h)
; ---------------------------------------------------------------------
disk_main:
        ld sp,0A7F0h
        ld a,(cpm_port)         ; the relocated copy starts with a blank value
        ld (r_cpm_port),a
        xor a
        ld (d_res),a
        ld a,(d_cmd)
        cp 1
        jp z,dk_save
        cp 2
        jp z,dk_load
        cp 3
        jp z,dk_heads
        jp dk_done

dk_fcb:                         ; FCB from d_name
        ld hl,fcb
        ld (hl),0
        inc hl
        ex de,hl
        ld hl,d_name
        ld bc,11
        ldir
        ld hl,fcb+12
        ld b,24
.z:     ld (hl),0
        inc hl
        djnz .z
        ret

dk_save:
        ld c,25                 ; current disk
        call BDOS
        push af
        ld c,29                 ; read-only vector
        call BDOS
        pop af
        ld b,a
        inc b
.rb:    dec b
        jr z,.rt
        srl h
        rr l
        jr .rb
.rt:    bit 0,l
        ld a,2
        jp nz,dk_res
        call dk_fcb
        ld de,fcb
        ld c,19                 ; delete the old save
        call BDOS
        call dk_fcb
        ld de,fcb
        ld c,22                 ; make
        call BDOS
        inc a
        ld a,3
        jp z,dk_res
        ld a,BLK_SAVE
        ld (cur_blk),a
        ld hl,0
        ld (dest),hl
        ; records = ceil(len / 128)
        ld hl,(d_len)
        ld a,(d_len+2)
        ld de,127
        add hl,de
        adc a,0
        add hl,hl
        rla
        ld l,h
        ld h,a                  ; HL = len*2 / 256 = records
        ld (recs),hl
.w:     ld hl,(recs)
        ld a,h
        or l
        jr z,.wd
        dec hl
        ld (recs),hl
        di
        ld a,(cur_blk)
        call blk_port
        out (P_MEM),a
        ld hl,(dest)
        ld de,DMA
        ld bc,128
        ldir
        ld a,(r_cpm_port)
        out (P_MEM),a
        ei
        call dk_adv
        ld de,DMA
        ld c,26
        call BDOS
        ld de,fcb
        ld c,21
        call BDOS
        or a
        jr z,.w
        ld de,fcb
        ld c,16
        call BDOS
        ld a,4
        jp dk_res
.wd:    ld de,fcb
        ld c,16
        call BDOS
        xor a
        jp dk_res

dk_adv: ld hl,(dest)            ; next 128 bytes of the staging blocks
        ld de,128
        add hl,de
        bit 7,h
        jr z,.s
        ld hl,0
        ld a,(cur_blk)
        inc a
        ld (cur_blk),a
.s:     ld (dest),hl
        ret

dk_load:
        call dk_fcb
        ld de,fcb
        ld c,15
        call BDOS
        inc a
        ld a,1
        jp z,dk_res
        ld a,BLK_SAVE
        ld (cur_blk),a
        ld hl,0
        ld (dest),hl
        ld (recs),hl
.r:     ld de,DMA
        ld c,26
        call BDOS
        ld de,fcb
        ld c,20
        call BDOS
        or a
        jr nz,.e
        di
        ld a,(cur_blk)
        call blk_port
        out (P_MEM),a
        ld hl,DMA
        ld de,(dest)
        ld bc,128
        ldir
        ld a,(r_cpm_port)
        out (P_MEM),a
        ei
        call dk_adv
        ld hl,(recs)
        inc hl
        ld (recs),hl
        ld a,(cur_blk)
        cp BLK_SAVE+4
        jr nz,.r
.e:     ld de,fcb
        ld c,16
        call BDOS
        ld hl,(recs)            ; bytes = records * 128
        xor a
        srl h
        rr l
        rra
        ld (d_len),a
        ld (d_len+1),hl
        xor a
        jp dk_res

dk_heads:                       ; record 0 of SAVE1-3.EMP -> staging block offsets 0, 128, 256
        ld a,'1'
        ld (d_name+4),a
        ld hl,0
        ld (dest),hl
.n:     call dk_fcb
        ld hl,DMA
        ld de,DMA+1
        ld bc,127
        ld (hl),0
        ldir
        ld de,fcb
        ld c,15
        call BDOS
        inc a
        jr z,.cp
        ld de,DMA
        ld c,26
        call BDOS
        ld de,fcb
        ld c,20
        call BDOS
        ld de,fcb
        ld c,16
        call BDOS
.cp:    di
        ld a,BLK_SAVE
        call blk_port
        out (P_MEM),a
        ld hl,DMA
        ld de,(dest)
        ld bc,128
        ldir
        ld (dest),de
        ld a,(r_cpm_port)
        out (P_MEM),a
        ei
        ld a,(d_name+4)
        inc a
        ld (d_name+4),a
        cp '4'
        jr nz,.n
        xor a

dk_res: ld (d_res),a
dk_done:
        ; back to the engine: re-snapshot CP/M, restore the engine (stub at F000h)
        di
        ld a,(cpm_port)
        ld (r_cpm_port),a
        or 8
        out (P_MEM),a
        ld hl,ret_src
        ld de,0F000h
        ld bc,ret_end-ret_start
        ldir
        ld a,(d_res)
        ld (rt_res),a
        jp 0F000h
recs:   dw 0

cur_blk:    db 0
cur_name:   dw 0
dest:       dw 0
r_cpm_port: db 0
r_cpm_block: db 0
vid_bits:   db 0
lv_save:    db 0
pb_save:    db 0
pb_res:     db 0
sig_copy:   ds 16
saved:      ds 32
fcb:        ds 36
reloc_end:
        ent

; ---------------------------------------------------------------------
; Final stage: copied to F000h, runs with the video window off.
; ---------------------------------------------------------------------
final_src:
        disp 0F000h
final_start:
fstage: ld sp,0FFF0h
        ; snapshot CP/M's upper memory
        ld a,BLK_CPM
        call fb_port
        out (P_MEM),a
        ld hl,8000h
        ld de,0
        ld bc,UP_LEN
        ldir
        ; engine image -> 8000h
        ld a,BLK_STAGE
        call fb_port
        out (P_MEM),a
        ld hl,0
        ld de,8000h
        ld bc,UP_LEN
        ldir
        ; parameters for the engine
        ld a,(f_cpm)
        ld (8003h),a
        ld a,(f_blk)
        ld (8004h),a
        ; lower window = first map band; the engine turns the video on
        ld a,BLK_MAP
        call fb_port
        out (P_MEM),a
        jp 8000h
fb_port: ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and 1Ch
        rlca
        rlca
        rlca
        or c
        or 0Ch
        ret
f_cpm:  db 0
f_blk:  db 0
final_end:
        ent

ret_src:
        disp 0F000h
ret_start:
        ld a,BLK_CPM
        call fb_port2
        out (P_MEM),a
        ld hl,8000h
        ld de,0
        ld bc,UP_LEN
        ldir                    ; CP/M snapshot refreshed (BDOS state changed)
        ld a,BLK_GAME
        call fb_port2
        out (P_MEM),a
        ld hl,0
        ld de,8000h
        ld bc,UP_LEN
        ldir                    ; engine back
        db 3Eh
rt_res: db 0
        ld (8005h),a
        jp 8006h                ; engine: svc_resume
fb_port2: ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and 1Ch
        rlca
        rlca
        rlca
        or c
        or 0Ch
        ret
ret_end:
        ent
phys_end:
        assert phys_end <= 0F00h, "loader too long for the signature at 0F00h"
        org 0F00h
sig:    db "EMPIRES-LOADER!!"
        db 1Ah
