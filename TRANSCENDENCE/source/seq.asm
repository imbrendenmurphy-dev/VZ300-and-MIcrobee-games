;=====================================================================
; Music sequencer (runs once per field inside the ISR)
;=====================================================================
C_PTR   equ 0
C_CNT   equ 2
C_DUTY  equ 3
C_EMODE equ 4
C_EA    equ 5
C_ES    equ 6
C_ESTEP equ 7
C_EPER  equ 8
C_ETIM  equ 9
C_DRT   equ 10
C_DRC   equ 11
C_DRI   equ 12
C_INC   equ 14
C_SP    equ 16
C_STK   equ 17      ; 2 levels x 5 bytes (ret lo,hi, count, tgt lo,hi)
C_DDUTY equ 27
C_OUT   equ 28
C_OD    equ 30
C_ENVK  equ 31
C_SIZE  equ 32

seqinit:
        ld hl,CH1
        ld b,C_SIZE*2
.c:     ld (hl),0
        inc hl
        djnz .c
        ld hl,SONG1
        ld (CH1+C_PTR),hl
        ld hl,SONG2
        ld (CH2+C_PTR),hl
        ld a,1
        ld (CH1+C_CNT),a
        ld (CH2+C_CNT),a
        ld a,2
        ld (CH1+C_EMODE),a
        ld (CH2+C_EMODE),a
        ld hl,$9E37
        ld (SEQRND),hl
        ret

seq:    ld ix,CH1
        call seqch
        ld ix,CH2
        call seqch
        ; push to sound engine
        ld a,(CH1+C_OD)
        ld (sndD1+1),a
        ld (sndiD1+1),a
        ld (DUTY1),a
        ld a,(CH2+C_OD)
        ld (sndD2+1),a
        ld (sndiD2+1),a
        ld (DUTY2),a
        ld hl,(CH1+C_OUT)
        ld bc,(CH2+C_OUT)
        push hl
        push bc
        exx
        pop bc
        pop de
        exx
        ret

seqch:  dec (ix+C_CNT)
        jp nz,.env
        ld l,(ix+C_PTR)
        ld h,(ix+C_PTR+1)
.fetch: ld a,(hl)
        inc hl
        cp $60
        jr c,.note
        jp z,.rest
        cp $61
        jr z,.setenv
        cp $62
        jr z,.jump
        cp $63
        jp z,.call
        cp $64
        jp z,.ret
        cp $65
        jp z,.drum
        cp $66
        jp z,.mark
        cp $67
        jp z,.hold
        ; $68 end: silence forever
        dec hl
        ld (ix+C_EMODE),2
        ld (ix+C_CNT),255
        jp .store
.jump:  ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .fetch
.setenv:
        ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; *5
        ld de,ENVTAB
        add hl,de
        ld a,(hl)
        ld (ix+C_ENVK),a
        inc hl
        ld a,(hl)
        ld (ix+C_EA),a
        inc hl
        ld a,(hl)
        ld (ix+C_ES),a
        inc hl
        ld a,(hl)
        ld (ix+C_ESTEP),a
        inc hl
        ld a,(hl)
        ld (ix+C_EPER),a
        pop hl
        jp .fetch
.note:  push hl
        ld l,a
        ld h,0
        add hl,hl
        ld de,FREQ
        add hl,de
        ld a,(hl)
        ld (ix+C_INC),a
        inc hl
        ld a,(hl)
        ld (ix+C_INC+1),a
        pop hl
        ld a,(ix+C_EPER)
        ld (ix+C_ETIM),a
        ld a,(ix+C_ENVK)
        or a
        jr nz,.sw
        ld (ix+C_EMODE),0
        ld a,(ix+C_EA)
        ld (ix+C_DUTY),a
        jr .len
.sw:    ld (ix+C_EMODE),1
        ld (ix+C_DUTY),0
.len:   ld a,(hl)
        inc hl
        ld (ix+C_CNT),a
        jr .store
.rest:  ld a,(hl)
        inc hl
        ld (ix+C_CNT),a
        ld (ix+C_EMODE),2
        jr .store
.hold:  ld a,(hl)
        inc hl
        ld (ix+C_CNT),a
.store: ld (ix+C_PTR),l
        ld (ix+C_PTR+1),h
        jp .env2
