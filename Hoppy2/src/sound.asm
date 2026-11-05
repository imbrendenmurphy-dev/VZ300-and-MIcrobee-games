;=====================================================================
; sound data: (n, fields) pairs, n = half-period (0 rest, $80+ noise), fields 0 = end
; freq ~ 57208/(n+1.35) Hz
;=====================================================================
; note values
N_C4 equ 217
N_D4 equ 193
N_E4 equ 172
N_F4 equ 162
N_G4 equ 145
N_A4 equ 129
N_B4 equ 114
N_C5 equ 108
N_D5 equ 96
N_E5 equ 85
N_F5 equ 80
N_G5 equ 72
N_A5 equ 64
N_B5 equ 57
N_C6 equ 53
N_D6 equ 47
N_E6 equ 42
N_G6 equ 35
N_C7 equ 26
N_G3 equ 255

	MACRO NT n,len		; staccato note: sound len-2 then 2 rest
	db n,len-2,0,2
	ENDM
	MACRO NL n,len		; legato
	db n,len
	ENDM

sfx_hop:	db 90,1,70,1,55,1,0,0
sfx_bonk:	db 230,2,250,3,0,0
sfx_squash:	db $80+6,2,$80+14,2,$80+30,3,$80+60,4,$80+110,6,0,0
sfx_splash:	db $80+3,2,$80+6,3,$80+12,4,$80+24,5,$80+48,6,0,0
sfx_faint:	db N_C5,6,N_B4,6,N_A4,6,N_G4,14,0,0
sfx_home:	db N_C5,3,N_E5,3,N_G5,3,N_C6,7,0,0
sfx_gulp:	db 40,2,60,2,90,2,130,3,0,0
sfx_pick:	db N_C6,2,N_E6,2,N_G6,2,N_C7,4,0,0
sfx_tick:	db 30,1,0,0
sfx_pop:	db 40,1,$80+10,2,70,1,0,0
sfx_rev:	db 250,2,220,2,190,2,160,2,130,3,0,0
sfx_bubble:	db 60,1,0,1,50,1,0,1,40,1,0,0
sfx_kiss:	db N_G5,2,N_C6,2,0,2,N_G5,2,N_C6,4,0,0
sfx_slow:	db 40,2,60,2,90,3,140,4,200,6,0,0
sfx_1up:	db N_G5,3,N_C6,3,N_E6,3,N_G6,3,N_C7,8,0,0
sfx_tock:	db 200,1,0,0
sfx_type:	db 50,1,0,0

sfx_croak:	db 255,1,$80+110,1,255,1,$80+120,1,0,3,230,1,$80+90,1,240,1,0,0
