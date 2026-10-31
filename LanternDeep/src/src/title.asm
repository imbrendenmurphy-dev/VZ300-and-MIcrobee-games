; =====================================================================
; THE LANTERN DEEP - title screen, menu, text pages, attract demo
; The title illustration uses PCG banks 0-14 (from the TITLE bank); the
; font in bank 15 stays. Its animation tables are copied into the FLAGS /
; LIGHT work area, which the game does not need while the title runs.
; =====================================================================
TANIM       EQU FLAGS               ; flame cells (records of TB_ANIMREC bytes)
TLOGO       EQU TANIM+TB_NANIM*TB_ANIMREC
TLOGOIDX    EQU TLOGO+TB_NLOGO*4
TGLOW       EQU TLOGOIDX+81

title_screen:
            ld sp,STACK
            xor a : ld (demo_on),a
            call music_stop
            call clear_play
            ; the illustration's glyphs and maps straight from expanded RAM
            ld a,BLK_TITLE : ld b,15 : call pcg_load_n
            ; (bank_read lives in the fixed upper block: it maps the TITLE
            ; bank into the lower window, copies, and maps home back)
            ld a,LV_SCREEN : out (P_LV),a
            ld a,BLK_TITLE : ld hl,TB_SCR : ld de,VIDEO : ld bc,1920 : call bank_read
            ld a,LV_ATTR : out (P_LV),a
            ld a,BLK_TITLE : ld hl,TB_ATTR : ld de,VIDEO : ld bc,1920 : call bank_read
            ld a,LV_SCREEN : out (P_LV),a
            ld a,BLK_TITLE : ld hl,TB_ANIM : ld de,TANIM : ld bc,TB_LEN-TB_ANIM : call bank_read
            ; reveal the picture row by row, top to bottom
            ld b,0
.rv:        push bc
            call wait_frame
            ld a,1 : ld (dt),a : call snd_update
            pop bc
            push bc
            ld a,b : call reveal_row
            pop bc
            inc b
            ld a,b : cp 18 : jr nz,.rv
            call menu_draw
            ld a,(spoke) : or a : jr nz,.sp
            inc a : ld (spoke),a
            ld hl,SPEECH_TITLE : ld de,SPEECH_TITLE_LEN : ld a,SPEECH_TITLE_BLK : call speak
.sp:        ld hl,0 : ld (idle_t),hl
            ld hl,TM_DATA : ld (tm_ptr),hl
            ld a,1 : ld (tm_on),a
; ------------------------------------------------------------------ loop
title_loop: ld a,1 : ld (tk_anim),a
            call tm_tick
            ; menu input (edges only): what the keys did during the row
            call tm_input
            ld a,(input) : ld c,a
            ld a,(prev_input) : cpl : and c : ld b,a
            ld a,c : ld (prev_input),a
            ld a,c : or a : jr z,.idle
            ld hl,0 : ld (idle_t),hl
.idle:      bit 0,b : jr z,.n1
            ld a,(menu_sel) : or a : jr z,.n1
            dec a : ld (menu_sel),a
            ld a,SFX_MOVE : call sfx
            push bc : call menu_draw : pop bc
.n1:        bit 1,b : jr z,.n2
            ld a,(menu_sel) : cp 3 : jr z,.n2
            inc a : ld (menu_sel),a
            ld a,SFX_MOVE : call sfx
            push bc : call menu_draw : pop bc
.n2:        ld a,b : and $90                ; SPACE / RETURN
            jr nz,.select
            ; attract mode after half a minute
            ld hl,(idle_t) : ld a,(dt) : ld e,a : ld d,0 : add hl,de : ld (idle_t),hl
            ld de,1500 : or a : sbc hl,de
            jr c,.na
            ld a,(ck_valid) : or a : jp z,attract
.na:

            jp title_loop
.select:    ld a,SFX_SELECT : call sfx
            ld a,(menu_sel)
            or a : jp z,new_game
            dec a : jr z,.cont
            dec a : jp z,instructions
            jp credits
.cont:      ld a,(ck_valid) : or a : jp nz,continue_game
            call title_load : jp z,continue_game
            ld hl,23*80 : ld de,t_nosave : ld c,C_YEL : call print_centre
            jp title_loop

idle_t:     DW 0
spoke:      DB 0                    ; the title speaks once per power-on
menu_sel:   DB 0

; A = row: copy that row's colours from the TITLE bank to colour RAM
reveal_row: ld l,a : ld h,0
            add hl,hl : add hl,hl : add hl,hl : add hl,hl   ; *16
            ld d,h : ld e,l
            add hl,hl : add hl,hl : add hl,de               ; *80
            push hl
            ld de,TB_COL : add hl,de
            pop de
            ld a,d : or $F8 : ld d,a
            ld a,COL_ON : out (P_COLCTL),a
            ld a,BLK_TITLE : ld bc,80 : call bank_read
            xor a : out (P_COLCTL),a
            ret

; ------------------------------------------------------------------ animation
ta_t:       DB 0
ta_flame:   DB 0
ta_ff:      DB 0
ta_gx:      DB 0
ta_gp:      DB 0
ta_gq:      DB 0

; A band of light sweeps across the lettering, one column every two
; frames. Only the columns entering and leaving the band are rewritten.
glint:      ld a,(ta_gx) : sub 32               ; column leaving the band
            ld c,0 : call glint_col
            ld a,(ta_gx) : sub 29               ; column entering it
            ld c,1 : call glint_col
            ret
; A = column (ignored outside 0..79), C = 1 white / 0 restore
glint_col:  cp 80 : ret nc
            ld e,a : ld d,0
            ld hl,TLOGOIDX : add hl,de
            ld a,(hl) : inc hl : ld b,(hl)
            sub b : ret z
            neg : ld b,a                        ; cells in this column
            ld a,(hl) : dec hl : ld a,(hl)      ; first index
            ld l,a : ld h,0 : add hl,hl : add hl,hl
            ld de,TLOGO : add hl,de
            push hl : pop ix
            ld a,COL_ON : out (P_COLCTL),a
.c:         ld a,(ix+3)
            dec c : inc c : jr z,.w
            and $F0 : or C_WHT
.w:         ld e,a
            ld l,(ix+0) : ld a,(ix+1) : or $F8 : ld h,a
            ld (hl),e
            inc ix : inc ix : inc ix : inc ix
            djnz .c
            xor a : out (P_COLCTL),a
            ret

; ------------------------------------------------------------------ menu
menu_draw:  ld b,0
.m:         push bc
            ld a,b : add a,19 : ld l,a : call row_off      ; HL = row start
            call clear_row
            pop bc : push bc
            push hl
            ld a,b : add a,a : ld e,a : ld d,0
            ld hl,menu_items : add hl,de
            ld e,(hl) : inc hl : ld d,(hl)                 ; DE = text
            pop hl
            ld c,C_GRY
.c1:        ld a,(menu_sel) : cp b : jr nz,.c2
            ld c,C_BYEL
.c2:        push hl
            call print_centre
            pop hl
            pop bc : push bc
            ld a,(menu_sel) : cp b : jr nz,.nx
            ; lantern flames either side of the chosen line
            ld de,28 : add hl,de
            ld a,G_FLAME : ld c,C_BYEL : ld b,FONT_BANK : call put_glyph
            ld de,22 : add hl,de
            ld a,G_FLAME : ld c,C_BYEL : ld b,FONT_BANK : call put_glyph
.nx:        pop bc
            inc b : ld a,b : cp 4 : jr nz,.m
            ; credit line
            ld hl,23*80 : call clear_row
            ld de,t_credit : ld c,C_GRY : call print_centre
            ld hl,23*80+39 : ld de,t_bpm : ld c,C_BYEL : call print
            ret
menu_items: DW t_new,t_cont,t_instr,t_cred
t_new:      DB "NEW GAME",0
t_cont:     DB "CONTINUE",0
t_instr:    DB "INSTRUCTIONS",0
t_cred:     DB "CREDITS",0
t_credit:   DB "VIBED BY BPM # 2026",0
t_bpm:      DB "BPM",0
t_nosave:   DB "NO JOURNEY HAS BEEN SAVED YET.",0

