; =====================================================================
;  SOUTHERN CROSS  -  Stage 3: area files from disk, Coral Coast
;  Microbee Premium Plus (32K PCG), runs from the CP/M DOS prompt
;  VIBED BY BPM 2026
; ---------------------------------------------------------------------
;  Screen: 64x16, 8x16 cells (512x256).  Rows 0-7 = 512x128 3D view
;  built from PCG cells, rows 8-15 = text instrument panel.
;  View cells are arranged as four vertical strips of 16x8 cells; each
;  strip lives in one 2K PCG bank, so a pixel column is a contiguous
;  128-byte run and moving up/down a line is just INC/DEC L.
;  Double buffered: page A (screen F000, banks 1-4) and page B
;  (screen F400, banks 5-8), flipped with the 6545 start address.
; =====================================================================

        org 0100h

CRTCA   equ 0Ch
CRTCD   equ 0Dh
LATCH   equ 1Ch                 ; Premium video latch
COLP    equ 08h                 ; bit 6: F800 window = colour RAM
ROMLAT  equ 0Bh                 ; 1 during keyboard scans
SCREEN  equ 0F000h
EXT     equ 80h                 ; extended PCG / attributes on
ATTRSEL equ 10h                 ; attribute RAM at F000
BANKA   equ 1
BANKB   equ 5
NEAR    equ 10                  ; near clip plane (half metres)
STALLV  equ 22                  ; stall speed m/s (43 kt)
ROTATE  equ 27                  ; rotate speed m/s (52 kt)
STKTOP  equ 7F00h

; Microbee keyboard scan codes
K_A     equ 1
K_D     equ 4
K_F     equ 6
K_G     equ 7
K_O     equ 15
K_P     equ 16
K_Q     equ 17
K_R     equ 18
K_N     equ 14
LOCBUF  equ 5000h
LOCEND  equ 7A00h
K_T     equ 20
K_SPC   equ 55

; =====================================================================
start:
        ld sp,STKTOP
        call loadloc            ; through CP/M, before taking over
        di
        call vinit
        call drawstatic
        ld a,'Z'
        ld (bestg),a
        call resetrwy
        ld a,(locok)
        or a
        ld hl,m_noloc
        call z,setmsg
        ld a,6
        ld (ticks),a
        ld a,2                  ; scenery on, ground grid off (D for more)
        ld (detail),a
mloop:
        call keys
        call vbpoll
        call physics
        call vbpoll
        call mkmatrix
        call clrback
        call vbpoll
        call render
        call vbpoll
        call panel
        call vbpoll
        call flip
        call timing
        jp mloop

; 6545 status bit 5 = vertical blank. Counts 50 Hz fields; must be
; called at least every ~10,000 T-states.
vbpoll: push af
        push hl
        in a,(CRTCA)
        and 20h
        ld hl,vblast
        cp (hl)
        jr z,vbp1
        ld (hl),a
        or a
        jr z,vbp1
        ld hl,fields
        inc (hl)
vbp1:   pop hl
        pop af
        ret

; =====================================================================
;  VIDEO
; =====================================================================
vinit:
        ld hl,crtctab
        ld c,0
vi1:    ld a,c
        out (CRTCA),a
        ld a,(hl)
        out (CRTCD),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,vi1
        ; colour RAM (F800 window): view white, title cyan, panel yellow
        ld a,EXT
        out (LATCH),a
        ld a,40h
        out (COLP),a
        ld hl,0F800h
        call colpage
        ld hl,0FC00h
        call colpage
        xor a
        out (COLP),a
        ; screen codes
        ld hl,SCREEN
        call scrcodes
        ld hl,SCREEN+400h
        call scrcodes
        ; attributes (PCG bank per cell)
        ld a,EXT+ATTRSEL
        out (LATCH),a
        ld hl,SCREEN
        ld e,BANKA
        call scrattr
        ld hl,SCREEN+400h
        ld e,BANKB
        call scrattr
        ld a,EXT
        out (LATCH),a
        ; clear PCG banks 1-8
        ld c,1
vi2:    ld a,c
        call clrbank
        inc c
        ld a,c
        cp 9
        jr nz,vi2
        xor a
        ld (front),a
        ld a,BANKB
        ld (backbank),a
        ld hl,SCREEN+400h
        ld (backscr),hl
        ld hl,rngb
        ld (rngback),hl
        ld hl,rnga              ; nothing drawn yet: empty row ranges
        ld b,8
vi3:    ld (hl),0FFh
        inc hl
        ld (hl),0
        inc hl
        djnz vi3
        ret

; HL = colour page base (1024 cells)
colpage:
        ld b,0
cp1:    ld (hl),0Fh             ; rows 0-7: 512 cells
        inc hl
        ld (hl),0Fh
        inc hl
        djnz cp1
        ld b,64
cp2:    ld (hl),0Eh             ; row 8: title
        inc hl
        djnz cp2
        ld b,0
cp3:    ld (hl),0Bh             ; rows 9-15: 448 cells
        inc hl
        djnz cp3
        ld b,192
cp4:    ld (hl),0Bh
        inc hl
        djnz cp4
        ret

; HL = page base. View rows get strip-ordered PCG codes, panel = spaces
scrcodes:
        ld c,0
sc1:    ld b,0
sc2:    ld a,b
        and 15
        add a,a
        add a,a
        add a,a
        add a,c
        or 80h
        ld (hl),a
        inc hl
        inc b
        ld a,b
        cp 64
        jr nz,sc2
        inc c
        ld a,c
        cp 8
        jr nz,sc1
        ld (hl),20h
        ld d,h
        ld e,l
        inc de
        ld bc,511
        ldir
        ret

; HL = page base, E = first bank
scrattr:
        ld c,8
sa1:    ld b,0
sa2:    ld a,b
        rrca
        rrca
        rrca
        rrca
        and 3
        add a,e
        ld (hl),a
        inc hl
        inc b
        ld a,b
        cp 64
        jr nz,sa2
        dec c
        jr nz,sa1
        ld (hl),0
        ld d,h
        ld e,l
        inc de
        ld bc,511
        ldir
        ret

; A = bank. Zero F800-FFFF of that bank with PUSH (preserves C,E)
clrbank:
        or EXT
        out (LATCH),a
        call vbpoll
        ld hl,0
        ld (savsp),sp
        ld sp,0                 ; upper 1K
        ld b,32
cbk1:
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        djnz cbk1
        ld sp,(savsp)
        call vbpoll
        ld (savsp),sp
        ld sp,0FC00h            ; lower 1K
        ld b,32
cbk2:
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        djnz cbk2
        ld sp,(savsp)
        jp vbpoll

; ---------------------------------------------------------------------
;  Clear the back buffer: per strip, only rows ymin..ymax that were drawn
;  on (recorded by dmark), with PUSH runs down each byte column.
; ---------------------------------------------------------------------
clrback:
        ld hl,(rngback)
        ld a,(backbank)
        ld (cbank),a
        ld b,4
cbs1:   push bc
        ld e,(hl)               ; E = ymin, D = ymax
        ld (hl),0FFh
        inc hl
        ld d,(hl)
        ld (hl),0
        inc hl
        push hl
        ld a,d
        cp e
        jr c,cbs2               ; nothing drawn in this strip
        ld a,(cbank)
        or EXT
        out (LATCH),a
        call vbpoll
        ld a,d                  ; len = ymax-ymin+1
        sub e
        inc a
        ld c,a
        inc d                   ; top = ymax+1
        bit 0,c
        jr z,cbs3
        inc c                   ; odd: one extra row, below unless ymin = 0
        ld a,e
        or a
        jr nz,cbs3
        inc d
cbs3:   srl c                   ; pairs
        ld a,64
        sub c
        ld l,a
        ld h,0
        ld bc,pblk1
        add hl,bc
        ld (cjp1+1),hl
        ld bc,pblk2-pblk1
        add hl,bc
        ld (cjp2+1),hl
        call cstrip
cbs2:   ld hl,cbank
        inc (hl)
        pop hl
        pop bc
        djnz cbs1
        ret

; D = top row (exclusive), entry points patched: clear 16 byte columns
cstrip: ld (savsp),sp
        ld c,0F8h
        ld b,8
cst1:   ld h,c                  ; even column: (C<<8) + top
        ld l,d
        ld sp,hl
        ld hl,0
cjp1:   jp pblk1
pret1:  ld h,c                  ; odd column: (C<<8) + 128 + top
        ld a,d
        add a,80h
        ld l,a
        jr nc,cst2
        inc h
cst2:   ld sp,hl
        ld hl,0
cjp2:   jp pblk2
pret2:  inc c
        djnz cst1
        ld sp,(savsp)
        ret

pblk1:
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        jp pret1
pblk2:
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        jp pret2

; mark rows cy0..cy1 over strips of cx0..cx1 (cx0 <= cx1) as used
dmark:  ld a,(cy0)
        ld b,a
        ld a,(cy1)
        cp b
        jr nc,dmk1
        ld c,b
        ld b,a
        jr dmk2
dmk1:   ld c,a                  ; B = low row, C = high row
dmk2:   ld hl,(cx1)
        add hl,hl
        ld e,h                  ; strip of x1
        ld hl,(cx0)
        add hl,hl
        ld a,h                  ; strip of x0
        sub e
        neg
        inc a
        ld d,a                  ; strips to mark
        ld a,h
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,(rngback)
        add hl,de
        pop de
dmk3:   ld a,b
        cp (hl)
        jr nc,dmk4
        ld (hl),a
dmk4:   inc hl
        ld a,c
        cp (hl)
        jr c,dmk5
        ld (hl),a
dmk5:   inc hl
        dec d
        jr nz,dmk3
        ret

flip:
        ld a,(front)
        xor 1
        ld (front),a
        ld b,a
        ld a,12
        out (CRTCA),a
        ld a,b
        add a,a
        add a,a
        out (CRTCD),a
        ld a,13
        out (CRTCA),a
        xor a
        out (CRTCD),a
        ld a,b
        or a
        ld a,BANKB
        ld hl,SCREEN+400h
        ld de,rngb
        jr z,fl1
        ld a,BANKA
        ld hl,SCREEN
        ld de,rnga
fl1:    ld (backbank),a
        ld (backscr),hl
        ld (rngback),de
        ret

; =====================================================================
;  KEYBOARD (6545 light-pen scan)
; =====================================================================
; A = key code. Returns NZ if pressed.
keytst:
        ld c,a
        ld a,18
        out (CRTCA),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 3
        out (CRTCD),a
        ld a,19
        out (CRTCA),a
        ld a,c
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        out (CRTCD),a
        ld a,16
        out (CRTCA),a
        in a,(CRTCD)
        ld a,17
        out (CRTCA),a
        in a,(CRTCD)
        ld a,31
        out (CRTCA),a
        out (CRTCD),a
        ld b,0
