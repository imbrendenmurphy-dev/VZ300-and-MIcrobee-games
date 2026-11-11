; generated SD file table
f_dc2a0p1: dw 1
            db 4
            dw 0

f_dc2a0p2: dw 1
            db 4
            dw 128

f_dc2a0s: dw 911
            db 4
            dw 256

f_dc2a1p1: dw 1
            db 4
            dw 1280

f_dc2a1p2: dw 1
            db 4
            dw 1408

f_dc2a1s: dw 575
            db 4
            dw 1536

f_dc2a2p1: dw 1
            db 4
            dw 2176

f_dc2a2p2: dw 1
            db 4
            dw 2304

f_dc2a2s: dw 1411
            db 4
            dw 2432

f_dc2a3p1: dw 1
            db 4
            dw 3968

f_dc2a3p2: dw 1
            db 4
            dw 4096

f_dc2a3s: dw 960
            db 4
            dw 4224

f_dc2a4p1: dw 1
            db 4
            dw 5248

f_dc2a4p2: dw 1
            db 4
            dw 5376

f_dc2a4s: dw 1304
            db 4
            dw 5504

f_dc2a5p1: dw 1
            db 4
            dw 6912

f_dc2a5p2: dw 1
            db 4
            dw 7040

f_dc2a5s: dw 908
            db 4
            dw 7168

area_files: dw f_dc2a0p1,f_dc2a0p2,f_dc2a0s,f_dc2a1p1,f_dc2a1p2,f_dc2a1s,f_dc2a2p1,f_dc2a2p2,f_dc2a2s,f_dc2a3p1,f_dc2a3p2,f_dc2a3s,f_dc2a4p1,f_dc2a4p2,f_dc2a4s,f_dc2a5p1,f_dc2a5p2,f_dc2a5s
monsters:
            dw mname_0
            db 9,5,0,4,3,2,0,3
            dw f_dc2mon1
            db 0,0,0,0
            dw mname_1
            db 20,7,2,9,7,1,0,3
            dw f_dc2mon2
            db 0,0,0,0
            dw mname_2
            db 18,7,1,11,8,4,1,3
            dw f_dc2mon3
            db 3,1,0,0
            dw mname_3
            db 60,8,4,45,60,8,0,3
            dw f_dc2mon4
            db 0,1,0,0
            dw mname_4
            db 80,11,4,70,60,10,0,3
            dw f_dc2mon5
            db 2,2,0,0
            dw mname_5
            db 34,14,4,16,10,1,0,3
            dw f_dc2mon6
            db 2,3,0,0
            dw mname_6
            db 28,12,8,14,12,0,0,3
            dw f_dc2mon7
            db 2,3,0,0
            dw mname_7
            db 140,20,7,120,100,9,1,3
            dw f_dc2mon8
            db 2,3,0,0
            dw mname_8
            db 46,22,12,26,18,0,0,3
            dw f_dc2mon9
            db 0,4,0,0
            dw mname_9
            db 180,26,9,160,120,10,1,3
            dw f_dc2mon10
            db 0,4,0,0
            dw mname_10
            db 255,34,12,255,255,9,0,3
            dw f_dc2mon11
            db 0,5,1,0
            dw mname_11
            db 48,26,8,30,20,1,0,3
            dw f_dc2mon12
            db 0,5,0,0
f_dc2mon1: dw 2112
            db 4
            dw 19456

f_dc2mon2: dw 2112
            db 4
            dw 28160

f_dc2mon3: dw 2112
            db 4
            dw 30336

f_dc2mon4: dw 2112
            db 5
            dw 0

f_dc2mon5: dw 2112
            db 5
            dw 2176

f_dc2mon6: dw 2112
            db 5
            dw 4352

f_dc2mon7: dw 2112
            db 5
            dw 6528

f_dc2mon8: dw 2112
            db 5
            dw 8704

f_dc2mon9: dw 2112
            db 5
            dw 10880

f_dc2mon10: dw 2112
            db 4
            dw 21632

f_dc2mon11: dw 2112
            db 4
            dw 23808

f_dc2mon12: dw 2112
            db 4
            dw 25984

mname_0: db "BAT",0
mname_1: db "SKELETON",0
mname_2: db "GHOST",0
mname_3: db "GARGOYLE",0
mname_4: db "GRELL",0
mname_5: db "ZOMBIE",0
mname_6: db "SLIME",0
mname_7: db "GHOUL KING",0
mname_8: db "KNIGHT",0
mname_9: db "BAT LORD",0
mname_10: db "DRACULA",0
mname_11: db "BRIDE",0
NUM_MONSTERS equ 12
f_dc2bbg0: dw 1472
            db 4
            dw 8192

f_dc2bbg1: dw 1472
            db 4
            dw 9728

f_dc2bbg2: dw 1472
            db 4
            dw 11264

f_dc2bbg3: dw 1472
            db 4
            dw 12800

f_dc2bbg4: dw 1472
            db 4
            dw 14336

f_dc2bbg5: dw 1472
            db 4
            dw 15872

bbg_files: dw f_dc2bbg0,f_dc2bbg1,f_dc2bbg2,f_dc2bbg3,f_dc2bbg4,f_dc2bbg5
f_title: dw 2048
            db 5
            dw 13056

f_egg: dw 2048
            db 4
            dw 17408

