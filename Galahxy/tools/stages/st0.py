"""pack 0: the front end (title backdrop = a stretch of PARTY PLANET, the cast portraits, the logo)"""
import sprites, scenery, sound
ASM = 'fe0.asm'
PAL = 0
SPR = sprites.S
ORDER = sprites.STAGE0
TUNES = {'title': sound.TUNES['title']}
def sky(): return scenery.skyline()
def ground():
    g = scenery.ground()['intro']
    return {'title': [row[:480] for row in g]}