kt1:    in a,(CRTCA)
        bit 7,a
        jr nz,kt2
        djnz kt1
kt2:    in a,(CRTCA)
        and 40h
        ret

keys:
        ld a,1
        out (ROMLAT),a
        call keys1
        xor a
        out (ROMLAT),a
        ret
keys1:
        xor a
        ld (pin),a
        ld (rin),a
        ld (lvl),a
        ld a,K_Q
        call keytst
        jr z,k1
        ld a,0FFh
        ld (pin),a
k1:     ld a,K_A
        call keytst
        jr z,k2
        ld a,1
        ld (pin),a
k2:     ld a,K_O
        call keytst
        jr z,k3
        ld a,0FFh
        ld (rin),a
k3:     ld a,K_P
        call keytst
        jr z,k4
        ld a,1
        ld (rin),a
k4:     call vbpoll
        ld a,K_T
        call keytst
        jr z,k5
        ld a,(thr)
        add a,4
        cp 101
        jr c,k4a
        ld a,100
k4a:    ld (thr),a
k5:     ld a,K_G
        call keytst
        jr z,k6
        ld a,(thr)
        sub 4
        jr nc,k5a
        xor a
k5a:    ld (thr),a
k6:     ld a,K_SPC
        call keytst
        jr z,k7
        ld a,1
        ld (lvl),a
k7:     ld a,K_D
        call keytst
        ld hl,dkey
        jr z,k8
        ld a,(hl)
        ld (hl),1
        or a
        jr nz,k9
        ld a,(detail)
        inc a
        cp 4
        jr c,k7a
        ld a,1
k7a:    ld (detail),a
        jr k9
k8:     ld (hl),0
k9:     ld a,K_N
        call keytst
        ld hl,nkey
        jr z,k9b
        ld a,(hl)
        ld (hl),1
        or a
        call z,nextfld
        jr k9c
k9b:    ld (hl),0
k9c:    ld a,K_R
        call keytst
        call nz,resetrwy
        ld a,K_F
        call keytst
        call nz,resetfin
        ret

; =====================================================================
;  FLIGHT MODEL  (each tick = 1/50 second)
; =====================================================================
resetrwy:
        ld hl,0
        ld (px),hl
        ld (alt),hl
        ld (vel),hl
        ld (pitch),hl
        ld (roll),hl
        ld (hdg),hl
        ld (vs),hl
        ld (gs),hl
        xor a
        ld (pxf),a
        ld (pzf),a
        ld (altf),a
        ld (thr),a
        ld (crashed),a
        ld (stall),a
        ld (bounces),a
        ld (crtimer),a
        inc a
        ld (ongnd),a
        xor a
        call rwplace
        ld hl,(px)
        ld (rollx),hl
        ld hl,(pz)
        ld (rollz),hl
        ret

resetfin:
        ld hl,0
        ld (roll),hl
        ld hl,80
        ld (alt),hl
        ld hl,35*256
        ld (vel),hl
        ld hl,-3*256
        ld (pitch),hl
        xor a
        ld (pxf),a
        ld (pzf),a
        ld (altf),a
        ld (crashed),a
        ld (stall),a
        ld (ongnd),a
        ld (bounces),a
        ld (crtimer),a
        ld a,22
        ld (thr),a
        ld a,1
        jp rwplace

physics:
        ld a,(crashed)
        or a
        jr z,phgo
        ld a,(crtimer)          ; 0 = frozen
        or a
        ret z
        ld hl,ticks
        sub (hl)
        jr c,phrs
        jr z,phrs
        ld (crtimer),a
        ret
phrs:   xor a
        ld (crtimer),a
        call resetfin
        ld hl,m_again
        jp setmsg
phgo:
        ld a,(ticks)
        ld b,a
ph1:    push bc
        call vbpoll
        call tick
        pop bc
        ld a,(crashed)
        or a
        ret nz
        djnz ph1
        ret

tick:
        ; ---- pitch input (0.25 unit per tick) ----
        ld a,(pin)
        or a
        jr z,tk2
        ld hl,(pitch)
        ld de,64
        bit 7,a
        jr z,tk1
        ld de,-64
tk1:    add hl,de
        ld (pitch),hl
tk2:
        ld a,(ongnd)
        or a
        jr nz,tkgs
        ; ---- roll input (0.5 unit per tick) ----
        ld a,(rin)
        or a
        jr z,tk4
        ld hl,(roll)
        ld de,128
        bit 7,a
        jr z,tk3
        ld de,-128
tk3:    add hl,de
        ld (roll),hl
        ; ---- auto level (space) ----
tk4:    ld a,(lvl)
        or a
        jr z,tk6
        ld hl,(roll)
        bit 7,h
        jr nz,tk5n
        ld de,-128
        add hl,de
        jr c,tk5s
        ld hl,0
        jr tk5s
tk5n:   ld de,128
        add hl,de
        jr nc,tk5s
        ld hl,0
tk5s:   ld (roll),hl
        jr tk6
        ; ---- ground steering ----
tkgs:   ld hl,0
        ld (roll),hl
        ld a,(vel+1)
        or a
        jr z,tk6
        ld a,(rin)
        or a
        jr z,tk6
        ld hl,(hdg)
        ld de,80
        bit 7,a
        jr z,tkg1
        ld de,-80
tkg1:   add hl,de
        ld (hdg),hl
        ; ---- pitch limits ----
tk6:    ld hl,(pitch)
        ld a,h
        bit 7,a
        jr nz,tk7
        cp 42
        jr c,tk8
        ld hl,42*256
        jr tk8
tk7:    cp 0D6h                 ; -42
        jr nc,tk8
        ld hl,-42*256
tk8:    ld a,(ongnd)
        or a
        jr z,tk9
        bit 7,h
        jr z,tk8a
        ld hl,0
tk8a:   ld a,(vel+1)
        cp ROTATE
        jr nc,tk8b
        ld hl,0
tk8b:   ld a,h
        cp 12
        jr c,tk9
        ld hl,12*256
tk9:    ld (pitch),hl
        ; ---- stall: nose drops ----
        xor a
        ld (stall),a
        ld a,(ongnd)
        or a
        jr nz,tk10
        ld a,(vel+1)
        cp STALLV
        jr nc,tk10
        ld a,1
        ld (stall),a
        ld hl,(pitch)
        ld de,-40
        add hl,de
        ld (pitch),hl
tk10:
        ld a,(pitch+1)
        call sincos
        ld a,b
        ld (sinp),a
        ld a,c
        ld (cosp),a
        ; ---- speed: thrust - drag - friction - gravity ----
        ld a,(thr)              ; thrust = thr*26/256
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        ex de,hl
        add hl,de
        ex de,hl
        add hl,hl
        add hl,de
        ld l,h
        ld h,0
        push hl
        ld a,(vel+1)            ; drag = v*v*7/2048
        ld l,a
        ld h,0
        ld e,a
        ld d,0
        call mul16u8            ; HL = v*v
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld a,h
        rrca
        rrca
        rrca
        and 1Fh
        ld e,a
        ld d,0
        pop hl
        or a
        sbc hl,de
        ld de,2                 ; airborne: extra drag
        ld a,(ongnd)
        or a
        jr z,tka
        ld de,2                 ; rolling
        ld a,(thr)
        or a
        jr nz,tka
        ld de,12                ; brakes when throttle closed
tka:    or a
        sbc hl,de
        push hl
        ld a,(sinp)             ; gravity = sinp*25/64
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        add hl,de
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld de,(vel)
        add hl,de
        bit 7,h
        jr z,tkv1
        ld hl,0
tkv1:   ld a,h
        cp 90
        jr c,tkv2
        ld hl,90*256
tkv2:   ld (vel),hl
        ; ---- vertical speed / altitude ----
        ld a,(ongnd)
        or a
        jr z,tkair
        ld a,(pitch+1)
        or a
        jr z,tkvz
        ld a,(vel+1)
        cp ROTATE
        jr nc,tkair
tkvz:   ld hl,0
        ld (vs),hl
        jr tkhor
tkair:  ld hl,(vel)
        ld a,(sinp)
        call mul168
        ld (vs),hl
        call scale02
        ld bc,altf
        call add24
tkhor:  ; ---- horizontal movement ----
        ld hl,(vel)
        ld a,(cosp)
        call mul168
        ld (gs),hl
        ld a,(hdg+1)
        call sincos
        push bc
        ld hl,(gs)
        ld a,b
        call mul168
        call scale02
        ld bc,pxf
        call add24
        pop bc
        ld hl,(gs)
        ld a,c
        call mul168
        call scale02
        ld bc,pzf
        call add24
        ; ---- turning (airborne) ----
        ld a,(ongnd)
        or a
        jr nz,tkgc
        ld a,(roll+1)
        call sincos
        ld a,c
        ld (cosr),a
        ld a,b                  ; dh = 22*sin(roll)/v
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,de
        ld a,(vel+1)
        cp 10
        jr nc,tkt1
        ld a,10
tkt1:   call sdiv168
        ld de,(hdg)
        add hl,de
        ld (hdg),hl
        ld a,(cosr)             ; banking costs lift: nose sinks
        ld b,a
        ld a,127
        sub b
        srl a
        srl a
        srl a
        ld e,a
        ld d,0
        ld hl,(pitch)
        or a
        sbc hl,de
        ld (pitch),hl
        ; ---- altitude ceiling ----
        ld hl,(alt)
        ld de,9999
        or a
        sbc hl,de
        jr c,tkgc
        jr z,tkgc
        bit 7,h
        jr nz,tkgc
        ld (alt),de
        ; ---- ground contact ----
tkgc:   ld a,(alt+1)
        bit 7,a
        jr z,tkab
        ld a,(ongnd)
        or a
        jr nz,tkld
        call touch              ; 0 landed, 1 bounce, 2 crash
        or a
        jr z,tkld0
        dec a
        jp z,bounce
        jr tkcr
tkld0:  call landed
tkld:   xor a
        ld (altf),a
        ld hl,0
        ld (alt),hl
        ld (vs),hl
        ld (roll),hl
        inc a
        ld (ongnd),a
        ret
tkab:   ld a,(alt)
        ld hl,alt+1
        or (hl)
        ld hl,altf
        or (hl)
        jr z,tkst
        ld a,(ongnd)
        or a
        ret z
        xor a
        ld (ongnd),a
        ld (bounces),a
        jp liftoff
tkst:   ld a,(vel+1)            ; standing still: take-off roll starts here
        cp 3
        ret nc
        ld hl,(pz)
        ld (rollz),hl
        ld hl,(px)
        ld (rollx),hl
        ret
tkcr:   call crashmsg
        ld a,150                ; back on final after 3 seconds
        ld (crtimer),a
        ld a,1
        ld (crashed),a
        xor a
        ld (altf),a
        ld hl,0
        ld (alt),hl
        ld (vel),hl
        ld (vs),hl
        ld (gs),hl
        ret

