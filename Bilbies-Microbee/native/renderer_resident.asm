; Persistent foreground residency experiment. Common code and UI are fixed;
; metadata/kernel use block 14, compiled column programs use block 26.
        DEFINE RESIDENT_CACHE 1
n_patch_buffer EQU $E600
        INCLUDE "common.asm"
n_sprites:
        ld a,14 : call n_bank : jp n_renderer_work
n_execute_list:
        ld a,26 : call n_bank
        call $EC00
        ld a,14 : jp n_bank

n_slot: db 0
n_overflow: db 0
n_pool_valid: db 0
n_pool_highwater: db 0
n_free_count: db 0
n_generation: db 0
n_mark_kind: db 0
n_cell_count: dw 0
n_cells_write: dw 0
n_cells_left: dw 0
n_command_write: dw 0
n_command_count: db 0
n_remaining: db 0
n_xphase: db 0
n_col: db 0
n_dy: db 0
n_topcell: dw 0
n_topcpu: dw 0
n_sprite: dw 0
n_drawptr: dw 0
n_columns: db 0
n_column_touch: db 0
n_start_row: db 0
n_end_row: db 0
n_cell: dw 0
n_tileptr: dw 0
n_usedslot: db 0
n_scan_slot: db 0
n_work_left: db 0
n_rows_new: db 0
n_rows_old: db 0
n_rows_current: db 0
n_copy_first: db 0
n_copy_len: db 0
n_basechar: db 0
n_baseattr: db 0
n_basecolour: db 0
n_pcg_selected: db 0
n_patch_count: db 0
n_initial_entities: INCBIN "../build/native/entities.bin"
n_demo_patches: INCBIN "../build/native/patches.bin"
n_end:
        ASSERT n_end < $9000
        ASSERT $EC00+40*(3*6+3)+1 < $EFC0
        SAVEBIN "../build/native/ENGINE.HI",$8000,n_end-$8000
        ORG 0
        INCBIN "../build/native/sprite-meta.bnk"
        ORG $6000
        INCLUDE "resident.asm"
n_resident_end:
        ASSERT n_resident_end < $8000
        SAVEBIN "../build/native/RENDER.BNK",0,$8000
