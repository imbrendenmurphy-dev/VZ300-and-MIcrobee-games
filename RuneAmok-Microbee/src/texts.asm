; =====================================================================
;  TEXTS (the log wraps them at 24 columns)
; =====================================================================
t_the:          db "The ",0
t_youhit:       db "You strike ",0
t_youmiss:      db "You miss ",0
t_for:          db " for ",0
t_dies:         db " is slain!",0
t_plus:         db " +",0
t_xp:           db " XP",0
t_misses:       db " misses.",0
t_strikes:      db " hits you ",0
t_fromside:     db "from the side ",0
t_levelup:      db "You grow stronger: level ",0
t_blocked:      db "Something blocks the way.",0
t_door_shut:    db "A door. SPACE opens it.",0
t_door_open:    db "The door creaks open.",0
t_gate_shut:    db "The gate is shut fast.",0
t_locked:       db "The door is locked.",0
t_wall:         db "Cold, solid stone.",0
t_illus:        db "Your hand passes through the stone!",0
t_torch:        db "The torch gutters in a cold draught.",0
t_nothing:      db "Nothing more happens.",0
t_alcove_empty: db "The alcove is empty.",0
t_fount:        db "You drink. Strength and magic flow back.",0
t_fount_dry:    db "The fountain has run dry.",0
t_rune_ok:      db "The rune kindles.",0
t_rune_bad:     db "The runes gutter out. Wrong order.",0
t_vault:        db "A vault door, sealed by runes.",0
t_seal:         db "Sealed by three sigils.",0
t_seal_open:    db "The three sigils blaze: the seal breaks!",0
t_down:         db "You descend...",0
t_up:           db "You climb back up.",0
t_noup:         db "The way out is barred until the King falls.",0
t_pit:          db "The floor gives way! You fall!",0
t_portal:       db "A portal whirls you away!",0
t_spin:         db "The floor turns beneath you!",0
t_gold_a:       db "You find # gold.",0
t_potion:       db "A healing potion.",0
t_sword:        db "A finer sword! Attack +2",0
t_armour:       db "Mail armour! Defence +2",0
t_fire:         db "A scroll: you learn FIREBOLT (key 1).",0
t_mend:         db "A tome: you learn MEND (key 2).",0
t_sigil:        db "A SIGIL! It hums with old power.",0
t_ring:         db "A ring of vigour: Health +5",0
t_vial:         db "A mana vial: magic restored.",0
t_bones:        db "Old bones. Best not to linger.",0
t_key_tab:      dw t_key1, t_key2, t_key3
t_key1:         db "A bronze key.",0
t_key2:         db "A silver key.",0
t_key3:         db "A golden key.",0
t_unlock_tab:   dw t_unl1, t_unl2, t_unl3
t_unl1:         db "The bronze key turns.",0
t_unl2:         db "The silver key turns.",0
t_unl3:         db "The golden key turns.",0
t_nokey_tab:    dw t_nk1, t_nk2, t_nk3
t_nk1:          db "Locked: it wants a bronze key.",0
t_nk2:          db "Locked: it wants a silver key.",0
t_nk3:          db "Locked: it wants a golden key.",0
t_nopotion:     db "You have no potions.",0
t_quaff:        db "You drink a potion. +25",0
t_nospell:      db "You know no such spell.",0
t_nomp:         db "Not enough magic.",0
t_mended:       db "Warm light mends your wounds.",0
t_fizzle:       db "The firebolt bursts on stone.",0
t_trader_no:    db "The trader ducks. 'Oi!'",0
t_shop1:        db "Trader: 1 Potion 20g  2 Hone blade  3 Mend mail",0
t_shop2:        db "(blade and mail 50g+) SPACE leaves.",0
t_shop_sold:    db "'A pleasure, last Warden.'",0
t_shop_poor:    db "'Come back with gold.'",0
t_shop_bye:     db "'Mind the dark.'",0
t_snd_all:      db "Sound: music and effects.",0
t_snd_fx:       db "Sound: effects only.",0
t_snd_off:      db "Sound: off.",0
t_help:         db "Arrows/WASD move, Q E step, SPACE act, 1 fire 2 mend 3 potion, T sound, ESC quit",0
t_quit:         db "Leave the Runedeep? (Y/N)",0
t_onward:       db "Onward, then.",0
t_dead1:        db "You have fallen in the dark...",0
t_dead2:        db "Rise again (half your gold lost)? Y/N",0
t_rise:         db "You rise, aching, at the stair.",0
t_king_rage:    db "The Hollow King howls - the ash hounds answer!",0

