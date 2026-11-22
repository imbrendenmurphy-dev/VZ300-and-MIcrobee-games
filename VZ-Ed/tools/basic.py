"""VZ BASIC V2.1 tokens: a Python model of the ROM's tokeniser (CRUNCH) and of LIST.

The keyword list is the ROM's table at $1650 (token = $80 + index); None = a
token the VZ doesn't use.  Checked against lines typed into the real ROM (vzemu):
    py basic.py      runs those checks
VZ-ED's ovl_vzopen.asm (LIST) and ovl_bsave.asm (CRUNCH) follow the same rules:
  * one space after the line number is dropped; the rest of the line is kept as typed
  * at each place outside quotes / REM / DATA the first keyword in table order
    that matches is used (so TOTAL = TO + TAL, FORMAT = FOR + MAT); ? = PRINT
  * ELSE and ' get a ':' in front (':' + $95, ':' + REM + $FB), even after a ':'
  * after REM (and ') the rest of the line is kept; after DATA up to the next ':'
  * VZ-ED also matches keywords in either case and makes other letters outside
    quotes / REM / DATA capitals (the VZ only knows capitals there)
  * LIST: a ':' straight before ELSE or REM' isn't shown
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src'))
from gen import BASIC_KW as KW
T_DATA, T_REM, T_ELSE, T_PRINT, T_APOS = 0x88, 0x93, 0x95, 0xB2, 0xFB

def crunch_body(s, fold=True):
    """the text after the line number (and its one space) -> token bytes"""
    out = bytearray(); i = 0; n = len(s); mode = None     # None, 'q' quote, 'r' REM rest, 'd' DATA
    while i < n:
        c = s[i]
        if mode == 'r': out.append(ord(c)); i += 1; continue
        if mode == 'q':
            out.append(ord(c)); i += 1
            if c == '"': mode = None
            continue
        if c == '"':
            out.append(34); i += 1; mode = 'q'; continue
        if mode == 'd':
            out.append(ord(c)); i += 1
            if c == ':': mode = None
            continue
        if c == '?': out.append(T_PRINT); i += 1; continue
        if c == "'":
            out += bytes([0x3A, T_REM, T_APOS]); i += 1; mode = 'r'; continue
        hit = None
        for k, w in enumerate(KW):
            if w is None or w == "'": continue
            t = s[i:i + len(w)]
            if (t.upper() if fold else t) == w: hit = k; break
        if hit is not None:
            tok = 0x80 + hit
            if tok == T_ELSE: out.append(0x3A)
            out.append(tok); i += len(KW[hit])
            if tok == T_REM: mode = 'r'
            elif tok == T_DATA: mode = 'd'
            continue
        out.append(ord(c.upper()) if fold and 'a' <= c <= 'z' else ord(c)); i += 1
    return bytes(out)

def list_body(b):
    """token bytes -> the text LIST shows"""
    out = []; i = 0; n = len(b); mode = None
    while i < n:
        x = b[i]
        if mode == 'r': out.append(chr(x)); i += 1; continue
        if mode == 'q':
            out.append(chr(x)); i += 1
            if x == 34: mode = None
            continue
        if x == 34: out.append('"'); i += 1; mode = 'q'; continue
        if mode == 'd':
            out.append(chr(x)); i += 1
            if x == 0x3A: mode = None
            continue
        if x == 0x3A and i + 1 < n and (b[i + 1] == T_ELSE or (b[i + 1] == T_REM and i + 2 < n and b[i + 2] == T_APOS)):
            i += 1; continue
        if x == T_REM and i + 1 < n and b[i + 1] == T_APOS:
            out.append("'"); i += 2; mode = 'r'; continue
        if x >= 0x80 and x - 0x80 < len(KW) and KW[x - 0x80] is not None:
            out.append(KW[x - 0x80]); i += 1
            if x == T_REM: mode = 'r'
            elif x == T_DATA: mode = 'd'
            continue
        out.append(chr(x)); i += 1
    return ''.join(out)

def program_lines(data, start=0x7AE9):
    """program bytes (as at start) -> [(line number, token bytes)], bytes after the end marker"""
    p = 0; lines = []
    while True:
        nxt = data[p] | data[p + 1] << 8
        if nxt == 0: return lines, data[p + 2:]
        ln = data[p + 2] | data[p + 3] << 8; e = data.index(0, p + 4)
        assert nxt - start == e + 1, 'line %d: link %04X' % (ln, nxt)
        lines.append((ln, data[p + 4:e])); p = e + 1

def detokenise(data, start=0x7AE9):
    lines, rest = program_lines(data, start)
    return ''.join('%d %s\n' % (ln, list_body(b)) for ln, b in lines), rest

def tokenise(text, start=0x7AE9):
    """text (one BASIC line per text line) -> program bytes, or raises ValueError((line index, why))"""
    out = bytearray(); last = -1
    for k, line in enumerate(text.split('\n')):
        if not line.strip(' '): continue
        i = 0
        while i < len(line) and line[i] == ' ': i += 1
        j = i
        while j < len(line) and line[j].isdigit(): j += 1
        if j == i: raise ValueError((k, 'NO LINE NO.'))
        ln = int(line[i:j])
        if ln > 65529 or ln <= last: raise ValueError((k, 'LINE ORDER' if ln <= last else 'NO LINE NO.'))
        last = ln
        if j < len(line) and line[j] == ' ': j += 1
        body = crunch_body(line[j:])
        if len(body) > 250: raise ValueError((k, 'LONG LINE'))
        nxt = start + len(out) + 4 + len(body) + 1
        out += bytes([nxt & 255, nxt >> 8, ln & 255, ln >> 8]) + body + b'\0'
    return bytes(out) + b'\0\0'

def vzfile(name17, prog, start=0x7AE9):
    return b'VZF0' + name17 + b'\xf0' + bytes([start & 255, start >> 8]) + prog

if __name__ == '__main__':
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    bad = 0
    for txt, prog in (('lines1.txt', 'rom1.bin'), ('lines2.txt', 'rom2.bin')):
        d = os.path.join(here, 'basicrom')          # lines typed into the real ROM, and what it made
        typed = [l for l in open(os.path.join(d, txt)).read().splitlines() if l.strip()]
        rom, _ = program_lines(open(os.path.join(d, prog), 'rb').read())
        for line, (ln, b) in zip(typed, rom):
            num, _, rest = line.partition(' ')
            mine = crunch_body(rest)
            ok = mine == b and int(num) == ln
            if not ok: bad += 1; print('CRUNCH', line, '\n  rom ', b, '\n  mine', mine)
        print(txt, len(rom), 'lines checked against the ROM')
    print('all match' if not bad else '%d differ' % bad)
