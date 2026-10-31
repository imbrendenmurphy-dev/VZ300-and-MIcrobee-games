        DEVICE NOSLOT64K
        include "defs.asm"

; ===================================================================== vars
        org $7800
fieldctr  db 0
lastcopy  db 0
ready     db 0
frame     db 0          ; game frame counter
rnd       dw $1234
camx      dw 0
camy      db 40
look      db 0
rlo       dw 0          ; world byte column held in ring slot rslot
rslot     db 0
sndph     dw 0
keys      db 0
keysold   db 0
kedge     db 0
joyok     db 0
; player
px16      dw 0
py16      dw 0
vx        db 0
vy        db 0
pstate    db 0
onground  db 0
coyote    db 0
jbuf      db 0
facing    db 0          ; 0 right, 1 left
pframe    db 0
panim     db 0
invuln    db 0
health    db 3
shield    db 0
idlet     db 0
burstt    db 0
landt     db 0
skidding  db 0
statet    db 0          ; generic timer for die/win
oldppy    db 0
ppx       dw 0          ; integer position scratch
ppy       db 0
ridedx    db 0
; game
lives     db 3
nstars    db 0
score     ds 3          ; BCD, high first
chkx      dw 0
chky      db 0
hudflag   db 0
gameover  db 0
levdone   db 0
starscan  db 0
nstarl    db 0
; sound
mus_ptr   dw 0
mus_t     db 0
mus_base  dw 0
sfx_t     db 0
sfx_n     dw 0
sfx_d     dw 0
sfx_noise db 0
curtone   dw 0
; scratch
tmp1      dw 0
tmp2      dw 0
tmp3      dw 0
gc_slot   db 0
gc_cnt    db 0
isrcnt    db 0
ecount    db 0
shake     db 0
; v0.2
levnum    db 0
levw      dw 0
bossmode  db 0
latchv    db LATBASE
demo      db 0
demoptr   dw 0
demot     db 0
mode      db 0          ; 0 story, 1 time attack
musoff    db 0          ; S toggles in-game music
tsec      dw 0          ; story-mode level clock (seconds left)
tsub      db 0
skey      db 0
timer     dw 0
lvrec:
lv_world  db 0
lv_flags  db 0          ; bit0 boss, bit1 mirrored ("The Way Back")
lv_w      dw 0
lv_sx     dw 0
lv_sy     db 0
lv_bossid db 0
lv_mapb   db 0
lv_map    dw 0
lv_entb   db 0
lv_ents   dw 0
lv_entslen dw 0
lv_songb  db 0
lv_song   dw 0
lv_songlen dw 0
lv_tilb   db 0
lv_tiles  dw 0
lv_attb   db 0
lv_attrs  dw 0
lv_enb    db 0
lv_en     dw 0
lv_bossb  db 0
lv_bossraw dw 0
          ds 7
stack_bottom:
        ASSERT stack_bottom <= $7A00, "vars overflow"
songbuf   equ $7A00         ; 512
ptab      equ $7C00         ; 16 frames x 2 dirs x 4 phases x 2
etab      equ $7D00         ; 15 x 2 x 4 x 2 = 240
qtab      equ $7DF0         ; 4 x 2
        org $7FF0
stack_top:

; ===================================================================== code
        org $8000
entry:
        di
        ld sp,stack_top
        jp boot                 ; one-time start-up code lives after the staging data
game_boot:
        xor a
        ld (demo),a
        ld (mode),a
        call load_level         ; World 1 tiles for the title screen
        ld hl,OVL_TITLE
        call ovl_call           ; A = 0 story, 1 demo, 2 time attack
        cp 2
        jp z,ta_start
        ld (demo),a
        call new_game
.lvl:   call level_start
        call game_loop          ; returns when level done / game over / demo ends
        call flush_frame
        ld a,(demo)
        or a
        jr nz,game_boot
        ld a,(gameover)
        or a
        jr nz,.over
        ld hl,OVL_CLEAR
        call ovl_call
        ld hl,levnum
        inc (hl)
        ld a,(hl)
        cp NLEVELS
        jr c,.lvl
        ld hl,OVL_ENDING
        call ovl_call
        jr .hisc
.over:  ld hl,OVL_OVER
        call ovl_call           ; A = 1 if the player continues
        or a
        jr nz,.cont
.hisc:  ld hl,OVL_HISC
        call ovl_call
        jp game_boot
