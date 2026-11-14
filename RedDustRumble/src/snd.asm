; ============================================================================
;  SOUND DATA (read inside the interrupt, so it lives in always-visible memory)
; ============================================================================
; ---------------------------------------------------------------------------
; sounds: db fields, mode (0 rest 1 tone 2 noise), dw step ; 0 = end
; tone frequency = step * 0.73 Hz
; ---------------------------------------------------------------------------
sfx_hit_lt:
        db 2,2
        dw $3000
        db 2,2
        dw $1400
        db 0
sfx_hit_hvy:
        db 2,2
        dw $2400
        db 2,2
        dw $1000
        db 2,2
        dw $0700
        db 0
sfx_block:
        db 1,2
        dw $5000
        db 1,1
        dw $0C00
        db 0
sfx_thud:
        db 3,2
        dw $0500
        db 0
sfx_special:
        db 1,1
        dw $0400
        db 1,1
        dw $0600
        db 1,1
        dw $0900
        db 0
sfx_ko:
        db 3,1
        dw $0445
        db 3,1
        dw $0334
        db 3,1
        dw $0267
        db 3,1
        dw $01D0
        db 3,1
        dw $0156
        db 3,1
        dw $0103
        db 4,1
        dw $00BF
        db 6,1
        dw $0089
        db 0
sfx_bell:
        db 5,1
        dw $0668
        db 3,0
        dw 0
        db 12,1
        dw $0668
        db 0
sfx_win:
        db 4,1
        dw $02CB
        db 2,0
        dw 0
        db 4,1
        dw $0384
        db 2,0
        dw 0
        db 4,1
        dw $0430
        db 2,0
        dw 0
        db 10,1
        dw $0597
        db 0
sfx_blip:
        db 2,1
        dw $0700
        db 0
sfx_sel:
        db 2,1
        dw $0500
        db 3,1
        dw $0A00
        db 0

; title tune: a slow, gritty riff - short notes with gaps ("dink, dink-dink")
N_A2  equ $0096
N_C3  equ $00B3
N_D3  equ $00C9
N_E3  equ $00E1
N_G3  equ $010C
N_A3  equ $012D
tune_title:
        db 3,1
        dw N_A2
        db 9,0
        dw 0
        db 3,1
        dw N_A2
        db 3,0
        dw 0
        db 3,1
        dw N_C3
        db 9,0
        dw 0
        db 3,1
        dw N_D3
        db 9,0
        dw 0
        db 3,1
        dw N_E3
        db 3,0
        dw 0
        db 3,1
        dw N_G3
        db 3,0
        dw 0
        db 3,1
        dw N_E3
        db 9,0
        dw 0
        db 3,1
        dw N_D3
        db 3,0
        dw 0
        db 3,1
        dw N_C3
        db 9,0
        dw 0
        db 3,1
        dw N_A2
        db 3,0
        dw 0
        db 3,1
        dw N_A3
        db 3,0
        dw 0
        db 3,1
        dw N_G3
        db 3,0
        dw 0
        db 3,1
        dw N_E3
        db 21,0
        dw 0
        db 0

sfx_taunt:
        db 2,1
        dw $0500
        db 2,1
        dw $0700
        db 2,0
        dw 0
        db 2,1
        dw $0700
        db 3,1
        dw $0A00
        db 0
sfx_fin:
        db 2,1
        dw $0300
        db 2,1
        dw $0400
        db 2,1
        dw $0500
        db 2,1
        dw $0700
        db 2,1
        dw $0900
        db 4,2
        dw $0200
        db 6,2
        dw $0600
        db 0
sfx_shot:
        db 1,1
        dw $0C00
        db 1,1
        dw $0900
        db 1,1
        dw $0700
        db 0
