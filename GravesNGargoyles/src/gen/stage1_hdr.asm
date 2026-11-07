; stage 1 header (Gallows Hill content comes from mkassets.py)
        db 'S',1
        dw LEVEL1_MAP,LEVEL1_W,LEVEL1_OBJ,TILES,TATTR,SONG_STAGE1,SONG_BOSS,S_MOON_0,S_BSKULL_0,S_BJAW_0
        db 8,11,16,3,$00,1
        dw CARD_STAGE1,STR_BOSS
        dw S_ZOMBIE_0,S_ZOMBIE_1,S_ZOMBIE_0,S_ZOMBIE_1
        dw S_SKEL_0,S_SKEL_1,S_SKEL_2,S_SKEL_3
        dw S_BAT_0,S_BAT_1,S_BAT_0,S_BAT_1
        dw S_GHOST_0,S_GHOST_1,S_GHOST_0,S_GHOST_1
        dw S_CROW_0,S_CROW_1,S_CROW_0,S_CROW_1
        dw S_PLANT_0,S_PLANT_1,S_PLANT_0,S_PLANT_1
        dw S_IMP_0,S_IMP_1,S_IMP_0,S_IMP_1
        dw S_SKULL_0,S_SKULL_0
        db 0,3,18
        dw LEVEL1_COLS,S1_LOGIC
S1_LOGIC: dw o_zombie,o_skel,o_bat,o_ghost,o_crow,o_imp,o_plant
