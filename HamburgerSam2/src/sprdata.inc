; ---- sprite sources (relocated to STATBG at start-up): per row d0,d1,m0,m1
spr_src_start:
sprsrc:
    dw ss_SAM_A-spr_src_start+STATBG : db 8,0
    dw ss_SAM_A_L-spr_src_start+STATBG : db 8,0
    dw ss_SAM_B-spr_src_start+STATBG : db 8,0
    dw ss_SAM_B_L-spr_src_start+STATBG : db 8,0
    dw ss_SAM_THROW-spr_src_start+STATBG : db 8,0
    dw ss_SAM_THROW_L-spr_src_start+STATBG : db 8,0
    dw ss_SAM_CLIMB_A-spr_src_start+STATBG : db 8,0
    dw ss_SAM_CLIMB_B-spr_src_start+STATBG : db 8,0
    dw ss_SAM_FRONT-spr_src_start+STATBG : db 8,1
    dw ss_SAM_CHEER-spr_src_start+STATBG : db 8,1
    dw ss_SAM_DIZZY-spr_src_start+STATBG : db 8,1
    dw ss_SAM_PLATE-spr_src_start+STATBG : db 8,1
    dw ss_SAM_UPSIDE-spr_src_start+STATBG : db 8,1
    dw ss_HOTDOG_A-spr_src_start+STATBG : db 8,0
    dw ss_HOTDOG_A_L-spr_src_start+STATBG : db 8,0
    dw ss_HOTDOG_B-spr_src_start+STATBG : db 8,0
    dw ss_HOTDOG_B_L-spr_src_start+STATBG : db 8,0
    dw ss_HOTDOG_STUN-spr_src_start+STATBG : db 8,0
    dw ss_HOTDOG_SQUASH-spr_src_start+STATBG : db 8,0
    dw ss_EGG_A-spr_src_start+STATBG : db 8,0
    dw ss_EGG_A_L-spr_src_start+STATBG : db 8,0
    dw ss_EGG_B-spr_src_start+STATBG : db 8,0
    dw ss_EGG_B_L-spr_src_start+STATBG : db 8,0
    dw ss_EGG_STUN-spr_src_start+STATBG : db 8,0
    dw ss_EGG_SQUASH-spr_src_start+STATBG : db 8,0
    dw ss_PICKLE_A-spr_src_start+STATBG : db 8,0
    dw ss_PICKLE_A_L-spr_src_start+STATBG : db 8,0
    dw ss_PICKLE_B-spr_src_start+STATBG : db 8,0
    dw ss_PICKLE_B_L-spr_src_start+STATBG : db 8,0
    dw ss_PICKLE_STUN-spr_src_start+STATBG : db 8,0
    dw ss_PICKLE_SQUASH-spr_src_start+STATBG : db 8,0
    dw ss_CHILLI_A-spr_src_start+STATBG : db 8,0
    dw ss_CHILLI_A_L-spr_src_start+STATBG : db 8,0
    dw ss_CHILLI_B-spr_src_start+STATBG : db 8,0
    dw ss_CHILLI_B_L-spr_src_start+STATBG : db 8,0
    dw ss_CHILLI_STUN-spr_src_start+STATBG : db 8,0
    dw ss_CHILLI_SQUASH-spr_src_start+STATBG : db 8,0
    dw ss_PEPPER_A-spr_src_start+STATBG : db 8,1
    dw ss_PEPPER_B-spr_src_start+STATBG : db 8,1
    dw ss_COFFEE-spr_src_start+STATBG : db 8,1
    dw ss_FRIES-spr_src_start+STATBG : db 8,1
    dw ss_ICECREAM-spr_src_start+STATBG : db 8,1
    dw ss_SPATULA-spr_src_start+STATBG : db 8,1
    dw ss_SPARK_A-spr_src_start+STATBG : db 8,1
    dw ss_SPARK_B-spr_src_start+STATBG : db 8,1
    dw ss_ARROW-spr_src_start+STATBG : db 8,1
ss_SAM_A:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F,$05,$94,$F0,$03
    db $0F,$F0,$F0,$0F,$1F,$F4,$C0,$03,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_A_L:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F,$16,$50,$C0,$0F
    db $0F,$F0,$F0,$0F,$1F,$F4,$C0,$03,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_B:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F,$05,$94,$F0,$03
    db $0F,$F0,$F0,$0F,$1F,$F4,$C0,$03,$0A,$A0,$F0,$0F,$28,$08,$C3,$F3
