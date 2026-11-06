; ---------------------------------------------------------------------------
; BILBIES!  -  VZ300 (BennVenn SD loader + 128K)  -  equates and memory map
; ---------------------------------------------------------------------------
LATCH       equ $6800
VRAM        equ $7000
L_SPK0      equ $01
L_MODE      equ $08            ; 1 = mode(1) graphics
L_CSS       equ $10
L_SPK1      equ $20

; keyboard rows (active low, bits 0-5)
KR0         equ $68FE          ; T W - E Q R
KR1         equ $68FD          ; G S CTRL D A F
KR2         equ $68FB          ; B X SHIFT C Z V
KR3         equ $68F7          ; 5 2 - 3 1 4
KR4         equ $68EF          ; N . - , SPACE M
KR5         equ $68DF          ; 6 9 - 8 0 7
KR6         equ $68BF          ; Y O RET I P U
KR7         equ $687F          ; H L : K ; J

; colours (mode 1, colour set 0)
C_GRN       equ 0
C_YEL       equ 1
C_BLU       equ 2
C_RED       equ 3
BG          equ $AA            ; four blue pixels

; ---- memory map ------------------------------------------------------------
VARS        equ $7800          ; variables
CRT         equ $7B00          ; creatures: NCRT x 16
NCRT        equ 40
CSZ         equ 16
PART        equ $7D80          ; particles: NPART x 6
NPART       equ 18
IMTAB       equ $7E00          ; IM2 table (257 x $7F) -> $7F7F
ISRJP       equ $7F7F
SCRBUF      equ $7F02          ; a level's solution script (demo / test), 125 bytes
CODE        equ $8000

MAPPER      equ $37            ; BennVenn mapper: 1 = SRAM bank A, 3 = bank B at $4000
; the level picture fills SRAM bank A ($37 = 1, as the DOS leaves it)
TERR        equ $4000          ; picture: 80 rows x 128 bytes (512 pixels)
TSTR        equ 128
LHMAX       equ 80
PFH         equ 44             ; playfield rows on screen
; SRAM bank B ($37 = 3) holds the level designs (copied to LSTAGE to build)
LVBANK      equ $4000
; main RAM
MASK        equ $DE00          ; what's solid: 80 rows x 64 bytes (1 bit a pixel)
MASKSZ      equ 80*64
SHT         equ $F200          ; shift tables: 3 shifts x (hi page, lo page)
OPQ         equ $F800          ; opaque mask of a sprite byte (256)
BACK        equ $F900          ; composed playfield: 44 rows x BSTR
BSTR        equ 36             ; 2 bytes of margin either side
LSTAGE      equ BACK           ; a level's design while it's built
PREV        equ BACK           ; level preview (32 x 20)
GBUF        equ CRT            ; ground heights while a level is built (512)
STBUF       equ CRT+512        ; a scenery stamp while a level is built (256)
STACKTOP    equ $0000          ; stack: $FF30-$FFFF, just above BACK ($F900-$FF2F)

; ---- creature record --------------------------------------------------------
C_ST        equ 0
C_XL        equ 1              ; x (16 bits)
C_XH        equ 2
C_Y         equ 3
C_DIR       equ 4              ; 0 right, 1 left
C_AN        equ 5              ; animation frame
C_FL        equ 6              ; b0 climber b1 floater b2 bomb ticking
C_CNT       equ 7              ; fall distance / bricks / work
C_BT        equ 8              ; bomb timer (ticks)

ST_NONE     equ 0
ST_WALK     equ 1
ST_FALL     equ 2
ST_FLOAT    equ 3
ST_CLIMB    equ 4
ST_HOIST    equ 5
ST_BLOCK    equ 6
ST_BUILD    equ 7
ST_SHRUG    equ 8
ST_BASH     equ 9
ST_MINE     equ 10
ST_DIG      equ 11
ST_SPLAT    equ 12
ST_DROWN    equ 13
ST_EXIT     equ 14
ST_OHNO     equ 15
ST_GONE     equ 16             ; lost
ST_HOME     equ 17             ; saved
NSTATES     equ 18

; ---- rules (VZ pixels: 2 dots wide, 3 lines tall) ---------------------------
STEPUP      equ 2              ; a walker steps up to 2 rows
STEPDN      equ 2              ; and down up to 2 before it falls
DEATHFALL   equ 24             ; falls of 24+ rows (5 bilby heights) are fatal
FLOATAT     equ 4              ; floaters open after 4 rows
NBRICK      equ 12
BOMBTICKS   equ 63             ; 5 seconds at 12.5 ticks a second

; skills
SK_CLIMB    equ 0
SK_FLOAT    equ 1
SK_BOMB     equ 2
SK_BLOCK    equ 3
SK_BUILD    equ 4
SK_BASH     equ 5
SK_MINE     equ 6
SK_DIG      equ 7

; panel buttons 0..11: rate-, rate+, 8 skills, pause, nuke
BT_RMINUS   equ 0
BT_RPLUS    equ 1
BT_SKILL0   equ 2
BT_PAUSE    equ 10
BT_NUKE     equ 11
