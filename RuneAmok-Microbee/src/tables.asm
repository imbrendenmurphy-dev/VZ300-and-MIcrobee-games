; =====================================================================
;  TABLES: square types
;   0 floor  1 wall  2 wall (second look)  3 door  4 gate  5 sealed door
;   6 illusion (looks like a wall, walk through)  7 hidden wall (opens by
;   a trigger)  8/9/10 bronze / silver / gold locked doors
;  16 stairs down  17 stairs up  18 pit  19 pressure plate
;  20 teleporter  21 spinner (unseen)  22 rune floor (unseen trigger)
; =====================================================================
T_FLOOR     EQU 0
T_WALL      EQU 1
T_WALL2     EQU 2
T_DOOR      EQU 3
T_GATE      EQU 4
T_SEAL      EQU 5
T_ILLUS     EQU 6
T_HIDDEN    EQU 7
T_LOCK1     EQU 8
T_LOCK2     EQU 9
T_LOCK3     EQU 10
T_DOWN      EQU 16
T_UP        EQU 17
T_PIT       EQU 18
T_PLATE     EQU 19
T_TELE      EQU 20
T_SPIN      EQU 21
T_MARK      EQU 22

        ALIGN 256
; the look of each square type in the view: 0 open, 1 wall, 2 wall B,
; 3 door, 4 gate, 5 sealed door (the wall table kinds)
kindtab:
        db 0,1,2,3,4,5,1,1,3,3,3,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ds 256-32,1
; can you walk onto it? (1 = yes)
passtab:
        db 1,0,0,0,0,0,1,0,0,0,0,1,1,1,1,1
        db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
; what a floor type shows as a sprite (0 = nothing): see sprites.py
floorspr:
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db SP_STAIRS,SP_UPSTAIR,SP_PIT,SP_PLATE,SP_PORTAL,0,0,0,0,0,0,0,0,0,0,0

; facing: map step forward (N E S W)
fwdtab: dw -32, 1, 32, -1
