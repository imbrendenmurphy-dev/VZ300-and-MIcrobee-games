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
FRONT_END:
        endsegment

        segment "GNGSTAG1.DAT"
        org PACK_AREA
        db 'S'                  ; pack magic
        db 1                    ; stage number
        include "gen/gfx_s1.asm"
        include "gen/level1.asm"
        include "gen/music_s1.asm"
        include "text_s1.asm"
S1_END:
        endsegment

; pack directory: destination, length, quoted 8-character name
PK_FRONT:  dw PACK_AREA,FRONT_END-PACK_AREA
           db 34,"GNGFRONT",34
PK_STAGE1: dw PACK_AREA,S1_END-PACK_AREA
           db 34,"GNGSTAG1",34