.call:  ; $63 lo hi count
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push de
        push ix
        pop de
        ld a,(ix+C_SP)
        add a,C_STK
        add a,e
        ld e,a
        jr nc,.c1
        inc d
.c1:    ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        pop hl                  ; target
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        ld a,(ix+C_SP)
        add a,5
        ld (ix+C_SP),a
        jp .fetch
.ret:   push ix
        pop de
        ld a,(ix+C_SP)
        sub 5
        add a,C_STK
        add a,e
        ld e,a
        jr nc,.r1
        inc d
.r1:    inc de
        inc de
        ld a,(de)               ; count
        dec a
        ld (de),a
        jr z,.rdone
        inc de
        ld a,(de)
        ld l,a
        inc de
        ld a,(de)
        ld h,a
        jp .fetch
.rdone: dec de
        ld a,(de)
        ld h,a
        dec de
        ld a,(de)
        ld l,a
        ld a,(ix+C_SP)
        sub 5
        ld (ix+C_SP),a
        jp .fetch
.mark:  ld a,(hl)
        inc hl
        ld (MARK),a
        jp .fetch
.drum:  ld a,(hl)
        inc hl
        push hl
        ld (ix+C_DRT),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,DRUMTAB
        add hl,de
        ld a,(hl)
        ld (ix+C_DRC),a
        inc hl
        ld a,(hl)
        ld (ix+C_DDUTY),a
        inc hl
        ld a,(hl)
        ld (ix+C_DRI),a
        inc hl
        ld a,(hl)
        ld (ix+C_DRI+1),a
        pop hl
        jp .fetch

.env:   ; per-frame envelope
.env2:  ld a,(ix+C_EMODE)
        cp 2
        jr nz,.e1
        xor a
        ld (ix+C_DUTY),a
        jr .out
.e1:    dec (ix+C_ETIM)
        jr nz,.out
        ld b,a
        ld a,(ix+C_EPER)
        ld (ix+C_ETIM),a
        ld a,b
        or a
        jr nz,.swell
        ld a,(ix+C_DUTY)
        sub (ix+C_ESTEP)
        jr c,.flo
        cp (ix+C_ES)
        jr nc,.dset
.flo:   ld a,(ix+C_ES)
.dset:  ld (ix+C_DUTY),a
        jr .out
.swell: ld a,(ix+C_DUTY)
        add a,(ix+C_ESTEP)
        jr c,.top
        cp (ix+C_EA)
        jr c,.dset
.top:   ld a,(ix+C_EA)
        ld (ix+C_DUTY),a
        ld (ix+C_EMODE),0
.out:   ld a,(ix+C_DRC)
        or a
        jr z,.plain
        dec (ix+C_DRC)
        ld a,(ix+C_DRT)
        or a
        jr z,.kick
        cp 3
        jr z,.kick
        ; noise types: random inc
        push hl
        ld hl,(SEQRND)
        add hl,hl
        jr nc,.nr
        ld a,l
        xor $2D
        ld l,a
.nr:    ld (SEQRND),hl
        ld a,(ix+C_DRT)
        cp 1
        ld a,h
        jr nz,.sn
        or $50                  ; hat: very high
        jr .ns
.sn:    and $1F
        or $08                  ; snare/crackle: mid
.ns:    ld (ix+C_OUT+1),a
        ld (ix+C_OUT),l
        pop hl
        ld a,(ix+C_DDUTY)
        ld (ix+C_OD),a
        sub 6
        jr nc,.nd
        xor a
.nd:    ld (ix+C_DDUTY),a
        ret
.kick:  ld e,(ix+C_DRI)
        ld d,(ix+C_DRI+1)
        ld (ix+C_OUT),e
        ld (ix+C_OUT+1),d
        ; d,e -= de>>3
        push hl
        ld h,d
        ld l,e
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        ld (ix+C_DRI),l
        ld (ix+C_DRI+1),h
        pop hl
        ld a,(ix+C_DDUTY)
        ld (ix+C_OD),a
        sub 10
        jr nc,.kd
        xor a
.kd:    ld (ix+C_DDUTY),a
        ret
.plain: ld a,(ix+C_INC)
        ld (ix+C_OUT),a
        ld a,(ix+C_INC+1)
        ld (ix+C_OUT+1),a
        ld a,(ix+C_DUTY)
        ld (ix+C_OD),a
        ret
