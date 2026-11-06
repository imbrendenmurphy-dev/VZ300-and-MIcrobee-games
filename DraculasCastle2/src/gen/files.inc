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

area_files: dw f_dc2a0p1,f_dc2a0p2,f_dc2a0s,f_dc2a1p1,f_dc2a1p2,f_dc2a1s
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
            db 3,0,0,0
            dw mname_3
            db 60,8,4,45,60,8,0,3
            dw f_dc2mon4
            db 0,0,0,0
f_dc2mon1: dw 2112
            db 34,"DC2MON1",34,0

f_dc2mon2: dw 2112
            db 34,"DC2MON2",34,0

f_dc2mon3: dw 2112
            db 34,"DC2MON3",34,0

f_dc2mon4: dw 2112
            db 34,"DC2MON4",34,0

mname_0: db "BAT",0
mname_1: db "SKELETON",0
mname_2: db "GHOST",0
mname_3: db "GARGOYLE",0
f_dc2bbg0: dw 1472
            db 34,"DC2BBG0",34,0

f_dc2bbg1: dw 1472
            db 34,"DC2BBG1",34,0

bbg_files: dw f_dc2bbg0,f_dc2bbg1
f_title: dw 2048
            db 34,"DC2TITLE",34,0

f_egg: dw 2048
            db 34,"DC2EGG",34,0

