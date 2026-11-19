"""The high-score record (CRYPT.HI, 128 bytes), as src/disk.asm keeps it:
0 "CRYPTHI1"  8 furthest crypt reached  9 spare  10 eight entries of
(name 8, score 3 BCD in tens of points, crypt 1)  127 checksum."""
DEFAULT = [('MORT', 3000, 8), ('BPM', 2500, 7), ('IGOR', 2000, 6), ('VLAD', 1500, 5),
           ('ELSA', 1200, 4), ('BELA', 900, 3), ('BORIS', 600, 2), ('BAT', 300, 1)]


def bcd3(points):
    s = '%06d' % (points // 10)
    return bytes(int(s[i:i + 2], 16) for i in (0, 2, 4))


def checksum(rec):
    a = 0
    for b in rec[:127]:
        a = (a + b) & 255
        a = ((a << 1) | (a >> 7)) & 255
    return a


def default_record(table=DEFAULT, furthest=0):
    r = bytearray(128)
    r[0:8] = b'CRYPTHI1'
    r[8] = furthest
    for i, (n, s, c) in enumerate(table):
        o = 10 + i * 12
        r[o:o + 8] = n.ljust(8).encode()
        r[o + 8:o + 11] = bcd3(s)
        r[o + 11] = c
    r[127] = checksum(r)
    return bytes(r)


def parse(rec):
    out = []
    for i in range(8):
        o = 10 + i * 12
        out.append((rec[o:o + 8].decode('ascii', 'replace').strip(), int(rec[o + 8:o + 11].hex()) * 10, rec[o + 11]))
    return dict(valid=rec[:8] == b'CRYPTHI1' and checksum(rec) == rec[127], furthest=rec[8], table=out)