; HL = signed 8.8 per-second value -> HL = value/51.2 (per tick, 8.8)
scale02:
        ld d,h
        ld e,l
        ld b,6
s02a:   sra d
        rr e
        djnz s02a
        push de
        sra d
        rr e
        sra d
        rr e
        push de
        sra d
        rr e
        pop hl
        add hl,de
        pop de
        add hl,de
        ret

; HL = signed 8.8 delta, BC -> 3-byte var (frac, lo, hi)
add24:
        ld e,h
        ld a,h
        rla
        sbc a,a
        ld d,a
        ld a,(bc)
        add a,l
        ld (bc),a
        inc bc
        ld a,(bc)
        adc a,e
        ld (bc),a
        inc bc
        ld a,(bc)
        adc a,d
        ld (bc),a
        ret

; =====================================================================
;  MATHS
; =====================================================================
; A = angle -> B = sin, C = cos (signed, scale 127)
sincos:
        ld h,sintab/256
        ld l,a
        ld b,(hl)
        add a,64
        ld l,a
        ld c,(hl)
        ret

neghl:
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; HL = signed 16, A = signed 8 (|A|<=127) -> HL = (HL*A)>>7
mul168:
        ld c,a
        xor h
        ld (msgn),a
        bit 7,h
        jr z,$+8
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld a,c
        bit 7,a
        jr z,ml1
        neg
ml1:    ld c,a
        ex de,hl
        ld hl,0
        srl c
        jr nc,$+3
        add hl,de
        rr h
        rr l
        srl c
        jr nc,$+3
        add hl,de
        rr h
        rr l
        srl c
        jr nc,$+3
        add hl,de
        rr h
        rr l
        srl c
        jr nc,$+3
        add hl,de
        rr h
        rr l
        srl c
        jr nc,$+3
        add hl,de
        rr h
        rr l
        srl c
        jr nc,$+3
        add hl,de
        rr h
        rr l
        srl c
        jr nc,$+3
        add hl,de
        rr h
        rr l
        ld a,(msgn)
        bit 7,a
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; A, B signed 8 -> HL = (A*B)>>7
mulw:
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld a,b
        jp mul168

; HL -> A clamped to -127..127
clampb:
        ld a,h
        or a
        jr z,clp1
        inc a
        jr z,clp2
        bit 7,h
        jr nz,clpm
clpp:   ld a,127
        ret
clpm:   ld a,-127
        ret
clp1:   ld a,l
        cp 128
        jr nc,clpp
        ret
clp2:   ld a,l
        cp 129
        jr c,clpm
        ret

; HL = unsigned 16 x E (unsigned 8) -> HL (low 16 bits)
mul16u8:
        ex de,hl
        ld a,l
        ld hl,0
        ld b,8
mu1:    add hl,hl
        rla
        jr nc,mu2
        add hl,de
mu2:    djnz mu1
        ret

; HL signed / A unsigned (>=1) -> HL signed
sdiv168:
        ld c,a
        ld a,h
        ld (msgn),a
        bit 7,h
        jr z,$+8
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld b,16
        xor a
sd1:    add hl,hl
        rla
        cp c
        jr c,sd2
        sub c
        inc l
sd2:    djnz sd1
        ld a,(msgn)
        bit 7,a
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; HL = signed numerator, DE = positive denominator
; -> HL = (num*256)/den clamped to +-15000
projdiv:
        ld a,h
        ld (dsgn),a
        bit 7,h
        jr z,$+8
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        or a
        sbc hl,de
        add hl,de
        jr nc,pdbig
        ld c,0                  ; |num| < den: 8-bit quotient is enough
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        add hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        ld l,c
        ld h,0
        jp pdsg
pdbig:  ld a,d
        cp 2
        jp nc,pdns
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        pop hl
        or a
        sbc hl,bc
        jp nc,pdsat
        add hl,bc
pdns:   ld a,l
        and 3Fh
        add a,a
        add a,a
        ld b,a
        ld c,0
        add hl,hl
        add hl,hl
        ld l,h
        ld h,0
        rl h
        sla c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,$+3
        add hl,de
        ccf
        rl c
        rl b
pd3:    ld h,b
        ld l,c
        ld de,15000
        or a
        sbc hl,de
        add hl,de
        jr c,pdsg
pdsat:  ld hl,15000
pdsg:   ld a,(dsgn)
        bit 7,a
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; HL = HL*0.672 (vertical pixel aspect for a 4:3 screen)
vscale:
        bit 7,h
        jr z,vsc1
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        call vsc1
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret
vsc1:   ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        ret

vsb:    call sexta
        call vscale
        ld a,l
        ret

absa:   bit 7,a
        ret z
        neg
        ret

; =====================================================================
;  CAMERA MATRIX  (stored column-major: col0 m00 m10 m20, ...)
; =====================================================================
mkmatrix:
        ld a,(hdg+1)
        call sincos
        ld a,b
        ld (sh),a
        ld a,c
        ld (ch),a
        ld a,(pitch+1)
        call sincos
        ld a,b
        ld (spp),a
        ld a,c
        ld (cpp),a
        ld a,(roll+1)
        call sincos
        ld a,b
        ld (sr),a
        ld a,c
        ld (cr),a
        ; forward row
        ld a,(sh)
        ld b,a
        ld a,(cpp)
        call mulw
        call clampb
        ld (m20),a
        ld a,(spp)
        ld (m21),a
        ld a,(ch)
        ld b,a
        ld a,(cpp)
        call mulw
        call clampb
        ld (m22),a
        ; pitched up row u = (-sh*sp, cp, -ch*sp)
        ld a,(sh)
        ld b,a
        ld a,(spp)
        call mulw
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        call clampb
        ld (u0),a
        ld a,(ch)
        ld b,a
        ld a,(spp)
        call mulw
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        call clampb
        ld (u2),a
        ; m00 = cr*ch - sr*u0
        ld a,(cr)
        ld b,a
        ld a,(ch)
        call mulw
        push hl
        ld a,(sr)
        ld b,a
        ld a,(u0)
        call mulw
        ex de,hl
        pop hl
        or a
        sbc hl,de
        call clampb
        ld (m00),a
        ; m01 = -sr*cp
        ld a,(sr)
        ld b,a
        ld a,(cpp)
        call mulw
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        call clampb
        ld (m01),a
        ; m02 = -cr*sh - sr*u2
        ld a,(cr)
        ld b,a
        ld a,(sh)
        call mulw
        push hl
        ld a,(sr)
        ld b,a
        ld a,(u2)
        call mulw
        pop de
        add hl,de
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        call clampb
        ld (m02),a
        ; m10 = sr*ch + cr*u0
        ld a,(sr)
        ld b,a
        ld a,(ch)
        call mulw
        push hl
        ld a,(cr)
        ld b,a
        ld a,(u0)
        call mulw
        pop de
        add hl,de
        call clampb
        ld (m10),a
        ; m11 = cr*cp
        ld a,(cr)
        ld b,a
        ld a,(cpp)
        call mulw
        call clampb
        ld (m11),a
        ; m12 = -sr*sh + cr*u2
        ld a,(cr)
        ld b,a
        ld a,(u2)
        call mulw
        push hl
        ld a,(sr)
        ld b,a
        ld a,(sh)
        call mulw
        ex de,hl
        pop hl
        or a
        sbc hl,de
        call clampb
        ld (m12),a
        ; keep true m11 for the horizon, then scale U row for 4:3 aspect
        ld a,(m11)
        ld (m11h),a
        ld a,(m10)
        call vsb
        ld (m10),a
        ld a,(m11)
        call vsb
        ld (m11),a
        ld a,(m12)
        call vsb
        ld (m12),a
        ; eye height term: col1 * -(alt+2)
        ld hl,(alt)
        add hl,hl
        ld a,(altf)
        rlca
        and 1
        ld e,a
        ld d,0
        add hl,de
        ld de,4
        add hl,de
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld (nege),hl
        ld a,(m01)
        call mul168
        ld (cyr),hl
        ld hl,(nege)
        ld a,(m11)
        call mul168
        ld (cyu),hl
        ld hl,(nege)
        ld a,(m21)
        call mul168
        ld (cyf),hl
        ret

; HL = component value, DE -> matrix column: v += value*column
addcol:
        ld (acv),hl
        ld a,(de)
        inc de
        push de
        call mul168
        ld de,(vr)
        add hl,de
        ld (vr),hl
        pop de
        ld hl,(acv)
        ld a,(de)
        inc de
        push de
        call mul168
        ld de,(vu)
        add hl,de
        ld (vu),hl
        pop de
        ld hl,(acv)
        ld a,(de)
        call mul168
        ld de,(vf)
        add hl,de
        ld (vf),hl
        ret

; (tx,ty,tz) -> (vr,vu,vf), skipping zero components
vxform:
        ld hl,0
        ld (vr),hl
        ld (vu),hl
        ld (vf),hl
        ld hl,(tx)
        ld a,h
        or l
        jr z,vx1
        ld de,m00
        call addcol
vx1:    ld hl,(ty)
        ld a,h
        or l
        jr z,vx2
        ld de,m01
        call addcol
vx2:    ld hl,(tz)
        ld a,h
        or l
        ret z
        ld de,m02
        jp addcol

rdvec:  ld de,tx
        ld bc,6
        ldir
        ret

; =====================================================================
;  SCENE
; =====================================================================
render:
        call horizon
        ld a,(detail)
        cp 3
        jr c,rn0
        call ggrid
rn0:    call drawloc
        jp reticle

        include_ggrid
        include_stage2
        include_stage3
; Series: sx,sy,sz, tx,ty,tz (step), lx,ly,lz (segment), n
; Draws n segments: P(k) -> P(k)+L,  P(k) = S + k*T
dser:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(px)
        ex de,hl
        or a
        sbc hl,de
        ld a,h
        add a,24
        cp 48
        jp nc,dsfail
        add hl,hl
        ld a,(pxf)
        rlca
        and 1
        jr z,ds1
        dec hl
ds1:    ld (tx),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ty),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(pz)
        ex de,hl
        or a
        sbc hl,de
        ld a,h
        add a,24
        cp 48
        jp nc,dsfail
        add hl,hl
        ld a,(pzf)
        rlca
        and 1
        jr z,ds2
        dec hl
ds2:    ld (tz),hl
        call vxform
        ld hl,(vr)
        ld de,(cyr)
        add hl,de
        ld (cvr),hl
        ld hl,(vu)
        ld de,(cyu)
        add hl,de
        ld (cvu),hl
        ld hl,(vf)
        ld de,(cyf)
        add hl,de
        ld (cvf),hl
        pop hl
        call rdvec
        push hl
        call vxform
        ld hl,vr
        ld de,svec
        ld bc,6
        ldir
        pop hl
        call rdvec
        ld a,(hl)
        ld (scount),a
        call vxform
        ld hl,vr
        ld de,lvec
        ld bc,6
        ldir
