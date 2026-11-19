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

BASE = 0x4800
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
    (12, BCYAN, "THE OUTBACK BITES BACK."),
    (14, GREY, "NOW ON THE MICROBEE, AT UP TO 16 FRAMES"),
    (15, GREY, "A SECOND. ON A GOOD DAY. FACING A WALL."),
    (18, WHITE, "PRESS SPACE TO START"),
    (20, 9, GREY, "C: SCREEN"),
    (22, DGREY, "T: TEST CARD FOR THE WORRIED"),
    (24, YELLOW, "VIBED BY BPM 2026"),
 ]),
 'P_STORY': page([
    (2, YELLOW, "G'DAY, RANGER!"),
    (3, BROWN, "=============="),
    (6, WHITE, "DROP BEARS HAVE OVERRUN THE OUTBACK."),
    (7, WHITE, "THEY ATE THE STATION'S SCONES, ITS"),
    (8, WHITE, "SHEEP AND, LAST TUESDAY, ITS MANAGER."),
    (11, BCYAN, "THE COUNCIL WANTED A HERO. THE BUDGET"),
    (12, BCYAN, "RAN TO YOU, A BLASTER AND A JAR OF"),
    (13, BCYAN, "VEGEMITE."),
    (16, BGREEN, "NINE AREAS. THE BIG THREE. ONE UTE."),
    (17, BGREEN, "TWENTY OPALS, IF YOU'RE THE TYPE."),
    (20, GREY, "FIGHT YOUR WAY THROUGH AND GET BACK"),
    (21, GREY, "TO YOUR UTE. SHE'LL BE RIGHT. PROBABLY."),
    (24, DGREY, "PRESS SPACE TO START"),
 ]),
 'P_HOW': page([
    (2, YELLOW, "HOW NOT TO GET EATEN (MUCH)"),
    (3, BROWN, "==========================="),
    (5, 3, BCYAN, "ARROWS OR W A S D"), (5, 23, WHITE, "WALK AND TURN"),
    (6, 3, BCYAN, "Z  X"), (6, 23, WHITE, "SIDESTEP"),
    (7, 3, BCYAN, "SPACE"), (7, 23, WHITE, "BLAST"),
    (8, 3, BCYAN, "E OR RETURN"), (8, 23, WHITE, "OPEN, PULL, PROD"),
    (9, 3, BCYAN, "M   P   R   C"), (9, 23, WHITE, "MAP, PAUSE,"),
    (10, 23, WHITE, "WALLS, SCREEN"),
    (12, BGREEN, "WALK INTO THE PINK ARROWS TO MOVE ON."),
    (13, BGREEN, "AREAS REMEMBER EVERYTHING YOU DID."),
    (15, BGREEN, "DOORS ARE PANELS. COLOURED ONES WANT"),
    (16, BGREEN, "THEIR KEY. LEVERS SWING THE GATES."),
    (17, BGREEN, "BEAT THE BIG ONES TO OPEN THEIR GATES."),
    (19, GREY, "SHOOT OIL DRUMS FOR GOODIES. BUMP"),
    (20, GREY, "CRACKED-LOOKING WALLS. EAT VEGEMITE."),
    (21, GREY, "GET KNOCKED DOWN? UP AT THE LAST DOOR."),
    (24, DGREY, "PRESS SPACE TO START"),
 ]),
 'P_LOCALS': page([
    (1, YELLOW, "MEET THE LOCALS"),
    (2, BROWN, "==============="),
    (4, 2, BGREEN, "DROP BEAR"), (4, 14, WHITE, "DROPS ON YOU. ON PURPOSE."),
    (6, 2, BROWN, "FRUIT BAT"), (6, 14, WHITE, "ONLY CAME FOR THE MANGOES."),
    (8, 2, BRED, "CANE TOAD"), (8, 14, WHITE, "NOBODY INVITED HIM."),
    (10, 2, WHITE, "MAGPIE"), (10, 14, WHITE, "SWOOPS. MISSES. SWOOPS."),
    (12, 2, YELLOW, "SNAKE"), (12, 14, WHITE, "SLOW, BUT GRUMPY ABOUT IT."),
    (14, 2, GREY, "HUNTSMAN"), (14, 14, WHITE, "TOTALLY HARMLESS. HONEST."),
    (16, 2, BROWN, "DINGO"), (16, 14, WHITE, "ATE YOUR SANDWICH."),
    (18, 2, BGREEN, "BIG FELLA"), (18, 14, WHITE, "NOT FAT. BIG BONED."),
    (20, 2, BCYAN, "THE BUNYIP"), (20, 14, WHITE, "MOSTLY TEETH. SOME FEELS."),
    (22, 2, WHITE, "THE YOWIE"), (22, 14, WHITE, "BLURRY IN EVERY PHOTO."),
    (24, GREY, "THEY ARE ALL VERY SORRY. NOT REALLY."),
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
    (17, 2, BCYAN, "RRD"),
    (18, 2, BCYAN, "RLD"),
    (19, 2, BCYAN, "RAM BLOCKS, LOW HALF"),
    (20, 2, BCYAN, "RAM BLOCKS, HIGH HALF"),
    (21, 2, BCYAN, "VIDEO WRITE, HIGH BLOCK"),
    (23, 2, GREY, "A PHOTO OF THIS HELPS IF ANY SAY NO."),
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


# DROPBEAR 3D's title tune (from the VZ300 version): in beats of 0.5 s
def _db_voices():
    vb, vm, vt = [], [], []
    for bar in range(20):                      # heartbeat: dum-dum ... dum-dum
        t = bar * 2
        vb += [(t, .25, 'A1'), (t + .5, .25, 'A1')]
    for k in range(8):
        vb.append((40 + k * .5, .25, 'A1' if k % 2 == 0 else 'A#1'))
    for k, n in enumerate(['A2', 'A#2', 'A2', 'G#2']):
        vm.append((8 + k * 4, 3.5, n))
    for k, n in enumerate(['C3', 'C#3', 'C3', 'B2']):
        vm.append((24 + k * 4, 3.5, n))
    for k, n in enumerate(['E3', 'F3', 'E3', 'D#3', 'A3', 'G#3', 'G3', 'F#3']):
        vt.append((24 + k * 2, 1.75, n))
    vm.append((40, 3.8, 'E3'))
    vt.append((40, 3.8, 'A#3'))                 # the stinger: a tritone
    vt += [(45, .55, 'A#2'), (45.7, .55, 'A2'), (46.4, 1.6, 'G#2')]   # and a sad trombone
    vb.append((46.4, 1.6, 'E2'))
    return vb, vm, vt


def tune():
    row_s = 9 * 256 / FS                       # seconds per row of the player
    end = 48.5
    rows = bytearray()
    prev = [None, None, None]

    def at(v, t):
        for t0, d, n in v:
            if t0 <= t < t0 + d:
                return (t0, n)
        return None
    for r in range(int(end * 0.5 / row_s) + 1):
        t = r * row_s / 0.5
        for i, v in enumerate(_db_voices()):
            cur = at(v, t)
            if cur == prev[i]:
                rows.append(0)
            elif cur is None:
                rows.append(1)
            else:
                rows.append(note(cur[1]) + (12 if i == 2 else 0))
            prev[i] = cur
    rows += bytes([1, 1, 1])
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
    print('front end: %d bytes (%d pages, tune %d rows)' % (len(blob), len(PAGES), (len(tune()) - 1) // 3))


if __name__ == '__main__':
    build(Path(sys.argv[1] if len(sys.argv) > 1 else 'build'))
