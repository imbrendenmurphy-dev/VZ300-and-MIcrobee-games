; generated blit routines (interrupts must be off)
BLIT_PF:
    ld (BLIT_SP),sp
    ld sp,FB+324
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7110
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+340
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7120
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+364
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7130
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+380
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7140
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+404
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7150
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+420
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7160
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+444
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7170
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+460
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7180
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+484
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7190
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+500
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$71A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+524
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$71B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+540
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$71C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+564
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$71D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+580
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$71E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+604
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$71F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+620
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7200
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+644
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7210
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+660
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7220
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+684
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7230
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+700
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7240
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+724
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7250
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+740
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7260
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+764
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7270
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+780
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7280
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+804
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7290
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+820
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$72A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+844
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$72B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+860
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$72C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+884
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$72D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+900
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$72E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+924
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$72F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+940
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7300
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+964
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7310
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+980
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7320
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1004
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7330
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1020
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7340
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1044
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7350
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1060
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7360
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1084
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7370
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1100
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7380
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1124
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7390
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1140
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$73A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1164
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$73B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1180
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$73C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1204
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$73D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1220
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$73E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1244
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$73F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1260
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7400
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1284
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7410
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1300
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7420
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1324
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7430
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1340
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7440
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1364
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7450
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1380
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7460
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1404
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7470
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1420
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7480
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1444
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7490
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1460
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$74A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1484
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$74B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1500
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$74C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1524
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$74D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1540
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$74E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1564
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$74F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1580
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7500
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1604
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7510
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1620
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7520
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1644
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7530
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1660
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7540
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1684
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7550
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1700
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7560
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1724
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7570
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1740
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7580
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1764
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7590
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1780
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$75A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1804
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$75B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1820
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$75C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1844
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$75D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1860
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$75E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1884
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$75F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1900
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7600
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1924
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7610
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1940
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7620
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1964
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7630
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+1980
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7640
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2004
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7650
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2020
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7660
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2044
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7670
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2060
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7680
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2084
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7690
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2100
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$76A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2124
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$76B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2140
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$76C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2164
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$76D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2180
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$76E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2204
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$76F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2220
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7700
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2244
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7710
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2260
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7720
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2284
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7730
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2300
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7740
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2324
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7750
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2340
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7760
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2364
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7770
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2380
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7780
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2404
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7790
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2420
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$77A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2444
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$77B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2460
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$77C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2484
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$77D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2500
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$77E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2524
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$77F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+2540
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7800
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,(BLIT_SP)
    ret
BLIT_TOP:
    ld (BLIT_SP),sp
    ld sp,FB+4
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7010
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+20
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7020
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+44
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7030
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+60
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7040
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+84
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7050
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+100
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7060
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+124
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7070
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+140
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7080
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+164
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7090
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+180
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+204
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+220
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+244
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+260
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+284
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,FB+300
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7100
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,(BLIT_SP)
    ret
BLIT_HUD:
    ld (BLIT_SP),sp
    ld sp,HUDBUF+0
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7010
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+16
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7020
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+32
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7030
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+48
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7040
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+64
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7050
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+80
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7060
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+96
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7070
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+112
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7080
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+128
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7090
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+144
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70A0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+160
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70B0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+176
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70C0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+192
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70D0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+208
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70E0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+224
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$70F0
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,HUDBUF+240
    pop af
    pop bc
    pop de
    pop hl
    exx
    pop bc
    pop de
    pop hl
    pop ix
    ld sp,$7100
    push ix
    push hl
    push de
    push bc
    exx
    push hl
    push de
    push bc
    push af
    ld sp,(BLIT_SP)
    ret
