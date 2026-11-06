#!/usr/bin/env python3
"""tiny Z80 disassembler (study tool for the original DUEL code)
usage: dis.py file.vz [start end]"""
import sys
R = ['B','C','D','E','H','L','(HL)','A']
RP = ['BC','DE','HL','SP']; RP2 = ['BC','DE','HL','AF']
CC = ['NZ','Z','NC','C','PO','PE','P','M']
ALU = ['ADD A,','ADC A,','SUB ','SBC A,','AND ','XOR ','OR ','CP ']
ROT = ['RLC','RRC','RL','RR','SLA','SRA','SLL','SRL']

def dis(m, pc):
    b = lambda o: m.get(pc+o, 0)
    w = lambda o: b(o) | b(o+1) << 8
    op = b(0); x, y, z = op >> 6, (op >> 3) & 7, op & 7; p, q = y >> 1, y & 1
    def idx(prefix, hl):
        # handle DD/FD prefixed
        op2 = b(1); x2, y2, z2 = op2 >> 6, (op2 >> 3) & 7, op2 & 7
        d = b(2); d = d - 256 if d > 127 else d
        ixd = '(%s%+d)' % (hl, d)
        if op2 == 0xCB:
            o3 = b(3); d = b(2); d = d - 256 if d > 127 else d; ixd = '(%s%+d)' % (hl, d)
            xx, yy = o3 >> 6, (o3 >> 3) & 7
            if xx == 0: return 4, '%s %s' % (ROT[yy], ixd)
            return 4, '%s %d,%s' % (['', 'BIT', 'RES', 'SET'][xx], yy, ixd)
        if op2 == 0x21: return 4, 'LD %s,$%04X' % (hl, b(2) | b(3) << 8)
        if op2 == 0x22: return 4, 'LD ($%04X),%s' % (b(2) | b(3) << 8, hl)
        if op2 == 0x2A: return 4, 'LD %s,($%04X)' % (hl, b(2) | b(3) << 8)
        if op2 == 0x23: return 2, 'INC ' + hl
        if op2 == 0x2B: return 2, 'DEC ' + hl
        if op2 == 0x36: return 4, 'LD %s,$%02X' % (ixd, b(3))
        if op2 == 0x34: return 3, 'INC ' + ixd
        if op2 == 0x35: return 3, 'DEC ' + ixd
        if op2 == 0xE1: return 2, 'POP ' + hl
        if op2 == 0xE5: return 2, 'PUSH ' + hl
        if op2 == 0xE9: return 2, 'JP (%s)' % hl
        if op2 == 0xF9: return 2, 'LD SP,' + hl
        if op2 == 0xE3: return 2, 'EX (SP),' + hl
        if x2 == 0 and z2 == 1 and op2 & 8: return 2, 'ADD %s,%s' % (hl, ['BC','DE',hl,'SP'][y2 >> 1])
        if x2 == 1 and (z2 == 6) != (y2 == 6):
            if z2 == 6: return 3, 'LD %s,%s' % (R[y2], ixd)
            return 3, 'LD %s,%s' % (ixd, R[z2])
        if x2 == 2 and z2 == 6: return 3, ALU[y2] + ixd
        return 1, 'DB $%02X' % op
    if op == 0xDD: return idx('DD', 'IX')
    if op == 0xFD: return idx('FD', 'IY')
    if op == 0xCB:
        o = b(1); xx, yy, zz = o >> 6, (o >> 3) & 7, o & 7
        if xx == 0: return 2, '%s %s' % (ROT[yy], R[zz])
        return 2, '%s %d,%s' % (['', 'BIT', 'RES', 'SET'][xx], yy, R[zz])
    if op == 0xED:
        o = b(1); xx, yy, zz = o >> 6, (o >> 3) & 7, o & 7
        tbl = {0xB0:'LDIR',0xB8:'LDDR',0xA0:'LDI',0xA8:'LDD',0xB1:'CPIR',0x44:'NEG',0x4D:'RETI',0x45:'RETN',
               0x56:'IM 1',0x5E:'IM 2',0x46:'IM 0',0x47:'LD I,A',0x57:'LD A,I',0x6F:'RLD',0x67:'RRD',0xB3:'OTIR',0xA3:'OUTI'}
        if o in tbl: return 2, tbl[o]
        if xx == 1:
            if zz == 3: return 4, ('LD ($%04X),%s' if not yy & 1 else 'LD %s,($%04X)') % (((w(2), RP[yy >> 1]) if not yy & 1 else (RP[yy >> 1], w(2))))
            if zz == 2: return 2, ('SBC HL,' if not yy & 1 else 'ADC HL,') + RP[yy >> 1]
            if zz == 0: return 2, 'IN %s,(C)' % R[yy]
            if zz == 1: return 2, 'OUT (C),%s' % R[yy]
        return 2, 'DB $ED,$%02X' % o
    if x == 0:
        if z == 0:
            if y == 0: return 1, 'NOP'
            if y == 1: return 1, "EX AF,AF'"
            d = b(1); d = d - 256 if d > 127 else d; t = (pc + 2 + d) & 0xffff
            if y == 2: return 2, 'DJNZ $%04X' % t
            if y == 3: return 2, 'JR $%04X' % t
            return 2, 'JR %s,$%04X' % (CC[y - 4], t)
        if z == 1: return (3, 'LD %s,$%04X' % (RP[p], w(1))) if q == 0 else (1, 'ADD HL,' + RP[p])
        if z == 2:
            return [(1, 'LD (BC),A'), (1, 'LD A,(BC)'), (1, 'LD (DE),A'), (1, 'LD A,(DE)'),
                    (3, 'LD ($%04X),HL' % w(1)), (3, 'LD HL,($%04X)' % w(1)), (3, 'LD ($%04X),A' % w(1)), (3, 'LD A,($%04X)' % w(1))][y]
        if z == 3: return 1, ('INC ' if q == 0 else 'DEC ') + RP[p]
        if z == 4: return 1, 'INC ' + R[y]
        if z == 5: return 1, 'DEC ' + R[y]
        if z == 6: return 2, 'LD %s,$%02X' % (R[y], b(1))
        return 1, ['RLCA', 'RRCA', 'RLA', 'RRA', 'DAA', 'CPL', 'SCF', 'CCF'][y]
    if x == 1:
        if op == 0x76: return 1, 'HALT'
        return 1, 'LD %s,%s' % (R[y], R[z])
    if x == 2: return 1, ALU[y] + R[z]
    if z == 0: return 1, 'RET ' + CC[y]
    if z == 1:
        if q == 0: return 1, 'POP ' + RP2[p]
        return 1, ['RET', 'EXX', 'JP (HL)', 'LD SP,HL'][p]
    if z == 2: return 3, 'JP %s,$%04X' % (CC[y], w(1))
    if z == 3:
        if y == 0: return 3, 'JP $%04X' % w(1)
        if y == 2: return 2, 'OUT ($%02X),A' % b(1)
        if y == 3: return 2, 'IN A,($%02X)' % b(1)
        return 1, ['', '', '', '', 'EX (SP),HL', 'EX DE,HL', 'DI', 'EI'][y]
    if z == 4: return 3, 'CALL %s,$%04X' % (CC[y], w(1))
    if z == 5:
        if q == 0: return 1, 'PUSH ' + RP2[p]
        return 3, 'CALL $%04X' % w(1)
    if z == 6: return 2, ALU[y] + '$%02X' % b(1)
    return 1, 'RST $%02X' % (y * 8)

if __name__ == '__main__':
    d = open(sys.argv[1], 'rb').read()
    start = d[22] | d[23] << 8
    m = {start + i: v for i, v in enumerate(d[24:])}
    a = int(sys.argv[2], 16) if len(sys.argv) > 2 else start
    e = int(sys.argv[3], 16) if len(sys.argv) > 3 else start + len(d) - 24
    while a < e:
        n, s = dis(m, a)
        print('%04X  %-12s %s' % (a, ' '.join('%02X' % m.get(a + i, 0) for i in range(n)), s))
        a += n
