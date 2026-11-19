; ==========================================================================
; main.asm - BUNYIP: a first-person adventure for the Microbee Premium Plus
;   VIBED BY BPM 2026
;
; BUNYIP.COM (the loader) puts this program at 8000h of the upper 32K and
; the game's data into RAM blocks:
;   block 1  TABLES.BIN  ray tables, the zone map, the seen-map
;   block 2  ZONES.BIN   the four zones
;   block 3  ART.BIN     sprite masters
;   block 4  PCG.BIN     PCG glyphs (walls, font, title), also the tileset
;   blocks 6-21          sprites, shrunk to 16 sizes at start-up
; ==========================================================================
        org 8000h
        jp start

        include "hw.asm"
        include "defs.asm"
        include "../build/tabsym.inc"
        include "../build/artsym.inc"
        include "../build/zonesym.inc"
        include "../build/frontsym.inc"

PORT_PIOBC equ 03h
LEVERS  equ ZH+(Z_LEVERS-400h)
GATES   equ ZH+(Z_GATES-400h)
ZINKS   equ ZH+(Z_INKS-400h)
ZKINDS  equ ZH+(Z_KINDS-400h)
SOLID   equ MAP+1C00h       ; 1 where scenery blocks the cell (block 1)
ZHN     equ 2C8h            ; the header up to the end of the textures

; --------------------------------------------------------------------------
start:  di
        ld sp,0EFF0h
        ld a,BLK_TAB
        call setblk
        ld a,0CFh               ; PIO B: bit mode, bit 6 (speaker) out
        out (PORT_PIOBC),a
        ld a,0BFh
        out (PORT_PIOBC),a
        ld a,07h
        out (PORT_PIOBC),a
        xor a
        out (PORT_PIOB),a
        ld (spk),a
        ld hl,POPC              ; bit counts
.pc     ld a,l
        ld b,0
.pb     or a
        jr z,.pd
        srl a
        jr nc,.pb
        inc b
        jr .pb
.pd     ld (hl),b
        inc l
        jr nz,.pc
        ld hl,ROW40             ; screen row addresses
        ld de,VRAM
        ld b,26
.rw     ld (hl),e
        inc l
        ld (hl),d
        inc l
        ex de,hl
        ld bc,40
        add hl,bc
        ex de,hl
        ld a,l
        cp 52
        jr nz,.rw
        call init_video
        ld bc,0010h             ; all 16 PCG banks
        call upload_pcg
        call showpage0
        ld b,CWHITE
        call cls
        ld hl,T_PREP
        ld de,10*40+2
        ld b,CYELLOW
        call printc
        call prescale_all
        ld hl,1234h
        ld (seed),hl

title:  ld a,(dbg_on)
        or a
        call z,front
        ; a new game
        ld a,100
        ld (health),a
        ld a,30
        ld (charges),a
        ld hl,0
        ld (score),hl
        ld a,(dbg_zone)
        ld (zone),a
