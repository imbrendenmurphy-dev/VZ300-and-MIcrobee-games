; ============================================================================
;  RED DUST RUMBLE  -  a one-on-one fighting game for the Dick Smith VZ300
;  Target: VZ300 + BennVenn SD loader + 128K SRAM.  Mode 1 (128x64, 4 colours)
;  VIBED BY BPM 2026
; ============================================================================
;
;  MEMORY MAP
;   $4000-$67FF  SRAM bank 0 ($37=1)  Dusty's frames (the DOS copy here is
;                overwritten; quitting reboots, which reloads it from the card)
;   $4000-$67FF  SRAM bank 1 ($37=3)  Flick's frames
;   $7000-$77FF  video RAM
;   $8000-       program, data and the packed master frames (the masters are
;                only read at start-up; Dusty's overflow frames are built over
;                Flick's masters afterwards)
;   $E000-$E7FF  SB  shadow screen: every frame is composed here
;   $D400-$DE1F  the stage shifted 2 pixels (built at start-up over
;                Dusty's spent master frames)
;   $E800-$EFFF  BG  clean view of the arena at the current camera
;   $F000-$F7FF  draw tables: 4 colour/mirror transforms, each followed by
;                a copy of the mask table
;   $F800-$F900  IM2 vector table (257 x $F9) -> jp isr at $F9F9
;   $F901-$F9F0  stack
;   $FA00-$FFFF  variables (the DOS work area: the DOS is never called)
;
LATCH    equ $6800
VRAM     equ $7000
SB       equ $E000
BG       equ $E800
XF_ID    equ $F0          ; transform pages (high bytes); mask = page+1
XF_FLIP  equ $F2
XF_RED   equ $F4
XF_FRED  equ $F6
IM2TAB   equ $F800
ISRJP    equ $F9F9
STAGE2   equ $D400          ; 54 rows x 48 bytes, the stage shifted 2 pixels
STAGE2END equ STAGE2+54*48
STACKTOP equ $F9F0

BANK_FLICK equ 3          ; port $37 value: SRAM bank 1
BANK_DUSTY equ 1          ; port $37 value: SRAM bank 0 (the DOS bank)

GROUND   equ 58           ; feet row
BANDBOT  equ 62           ; rows composed each tick: band top .. 61
ARENATOP equ 10           ; rows 0-9 are the HUD band
HUDROWS  equ 10

        org $8000
        jp init

        include "sys.asm"
        include "gfx.asm"
        include "fight.asm"
        include "cpu.asm"
        include "front.asm"
        include "data.asm"
        include "gen/font.asm"
        include "gen/stage.asm"
        include "vars.asm"
; master frames last: only needed at start-up
        include "gen/fighters.asm"
LOAD_END:
        assert STAGE2END <= SB
        assert VARSEND <= $10000
        assert LOAD_END <= BG       ; the master frames may run into SB: they are used up before SB is