t_subtitle:     db "The Vault of the Hollow King",0
t_credit:       db "VIBED BY BPM 2026",0
t_press:        db "Press SPACE to descend",0
t_blank38:      db "                                        ",0

; title pages: row, column, colour, text ... FF
tt_tale:
        db 10,3,WHITE,"For a thousand years the Wardens",0
        db 11,3,WHITE,"kept the Hollow King sealed in the",0
        db 12,3,WHITE,"Runedeep. Now the order is dust,",0
        db 13,3,WHITE,"and you - its last, half-trained",0
        db 14,3,WHITE,"apprentice - hear him stir below.",0
        db 16,3,BCYAN,"Find the three SIGILS that seal his",0
        db 17,3,BCYAN,"vault, break the seal, and end him.",0
        db 19,3,GREY,"Keys, levers, runes, a shifty",0
        db 20,3,GREY,"trader - and things that bite.",0
        db $FF
tt_keys:
        db 10,3,YELLOW,"Arrows / W A S D",0
        db 10,20,WHITE,"walk and turn",0
        db 11,3,YELLOW,"Q E (or Z X)",0
        db 11,20,WHITE,"step aside",0
        db 12,3,YELLOW,"SPACE / RETURN",0
        db 12,20,WHITE,"fight, open, use",0
        db 13,3,YELLOW,"1",0
        db 13,20,WHITE,"FIREBOLT (3 magic)",0
        db 14,3,YELLOW,"2",0
        db 14,20,WHITE,"MEND (4 magic)",0
        db 15,3,YELLOW,"3 or P",0
        db 15,20,WHITE,"drink a potion",0
        db 16,3,YELLOW,"H",0
        db 16,20,WHITE,"help",0
        db 17,3,YELLOW,"T",0
        db 17,20,WHITE,"music/effects/off",0
        db 18,3,YELLOW,"ESC",0
        db 18,20,WHITE,"back to CP/M",0
        db 20,1,GREY,"Turning is free; all else takes a turn.",0
        db $FF
tt_foes:
        db 10,3,BRED,"Rats and restless skeletons",0
        db 11,5,GREY,"guard the Gatehouse.",0
        db 12,3,BMAGENTA,"Spiders and fungoids",0
        db 13,5,GREY,"creep in the Fungal Grotto.",0
        db 14,3,BGREEN,"Ghouls and wisps",0
        db 15,5,GREY,"drift through the Drowned Archive.",0
        db 16,3,YELLOW,"Imps and ash hounds",0
        db 17,5,GREY,"keep the Ember Throne -",0
        db 18,3,BCYAN,"and the Hollow King waits there.",0
        db $FF

; the end screens
es_win:
        db 9,4,YELLOW,"The Hollow King crumbles to ash.",0
        db 11,3,WHITE,"The last Warden has kept the oath.",0
        db 12,5,WHITE,"The Runedeep sleeps once more.",0
        db 22,9,GREY,"Press a key for the title",0
        db $FF
es_lose:
        db 9,6,BRED,"You have fallen in the dark.",0
        db 11,2,WHITE,"The Hollow King stirs on, unopposed,",0
        db 12,3,WHITE,"and the Runedeep waits for another.",0
        db 22,9,GREY,"Press a key for the title",0
        db $FF
es_labels:
        db 15,10,YELLOW,"Turns taken",0
        db 16,10,YELLOW,"Foes slain",0
        db 17,10,YELLOW,"Gold carried",0
        db 18,10,YELLOW,"Warden level",0
        db 19,10,YELLOW,"Sigils found",0
        db $FF
