; generated sound effects
SFX_SHOT equ 0
SFX_ESHOT equ 1
SFX_HIT equ 2
SFX_BOOM equ 3
SFX_DOOR equ 4
SFX_CHARGE equ 5
SFX_LINK equ 6
SFX_HURT equ 7
SFX_CLEAR equ 8
sfx_tab:    dw sfx_shot,sfx_eshot,sfx_hit,sfx_boom,sfx_door,sfx_charge,sfx_link,sfx_hurt,sfx_clear
sfx_prio:   db 1,1,2,3,0,0,2,3,4
sfx_shot:
            db $01,$B5,$6D,$21,$01,$9D,$56,$21,$01,$67,$42,$21,$01,$14,$31,$21
            db $01,$A5,$22,$20,$00
sfx_eshot:
            db $01,$6B,$28,$21,$01,$56,$20,$21,$01,$68,$19,$21,$01,$A2,$13,$20
            db $00
sfx_hit:
            db $01,$00,$00,$A1,$01,$53,$11,$A1,$01,$00,$00,$A0,$00
sfx_boom:
            db $02,$00,$00,$A1,$02,$32,$05,$A1,$02,$00,$00,$A1,$02,$0B,$04,$A1
            db $03,$00,$00,$A0,$03,$2D,$03,$A0,$03,$00,$00,$A0,$00
sfx_door:
            db $01,$00,$00,$A0,$01,$B4,$0C,$A0,$01,$65,$0A,$20,$00
sfx_charge:
            db $01,$10,$4B,$20,$00
sfx_link:
            db $01,$19,$17,$21,$01,$A5,$22,$21,$01,$31,$2E,$21,$01,$4A,$45,$21
            db $01,$63,$5C,$20,$00
sfx_hurt:
            db $01,$03,$0F,$A1,$01,$8C,$0B,$21,$01,$3D,$09,$A1,$01,$82,$07,$20
            db $00
sfx_clear:
            db $03,$33,$1E,$21,$03,$0D,$26,$21,$03,$45,$2D,$21,$06,$74,$3C,$21
            db $02,$00,$00,$00,$08,$74,$3C,$20,$00