.zone   call zone_load
        ld a,(dbg_on)
        or a
        call z,zone_intro       ; (makes the zone's sprites while it is read)
        ld a,(dbg_on)
        or a
        call nz,prescale_zone
        call play
        call zone_clear
        ld a,(zone)
        inc a
        ld (zone),a
        cp NZONES
        jr c,.zone
        call victory
        jr title

; make_litc: LITC = lit pixels of every glyph in the tileset (block 4)
make_litc:
        ld a,BLK_PCG
        call setblk
        ld hl,13*128
        ld (litn),hl
        ld hl,0
        ld de,LITC
.g      ld b,CELLH
        ld c,0
.l      ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,high(POPC)
        ld a,c
        add a,(hl)
        ld c,a
        pop hl
        djnz .l
        ld a,c
        ld (de),a
        inc de
        push hl
        ld hl,(litn)
        dec hl
        ld (litn),hl
        ld a,h
        or l
        pop hl
        jr nz,.g
        jp tabblk

NCOMMON equ IMG_RB_A          ; images 0.. NCOMMON-1 are in every zone
T_PREP: db "SHARPENING THE PIXELS. BOTH OF THEM.",0


; --------------------------------------------------------------------------
; zone_load: zone (zone) from block 2: map, header, colours, things
; --------------------------------------------------------------------------
zone_load:
        ld a,BLK_ZONES
        call setblk
        ld a,(zone)
        add a,a
        add a,a
        add a,a
        add a,a
        ld h,a
        ld l,0                  ; zone * 1000h
        ld de,SHADOW            ; map + header into the scratch area
        ld bc,800h
        ldir
        call tabblk
        ld hl,SHADOW
        ld de,MAP
        ld bc,1024
        ldir
        ld de,ZH
        ld bc,ZHN
        ldir
        ld hl,SEEN              ; nothing seen yet
        ld de,SEEN+1
        ld bc,1023
        ld (hl),0
        ldir
        ld hl,SOLID             ; no scenery in the way yet
        ld de,SOLID+1
        ld bc,1023
        ld (hl),0
        ldir
        call spawn_all
        xor a
        ld (keys),a
        ld (kills),a
        ld (opals),a
        ld (secrets),a
        ld (bossdead),a
        ld (zdone),a
        ld (losn),a
        call wallgen
        call colours
        jp to_start

; --------------------------------------------------------------------------
; wallgen: the zone's wall glyphs.  Banks 0-5 (above the horizon) and 6-11
;   (below it, over the zone's floor) of the tileset in block 4 are made
;   from six 8 x 10 textures: the zone's three (Z_TEX: lit wall, shaded
;   wall, accent) and the door, gate and panel every zone shares.  Then
;   they go to PCG RAM, and LITC (lit dots per glyph) is counted.
; --------------------------------------------------------------------------
wallgen:
        ld a,BLK_PCG
        call setblk
        xor a
        ld (wg_p),a
        ld hl,0
        ld (wg_t),hl
        ld hl,NPAT*1280
        ld (wg_b),hl
.p      ld a,(wg_p)
        ld hl,ZH+(Z_TEX-400h)
        cp 3
        jr c,.pp
        sub 3
        ld hl,PAT_FIXED
.pp     add a,a
        ld e,a
        add a,a
        add a,a
        add a,e                 ; * 10
        ld e,a
        ld d,0
        add hl,de
        ld (wg_pat),hl
        ld b,0                  ; B = scanlines of wall in the left half
.l      ld c,0                  ; C = ... the right half
.r      push bc
        ld d,0                  ; D = scanline
.y      ld hl,(wg_pat)
        ld a,d
        add a,l
        ld l,a
        jr nc,.n1
        inc h
.n1     ld e,(hl)               ; E = the texture's line
        ; above the horizon: wall up from the cell's bottom (y + n >= 10)
        ld h,0
        ld a,d
        add a,b
        cp CELLH
        jr c,.tl
        ld a,e
        and 0F0h
        ld h,a
.tl     ld a,d
        add a,c
        cp CELLH
        jr c,.tr
        ld a,e
        and 0Fh
        or h
        ld h,a
.tr     ld a,h
        ld hl,(wg_t)
        ld (hl),a
        inc hl
        ld (wg_t),hl
        ; below it: wall down from the cell's top (y < n), floor under it
        ld hl,ZH+(Z_TEX-400h)+30
        ld a,d
        add a,l
        ld l,a
        jr nc,.n2
        inc h
.n2     ld l,(hl)               ; L = the floor's line
        ld a,d
        cp b
        ld a,e
        jr c,.bl
        ld a,l
.bl     and 0F0h
        ld h,a
        ld a,d
        cp c
        ld a,e
        jr c,.br
        ld a,l
.br     and 0Fh
        or h
        ld hl,(wg_b)
        ld (hl),a
        inc hl
        ld (wg_b),hl
        inc d
        ld a,d
        cp CELLH
        jr nz,.y
        pop bc
        inc c
        ld a,c
        cp CELLH+1
        jr nz,.r
        inc b
        ld a,b
        cp CELLH+1
        jr nz,.l
        ld de,1280-1210         ; on to the next bank
        ld hl,(wg_t)
        add hl,de
        ld (wg_t),hl
        ld hl,(wg_b)
        add hl,de
        ld (wg_b),hl
        ld hl,wg_p
        inc (hl)
        ld a,(hl)
        cp NPAT
        jp nz,.p
        ld bc,000Ch             ; banks 0..11 to PCG RAM
        call upload_pcg
        jp make_litc

wg_p:   db 0
wg_t:   dw 0
wg_b:   dw 0
wg_pat: dw 0
; texture for each kind of wall cell (0: the wall's own, lit or shaded face)
TPAT:   db 0,0,0,2,2,3,3,3,3,5,2,5,4,0,4,2

; to_start: the player at the zone's start
to_start:
        ld hl,ZH+(Z_START-400h)
        ld a,(hl)
        ld (px+2),a
        inc hl
        ld a,(hl)
        ld (py+2),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (pa),de
        ld hl,8000h
        ld (px),hl
        ld (py),hl
        ld a,(dbg_on)           ; test builds: start where told
        or a
        ret z
        ld a,(dbg_x)
        ld (px+2),a
        ld a,(dbg_y)
        ld (py+2),a
        ld hl,(dbg_a)
        ld (pa),hl
        ret

; colours: the shade tables, papers and floor dots for the zone and mode
colours:
        ld a,(mono)
        or a
        ld a,0
        jr z,.m
        ld a,128
.m      ld (M_shofs+1),a
        ; SHC / SHP: key = type * 8 + side * 4 + band
        ld hl,SHC
        ld c,0
.k      ld a,c
        rrca
        rrca
        and 1
        ld b,a                  ; side
        ld a,c
        rrca
        rrca
        rrca
        and 15                  ; type
        add a,a
        add a,b
        ld e,a
        ld d,0
        push hl
        ld hl,ZINKS
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a               ; colour ink
        inc h
        push hl
        ld a,c
        rrca
        rrca
        rrca
        and 15
        ld e,a
        ld d,0
        ld hl,TPAT
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.p
        ld a,b                  ; plain walls: lit or shaded face
.p      ld (hl),a               ; the texture, in colour
        set 7,l
        ld (hl),a               ; ... and in mono
        dec h
        ld (hl),CWHITE          ; mono ink
        res 7,l
        inc l
        inc c
        bit 7,c
        jr z,.k
        ; papers and floor dots
        ld a,(mono)
        or a
        jr z,.col
        xor a
        ld (cpaper),a
        ld (fpaper),a
        ld a,CGREY
        ld (floorc),a
        ret
.col    ld a,(ZH+(Z_CEIL-400h))
        add a,a
        add a,a
        add a,a
        add a,a
        ld (cpaper),a
        ld a,(ZH+(Z_FLOOR-400h))
        add a,a
        add a,a
        add a,a
        add a,a
        ld (fpaper),a
        ld a,(ZH+(Z_FLINK-400h))
        ld (floorc),a
        ret

; --------------------------------------------------------------------------
; text screens
; --------------------------------------------------------------------------
zone_intro:
        call showpage0
        ld b,CWHITE
        call cls
        ld hl,T_ZONE
        ld de,3*40+4
        ld b,CYELLOW
        call printc
        ld a,(zone)
        add a,'1'
        ld b,CYELLOW
        call putch
        ld hl,ZH+(Z_NAME-400h)
        ld de,5*40+4
        ld b,CBGREEN
        call printc
        ld hl,ZH+(Z_INTRO-400h)
        ld de,8*40+2
        ld c,4
.l      push bc
        push hl
        push de
        ld b,CWHITE
        call printc
        pop hl
        ld de,40
        add hl,de
        ex de,hl
        pop hl
        ld bc,40
        add hl,bc
        pop bc
        dec c
        jr nz,.l
        ld hl,ZH+(Z_HINT-400h)
        ld de,14*40+1
        ld b,CBCYAN
        call printc
        call prescale_zone
        ld hl,T_ENTER
        ld de,20*40+7
        ld b,CYELLOW
        call printc
        jp wait_space

T_ENTER: db "PRESS SPACE. DEEP BREATH.",0

; wait_space: until SPACE is pressed (after it is let go)
wait_space:
.r      call wait_vb
        call readkeys
        ld a,(keyst+KY_FIRE)
        or a
        jr nz,.r
.w      call wait_vb
        call readkeys
        ld a,KY_FIRE
        call edge
        jr z,.w
        ret

zone_clear:
        call showpage0
        ld b,CWHITE
        call cls
        ld hl,T_ZONE
        ld de,4*40+10
        ld b,CYELLOW
        call printc
        ld a,(zone)
        add a,'1'
        ld b,CYELLOW
        call putch
        ld hl,T_CLEAR
        ld de,4*40+17
        ld b,CYELLOW
        call printc
        ld hl,T_CREAT
        ld de,8*40+8
        ld a,(kills)
        ld c,a
        ld a,(ncreat)
        call stat
        ld hl,T_OPALS
        ld de,10*40+8
        ld a,(opals)
        ld c,a
        ld a,(nopals)
        call stat
        ld hl,T_SECR
        ld de,12*40+8
        ld a,(secrets)
        ld c,a
        ld a,0FFh
        call stat
        ld hl,T_SCORE
        ld de,15*40+8
        ld b,CWHITE
        call printc
        ld hl,(score)
        ld de,15*40+24
        ld a,5
        ld b,CYELLOW
        call prnum
        ld hl,T_ON
        ld de,20*40+6
        ld b,CYELLOW
        call printc
        jp wait_space

; stat: text HL at DE, then "C OF A" (A = 0FFh: just C)
stat:   push af
        push bc
        push de
        ld b,CWHITE
        call printc
        pop de
        ld hl,16
        add hl,de
        ex de,hl
        pop bc
        ld l,c
        ld h,0
        ld a,2
        ld b,CBGREEN
        push de
        call prnum
        pop de
        pop af
        cp 0FFh
        ret z
        push af
        inc de
        inc de
        ld hl,T_OF
        ld b,CGREY
        call printc
        pop af
        ld l,a
        ld h,0
        ld a,2
        ld b,CWHITE
        jp prnum

T_CLEAR: db "SURVIVED!",0
T_CREAT: db "CREATURES",0
T_OPALS: db "OPALS",0
T_SECR:  db "SECRETS",0
T_OF:    db " OF ",0
T_ON:    db "PRESS SPACE. IT GETS WORSE.",0

victory:
        call showpage0
        ld b,CWHITE
        call cls
        ld hl,T_V1
        ld de,4*40+4
        ld b,CYELLOW
        call printc
        ld hl,T_V2
        ld de,7*40+4
        call print
        ld hl,T_V3
        ld de,8*40+4
        call print
        ld hl,T_V4
        ld de,9*40+4
        call print
        ld hl,T_SCORE
        ld de,13*40+12
        ld b,CWHITE
        call printc
        ld hl,(score)
        ld de,13*40+19
        ld a,5
        ld b,CYELLOW
        call prnum
        ld hl,T_CRED
        ld de,18*40+12
        ld b,CBGREEN
        call printc
        ld hl,T_ON
        ld de,22*40+6
        ld b,CGREY
        call printc
        jp wait_space

T_CRED: db "VIBED BY BPM 2026",0
T_V1:   db "THE BUNYIP IS HAVING A LIE DOWN",0
T_V2:   db "THE BLACK WATER STILLS. THE SHIRE",0
T_V3:   db "IS SAFE, THE OPALS ARE BACK AND",0
T_V4:   db "THE COUNCIL OWES YOU A NEW PIE.",0

; --------------------------------------------------------------------------
; play: the zone, until its exit
; --------------------------------------------------------------------------
play:   ld b,CWHITE
        call cls
        xor a
        ld (show_gun),a         ; (drawn as fixed glyphs instead: draw_gun)
        ld a,25
        ld (firecd),a
        call hud_all
        call view_reset
        ld a,MSG_HINT
        call message
        ld hl,(fields)
        ld (flast),hl
.f      call readkeys
        ld a,KY_C
        call edge
        call nz,swap_mode
        ld a,KY_R
        call edge
        call nz,swap_rays
        ld a,KY_M
        call edge
        call nz,automap
        ld a,KY_P
        call edge
        call nz,pause
        ld hl,(pwrt)            ; the Southern Cross fades
        ld a,h
        or l
        jr z,.pw0
        ld a,(nstep)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        jr nc,.pw1
        ld hl,0
.pw1    ld (pwrt),hl
        ld a,h
        or l
        jr nz,.pw0
        inc a
        ld (hud_dirty),a
.pw0    call player_input
        call actors
        ld a,(zdone)
        or a
        ret nz
        ld a,(health)
        or a
        call z,overcome
P_render:
        call restore_page
        call frame_setup
        call render
P_sprites:
        call proj_all
        call draw_sprites
        call draw_gun
P_hud:  call hud_tick
P_flip: call flip
        jr .f

; draw_gun: the zapper, 4 x 3 font glyphs at the bottom of the hidden page
draw_gun:
        ld hl,VRAM+19*40+17
        ld a,(page)
        or a
        jr z,.p
        ld hl,VRAM+400h+19*40+17
.p      ld de,GUNMAP
        ld c,CGREY
        ld a,(gun_fire)
        or a
        jr z,.nf
        ld de,GUNMAP+24
        ld c,CYELLOW
        jr .f
.nf     ld a,(pwrt)             ; powered up: a yellow zapper
        ld b,a
        ld a,(pwrt+1)
        or b
        jr z,.f
        ld c,CYELLOW
.f      ld a,(mono)
        or a
        jr z,.m
        ld c,CWHITE
.m      ld b,4
.r      push bc
        ld b,6
.c      ld a,(de)
        inc de
        or a
        jr z,.s                 ; not part of the zapper: the view shows
        ld (hl),a
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld (hl),FONT_BANK
        ld a,X1C
        out (PORT_1C),a
        set 3,h
        ld a,40h
        out (PORT_08),a
        ld (hl),c
        xor a
        out (PORT_08),a
        res 3,h
.s      inc hl
        djnz .c
        ld bc,40-6
        add hl,bc
        pop bc
        djnz .r
        ret

; view_reset: empty 3D view on both pages, no sprite cells to put back
view_reset:
        call reset_view
        xor a
        ld (RLIST0),a
        ld (RLIST1),a
        ld (nvis),a
        ld a,1
        ld (hud_dirty),a
        ret

swap_mode:
        ld a,(mono)
        xor 1
        ld (mono),a
        call colours
        call view_reset
        jp hud_all

; swap_rays: R - sharp walls (80 rays) or fast walls (40 rays)
swap_rays:
        ld a,(M_rays+1)
        xor 1
        ld (M_rays+1),a
        ld a,MSG_SHARP
        jr nz,.m
        ld a,MSG_FAST
.m      jp message

pause:  ld a,MSG_PAUSE
        call message
.w      call wait_vb
        call readkeys
        ld a,KY_P
        call edge
        jr z,.w
        call msg_clear
        ld hl,(fields)
        ld (flast),hl
        ret

; overcome: out of health - a moment, then back at the start, forgiven
overcome:
        ld a,MSG_DEAD
        call message
        ld a,SND_BOSS
        call snd_play
        ld b,60
.w      push bc
        call snd_wait
        pop bc
        djnz .w
        ld a,100
        ld (health),a
        ld a,(charges)
        cp 20
        jr nc,.c
        ld a,20
        ld (charges),a
.c      call to_start
        call view_reset
        ld hl,(fields)
        ld (flast),hl
        ld a,1
        ld (hud_dirty),a
        ret

        include "front.asm"
        include "engine.asm"
        include "sprite.asm"
        include "prescale.asm"
        include "player.asm"
        include "actors.asm"
        include "hud.asm"
        include "vars.asm"