ss_SAM_B_L:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F,$16,$50,$C0,$0F
    db $0F,$F0,$F0,$0F,$1F,$F4,$C0,$03,$0A,$A0,$F0,$0F,$20,$28,$CF,$C3
ss_SAM_THROW:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F,$05,$94,$F0,$03
    db $0F,$F5,$F0,$00,$1F,$F0,$C0,$0F,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_THROW_L:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F,$16,$50,$C0,$0F
    db $5F,$F0,$00,$0F,$0F,$F4,$F0,$03,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_CLIMB_A:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$1A,$A0,$C0,$0F,$35,$5C,$C0,$03
    db $0F,$F4,$F0,$03,$0F,$F0,$F0,$0F,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_CLIMB_B:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A4,$F0,$03,$35,$5C,$C0,$03
    db $1F,$F0,$C0,$0F,$0F,$F0,$F0,$0F,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_FRONT:
    db $05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F,$09,$60,$F0,$0F
    db $4F,$F1,$30,$0C,$3F,$FC,$C0,$03,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_CHEER:
    db $45,$51,$30,$0C,$D5,$57,$00,$00,$3A,$AC,$C0,$03,$09,$60,$F0,$0F
    db $0D,$70,$F0,$0F,$0F,$F0,$F0,$0F,$0A,$A0,$F0,$0F,$20,$08,$CF,$F3
ss_SAM_DIZZY:
    db $11,$10,$CC,$CF,$05,$50,$F0,$0F,$15,$54,$C0,$03,$0A,$A0,$F0,$0F
    db $0D,$70,$F0,$0F,$1F,$F4,$C0,$03,$0A,$A0,$F0,$0F,$20,$08,$CF,$F3
ss_SAM_PLATE:
    db $AA,$AA,$00,$00,$15,$54,$C0,$03,$4A,$A1,$30,$0C,$C9,$63,$30,$0C
    db $3F,$FC,$C0,$03,$0F,$F0,$F0,$0F,$0A,$A0,$F0,$0F,$08,$20,$F3,$CF
ss_SAM_UPSIDE:
    db $08,$20,$F3,$CF,$0A,$A0,$F0,$0F,$3F,$FC,$C0,$03,$4F,$F1,$30,$0C
    db $09,$60,$F0,$0F,$0A,$A0,$F0,$0F,$15,$54,$C0,$03,$05,$50,$F0,$0F
ss_HOTDOG_A:
    db $03,$C0,$FC,$3F,$0F,$F0,$F0,$0F,$0E,$E0,$F0,$0F,$0F,$F0,$F0,$0F
    db $07,$F0,$F0,$0F,$0D,$F0,$F0,$0F,$0F,$70,$F0,$0F,$08,$20,$F3,$CF
ss_HOTDOG_A_L:
    db $03,$C0,$FC,$3F,$0F,$F0,$F0,$0F,$0B,$B0,$F0,$0F,$0F,$F0,$F0,$0F
    db $0F,$D0,$F0,$0F,$0F,$70,$F0,$0F,$0D,$F0,$F0,$0F,$08,$20,$F3,$CF
ss_HOTDOG_B:
    db $03,$C0,$FC,$3F,$0F,$F0,$F0,$0F,$0E,$E0,$F0,$0F,$0F,$F0,$F0,$0F
    db $07,$F0,$F0,$0F,$0D,$F0,$F0,$0F,$0F,$70,$F0,$0F,$20,$08,$CF,$F3
ss_HOTDOG_B_L:
    db $03,$C0,$FC,$3F,$0F,$F0,$F0,$0F,$0B,$B0,$F0,$0F,$0F,$F0,$F0,$0F
    db $0F,$D0,$F0,$0F,$0F,$70,$F0,$0F,$0D,$F0,$F0,$0F,$20,$08,$CF,$F3
ss_HOTDOG_STUN:
    db $44,$10,$33,$CF,$0F,$F1,$F0,$0C,$0D,$D0,$F0,$0F,$0F,$F0,$F0,$0F
    db $07,$F0,$F0,$0F,$0D,$F0,$F0,$0F,$0F,$70,$F0,$0F,$08,$20,$F3,$CF
