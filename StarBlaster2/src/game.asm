; =====================================================================
;  STAR BLASTER II - the game
; =====================================================================
OBJS    equ $E900               ; 16 objects x 32 bytes
NOBJ    equ 16
OSZ     equ 32
STARS   equ $EB00               ; 30 stars x 5 bytes (x 8.8, y 8.8, layer)
NSTAR   equ 20
PARTS   equ $EC00               ; 32 particles x 8 bytes
NPART   equ 32

; object fields
O_TYPE  equ 0
O_AZ    equ 1
O_EL    equ 3
O_Z     equ 5
O_VAZ   equ 7
O_VEL   equ 9
O_VZ    equ 10
O_TIM   equ 11
O_HP    equ 12
O_ST    equ 13
O_SX    equ 14
O_SY    equ 16
O_HW    equ 17
O_HH    equ 18
O_VIS   equ 19
O_SIZE  equ 20
O_PH    equ 21
O_AUX   equ 22
O_FL    equ 23                  ; hit flash timer

; object types (sprite = type-1 for 1..8)
T_FHT   equ 1
T_ACE   equ 2
T_TNK   equ 3
T_FRT   equ 4
T_TRP   equ 5
T_ROCK  equ 6
T_MINE  equ 7
T_POD   equ 8
T_PLASMA equ 9
T_BOSS  equ 10
T_PLANET equ 11

F_ROCKS equ 1
F_MINES equ 2
F_PLANET equ 4
F_CLOAK equ 8
F_BOSS  equ 16

; ---------------------------------------------------------------------
; sector table: name, flags, palette, quotas FRT TRP TNK FHT ACE
; ---------------------------------------------------------------------
sectab:
        dw sn1 : db 0,0,                2,2,2,4,0
        dw sn2 : db F_ROCKS,0,          3,0,3,5,0
        dw sn3 : db F_MINES,0,          2,3,2,6,0
        dw sn4 : db F_PLANET,0,         0,6,2,6,0
        dw sn5 : db F_CLOAK,CSS1,       3,2,3,8,0
        dw sn6 : db 0,0,                2,0,2,4,5
        dw sn7 : db F_ROCKS|F_MINES,0,  3,3,3,6,3
        dw sn8 : db F_BOSS,0,           0,0,0,8,0
sn1:    db "OUTER RIM",0
sn2:    db "THE ROCK BELT",0
sn3:    db "THE MINEFIELD",0
sn4:    db "THE INVASION",0
sn5:    db "NEBULA X",0
sn6:    db "ACE SQUADRON",0
sn7:    db "THE GAUNTLET",0
sn8:    db "ENERMY MOTHERSHIP",0
secstr: db "SECTOR 0",0

; points per type (BCD, 2 bytes big end)
pointtab:
        dw 0, $0250, $0500, $0100, $0150, $0200, $0050, $0100, $0000, $0025
pts_tur equ $1000
pts_core equ $5000

; ---------------------------------------------------------------------
; new_game: start at sector 0 with the chosen skill
; ---------------------------------------------------------------------
new_game:
        ld hl,999
        ld (energy),hl
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (lap),a
        ld a,(startsec)         ; test hook (normally 0)
        ld (sector),a
        ld a,2
        ld (novas),a
        call start_sector
        jp game_loop

; ---------------------------------------------------------------------
; start_sector: clear the field, draw the cockpit, warp in
; ---------------------------------------------------------------------
start_sector:
        ; objects / particles off
        ld hl,OBJS
        ld de,OBJS+1
        ld bc,NOBJ*OSZ-1
        ld (hl),0
        ldir
        ld hl,PARTS
        ld de,PARTS+1
        ld bc,NPART*8-1
        ld (hl),0
        ldir
        xor a
        ld (bolt_t),a
        ld (bolt_t+1),a
        ld (crackt),a
        ld (shaket),a
        ld (chain),a
        ld (bossdead),a
        ld (paused),a
        ld (bannert),a
        ld hl,popt
        ld b,20
.pc:    ld (hl),0
        inc hl
        djnz .pc
        ld hl,0
        ld (vel),hl
        ld (vvaz),hl
        ld (vvel),hl
        ; sector record
        ld a,(sector)
        ld e,a
        ld a,9
        call mul8
        ld de,sectab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (banner2),de
        ld a,(hl)
        ld (secflags),a
        inc hl
        ld a,(hl)
        or MODE1
        ld (latchbase),a
        inc hl
        ld de,quota
        ld bc,5
        ldir
        ; lap 2+: more fighters
        ld a,(lap)
        or a
        jr z,.l1
        ld hl,quota+3
        ld a,(hl)
        add a,2
        ld (hl),a
.l1:    ld a,(sector)
        add a,'1'
        ld (secstr+7),a
        ld hl,secstr
        ld (banner1),hl
        ; stars
        call stars_init
        ; picture: blue view, HUD
        call draw_cockpit
        ; planet / boss
        ld a,(secflags)
        and F_PLANET
        call nz,spawn_planet
        ld a,(secflags)
        and F_BOSS
        call nz,spawn_boss
        ld a,1
        ld (gstate),a
        ld hl,60
        ld (gtimer),hl
        ld a,SFX_WARP
        call play_sfx
        ld hl,mus_start_0
        ld de,mus_start_1
        call play_music
        ld a,30
        ld (spawnt),a
        ret

; draw_cockpit: BASE = blue view + HUD panel; whole screen marked
draw_cockpit:
        ld a,$AA
        ld d,0
        ld e,VIEWH
        call fill_rows
        xor a                   ; green panel
        ld d,VIEWH
        ld e,64
        call fill_rows
        xor a
        ld (bezcol),a
        call draw_bezel
        ; radar box: blue interior cols 9..22, rows 52..62, yellow frame
        ld d,52
.rb:    ld a,d
        call bgrow
        ld a,l
        or 9
        ld l,a
        ld b,14
        ld a,$AA
        ld e,d
.rbb:   ld (hl),a
        res 3,h
        ld (hl),a
        set 3,h
        inc l
        djnz .rbb
        inc d
        ld a,d
        cp 62
        jr nz,.rb
        ld a,1
        ld (txtbase),a
        ld a,64
        ld (clipbot),a
        ; frame + view bracket via pset into BG and BASE
        ld b,35
.fr:    push bc
        ld c,51
        ld e,1
        call pset_both
        pop bc
        push bc
        ld c,62
        ld e,1
        call pset_both
        pop bc
        inc b
        ld a,b
        cp 93
        jr nz,.fr
        ld c,52
.fv:    push bc
        ld b,35
        ld e,1
        call pset_both
        pop bc
        push bc
        ld b,92
        ld e,1
        call pset_both
        pop bc
        inc c
        ld a,c
        cp 62
        jr nz,.fv
        ld bc,60*256+52
        ld e,1
        call pset_both
        ld bc,68*256+52
        ld e,1
        call pset_both
        ld bc,60*256+61
        ld e,1
        call pset_both
        ld bc,68*256+61
        ld e,1
        call pset_both
        ld bc,64*256+57
        ld e,0
        call pset_both
        ; labels
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_energy
        ld de,1*256+53
        call print
        ld hl,s_score
        ld de,25*256+53
        call print
        ld a,(trainer)
        or a
        jr z,.nt
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_trainer
        ld de,1*256+59
        call print
.nt:    xor a
        ld (txtbase),a
        ld a,$0F
        ld (hudflag),a
        call hud_update
        call mark_all
        ret
s_energy: db "ENERGY",0
s_score: db "SCORE",0
s_trainer: db "TRAIN",0

; pset into BG and BASE (B,C,E as pset)
pset_both:
        push bc
        push de
        call pset
        pop de
        pop bc
        ld a,c
        call bgrow
        ld a,b
        rrca
        rrca
        and $1F
        or l
        ld l,a
        ld a,(hl)
        res 3,h
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; HUD numbers (drawn into BASE + BG when they change)
; ---------------------------------------------------------------------
hud_update:
        ld a,(hudflag)
        or a
        ret z
        ld a,1
        ld (txtbase),a
        ld a,(hudflag)
        bit 0,a
        call nz,hud_tally
        ld a,(hudflag)
        bit 1,a
        call nz,hud_energy
        ld a,(hudflag)
        bit 2,a
        call nz,hud_score
        xor a
        ld (hudflag),a
        ld (txtbase),a
        ret
hud_tally:
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_tally
        ld de,1*256+47
        call print
        ld a,3
        ld b,0
        call set_ink
        ld hl,quota
        ld d,5
        ld b,4
.t:     push bc
        push hl
        push de
        ld a,(hl)
        ld c,a
        ld a,b
        cp 1
        jr nz,.nf
        ld a,(quota+4)          ; fighters + aces
        add a,c
        ld c,a
.nf:    ld a,c
        ld l,a
        ld h,0
        ld e,47
        ld b,2
        call print_num
        pop de
        pop hl
        inc hl
        ld a,d
        add a,7
        ld d,a
        pop bc
        djnz .t
        ; novas
        ld a,2
        ld b,0
        call set_ink
        ld a,(novas)
        ld l,a
        ld h,0
        ld de,30*256+47
        ld b,1
        call print_num
        ret
s_tally: db "FRT    TRP    TNK    FHT    @",0
hud_energy:
        ld hl,(energy)
        ld de,200
        or a
        sbc hl,de
        ld a,2
        jr nc,.ok
        ld a,3
.ok:    ld b,0
        call set_ink
        ld hl,(energy)
        ld de,2*256+58
        ld b,3
        call print_num
        ret
hud_score:
        ld a,2
        ld b,0
        call set_ink
        ld hl,score
        ld b,3
        ld de,24*256+58
        jp print_bcd

; ---------------------------------------------------------------------
; main loop
; ---------------------------------------------------------------------
game_loop:
        call prep_commit
        call wait_tick
        call commit
        call read_input
        call game_keys
        ret c                   ; quit to title
        ld a,(paused)
        or a
        jr nz,game_loop
        call game_step
        ret c                   ; game over -> caller
        ; catch up: if ticks are running late, run the logic once more
        ld a,(elapsed)
        sub 2
        jr c,.nl
        ld b,a
        ld a,(lag)
        add a,b
        cp 6
        jr c,.lg
        ld a,6
.lg:    ld (lag),a
        cp 2
        jr c,.nl
        sub 2
        ld (lag),a
        call fs_check
        call game_step
        ret c
.nl:    call fs_check
        call erase
        call fs_check
        call render
        jr game_loop

game_step:
        ld hl,(tick)
        inc hl
        ld (tick),hl
        call ai_play
        call update_view
        call fs_check
        call update_objects
        call fs_check
        call update_parts
        call update_bolts
        jp update_state

; P pause, S sound, X quit when paused, N nova
game_keys:
        ld a,(demo)
        or a
        jr z,.nd
        ld hl,(tick)
        ld de,1100
        or a
        sbc hl,de
        jr nc,.quit
        ld a,(keysnew)
        or a
        jr nz,.quit
        ld a,(inpnew)
        and $10
        jr nz,.quit
        xor a
        ret
.nd:    ld a,(keysnew)
        bit 1,a
        jr z,.np
        ld a,(paused)
        xor 1
        ld (paused),a
        call z,show_unpause
        ld a,(paused)
        or a
        call nz,show_pause
        or a
        ret
.np:    ld a,(paused)
        or a
        jr z,.ns
        ld a,(keysnew)
        bit 3,a
        jr nz,.quit
        or a
        ret
.ns:    ld a,(keysnew)
        bit 0,a
        jr z,.nn
        ld a,(soundmode)
        dec a
        jp p,.sm
        ld a,2
.sm:    ld (soundmode),a
        cp 2
        call z,game_music
        ld a,(soundmode)
        cp 2
        call nz,stop_music
.nn:    ld a,(keysnew)
        bit 5,a
        call nz,fire_nova
        or a
        ret
.quit:  scf
        ret
show_pause:
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_paused
        ld e,18
        call print_c
        ld hl,s_xquit
        ld e,26
        call print_c
        call stop_music
        ret
show_unpause:
        call game_music
        ret
s_paused: db "PAUSED",0
s_xquit: db "P PLAY ON   X QUIT",0

game_music:
        ld a,(soundmode)
        cp 2
        jp nz,stop_music
        ld a,(secflags)
        and F_BOSS
        jr nz,.b
        ld hl,mus_game_0
        ld de,mus_game_1
        jp play_music
.b:     ld hl,mus_boss_0
        ld de,mus_boss_1
        jp play_music

; ---------------------------------------------------------------------
; view: scanning with momentum
; ---------------------------------------------------------------------
update_view:
        ld a,(gstate)
        cp 3
        jr nc,.coast            ; dying / warp-out: no control
        ld a,(inp)
        ld b,a
        ld hl,(vvaz)
        bit 0,b
        jr z,.nr
        ld de,48
        add hl,de
.nr:    bit 1,b
        jr z,.nl
        ld de,-48
        add hl,de
.nl:    ld a,b
        and 3
        jr nz,.cl
.coast: ld hl,(vvaz)
        call damp
.cl:    ld de,420
        call clamp16
        ld (vvaz),hl
        ld de,(vaz)
        ex de,hl
        add hl,de
        ld (vaz),hl
        ld (dvaz),de
        ld hl,(sdvaz)
        add hl,de
        ld (sdvaz),hl
        ; pitch
        ld a,(gstate)
        cp 3
        jr nc,.pc
        ld a,(inp)
        ld b,a
        ld hl,(vvel)
        bit 2,b
        jr z,.nu
        ld de,40
        add hl,de
.nu:    bit 3,b
        jr z,.nd
        ld de,-40
        add hl,de
.nd:    ld a,b
        and $0C
        jr nz,.cp
.pc:    ld hl,(vvel)
        call damp
.cp:    ld de,300
        call clamp16
        ld (vvel),hl
        ex de,hl
        ld hl,(vel)
        add hl,de
        ; clamp pitch to +-22 rows
        ld de,22*256
        call clamp16
        ld de,(vel)
        ld (vel),hl
        or a
        sbc hl,de
        ld (dvel),hl
        call acc_dvel
        ; shake
        ld a,(shaket)
        or a
        ret z
        dec a
        ld (shaket),a
        ld hl,(dvel)
        bit 0,a
        ld de,384
        jr z,.s1
        ld de,-384
.s1:    add hl,de
        ld (dvel),hl
        ld hl,(sdvel)
        add hl,de
        ld (sdvel),hl
        ret
acc_dvel:
        ex de,hl
        ld hl,(sdvel)
        add hl,de
        ld (sdvel),hl
        ret

; damp: HL -= HL/4 (towards 0)
damp:
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e
        or a
        sbc hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp 8
        ret nc
        ld hl,0
        ret
; clamp16: clamp signed HL to +-DE
clamp16:
        bit 7,h
        jr nz,.neg
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret
.neg:   push hl
        add hl,de
        pop hl
        ret c
        ld hl,0
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------------
; stars: screen-space, drift outward (forward flight) and slide with scans
; ---------------------------------------------------------------------
stars_init:
        ld ix,STARS
        ld b,NSTAR
.s:     push bc
        call star_rand
        ld de,5
        add ix,de
        pop bc
        djnz .s
        ret
star_rand:              ; anywhere in view
        ld b,128
        call rand_n
        ld (ix+1),a
        ld b,VIEWH
        call rand_n
        ld (ix+3),a
        call random
        ld (ix+0),a
        ld (ix+2),a
        and 1
        ld (ix+4),a
        ret
star_centre:            ; near the centre (new star ahead)
        ld b,48
        call rand_n
        add a,40
        ld (ix+1),a
        ld b,20
        call rand_n
        add a,12
        ld (ix+3),a
        ret

update_stars:
        ; scan shift: dx = -dvaz*4 (8.8 px), dy = +dvel
        ld hl,(sdvaz)
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (st_dx),hl
        ld ix,STARS
        ld b,NSTAR
.s:     push bc
        ; forward drift: x += (x-64)*k, y += (y-22)*k ; k = 1/16 near, 1/32 far
        ld a,(warpk)
        ld c,a
        ld a,(ix+4)
        add a,c
        ld c,a                  ; shift count (lower = faster)
        ld a,(ix+1)
        sub CX
        call drift
        ld e,(ix+0)
        ld d,(ix+1)
        add hl,de
        ld de,(st_dx)
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        ld a,h
        cp 128
        jr nc,.out
        ld a,(ix+3)
        sub CY
        call drift
        ld e,(ix+2)
        ld d,(ix+3)
        add hl,de
        ld de,(sdvel)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld a,h
        cp VIEWH
        jr c,.ok
.out:   ; scanning hard: wrap to the far edge, else a new star near the centre
        ld hl,(sdvaz)
        ld a,h
        or a
        jr z,.cen
        inc a
        jr z,.cen
.wrap:  ld a,(ix+1)
        bit 7,a
        jr z,.w1
        add a,128
        jr .w2
.w1:    cp 128
        jr c,.w3
        sub 128
.w2:    ld (ix+1),a
.w3:    ld b,VIEWH
        call rand_n
        ld (ix+3),a
        jr .ok
.cen:   ld hl,(sdvel)
        ld a,h
        cp 2
        jr c,.cen2
        cp $FE
        jr c,.wrapv
.cen2:  call star_centre
        jr .ok
.wrapv: ld b,128
        call rand_n
        ld (ix+1),a
        ld a,(ix+3)
        bit 7,a
        ld a,VIEWH-1
        jr nz,.wv
        xor a
.wv:    ld (ix+3),a
.ok:    ld de,5
        add ix,de
        pop bc
        ld a,b
        and 7
        call z,fs_check
        dec b
        jp nz,.s
        ld hl,0
        ld (sdvaz),hl
        ld (sdvel),hl
        ret
; drift: HL = sext(A) << (8-C)   (i.e. A*256 >> C in 8.8)
drift:
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld a,8
        sub c
        ret z
        ld b,a
.l:     add hl,hl
        djnz .l
        ret
; HL = HL >> C (arithmetic), C >= 1
sra_c:
        ld b,c
.l:     sra h
        rr l
        djnz .l
        ret

draw_stars:
        ld ix,STARS
        ld b,NSTAR
.s:     push bc
        ld b,(ix+1)
        ld c,(ix+3)
        ld a,(ix+4)
        xor 1
        ld e,a                  ; near = yellow(1), far = green(0)
        ld a,(warpk)
        cp 2
        jr nc,.dot
        ; warp streak towards centre
        ld a,b
        ld (lx0),a
        ld a,c
        ld (ly0),a
        ld a,b
        sub CX
        sra a
        sra a
        neg
        add a,b
        ld (lx1),a
        ld a,c
        sub CY
        sra a
        sra a
        neg
        add a,c
        ld (ly1),a
        ld a,1
        ld (lcol),a
        call line
        jr .nx