.cont:
        ld a,3
        ld (lives),a
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (nstars),a
        jr .lvl

; ---------------------------------------------------------------- time attack
ta_start:
        ld a,1
        ld (mode),a
.menu:  ld hl,OVL_TAMENU
        call ovl_call           ; A = level number, or $FF to leave
        cp $FF
        jp z,game_boot
        push af
        call new_game
        pop af
        ld (levnum),a
        ld a,99
        ld (lives),a
        call level_start
        ld hl,0
        ld (timer),hl
        call game_loop
        call flush_frame
        ld hl,OVL_TARES
        call ovl_call
        jr .menu

ovl_call:                       ; HL = overlay entry
        push hl
        call load_overlay
        pop hl
        jp (hl)

joyports: db $2C,$29,$2E,$2D,$2B,$27
NJOYP   equ 6
joymask db 0
joy_read:
        ld a,(joymask)
        or a
        ret z
        push bc
        push de
        push hl
        ld d,a
        ld e,$1F
        ld hl,joyports
.p:     srl d
        jr nc,.n
        ld c,(hl)
        ld b,0
        in a,(c)
        or $E0
        and e
        ld e,a
.n:     inc hl
        ld a,d
        or a
        jr nz,.p
        ld a,e
        cpl
        and $1F
        pop hl
        pop de
        pop bc
        ret

; ---------------------------------------------------------------- ISR
; Fires at the start of field sync (INT is held for the 56 sync lines).
; If a finished back buffer is waiting (and 2 fields have passed), copy it to
; VRAM racing ahead of the beam (sync is over by the time we finish, so EI).
; Otherwise return with interrupts still disabled; the main loop calls
; maybe_ei once sync has ended.  This avoids burning the 56 sync lines.
isr:
        push af
        push bc
        push de
        push hl
        ld hl,fieldctr
        inc (hl)
        ld a,(ready)
        or a
        jr z,.noc
        ld a,(lastcopy)
        ld b,a
        ld a,(hl)
        sub b
        cp 2
        jr c,.noc
        ld a,(hl)
        ld (lastcopy),a
        ld hl,BBVIS
        ld de,VRAM+8*32
        ld a,PFROWS
        ld (isrcnt),a
.row:   call ldi32
        ld bc,BBW-32
        add hl,bc
        ; ---- sound tick (site 2)
        ld a,(sndph)
.tk2l:   add a,0
        ld (sndph),a
        ld a,(sndph+1)
.tk2h:   adc a,0
        ld (sndph+1),a
        and $C0                 ; 25% duty pulse: thinner, quieter than a square
        add a,$40
        sbc a,a
        and $21
.tk2x:   xor $20|LATBASE
        ld (LATCH),a
        ex (sp),hl              ; pad: keep the sample rate equal to draw_bg's
        ex (sp),hl
        inc hl
        dec hl
        nop
        ld a,(isrcnt)
        dec a
        ld (isrcnt),a
        jr nz,.row
        xor a
        ld (ready),a
        pop hl
        pop de
        pop bc
        pop af
        ei
        reti
.noc:   pop hl
        pop de
        pop bc
        pop af
        reti

maybe_ei:                       ; enable interrupts once field sync is over
        ld a,(LATCH)
        rla
        ret nc
        ei
        ret

ldi32:  REPT 32
        ldi
        ENDR
        ret

; ---------------------------------------------------------------- ring buffer
; gen_col: render world byte column HL into ring slot A for tile rows
;   (gc_r0 .. gc_r0+gc_nt-1).  All four pixel phases are written.
gc_r0   db 0
gc_nt   db 12
gen_col:
        ld (gc_slot),a
        push hl
        ; ix = RING + r0*8*RSTRIDE + slot
        ld a,(gc_r0)
        ld b,a
        ld ix,RING
        ld de,8*RSTRIDE
        or a
        jr z,.r0
.r1:    add ix,de
        djnz .r1
.r0:    ld a,(gc_slot)
        ld e,a
        ld d,0
        add ix,de
        pop hl
        ; map pointers: mA = MAP + (J>>1)*12 + r0 ; byte idx iA = J&1
        ld a,l
        and 1
        ld (gc_ia),a
        push hl
        srl h
        rr l
        call mul12
        ld de,MAP
        add hl,de
        ld a,(gc_r0)
        ld e,a
        ld d,0
        add hl,de
        ld (gc_ma),hl
        pop hl
        inc hl
        ld a,l
        and 1
        ld (gc_ib),a
        srl h
        rr l
        call mul12
        ld de,MAP
        add hl,de
        ld a,(gc_r0)
        ld e,a
        ld d,0
        add hl,de
        ld (gc_mb),hl
        ld a,(gc_nt)
        ld (gc_cnt),a
        exx
        ld de,RSTRIDE
        exx
.tile:  ; pA = TILES + tile*16 + iA
        ld hl,(gc_ma)
        ld a,(hl)
        inc hl
        ld (gc_ma),hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,tiles
        add hl,de
        ld a,(gc_ia)
        ld e,a
        ld d,0
        add hl,de
        push hl                 ; pA
        ld hl,(gc_mb)
        ld a,(hl)
        inc hl
        ld (gc_mb),hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,tiles
        add hl,de
        ld a,(gc_ib)
        ld e,a
        ld d,0
        add hl,de
        ld b,h
        ld c,l                  ; BC = pB
        pop de                  ; DE = pA
        ld l,8
.row:   ld a,(de)
        inc de
        inc de
        ld (ix+0),a
        exx
        ld b,a
        exx
        ld a,(bc)
        inc bc
        inc bc
        exx
        ld c,a
        ld h,LS1
        ld l,b
        ld a,(hl)
        inc h
        ld l,c
        or (hl)
        ld (ix+RW),a
        inc h
        ld l,b
        ld a,(hl)
        inc h
        ld l,c
        or (hl)
        ld (ix+RW*2),a
        inc h
        ld l,b
        ld a,(hl)
        inc h
        ld l,c
        or (hl)
        ld (ix+RW*3),a
        add ix,de
        exx
        dec l
        jr nz,.row
        ld a,(gc_cnt)
        dec a
        ld (gc_cnt),a
        jr nz,.tile
        ret
gc_ia   db 0
gc_ib   db 0
gc_ma   dw 0
gc_mb   dw 0

mul12:  ; HL = HL*12
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        ret

; full ring rebuild around current camera
ring_fill:
        ld hl,(camx)
        srl h
        rr l
        srl h
        rr l
        ld (rlo),hl
        xor a
        ld (rslot),a
        ld (gc_r0),a
        ld a,12
        ld (gc_nt),a
        ld b,0
.l:     push bc
        ld hl,(rlo)
        ld c,b
        ld b,0
        add hl,bc
        ld a,c
        call gen_col
        call maybe_ei
        pop bc
        inc b
        ld a,b
        cp RW
        jr nz,.l
        ret

; keep the ring in step with the camera (at most one column per frame)
colgen  db 0
ring_update:
        xor a
        ld (colgen),a
        ld hl,(camx)
        srl h
        rr l
        srl h
        rr l                    ; HL = c
        ld de,(rlo)
        or a
        sbc hl,de               ; c - rlo
        jr c,.left
        ld a,l
        cp 3
        ret c                   ; c <= rlo+2 : nothing to do
        ; generate column rlo+34 into rslot
        ld a,1
        ld (colgen),a
        xor a
        ld (gc_r0),a
        ld a,12
        ld (gc_nt),a
        ld hl,(rlo)
        ld de,RW
        add hl,de
        ld a,(rslot)
        call gen_col
        ld hl,(rlo)
        inc hl
        ld (rlo),hl
        ld a,(rslot)
        inc a
        cp RW
        jr c,.s1
        xor a
.s1:    ld (rslot),a
        ret
.left:  ld a,1
        ld (colgen),a
        ld hl,(rlo)
        dec hl
        ld (rlo),hl
        ld a,(rslot)
        or a
        jr nz,.s2
        ld a,RW
.s2:    dec a
        ld (rslot),a
        xor a
        ld (gc_r0),a
        ld a,12
        ld (gc_nt),a
        ld hl,(rlo)
        ld a,(rslot)
        jp gen_col

; patch_tile: tile at (tx=HL, ty=C) changed in the map -> re-render it in ring
patch_tile:
        ld a,c
        ld (gc_r0),a
        ld a,1
        ld (gc_nt),a
        add hl,hl               ; J = 2*tx
        dec hl                  ; start at 2tx-1
        ld b,3
.l:     push bc
        push hl
        bit 7,h
        jr nz,.skip
        ; d = J - rlo ; must be 0..33
        ld de,(rlo)
        or a
        sbc hl,de
        jr c,.skip
        ld a,h
        or a
        jr nz,.skip
        ld a,l
        cp RW
        jr nc,.skip
        ld hl,rslot
        add a,(hl)
        cp RW
        jr c,.ok
        sub RW
