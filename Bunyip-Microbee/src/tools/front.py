#!/usr/bin/env python3
"""BUNYIP front end data: goes after the four zones in ZONES.BIN (RAM block 2,
4000h on).  VIBED BY BPM 2026

  * the title logo's cell map (from tools/gen.py)
  * text pages: lines of  row, column, colour, text, 0  ending with FFh
  * the title tune: a table of note steps, then rows of three notes
    (bass, lead, twinkle; 0 = let it ring, 1 = quiet), ending with FFh

Run after gen.py and zones.py:  front.py <build dir>
"""
import sys
from pathlib import Path

BASE = 0x4000
BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)
OK = set(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:-/=!?'+()")


def page(lines):
    """lines: (row, colour, text) centred, or (row, col, colour, text)"""
    out = bytearray()
    for ln in lines:
        if len(ln) == 3:
            row, colour, text = ln
            col = (40 - len(text)) // 2
        else:
            row, col, colour, text = ln
        assert set(text) <= OK, text
        assert col >= 0 and col + len(text) <= 40, text
        out += bytes([row, col, colour]) + text.encode('ascii') + b'\0'
    return bytes(out) + b'\xff'


PAGES = {
 # under the logo (rows 1-10)
 'P_TITLE': page([
    (12, BCYAN, "A FIRST-PERSON SHOCKER FROM DOWN UNDER"),
    (14, GREY, "NOW WITH UP TO 16 FRAMES A SECOND!"),
    (15, DGREY, "(ON A GOOD DAY, FACING A WALL)"),
    (18, WHITE, "PRESS SPACE TO START"),
    (20, 9, GREY, "C: SCREEN"),
    (22, DGREY, "T: TEST CARD FOR THE WORRIED"),
    (24, YELLOW, "VIBED BY BPM 2026"),
 ]),
 'P_STORY': page([
    (2, YELLOW, "THE STORY SO FAR"),
    (3, BROWN, "================"),
    (6, WHITE, "SOMETHING IN THE BILLABONG HAS BEEN"),
    (7, WHITE, "EATING THE SHIRE'S OPALS, ITS SHEEP"),
    (8, WHITE, "AND, LAST TUESDAY, ITS MAYOR."),
    (11, BCYAN, "THE COUNCIL WANTED A HERO. THE BUDGET"),
    (12, BCYAN, "RAN TO YOU, A ZAPPER AND A MEAT PIE."),
    (15, BGREEN, "FOUR ZONES. FOUR GUARDIANS. ONE BUNYIP."),
    (16, BGREEN, "NO TRAINING AT ALL. SHE'LL BE RIGHT."),
    (20, GREY, "FIND THE KEYS. PULL THE LEVERS."),
    (21, GREY, "BEAT EACH GUARDIAN. FIND THE WAY DOWN."),
    (24, DGREY, "PRESS SPACE TO START"),
 ]),
 'P_HOW': page([
    (2, YELLOW, "HOW NOT TO DIE (MUCH)"),
    (3, BROWN, "====================="),
    (5, 3, BCYAN, "ARROWS OR W A S D"), (5, 23, WHITE, "WALK AND TURN"),
    (6, 3, BCYAN, "Z  X"), (6, 23, WHITE, "SIDESTEP"),
    (7, 3, BCYAN, "SPACE"), (7, 23, WHITE, "ZAP"),
    (8, 3, BCYAN, "E OR RETURN"), (8, 23, WHITE, "OPEN, PULL, PROD"),
    (9, 3, BCYAN, "M   P   R   C"), (9, 23, WHITE, "MAP, PAUSE,"),
    (10, 23, WHITE, "WALLS, SCREEN"),
    (13, BGREEN, "DOORS ARE THE WALLS MADE OF PANELS."),
    (14, BGREEN, "WALK UP AND PRESS E. SOME WANT A KEY."),
    (16, BGREEN, "ARROWS MARK THINGS WORTH PRODDING:"),
    (17, BGREEN, "LEVERS SWING THE BARRED GATES."),
    (19, GREY, "SMASH URNS. EAT PIES. SHOOT THE TNT"),
    (20, GREY, "FROM MUCH FURTHER AWAY THAN THAT."),
    (24, DGREY, "PRESS SPACE TO START"),
 ]),
 'P_LOCALS': page([
    (2, YELLOW, "MEET THE LOCALS"),
    (3, BROWN, "==============="),
    (5, 2, BRED, "REDBACK"), (5, 14, WHITE, "BITES. LIVES UNDER SEATS."),
    (7, 2, BROWN, "FLYING FOX"), (7, 14, WHITE, "FLAPS. ALSO BITES."),
    (9, 2, BGREEN, "CANE TOAD"), (9, 14, WHITE, "HOPS. TASTES DREADFUL."),
    (11, 2, GREY, "DROP BEAR"), (11, 14, WHITE, "DOES NOT EXIST. BITES."),
    (13, 2, WHITE, "YOWIE"), (13, 14, WHITE, "BIG, HAIRY, THROWS ROCKS."),
    (15, 2, BCYAN, "MIN MIN"), (15, 14, WHITE, "A LIGHT WITH A GRUDGE."),
    (17, 2, GREEN, "SALTIE"), (17, 14, WHITE, "MOSTLY TEETH."),
    (19, 2, BGREEN, "THE BUNYIP"), (19, 14, WHITE, "THE BOSS. BRING PIES."),
    (22, GREY, "EVERYTHING HERE WANTS TO EAT YOU."),
    (23, GREY, "IT IS NOTHING PERSONAL."),
 ]),
 'P_SKILL': page([
    (3, YELLOW, "HOW BRAVE ARE WE FEELING?"),
    (4, BROWN, "========================="),
    (8, 12, WHITE, "SHE'LL BE RIGHT"),
    (10, 12, WHITE, "HURT ME PLENTY"),
    (12, 12, WHITE, "FLAMIN' NIGHTMARE"),
    (20, GREY, "UP AND DOWN TO CHOOSE"),
    (21, GREY, "SPACE TO REGRET IT"),
 ]),
 'P_SK0': page([(15, BGREEN, "  HALF THE BITES. ALL OF THE SHAME.  ")]),
 'P_SK1': page([(15, BCYAN, "    THE WAY THE BUNYIP INTENDED.     ")]),
 'P_SK2': page([(15, BRED, "   DOUBLE BITES. YOU WERE WARNED.    ")]),
 'P_TEST': page([
    (1, YELLOW, "TEST CARD"),
    (3, 2, WHITE, "WHAT THIS MACHINE READS BACK FROM"),
    (4, 2, WHITE, "ITS VIDEO MEMORY. THE GAME NO LONGER"),
    (5, 2, WHITE, "NEEDS ANY OF IT. WE ARE JUST NOSY."),
    (8, 2, BCYAN, "SCREEN RAM"),
    (10, 2, BCYAN, "SCREEN RAM, PCG BANK ON"),
    (12, 2, BCYAN, "ATTRIBUTE RAM"),
    (14, 2, BCYAN, "COLOUR RAM"),
    (16, 2, BCYAN, "PCG RAM"),
    (19, 2, GREY, "EACH SHOULD SAY 5A A5 OK."),
    (20, 2, GREY, "A PHOTO OF THIS SCREEN HELPS IF NOT."),
    (24, DGREY, "PRESS SPACE TO GO BACK"),
 ]),
}

# ------------------------------------------------------------------ the title tune
# The player's sample loop (src/front.asm mus_row) takes SAMPLE_T T-states.
SAMPLE_T = 187
FS = 3375000 / SAMPLE_T
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def note(name):
    """'D4' -> note number (2 = A1); '-' = 0 (ring on), '.' = 1 (quiet)"""
    if name == '-':
        return 0
    if name == '.':
        return 1
    n, o = name[:-1], int(name[-1])
    semis = NAMES.index(n) + 12 * o - (9 + 12)     # from A1
    assert 0 <= semis < 72, name
    return 2 + semis


STEPS = [0, 0] + [round(55.0 * 2 ** (k / 12) * 65536 / FS) for k in range(72)]

# eight rows to the bar; each bar: (bass, lead, twinkle) as 8 names each
BARS = [
 # D minor: the thing in the water
 ('D2 - - D2 - - D2 -', 'D4 - - - F4 - E4 -', 'D6 A5 F6 A5 D6 A5 F6 A6'),
 ('D2 - - D2 - - D2 -', 'D4 - - - A3 - - -', 'D6 A5 F6 A5 D6 F6 A6 D7'),
 # B flat: it gets worse
 ('A#1 - - A#1 - - A#1 -', 'A#3 - - - D4 - F4 -', 'D6 A#5 F6 A#5 D6 A#5 F6 A#6'),
 ('A#1 - - A#1 - - A#1 -', 'F4 - - - E4 - D4 -', 'F6 D6 A#5 D6 F6 A#6 F6 D6'),
 # C: a ray of hope
 ('C2 - - C2 - - C2 -', 'E4 - - - G4 - E4 -', 'E6 C6 G6 C6 E6 C6 G6 C7'),
 ('C2 - - C2 - - C2 -', 'C4 - - - E4 - - -', 'G6 E6 C6 E6 G6 C7 G6 E6'),
 # A: no, it is definitely worse
 ('A1 - - A1 - - A1 -', 'C#4 - - - E4 - A4 -', 'E6 C#6 A6 C#6 E6 C#6 A6 C#7'),
 ('A1 - - A1 - A1 A1 A1', 'G4 - F4 - E4 - C#4 -', 'A6 G6 E6 C#6 A5 C#6 E6 G6'),
 # and home, with a shiver up the keyboard
 ('D2 - - - - - - -', 'D4 - - - - - - -', 'D5 F5 A5 D6 F6 A6 D7 -'),
 ('- - - - - - - .', '- - - - - - - .', 'A6 - F6 - D6 - - .'),
]


def tune():
    rows = bytearray()
    for bass, lead, tw in BARS:
        b, l, t = bass.split(), lead.split(), tw.split()
        assert len(b) == len(l) == len(t) == 8
        for i in range(8):
            rows += bytes([note(b[i]), note(l[i]), note(t[i])])
    return bytes(rows) + b'\xff'


def build(out):
    zones = bytearray((out / 'ZONES.BIN').read_bytes())[:BASE]
    assert len(zones) == BASE, 'zones.py must run first'
    blob = bytearray()
    sym = {}

    def put(name, data):
        sym[name] = BASE + len(blob)
        blob.extend(data)
    logo = (out / 'logo.map').read_bytes()
    put('F_LOGO', logo)
    for name, data in PAGES.items():
        put(name, data)
    put('F_STEPS', b''.join(v.to_bytes(2, 'little') for v in STEPS))
    put('F_TUNE', tune())
    assert BASE + len(blob) <= 0x8000
    (out / 'ZONES.BIN').write_bytes(zones + blob)
    S = ['; generated by tools/front.py: front end data in RAM block 2']
    for k, v in sym.items():
        S.append('%-10s equ %05Xh' % (k, v))
    (out / 'frontsym.inc').write_text('\n'.join(S) + '\n')
    print('front end: %d bytes (%d pages, tune %d rows)' % (len(blob), len(PAGES), sum(1 for _ in BARS) * 8))


if __name__ == '__main__':
    build(Path(sys.argv[1] if len(sys.argv) > 1 else 'build'))