.dot:   call pset_c
.nx:    ld de,5
        add ix,de
        pop bc
        djnz .s
        ret

; ---------------------------------------------------------------------
; objects
; ---------------------------------------------------------------------
; alloc: IX = free slot (cleared), carry if none
obj_alloc:
        ld ix,OBJS
        ld b,NOBJ
        ld de,OSZ
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.f
        add ix,de
        djnz .l
        scf
        ret
.f:     push ix
        pop hl
        ld d,h
        ld e,l
        inc de
        ld bc,OSZ-1
        ld (hl),0
        ldir
        or a
        ret

; count objects of type A -> A
obj_count:
        ld c,a
        ld b,NOBJ
        ld hl,OBJS
        ld de,OSZ
        xor a
.l:     push af
        ld a,(hl)
        cp c
        jr nz,.n
        pop af
        inc a
        push af
.n:     pop af
        add hl,de
        djnz .l
        ret

; random signed value in +-(B/2) -> A
rand_pm:
        push bc
        call rand_n
        pop bc
        srl b
        sub b
        ret

; az = vaz + random spread; A = spread in units (0 = anywhere)
set_az_near:
        or a
        jr z,.any
        ld b,a
        call rand_pm
        ld hl,(vaz)
        add a,h
        ld (ix+O_AZ+1),a
        ld (ix+O_AZ),l
        ret
.any:   call random
        ld (ix+O_AZ+1),a
        ld (ix+O_AZ),l
        ret

; spawn manager: called each tick
spawn_tick:
        ld a,(gstate)
        or a
        ret nz
        ld a,(spawnt)
        or a
        jr z,.go
        dec a
        ld (spawnt),a
        ret
.go:    ld a,20
        ld (spawnt),a
        ; fighters: allow 2 + skill/2 at once (aces count separately)
        ld a,(quota+3)
        or a
        jr z,.nofht
        ld a,T_FHT
        call obj_count
        ld b,a
        ld a,(skill)
        srl a
        inc a
        cp b
        jr z,.nofht
        jr c,.nofht
        ld a,(quota+3)
        cp b
        jr z,.nofht
        jr c,.nofht
        call spawn_fighter
.nofht: ld a,(quota+4)
        or a
        jr z,.noace
        ld a,T_ACE
        call obj_count
        cp 2
        jr nc,.noace
        ld b,a
        ld a,(quota+4)
        cp b
        jr z,.noace
        jr c,.noace
        call spawn_ace
.noace: ; convoys: up to 2 of each type with quota
        ld c,0
.cv:    push bc
        ld hl,quota
        ld b,0
        add hl,bc
        ld a,(hl)
        or a
        jr z,.cn
        ld e,a
        ld a,c
        ld hl,cvtype
        add hl,bc
        ld a,(hl)
        push de
        push af
        call obj_count
        pop bc                  ; B = type
        pop de
        cp 2
        jr nc,.cn
        cp e
        jr nc,.cn
        ld a,b
        call spawn_convoy
.cn:    pop bc
        inc c
        ld a,c
        cp 3
        jr nz,.cv
        ; rocks
        ld a,(secflags)
        and F_ROCKS
        jr z,.nr
        ld a,T_ROCK
        call obj_count
        cp 4
        call c,spawn_rock
.nr:    ld a,(secflags)
        and F_MINES
        jr z,.nm
        ld a,T_MINE
        call obj_count
        cp 3
        call c,spawn_mine
.nm:    ; supply pod now and then
        ld a,T_POD
        call obj_count
        or a
        ret nz
        ld b,12
        call rand_n
        or a
        ret nz
        jp spawn_pod
cvtype: db T_FRT,T_TRP,T_TNK

spawn_fighter:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),T_FHT
        ld a,90
        call set_az_near
        ld b,40
        call rand_pm
        ld (ix+O_EL+1),a
        ld (ix+O_Z+1),56
        ld a,(skill)
        ld b,a
        add a,a
        add a,b                 ; skill*6
        add a,a
        ld b,a
        ld a,(lap)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,24
        neg
        ld (ix+O_VZ),a          ; approach speed
        call random
        ld (ix+O_PH),a
        ld (ix+O_HP),1
        ld a,(secflags)
        and F_BOSS
        ret z
        ; boss: launch from the mothership
        ld iy,OBJS
        ld a,(iy+O_AZ+1)
        ld (ix+O_AZ+1),a
        ld a,(iy+O_EL+1)
        ld (ix+O_EL+1),a
        ld a,(iy+O_Z+1)
        sub 2
        ld (ix+O_Z+1),a
        ret

spawn_ace:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),T_ACE
        xor a
        call set_az_near
        ld b,30
        call rand_pm
        ld (ix+O_EL+1),a
        ld (ix+O_Z+1),58
        ld (ix+O_VZ),-70
        call random
        ld (ix+O_PH),a
        ld (ix+O_HP),2
        ld (ix+O_TIM),60
        ret

; A = type
spawn_convoy:
        push af
        call obj_alloc
        pop bc
        ret c
        ld (ix+O_TYPE),b
        ld a,b
        cp T_FRT
        ld c,3
        jr z,.h
        ld c,2
.h:     ld (ix+O_HP),c
        xor a
        call set_az_near
        ; keep them away from the current view so they cruise in
        ld hl,(vaz)
        ld a,h
        add a,64
        ld b,a
        call random
        and $7F
        add a,b
        ld (ix+O_AZ+1),a
        ld b,40
        call rand_pm
        ld (ix+O_EL+1),a
        ld b,16
        call rand_n
        add a,10
        ld (ix+O_Z+1),a
        call random
        and $3F
        add a,32
        bit 0,l
        jr z,.d
        neg
.d:     ld (ix+O_VAZ),a
        rla
        sbc a,a
        ld (ix+O_VAZ+1),a
        ld a,(secflags)
        and F_PLANET
        ret z
        ld a,(ix+O_TYPE)
        cp T_TRP
        ret nz
        ; troop carriers head for the planet (slot 0)
        ld iy,OBJS
        ld a,(iy+O_AZ+1)
        sub (ix+O_AZ+1)
        ld a,50
        jp p,.tp
        neg
.tp:    ld (ix+O_VAZ),a
        rla
        sbc a,a
        ld (ix+O_VAZ+1),a
        ret

spawn_rock:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),T_ROCK
        ld a,70
        call set_az_near
        ld b,40
        call rand_pm
        ld (ix+O_EL+1),a
        ld b,20
        call rand_n
        add a,36
        ld (ix+O_Z+1),a
        ld (ix+O_VZ),-36
        ld b,40
        call rand_pm
        ld (ix+O_VAZ),a
        rla
        sbc a,a
        ld (ix+O_VAZ+1),a
        ld b,30
        call rand_pm
        ld (ix+O_VEL),a
        ld (ix+O_HP),1
        ret

spawn_mine:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),T_MINE
        xor a
        call set_az_near
        ld b,30
        call rand_pm
        ld (ix+O_EL+1),a
        ld (ix+O_Z+1),40
        ld (ix+O_VZ),-22
        ld (ix+O_HP),1
        ret

spawn_pod:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),T_POD
        xor a
        call set_az_near
        ld b,24
        call rand_pm
        ld (ix+O_EL+1),a
        ld (ix+O_Z+1),20
        ld (ix+O_VAZ),60
        ld (ix+O_TIM),250
        ld (ix+O_HP),1
        call random
        and 3
        ld (ix+O_AUX),a         ; 0 = nova pod, else energy
        ret

spawn_planet:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),T_PLANET
        ld hl,(vaz)
        ld a,h
        add a,40
        ld (ix+O_AZ+1),a
        ld (ix+O_EL+1),12
        ld (ix+O_Z+1),63
        ret

spawn_boss:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),T_BOSS
        ld hl,(vaz)
        ld a,h
        add a,100
        ld (ix+O_AZ+1),a
        ld (ix+O_Z+1),60
        ld (ix+O_VZ),-24
        ld a,2
        ld (turhp),a
        ld (turhp+1),a
        ld (turhp+2),a
        ld (turhp+3),a
        ld a,8
        ld (corehp),a
        ld a,80
        ld (bosst),a
        ret

; plasma bolt from IX's position (aimed at us)
spawn_plasma:
        push ix
        push ix
        pop iy
        call obj_alloc
        jr c,.x
        ld (ix+O_TYPE),T_PLASMA
        ld a,(iy+O_AZ)
        ld (ix+O_AZ),a
        ld a,(iy+O_AZ+1)
        ld (ix+O_AZ+1),a
        ld a,(iy+O_EL)
        ld (ix+O_EL),a
        ld a,(iy+O_EL+1)
        ld (ix+O_EL+1),a
        ld a,(iy+O_Z+1)
        ld (ix+O_Z+1),a
        ld (ix+O_VZ),-100
        ld (ix+O_HP),1
        ld a,SFX_PLASMA
        call play_sfx
.x:     pop ix
        ret

; ---------------------------------------------------------------------
; update_objects: movement + behaviour
; ---------------------------------------------------------------------
update_objects:
        call spawn_tick
        ld ix,OBJS
        ld b,NOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.nx
        ld a,(ix+O_FL)
        or a
        jr z,.nf
        dec (ix+O_FL)
