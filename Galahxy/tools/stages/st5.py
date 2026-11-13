"""stage 5: BACKYARD BLITZ (main palette). Sunday arvo in the burbs - the barbie's alive.
The art is the game's very first stage, kept from the early backyard build."""
import backyard_sprites as _bs, backyard_scenery as _bg
ASM = 'stage5.asm'
PAL = 0
SPR = _bs.S
ORDER = ['SNAG', 'BLOWIE', 'SWOOPER', 'THONG', 'TINNIE', 'SPRINKLER', 'ESKY', 'GNOME', 'HOTSNAG', 'POSSUM',
         'HOIST', 'PEG', 'UNDIES', 'GRILL', 'TONGS']
TUNES = {
    # "Backyard Bop"
    'stage': (2, 7, "A3 . E4 . C#4 E4 . . F#4 . E4 . C#4 . A3 . "
                    "D4 . A4 . F#4 A4 . . B4 . A4 . F#4 . D4 . "
                    "E4 . B4 . G#4 B4 . . E5 . D5 . B4 . G#4 . "
                    "A4 . G#4 . F#4 . E4 . A3 . . . . . . . "),
    'mid':   (2, 6, "E3 . . G3 B3 . E3 . . G3 C4 . E3 . . G3 B3 . A3 . G3 F#3 . . "),
    'boss':  (2, 5, "D3 . D3 . A3 . D3 . F3 . E3 . D3 . C#3 . "
                    "D3 . D3 . A3 . D3 . A#3 . A3 . G3 . A3 . "),
}
def sky(): return _bg.skyline()
def ground(): return _bg.ground()
