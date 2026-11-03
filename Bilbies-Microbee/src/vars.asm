; ---------------------------------------------------------------------------
; variables at $7800 (cleared at boot)
; ---------------------------------------------------------------------------
        ORG VARS
v_tick:     db 0
v_last:     db 0
v_hold:     db 0
v_latch:    db 0
v_spkoff:   db 0
v_spkon:    db 0
v_joyok:    db 0
v_seed:     dw 0
v_ctl:      db 0
v_ctlold:   db 0
v_kold:     db 0
v_musicon:  db 0
v_sfxon:    db 0
v_demo:     db 0            ; scripted skills (attract mode / tests)
v_test:     db 0            ; test run: keys don't stop it
v_quit:     db 0
v_train:    db 0            ; trainer: every level open
v_unlock:   db 0            ; highest level reached
v_lvl:      db 0
v_title:    db 0            ; title scene running
; level
v_lname:    dw 0
v_nbuf:     ds 26
v_ncrt:     db 0            ; (these 12 are copied from the level header)
v_rate:     db 0
v_tosave:   db 0
v_min:      db 0
v_skill:    ds 8
v_lwb:      db 0            ; width / 4
v_lw:       dw 0            ; width in pixels
v_lh:       db 0            ; (these 13 are copied from the header)
v_hx:       dw 0
v_hy:       db 0
v_ex:       dw 0
v_ey:       db 0
v_brick:    db 0
v_wy:       db 0
v_wx0:      dw 0
v_wx1:      dw 0
v_bgtex:    dw 0
v_nsteel:   db 0
v_steel:    ds 6*8
v_minrate:  db 0
; level building
v_tex:      dw 0
v_prow:     dw 0
v_trow:     dw 0
v_fmode:    db 0
v_xr:       dw 0
v_x0:       dw 0
v_x1:       dw 0
v_op:       db 0
v_ecy:      db 0
v_rx:       db 0
v_ry:       db 0
v_dy:       db 0
v_hw:       db 0
v_lfsr:     dw 0
v_cnt:      dw 0
v_k:        dw 0
v_gp:       dw 0
v_inrun:    db 0
v_runx:     dw 0
v_brow:     dw 0
v_mrow:     dw 0
v_pm:       db 0
v_nm:       db 0
v_sm:       db 0
v_dp:       dw 0
v_mp:       dw 0
v_texa:     dw 0
v_texb:     dw 0
v_band1:    db 0
v_band2:    db 0
v_rowsave:  db 0
v_top:      db 0
v_bot:      db 0
v_erow:     dw 0
v_efill:    db 0
; game state
v_released: db 0
v_saved:    db 0
v_lost:     db 0
v_reltimer: db 0
v_hatch:    db 0
v_paused:   db 0
v_nuke:     db 0
v_nukeidx:  db 0
v_nukeask:  dw 0
v_end:      db 0
v_gtick:    dw 0
v_tleft:    dw 0
v_secfr:    db 0
v_loop:     db 0
v_dug:      db 0
v_spawnfl:  db 0
v_nblock:   db 0
; view / controls
v_scrb:     db 0
v_scry:     db 0
v_lastsy:   db 0
v_cx:       db 0
v_cy:       db 0
v_cheld:    db 0
v_sel:      db 0
v_hcount:   db 0
v_hst:      db 0
v_hptr:     dw 0
v_hx2:      dw 0
v_hy2:      db 0
v_spx:      dw 0
v_sx:       db 0
v_sy:       db 0
v_wcnt:     db 0
v_wph:      db 0
; demo
v_dptr:     dw 0
v_demoidx:  db 0
v_dlast:    db 0
v_ev0:      dw 0
v_ev1:      dw 0
v_dfired:   ds 8
; panel
v_psig:     db 0
v_pdirty:   db 0
v_pselold:  db 0
v_psb:      db 0
v_fcol:     db 0
v_fc:       db 0
v_bnaddr:   dw 0
v_g1:       dw 0
v_g2:       dw 0
v_mmcol:    db 0
v_mmm:      db 0
v_mmw:      db 0
v_mmdone:   db 0
; sprite drawing
ds_sh:      db 0
ds_col:     db 0
ds_ptr:     dw 0
ds_n:       db 0
ds_o0:      db 0
ds_o1:      db 0
ds_d0:      db 0
ds_d1:      db 0
ds_d2:      db 0
ds_rows:    db 0
v_lastscr:  db 0
v_csaved:   db 0
v_ccol:     db 0
v_crow:     db 0
CURSAVE:    ds 21            ; row table page (BROW or VROW)
; text
t_fg:       db 0
t_bg:       db 0
EXPT:       ds 16
numbuf:     ds 6
sbuf:       ds 34
MMB:        ds 88
MMS:        ds 88
; title
v_pcol:     ds NCRT
v_prow2:    ds NCRT
v_tframe:   db 0
v_idle:     dw 0
v_flash:    db 0
v_infoi:    db 0
v_res:      db 0
; Derived tick-local index. State is rechecked when queried, because a
; blocker may fall or enter its bomb animation earlier in this same tick.
v_blkptrs:  ds NCRT*2
VARS_END:
        ASSERT VARS_END <= CRT