.nf:    ; integrate az, el, z
        ld l,(ix+O_AZ)
        ld h,(ix+O_AZ+1)
        ld e,(ix+O_VAZ)
        ld d,(ix+O_VAZ+1)
        add hl,de
        ld (ix+O_AZ),l
        ld (ix+O_AZ+1),h
        ld a,(ix+O_VEL)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+O_EL)
        ld h,(ix+O_EL+1)
        add hl,de
        ld (ix+O_EL),l
        ld (ix+O_EL+1),h
        ld a,(ix+O_VZ)
        ld e,a
        rla
        sbc a,a
        ld d,a
        sla e
        rl d
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        add hl,de
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        inc (ix+O_PH)
        ; behaviour
        ld a,(ix+O_TYPE)
        add a,a
        ld l,a
        ld h,0
        ld de,behav-2
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call jphl
.nx:    ld de,OSZ
        add ix,de
        call fs_check
        pop bc
        djnz .o
        ret
jphl:   jp (hl)
behav:  dw b_fighter,b_ace,b_convoy,b_convoy,b_convoy,b_rock,b_mine,b_pod,b_plasma,b_boss,b_none
b_none: ret

; arrived at the cockpit? (z < 1)
reached:
        ld a,(ix+O_Z+1)
        or a
        ret nz
        scf
        ret

b_fighter:
        ; weave
        ld a,(ix+O_PH)
        add a,a
        call sinv
        sra a
        sra a
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+O_AZ)
        ld h,(ix+O_AZ+1)
        add hl,de
        ld (ix+O_AZ),l
        ld (ix+O_AZ+1),h
        ; steer gently towards the view centre when close
        ld a,(ix+O_Z+1)
        cp 20
        call c,home_in
        call reached
        ret nc
        ld a,35
        jp ram_us

b_ace:
        ld a,(ix+O_ST)
        or a
        jr nz,.hover
        ld a,(ix+O_Z+1)
        cp 16
        jr nc,.w
        ld (ix+O_ST),1
        ld (ix+O_VZ),0
        jr .w
.hover: ; strong figure-8 weave, fire, then dive
        ld a,(ix+O_PH)
        add a,a
        add a,a
        call sinv
        ld (ix+O_VAZ),a
        rla
        sbc a,a
        ld (ix+O_VAZ+1),a
        ld a,(ix+O_PH)
        add a,a
        add a,a
        add a,a
        call sinv
        sra a
        ld (ix+O_VEL),a
        dec (ix+O_TIM)
        jr nz,.w
        ld (ix+O_TIM),70
        call spawn_plasma
        inc (ix+O_AUX)
        ld a,(ix+O_AUX)
        cp 4
        jr c,.w
        ld (ix+O_VZ),-90        ; dive at us
        ld (ix+O_ST),2
        ld (ix+O_VAZ),0
        ld (ix+O_VAZ+1),0
        ld (ix+O_VEL),0
.w:     ld a,(ix+O_ST)
        cp 2
        ret nz
        call home_in
        call reached
        ret nc
        ld a,50
        jp ram_us

b_convoy:
        ; troop carriers land on the planet
        ld a,(secflags)
        and F_PLANET
        ret z
        ld a,(ix+O_TYPE)
        cp T_TRP
        ret nz
        ld iy,OBJS
        ld a,(iy+O_AZ+1)
        sub (ix+O_AZ+1)
        add a,2
        cp 5
        ret nc
        ; landed!
        ld (ix+O_TYPE),0
        ld a,SFX_LAND
        call play_sfx
        ld hl,s_landed
        call popup_centre
        ld a,60
        jp lose_energy
s_landed: db "TROOPS LANDED!",0

b_rock:
        call reached
        ret nc
        ld (ix+O_TYPE),0
        ; collision only if near the view centre
        call rel_az
        ld a,h
        add a,6
        cp 13
        ret nc
        ld a,30
        jp ram_us

b_mine:
        call home_in
        ld a,(ix+O_PH)
        and 15
        jr nz,.nb
        ld a,(ix+O_Z+1)
        cp 16
        jr nc,.nb
        ld a,SFX_TICK
        call play_sfx
.nb:    call reached
        ret nc
        ld a,45
        jp ram_us

b_pod:
        dec (ix+O_TIM)
        ret nz
        ld (ix+O_TYPE),0
        ret

b_plasma:
        call reached
        ret nc
        ld a,20
        jp ram_us

b_boss:
        ; approach, then hold and circle slowly
        ld a,(ix+O_Z+1)
        cp 9
        jr nc,.mv
        ld (ix+O_VZ),0
.mv:    ld a,(ix+O_PH)
        call sinv
        sra a
        sra a
        sra a
        ld (ix+O_VAZ),a
        rla
        sbc a,a
        ld (ix+O_VAZ+1),a
        ld a,(ix+O_PH)
        add a,a
        call sinv
        sra a
        sra a
        sra a
        ld (ix+O_VEL),a
        ; weapons
        ld a,(bossdead)
        or a
        jr nz,.dying
        ld a,(bosst)
        dec a
        ld (bosst),a
        ret nz
        ld b,40
        call rand_n
        add a,30
        ld (bosst),a
        ; a live turret fires
        ld hl,turhp
        ld b,4
        ld c,0
.t:     ld a,(hl)
        or a
        jr z,.tn
        inc c
.tn:    inc hl
        djnz .t
        ld a,c
        or a
        jr z,.core
        jp spawn_plasma
.core:  ; core exposed: launch a fighter instead
        ld a,(quota+3)
        or a
        ret z
        push ix
        call spawn_fighter
        pop ix
        ret
.dying: ; explosion sequence
        ld a,(ix+O_TIM)
        dec a
        ld (ix+O_TIM),a
        jr z,.gone
        and 3
        ret nz
        ld b,40
        call rand_pm
        ld l,(ix+O_SX)
        add a,l
        ld b,a
        push bc
        ld b,12
        call rand_pm
        add a,(ix+O_SY)
        pop bc
        ld c,a
        ld a,10
        call burst
        ld a,SFX_BIGBOOM
        call play_sfx
        ld a,2
        ld (flasht),a
        ret
.gone:  ld (ix+O_TYPE),0
        ld a,2
        ld (bossdead),a
        ld a,20
        ld (shaket),a
        ret

; home_in: drift az/el towards the view centre
home_in:
        call rel_az
        ld a,h
        or a
        jp m,.r
        jr z,.e
        ld de,-24
        jr .a
.r:     ld de,24
.a:     ld l,(ix+O_AZ)
        ld h,(ix+O_AZ+1)
        add hl,de
        ld (ix+O_AZ),l
        ld (ix+O_AZ+1),h
.e:     ld hl,(vel)
        ld a,(ix+O_EL+1)
        sub h
        ret z
        ld de,-24
        jp p,.u
        ld de,24
.u:     ld l,(ix+O_EL)
        ld h,(ix+O_EL+1)
        add hl,de
        ld (ix+O_EL),l
        ld (ix+O_EL+1),h
        ret

; HL = az - vaz
rel_az:
        ld l,(ix+O_AZ)
        ld h,(ix+O_AZ+1)
        ld de,(vaz)
        or a
        sbc hl,de
        ret

; A = sin(A) signed
sinv:
        ld e,a
        ld d,0
        ld hl,sintab
        add hl,de
        ld a,(hl)
        ret

; ram_us: object hits the cockpit for A energy
ram_us:
        ld (ix+O_TYPE),0
        push af
        ld a,SFX_HIT
        call play_sfx
        ld a,16
        ld (crackt),a           ; bezel flash timer
        ld a,8
        ld (shaket),a
        ld a,2
        ld (flasht),a
        ld bc,CX*256+CY+10      ; sparks spray up from the dashboard
        ld a,14
        call burst
        pop af
        ; damage grows with skill
        ld b,a
        ld a,(skill)
        ld c,a
        add a,a
        add a,c
        add a,b
lose_energy:
        ld e,a
        ld d,0
        ld a,(godmode)
        ld b,a
        ld a,(trainer)
        or b
        ret nz
        ld hl,(energy)
        or a
        sbc hl,de
        jr nc,.ok
        ld hl,0
.ok:    ld (energy),hl
        ld a,(hudflag)
        or 2
        ld (hudflag),a
        ret

gain_energy:    ; DE
        ld hl,(energy)
        add hl,de
        ld de,999
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ld hl,999
.ok:    ld (energy),hl
        ld a,(hudflag)
        or 2
        ld (hudflag),a
        ret

; ---------------------------------------------------------------------
; laser bolts + NOVA
; ---------------------------------------------------------------------
update_bolts:
        ld a,(firecd)
        or a
        jr z,.c0
        dec a
        ld (firecd),a
.c0:    ld a,(gstate)
        or a
        jr nz,.adv
        ld a,(inp)
        and $10
        jr z,.adv
        ld a,(firecd)
        or a
        jr nz,.adv
        ; free bolt?
        ld hl,bolt_t
        ld a,(hl)
        or a
        jr z,.f
        inc hl
        ld a,(hl)
        or a
        jr nz,.adv
.f:     ld (hl),1
        ld a,4
        ld (firecd),a
        ld a,SFX_LASER
        call play_sfx
        ld a,1
        call lose_energy
.adv:   ld hl,bolt_t
        call .one
        ld hl,bolt_t+1
.one:   ld a,(hl)
        or a
        ret z
        inc a
        ld (hl),a
        cp 6
        ret c
        ld (hl),0
        jp laser_hit

BOLTN   equ 5
; draw bolts: two converging beams per active bolt
draw_bolts:
        ld a,(bolt_t)
        or a
        call nz,.b
        ld a,(bolt_t+1)
        or a
        ret z