.ok:    pop hl
        push hl
        call gen_col
.skip:  pop hl
        inc hl
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------- compose
; draw_bg: copy the visible window of the ring (phase camx&3) into the
; back buffer.  Two LDI runs per row handle the ring wrap.
draw_bg:
        ld hl,(camx)
        ld a,l
        and 3
        ld (tmp1),a             ; phase
        srl h
        rr l
        srl h
        rr l
        ld de,(rlo)
        or a
        sbc hl,de
        ld a,(rslot)
        add a,l
        cp RW
        jr c,.c1
        sub RW
.c1:    ld c,a                  ; c = ring slot of left screen byte
        ; n1 = min(32, RW-c) ; target A = ldi32 + 2*(32-n1)
        ld a,RW
        sub c
        cp 33
        jr c,.n1
        ld a,32
.n1:    ld b,a                  ; n1
        ld a,32
        sub b                   ; 32-n1  (= n2)
        push af
        add a,a
        ld e,a
        ld d,0
        ld hl,ldi32
        add hl,de
        ld (.ca+1),hl
        pop af                  ; n2
        ld b,a
        ld a,32
        sub b                   ; 32-n2
        add a,a
        ld e,a
        ld d,0
        ld hl,ldi32
        add hl,de
        ld (.cb+1),hl
        ; src = RING + camy*RSTRIDE + phase*RW + c
        ld a,(camy)
        ld l,a
        ld h,0
        ld de,RSTRIDE
        call mul16              ; HL = camy*136
        ld de,RING
        add hl,de
        ld a,(tmp1)
        ld b,a
        or a
        jr z,.p0
        ld de,RW
.p1:    add hl,de
        djnz .p1
.p0:    ld b,0
        add hl,bc
        ld de,BBVIS
        exx
        ld b,PFROWS
        exx
.row:
.ca:    call ldi32
        ld bc,-RW
        add hl,bc
.cb:    call ldi32
        ld bc,RSTRIDE+2
        add hl,bc
        ex de,hl
        ld bc,BBW-32
        add hl,bc
        ex de,hl
        ; ---- sound tick (site 1)
        ld a,(sndph)
.tk1l:   add a,0
        ld (sndph),a
        ld a,(sndph+1)
.tk1h:   adc a,0
        ld (sndph+1),a
        and $C0                 ; 25% duty pulse: thinner, quieter than a square
        add a,$40
        sbc a,a
        and $21
.tk1x:   xor $20|LATBASE
        ld (LATCH),a
        exx
        dec b
        exx
        jp nz,.row
        ret

mul16:  ; HL = L * DE (L 8-bit)
        ld a,l
        ld hl,0
        ld b,8
.l:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; ---------------------------------------------------------------- sprites
; drawspr: HL = pre-shifted gfx (already for this phase), A = screen y
; (signed), C = screen byte column (signed, caller keeps it in -4..35),
; B = rows, E = width (3 or 5).  Pixel colour 0 is transparent.
drawspr:
        ld (ds_y),a
        ld a,e
        ld (ds_w),a
        ld a,c
        add a,4
        ld c,a                  ; column inside the 40-byte row
        bit 7,a                 ; further left than the guard bytes: skip
        ret nz                  ; (it used to wrap round to the far right and
        add a,e                 ;  could write past the buffer into the map)
        cp BBW+1
        ret nc
        ld a,(ds_y)
        bit 7,a
        jr z,.nt
        neg                     ; rows to skip
        cp b
        ret nc
        ld d,a
        ld a,b
        sub d
        ld b,a
        ld a,d
        ld d,0
.sk:    add hl,de
        dec a
        jr nz,.sk
.nt:    cp PFROWS
        ret nc
        ld d,a                  ; y
        add a,b
        cp PFROWS+1
        jr c,.nb
        ld a,PFROWS
        sub d
        ld b,a
.nb:    push hl
        ld l,d
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; y*40
        ld e,c
        ld d,0
        add hl,de
        ld de,BB
        add hl,de               ; HL = dest
        pop de                  ; DE = gfx
        ld a,b
        exx
        ld b,a
        exx
        ld b,MASKPG
        ld a,(ds_w)
        cp 5
        jr z,.w5
        cp 3
        jr nz,.wg
