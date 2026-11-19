"""stage 1: PARTY PLANET (main palette)"""
import sprites, scenery, sound
ASM = 'stage1.asm'
PAL = 0
SPR = sprites.S
ORDER = sprites.STAGE1
TUNES = {k: sound.TUNES[k] for k in ('stage1', 'hoist', 'boss')}
def sky(): return scenery.skyline()
def ground(): return scenery.ground()
