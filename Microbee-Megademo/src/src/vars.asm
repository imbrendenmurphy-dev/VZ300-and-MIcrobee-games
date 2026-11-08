; =====================================================================
;  variables (cleared at start-up; they follow the program)
; =====================================================================
vars_start:
ksp	dw 0
lpp	dw 0
lp_live	db 0
lp_build db 0
overruns db 0
st_src	dw 0
st_dst	dw 0
r1val	db 0
s1_addr	dw 0
cur_blk	db 0
monomode db 0
pframes	dw 0
pr_frame dw 0
pr_end	dw 0
js_left	dw 0
js_ptr	dw 0
js_m	db 0
jb_kind	db 0
tb_ph	db 0
tr_slot	db 0
tr_fa	dw 0
tr_fb	dw 0
tb_sp	dw 0
tb_list	ds 4*8
pl_wp	dw 0
pl_y	db 0
pl_e	db 0
tr_ph	db 0
; music
mus_on	db 0
m_order	dw 0
m_loop	dw 0
m_opos	dw 0
m_frames dw 0
m_tick	db 0
m_speed	db 0
m_row	db 0
m_ptr	dw 0
m_lnote	db 0
m_bnote	db 0
m_linst	db 0
m_binst	db 0
m_lt	dw 0
m_bt	dw 0
m_drum	db 0
m_dt	db 0
rseed	dw 0
; the current part's variables (cleared when it starts)
PV_SIZE	equ 96
pv	ds PV_SIZE
pv_done	equ pv+PV_SIZE-1
vars_end:
