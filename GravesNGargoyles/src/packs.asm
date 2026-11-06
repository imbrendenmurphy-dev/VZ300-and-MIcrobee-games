; ============================================================================
;  SD PACKS
;  Both packs are assembled to the same address (PACK_AREA) and written out as
;  separate files.  Only one is in memory at a time: the front pack while the
;  title and menus run, a stage pack during play.
; ============================================================================

        segment "GNGFRONT.DAT"
        org PACK_AREA
        db 'F'                  ; pack magic
        include "gen/title.asm"
        include "gen/music_front.asm"
        include "gen/gfx_front.asm"
        include "text_front.asm"
        include "front_pw.asm"
FRONT_END:
        endsegment

        segment "GNGSTAG1.DAT"
        org PACK_AREA
        include "gen/stage1_hdr.asm"   ; 'S',1 and the stage header
        include "gen/gfx_s1.asm"
        include "gen/level1.asm"
        include "gen/music_s1.asm"
        include "text_s1.asm"
S1_END:
        endsegment

        segment "GNGSTAG2.DAT"
        org PACK_AREA
        include "gen/stage2.asm"
S2_END:
        endsegment

        segment "GNGSTAG3.DAT"
        org PACK_AREA
        include "gen/stage3.asm"
S3_END:
        endsegment

        segment "GNGSTAG4.DAT"
        org PACK_AREA
        include "gen/stage4.asm"
S4_END:
        endsegment

        segment "GNGSTAG5.DAT"
        org PACK_AREA
        include "gen/stage5.asm"
S5_END:
        endsegment

        segment "GNGSTAG6.DAT"
        org PACK_AREA
        include "gen/stage6.asm"
S6_END:
        endsegment

        segment "GNGSTAG7.DAT"
        org PACK_AREA
        include "gen/stage7.asm"
S7_END:
        endsegment

; pack directory: destination, length, quoted 8-character name
PK_FRONT:  dw PACK_AREA,FRONT_END-PACK_AREA
           db 34,"GNGFRONT",34
PK_STAGES:
           dw PACK_AREA,S1_END-PACK_AREA
           db 34,"GNGSTAG1",34
           dw PACK_AREA,S2_END-PACK_AREA
           db 34,"GNGSTAG2",34
           dw PACK_AREA,S3_END-PACK_AREA
           db 34,"GNGSTAG3",34
           dw PACK_AREA,S4_END-PACK_AREA
           db 34,"GNGSTAG4",34
           dw PACK_AREA,S5_END-PACK_AREA
           db 34,"GNGSTAG5",34
           dw PACK_AREA,S6_END-PACK_AREA
           db 34,"GNGSTAG6",34
           dw PACK_AREA,S7_END-PACK_AREA
           db 34,"GNGSTAG7",34

; the largest pack sets where the variables start
PKMAX1 equ FRONT_END+(S1_END-FRONT_END)*(S1_END>=FRONT_END)
PKMAX2 equ PKMAX1+(S2_END-PKMAX1)*(S2_END>=PKMAX1)
PKMAX3 equ PKMAX2+(S3_END-PKMAX2)*(S3_END>=PKMAX2)
PKMAX4 equ PKMAX3+(S4_END-PKMAX3)*(S4_END>=PKMAX3)
PKMAX5 equ PKMAX4+(S5_END-PKMAX4)*(S5_END>=PKMAX4)
PKMAX6 equ PKMAX5+(S6_END-PKMAX5)*(S6_END>=PKMAX5)
PKMAX7 equ PKMAX6+(S7_END-PKMAX6)*(S7_END>=PKMAX6)
