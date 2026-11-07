; ===================================================================
;  text.asm - game text, kept in the overlay block (engine copies it
;  out with far_str when it needs it)
; ===================================================================
tn0:    db "ROAD      ",0
tn1:    db "HUT       ",0
tn2:    db "FARM      ",0
tn3:    db "WOODCUTTER",0
tn4:    db "QUARRY    ",0
tn5:    db "WELL      ",0
tn6:    db "MARKET    ",0
tn7:    db "WINDMILL  ",0
tn8:    db "WATCHTOWER",0
tn9:    db "CLEAR LAND",0
on0:    db "",0
on1:    db "ROAD",0
on2:    db "TOWN HALL",0
on6:    db "HUT",0
on7:    db "HOUSE",0
on8:    db "MANOR",0
th0:    db "ROADS LINK; BRIDGE RIVERS",0
th1:    db "HOMES 4; GROWS INTO HOUSE",0
th2:    db "PLOUGHS GRASS INTO FIELDS",0
th3:    db "TIMBER FROM NEARBY FOREST",0
th4:    db "STONE FROM HILLS AND ROCK",0
th5:    db "WATER: HAPPIER, HOMES GROW",0
th6:    db "TRADE GOLD; MANORS NEED IT",0
th7:    db "+FOOD EXCEPT IN WINTER",0
th8:    db "SEES FAR, WIDENS LANDS",0
th9:    db "FELL, DRAIN, DEMOLISH",0
sn0:    db "SPRING",0
sn1:    db "SUMMER",0
sn2:    db "AUTUMN",0
sn3:    db "WINTER",0
msg_welcome:  db "YOUR SETTLERS HAVE FOUNDED A TOWN. BUILD HUTS, FARMS AND A WOODCUTTER!",0
msg_hint:     db "ARROWS MOVE  SPACE BUILD  1-0 TOOLS  M MAP  F SAVE/LOAD  P PAUSE  H HELP",0
msg_started:  db "CONSTRUCTION BEGUN.",0
msg_complete: db "CONSTRUCTION COMPLETE!",0
msg_grow:     db "A HUT HAS GROWN INTO A FINER HOME.",0
msg_starve:   db "FOOD HAS RUN OUT - PEOPLE ARE LEAVING! BUILD FARMS.",0
msg_ruins:    db "ANCIENT RUINS DISCOVERED! SCHOLARS FIND 25 GOLD.",0
msg_quit:     db "ABANDON THIS WORLD AND RETURN TO THE MENU? (Y/N)",0
msg_ev_trade: db "TRAVELLING TRADERS ARRIVE: +30 GOLD",0
msg_ev_harvest: db "A BUMPER HARVEST: +40 FOOD",0
msg_ev_migrant: db "MIGRANTS SETTLE IN YOUR TOWN: +5 PEOPLE",0
msg_ev_storm: db "A STORM DAMAGES THE TIMBER STORES: -10 WOOD",0
msg_ev_wolves: db "WOLVES RAID THE GRANARY: -8 FOOD",0
ms0:    db "SPRING ARRIVES. THE FIELDS ARE SOWN.",0
ms1:    db "SUMMER. THE CROPS GROW TALL.",0
ms2:    db "AUTUMN - HARVEST TIME!",0
ms3:    db "WINTER. SNOW COVERS THE LAND; FARMS LIE FALLOW.",0
err_fog:      db "YOU HAVE NOT EXPLORED THERE. BUILD A WATCHTOWER TO SEE FURTHER.",0
err_terr:     db "TOO FAR FROM YOUR SETTLEMENT. BUILD CLOSER, OR RAISE A TOWER.",0
err_occ:      db "THAT SPOT IS ALREADY OCCUPIED.",0
err_terrain:  db "YOU CANNOT BUILD ON THAT TERRAIN.",0
err_forest:   db "CLEAR THE FOREST FIRST (TOOL 0).",0
err_farm:     db "FARMS NEED OPEN GRASSLAND OR MEADOW.",0
err_wood:     db "A WOODCUTTER NEEDS FOREST WITHIN 2 TILES.",0
err_quarry:   db "A QUARRY NEEDS HILLS, ROCK OR MOUNTAINS NEARBY.",0
err_poor:     db "NOT ENOUGH RESOURCES.",0
err_tc:       db "THE TOWN HALL CANNOT BE DEMOLISHED.",0
err_nothing:  db "NOTHING TO CLEAR HERE.",0
txt_yr:       db " YR ",0
txt_unexplored: db "UNEXPLORED",0
txt_building: db " (BUILDING)",0
txt_worldmap: db "WORLD MAP",0
txt_ovhelp:   db "WASD MOVE",0
de1:    db "THERE IS NO SAVED WORLD IN THAT SLOT.",0
de2:    db "THE DISK IS WRITE-PROTECTED.",0
de3:    db "NO ROOM IN THE DISK DIRECTORY.",0
de4:    db "THE DISK IS FULL - THE SAVE IS INCOMPLETE.",0
de5:    db "THAT SAVE IS DAMAGED OR NOT AN EMPIRES SAVE.",0
msg_reading: db "READING THE DISK...",0
msg_saving:  db "SAVING YOUR WORLD TO DISK...",0
msg_saved:   db "YOUR WORLD HAS BEEN SAVED.",0
msg_loaded:  db "WORLD LOADED. WELCOME BACK!",0
txt_building_world: db "BUILDING A NEW WORLD",0
msg_gen1: db "SHAPING THE CONTINENTS...",0
msg_gen2: db "RAISING THE MOUNTAINS...",0
msg_gen3: db "CARVING RIVERS...",0
msg_gen4: db "PLANTING FORESTS...",0
