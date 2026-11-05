; ===========================================================================
;  egg.asm - THE FORGOTTEN MAZE - 1984   (a tribute to the original)
;  Switches to the crude mode 0 display of the original BASIC game.
; ===========================================================================

forgotten_maze:
            ld a,TX_PLAQUE
            call show_text_wait
            ld a,MUS_MAZE
            call play_music
            ; the 1984 screens live on the SD card
            ld ix,f_egg
            ld de,EGGBUF
            xor a
            call sd_load
            ; mode 0, green
            xor a
            call set_latch
            call m0_cls
            ld hl,m0_welcome
            ld de,BACK
            call m0_print
            call m0_present
            call wait_key
            ld a,5
            ld (egg_steps),a
.step:      ; pick a corridor picture
            call m0_cls
            call random
            and 3
            ld hl,egg_ahead
            cp 2
            jr c,.p
            ld hl,egg_left
            jr z,.p
            ld hl,egg_right
.p:         call copy512
            ld hl,m0_facing
            ld de,BACK+52
            call m0_print
            ld hl,m0_prompt
            ld de,BACK+15*32
            call m0_print
            call m0_present
            call m0_wait_nesw
            ld hl,egg_steps
            dec (hl)
            jr nz,.step
            ; Dracula appears...
            call m0_cls
            ld hl,egg_dracula
            call copy512
            ld hl,m0_need
            ld de,BACK+82
            call m0_print
            ld hl,m0_have
            ld de,BACK+178
            call m0_print
            call m0_present
            ld b,150
            call wait_frames
            ; ...and you die. Immediately.
            call stop_song
            ld hl,sfx_gameover
            call play_sfx
            call m0_cls
            ld hl,m0_dead
            ld de,BACK
            call m0_print
            call m0_present
            ld b,200
            call wait_frames
            call wait_key
            call reload_part2       ; the egg borrowed the asset RAM
            ; back to 2026 - turned away from the plaque
            ld a,(pdir)
            xor 2
            ld (pdir),a
            ld a,(area_music)
            call play_music
            call draw_explore_screen
            ld a,TX_JOKE
            jp show_text

EGGBUF      equ P2BASE
egg_ahead   equ EGGBUF
egg_left    equ EGGBUF+512
egg_right   equ EGGBUF+1024
egg_dracula equ EGGBUF+1536

copy512:    ld de,BACK
            ld bc,512
            ldir
            ret

m0_cls:     ld hl,BACK
            ld de,BACK+1
            ld bc,511
            ld (hl),$20             ; mode 0 space (green)
            ldir
            ret

m0_present: ld c,0
            ld b,32
            ld d,0
            ld e,16
            jp present_rect

; print ASCII (1 = newline to next 32-col row) into mode 0 buffer at DE
m0_print:
            push de
.l:         ld a,(hl)
            inc hl
            or a
            jr z,.e
            cp 1
            jr z,.nl
            and $3F
            ld (de),a
            inc de
            jr .l
.nl:        pop de
            ex de,hl
            ld bc,32
            add hl,bc
            ex de,hl
            push de
            jr .l
.e:         pop de
            ret

m0_wait_nesw:
.rel:       call wait_frame
            call read_input
            ld a,(any_key)
            or a
            jr nz,.rel
.w:         call wait_frame
            ld a,($68EF)
            cpl
            and $20                 ; N
            jr nz,.ok
            ld a,($68FE)
            cpl
            and $14                 ; E (bit2), W (bit4)
            jr nz,.ok
            ld a,($68FD)
            cpl
            and $10                 ; S
            jr z,.w
.ok:        ld hl,sfx_tick
            jp play_sfx

m0_welcome: db "WELCOME....... YOU HAVE ENTERED",1
            db "DRACULAS CASTLE.. THE DRAWBRIDGE",1
            db "SHUTS BEHIND YOU.....",1,1
            db "      THE FORGOTTEN MAZE",1
            db "      BASIC VERSION - 1984",1,1,1
            db "PRESS ANY KEY TO BEGIN....",1
            db "GOOD LUCK.....",0
m0_facing:  db "FACING NORTH",1,1,1,"MOVING ???",0
m0_prompt:  db "WHICH WAY? (N,E,S OR W)",0
m0_need:    db "YOU NEED 400",1,"SILVER STAKES",1,1,"YOU HAVE 10",1,"SILVER STAKES",0
m0_have:    db 0
m0_dead:    db "YOU ARE DEAD...",1
            db "YOU GOT TO LEVEL 1",1
            db "AND SURVIVED 5 VAULTS",1,1,1,1
            db "           GAME OVER",1,1,1,1,1,1
            db "ANOTHER GAME? (Y/N)",0
