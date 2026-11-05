TOMX equ 8
TOMY equ 38
TOMW equ 16
TOMH equ 26
tom_base:
        db $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$0A,$AA,$AA,$AA,$AA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AA,$AA,$AA,$AA,$2A,$0A,$2A,$AA,$AA,$AA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AA,$AA,$AA,$82,$0A,$28,$20,$AA,$AA,$AA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AA,$AA,$AA,$A0,$00,$00,$02,$AA,$AA,$AA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AA,$AA,$BF,$FF,$0C,$0C,$3F,$FE,$AA,$AA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AA,$AF,$BF,$FF,$FF,$FF,$FF,$FF,$BA,$AA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AA,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$AA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FA,$AA,$AA,$AA
        db $AA,$AA,$AA,$AA,$BF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$AA,$AA,$AA,$AA
        db $AA,$AA,$AD,$7F,$EA,$BF,$FF,$FF,$FF,$FF,$FE,$AA,$FF,$FA,$AA,$AA
        db $AA,$AA,$B7,$D5,$55,$FF,$FF,$FF,$FF,$FF,$FF,$55,$57,$FE,$AA,$AA
        db $AA,$AA,$FD,$55,$A5,$7F,$FF,$FF,$FF,$FF,$FD,$56,$95,$FF,$AA,$AA
        db $AA,$AB,$FF,$56,$A5,$7F,$FF,$FF,$FF,$FF,$FD,$5A,$95,$FF,$EA,$AA
        db $AA,$AF,$DF,$56,$A5,$7F,$FF,$FF,$FF,$FF,$FD,$5A,$95,$FF,$FA,$AA
        db $AA,$BF,$FF,$D5,$55,$FF,$FF,$FF,$FF,$FF,$FF,$55,$57,$FF,$FE,$AA
        db $AA,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$AA
        db $AA,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$AA
        db $AB,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$EA
        db $AF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FA
        db $AF,$FF,$FF,$FF,$FE,$5A,$5A,$5A,$5A,$5A,$5A,$7F,$FF,$FF,$FF,$FA
        db $BF,$FF,$FF,$FF,$FE,$AA,$AA,$AA,$AA,$AA,$AA,$BF,$FF,$FF,$FF,$FE
        db $BF,$FF,$FF,$FF,$FD,$A5,$A5,$A5,$A5,$A5,$A5,$BF,$FF,$FF,$FF,$FE
        db $BF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE
        db $BF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
EYEX equ 11
EYEY equ 46
EYEW equ 11
EYEH equ 7
tom_eyes:
        db $AA,$BF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$AA,$AA,$7F,$EA,$BF,$FF,$FF
        db $FF,$FF,$FE,$AA,$FF,$FA,$D5,$55,$FF,$FF,$FF,$FF,$FF,$FF,$55,$57
        db $FE,$5A,$55,$7F,$FF,$FF,$FF,$FF,$FD,$69,$55,$FF,$6A,$55,$7F,$FF
        db $FF,$FF,$FF,$FD,$A9,$55,$FF,$6A,$55,$7F,$FF,$FF,$FF,$FF,$FD,$A9
        db $55,$FF,$D5,$55,$FF,$FF,$FF,$FF,$FF,$FF,$55,$57,$FF,$AA,$BF,$FF
        db $FF,$FF,$FF,$FF,$FF,$FF,$AA,$AA,$7F,$EA,$BF,$FF,$FF,$FF,$FF,$FE
        db $AA,$FF,$FA,$D5,$55,$FF,$FF,$FF,$FF,$FF,$FF,$55,$57,$FE,$55,$A5
        db $7F,$FF,$FF,$FF,$FF,$FD,$56,$95,$FF,$56,$A5,$7F,$FF,$FF,$FF,$FF
        db $FD,$5A,$95,$FF,$56,$A5,$7F,$FF,$FF,$FF,$FF,$FD,$5A,$95,$FF,$D5
        db $55,$FF,$FF,$FF,$FF,$FF,$FF,$55,$57,$FF,$AA,$BF,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$AA,$AA,$7F,$EA,$BF,$FF,$FF,$FF,$FF,$FE,$AA,$FF,$FA
        db $D5,$55,$FF,$FF,$FF,$FF,$FF,$FF,$55,$57,$FE,$55,$5A,$7F,$FF,$FF
        db $FF,$FF,$FD,$55,$69,$FF,$55,$6A,$7F,$FF,$FF,$FF,$FF,$FD,$55,$A9
        db $FF,$55,$6A,$7F,$FF,$FF,$FF,$FF,$FD,$55,$A9,$FF,$D5,$55,$FF,$FF
        db $FF,$FF,$FF,$FF,$55,$57,$FF,$AA,$BF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $AA,$AA,$7F,$EA,$BF,$FF,$FF,$FF,$FF,$FE,$AA,$FF,$FA,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$EA,$AA,$FF,$FF,$FF,$FF,$FF,$FF,$AA,$AB,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF
MOUX equ 12
MOUY equ 55
MOUW equ 8
MOUH equ 7
tom_mouth0:
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $FE,$5A,$5A,$5A,$5A,$5A,$5A,$7F,$FE,$AA,$AA,$AA,$AA,$AA,$AA,$BF
        db $FD,$A5,$A5,$A5,$A5,$A5,$A5,$BF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
tom_mouth1:
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$5A,$5A,$5A,$5A,$5A,$5A,$7F
        db $FE,$6A,$6A,$6A,$6A,$6A,$6A,$7F,$FE,$AA,$AA,$AA,$AA,$AA,$AA,$BF
        db $FE,$AA,$AA,$FF,$FF,$AA,$AA,$BF,$FD,$A5,$A5,$FF,$FF,$A5,$A5,$BF
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