dsl:    call vbpoll
        ld hl,cvr
        ld de,sega
        ld bc,6
        ldir
        ld hl,(cvr)
        ld de,(lvec)
        add hl,de
        ld (segb),hl
        ld hl,(cvu)
        ld de,(lvec+2)
        add hl,de
        ld (segb+2),hl
        ld hl,(cvf)
        ld de,(lvec+4)
        add hl,de
        ld (segb+4),hl
        call segment
        ld hl,(cvr)
        ld de,(svec)
        add hl,de
        ld (cvr),hl
        ld hl,(cvu)
        ld de,(svec+2)
        add hl,de
        ld (cvu),hl
        ld hl,(cvf)
        ld de,(svec+4)
        add hl,de
        ld (cvf),hl
        ld hl,scount
        dec (hl)
        jr nz,dsl
        ret
dsfail: pop hl
        ret


; ---------------------------------------------------------------------
;  Lattice object: shared vertices, each transformed/projected once.
;  ox(m), oy(half m), oz(m) / nx,X.. / ny,Y.. / nz,Z.. (half m words)
;  nv, verts (ix,iy,iz bytes) / ne, edges (a,b bytes)
; ---------------------------------------------------------------------
dobj:   call vbpoll
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(px)
        ex de,hl
        or a
        sbc hl,de
        ld a,h
        add a,24
        cp 48
        jp nc,dsfail
        add hl,hl
        ld a,(pxf)
        rlca
        and 1
        jr z,do1
        dec hl
do1:    ld (tx),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ty),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(pz)
        ex de,hl
        or a
        sbc hl,de
        ld a,h
        add a,24
        cp 48
        jp nc,dsfail
        add hl,hl
        ld a,(pzf)
        rlca
        and 1
        jr z,do2
        dec hl
do2:    ld (tz),hl
        call vxform
        ld hl,(vr)
        ld de,(cyr)
        add hl,de
        ld (cvr),hl
        ld hl,(vu)
        ld de,(cyu)
        add hl,de
        ld (cvu),hl
        ld hl,(vf)
        ld de,(cyf)
        add hl,de
        ld (cvf),hl
        pop hl
        ; axis tables
        ld de,m00
        ld bc,axx
        call axtab
        ld de,m01
        ld bc,axy
        call axtab
        ld de,m02
        ld bc,axz
        call axtab
        call vbpoll
        ; vertices: nv, nv when far (the far ones come first)
        ld a,(hl)
        inc hl
        ld b,a
        ld a,(hl)
        inc hl
        call lodpick            ; A = count to use, (lskip) = bytes to skip
        ld (vcnt),a
        ld a,0
        ld (vidx),a
dov1:   call vbpoll
        push hl
        ld hl,(cvr)
        ld (vr),hl
        ld hl,(cvu)
        ld (vu),hl
        ld hl,(cvf)
        ld (vf),hl
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld hl,axx
        call addax
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld hl,axy
        call addax
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld hl,axz
        call addax
        ld a,(vidx)
        ld hl,vbuf
        call idx6
        ex de,hl
        ld hl,vr
        ld bc,6
        push de
        ldir
        pop hl
        push hl
        call fastin
        pop hl
        ld c,0
        jr c,dovin
        push hl
        ld b,3
        ld c,0
        call sgs1
        pop hl
        ld de,hT
        ld bc,dT
        call halfdist
        ld c,a
dovin:
        ld a,(vidx)
        ld e,a
        ld d,0
        ld hl,vcode
        add hl,de
        ld (hl),c
        ld a,c
        or a
        jr nz,dov2
        ld a,(vidx)
        ld hl,vbuf
        call idx6
        call project
        push de
        push hl
        ld a,(vidx)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,vproj
        add hl,de
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
dov2:   pop hl
        ld a,(vidx)
        inc a
        ld (vidx),a
        ld b,a
        ld a,(vcnt)
        cp b
        jp nz,dov1
        ld de,(lskip)
        add hl,de
        ; edges: ne, ne when far
        ld a,(hl)
        inc hl
        ld b,a
        ld a,(hl)
        inc hl
        call lodpick
        ld (vcnt),a
doe1:   call vbpoll
        ld a,(hl)
        inc hl
        ld (ea),a
        ld a,(hl)
        inc hl
        ld (eb),a
        push hl
        call doedge
        pop hl
        ld a,(vcnt)
        dec a
        ld (vcnt),a
        jr nz,doe1
        ret

doedge: ld a,(ea)
        call vcod
        ld c,a
        ld a,(eb)
        call vcod
        ld b,a
        and c
        ret nz
        ld a,b
        or c
        jr z,dog1
        ld a,(ea)
        ld hl,vbuf
        call idx6
        ld de,sega
        ld bc,6
        ldir
        ld a,(eb)
        ld hl,vbuf
        call idx6
        ld de,segb
        ld bc,6
        ldir
        jp segment
dog1:   ld a,(ea)
        call vpp
        ld de,cx0
        ld bc,2
        ldir
        ld de,cy0
        ld bc,2
        ldir
        ld a,(eb)
        call vpp
        ld de,cx1
        ld bc,2
        ldir
        ld de,cy1
        ld bc,2
        ldir
        jp fixdraw

vcod:   ld e,a
        ld d,0
        ld hl,vcode
        add hl,de
        ld a,(hl)
        ret

vpp:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,vproj
        add hl,de
        ret

; HL -> count + words; DE -> matrix column; BC -> 6-byte entries
; HL -> count, count when far, values.  Far: only the first values.
axtab:  push bc
        ld b,(hl)
        inc hl
        ld a,(lodfar)
        or a
        ld a,b
        jr z,axs1
        ld a,(hl)
axs1:   inc hl
        ld c,a
        ld a,b
        sub c
        add a,a
        ld (axskip),a
        ld a,c
        pop bc
        or a
        call nz,axt1
        push de
        ld a,(axskip)
        ld e,a
        ld d,0
        add hl,de
        pop de
        ret
axt1:   push af
        push bc
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        pop bc
        pop de
        push bc
        push de
        ld bc,0
        ld (vr),bc
        ld (vu),bc
        ld (vf),bc
        ld a,h
        or l
        call nz,addcol
        pop de
        pop hl
        pop bc
        push hl
        push de
        ld hl,vr
        ld d,b
        ld e,c
        ld bc,6
        ldir
        ld b,d
        ld c,e
        pop de
        pop hl
        pop af
        dec a
        jr nz,axt1
        ret

; A = index, HL -> 6-byte table: v += entry
addax:  call idx6
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(vr)
        add hl,de
        ld (vr),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(vu)
        add hl,de
        ld (vu),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(vf)
        add hl,de
        ld (vf),hl
        ret

; HL = base, A = index -> HL = base + 6*index
idx6:   push de
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        add hl,de
        pop de
        ret

; ---------------------------------------------------------------------
;  Camera-space segment sega -> segb.  One-pass 3D clip (Liang-Barsky)
;  to the view plus a 16 pixel margin (distances at half scale):
;    0  f >= NEAR        1  r <= 17f/16    2  r >= -17f/16
;    3  u <= 5f/16       4  u >= -5f/16
;  Interpolation is full precision, so rounding stays inside the margin
;  and edgefix then slides each end exactly onto the screen edge.
; ---------------------------------------------------------------------
segment:
        call vbpoll
        ld hl,(sega+4)          ; both behind the near plane? (cheap reject)
        ld de,-NEAR
        add hl,de
        bit 7,h
        jr z,sgf
        ld hl,(segb+4)
        add hl,de
        bit 7,h
        ret nz
sgf:    ld hl,sega              ; both ends plainly in view: no clipping
        call fastin
        jr nc,sgslow
        ld hl,segb
        call fastin
        jp c,sgdraw
sgslow: ld hl,sega              ; full scale if every |component| < 12288
        ld b,6
        ld c,0
        call sgs1
        ld hl,sega
        ld hl,sega
        ld de,hA
        ld bc,dA
        call halfdist
        ld (lcA),a
        ld hl,segb
        ld de,hB
        ld bc,dB
        call halfdist
        ld (lcB),a
        ld b,a
        ld a,(lcA)
        and b
        ret nz                  ; both outside one plane
        ld a,(lcA)
        or b
        jp z,sgdraw             ; both fully inside
        ld (lbm),a
        ld hl,0
        ld (tmin),hl
        ld hl,8000h
        ld (tmax),hl
        ld hl,dA
        ld (lbpa),hl
        ld hl,dB
        ld (lbpb),hl
lb1:    ld hl,lbm
        srl (hl)
        jr nc,lbnext
        ld hl,(lbpa)            ; DE = dA
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(lbpb)            ; BC = dB
        ld c,(hl)
        inc hl
        ld b,(hl)
        bit 7,d
        jr z,lbleave
        ; A outside, B inside: entering. t = -dA / (dB - dA)
        ld h,b
        ld l,c
        or a
        sbc hl,de
        ex de,hl                ; DE = den
        call neghl              ; HL = -dA
        call tdiv
        ex de,hl
        ld hl,(tmin)
        or a
        sbc hl,de
        jr nc,lbnext
        ld (tmin),de
        jr lbnext
lbleave:                        ; A inside, B outside: t = dA / (dA - dB)
        ld h,d
        ld l,e
        or a
        sbc hl,bc
        ex de,hl                ; DE = den, HL = dA
        call tdiv
        ex de,hl
        ld hl,(tmax)
        or a
        sbc hl,de
        jr c,lbnext
        ld (tmax),de
lbnext: ld hl,(lbpa)
        inc hl
        inc hl
        ld (lbpa),hl
        ld hl,(lbpb)
        inc hl
        inc hl
        ld (lbpb),hl
        ld a,(lbm)
        or a
        jr nz,lb1
        ld hl,(tmin)
        ld de,(tmax)
        or a
        sbc hl,de
        ret nc                  ; nothing left
        ; D = B - A (full scale, |D| unsigned + sign) ; keep the original A
        ld hl,segb
        ld de,sega
        ld bc,hD
        call dsub
        ld hl,segb+2
        ld de,sega+2
        ld bc,hD+3
        call dsub
        ld hl,segb+4
        ld de,sega+4
        ld bc,hD+6
        call dsub
        ld hl,sega
        ld de,sega0
        ld bc,6
        ldir
        ld de,(tmax)
        ld a,d
        cp 80h
        jr z,lb2
        ld hl,segb
        call interp
lb2:    ld de,(tmin)
        ld a,d
        or e
        jr z,sgdraw
        ld hl,sega
        call interp
