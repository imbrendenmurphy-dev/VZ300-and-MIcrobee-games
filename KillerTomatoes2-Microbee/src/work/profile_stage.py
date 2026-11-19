"""Profile one stage's frame work by routine (PC sampled every 200 T-states)."""
import sys
from collections import Counter
from test_plus import *
stage = int(sys.argv[1]) if len(sys.argv) > 1 else 9
b = PlusBee(); b.until('hw_init', limit=40000)
b.call('hw_init'); b.write(sym['seed'], 0xE1); b.write(sym['seed'] + 1, 0xAC)
b.write(sym['trainer'], 1); b.write(sym['diff'], 1); b.write(sym['mono_mode'], 0)
b.write(sym['stage'], stage - 1); b.write(sym['lives'], 4); b.call('setup_stage')
labels = sorted((v, k) for k, v in sym.items() if v < 0x8000 and '.' not in k)
def where(pc):
    if pc >= 0xE000: return 'BANK_COPY'
    name = '?'
    for v, k in labels:
        if v <= pc: name = k
        else: break
    return name
hist = Counter(); frames = 60
def sampled(label):
    b.m.sp = 0xEF00; b.write(0xEF00, 0xFE); b.write(0xEF01, 0xEF); b.m.pc = sym[label]
    b.m.set_breakpoint(0xEFFE)
    while b.m.pc != 0xEFFE:
        b.run(1, 200); hist[(label, where(b.m.pc))] += 1
    b.m.clear_breakpoint(0xEFFE)
for f in range(frames):
    b.write(sym['frame_cnt'], f & 255)
    b.call('bot_input'); b.call('game_logic'); b.call('sound_tick')
    sampled('draw_frame'); sampled('video_upload'); b.call('video_present')
tot = sum(hist.values())
print(f'stage {stage}: ~{tot*200//frames} T-states/frame in draw+upload')
for (top, k), v in hist.most_common(14): print(f'{100*v/tot:5.1f}%  {top:12s} {k}')
b.shot(f'profile-stage-{stage}')