.r3:    REPT 3
        ld a,(de)
        inc de
        ld c,a
        ld a,(bc)
        and (hl)
        or c
        ld (hl),a
        inc hl
        ENDR
        ld a,BBW-3
        add a,l
        ld l,a
        jr nc,.n3
        inc h
.n3:    exx
        dec b
        exx
        jr nz,.r3
        ret
.w5:    REPT 5
        ld a,(de)
        inc de
        ld c,a
        ld a,(bc)
        and (hl)
        or c
        ld (hl),a
        inc hl
        ENDR
        ld a,BBW-5
        add a,l
        ld l,a
        jr nc,.n5
        inc h
.n5:    exx
        dec b
        exx
        jr nz,.w5
        ret
.wg:    ld a,(ds_w)
        ld (.gc),a
.gb:    ld a,(de)
        inc de
        ld c,a
        ld a,(bc)
        and (hl)
        or c
        ld (hl),a
        inc hl
        ld a,(.gc)
        dec a
        ld (.gc),a
        jr nz,.gb
        ld a,(ds_w)
        neg
        add a,BBW
        add a,l
        ld l,a
        jr nc,.ng
        inc h
.ng:    exx
        dec b
        exx
        jr nz,.wg
        ret
.gc     db 0
ds_y    db 0
ds_w    db 0

; plot: particle pixel. HL = screen x (0..127 valid), A = screen y, C = colour 0-3
plot:
        cp PFROWS
        ret nc
        ld b,a
        ld a,h
        or a
        ret nz
        ld a,l
        cp 128
        ret nc
        push bc
        ld e,a
        srl e
        srl e
        and 3
        ld c,a                  ; pixel index in byte
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        pop de
        ld d,0
        add hl,de
        ld de,BBVIS
        add hl,de
        ld b,0
        ex de,hl
        ld hl,pixmask
        add hl,bc
        ld a,(hl)               ; mask of this pixel
        pop bc                  ; c = colour
        push af
        ld l,c
        ld h,0
        ld bc,colfill
        add hl,bc
        pop bc                  ; b = mask
        ld a,(hl)
        and b
        ld c,a
        ld a,b
        cpl
        ex de,hl
        and (hl)
        or c
        ld (hl),a
        ret
pixmask db $C0,$30,$0C,$03
colfill db $00,$55,$AA,$FF

        include "game.asm"
        include "ents.asm"
        include "boss.asm"
        include "fx.asm"
        include "bank.asm"
        include "demo.asm"

; ===================================================================== data
        include "../build/assets.inc"
font_hud: incbin "../build/font_hud.bin"
; high scores (score/10 as BCD, then 3 letters) and time-attack records
hitab:  db $00,$05,$00,"BIX", $00,$04,$00,"BPM", $00,$03,$00,"VZ ", $00,$02,$00,"DSE", $00,$01,$00,"JOY"
besttime: ds NLEVELS*2,$FF
        align 16
tiles:  ds NTILES*16
code_end:
        ASSERT code_end <= IM2TAB, "code overflows into IM2 table"

; ===================================================================== overlay
; Assembled at its run address and saved to ovl.bin; the build packs it with
; BIX-LZ (ovl.lz) and the staging area below carries the packed copy.
OVL_ORG equ RING
        org OVL_ORG
ovl_start:
        include "screens.asm"
ovl_end:
OVL_SIZE equ ovl_end-ovl_start
        ASSERT OVL_ORG+OVL_SIZE <= SCR, "overlay overlaps loader scratch"
        SAVEBIN "../build/ovl.bin",OVL_ORG,OVL_SIZE

; ===================================================================== staging
; Loaded with the program, copied into the SRAM banks at boot, then the
; ring buffer overwrites it.
        org RING
stage_bank3:
        incbin "../build/bank3.bin"
stage_ovl:
        incbin "../build/ovl.lz"
OVL_LZ  equ $-stage_ovl
        ASSERT UP_OVL+OVL_LZ <= B5BASE, "packed overlay runs into the upper-bank archive"
        ASSERT OVLPACK+OVL_LZ <= LANDING, "packed overlay landing too small"
        ASSERT OVL_ORG+OVL_SIZE <= OVLPACK, "overlay overlaps its packed copy"
stage_b5x:
        incbin "../build/bank5x.bin"
        include "boot.asm"
stage_end:
        ASSERT stage_end <= $F900, "staging overflow"  ; (MAP is free at boot)

        SAVEBIN "../build/bix.bin",$8000,stage_end-$8000