ss_HOTDOG_SQUASH:
    db $00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
    db $13,$C4,$CC,$33,$FF,$FF,$00,$00,$37,$7C,$C0,$03,$00,$00,$FF,$FF
ss_EGG_A:
    db $01,$40,$FC,$3F,$05,$50,$F0,$0F,$16,$60,$C0,$0F,$17,$D4,$C0,$03
    db $1F,$F4,$C0,$03,$17,$D4,$C0,$03,$05,$50,$F0,$0F,$08,$20,$F3,$CF
ss_EGG_A_L:
    db $01,$40,$FC,$3F,$05,$50,$F0,$0F,$09,$94,$F0,$03,$17,$D4,$C0,$03
    db $1F,$F4,$C0,$03,$17,$D4,$C0,$03,$05,$50,$F0,$0F,$08,$20,$F3,$CF
ss_EGG_B:
    db $01,$40,$FC,$3F,$05,$50,$F0,$0F,$16,$60,$C0,$0F,$17,$D4,$C0,$03
    db $1F,$F4,$C0,$03,$17,$D4,$C0,$03,$05,$50,$F0,$0F,$20,$08,$CF,$F3
ss_EGG_B_L:
    db $01,$40,$FC,$3F,$05,$50,$F0,$0F,$09,$94,$F0,$03,$17,$D4,$C0,$03
    db $1F,$F4,$C0,$03,$17,$D4,$C0,$03,$05,$50,$F0,$0F,$20,$08,$CF,$F3
ss_EGG_STUN:
    db $41,$04,$3C,$F3,$05,$50,$F0,$0F,$17,$70,$C0,$0F,$17,$D4,$C0,$03
    db $1F,$F4,$C0,$03,$17,$D4,$C0,$03,$05,$50,$F0,$0F,$08,$20,$F3,$CF
ss_EGG_SQUASH:
    db $00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
    db $11,$44,$CC,$33,$57,$D5,$00,$00,$15,$54,$C0,$03,$00,$00,$FF,$FF
ss_PICKLE_A:
    db $02,$80,$FC,$3F,$0A,$A0,$F0,$0F,$09,$90,$F0,$0F,$2A,$A0,$C0,$0F
    db $0A,$A8,$F0,$03,$2A,$A0,$C0,$0F,$0A,$A0,$F0,$0F,$0C,$30,$F3,$CF
ss_PICKLE_A_L:
    db $02,$80,$FC,$3F,$0A,$A0,$F0,$0F,$06,$60,$F0,$0F,$0A,$A8,$F0,$03
    db $2A,$A0,$C0,$0F,$0A,$A8,$F0,$03,$0A,$A0,$F0,$0F,$0C,$30,$F3,$CF
ss_PICKLE_B:
    db $02,$80,$FC,$3F,$0A,$A0,$F0,$0F,$09,$90,$F0,$0F,$2A,$A0,$C0,$0F
    db $0A,$A8,$F0,$03,$2A,$A0,$C0,$0F,$0A,$A0,$F0,$0F,$30,$0C,$CF,$F3
ss_PICKLE_B_L:
    db $02,$80,$FC,$3F,$0A,$A0,$F0,$0F,$06,$60,$F0,$0F,$0A,$A8,$F0,$03
    db $2A,$A0,$C0,$0F,$0A,$A8,$F0,$03,$0A,$A0,$F0,$0F,$30,$0C,$CF,$F3
ss_PICKLE_STUN:
    db $44,$10,$33,$CF,$0A,$A1,$F0,$0C,$0B,$B0,$F0,$0F,$2A,$A0,$C0,$0F
    db $0A,$A8,$F0,$03,$2A,$A0,$C0,$0F,$0A,$A0,$F0,$0F,$0C,$30,$F3,$CF
ss_PICKLE_SQUASH:
    db $00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
    db $12,$84,$CC,$33,$AA,$AA,$00,$00,$29,$A8,$C0,$03,$00,$00,$FF,$FF
ss_CHILLI_A:
    db $00,$A0,$FF,$0F,$02,$80,$FC,$3F,$0F,$F0,$F0,$0F,$37,$7C,$C0,$03
    db $3F,$FC,$C0,$03,$0F,$F0,$F0,$0F,$03,$F0,$FC,$0F,$08,$2C,$F3,$C3
