; ==========================================================================
; front.asm - title, attract pages, skill menu, title tune, test card
;   VIBED BY BPM 2026
;
;   The pages, the logo's cell map and the tune are in RAM block 2 after
;   the zones (tools/front.py).
; ==========================================================================

; front: the title with its tune, then the pages in turn, until SPACE;
;        then the skill menu.  -> (skill) 0..2
front:  call f_title
        call music
        jr nz,.key
.pages  ld hl,P_STORY
        call f_show
        jr nz,.key
        ld hl,P_HOW
        call f_show
        jr nz,.key
        ld hl,P_LOCALS
        call f_show
        jr z,front
.key    cp 2
        jp nz,f_skill
        call f_test
        jr front

; f_title: the logo and the title page
f_title:
        call showpage0
        ld bc,0D10h             ; banks 13..15: the logo's glyphs
        call upload_pcg
        ld b,CWHITE
        call cls
        ld a,BLK_ZONES
        call setblk
        ld hl,F_LOGO
        ld de,VRAM+40           ; screen row 1
        ld c,LOGO_H
.r      ld b,LOGO_W
.c      push bc
        ld a,(hl)               ; code
        inc hl
        ld b,(hl)               ; bank (255 = blank)
        inc hl
        inc b
        jr z,.s
        dec b
        ld (de),a
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld a,b
        ld (de),a
        ld a,X1C
        out (PORT_1C),a
        ld a,c                  ; hot at the top, cooling to the fangs
        cp LOGO_H-3
        ld b,CYELLOW
        jr nc,.k
        cp 3
        ld b,CBRED
        jr nc,.k
        ld b,CRED
.k      set 3,d
        ld a,40h
        out (PORT_08),a
        ld a,b
        ld (de),a
        xor a
        out (PORT_08),a
        res 3,d
.s      inc de
        pop bc
        djnz .c
        dec c
        jr nz,.r
        ld hl,P_TITLE
        call f_page
        call tabblk
        ld a,1
        ld (f_ont),a
        ; fall through
; f_mode: the screen setting, on the title
f_mode: ld hl,T_COLOUR
        ld a,(mono)
        or a
        jr z,.m
        ld hl,T_MONO
.m      ld de,20*40+20
        ld b,CBGREEN
        jp printc

; f_page: HL = page (block 2 mapped): lines of row, column, ink, text, 0
f_page: ld a,(hl)
        cp 0FFh
        ret z
        inc hl
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; row * 40
        ex de,hl
        pop hl
        ld a,(hl)
        inc hl
        add a,e
        ld e,a
        jr nc,.n
        inc d
.n      ld b,(hl)
        inc hl
        call printc
        inc hl
        jr f_page

; f_show: HL = page: show it for about nine seconds -> NZ, A = key if one
;         was pressed (see f_keys)
f_show: push hl
        xor a
        ld (f_ont),a
        ld b,CWHITE
        call cls
        ld a,BLK_ZONES
        call setblk
        pop hl
        call f_page
        call tabblk
        ld bc,450
.w      push bc
        call wait_vb
        call f_keys
        pop bc
        ret nz
        dec bc
        ld a,b
        or c
        jr nz,.w
        ret

; f_keys: -> A = 1 SPACE, 2 T, else 0 (flags set).  C swaps colour / mono.
f_keys: call readkeys
        ld a,KY_C
        call edge
        jr z,.nc
        ld a,(mono)
        xor 1
        ld (mono),a
        ld a,(f_ont)
        or a
        call nz,f_mode
.nc     ld a,KY_T
        call edge
        ld a,2
        ret nz
        ld a,KY_FIRE
        call edge
        ld a,1
        ret nz
        xor a
        ret

; f_skill: the three ways to suffer
f_skill:
        xor a
        ld (f_ont),a
        ld b,CWHITE
        call cls
        ld a,BLK_ZONES
        call setblk
        ld hl,P_SKILL
        call f_page
.draw   ld a,BLK_ZONES
        call setblk
        ld c,0
.mk     ld a,c                  ; a marker beside the chosen one
        add a,a
        add a,8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,8
        add hl,de
        ex de,hl
        ld hl,T_MARK
        ld a,(skill)
        cp c
        jr z,.on
        ld hl,T_NOMARK
.on     ld b,CYELLOW
        push bc
        call printc
        pop bc
        inc c
        ld a,c
        cp 3
        jr nz,.mk
        ld a,(skill)            ; and what it means
        add a,a
        ld e,a
        ld d,0
        ld hl,SKP
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call f_page
        call tabblk
.w      call wait_vb
        call readkeys
        ld a,KY_UP
        call edge
        jr z,.nu
        ld a,(skill)
        or a
        jr z,.nu
        dec a
        ld (skill),a
        jr .draw