.b:     ; t = 1..5: segment from p(t-1) to p(t), p = start + (end-start)*t/5
        ld (bt_t),a
        ld hl,boltpos
        dec a
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (lx0),a
        inc hl
        ld a,(hl)
        ld (ly0),a
        inc hl
        ld a,(hl)
        ld (lx1),a
        inc hl
        ld a,(hl)
        ld (ly1),a
        push hl
        ld a,1
        ld (lcol),a
        call line
        pop hl
        dec hl
        dec hl
        dec hl
        ; mirrored beam from the right
        ld a,127
        sub (hl)
        ld (lx0),a
        inc hl
        ld a,(hl)
        ld (ly0),a
        inc hl
        ld a,127
        sub (hl)
        ld (lx1),a
        inc hl
        ld a,(hl)
        ld (ly1),a
        ld a,3
        ld (lcol),a
        jp line
boltpos: ; x0,y0,x1,y1 for t = 1..5 (left beam)
        db 2,43, 14,38
        db 16,37, 30,32
        db 32,31, 44,27
        db 46,26, 56,24
        db 57,24, 63,22

; laser_hit: whatever is under the sights takes a hit
laser_hit:
        ld iy,0
        ld c,255                ; best z
        ld ix,OBJS
        ld b,NOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_PLANET
        jr z,.n
        ld a,(ix+O_VIS)
        or a
        jr z,.n
        ; |sx-64| <= hw+1
        ld l,(ix+O_SX)
        ld h,(ix+O_SX+1)
        ld de,-CX
        add hl,de
        call abs16
        ld a,h
        or a
        jr nz,.n
        ld a,(ix+O_HW)
        add a,3
        cp l
        jr c,.n
        ld a,(ix+O_SY)
        sub CY
        jp p,.ay
        neg
.ay:    ld b,a
        ld a,(ix+O_HH)
        add a,3
        cp b
        jr c,.n
        pop bc
        ld a,(ix+O_Z+1)
        cp c
        jr nc,.n2
        ld c,a
        push ix
        pop iy
.n2:    push bc
.n:     pop bc
        ld de,OSZ
        add ix,de
        djnz .o
        push iy
        pop ix
        ld a,ixh
        or ixl
        ret z
        ld a,(ix+O_TYPE)
        cp T_BOSS
        jp z,hit_boss
        ; damage
        ld a,6
        ld (ix+O_FL),a
        dec (ix+O_HP)
        jr z,kill_obj
        ; spark
        ld b,(ix+O_SX)
        ld c,(ix+O_SY)
        ld a,3
        call burst
        ld a,SFX_CLANG
        jp play_sfx

; kill_obj: IX destroyed by the player
kill_obj:
        ld a,(ix+O_TYPE)
        ld (lastkill),a
        ld b,(ix+O_SX)
        ld c,(ix+O_SY)
        ld a,(ix+O_HW)
        srl a
        add a,6
        call burst
        ld a,(ix+O_TYPE)
        cp T_POD
        jp z,.pod
        cp T_TNK
        ld a,SFX_BOOM
        jr c,.s
        ld a,SFX_BIGBOOM
.s:     call play_sfx
        ; quota
        ld a,(ix+O_TYPE)
        ld hl,quotamap-1
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        cp $FF
        jr z,.nq
        ld e,a
        ld hl,quota
        add hl,de
        ld a,(hl)
        or a
        jr z,.nq
        dec (hl)
        ld a,(hudflag)
        or 1
        ld (hudflag),a
.nq:    ; points with chain bonus
        ld a,(chaint)
        or a
        ld a,(chain)
        jr z,.c1
        inc a
        cp 5
        jr c,.c2
        ld a,4
        jr .c2
.c1:    ld a,1
.c2:    ld (chain),a
        ld a,50
        ld (chaint),a
        ld a,(ix+O_TYPE)
        add a,a
        ld e,a
        ld d,0
        ld hl,pointtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(chain)
        ld b,a
.pt:    push bc
        push de
        call add_score
        pop de
        pop bc
        djnz .pt
        ld a,(chain)
        cp 2
        jr c,.np
        add a,'0'
        ld (s_chain+1),a
        ld hl,s_chain
        ld b,(ix+O_SX)
        ld c,(ix+O_SY)
        call popup_at
.np:    ld (ix+O_TYPE),0
        ret
.pod:   ld a,SFX_PICKUP
        call play_sfx
        ld a,(ix+O_AUX)
        or a
        jr nz,.en
        ld a,(novas)
        cp 9
        jr nc,.en
        inc a
        ld (novas),a
        ld a,(hudflag)
        or 1
        ld (hudflag),a
        ld hl,s_novapod
        jr .pp
.en:    ld de,150
        call gain_energy
        ld hl,s_energypod
.pp:    call popup_centre
        ld (ix+O_TYPE),0
        ret
s_chain: db "X2",0
s_novapod: db "NOVA +1",0
s_energypod: db "ENERGY +150",0
; type -> quota index (FRT0 TRP1 TNK2 FHT3 ACE4)
quotamap: db 3,4,2,0,1,$FF,$FF,$FF,$FF,$FF,$FF

; hit_boss: turrets first, then the core
hit_boss:
        ld a,(ix+O_SIZE)
        cp 2
        jr nc,.near
.clang: ld b,CX
        ld c,CY
        ld a,3
        call burst
        ld a,SFX_CLANG
        jp play_sfx
.near:  ld a,(bossdead)
        or a
        ret nz
        ; which part is under the sights? offsets from the boss centre
        ld l,(ix+O_SX)
        ld a,CX
        sub l
        ld (bt_dx),a            ; sight - centre
        ld a,CY
        sub (ix+O_SY)
        ld (bt_dy),a
        ld hl,turpos
        ld b,0
.t:     ld a,(bt_dx)
        sub (hl)
        add a,5
        cp 11
        jr nc,.tn
        inc hl
        ld a,(bt_dy)
        sub (hl)
        dec hl
        add a,3
        cp 7
        jr nc,.tn
        ; turret B
        push hl
        ld hl,turhp
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        pop hl
        jr z,.tn
        push hl
        ld hl,turhp
        add hl,de
        dec (hl)
        ld a,(hl)
        pop hl
        ld (ix+O_FL),4
        or a
        jr nz,.hitonly
        ld de,pts_tur
        call add_score
        ld b,CX
        ld c,CY
        ld a,12
        call burst
        ld a,SFX_BIGBOOM
        call play_sfx
        ld hl,s_turret
        jp popup_centre
.hitonly:
        ld b,CX
        ld c,CY
        ld a,4
        call burst
        ld a,SFX_ZAP
        jp play_sfx
.tn:    inc hl
        inc hl
        inc b
        ld a,b
        cp 4
        jr nz,.t
        ; core?
        ld a,(turhp)
        ld hl,turhp+1
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        jp nz,.clang
        ld a,(bt_dx)
        add a,5
        cp 11
        jp nc,.clang
        ld a,(bt_dy)
        add a,3
        cp 7
        jp nc,.clang
        ld (ix+O_FL),4
        ld a,(corehp)
        dec a
        ld (corehp),a
        jr nz,.hitonly
        ; destroyed!
        ld de,pts_core
        call add_score
        ld a,1
        ld (bossdead),a
        ld (ix+O_TIM),80
        ld (ix+O_VAZ),0
        ld (ix+O_VAZ+1),0
        ld hl,s_core
        jp popup_centre
s_turret: db "TURRET DOWN",0
s_core: db "CORE DESTROYED!",0
; turret offsets (dx, dy) from the boss centre at full size
turpos: db -13,-5, 12,-5, -13,4, 12,4

fire_nova:
        ld a,(gstate)
        or a
        ret nz
        ld a,(novas)
        or a
        ret z
        dec a
        ld (novas),a
        ld a,(hudflag)
        or 1
        ld (hudflag),a
        ld a,SFX_NOVA
        call play_sfx
        ld a,6
        ld (flasht),a
        ; everything visible (except the boss and planet) is destroyed
        ld ix,OBJS
        ld b,NOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_BOSS
        jr z,.n
        cp T_PLANET
        jr z,.n
        cp T_POD
        jr z,.n
        ld a,(ix+O_VIS)
        or a
        call nz,kill_obj
.n:     ld de,OSZ
        add ix,de
        pop bc
        djnz .o
        ret

; add_score: DE = BCD points (D high)
add_score:
        ld a,(demo)
        or a
        ret nz
        ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,(hudflag)
        or 4
        ld (hudflag),a
        ret

abs16:
        bit 7,h
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; ---------------------------------------------------------------------
; particles: x 8.8, y 8.8, dx, dy (1/16 px), life, colour
; ---------------------------------------------------------------------
; burst: B = x, C = y (screen), A = count
burst:
        push ix
        call burst0
        pop ix
        ret
burst0:
        ld (bu_n),a
        ld a,b
        ld (bu_x),a
        ld a,c
        ld (bu_y),a
        ld ix,PARTS
        ld b,NPART
.p:     ld a,(ix+6)
        or a
        jr nz,.n
        ld a,(bu_x)
        ld (ix+1),a
        ld a,(bu_y)
        ld (ix+3),a
        ld (ix+0),128
        ld (ix+2),128
        push bc
        ld b,64
        call rand_pm
        ld (ix+4),a
        ld b,40
        call rand_pm
        ld (ix+5),a
        ld b,10
        call rand_n
        add a,6
        ld (ix+6),a
        call random
        and 1
        jr z,.c
        ld a,3
.c:     ld (ix+7),a
        pop bc
        ld a,(bu_n)
        dec a
        ld (bu_n),a
        ret z
.n:     ld de,8
        add ix,de
        djnz .p
        ret

update_parts:
        call crack_tick
        ld hl,(dvaz)
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (st_dx),hl
        ld ix,PARTS
        ld b,NPART
.p:     ld a,(ix+6)
        or a
        jr z,.n
        dec (ix+6)
        push bc
        ld a,(ix+4)
        ld e,a
        rla
        sbc a,a
        ld d,a
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,de
        ld de,(st_dx)
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        ld a,h
        cp 128
        jr c,.xo
        ld (ix+6),0
.xo:    ld a,(ix+5)
        ld e,a
        rla
        sbc a,a
        ld d,a
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld de,(dvel)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld a,h
        cp VIEWH
        jr c,.yo
        ld (ix+6),0
.yo:    pop bc
.n:     ld de,8
        add ix,de
        djnz .p
        ; chain timer, popups
        ld a,(chaint)
        or a
        jr z,.ct
        dec a
        ld (chaint),a
.ct:    ret

draw_parts:
        ld ix,PARTS
        ld b,NPART
.p:     ld a,(ix+6)
        or a
        jr z,.n
        push bc
        ld b,(ix+1)
        ld c,(ix+3)
        ld e,(ix+7)
        ld a,(ix+6)
        cp 4
        jr nc,.c
        ld e,0
.c:     call pset_c
        pop bc
.n:     ld de,8
        add ix,de
        djnz .p
        ret

; ---------------------------------------------------------------------
; popups (temporary text in the view)
; ---------------------------------------------------------------------
popup_centre:
        ld b,64
        ld c,30
; popup_at: HL = text, B = x, C = y (pixels)
popup_at:
        push hl
        ld hl,popt
        ld e,4
.f:     ld a,(hl)
        inc hl
        inc hl
        or a
        jr z,.got
        ld a,(hl)
        or a
        jr z,.got2
        inc hl
        inc hl
        inc hl
        dec e
        jr nz,.f
        pop hl
        ret
.got2:  dec hl
        dec hl
        jr .g
.got:   dec hl
        dec hl
.g:     ; col = x/4 - len/2, clamp
        pop de                  ; DE = text
        push hl
        ld h,d
        ld l,e
        ld a,0
.ln:    ld a,(hl)
        or a
        jr z,.le
        inc hl
        inc a
        jr .ln
.le:    or a
        sbc hl,de
        ld a,l
        srl a
        ld l,a
        ld a,b
        srl a
        srl a
        sub l
        jp p,.c1
        xor a
.c1:    pop hl
        ld (hl),a
        inc hl
        ld a,c
        sub 2
        jp p,.r1
        xor a
.r1:    cp VIEWH-5
        jr c,.r2
        ld a,VIEWH-6
.r2:    ld (hl),a
        inc hl
        ld (hl),40
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

draw_popups:
        ld hl,popt
        ld b,4
.p:     push bc
        push hl
        inc hl
        inc hl
        ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        push de
        ld d,a
        ld e,c
        pop hl
        push de
        push hl
        ld a,(tick)
        and 2
        ld a,1
        jr z,.ci
        ld a,3
.ci:    ld b,2
        call set_ink
        pop hl
        pop de
        call print
.n:     pop hl
        ld de,5
        add hl,de
        pop bc
        djnz .p
        ret

; ---------------------------------------------------------------------
; state machine: warp-in, play, clear, dying, warp-out
; ---------------------------------------------------------------------
update_state:
        ; energy drain
        ld a,(gstate)
        or a
        jp nz,.st
        ld a,(drainc)
        dec a
        ld (drainc),a
        jr nz,.dr
        ld a,(skill)
        add a,a
        ld b,a
        ld a,(lap)
        add a,a
        add a,b
        ld b,a
        ld a,16
        sub b
        jr nc,.d1
        ld a,4
.d1:    cp 4
        jr nc,.d2
        ld a,4
.d2:    ld (drainc),a
        ld a,1
        call lose_energy
        ; low energy alarm
        ld hl,(energy)
        ld de,150
        or a
        sbc hl,de
        jr nc,.dr
        ld a,(tick)
        and 31
        cp 12
        jr nc,.dr
        ld a,SFX_ALARM
        call play_sfx
.dr:    ld hl,(energy)
        ld a,h
        or l
        jr nz,.alive
        ; out of energy
        ld a,3
        ld (gstate),a
        ld hl,150
        ld (gtimer),hl
        ld hl,s_depleted
        ld (banner1),hl
        ld hl,s_gameover
        ld (banner2),hl
        ld a,255
        ld (bannert),a
        call stop_music
        ld hl,mus_over_0
        ld de,mus_over_1
        call play_music
        or a
        ret
.alive: ; sector cleared?
        ld a,(forceclear)
        or a
        jr nz,.clr
        ld hl,quota
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        jr nz,.notyet
        ld a,(secflags)
        and F_BOSS
        jr z,.clr
        ld a,(bossdead)
        cp 2
        jr nz,.notyet
.clr:   xor a
        ld (forceclear),a
        ld a,2
        ld (gstate),a
        ld hl,200
        ld (gtimer),hl
        ld hl,s_clear
        ld (banner1),hl
        ld hl,s_refuel
        ld (banner2),hl
        ld a,200
        ld (bannert),a
        call stop_music
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld hl,(energy)
        ld (ehold),hl
.notyet:
        call hud_update
        or a
        ret
.st:    ld hl,(gtimer)
        dec hl
        ld (gtimer),hl
        cp 1
        jr z,.warpin
        cp 2
        jr z,.clear
        cp 3
        jp z,.dying
        ; 4: warp out
        ld a,h
        or l
        jr nz,.wo
        ; next sector
        ld a,(sector)
        inc a
        cp 8
        jr c,.ns
        call mission_complete
        ld a,(lap)
        inc a
        ld (lap),a
        xor a
.ns:    ld (sector),a
        call start_sector
        or a
        ret
.wo:    ld a,l
        cp 40
        jr nc,.wk
        ld a,1
        ld (warpk),a
.wk:    call hud_update
        or a
        ret
.warpin:
        ; streaks while the timer runs
        ld a,l
        cp 30
        ld a,1
        jr nc,.wi
        ld a,4
.wi:    ld (warpk),a
        ld a,l
        cp 59
        jr nz,.wi2
        ld a,90
        ld (bannert),a
.wi2:   ld a,h
        or l
        jr nz,.wk
        xor a
        ld (gstate),a
        ld a,4
        ld (warpk),a
        call game_music
        or a
        ret
.clear: ; refuel tally: +2 energy a tick (up to 250), 5 points each
        ld a,l
        and 1
        jr nz,.cl2
        ld a,h
        or a
        jr nz,.cl2
        ld a,l
        cp 70
        jr c,.cl2
        ld hl,(energy)
        ld de,999
        or a
        sbc hl,de
        jr nc,.cl2
        ld de,3
        call gain_energy
        ld de,$0005
        call add_score
        ld a,SFX_TICK
        call play_sfx
.cl2:   call hud_update
        ld hl,(gtimer)
        ld a,h
        or l
        jr nz,.cl3
        ld a,4
        ld (gstate),a
        ld hl,70
        ld (gtimer),hl
        ld a,SFX_WARP
        call play_sfx
.cl3:   or a
        ret
.dying: call hud_update
        ld a,h
        or l
        jr z,.over
        ld a,l
        and 7
        jr nz,.dy2
        ld a,2
        ld (flasht),a
.dy2:   or a
        ret
.over:  scf
        ret
s_depleted: db "ENERGY DEPLETED",0
s_gameover: db "GAME OVER",0
s_clear: db "SECTOR CLEAR",0
s_refuel: db "REFUELLING",0

; ---------------------------------------------------------------------
; render the frame into BG
; ---------------------------------------------------------------------
render:
        ld a,VIEWH
        ld (clipbot),a
        ; palette flash
        ld a,(latchbase)
        and $FF-CSS1
        ld b,a
        ld a,(secflags)
        and F_CLOAK
        jr z,.p0
        ld a,b
        or CSS1
        ld b,a
.p0:    ld a,(flasht)
        or a
        jr z,.pf
        dec a
        ld (flasht),a
        bit 0,a
        jr z,.pf
        ld a,b
        xor CSS1
        ld b,a
.pf:    ld a,b
        ld (latchbase),a
        call update_stars
        call fs_check
        call draw_stars
        call fs_check
        call project_all
        call fs_check
        call draw_objects
        call fs_check
        call draw_parts
        call draw_bolts
        call draw_sights
        call fs_check
        call draw_popups
        call draw_banner
        ld a,64
        ld (clipbot),a
        call draw_radar
        ret

; crosshair: yellow cross, red centre (fixed bytes, ORed in)
SROW    equ BG+CY*32+15
draw_sights:
        ld a,(gstate)
        cp 3
        ret nc
        call sights_busy
        ld a,$14                ; yellow arms
        ld c,$C5
        ld d,$40
        jr nc,.col
        ld a,$3C                ; red arms when locked on
        ld c,$CF
        ld d,$C0
.col:   ld (sg_a),a
        ld a,c
        ld (sg_c),a
        ld a,d
        ld (sg_d),a
        ld hl,SROW
        ld a,(sg_a)
        ld b,a
        ld a,(hl)
        and $C3
        or b                    ; x 61,62
        ld (hl),a
        inc l
        ld a,(sg_c)
        ld b,a
        ld a,(hl)
        and $30
        or b                    ; x 64 red, 66,67
        ld (hl),a
        ld de,-96
        call .v
        ld de,-32
        call .v
        ld de,64
        call .v
        ld de,96
        call .v
        ld b,16
        ld c,15
        ld e,CY-3
