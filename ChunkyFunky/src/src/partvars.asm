; part variables (inside the NOEMIT block of main.asm)
pl_b1:      ds 1
pl_b2:      ds 1
st_speed:   ds 1
st_row:     ds 2
st_step:    ds 2
st_ready:   ds 1
stars:      ds NSTAR*6                  ; x index, y index, z, address lo/hi, mask
cu_a:       ds 1
cu_b:       ds 1
cu_sa:      ds 1
cu_ca:      ds 1
cu_sb:      ds 1
cu_cb:      ds 1
cu_saS:     ds 1
cu_caS:     ds 1
cu_cols:    ds 9                        ; rotation columns C0 C1 C2 (x y z each), scaled
cu_vx:      ds 24                       ; corners: X[8] Y[8] Z[8]
cu_sx:      ds 8                        ; screen x[8], then y[8]
cu_sy:      ds 8
cu_ox0:     ds 1
cu_ox1:     ds 1
cu_oy0:     ds 1
cu_oy1:     ds 1
cu_nx0:     ds 1
cu_nx1:     ds 1
cu_ny0:     ds 1
cu_ny1:     ds 1
cu_ux0:     ds 1
cu_ux1:     ds 1
cu_uy0:     ds 1
cu_rows:    ds 1
ln_dx:      ds 1
ln_dy:      ds 1
sc_pos:     ds 2
sc_half:    ds 1
sc_p:       ds 2
sc_ph:      ds 1
sc_col:     ds 1
sc_old:     ds 64
sc_obar:    ds NBAR
tu_ox:      ds 1
tu_oy:      ds 1
tu_rows:    ds 1
cr_ptr:     ds 2
cr_cnt:     ds 1