; L = row -> HL = row * 80
row_off:    ld h,0
            add hl,hl : add hl,hl : add hl,hl : add hl,hl
            ld d,h : ld e,l
            add hl,hl : add hl,hl : add hl,de
            ret

; HL = row start: blank 80 cells
clear_row:  push hl
            ld b,80
.c:         push bc
            ld a,$80 : ld c,0 : ld b,FONT_BANK : call put_glyph
            pop bc
            djnz .c
            pop hl
            ret

; HL = row start, DE = text, C = colour: centred on the row
print_centre:
            push hl
            ld h,d : ld l,e
            ld b,0
.l:         ld a,(hl) : or a : jr z,.e
            inc b : inc hl : jr .l
.e:         ld a,80 : sub b : srl a
            pop hl
            add a,l : ld l,a : jr nc,.p
            inc h
.p:         jp print

; ------------------------------------------------------------------ text pages
instructions:
            ld hl,page_instr : jr text_page
credits:    ld hl,page_credits
text_page:  push hl
            call clear_play
            ld hl,0*80 : call rule_row
            ld hl,21*80 : call rule_row
            pop hl
            ld b,2                          ; first text row
.l:         ld a,(hl) : cp $FF : jr z,.wait
            ld c,a : inc hl                 ; colour
            push hl                         ; text
            push bc
            ld l,b : call row_off           ; HL = row start
            pop bc
            pop de                          ; DE = text
            push bc
            bit 7,c : jr nz,.left
            call print_centre               ; DE ends on the 0
            jr .pd
.left:      ld a,c : and $0F : ld c,a       ; left-aligned table row
            push de : ld de,6 : add hl,de : pop de
            call print
.pd:        pop bc
            inc de
            ex de,hl
            inc b
            jr .l
.wait:      ld hl,22*80 : ld de,t_anykey : ld c,C_DGR : call print_centre
            ld hl,(frames) : ld (last_frames),hl
            xor a : ld (prev_input),a
.w:         ld a,(tm_on) : or a : jr z,.w0
            xor a : ld (tk_anim),a
            call tm_tick
            call tm_input
            jr .w1
.w0:        call wait_frame
            ld a,1 : ld (dt),a : call snd_update
            call read_input
.w1:
            ld a,(input) : ld c,a
            ld a,(prev_input) : cpl : and c : ld b,a
            ld a,c : ld (prev_input),a
            ld a,b : or a : jr z,.w
            jp title_screen

rule_row:   ld b,80
.r:         push bc
            ld a,G_RULE : ld c,C_DGR : ld b,FONT_BANK : call put_glyph
            pop bc
            djnz .r
            ret

t_anykey:   DB "PRESS ANY KEY",0
page_instr:
            DB C_BYEL,"HOW TO EXPLORE THE DEEP",0
            DB C_BLK,0
            DB C_GRY|$80,"ARROW KEYS, OR Q A O P    WALK. YOUR LANTERN LIGHTS THE WAY YOU FACE.",0
            DB C_GRY|$80,"SPACE OR Z                STRIKE WITH YOUR SWORD, OPEN, READ, TOUCH.",0
            DB C_GRY|$80,"F OR X                    HURL A FIRE BOLT: IT LIGHTS THE DARK AS IT GOES",0
            DB C_GRY|$80,"M                         YOUR JOURNAL: A MAP OF THE REGION, YOUR ITEMS",0
            DB C_GRY|$80,"ESC                       BACK TO THE TITLE. CONTINUE BRINGS YOU BACK.",0
            DB C_BLK,0
            DB C_WHT,"HEARTS ARE YOUR LIFE, BLUE ORBS YOUR MAGIC. YOU HAVE THREE LIVES:",0
            DB C_WHT,"FALL, AND YOU WAKE WHERE THE REGION BEGAN, KEEPING ALL YOU CARRY.",0
            DB C_WHT,"THE GREAT CRYSTALS RESTORE MAGIC TO THOSE WHO TOUCH THEM.",0
            DB C_WHT,"WHAT YOU HAVE SEEN, YOU REMEMBER: EXPLORED HALLS STAY FAINTLY DRAWN.",0
            DB C_BLK,0
            DB C_BYEL,"FIVE REGIONS LIE BELOW. A KEY, A LANTERN, A BLADE AND A RING",0
            DB C_BYEL,"EACH OPEN THE WAY ON. AT THE BOTTOM, THE HEART MUST BE REKINDLED.",0
            DB C_BLK,0
            DB C_BCYN,"READ THE TABLETS. LOOK FOR WHAT THE LIGHT REVEALS.",0
            DB $FF
page_credits:
            DB C_BYEL,"THE LANTERN DEEP",0
            DB C_BLK,0
            DB C_WHT,"VIBED BY BPM # 2026",0
            DB C_BLK,0
            DB C_GRY,"AN ORIGINAL ADVENTURE FOR THE MICROBEE PREMIUM PLUS",0
            DB C_GRY,"80 X 24 PCG GRAPHICS, RAY-TRACED TORCHLIGHT,",0
            DB C_GRY,"1MB OF BANKED MEMORY AND A 1-BIT VOICE.",0
            DB C_BLK,0
            DB C_DGR,"FIVE REGIONS: THE DROWNED TEMPLE, THE OSSUARY, THE CRYSTAL",0
            DB C_DGR,"CAVERNS, THE EMBER HALLS AND THE HEART OF THE DEEP.",0
            DB $FF
page_end:
            DB C_BYEL,"THE LANTERN IS LIT",0
            DB C_BLK,0
            DB C_WHT,"THE HEART OF THE DEEP BURNS AGAIN. ITS LIGHT RUNS UP",0
            DB C_WHT,"THROUGH THE EMBER HALLS, THE SINGING CAVERNS, THE QUIET",0
            DB C_WHT,"TOMBS AND THE DROWNED TEMPLE, AND THE UNLIGHT FALLS BACK.",0
            DB C_BLK,0
            DB C_GRY,"THE KEEPERS SLEEP EASY. THE OLD TOWN WAKES TO A WARM WIND",0
            DB C_GRY,"RISING FROM THE STONES, AND NO ONE KNOWS WHY.",0
            DB C_BLK,0
            DB C_BCYN,"THANK YOU FOR CARRYING THE LAST FLAME.",0
            DB C_BLK,0
            DB C_GRY,"THE LANTERN DEEP  -  VIBED BY BPM # 2026",0
            DB $FF

; ------------------------------------------------------------------ start
new_game:   xor a : ld (tm_on),a
            call music_stop
            call clear_play
            ld a,BLK_GFX : call pcg_load_all
            call game_new
            jp game_loop

continue_game:
            xor a : ld (tm_on),a
            call music_stop
            call clear_play
            ld a,BLK_GFX : call pcg_load_all
            call game_continue
            jp game_loop

; ------------------------------------------------------------------ attract
attract:    xor a : ld (tm_on),a
            call music_stop
            call clear_play
            ld a,BLK_GFX : call pcg_load_all
            ld a,1 : ld (demo_on),a
            xor a : ld (demo_clip),a
            call game_new
            xor a : ld (ck_valid),a
            ld hl,DEMO_SCRIPT : ld (demo_ptr),hl
            ld a,(hl) : ld (demo_cnt),a
            ld hl,msg_demo : call message
            ld a,250 : ld (msg_timer),a
            jp game_loop

; ------------------------------------------------------------------ at boot
; Colour or monochrome monitor? Monochrome shows light by the character
; patterns alone and draws creatures inverted.
monitor_ask:
            call clear_play
            ld hl,8*80 : ld de,t_mon1 : ld c,C_BYEL : call print_centre
            ld hl,11*80 : ld de,t_mon2 : ld c,C_WHT : call print_centre
            ld hl,13*80 : ld de,t_mon3 : ld c,C_GRY : call print_centre
.w:         call wait_frame
            ld a,1 : out (P_ROMLAT),a
            ld a,3 : call keytest : jr nz,.col          ; C
            ld a,$34 : call keytest : jr nz,.col        ; RETURN
            ld a,13 : call keytest : jr nz,.mono        ; M
            xor a : out (P_ROMLAT),a
            jr .w
.mono:      ld a,1 : jr .set
.col:       xor a
.set:       ld (mono_on),a
            xor a : out (P_ROMLAT),a
.rel:       call wait_frame                     ; let the key go first
            ld a,1 : out (P_ROMLAT),a
            ld a,3 : call keytest : ld b,a
            ld a,13 : call keytest : or b : ld b,a
            ld a,$34 : call keytest : or b : ld b,a
            xor a : out (P_ROMLAT),a
            ld a,b : or a : jr nz,.rel
            ret

; ------------------------------------------------------------------ the title tune
; A three-voice beeper player. Three square waves (16-bit phase
; accumulators) are time-sliced onto the speaker inside one loop of
; exactly 176 T-states; the voices are OR-ed into one speaker write. Every 64 passes (2.75 ms) a step
; handles the note gates (notes stay separate), the kick drum (a falling
; pitch on the bass) and the snare (the chord voice jumps about
; randomly). One call plays one sixteenth-note row from the TITLE bank;
; the title animation and the keys are seen to between rows.
TM_IT       EQU 64
; one row of the tune, then the frame count moves on as if it had waited
tm_tick:    call tm_row
            ld a,(tm_buf+1) : add a,4 : rrca : rrca : rrca : and $1F   ; ~ frames that passed
            ld (dt),a
            ld e,a : ld d,0
            ld hl,(frames) : add hl,de : ld (frames),hl
            ret
tm_row:     ld hl,(tm_ptr)
            ld a,BLK_TITLE : ld de,BOUNCE : ld bc,11 : call bank_read   ; (via the upper block)
            ld hl,BOUNCE : ld de,tm_buf : ld bc,11 : ldir
            ld a,(tm_buf) : cp $FF : jr nz,.go
            ld hl,TM_DATA : ld (tm_ptr),hl
            jr tm_row
.go:        ld hl,(tm_ptr) : ld de,11 : add hl,de : ld (tm_ptr),hl
            ld a,(tm_buf+8) : ld (tm_g1+1),a
            ld a,(tm_buf+9) : ld (tm_g2+1),a
            ld a,(tm_buf+10) : ld (tm_g3+1),a
            ld hl,(tm_buf+2) : ld (tm_a1),hl
            ld hl,(tm_buf+6) : ld (tm_a3),hl
            xor a : ld (tm_kick),a : ld (tm_snare),a
            ld a,(tm_buf) : rra : jr nc,.nk
            ld hl,TM_KICK : ld (tm_buf+6),hl
            ld a,9 : ld (tm_kick),a
.nk:        ld a,(tm_buf) : and 2 : jr z,.ns
            ld a,3 : ld (tm_snare),a
.ns:        ld a,(tm_buf+1) : ld iyh,a
            ld iyl,TM_IT
            exx
            ld hl,(tm_acc2) : ld de,(tm_buf+4)
            exx
            ld ix,(tm_acc3) : ld bc,(tm_buf+6)
            ld hl,(tm_acc1) : ld de,(tm_buf+2)
; Each voice is a narrow pulse (when the top of its accumulator passes
; a threshold), and the three are OR-ed into ONE speaker write per pass:
; the speaker only moves at the voices' own edges, so there is no
; switching hiss under the notes. The voice's 'not sounding' bits are
; gathered in C' with the carry flag (which EXX leaves alone).
tm_loop:    add hl,de : ld a,h : cp $E0                 ; chord: 1/8 of its period
            exx : rl c
            add hl,de : ld a,h : cp $D0 : rl c          ; melody: 3/16
            exx
            add ix,bc : ld a,ixh : cp $C0               ; bass: 1/4
            exx : rl c
            ld a,c : or $F8 : inc a                     ; 0 only if none sounds
            add a,255 : sbc a,a : and $40
            out (P_PIOB),a
            exx
            dec iyl
            jp nz,tm_loop
            ; ---- a step (the speaker rests while it is worked out)
            xor a : out (P_PIOB),a
            ld iyl,TM_IT
            dec iyh : jp z,tm_end
            ld a,iyh
tm_g1:      cp 0 : jr nz,.n1
            ld de,0 : ld h,d
.n1:
tm_g2:      cp 0 : jr nz,.n2
            exx : ld de,0 : ld h,d : exx
