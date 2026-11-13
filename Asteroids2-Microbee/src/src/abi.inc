; ---------------------------------------------------------------------------
; Exchange area between the engine (upper 32K, block 0) and the simulation
; bank (lower 32K, block 1).  Fixed addresses so either side builds alone.
; ---------------------------------------------------------------------------
DLIST       equ $D000       ; 5-byte entries: x lo, x hi, y, sprite, colour
DLIST_MAX   equ 100
DCOUNT      equ $D1F8
PLIST       equ $E800       ; 3-byte entries: x/2, y, colour (dots)
PLIST_MAX   equ 120
PCOUNT      equ $D1F9
STATUS      equ $D300
ST_SCORE    equ STATUS+0    ; 3 BCD
ST_LIVES    equ STATUS+3
ST_WAVE     equ STATUS+4    ; BCD
ST_BOMBS    equ STATUS+5
ST_GOVER    equ STATUS+6
ST_SHIELD   equ STATUS+7
ST_WEAPON   equ STATUS+8
ST_DONE     equ STATUS+9    ; game finished (game-over delay ran out)
ST_DEMO     equ STATUS+10
ST_FRAME    equ STATUS+11
ST_VX       equ STATUS+12   ; ship velocity (2 words) for the star drift
ST_VY       equ STATUS+14
ST_BANNER   equ STATUS+16   ; 0 or banner visible this frame
ST_CHAIN    equ STATUS+17
ST_WTMR     equ STATUS+18
ST_BTEXT    equ STATUS+20   ; banner text, 0-terminated (24)
SND         equ $D340       ; ch0..ch2 records (3 x 11)
INPUT_BITS  equ $D380
GLYPH_BASE  equ $D381       ; set by the engine: sprite id of glyph '0'
COLOURS     equ $D382
