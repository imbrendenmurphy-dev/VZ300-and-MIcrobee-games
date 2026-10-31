;=====================================================================
;  T R A N S C E N D E N C E
;  An atmospheric audiovisual journey for the Dick Smith VZ300
;  (BennVenn SD + 128K). BPM / ViBED 2026
;=====================================================================
        device NOSLOT64K
ISRPAD  equ 15

        include "core.asm"
        include "seq.asm"
        include "gfx.asm"
        include "ch1.asm"
        include "ch2.asm"
        include "hum.asm"
        include "chh.asm"
        include "ch6.asm"
        include "ch7.asm"
        include "ch89.asm"
        include "chapters.asm"

        include "dbg.asm"
timeline:
        ifdef DBGBAR
        ld hl,DBGBAR*128
        ld (FRAMES),hl
        call DBGCH
        jr .end
        endif
        call ch_arrival
        call ch_search
        call ch_encounter
        call ch_awaken
        call ch_separate
        call ch_flight
        call ch_passage
        call ch_rebirth
        call ch_silence
        call chapters_rest
.end:   call waitvb
        jr .end

        include "data.asm"
codeend:

;---------------------------------------------------------------------
; variables (not saved in the .VZ)
        org $7E20
T:      dw 0
Q:      dw 0
SSPD:   db 0
SCX:    db 0
SCY:    db 0
ENTSZ:  db 0
ENTX:   db 0
ENTY:   db 0
ENTG:   db 0
ENTDIR: db 0
ENTSX:  db 0
ENTSY:  db 0
DCX:    db 0
DCY:    db 0
DR:     db 0
DCOL:   db 0
DDY:    db 0
DTB:    dw 0
PR:     db 0
PCX:    db 0
PCY:    db 0
PY:     db 0
PW:     db 0
HOR:    db 0
SKO:    db 0
SUNY:   db 0
SCR1:   db 0
SCR2:   db 0
SEQRND: dw 0
CH1:    ds 32
CH2:    ds 32
CAMX:   db 0
EX:     db 0
EY:     db 0
KEND:   db 0
LPX:    db 0
DX2:    dw 0
FIRST:  db 0
MBASE:  db 0
FIGX:   db 0
FIGY:   db 0
EWX:    db 0
EWY:    db 0
EWZ:    db 0
SPX:    db 0
SPY:    db 0
CTT:    dw 0
CTS:    db 0
CTP:    dw 0
CTQ:    dw 0
FLX:    db 0
FLY:    db 0
FTX:    db 0
FTY:    db 0
EPROJ:  ds 8
CZ:     dw 0
ALT:    db 0
HORY:   db 0
BANK:   db 0
CAMXW:  db 0
PROF:   db 0
ROWK:   db 0
DROW:   dw 0
SROW:   dw 0
PIDX:   dw 0
PSTEP:  dw 0
RCOL:   db 0
RBANK:  db 0
BKACC:  dw 0
BKSTEP: dw 0
TPH:    db 0
TROT:   db 0
TZ:     db 0
TLOB:   db 0
TSH:    db 0
TTW:    db 0
TPAT:   db 0
TOX:    db 0
TOY:    db 0
TCOL:   db 0
TMP1:   db 0
TMP2:   dw 0
TPATP:  dw 0
TRP:    dw 0
TDST:   dw 0
PT1:    db 0
PT2:    db 0
PT3:    db 0
NSTV:   db 0
SUNP:   db 0
E8S:    db 0
PLY:    db 0
PMODE:  db 0
EPD:    db 0

varend:
        assert varend < $8000
; large work arrays (free RAM above the back buffer after loading)
        org $F800
STARS:  ds 3*40
SCRATCH: ds 64
HN:     ds 64
HF:     ds 64
YT:     ds 22
YBUF:   ds 32
CMAP:   ds 32
var2end:
        assert var2end < $FC00

        savebin "demo.bin",$8000,codeend-$8000

;---------------------------------------------------------------------
; SRAM bank 3 assets
        org $4000
        include "assets.asm"
assetend:
        savebin "bank3.bin",$4000,assetend-$4000

        include "loader.asm"
        savebin "loader.bin",$F000,ldrend-$F000