.n2:
tm_g3:      cp 0 : jr nz,.n3
            ld bc,0 : ld ixh,b
            ld (tm_a3),bc
            xor a : ld (tm_kick),a
.n3:        ld a,(tm_kick) : or a : jr z,.nk
            dec a : ld (tm_kick),a
            jr nz,.kd
            ld bc,(tm_a3) : jr .nk
.kd:        push hl                         ; the kick's pitch falls by 1/8
            ld h,b : ld l,c
            srl h : rr l : srl h : rr l : srl h : rr l
            ld a,c : sub l : ld c,a
            ld a,b : sbc a,h : ld b,a
            pop hl
.nk:        ld a,(tm_snare) : or a : jp z,tm_task
            dec a : ld (tm_snare),a
            ld de,(tm_a1) : jp z,tm_task    ; snare over: the chord again
            ld a,r : and $1F : or $08 : ld d,a
            ld a,r : rlca : ld e,a
; ---- each step also does one small piece of other work, so the tune
;      never has to stop: a key of the keyboard scan every other step, and
;      in between a flame cell, four glowing cells or the glint
tm_task:    push hl : push de : push bc : push ix
            ld hl,tk_n : inc (hl)
            ld a,(hl) : rra : jr c,.key
            ld a,(tk_anim) : or a : jr z,.done
            ld a,(hl) : rra : and 3
            jr z,.glint
            dec a : jr z,.glow
            call tk_flame
            jr .done
.glow:      call tk_glow
            jr .done
.glint:     call tk_glint
            jr .done
.key:       call tk_key
.done:      pop ix : pop bc : pop de : pop hl
            jp tm_loop
tm_end:     ld (tm_acc1),hl : ld (tm_acc3),ix
            exx : ld (tm_acc2),hl : exx
            xor a : out (P_PIOB),a
            ret
tm_on:      DB 0
tk_n:       DB 0
tk_anim:    DB 0
tm_inl:     DB 0

; the keys seen during the row, and the joystick now -> input
tm_input:   ld a,(tm_inl) : ld c,a
            xor a : ld (tm_inl),a
            out (P_ROMLAT),a
            in a,(P_PIOA)
            or a : jr nz,.j1
            dec a                           ; reads 00: no joystick fitted
.j1:        cpl
            ld b,a
            and $0F
            or c : ld c,a
            bit 7,b : jr z,.nf
            set 4,c
.nf:        ld a,c : ld (input),a
            ret

; one key of the keymap, added to the row's input
tk_key:     ld a,1 : out (P_ROMLAT),a
            ld hl,(ki_ptr) : ld a,(hl) : cp $FF : jr nz,.k
            ld hl,tkeymap : ld a,(hl)
.k:         inc hl : ld c,(hl) : inc hl : ld (ki_ptr),hl
            call keytest : jr z,.n
            ld a,(tm_inl) : or c : ld (tm_inl),a
.n:         xor a : out (P_ROMLAT),a
            ret
ki_ptr:     DW tkeymap
; the keys the title and its pages answer to (a short list: scanned fast)
tkeymap:    DB $38,$01, $3A,$02, 17,$01, 1,$02
            DB $37,$10, $34,$80, 26,$10, $30,$40
            DB $FF

; one flame cell of the current frame; a new frame when all are done
tk_flame:   ld ix,(fl_ptr)
            ld a,(ix+2) : or LV_SCREEN : out (P_LV),a
            ld l,(ix+3) : ld h,0
            add hl,hl : add hl,hl : add hl,hl : add hl,hl
            ld de,PCGWIN : add hl,de : ex de,hl
            ld a,(ta_ff) : ld b,a : add a,a : add a,a : add a,a : add a,b
            add a,4 : ld c,a : ld b,0
            push ix : pop hl : add hl,bc
            ldi : ldi : ldi : ldi : ldi : ldi : ldi : ldi
            ld b,(hl)
            ld l,(ix+0) : ld a,(ix+1) : or $F8 : ld h,a
            ld a,COL_ON : out (P_COLCTL),a
            ld (hl),b
            xor a : out (P_COLCTL),a
            ld a,LV_SCREEN : out (P_LV),a
            ld de,TB_ANIMREC : add ix,de : ld (fl_ptr),ix
            ld hl,fl_n : dec (hl) : ret nz
            ld (hl),TB_NANIM
            ld hl,TANIM : ld (fl_ptr),hl
            ld a,(ta_ff) : inc a : and 3 : ld (ta_ff),a
            ret
