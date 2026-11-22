; ===========================================================================
;  ovl_print.asm - overlay slot 4: print the document (FILE menu).
;  Built by build.py against mainsym.inc; runs at OVLA+2.
;
;  The VZ printer interface (as the ROM's LPRINT at $3AC4 drives it): wait
;  while bit 0 of IN ($00) is 1 (busy), OUT ($0E) = the byte, OUT ($0D)
;  strobes it.  Lines of up to 80 characters (out_lay.inc) end with CR LF;
;  a form feed at the end.  Control characters print as spaces.  CTRL+Q stops
;  at any time; if the printer stays busy (or there is none: the port then
;  reads $FF) it says so and waits for the printer or CTRL+Q.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)

zq_go:  ld a,1
        ld (waitrel),a
        xor a
        ld (zNR),a
        ld hl,zs_prt
        call show_status
        call zl_start
zq_l:   call getkey         ; CTRL+Q between lines
        cp K_QUIT
        jr z,zq_stop
        call zl_next
        jr c,zq_end
        ld hl,zLB
        ld a,b
        or a
        jr z,zq_eol
zq_c:   ld a,(hl)
        inc hl
        cp ' '
        jr nc,zq_c1
        ld a,' '
zq_c1:  call zq_out
        jr c,zq_stop
        djnz zq_c
zq_eol: ld a,13
        call zq_out
        jr c,zq_stop
        ld a,10
        call zq_out
        jr c,zq_stop
        jr zq_l
zq_end: ld a,12             ; form feed: the last page out
        call zq_out
        jr c,zq_stop
        ld hl,zs_done
        jp zl_msg
zq_stop: ld hl,zs_stop
        jp zl_msg

; A = a byte for the printer.  C = stopped with CTRL+Q.
zq_out: push bc
        push hl
        ld (zBy),a          ; (getkey and show_status use BC)
        ld hl,0
zo_w:   in a,($00)
        rra
        jr nc,zo_go
        inc hl              ; busy
        ld a,h
        cp 64               ; (after half a second or so, say so)
        jr c,zo_k
        ld a,(zNR)
        or a
        jr nz,zo_k
        inc a
        ld (zNR),a
        push hl
        ld hl,zs_nr
        call show_status
        pop hl
zo_k:   ld a,l
        and 15
        jr nz,zo_w
        push hl
        call getkey
        pop hl
        cp K_QUIT
        jr nz,zo_w
        pop hl
        pop bc
        scf
        ret
zo_go:  ld a,(zNR)          ; ready again after "not ready"
        or a
        jr z,zo_o
        xor a
        ld (zNR),a
        push hl
        ld hl,zs_prt
        call show_status
        pop hl
zo_o:   ld a,(zBy)
        out ($0E),a
        out ($0D),a
        pop hl
        pop bc
        or a
        ret

        include "out_lay.inc"

zs_prt: db "PRINTING...  ^Q STOPS",0
zs_nr:  db "PRINTER NOT READY  ^Q STOPS",0
zs_done: db "PRINTED",0
zs_stop: db "STOPPED",0

zq_last:
        assert zq_last <= OVLA+OVLSEC*512
zNR     equ zq_last         ; "not ready" is showing
zBy     equ zNR+1           ; the byte being sent
zLP     equ zBy+1
zLB     equ zLP+2           ; 81
zq_wend equ zLB+81
        assert zq_wend <= OVLEND