sgdraw: ld hl,sega
        call project
        ld (cx0),hl
        ld (cy0),de
        ld hl,segb
        call project
        ld (cx1),hl
        ld (cy1),de
        ; fall through

; ---------------------------------------------------------------------
;  fixdraw: (cx0,cy0)-(cx1,cy1) lie within a small margin of the view.
;  Slide any end that is outside along the line onto the edge, draw.
; ---------------------------------------------------------------------
fixdraw:
        ld hl,cx0
        ld de,cx1
        call efix
        ret c
        ld hl,cx1
        ld de,cx0
        call efix
        ret c
        jp drawline

; HL -> this end (x,y), DE -> other end. Carry = line is not visible.
efix:   ld (efp),hl
        ld (efq),de
        ; ---- x ----
        call ldxy               ; BC = x, (efy) = y ; other: (eqx),(eqy)
        bit 7,b
        jr z,ef1
        ld hl,0                 ; x < 0 -> edge 0
        jr ef2
ef1:    ld a,b
        cp 2
        jr c,ef3
        ld hl,511               ; x > 511 -> edge 511
ef2:    ld (efe),hl
        ; y += (qy - y) * (e - x) / (qx - x)
        ld de,(eqx)
        ld h,b
        ld l,c
        ex de,hl
        or a
        sbc hl,de               ; HL = qx - x
        ld (efd),hl
        ld hl,(efe)
        or a
        sbc hl,bc               ; HL = e - x
        call efstep             ; carry if other end is on the same side
        ret c
        ld hl,(efy)
        add hl,de
        ld (efy),hl
        ld bc,(efe)
        call stxy
        call ldxy
ef3:    ; ---- y ----
        ld hl,(efy)
        bit 7,h
        jr z,ef4
        ld hl,0
        jr ef5
ef4:    ld a,h
        or a
        jr nz,ef4a
        ld a,l
        cp 128
        ccf
        ret nc
ef4a:   ld hl,127
ef5:    ld (efe),hl
        ld hl,(eqy)
        ld de,(efy)
        or a
        sbc hl,de               ; HL = qy - y
        ld (efd),hl
        ld hl,(efe)
        ld de,(efy)
        or a
        sbc hl,de               ; HL = e - y
        ld (efy2),bc
        ld bc,(eqx)
        ld (efq2),bc
        call efstepx            ; DE = x change
        ret c
        ld hl,(efy2)
        add hl,de
        ld b,h
        ld c,l
        ld hl,(efe)
        ld (efy),hl
        bit 7,b                 ; still off sideways -> not visible
        scf
        ret nz
        ld a,b
        cp 2
        ccf
        ret c
        call stxy
        or a
        ret

; HL = e - p (signed), (efd) = q - p.  Other-axis delta: (efy)/(eqy)
; DE = (q' - p') * (e - p) / (q - p).  Carry if q is not across the edge.
efstep: ld (efn),hl
        ld hl,(eqy)
        ld de,(efy)
        or a
        sbc hl,de
        jr efs0
efstepx:
        ld (efn),hl
        ld hl,(efq2)
        ld de,(efy2)
        or a
        sbc hl,de
efs0:   ld (efo),hl             ; other-axis delta
        ld hl,(efd)             ; need |e-p| <= |q-p| with same sign
        ld de,(efn)
        ld a,h
        xor d
        scf
        ret m                   ; opposite directions: q is on our side
        bit 7,h
        jr z,efs1
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ex de,hl
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ex de,hl
efs1:   or a                    ; HL = |q-p|, DE = |e-p|
        sbc hl,de
        ret c                   ; q is short of the edge too
        add hl,de
        ex de,hl                ; DE = |q-p| (den), HL = |e-p| (num)
        call tdiv               ; HL = fraction 0..8000h
        ld a,h                  ; clamp to 7FFFh for mulfu
        cp 80h
        jr c,efs2
        ld hl,7FFFh
efs2:   ex de,hl                ; DE = t
        ld hl,(efo)
        ld a,h
        ld (dsg),a
        bit 7,h
        jr z,$+8
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld b,h
        ld c,l
        call mulfu
        ld a,(dsg)
        bit 7,a
        jr z,$+8
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ex de,hl
        or a
        ret

; load this end -> BC = x, (efy) = y ; other end -> (eqx), (eqy)
ldxy:   ld hl,(efp)
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (efy),de
        ld hl,(efq)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (eqx),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (eqy),de
        ret

; store BC = x, (efy) = y into this end
stxy:   ld hl,(efp)
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld de,(efy)
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; (HL) - (DE) words -> BC: |difference| ; bit n of dsgn2 records sign
dsub:   ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        ld a,h                  ; HL = B, DE = A.  17-bit sign of B-A:
        xor d                   ; signs differ -> sign of B
        ld a,h
        jp m,dsb0
        or a
        sbc hl,de               ; same signs: no overflow, use bit 15
        ld a,h
        jr dsb2
dsb0:   or a
        sbc hl,de
dsb2:   and 80h
        ld (dsg),a
        jr z,dsb1
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
dsb1:   ld a,l
        ld (bc),a
        inc bc
        ld a,h
        ld (bc),a
        inc bc
        ld a,(dsg)
        ld (bc),a
        ret

; HL = x, DE = y -> clamped to 0..511, 0..127
clampxy:
        bit 7,h
        jr z,cx1a
        ld hl,0
        jr cx2a
cx1a:   ld a,h
        cp 2
        jr c,cx2a
        ld hl,511
cx2a:   bit 7,d
        jr z,cx3a
        ld de,0
        ret
cx3a:   ld a,d
        or a
        jr nz,cx4a
        ld a,e
        cp 128
        ret c
cx4a:   ld de,127
        ret

; HL -> B words: C counts components with |v| >= 12288, then sets scale
sgs1:   ld a,(hl)
        inc hl
        ld a,(hl)
        inc hl
        bit 7,a
        jr z,sgs2
        cpl
sgs2:   cp 30h
        jr c,sgs3
        inc c
sgs3:   djnz sgs1
; C = 0 -> full-scale distances, else half scale
setscale:
        ld a,c
        or a
        ld a,1
        ld hl,-NEAR
        jr z,ssc1
        xor a
        ld hl,-NEAR/2
ssc1:   ld (hfull),a
        ld (hnear),hl
        ret

; HL -> full-scale camera point, DE -> 6-byte half copy, BC -> 5 plane
; distances (words).  Returns A = outside mask (bit n = plane n).
halfdist:
        push bc
        ld c,(hl)               ; r/2 (or full scale)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hfull)
        or a
        jr nz,$+6
        sra b
        rr c
        ld (hr),bc
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
        ld c,(hl)               ; u/2 (or full scale)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hfull)
        or a
        jr nz,$+6
        sra b
        rr c
        ld (hu),bc
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
        ld c,(hl)               ; f/2 (or full scale)
        inc hl
        ld b,(hl)
        ld a,(hfull)
        or a
        jr nz,$+6
        sra b
        rr c
        ld (hf),bc
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        ld h,b                  ; kf = f + f/16
        ld l,c
        sra b
        rr c
        sra b
        rr c
        sra b
        rr c
        sra b
        rr c
        ld (hq2),bc             ; f/16
        add hl,bc
        ld (hq),hl
        pop hl                  ; HL -> distances
        ld c,0
        ; 0: f - NEAR/2
        push hl
        ld hl,(hf)
        ld de,(hnear)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,d
        rla
        rr c
        ; 1: kf - r
        push hl
        ld hl,(hq)
        ld de,(hr)
        or a
        sbc hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,d
        rla
        rr c
        ; 2: kf + r
        push hl
        ld hl,(hq)
        ld de,(hr)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,d
        rla
        rr c
        ; ku = f/4 + f/16
        push hl
        ld hl,(hf)
        sra h
        rr l
        sra h
        rr l
        ld de,(hq2)
        add hl,de
        ld (hq),hl
        ; 3: ku - u
        ld de,(hu)
        or a
        sbc hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,d
        rla
        rr c
        ; 4: ku + u
        push hl
        ld hl,(hq)
        ld de,(hu)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,d
        rla
        rr c
        ld a,c
        rrca
        rrca
        rrca
        and 1Fh
        ret

; HL = num, DE = den (unsigned, num <= den) -> HL = num*32768/den
tdiv:   or a
        sbc hl,de
        jr c,td0
        ld hl,8000h
        ret
td0:    add hl,de
        xor a
        ld c,a
        add hl,hl
        jr c,tdo0
        sbc hl,de
        jr nc,tdk0
        add hl,de
tdk0:  ccf
        rl c
        rla
        jp tdn0
tdo0:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn0:
        add hl,hl
        jr c,tdo1
        sbc hl,de
        jr nc,tdk1
        add hl,de
tdk1:  ccf
        rl c
        rla
        jp tdn1
tdo1:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn1:
        add hl,hl
        jr c,tdo2
        sbc hl,de
        jr nc,tdk2
        add hl,de
tdk2:  ccf
        rl c
        rla
        jp tdn2
tdo2:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn2:
        add hl,hl
        jr c,tdo3
        sbc hl,de
        jr nc,tdk3
        add hl,de
tdk3:  ccf
        rl c
        rla
        jp tdn3
tdo3:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn3:
        add hl,hl
        jr c,tdo4
        sbc hl,de
        jr nc,tdk4
        add hl,de
tdk4:  ccf
        rl c
        rla
        jp tdn4
tdo4:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn4:
        add hl,hl
        jr c,tdo5
        sbc hl,de
        jr nc,tdk5
        add hl,de
tdk5:  ccf
        rl c
        rla
        jp tdn5
tdo5:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn5:
        add hl,hl
        jr c,tdo6
        sbc hl,de
        jr nc,tdk6
        add hl,de
tdk6:  ccf
        rl c
        rla
        jp tdn6
tdo6:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn6:
        add hl,hl
        jr c,tdo7
        sbc hl,de
        jr nc,tdk7
        add hl,de
tdk7:  ccf
        rl c
        rla
        jp tdn7
tdo7:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn7:
        add hl,hl
        jr c,tdo8
        sbc hl,de
        jr nc,tdk8
        add hl,de
tdk8:  ccf
        rl c
        rla
        jp tdn8
tdo8:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn8:
        add hl,hl
        jr c,tdo9
        sbc hl,de
        jr nc,tdk9
        add hl,de
tdk9:  ccf
        rl c
        rla
        jp tdn9
tdo9:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn9:
        add hl,hl
        jr c,tdo10
        sbc hl,de
        jr nc,tdk10
        add hl,de
tdk10:  ccf
        rl c
        rla
        jp tdn10
tdo10:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn10:
        add hl,hl
        jr c,tdo11
        sbc hl,de
        jr nc,tdk11
        add hl,de
tdk11:  ccf
        rl c
        rla
        jp tdn11
tdo11:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn11:
        add hl,hl
        jr c,tdo12
        sbc hl,de
        jr nc,tdk12
        add hl,de
tdk12:  ccf
        rl c
        rla
        jp tdn12
tdo12:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn12:
        add hl,hl
        jr c,tdo13
        sbc hl,de
        jr nc,tdk13
        add hl,de
tdk13:  ccf
        rl c
        rla
        jp tdn13
tdo13:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn13:
        add hl,hl
        jr c,tdo14
        sbc hl,de
        jr nc,tdk14
        add hl,de
tdk14:  ccf
        rl c
        rla
        jp tdn14
tdo14:  ccf
        sbc hl,de
        scf
        rl c
        rla
tdn14:
        ld h,a
        ld l,c
        ret

; BC = unsigned magnitude, DE = 0..32767 -> HL = BC*DE/32768 (rounded)
mulfu:  ld hl,0
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        srl d
        rr e
        jr nc,$+3
        add hl,bc
        rr h
        rr l
        ret nc                  ; last bit shifted out = rounding
        inc hl
        ret

; DE = t, HL -> destination point: dest = sega0 + D*t
interp: ld (itt),de
        ld (idst),hl
        ld hl,hD
        ld (ioff),hl
        ld hl,sega0
        ld (isrc),hl
        ld a,3
        ld (icnt),a
ip1:    ld hl,(ioff)
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (ioff),hl
        ld (dsg),a
        ld de,(itt)
        call mulfu
        ld a,(dsg)
        or a
        jr z,$+8
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ex de,hl
        ld hl,(isrc)
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,de
        ex de,hl
        ld hl,(idst)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (idst),hl
        ld hl,(isrc)
        inc hl
        inc hl
        ld (isrc),hl
        ld hl,icnt
        dec (hl)
        jr nz,ip1
        ret

; HL -> (r,u,f).  Returns HL = screen x, DE = screen y
project:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pr),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pu),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (pf),de
        ld hl,(pr)
        call projdiv
        ld de,256
        add hl,de
        ld (psx),hl
        ld hl,(pu)
        ld de,(pf)
        call projdiv
        ex de,hl
        ld hl,64
        or a
        sbc hl,de
        ex de,hl
        ld hl,(psx)
        ret

; ---------------------------------------------------------------------
;  Horizon line straight from the matrix (true horizon, no altitude)
; ---------------------------------------------------------------------
horizon:
        ld a,(m11h)
        call absa
        ld c,a
        ld a,(m01)
        call absa
        cp c
        jr z,hzf
        jp nc,hzs
hzf:    ld a,(m21)              ; t0 = m21-m01, t1 = m21+m01, den = m11
        call sexta
        push hl
        ld a,(m01)
        call sexta
        ex de,hl
        pop hl
        push hl
        or a
        sbc hl,de
        ld (ht0),hl
        pop hl
        add hl,de
        ld (ht1),hl
        ld a,(m11h)
        call hzden
        ld hl,(ht0)
        ld de,(hden)
        call projdiv
        call vscale
        ld de,64
        add hl,de
        ld (cy0),hl
        ld hl,(ht1)
        ld de,(hden)
        call projdiv
        call vscale
        ld de,64
        add hl,de
        ld (cy1),hl
        ld (hzy1),hl
        ld hl,(cy0)
        ld (hzy0),hl
        ld a,1
        ld (hzfl),a
        ld hl,0
        ld (cx0),hl
        ld hl,511
        ld (cx1),hl
        jp clipdraw
hzs:    xor a
        ld (hzfl),a
        ld a,(m11h)              ; q = 3*m11/8 ; t0 = m21+q, t1 = m21-q
        call sexta
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ex de,hl
        ld a,(m21)
        call sexta
        push hl
        add hl,de
        ld (ht0),hl
        pop hl
        or a
        sbc hl,de
        ld (ht1),hl
        ld a,(m01)
        call hzden
        ld hl,(ht0)
        ld de,(hden)
        call projdiv
        ex de,hl
        ld hl,256
        or a
        sbc hl,de
        ld (cx0),hl
        ld hl,(ht1)
        ld de,(hden)
        call projdiv
        ex de,hl
        ld hl,256
        or a
        sbc hl,de
        ld (cx1),hl
        ld hl,0
        ld (cy0),hl
        ld hl,127
        ld (cy1),hl
        jp clipdraw

; A = signed denominator. Makes it positive (negating ht0/ht1 if needed)
hzden:
        bit 7,a
        jr z,hzd1
        neg
        push af
        ld hl,(ht0)
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld (ht0),hl
        ld hl,(ht1)
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld (ht1),hl
        pop af
hzd1:   or a
        jr nz,hzd2
        inc a
hzd2:   ld l,a
        ld h,0
        ld (hden),hl
        ret

sexta:  ld l,a
        add a,a
        sbc a,a
        ld h,a
        ret

reticle:
        ld hl,64
        ld (cy0),hl
        ld (cy1),hl
        ld hl,236
        ld (cx0),hl
        ld hl,250
        ld (cx1),hl
        call drawline
        ld hl,64
        ld (cy0),hl
        ld (cy1),hl
        ld hl,262
        ld (cx0),hl
        ld hl,276
        ld (cx1),hl
        call drawline
        ld hl,256
        ld (cx0),hl
        ld (cx1),hl
        ld hl,63
        ld (cy0),hl
        ld hl,65
        ld (cy1),hl
        jp drawline

; =====================================================================
;  2D CLIPPING  (midpoint subdivision, view 0-511 x 0-127)
; =====================================================================
; HL = x, DE = y -> A = outcode
outcode:
        ld c,0
        bit 7,h
        jr z,oc1
        set 0,c
        jr oc2
oc1:    ld a,h
        cp 2
        jr c,oc2
        set 1,c
oc2:    bit 7,d
        jr z,oc3
        set 2,c
        jr oc4
oc3:    ld a,d
        or a
        jr nz,oc5
        ld a,e
        cp 128
        jr c,oc4
oc5:    set 3,c
oc4:    ld a,c
        ret

; HL = a, DE = b -> carry if |a-b| <= 1
near1:
        or a
        sbc hl,de
        inc hl
        ld a,h
        or a
        ret nz
        ld a,l
        cp 3
        ret

small:
        ld hl,(cx0)
        ld de,(cx1)
        call near1
        ret nc
        ld hl,(cy0)
        ld de,(cy1)
        jp near1

clipdraw:
        ld hl,cstk
        ld (cstkp),hl
cdtop:  call vbpoll
        ld hl,(cx0)
        ld de,(cy0)
        call outcode
        ld (oc0),a
        ld hl,(cx1)
        ld de,(cy1)
        call outcode
        ld (oc1v),a
        ld b,a
        ld a,(oc0)
        or b
        jp z,cddraw
        ld a,(oc0)
        and b
        jp nz,cdpop
        call small
        jp c,cdpop
        ld hl,(cx0)
        ld de,(cx1)
        add hl,de
        sra h
        rr l
        ld (mx),hl
        ld hl,(cy0)
        ld de,(cy1)
        add hl,de
        sra h
        rr l
        ld (my),hl
        ex de,hl
        ld hl,(mx)
        call outcode
        or a
        jr z,cdmin
        ld b,a
        ld a,(oc0)
        and b
        jr z,cdn0
        ld hl,(mx)
        ld (cx0),hl
        ld hl,(my)
        ld (cy0),hl
        jp cdtop
cdn0:   ld a,(oc1v)
        and b
        jr z,cdsplit
        ld hl,(mx)
        ld (cx1),hl
        ld hl,(my)
        ld (cy1),hl
        jp cdtop
cdsplit:
        ld hl,(cstkp)
        ld de,cstkend
        or a
        sbc hl,de
        jr nc,cdsp1
        ld de,(cstkp)
        ld hl,mx
        ld bc,4
        ldir
        ld hl,cx1
        ld bc,4
        ldir
        ld (cstkp),de
cdsp1:  ld hl,(mx)
        ld (cx1),hl
        ld hl,(my)
        ld (cy1),hl
        jp cdtop
cdmin:  ld hl,(mx)
        ld (smx),hl
        ld hl,(my)
        ld (smy),hl
        ld a,(oc0)
        or a
        jr z,cdaok
        ld hl,(smx)
        ld (six),hl
        ld hl,(smy)
        ld (siy),hl
        ld hl,(cx0)
        ld (sox),hl
        ld hl,(cy0)
        ld (soy),hl
        call search
        ld hl,(six)
        ld (cx0),hl
        ld hl,(siy)
        ld (cy0),hl
cdaok:  ld a,(oc1v)
        or a
        jr z,cddraw
        ld hl,(smx)
        ld (six),hl
        ld hl,(smy)
        ld (siy),hl
        ld hl,(cx1)
        ld (sox),hl
        ld hl,(cy1)
        ld (soy),hl
        call search
        ld hl,(six)
        ld (cx1),hl
        ld hl,(siy)
        ld (cy1),hl
cddraw: call drawline
cdpop:  ld hl,(cstkp)
        ld de,cstk
        or a
        sbc hl,de
        ret z
        ld hl,(cstkp)
        ld de,-8
        add hl,de
        ld (cstkp),hl
        ld de,cx0
        ld bc,8
        ldir
        jp cdtop

; inside point (six,siy), outside point (sox,soy) -> boundary in six,siy
search:
srch1:  ld hl,(six)
        ld de,(sox)
        call near1
        jr nc,srch2
        ld hl,(siy)
        ld de,(soy)
        call near1
        ret c
srch2:  ld hl,(six)
        ld de,(sox)
        add hl,de
        sra h
        rr l
        ld (mx),hl
        ld hl,(siy)
        ld de,(soy)
        add hl,de
        sra h
        rr l
        ld (my),hl
        ex de,hl
        ld hl,(mx)
        call outcode
        or a
        ld hl,(mx)
        ld de,(my)
        jr nz,srch3
        ld (six),hl
        ld (siy),de
        jr srch1
srch3:  ld (sox),hl
        ld (soy),de
        jr srch1

; =====================================================================
;  LINE DRAWING into the back buffer (coords already inside the view)
; =====================================================================
drawline:
        call vbpoll
        ld hl,(cx0)
        ld de,(cx1)
        or a
        sbc hl,de
        jr c,dl1
        jr z,dl1
        ld hl,(cx0)
        ld (cx0),de
        ld (cx1),hl
        ld hl,(cy0)
        ld de,(cy1)
        ld (cy0),de
        ld (cy1),hl
dl1:    call dmark
        ld hl,(cx1)
        ld de,(cx0)
        or a
        sbc hl,de
        ld (ldx),hl
        ld a,h                  ; 256+ wide and sloping: draw as two
        or a                    ; halves so the 8-bit slope stays exact
        jr z,dl1b
        ld a,(cy0)
        ld hl,cy1
        cp (hl)
        jr z,dl1b
        ld hl,(cx1)
        push hl
        ld hl,(cy1)
        push hl
        ld hl,(cx0)             ; midpoint
        ld de,(cx1)
        add hl,de
        srl h
        rr l
        ld (cx1),hl
        ld a,(cy0)
        pop de
        push de
        add a,e
        rra                     ; (y0+y1)/2 (9-bit sum via carry)
        ld (cy1),a
        xor a
        ld (cy1+1),a
        call drawline
        ld hl,(cx1)
        ld (cx0),hl
        ld hl,(cy1)
        ld (cy0),hl
        pop hl
        ld (cy1),hl
        pop hl
        ld (cx1),hl
        jp drawline
dl1b:   ld a,(cy1)              ; very shallow (dx >= 40 dy): draw as runs
        ld hl,cy0
        sub (hl)
        jr nc,dlr0
        neg
dlr0:   cp 24                   ; short line: plain stepping, no set-up
        jr nc,dlr00
        ld b,a
        ld a,(ldx+1)
        or a
        jr nz,dlr00
        ld a,(ldx)
        cp 24
        jp c,dlshort
dlr00:  ld a,b
        or a
        jr z,dl1c
        cp 7
        jr nc,dl1c
        add a,a
        add a,a
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b                 ; 40 dy
        ld b,a
        ld a,(ldx+1)
        or a
        jp nz,dlrun
        ld a,(ldx)
        cp b
        jp nc,dlrun
dl1c:   ld a,(cy0)
        ld c,a
        ld a,(cy1)
        sub c
        ld d,2Ch                ; INC L
        jr nc,dl2
        neg
        ld d,2Dh                ; DEC L
dl2:    ld (lady),a
        ld a,d
        ld (ymys),a
        ld (xrow),a
        ld hl,(cx0)
        ld a,l
        rla
        ld a,h
        rla
        and 3
        ld b,a
        ld a,(backbank)
        add a,b
        or EXT
        ld (curbank),a
        out (LATCH),a
        ld a,l
        and 7
        ld e,a
        ld d,0
        push hl
        ld hl,masktab
        add hl,de
        ld a,(hl)
        ld (lmask),a
        pop hl
        ld a,l
        rrca
        rrca
        rrca
        and 15
        ld b,a
        srl a
        add a,0F8h
        ld h,a
        ld a,b
        rrca
        and 80h
        or c
        ld l,a
        ld a,(lmask)
        ld c,a
        ld a,(lady)
        or a
        jp z,dlh
        ld de,(ldx)
        ld a,d
        or a
        jr nz,dlx
        ld a,(lady)
        cp e
        jr z,dlx
        jr nc,dly
dlx:    push hl
        push bc
        ld a,d
        or e
        jr z,dlx2
        ld a,(lady)
        call slopediv
dlx2:   pop bc
        call xmfix              ; D = slope, (xacc) = start, never overshoots
        pop hl
        call xmpatch            ; set the 8 row-step opcodes
        push hl
        ld hl,(ldx)             ; count = dx+1 -> B low, C outer
        inc hl
        ld b,l
        ld c,h
        ld a,l
        or a
        jr z,dlx3
        inc c
dlx3:   ld a,(cx0)              ; entry block = x0 & 7
        and 7
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,xmtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ex (sp),hl              ; stack: entry, HL = address
        ld a,(xacc)
        ret                     ; jump to the entry block
dly:    push hl
        push bc
        ld a,(lady)
        ld l,a
        ld h,0
        ld a,e
        ex de,hl
        call slopediv
        pop bc
        pop hl
        ld d,a
        ld e,80h
        ld a,(lady)
        inc a
        ld b,a
        jp ymloop

; HL / A (unsigned) -> HL
div16u8:
        ld c,a
        xor a
        ld b,16
dv1:    add hl,hl
        rla
        jr c,dv2
        cp c
        jr c,dv3
dv2:    sub c
        inc l
dv3:    djnz dv1
        ret

; A = n, DE = d (>=1) -> A = n*256/d (255 if n >= d)
slopediv:
        ld l,a
        ld h,0
        or a
        sbc hl,de
        jr c,sdv1
        ld a,255
        ret
sdv1:   add hl,de
        ld b,8
        ld c,0
sdv2:   add hl,hl
        or a
        sbc hl,de
        jr nc,sdv3
        add hl,de
        or a
        rl c
        djnz sdv2
        jr sdv4
sdv3:   scf
        rl c
        djnz sdv2
sdv4:   add hl,hl               ; round: remainder*2 >= d -> +1
        or a
        sbc hl,de
        ld a,c
        ret c
        inc a
        ret nz
        dec a
        ret

; x-major, unrolled: A = acc, D = slope, B/C = count, HL = address
xp0:    set 7,(hl)
        add a,d
        jr nc,$+3
xs0:    inc l
        dec b
        jr z,xz0
xp1:    set 6,(hl)
        add a,d
        jr nc,$+3
xs1:    inc l
        dec b
        jr z,xz1
xp2:    set 5,(hl)
        add a,d
        jr nc,$+3
xs2:    inc l
        dec b
        jr z,xz2
xp3:    set 4,(hl)
        add a,d
        jr nc,$+3
xs3:    inc l
        dec b
        jr z,xz3
xp4:    set 3,(hl)
        add a,d
        jr nc,$+3
xs4:    inc l
        dec b
        jr z,xz4
xp5:    set 2,(hl)
        add a,d
        jr nc,$+3
xs5:    inc l
        dec b
        jr z,xz5
xp6:    set 1,(hl)
        add a,d
        jr nc,$+3
xs6:    inc l
        dec b
        jr z,xz6
xp7:    set 0,(hl)
        add a,d
        jr nc,$+3
xs7:    inc l
        dec b
        jr z,xz7
xpnb:   ld e,a                  ; next byte column
        ld a,l
        add a,80h
        ld l,a
        ld a,e
        jp nc,xp0
        inc h
        jp nz,xp0
        ld h,0F8h               ; next strip
        ld a,(curbank)
        inc a
        ld (curbank),a
        out (LATCH),a
        call vbpoll
        ld a,e
        jp xp0
xz0:    dec c
        jp nz,xp1
        ret
xz1:    dec c
        jp nz,xp2
        ret
xz2:    dec c
        jp nz,xp3
        ret
xz3:    dec c
        jp nz,xp4
        ret
xz4:    dec c
        jp nz,xp5
        ret
xz5:    dec c
        jp nz,xp6
        ret
xz6:    dec c
        jp nz,xp7
        ret
xz7:    dec c
        jp nz,xpnb
        ret

xmtab:  dw xp0,xp1,xp2,xp3,xp4,xp5,xp6,xp7

; A = rounded slope. excess = s*dx - 256*dy; start acc = 128 - excess,
; or use s-1 if the excess is over 128.  -> D = slope, (xacc)
xmfix:  ld d,a
        ld e,a
        ld hl,(ldx)
        push de
        call mul16u8            ; HL = s*dx
        pop de
        ld a,(lady)
        ld b,a
        ld c,0                  ; BC = 256*dy
        or a
        sbc hl,bc
        ld a,80h
        jr c,xf1                ; no excess
        jr z,xf1
        ld a,h
        or a
        jr nz,xf2
        ld a,l
        cp 129
        jr nc,xf2
        ld a,80h
        sub l
        jr xf1
xf2:    dec d
        ld a,80h
xf1:    ld (xacc),a
        ret

; A = INC L / DEC L opcode in (xrow) -> patch the 8 row steps
xmpatch:
        ld a,(xrow)
        ld (xs0),a
        ld (xs1),a
        ld (xs2),a
        ld (xs3),a
        ld (xs4),a
        ld (xs5),a
        ld (xs6),a
        ld (xs7),a
        ret

; y-major
ymloop: ld a,(hl)
        or c
        ld (hl),a
ymys:   inc l
        ld a,e
        add a,d
        ld e,a
        jr nc,ym2
        rrc c
        jr c,ymbyte
ym2:    djnz ymloop
        ret
ymbyte: ld a,l
        add a,80h
        ld l,a
        jr nc,ym2
        inc h
        jr nz,ym2
        ld h,0F8h
        call vbpoll
        ld a,(curbank)
        inc a
        ld (curbank),a
        out (LATCH),a
        jr ym2

; horizontal line: whole bytes at a time
dlh:    ld de,(cx0)
        ld (spx0),de
        ld de,(cx1)
        ld (spx1),de
; span: OR pixels spx0..spx1 into the row at HL (HL = byte of spx0).
; Leaves HL at the byte of spx1.
span:   ld a,(spx0)
        and 7
        ld e,a
        ld d,0
        push hl
        ld hl,rmask
        add hl,de
        ld b,(hl)
        ld a,(spx1)
        and 7
        ld e,a
        ld hl,emask
        add hl,de
        ld c,(hl)
        ld hl,(spx1)
        call div8
        ld e,a
        ld hl,(spx0)
        call div8
        ld d,a
        ld a,e
        sub d
        pop hl
        jr nz,dlh1
        ld a,b
        and c
        or (hl)
        ld (hl),a
        ret
dlh1:   ld e,a
        ld a,b
        or (hl)
        ld (hl),a
dlh2:   dec e
        jr z,dlh4
        call nextbyte
        ld (hl),0FFh
        jr dlh2
dlh4:   call nextbyte
        ld a,c
        or (hl)
        ld (hl),a
        ret

; ---------------------------------------------------------------------
;  Shallow line (dx >= 40 dy) as dy+1 horizontal runs, filled a byte at a time.
;  Run k ends at x0 + (2k+1)*dx / (2dy).
; ---------------------------------------------------------------------
dlrun:  ld a,(cy1)
        ld hl,cy0
        sub (hl)
        ld b,1
        jr nc,drn1
        neg
        ld b,0FFh
drn1:   ld (rdy),a
        add a,a
        ld (rdy2),a             ; 2dy
        ld a,b
        ld (rsgn),a
        ld a,(cy0)
        ld (ry),a
        ld hl,(cx0)
        ld (spx0),hl
        ld hl,(ldx)             ; step: dx / dy  (quotient, remainder of 2dx / 2dy)
        add hl,hl
        ld a,(rdy2)
        call div16u8
        ld (rqs),hl
        ld (rrs),a
        ld hl,(ldx)             ; first end: dx / 2dy
        ld a,(rdy2)
        call div16u8
        ld (rr),a
        ld de,(cx0)
        add hl,de
        ld (rq),hl              ; x of the end of the current run
        xor a
        ld (rk),a
drnl:   ld a,(rk)
        ld hl,rdy
        cp (hl)
        ld hl,(rq)
        jr nz,drn2
        ld hl,(cx1)             ; last run ends at the line's end