fl_ptr:     DW TANIM
fl_n:       DB TB_NANIM

; four cells of the breathing glow
tk_glow:    ld ix,(gw_ptr)
            ld b,4
.c:         push bc
            ld a,(ta_gp) : add a,(ix+3) : and 7
            ld b,(ix+2)
            cp 2 : jr nc,.w
            ld a,b : and $0F : cp C_CYN : jr nz,.bg
            ld a,b : and $F0 : or C_BCYN : ld b,a
.bg:        ld a,b : and $F0 : cp C_CYN<<4 : jr nz,.w
            ld a,b : and $0F : or C_BCYN<<4 : ld b,a
.w:         ld l,(ix+0) : ld a,(ix+1) : or $F8 : ld h,a
            ld a,COL_ON : out (P_COLCTL),a
            ld (hl),b
            xor a : out (P_COLCTL),a
            ld de,4 : add ix,de
            ld hl,gw_n : dec (hl)
            jr nz,.nx
            ld (hl),TB_NGLOW
            ld ix,TGLOW
            ld hl,ta_gp : inc (hl)
.nx:        pop bc
            djnz .c
            ld (gw_ptr),ix
            ret
gw_ptr:     DW TGLOW
gw_n:       DB TB_NGLOW

; the glint moves on one column every fourth time
tk_glint:   ld hl,gl_n : inc (hl)
            ld a,(hl) : and 3 : ret nz
            ld a,(ta_gx) : inc a : cp 140 : jr c,.g1
            xor a
.g1:        ld (ta_gx),a
            jp glint
gl_n:       DB 0
tm_ptr:     DW 0
tm_buf:     DS 11
tm_a1:      DW 0
tm_a3:      DW 0
tm_acc1:    DW 0
tm_acc2:    DW 0
tm_acc3:    DW 0
tm_kick:    DB 0
tm_snare:   DB 0

; called from read_input: replaces the input in demo mode
demo_input: ld a,(demo_on) : or a : ret z
            ld a,(input) : or a
            jp nz,title_screen              ; any key ends the demo
            ld hl,(demo_ptr)
            ld a,(hl) : or a
            jp z,demo_next                  ; clip finished: the next
            inc hl : ld a,(hl) : ld (input),a
            ld a,(demo_cnt) : ld b,a : ld a,(dt) : ld c,a : ld a,b
            sub c : jr z,.nx : jr c,.nx
            ld (demo_cnt),a
            ret
.nx:        ld hl,(demo_ptr) : inc hl : inc hl : ld (demo_ptr),hl
            ld a,(hl) : ld (demo_cnt),a
            ret
demo_on:    DB 0
demo_ptr:   DW 0
demo_cnt:   DB 0
msg_demo:   DB "THE LANTERN DEEP - PRESS ANY KEY",0

; frames, input bits (b0 up b1 down b2 left b3 right b4 strike b5 fire)
DEMO_SCRIPT:
            DB 40,0, 120,$08, 30,0, 120,$08, 20,0
            DB 3,$20, 30,0                          ; fire a bolt down the corridor
            DB 110,$08, 40,0, 30,$01, 20,0          ; into the hall, look up
            DB 60,$01, 20,0, 3,$10, 60,0            ; strike
            DB 40,$08, 3,$20, 40,0, 60,$02, 60,$08, 100,0
            DB 0

; blank the whole screen (colour 0) and reset the PCG character codes
clear_play: ld a,COL_ON : out (P_COLCTL),a
            ld hl,COLWIN : ld bc,$0800 : ld e,0 : call fill
            xor a : out (P_COLCTL),a
            ld a,LV_ATTR : out (P_LV),a
            ld hl,VIDEO : ld bc,$0800 : ld e,FONT_BANK : call fill
            ld a,LV_SCREEN : out (P_LV),a
            ld hl,VIDEO : ld bc,$0800 : ld e,$80 : call fill
            ret
