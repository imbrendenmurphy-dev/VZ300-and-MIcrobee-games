; generated music & sfx
; sample loop 129 T -> 27495 Hz
NOTE_STEP:
    dw 0,156,165,175,185,196,208,220
    dw 234,247,262,278,294,312,330,350
    dw 371,393,416,441,467,495,524,556
    dw 589,624,661,700,742,786,832,882
    dw 934,990,1049,1111,1177,1247,1321,1400
    dw 1483,1571,1665,1764,1869,1980,2098,2222
    dw 2354,2494,2643,2800,2966,3143,3330,3528
    dw 3737,3960,4195,4444,4709,4989,5285,5600
SONG_J_CLEAR: dw SONG_J_CLEAR_A,SONG_J_CLEAR_B
SONG_J_CLEAR_A:
    db $19,$03,$1D,$03,$20,$03,$25,$06,$20,$03,$25,$0C,$00,$02
    db $FE
SONG_J_CLEAR_B:
    db $0D,$06,$14,$06,$11,$06,$0D,$0C,$00,$02
    db $FE
SONG_J_OVER: dw SONG_J_OVER_A,SONG_J_OVER_B
SONG_J_OVER_A:
    db $22,$08,$20,$08,$1E,$08,$1D,$08,$1B,$08,$1A,$08,$1B,$18,$00,$04
    db $FE
SONG_J_OVER_B:
    db $0F,$10,$0A,$10,$06,$10,$03,$18,$00,$04
    db $FE
SONG_J_ITEM: dw SONG_J_ITEM_A,SONG_J_ITEM_B
SONG_J_ITEM_A:
    db $29,$02,$2C,$02,$31,$06,$00,$02
    db $FE
SONG_J_ITEM_B:
    db $00,$0C
    db $FE
SFXTAB:
    dw SFX_JUMP
    dw SFX_THROW
    dw SFX_HIT
    dw SFX_KILL
    dw SFX_COIN
    dw SFX_ARMOUR
    dw SFX_POWER
    dw SFX_MAGIC
    dw SFX_BOSSHIT
    dw SFX_BOOM
    dw SFX_CHECK
    dw SFX_CLINK
    dw SFX_DIE
    dw SFX_CHEST
    dw SFX_SELECT
    dw SFX_THUNDER
SFX_JUMP_ID equ 0
SFX_THROW_ID equ 1
SFX_HIT_ID equ 2
SFX_KILL_ID equ 3
SFX_COIN_ID equ 4
SFX_ARMOUR_ID equ 5
SFX_POWER_ID equ 6
SFX_MAGIC_ID equ 7
SFX_BOSSHIT_ID equ 8
SFX_BOOM_ID equ 9
SFX_CHECK_ID equ 10
SFX_CLINK_ID equ 11
SFX_DIE_ID equ 12
SFX_CHEST_ID equ 13
SFX_SELECT_ID equ 14
SFX_THUNDER_ID equ 15
SFX_JUMP:
    dw 524
    db 64
    dw 650
    db 55
    dw 806
    db 47
    dw 999
    db 38
    dw 1239
    db 30
    dw 0
    db 0
SFX_THROW:
    dw 2145
    db 48
    dw 1430
    db 34
    dw 953
    db 20
    dw 0
    db 0
SFX_HIT:
    dw 936
    db 90
    dw 627
    db 77
    dw 1521
    db 65
    dw 487
    db 52
    dw 0
    db 0
SFX_KILL:
    dw 1430
    db 90
    dw 1042
    db 78
    dw 759
    db 66
    dw 553
    db 55
    dw 403
    db 43
    dw 294
    db 31
    dw 214
    db 20
    dw 0
    db 0
SFX_COIN:
    dw 3141
    db 40
    dw 3141
    db 40
    dw 4195
    db 40
    dw 4195
    db 40
    dw 4195
    db 40
    dw 4195
    db 40
    dw 0
    db 0
SFX_ARMOUR:
    dw 1864
    db 100
    dw 1499
    db 86
    dw 839
    db 73
    dw 1191
    db 80
    dw 895
    db 68
    dw 673
    db 56
    dw 506
    db 44
    dw 380
    db 32
    dw 286
    db 20
    dw 0
    db 0
SFX_POWER:
    dw 624
    db 60
    dw 786
    db 60
    dw 934
    db 60
    dw 934
    db 60
    dw 1246
    db 60
    dw 1246
    db 60
    dw 1570
    db 60
    dw 1832
    db 50
    dw 2137
    db 40
    dw 2493
    db 30
    dw 0
    db 0
SFX_MAGIC:
    dw 190
    db 110
    dw 250
    db 103
    dw 328
    db 97
    dw 431
    db 90
    dw 566
    db 84
    dw 744
    db 78
    dw 977
    db 71
    dw 1283
    db 65
    dw 1684
    db 59
    dw 2212
    db 52
    dw 2904
    db 46
    dw 3813
    db 40
    dw 554
    db 120
    dw 173
    db 110
    dw 494
    db 100
    dw 199
    db 90
    dw 216
    db 80
    dw 487
    db 70
    dw 813
    db 60
    dw 243
    db 50
    dw 323
    db 40
    dw 651
    db 30
    dw 0
    db 0
SFX_BOSSHIT:
    dw 459
    db 120
    dw 335
    db 106
    dw 275
    db 93
    dw 715
    db 80
    dw 505
    db 52
    dw 357
    db 24
    dw 0
    db 0
SFX_BOOM:
    dw 514
    db 128
    dw 115
    db 120
    dw 463
    db 112
    dw 219
    db 104
    dw 157
    db 96
    dw 145
    db 88
    dw 227
    db 80
    dw 445
    db 72
    dw 172
    db 64
    dw 344
    db 56
    dw 369
    db 48
    dw 255
    db 40
    dw 330
    db 32
    dw 122
    db 24
    dw 0
    db 0
SFX_CHECK:
    dw 1868
    db 50
    dw 1868
    db 50
    dw 1868
    db 50
    dw 2493
    db 50
    dw 2493
    db 43
    dw 2493
    db 36
    dw 2493
    db 29
    dw 2493
    db 22
    dw 2493
    db 15
    dw 0
    db 0
SFX_CLINK:
    dw 4767
    db 30
    dw 3575
    db 20
    dw 0
    db 0
SFX_DIE:
    dw 1191
    db 100
    dw 1065
    db 96
    dw 953
    db 92
    dw 852
    db 88
    dw 762
    db 85
    dw 682
    db 81
    dw 610
    db 77
    dw 545
    db 74
    dw 488
    db 70
    dw 436
    db 66
    dw 390
    db 63
    dw 349
    db 59
    dw 312
    db 55
    dw 279
    db 52
    dw 249
    db 48
    dw 223
    db 44
    dw 199
    db 41
    dw 178
    db 37
    dw 159
    db 33
    dw 143
    db 30
    dw 0
    db 0
SFX_CHEST:
    dw 476
    db 70
    dw 583
    db 70
    dw 715
    db 70
    dw 1430
    db 50
    dw 1637
    db 43
    dw 1873
    db 36
    dw 2145
    db 30
    dw 0
    db 0
SFX_SELECT:
    dw 2383
    db 40
    dw 2383
    db 20
    dw 0
    db 0
SFX_THUNDER:
    dw 84
    db 128
    dw 115
    db 122
    dw 217
    db 116
    dw 163
    db 110
    dw 138
    db 104
    dw 197
    db 98
    dw 168
    db 92
    dw 135
    db 86
    dw 241
    db 80
    dw 221
    db 74
    dw 123
    db 69
    dw 194
    db 63
    dw 184
    db 57
    dw 259
    db 51
    dw 227
    db 45
    dw 133
    db 39
    dw 281
    db 33
    dw 96
    db 27
    dw 161
    db 21
    dw 233
    db 15
    dw 0
    db 0