drn2:   ld (spx1),hl
        ld hl,(spx0)
        ld a,(ry)
        call pxaddr
        call span
        ld a,(rk)
        ld hl,rdy
        cp (hl)
        ret z
        inc a
        ld (rk),a
        ld hl,(rq)              ; next start, next end
        inc hl
        ld (spx0),hl
        dec hl
        ld de,(rqs)
        add hl,de
        ld a,(rdy2)
        ld b,a
        ld a,(rrs)
        ld c,a
        ld a,(rr)
        add a,c
        cp b
        jr c,drn3
        sub b
        inc hl
drn3:   ld (rr),a
        ld (rq),hl
        ld a,(rsgn)
        ld b,a
        ld a,(ry)
        add a,b
        ld (ry),a
        jr drnl

; ---------------------------------------------------------------------
;  Short line (both spans under 24): Bresenham, one pixel at a time.
;  x runs left to right (drawline has already ordered the ends).
; ---------------------------------------------------------------------
dlshort:
        ld a,(cy1)
        ld hl,cy0
        sub (hl)
        ld d,2Ch                ; INC L
        jr nc,dsh1
        neg
        ld d,2Dh                ; DEC L
dsh1:   ld (rdy),a
        ld a,d
        ld (dshy1),a
        ld (dshy2),a
        ld hl,(cx0)
        ld a,(cy0)
        call pxaddr
        ld a,(cx0)
        and 7
        ld e,a
        ld d,0
        push hl
        ld hl,masktab
        add hl,de
        ld c,(hl)               ; C = pixel mask
        pop hl
        ld a,(ldx)
        ld b,a                  ; B = dx
        ld a,(rdy)
        ld e,a                  ; E = dy
        cp b
        jr nc,dshy
        ; x-major: dx+1 pixels
        ld a,b
        srl a
        ld d,a                  ; D = error
        inc b
dsx1:   ld a,(hl)
        or c
        ld (hl),a
        dec b
        ret z
        rrc c                   ; x + 1
        call c,nextbyte
        ld a,d
        sub e
        ld d,a
        jr nc,dsx1
        ld a,(ldx)              ; error went negative: add dx, step y
        add a,d
        ld d,a
dshy1:  inc l
        jr dsx1
dshy:   ; y-major: dy+1 pixels
        ld a,e
        srl a
        ld d,a
        ld a,e
        inc a
        ld e,a                  ; E = count
dsy1:   ld a,(hl)
        or c
        ld (hl),a
        dec e
        ret z
dshy2:  inc l                   ; y +/- 1
        ld a,d
        sub b
        ld d,a
        jr nc,dsy1
        ld a,(rdy)
        add a,d
        ld d,a
        rrc c
        call c,nextbyte
        jr dsy1

; HL = x, A = y -> HL = byte address in the back page, bank selected
pxaddr: ld c,a
        ld a,l
        rla
        ld a,h
        rla
        and 3
        ld b,a
        ld a,(backbank)
        add a,b
        or EXT
        ld (curbank),a
        out (LATCH),a
        ld a,l
        rrca
        rrca
        rrca
        and 15
        ld b,a
        srl a
        add a,0F8h
        ld h,a
        ld a,b
        rrca
        and 80h
        or c
        ld l,a
        ret

; HL = 0..511 -> A = HL>>3
div8:   ld a,l
        srl h
        rra
        srl a
        srl a
        ret

nextbyte:
        ld a,l
        add a,80h
        ld l,a
        ret nc
        inc h
        ret nz
        ld h,0F8h
        ld a,(curbank)
        inc a
        ld (curbank),a
        out (LATCH),a
        jp vbpoll

rmask:  db 0FFh,7Fh,3Fh,1Fh,0Fh,07h,03h,01h
emask:  db 80h,0C0h,0E0h,0F0h,0F8h,0FCh,0FEh,0FFh

masktab:
        db 80h,40h,20h,10h,08h,04h,02h,01h

; =====================================================================
;  PANEL
; =====================================================================
drawstatic:
        ld de,SCREEN+512
        call drawst1
        ld de,SCREEN+400h+512
drawst1:
        ld hl,paneltext
        ld bc,512
        ldir
        ret

; DE = offset -> DE = backscr + offset (HL preserved)
fadr:   push hl
        ld hl,(backscr)
        add hl,de
        ex de,hl
        pop hl
        ret

; HL = unsigned value, DE = dest, B = width, C = pad char
pdec:   push de
        push bc
        ld de,numbuf
        ld bc,-10000
        call pdg
        ld bc,-1000
        call pdg
        ld bc,-100
        call pdg
        ld bc,-10
        call pdg
        ld a,l
        add a,'0'
        ld (de),a
        pop bc
        ld hl,numbuf
        ld e,4
pz1:    ld a,(hl)
        cp '0'
        jr nz,pz2
        ld (hl),c
        inc hl
        dec e
        jr nz,pz1
pz2:    ld a,5
        sub b
        ld e,a
        ld d,0
        ld hl,numbuf
        add hl,de
        pop de
        ld c,b
        ld b,0
        ldir
        ret
pdg:    ld a,'0'-1
pdg1:   inc a
        add hl,bc
        jr c,pdg1
        sbc hl,bc
        ld (de),a
        inc de
        ret

; HL = signed value, DE = dest, B = width incl. sign
psdec:  ld a,'+'
        bit 7,h
        jr z,ps1
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld a,'-'
ps1:    ld (de),a
        inc de
        dec b
        ld c,' '
        jr pdec

; A = signed angle units -> HL = degrees (signed)
angdeg: bit 7,a
        jr z,ang0
        neg
        call ang0
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret
ang0:   call sexta
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e
        add hl,de
        sra d
        rr e
        add hl,de
        sra d
        rr e
        sra d
        rr e
        add hl,de
        ret

; A = m/s -> HL = knots
knots:  ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld b,4
kn1:    srl h
        rr l
        djnz kn1
        ret

; HL -> zero terminated string, DE = offset in back page
pstr:   call fadr
ps2:    ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr ps2

panel:
        ld a,(vel+1)
        call knots
        ld de,F_IAS
        call fadr
        ld bc,3*256+' '
        call pdec
        ; altitude feet = m*3.28
        ld hl,(alt)
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        srl d
        rr e
        srl d
        rr e
        add hl,de
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        add hl,de
        ld de,F_ALT
        call fadr
        ld bc,5*256+' '
        call pdec
        ; heading
        ld a,(hdg+1)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        add hl,de
        srl d
        rr e
        add hl,de
        srl d
        rr e
        srl d
        rr e
        add hl,de
        ld de,F_HDG
        call fadr
        ld bc,3*256+'0'
        call pdec
        ; throttle
        ld a,(thr)
        ld l,a
        ld h,0
        ld de,F_THR
        call fadr
        ld bc,3*256+' '
        call pdec
        ; climb ft/min = vs*0.766
        ld hl,(vs)
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e
        or a
        sbc hl,de
        sra d
        rr e
        sra d
        rr e
        sra d
        rr e
        sra d
        rr e
        add hl,de
        ld de,F_VS
        call fadr
        ld b,6
        call psdec
        call vbpoll
        ; pitch and bank
        ld a,(pitch+1)
        call angdeg
        ld de,F_PIT
        call fadr
        ld b,4
        call psdec
        ld a,(roll+1)
        call angdeg
        ld de,F_BNK
        call fadr
        ld b,4
        call psdec
        ; ground speed
        ld a,(gs+1)
        call knots
        ld de,F_GS
        call fadr
        ld bc,3*256+' '
        call pdec
        ; status
        ld hl,s_crash
        ld a,(crashed)
        or a
        jr nz,pn1
        ld hl,s_stall
        ld a,(stall)
        or a
        jr nz,pn1
        ld hl,s_air
        ld a,(ongnd)
        or a
        jr z,pn1
        ld hl,s_gnd
pn1:    ld de,F_STAT
        call pstr
        ; fps and frames
        ld a,(fps)
        or a
        jr nz,pn2
        ld hl,s_nofps
        ld de,F_FPS
        call pstr
        jr pn3
pn2:    ld l,a
        ld h,0
        ld de,F_FPS
        call fadr
        ld bc,2*256+' '
        call pdec
pn3:    ld a,(detail)
        add a,'0'
        ld de,F_DET
        call fadr
        ld (de),a
        call pnappr
        ld hl,msgbuf
        ld de,F_MSG
        call fadr
        ld bc,62
        ldir
        ret

s_gnd:   db "ON GROUND   ",0
s_air:   db "AIRBORNE    ",0
s_stall: db "** STALL ** ",0
s_crash: db "CRASHED     ",0
s_nofps: db "--",0

; =====================================================================
;  TIMING  (frames per second from the MC146818 clock)
; =====================================================================
timing:
        call vbpoll
        ld hl,(frames)
        inc hl
        ld (frames),hl
        ld hl,secfr
        inc (hl)
        ld a,(fields)           ; game ticks = fields since last frame
        ld b,a
        ld a,(lastfr)
        ld c,a
        ld a,b
        sub c
        jr nz,tm1
        inc a
tm1:    cp 13
        jr c,tm2
        ld a,12
tm2:    ld (ticks),a
        ld a,b
        ld (lastfr),a
        ld a,(fsec)             ; 50 fields = one second
        ld c,a
        ld a,b
        sub c
        cp 50
        ret c
        ld a,c
        add a,50
        ld (fsec),a
        ld a,(secfr)
        ld (fps),a
        xor a
        ld (secfr),a
        ret

; B = full count, A = far count -> A = count to use, (lskip) = 3*(unused)
lodpick:
        ld c,a
        ld a,(lodfar)
        or a
        ld a,b
        ld de,0
        jr z,lp1
        sub c
        ld e,a
        add a,a
        add a,e
        ld e,a                  ; 3 bytes a vertex
        ld a,c
lp1:    ld (lskip),de
        ret

; HL -> view-space point (r,u,f words).  Carry if it is in front of the
; near plane and inside the view (|r| <= f, |u| <= f/4): no clip needed.
fastin: ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        bit 7,h
        jr nz,fifail
        ld a,h
        or a
        jr nz,fi1
        ld a,l
        cp NEAR
        jr c,fifail
fi1:    bit 7,d
        jr z,fi2
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
fi2:    push hl
        or a
        sbc hl,de
        pop hl
        jr c,fifail
        ld d,b
        ld e,c
        bit 7,d
        jr z,fi3
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
fi3:    srl h
        rr l
        srl h
        rr l
        or a
        sbc hl,de
        jr c,fifail
        scf
        ret
fifail: or a
        ret

; =====================================================================
;  DATA
; =====================================================================
crtctab:                        ; 64x16, 8x16 cells
        db 6Bh,40h,51h,37h,12h,09h,10h,12h,48h,0Fh,20h,0Fh,00h,00h,00h,00h


; ---------------------------------------------------------------------