.nu     ld a,KY_DOWN
        call edge
        jr z,.nd
        ld a,(skill)
        cp 2
        jr z,.nd
        inc a
        ld (skill),a
        jr .draw
.nd     ld a,KY_FIRE
        call edge
        jr z,.w
        ret

SKP:    dw P_SK0,P_SK1,P_SK2
T_MARK: db "==",0
T_NOMARK: db "  ",0
T_COLOUR: db "COLOUR    ",0
T_MONO: db "AMBER MONO",0
f_ont:  db 0
skill:  db 1                    ; 0 she'll be right, 1 hurt me plenty, 2 nightmare

; --------------------------------------------------------------------------
; music: the title tune.  Three voices on the one speaker bit: each is a
;   16-bit phase counter making a narrow pulse (on while its high byte is
;   under the voice's width), the three OR-ed together.  The widths shrink
;   as a note rings, so notes pluck and the high voice twinkles.
;   A row is 9 ticks of 256 samples (187 T each: about 18 kHz).
;   -> NZ, A = key if one was pressed (f_keys), Z at the end of the tune
; --------------------------------------------------------------------------
MU_TICKS equ 9
music:  ld a,BLK_ZONES
        call setblk
        ld hl,MU_CH
        ld b,12
.z      ld (hl),0
        inc hl
        djnz .z
        ld a,50h                ; bass, lead, twinkle: widths when struck
        ld (MU_CH+3),a
        ld a,38h
        ld (MU_CH+7),a
        ld a,2Ch
        ld (MU_CH+11),a
        ld hl,F_TUNE
.row    ld a,(hl)
        cp 0FFh
        jr z,.end
        ld ix,MU_CH
        ld b,3
.n      ld a,(hl)
        inc hl
        or a
        jr z,.hold              ; 0: let it ring
        push hl
        add a,a
        ld l,a
        ld h,0
        ld de,F_STEPS
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (ix+0),e
        ld (ix+1),d
        ld a,(ix+3)
        ld (ix+2),a
        ld a,d
        or e
        jr nz,.nq
        ld (ix+2),0             ; 1: quiet
.nq     pop hl
.hold   inc ix
        inc ix
        inc ix
        inc ix
        djnz .n
        push hl
        call mus_row
        call f_keys
        pop hl
        jr z,.row
        push af
        call .off
        pop af
        or a
        ret
.end    call .off
        xor a
        ret
.off    xor a
        out (PORT_PIOB),a
        ld (spk),a
        jp tabblk

mus_row:
        ld a,MU_TICKS
        ld (mu_tk),a
        ld a,(MU_CH+8)
        ld (M_s3l+1),a
        ld a,(MU_CH+9)
        ld (M_s3h+1),a
        ld a,(MU_CH+10)
        ld (M_w3+1),a
        ld hl,(mu_a1)
        ld de,(MU_CH+0)
        ld a,(MU_CH+2)
        ld b,a
        exx
        ld hl,(mu_a2)
        ld de,(MU_CH+4)
        ld a,(MU_CH+6)
        ld b,a
        exx
.tick   ld c,0
.s      add hl,de               ; voice 1
        ld a,h
        cp b
        sbc a,a
        exx
        add hl,de               ; voice 2
        ld c,a
        ld a,h
        cp b
        sbc a,a
        or c
        ld c,a
        exx
        ld a,(mu_a3)            ; voice 3
M_s3l:  add a,0
        ld (mu_a3),a
        ld a,(mu_a3+1)
M_s3h:  adc a,0
        ld (mu_a3+1),a
M_w3:   cp 0
        sbc a,a
        exx
        or c
        exx
        and 40h
        out (PORT_PIOB),a
        dec c
        jp nz,.s
        ; the notes ring away
        ld a,b
        cp 21h
        jr c,.e1
        dec b
.e1     exx
        ld a,b
        cp 7
        jr c,.e2
        dec b
.e2     exx
        ld a,(M_w3+1)
        sub 3
        jr nc,.e3
        xor a
.e3     ld (M_w3+1),a
        ld a,(mu_tk)
        dec a
        ld (mu_tk),a
        jr nz,.tick
        ld (mu_a1),hl
        ld a,b
        ld (MU_CH+2),a
        exx
        ld (mu_a2),hl
        ld a,b
        ld (MU_CH+6),a
        exx
        ld a,(M_w3+1)
        ld (MU_CH+10),a
        ret

MU_CH:  ds 12                   ; per voice: step (w), width, width when struck
mu_a1:  dw 0
mu_a2:  dw 0
mu_a3:  dw 0
mu_tk:  db 0

; --------------------------------------------------------------------------
; f_test: the test card.  Writes two values to a cell of each video memory
;   and shows what reads back.  (The game itself never reads them.)
; --------------------------------------------------------------------------
TCELL   equ VRAM+400h+39        ; page 1, top right: not on show
f_test: xor a
        ld (f_ont),a
        ld b,CWHITE
        call cls
        ld a,BLK_ZONES
        call setblk
        ld hl,P_TEST
        call f_page
        call tabblk
        ; screen RAM
        ld hl,TCELL
        ld (hl),5Ah
        ld d,(hl)
        ld (hl),0A5h
        ld e,(hl)
        ld (hl),128
        ld a,8
        call .res
        ; screen RAM read with a PCG bank selected
        ld hl,TCELL
        ld (hl),5Ah
        ld a,X1C+13
        out (PORT_1C),a
        ld d,(hl)
        ld a,X1C
        out (PORT_1C),a
        ld (hl),0A5h
        ld a,X1C+13
        out (PORT_1C),a
        ld e,(hl)
        ld a,X1C
        out (PORT_1C),a
        ld (hl),128
        ld a,10
        call .res
        ; attribute RAM
        ld hl,TCELL
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld (hl),5Ah
        ld d,(hl)
        ld (hl),0A5h
        ld e,(hl)
        ld (hl),FONT_BANK
        ld a,X1C
        out (PORT_1C),a
        ld a,12
        call .res
        ; colour RAM
        ld hl,TCELL+800h
        ld a,40h
        out (PORT_08),a
        ld (hl),5Ah
        ld d,(hl)
        ld (hl),0A5h
        ld e,(hl)
        ld (hl),CWHITE
        xor a
        out (PORT_08),a
        ld a,14
        call .res
        ; PCG RAM: bank 12, glyph 127, a scanline that is never shown
        ld hl,PCGWIN+127*16+15
        ld a,X1C+FONT_BANK
        out (PORT_1C),a
        ld (hl),5Ah
        ld d,(hl)
        ld (hl),0A5h
        ld e,(hl)
        ld a,X1C
        out (PORT_1C),a
        ld a,16
        call .res
        ; two instructions nothing else uses: RRD and RLD
        ld hl,t_m
        ld (hl),20h
        ld a,84h
        rrd
        ld d,a
        ld e,(hl)
        ld hl,8042h
        ld (t_e),hl
        ld a,17
        call .res
        ld hl,t_m
        ld (hl),31h
        ld a,7Ah
        rld
        ld d,a
        ld e,(hl)
        ld hl,731Ah
        ld (t_e),hl
        ld a,18
        call .res
        ; RAM blocks 5-31: is each its own memory, low and high in the block?
        ld hl,0FFFFh
        ld (t_e),hl
        ld hl,0100h
        call ramtest
        push af
        ld hl,3F00h
        call ramtest
        pop de
        ld e,a
        ld a,19
        call .res
        ld hl,4100h
        call ramtest
        push af
        ld hl,7F00h
        call ramtest
        pop de
        ld e,a
        ld a,20
        call .res
        ; video writes made while a high RAM block is mapped
        ld hl,5AA5h
        ld (t_e),hl
        ld a,20
        call setblk
        ld hl,TCELL
        ld (hl),5Ah
        ld hl,PCGWIN+127*16+15
        ld a,X1C+FONT_BANK
        out (PORT_1C),a
        ld (hl),0A5h
        ld a,X1C
        out (PORT_1C),a
        call tabblk
        ld hl,TCELL
        ld d,(hl)
        ld (hl),128
        ld hl,PCGWIN+127*16+15
        ld a,X1C+FONT_BANK
        out (PORT_1C),a
        ld e,(hl)
        ld a,X1C
        out (PORT_1C),a
        ld a,21
        call .res
        ld hl,5AA5h
        ld (t_e),hl
        call wait_space
        call f_test2
        jp wait_space
; .res: A = row, D, E = the two values read: show them and a verdict
.res    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,30
        add hl,bc
        push de
        ex de,hl                ; DE = screen offset
        pop hl                  ; H, L = the values
        push hl
        ld a,h
        call .hex
        inc de
        pop hl
        push hl
        ld a,l
        call .hex
        inc de
        pop hl
        ld a,(t_e+1)
        cp h
        jr nz,.no
        ld a,(t_e)
        cp l
        jr nz,.no
        ld hl,T_OK
        ld b,CBGREEN
        jp printc
.no     ld hl,T_NO
        ld b,CBRED
        jp printc
.hex    push af
        rrca
        rrca
        rrca
        rrca
        call .dig
        pop af
.dig    and 15
        add a,'0'
        cp '9'+1
        jr c,.d9
        add a,7
.d9     ld b,CWHITE
        push de
        call putch
        pop de
        inc de
        ret
; f_test2: the sprite data exactly as this machine holds it
f_test2:
        ld b,CWHITE
        call cls
        ld hl,T2_HEAD
        ld de,40
        ld b,CYELLOW
        call printc
        ; sums of ART.BIN (7840 bytes) and the tileset (5000h bytes)
        ld a,BLK_ART
        call setblk
        ld hl,0
        ld bc,7840
        call t2sum
        ld (t_s1),de
        ld a,BLK_PCG
        call setblk
        ld hl,0
        ld bc,5000h
        call t2sum
        ld (t_s2),de
        call tabblk
        ld hl,T2_SUMS
        ld de,3*40
        ld b,CBCYAN
        call printc
        ld hl,t_s1
        ld de,3*40+9
        ld b,2
        call t2hex
        ld hl,t_s2
        ld de,3*40+20
        ld b,2
        call t2hex
        ; image 0 (key) size 15, then image 1 (pie) size 15
        ld a,0
        ld de,5*40
        call t2img
        ld a,1
        ld de,12*40
        call t2img
        ld a,7
        ld de,19*40
        jp t2img
; t2sum: HL = start, BC = length (lower window) -> DE = 16 bit sum
t2sum:  ld de,0
.l      ld a,(hl)
        add a,e
        ld e,a
        jr nc,.n
        inc d
.n      inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret
; t2hex: HL -> B bytes, shown as hex at screen offset DE (colour white)
t2hex:  ld a,(hl)
        inc hl
        push hl
        push bc
        push af
        rrca
        rrca
        rrca
        rrca
        call t2dig
        pop af
        call t2dig
        pop bc
        pop hl
        djnz t2hex
        ret
t2dig:  and 15
        add a,'0'
        cp '9'+1
        jr c,.d9
        add a,7
.d9     ld b,CWHITE
        push de
        call putch
        pop de
        inc de
        ret
; t2img: A = image, DE = screen offset: its size-15 directory entry, the
;   first 32 plain bytes and the first 32 shifted bytes
t2img:  ld (t_ds),de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,15
        add hl,bc
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,SPRDIR
        add hl,bc
        ld a,BLK_PCG
        call setblk
        ld de,t_dir
        ld bc,8
        ldir
        call tabblk
        ld hl,t_dir
        ld de,(t_ds)
        ld b,8
        call t2hex
        ld ix,t_dir
        ld a,(ix+D_BLK)
        call setblk
        ld l,(ix+D_B0)
        ld h,(ix+D_B0+1)
        ld de,t_buf
        ld bc,32
        ldir
        ld l,(ix+D_B1)
        ld h,(ix+D_B1+1)
        ld bc,32
        ldir
        call tabblk
        ld hl,t_buf
        ld a,1
        call t2row
        ld hl,t_buf+16
        ld a,2
        call t2row
        ld hl,t_buf+32
        ld a,3
        call t2row
        ld hl,t_buf+48
        ld a,4
        call t2row
        ret
; t2row: HL -> 16 bytes, shown on line A below (t_ds)
t2row:  ld de,(t_ds)
        ld b,a
.m      push hl
        ld hl,40
        add hl,de
        ex de,hl
        pop hl
        djnz .m
        ld b,16
        jp t2hex
t_s1:   dw 0
t_s2:   dw 0
t_ds:   dw 0
t_dir:  ds 8
t_buf:  ds 64
T2_HEAD: db "SPRITE DATA - PHOTO THIS PAGE",0
T2_SUMS: db "ART SUM",0
; ramtest: HL = offset: write its own number into each of blocks 5-31
;   there, read them back -> A = the first block that read back wrong, or FFh
ramtest:
        ld (t_o),hl
        ld ix,t_sv
        ld b,5
.w      ld a,b
        call setblk
        ld hl,(t_o)
        ld a,(hl)
        ld (ix+0),a
        ld (hl),b
        inc ix
        inc b
        ld a,b
        cp 32
        jr nz,.w
        ld c,0FFh
        ld b,31
.r      ld a,b
        call setblk
        ld hl,(t_o)
        ld a,(hl)
        cp b
        jr z,.g
        ld c,b
.g      dec b
        ld a,b
        cp 4
        jr nz,.r
        ld ix,t_sv
        ld b,5
.x      ld a,b
        call setblk
        ld hl,(t_o)
        ld a,(ix+0)
        ld (hl),a
        inc ix
        inc b
        ld a,b
        cp 32
        jr nz,.x
        push bc
        call tabblk
        pop bc
        ld a,c
        ret
t_e:    dw 5AA5h               ; the values a line should show (second, first)
t_m:    db 0
t_o:    dw 0
t_sv:   ds 27
T_OK:   db "OK",0
T_NO:   db "NO",0
