; ---------------------------------------------------------------------------
; Banked graphics loader (runs once, before hw_init).
;
; KILLTOM2.Pnn holds one LZ stream per 32K asset bank. Each stream decodes
; straight into its bank while that bank is paged into the low 32K, so the
; loader itself runs from the common upper 32K at $8000. CP/M's own bank ($0C)
; is paged back in only for BDOS calls, one 4K refill (32 records) at a time.
;
; Stream tokens:  0          end of bank
;                 1..127     n literal bytes follow
;                 128..255   match: length (t&127)+4, then 16-bit distance
; ---------------------------------------------------------------------------
LOADER_RUN equ $8000
LOAD_IN equ $A000               ; 4K disk buffer, $A000-$AFFF
LOAD_STACK equ $9FF0
CPM_PORT equ $0C

load_assets:
        ld hl,loader_image
        ld de,LOADER_RUN
        ld bc,loader_image_end-loader_image
        ldir
        jp lz_load

loader_image:
        DISP LOADER_RUN

        MACRO GETB              ; A = next input byte (HL), refilling as needed
        ld a,h
        cp (LOAD_IN+4096)>>8
        call z,lz_refill
        ld a,(hl)
        inc hl
        ENDM

lz_load:
        ld (lz_sp),sp
        ld sp,LOAD_STACK
        ld de,load_message
        ld c,9
        call 5
        ld de,asset_fcb
        ld c,15
        call 5
        inc a
        jp z,lz_fail
        ld a,CPM_PORT
        ld (lz_port),a
        call lz_refill
        ld a,4
        ld (load_bank),a
.bank:  ; port for bank N: ((N&3)^2) | 4 | ((N&28)<<3), video RAM off (8)
        ld a,(load_bank)
        ld c,a
        and 28
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,c
        and 3
        xor 2
        or 4+8
        or b
        ld (lz_port),a
        call lz_bank
        ld a,d                  ; a bank must decode to exactly 32768 bytes
        cp $80
        jp nz,lz_fail
        ld a,e
        or a
        jp nz,lz_fail
        push hl
        ld e,'.'
        ld c,2
        call 5
        pop hl
        ld hl,load_bank
        inc (hl)
        ld a,(hl)
        cp 4+ASSET_BANKS
        ld hl,(lz_in)
        jr nz,.bank
        ld sp,(lz_sp)
        ret

; Decode one bank. In: HL = input. Out: HL = input, DE = bytes written.
lz_bank:
        ld (lz_in),hl
        ld a,(lz_port)
        out ($50),a
        ld de,0
.tok:   GETB
        or a
        jr z,.end
        jp m,.match
        ld c,a                  ; literal run
        ld b,0
        ld a,h
        cp ((LOAD_IN+4096)>>8)-1
        jr nc,.slow
        ldir                    ; whole run is inside the input buffer
        jp .tok
.slow:  GETB
        ld (de),a
        inc de
        dec c
        jr nz,.slow
        jp .tok
.match: and 127
        add a,4
        ld (lz_len),a
        GETB
        ld c,a
        GETB
        ld b,a
        push hl
        ld h,d
        ld l,e
        or a
        sbc hl,bc               ; source = output - distance
        ld a,(lz_len)
        ld c,a
        ld b,0
        ldir                    ; forward copy handles overlapping repeats
        pop hl
        jp .tok
.end:   ld (lz_in),hl
        ld a,CPM_PORT
        out ($50),a
        ret

; Read up to 32 records into LOAD_IN, rolling on to the next KILLTOM2.Pnn at
; EOF. Pages CP/M in for the BDOS calls. Preserves BC,DE; returns HL=LOAD_IN.
lz_refill:
        push bc
        push de
        ld a,CPM_PORT
        out ($50),a
        ld hl,LOAD_IN
        ld b,32
.rec:   push bc
        push hl
        ex de,hl
        ld c,26
        call 5
        ld de,asset_fcb
        ld c,20
        call 5
        or a
        jr z,.ok
        cp 1
        jp nz,lz_fail
        call lz_next_file
        pop hl
        pop bc
        jr z,.rec               ; next segment opened: retry this record
        jr .fin                 ; no more segments: the data ends in this buffer
.ok:    pop hl
        ld de,128
        add hl,de
        pop bc
        djnz .rec
.fin:   ld a,(lz_port)
        out ($50),a
        ld hl,LOAD_IN
        pop de
        pop bc
        ret

; Each disk segment stays within one 16K logical CP/M extent. Z if opened.
lz_next_file:
        ld hl,asset_fcb+11
        inc (hl)
        ld a,(hl)
        cp ':'
        jr nz,.open
        ld (hl),'0'
        dec hl
        inc (hl)
.open:  ld hl,asset_fcb+12
        ld de,asset_fcb+13
        ld bc,23
        ld (hl),0
        ldir
        ld de,asset_fcb
        ld c,15
        call 5
        inc a                   ; BDOS open: 0..3 found, $FF missing
        jr z,.none
        xor a                   ; Z: opened
        ret
.none:  inc a                   ; A=1, NZ: no such file
        ret

lz_fail:
        ld a,CPM_PORT
        out ($50),a
        ld sp,LOAD_STACK
        ld de,load_error
        ld c,9
        call 5
        jp 0

load_message: db 'KILLER TOMATOES 2 - PREMIUM PLUS',13,10,'Loading arcade graphics into banked RAM','$'
load_error: db 13,10,'Graphics load failed. Keep all KILLTOM2.Pxx files on this disk.',13,10,'$'
asset_fcb: db 0,'KILLTOM2P00'
        ds 24,0
lz_sp:  dw 0
lz_in:  dw 0
lz_port: db 0
lz_len: db 0
load_bank: db 0
        ENT
loader_image_end:
        ASSERT loader_image_end-loader_image < $1000
