; generated SD file table
f_dc2a0p1: dw 6424
            db 34,"DC2A0P1",34,0

f_dc2a0p2: dw 6946
            db 34,"DC2A0P2",34,0

f_dc2a0s: dw 911
            db 34,"DC2A0S",34,0

f_dc2a1p1: dw 5384
            db 34,"DC2A1P1",34,0

f_dc2a1p2: dw 6246
            db 34,"DC2A1P2",34,0

f_dc2a1s: dw 575
            db 34,"DC2A1S",34,0

f_dc2a2p1: dw 5384
            db 34,"DC2A2P1",34,0

f_dc2a2p2: dw 6580
            db 34,"DC2A2P2",34,0

f_dc2a2s: dw 1411
            db 34,"DC2A2S",34,0

f_dc2a3p1: dw 5384
            db 34,"DC2A3P1",34,0

f_dc2a3p2: dw 5956
            db 34,"DC2A3P2",34,0

f_dc2a3s: dw 960
            db 34,"DC2A3S",34,0

area_files: dw f_dc2a0p1,f_dc2a0p2,f_dc2a0s,f_dc2a1p1,f_dc2a1p2,f_dc2a1s,f_dc2a2p1,f_dc2a2p2,f_dc2a2s,f_dc2a3p1,f_dc2a3p2,f_dc2a3s
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
            db 32,10,3,16,10,1,0,3
            dw f_dc2mon6
            db 2,3,0,0
            dw mname_6
            db 26,9,6,14,12,0,0,3
            dw f_dc2mon7
            db 2,3,0,0
            dw mname_7
            db 120,14,6,120,100,9,1,3
            dw f_dc2mon8
            db 2,3,0,0
f_dc2mon1: dw 2112
            db 34,"DC2MON1",34,0

f_dc2mon2: dw 2112
            db 34,"DC2MON2",34,0

f_dc2mon3: dw 2112
            db 34,"DC2MON3",34,0

f_dc2mon4: dw 2112
            db 34,"DC2MON4",34,0

f_dc2mon5: dw 2112
            db 34,"DC2MON5",34,0

f_dc2mon6: dw 2112
            db 34,"DC2MON6",34,0

f_dc2mon7: dw 2112
            db 34,"DC2MON7",34,0

f_dc2mon8: dw 2112
            db 34,"DC2MON8",34,0

mname_0: db "BAT",0
mname_1: db "SKELETON",0
mname_2: db "GHOST",0
mname_3: db "GARGOYLE",0
mname_4: db "GRELL",0
mname_5: db "ZOMBIE",0
mname_6: db "SLIME",0
mname_7: db "GHOUL KING",0
NUM_MONSTERS equ 8
f_dc2bbg0: dw 1472
            db 34,"DC2BBG0",34,0

f_dc2bbg1: dw 1472
            db 34,"DC2BBG1",34,0

f_dc2bbg2: dw 1472
            db 34,"DC2BBG2",34,0

f_dc2bbg3: dw 1472
            db 34,"DC2BBG3",34,0

bbg_files: dw f_dc2bbg0,f_dc2bbg1,f_dc2bbg2,f_dc2bbg3
f_title: dw 2048
            db 34,"DC2TITLE",34,0

f_egg: dw 2048
            db 34,"DC2EGG",34,0