.mk:    ld a,e
        push bc
        push de
        call mark
        pop de
        pop bc
        inc e
        ld a,e
        cp CY+4
        jr nz,.mk
        ret
.v:     ld hl,BG+CY*32+16
        add hl,de
        ld a,(sg_d)
        ld b,a
        ld a,(hl)
        and $3F
        or b                    ; x 64
        ld (hl),a
        ret

; bezel timer: flashes red/yellow after a hit; otherwise blinks yellow on
; the side a close threat is coming from (and ticks)
crack_tick:
        ld a,(crackt)
        or a
        jr z,.warn
        dec a
        ld (crackt),a
        jr z,.norm
        and 2
        ld a,4
        jr z,.set
        ld a,5
        jr .set
.warn:  ld a,(gstate)
        or a
        jr nz,.norm
        call threat_side
        or a
        jr z,.norm
        ld b,a
        ld a,(tick)
        and 4
        jr nz,.norm
        ld a,b
        jr .set
.norm:  xor a
.set:   ld hl,bezcol
        cp (hl)
        ret z
        ld (hl),a
        or a
        jr z,draw_bezel
        cp 4
        jr nc,draw_bezel
        push af
        ld a,SFX_TICK
        call play_sfx
        pop af
        jr draw_bezel

; threat_side: a fighter/ace/mine/plasma closer than z 9 ->
; A = 0 none, 1 left, 2 right, 3 ahead
threat_side:
        push ix
        ld ix,OBJS
        ld b,NOBJ
        ld c,0
.o:     ld a,(ix+O_TYPE)
        cp T_FHT
        jr z,.t
        cp T_ACE
        jr z,.t
        cp T_MINE
        jr z,.t
        cp T_PLASMA
        jr nz,.n
.t:     ld a,(ix+O_Z+1)
        cp 9
        jr nc,.n
        push bc
        call rel_az
        pop bc
        ld a,h
        add a,16
        cp 33
        jr nc,.side
        ld c,3
        jr .n
.side:  ld c,1
        bit 7,h
        jr nz,.n
        ld c,2
.n:     ld de,OSZ
        add ix,de
        djnz .o
        pop ix
        ld a,c
        ret

; draw_bezel: 50:50 dithered frame round the dashboard (BASE + BG)
draw_bezel:
        ld a,(bezcol)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,beztab
        add hl,de
        ld de,bz_top
        ld bc,4
        ldir
        ld a,(bz_top)
        ld c,a
        ld b,a
        ld a,VIEWH
        call bez_row
        ld a,(bz_top+1)
        ld c,a
        ld b,a
        ld a,VIEWH+1
        call bez_row
        ld a,(bz_top+1)
        ld c,a
        ld b,a
        ld a,63
        call bez_row
        ld d,VIEWH+2
.sd:    ld a,d
        call bgrow
        ld a,(bz_l)
        bit 0,d
        jr z,.e1
        rlca
        rlca
.e1:    ld (hl),a
        res 3,h
        ld (hl),a
        set 3,h
        ld a,l
        or 31
        ld l,a
        ld a,(bz_r)
        bit 0,d
        jr z,.e2
        rlca
        rlca
.e2:    ld (hl),a
        res 3,h
        ld (hl),a
        push de
        ld a,d
        ld c,0
        ld b,0
        call mark
        pop de
        push de
        ld a,d
        ld c,31
        ld b,31
        call mark
        pop de
        inc d
        ld a,d
        cp 63
        jr nz,.sd
        ret
; bez_row: A = row, C / B = bytes for even / odd columns
bez_row:
        push af
        call bgrow
        ld e,16
.b:     ld (hl),c
        res 3,h
        ld (hl),c
        set 3,h
        inc l
        ld (hl),b
        res 3,h
        ld (hl),b
        set 3,h
        inc l
        dec e
        jr nz,.b
        pop af
        ld c,0
        ld b,31
        jp mark
; per state: band bytes (row phase A, B), left side, right side
; dithers: red/yellow $DD/$77, red/blue $EE (rlca twice = next row)
beztab:
        db $DD,$77,$EE,$EE      ; normal
        db $DD,$77,$66,$EE      ; threat left: left side yellow/blue
        db $DD,$77,$EE,$66      ; threat right
        db $66,$99,$EE,$EE      ; threat ahead: band yellow/blue
        db $FF,$FF,$FF,$FF      ; hit flash: red
        db $55,$55,$55,$55      ; hit flash: yellow

; banner: two centred lines
draw_banner:
        ld a,(bannert)
        or a
        ret z
        cp 255
        jr z,.k
        dec a
        ld (bannert),a
.k:     ld a,1
        ld b,2
        call set_ink
        ld hl,(banner1)
        ld e,10
        call print_c
        ld a,3
        ld b,2
        call set_ink
        ld hl,(banner2)
        ld e,17
        jp print_c

; project all objects to the screen and sort far -> near
project_all:
        xor a
        ld (sortn),a
        ld ix,OBJS
        ld b,NOBJ
        ld c,0
.o:     push bc
        ld (ix+O_VIS),0
        ld a,(ix+O_TYPE)
        or a
        jp z,.n
        call rel_az
        ld a,h
        add a,30
        cp 61
        jp nc,.n                ; outside +-30 units
        ; sx = 64 + rel/64
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
        ld de,CX
        add hl,de
        ld (ix+O_SX),l
        ld (ix+O_SX+1),h
        ; sy = CY + vel - el
        ld hl,(vel)
        ld e,(ix+O_EL)
        ld d,(ix+O_EL+1)
        or a
        sbc hl,de
        ld de,128
        add hl,de               ; round
        ld a,h
        add a,CY
        ld (ix+O_SY),a
        ld a,h
        add a,40
        cp 104
        jr nc,.n
        ; size
        ld a,(ix+O_TYPE)
        call spr_of
        ld e,a
        cp SPR_PLANET
        ld a,0
        jr z,.sz
        ld a,e
        add a,a
        ld l,a
        ld h,0
        ld de,ztabtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(ix+O_Z+1)
        cp 64
        jr c,.zk
        ld a,63
.zk:    ld l,a
        ld h,0
        add hl,de
        ld a,(hl)
.sz:    ld (ix+O_SIZE),a
        cp $FE
        jr z,.n
        ; cloaked fighters in the nebula
        ld a,(secflags)
        and F_CLOAK
        jr z,.vis
        ld a,(ix+O_TYPE)
        cp T_FHT
        jr nz,.vis
        ld a,(ix+O_Z+1)
        cp 22
        jr c,.vis
        ld a,(tick)
        and 6
        jr nz,.n
.vis:   ld (ix+O_VIS),1
        ; add to sort list (index, z)
        pop bc
        push bc
        ld a,(sortn)
        ld e,a
        ld d,0
        ld hl,sortl
        add hl,de
        ld (hl),c
        inc a
        ld (sortn),a
.n:     ld de,OSZ
        add ix,de
        pop bc
        inc c
        dec b
        jp nz,.o
        ; insertion sort by z (descending: far first)
        ld a,(sortn)
        cp 2
        ret c
        ld b,1
.is:    ld a,(sortn)
        cp b
        ret z
        ld c,b
.in:    ld a,c
        or a
        jr z,.nb
        ld hl,sortl
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        call zof
        ld e,a
        dec hl
        ld a,(hl)
        push de
        call zof
        pop de
        cp e
        jr nc,.nb               ; previous is farther or equal: done
        ld a,(hl)
        inc hl
        ld d,(hl)
        ld (hl),a
        dec hl
        ld (hl),d
        dec c
        jr .in
.nb:    inc b
        jr .is
; A = object index -> A = z (planet counts as farthest)
zof:
        push hl
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,OBJS
        add hl,de
        ld a,(hl)
        cp T_PLANET
        ld a,255
        jr z,.p
        ld de,O_Z+1
        add hl,de
        ld a,(hl)
.p:     pop de
        pop hl
        ret

; type -> sprite index
spr_of:
        cp T_PLASMA
        jr c,.n
        cp T_BOSS
        ld a,SPR_BOSS
        ret z
        ld a,SPR_PLANET
        ret
.n:     dec a
        ret

draw_objects:
        ld a,(sortn)
        or a
        ret z
        ld b,a
        ld hl,sortl
.o:     push bc
        push hl
        ld l,(hl)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,OBJS
        add hl,de
        push hl
        pop ix
        call draw_obj
        call fs_check
        pop hl
        inc hl
        pop bc
        djnz .o
        ret

draw_obj:
        ld a,(ix+O_TYPE)
        cp T_PLASMA
        jp z,draw_plasma
        ; hit flash: flicker
        ld a,(ix+O_FL)
        and 1
        jr z,.d
        ld a,(ix+O_FL)
        cp 3
        jr c,.d
        ld (ix+O_HW),2
        ld (ix+O_HH),2
        ret
.d:     ld a,(ix+O_TYPE)
        call spr_of
        ld c,(ix+O_SIZE)
        ld l,(ix+O_SX)
        ld h,(ix+O_SX+1)
        ld e,(ix+O_SY)
        call draw_spr
        ld a,(spr_hw)
        ld (ix+O_HW),a
        ld a,(spr_hh)
        ld (ix+O_HH),a
        ; engine glow on convoys
        ld a,(ix+O_TYPE)
        cp T_TNK
        jr c,.ng
        cp T_ROCK
        jr nc,.ng
        ld a,(tick)
        and 1
        ret z
        ld a,(ix+O_VAZ+1)
        ld b,(ix+O_SX)
        ld a,(ix+O_HW)
        bit 7,(ix+O_VAZ+1)
        jr nz,.gr
        neg
        sub 1
        jr .gg