ss_CHILLI_A_L:
    db $0A,$00,$F0,$FF,$02,$80,$FC,$3F,$0F,$F0,$F0,$0F,$3D,$DC,$C0,$03
    db $3F,$FC,$C0,$03,$0F,$F0,$F0,$0F,$0F,$C0,$F0,$3F,$38,$20,$C3,$CF
ss_CHILLI_B:
    db $00,$A0,$FF,$0F,$02,$80,$FC,$3F,$0F,$F0,$F0,$0F,$37,$7C,$C0,$03
    db $3F,$FC,$C0,$03,$0F,$F0,$F0,$0F,$03,$F0,$FC,$0F,$20,$23,$CF,$CC
ss_CHILLI_B_L:
    db $0A,$00,$F0,$FF,$02,$80,$FC,$3F,$0F,$F0,$F0,$0F,$3D,$DC,$C0,$03
    db $3F,$FC,$C0,$03,$0F,$F0,$F0,$0F,$0F,$C0,$F0,$3F,$C8,$08,$33,$F3
ss_CHILLI_STUN:
    db $44,$A4,$33,$03,$02,$80,$FC,$3F,$0F,$F0,$F0,$0F,$3B,$BC,$C0,$03
    db $3F,$FC,$C0,$03,$0F,$F0,$F0,$0F,$03,$F0,$FC,$0F,$08,$2C,$F3,$C3
ss_CHILLI_SQUASH:
    db $00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
    db $12,$84,$CC,$33,$FF,$FF,$00,$00,$3F,$FC,$C0,$03,$00,$00,$FF,$FF
ss_PEPPER_A:
    db $00,$00,$FF,$FF,$04,$80,$F3,$3F,$21,$10,$CC,$CF,$48,$48,$33,$33
    db $12,$10,$CC,$CF,$08,$40,$F3,$3F,$01,$00,$FC,$FF,$00,$00,$FF,$FF
ss_PEPPER_B:
    db $01,$00,$FC,$FF,$20,$20,$CF,$CF,$44,$84,$33,$33,$21,$20,$CC,$CF
    db $84,$84,$33,$33,$12,$20,$CC,$CF,$80,$40,$3F,$3F,$00,$80,$FF,$3F
ss_COFFEE:
    db $04,$10,$F3,$CF,$01,$04,$FC,$F3,$2A,$A0,$C0,$0F,$2F,$EA,$C0,$00
    db $2A,$A2,$C0,$0C,$2A,$AA,$C0,$00,$0A,$80,$F0,$3F,$15,$50,$C0,$0F
ss_FRIES:
    db $11,$10,$CC,$CF,$15,$50,$C0,$0F,$15,$54,$C0,$03,$FF,$FC,$00,$03
    db $DF,$DC,$00,$03,$3F,$F0,$C0,$0F,$3F,$F0,$C0,$0F,$0F,$C0,$F0,$3F
ss_ICECREAM:
    db $0F,$C0,$F0,$3F,$3E,$F0,$C0,$0F,$3F,$F0,$C0,$0F,$2A,$A0,$C0,$0F
    db $05,$40,$F0,$3F,$05,$40,$F0,$3F,$01,$00,$FC,$FF,$01,$00,$FC,$FF
ss_SPATULA:
    db $15,$40,$C0,$3F,$11,$10,$CC,$CF,$15,$50,$C0,$0F,$05,$40,$F0,$3F
    db $01,$00,$FC,$FF,$02,$00,$FC,$FF,$02,$00,$FC,$FF,$02,$80,$FC,$3F
ss_SPARK_A:
    db $01,$00,$FC,$FF,$01,$00,$FC,$FF,$50,$14,$0F,$C3,$01,$00,$FC,$FF
    db $01,$00,$FC,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
ss_SPARK_B:
    db $10,$10,$CF,$CF,$04,$40,$F3,$3F,$00,$00,$FF,$FF,$04,$40,$F3,$3F
    db $10,$10,$CF,$CF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
ss_ARROW:
    db $01,$40,$FC,$3F,$01,$40,$FC,$3F,$01,$40,$FC,$3F,$01,$40,$FC,$3F
    db $15,$54,$C0,$03,$05,$50,$F0,$0F,$01,$40,$FC,$3F,$00,$00,$FF,$FF
spr_src_end:
