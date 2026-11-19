dirty_end: ds 2
blit_mode: ds 1
blit_w: ds 1
blit_h: ds 1
blit_col: ds 1
blit_x: ds 1
blit_y: ds 1
blit_shift: ds 1
blit_src: ds 2
blit_dst: ds 2
blit_carry: ds 1
native_text: ds 20
native_fill: ds 160
native_flash: ds 1

render_cache: ds NENTS*6
cache_flags: ds 1
cache_cell: ds 1
hw_vblank: ds 1
hw_pending: ds 1
logic_steps: ds 1

phase_melody: ds 2
phase_bass: ds 2

text_origin: ds 1
sprite_origin: ds 1

dirty_end1: ds 2
draw_page: ds 1
mono_mode: ds 1
mono_key: ds 1
prepared_width: ds 1
prepared_height: ds 1
prepared_size: ds 2
prepared_cols: ds 1
prepared_x: ds 1