.gr:    inc a
.gg:    add a,b
        ld b,a
        ld c,(ix+O_SY)
        ld e,1
        jp pset_c
.ng:    cp T_BOSS
        ret nz
        jp draw_boss_fx

; plasma: a pulsing blob, bigger as it nears
draw_plasma:
        ld a,(ix+O_Z+1)
        ld b,0
        cp 12
        jr nc,.r
        inc b
        cp 6
        jr nc,.r
        inc b
        cp 3
        jr nc,.r
        inc b
.r:     ld a,b
        ld (ix+O_HW),a
        ld (ix+O_HH),a
        ld (bu_n),a
        ld a,(ix+O_SX+1)
        or a
        ret nz
        ld b,(ix+O_SX)
        ld c,(ix+O_SY)
        ld a,(tick)
        and 1
        ld e,3
        jr z,.c
        ld e,1
.c:     push bc
        call pset_c
        pop bc
        ld a,(bu_n)
        or a
        ret z
        ld e,3
        dec b
        push bc
        call pset_c
        pop bc
        inc b
        inc b
        push bc
        call pset_c
        pop bc
        dec b
        dec c
        push bc
        call pset_c
        pop bc
        inc c
        inc c
        push bc
        call pset_c
        pop bc
        ld a,(bu_n)
        cp 2
        ret c
        dec c
        ld e,1
        dec b
        dec b
        push bc
        call pset_c
        pop bc
        inc b
        inc b
        inc b
        inc b
        jp pset_c

; boss extras: damaged turrets burn, exposed core pulses
draw_boss_fx:
        ld a,(ix+O_SIZE)
        cp 2
        ret c
        ld hl,turpos
        ld de,turhp
        ld b,4
.t:     push bc
        push hl
        push de
        ld a,(de)
        or a
        jr nz,.n
        ld a,(ix+O_SX)
        add a,(hl)
        ld b,a
        inc hl
        ld a,(ix+O_SY)
        add a,(hl)
        ld c,a
        ld a,(tick)
        and 1
        add a,a
        ld e,a                  ; green/blue flicker = smoke
        push bc
        call pset_c
        pop bc
        inc b
        ld e,3
        push bc
        call pset_c
        pop bc
        dec c
        ld a,(tick)
        and 2
        ld e,1
        jr z,.f
        ld e,3
.f:     call pset_c
.n:     pop de
        pop hl
        inc hl
        inc hl
        inc de
        pop bc
        djnz .t
        ; core open?
        ld a,(turhp)
        ld hl,turhp+1
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        ret nz
        ld a,(tick)
        and 2
        ret z
        ld b,(ix+O_SX)
        ld c,(ix+O_SY)
        ld e,1
        dec b
        push bc
        call pset_c
        pop bc
        inc b
        push bc
        call pset_c
        pop bc
        inc b
        jp pset_c

; radar: every object as a dot in the HUD scope
draw_radar:
        call fs_check
        ld ix,OBJS
        ld b,NOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_PLANET
        jr z,.n
        cp T_FHT
        jr nz,.nc
        ld a,(secflags)
        and F_CLOAK
        jr z,.nc
        ld a,(ix+O_Z+1)
        cp 30
        jr nc,.n
.nc:    call rel_az
        ld a,h
        sra a
        sra a
        ld b,a
        ld a,h
        sra a
        sra a
        sra a
        sra a
        sra a
        neg
        add a,b                 ; ~ rel * 0.22
        cp 27
        jr c,.xp
        cp -26
        jr nc,.xp
        bit 7,a
        ld a,26
        jr z,.xp
        ld a,-26
.xp:    add a,64
        ld b,a
        ld a,(ix+O_EL+1)
        sra a
        sra a
        sra a
        neg
        cp 5
        jr c,.yp
        cp -4
        jr nc,.yp
        bit 7,a
        ld a,4
        jr z,.yp
        ld a,-4
.yp:    add a,57
        ld c,a
        ld a,(ix+O_TYPE)
        ld e,a
        ld d,0
        ld hl,typecol-1
        add hl,de
        ld e,(hl)
        ld a,e
        cp 2
        jr nz,.cc
        ld e,1
.cc:    call pset_c
.n:     ld de,OSZ
        add ix,de
        pop bc
        dec b
        jp nz,.o
        ret

; mission complete: shown between laps
mission_complete:
        ld a,1
        ld (endflag),a
        jp ending_screen

; ---------------------------------------------------------------------
; demo / autoplay AI: chase the nearest threat and shoot
; ---------------------------------------------------------------------
ai_play:
        ld a,(autoplay)
        or a
        ret z
        ld c,0
        ld iy,0
        ld ix,OBJS
        ld b,NOBJ
        ld e,255
.o:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_PLANET
        jr z,.n
        ld d,(ix+O_Z+1)
        cp T_ROCK
        jr z,.lo
        cp T_TNK
        jr c,.hi
        cp T_PLASMA
        jr nc,.hi
        cp T_MINE
        jr z,.hi
.lo:    ld a,d                  ; non-threats count as farther
        add a,64
        jr nc,.lo2
        ld a,250
.lo2:   ld d,a
.hi:    ld a,d
        cp e
        jr nc,.n
        ld e,a
        push ix
        pop iy
.n:     push de
        ld de,OSZ
        add ix,de
        pop de
        djnz .o
        xor a
        ld (inp),a
        push iy
        pop ix
        ld a,ixh
        or ixl
        ret z
        ld c,0
        ld a,(ix+O_VIS)
        or a
        jp z,.far
        ; on screen: steer by screen position (boss: aim at a live turret / the core)
        xor a
        ld (bt_dx),a
        ld (bt_dy),a
        ld a,2
        ld (bu_n),a             ; aim tolerance
        ld a,(ix+O_TYPE)
        cp T_BOSS
        jr nz,.aim
        ld a,(ix+O_SIZE)
        cp 2
        jr c,.aim
        ld hl,turpos
        ld de,turhp
        ld b,4
.tl:    ld a,(de)
        or a
        jr nz,.tf
        inc hl
        inc hl
        inc de
        djnz .tl
        jr .aimb                ; core (offset 0,0)
.tf:    ld a,(hl)
        ld (bt_dx),a
        inc hl
        ld a,(hl)
        ld (bt_dy),a
.aimb:  xor a
        ld (bu_n),a
.aim:   ld a,(ix+O_SX+1)
        or a
        jr nz,.far
        ld a,(bt_dx)
        add a,(ix+O_SX)
        sub CX                  ; ex
        ld b,a
        ld a,(bt_dy)
        add a,(ix+O_SY)
        sub CY                  ; ey
        ld d,a
        ld a,b
        cp 2
        jr c,.xok0
        cp -1
        jr nc,.xok0
        bit 7,a
        jr nz,.xl
        set 0,c
        jr .xok0
.xl:    set 1,c
.xok0:  ld a,d
        cp 2
        jr c,.yok
        cp -1
        jr nc,.yok
        bit 7,a
        jr nz,.yu
        set 3,c                 ; target below centre: scan down
        jr .yok
.yu:    set 2,c
.yok:   ; fire when inside the target box
        ld a,(bu_n)
        or a
        ld a,(ix+O_HW)
        jr nz,.fw
        ld a,2
.fw:    add a,1
        ld e,a
        ld a,b
        bit 7,a
        jr z,.p1
        neg
.p1:    cp e
        jr nc,.done
        ld a,(bu_n)
        or a
        ld a,(ix+O_HH)
        jr nz,.fh
        ld a,2
.fh:    add a,1
        ld e,a
        ld a,d
        bit 7,a
        jr z,.p2
        neg
.p2:    cp e
        jr nc,.done
        set 4,c
        jr .done
.far:   call rel_az
        ld a,h
        bit 7,a
        jr nz,.l
        or a
        jr nz,.r
        ld a,l
        cp 200
        jr c,.ud
.r:     set 0,c
        jr .ud
.l:     inc a
        jr nz,.l2
        ld a,l
        cp 56
        jr nc,.ud
.l2:    set 1,c
.ud:    ld hl,(vel)
        ld a,(ix+O_EL+1)
        sub h
        jr z,.done
        jp m,.dn
        cp 2
        jr c,.done
        set 2,c
        jr .done
.dn:    cp -1
        jr nc,.done
        set 3,c
.done:  push bc
        call sights_busy
        pop bc
        jr nc,.nf
        set 4,c
.nf:    ld a,c
        ld (inp),a
        ret
; sights_busy: carry if any visible object is under the crosshair
sights_busy:
        ld ix,OBJS
        ld b,NOBJ
.o:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_PLANET
        jr z,.n
        ld a,(ix+O_VIS)
        or a
        jr z,.n
        ld a,(ix+O_SX+1)
        or a
        jr nz,.n
        ld a,(ix+O_SX)
        sub CX
        jp p,.a1
        neg
.a1:    ld c,a
        ld a,(ix+O_HW)
        inc a
        cp c
        jr c,.n
        ld a,(ix+O_SY)
        sub CY
        jp p,.a2
        neg
.a2:    ld c,a
        ld a,(ix+O_HH)
        inc a
        cp c
        jr c,.n
        scf
        ret
.n:     ld de,OSZ
        add ix,de
        djnz .o
        or a
        ret
