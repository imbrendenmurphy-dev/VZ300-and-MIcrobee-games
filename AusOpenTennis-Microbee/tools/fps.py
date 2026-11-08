import run, sys
pp=run.boot(); S=pp.S
pp.poke(S['boot_venue'], int(sys.argv[1]) if len(sys.argv)>1 else 3)
pp.poke(S['boot_test'],1); pp.run_frames(150); pp.poke(S['autoplay'],1)
pp.run_frames(100)
if len(sys.argv)>2: pp.poke(S['brd_on'],0); pp.poke(S['cl_on'],0)
def fc(): return pp.peek(S['framecount'])|pp.peek(S['framecount']+1)<<8
a=fc(); pp.run_frames(1500); b=fc()
print('venue', sys.argv[1:] , 'fps %.2f' % ((b-a)/30))
pp.png('/home/claude/aot/shots/fps_%s.png' % (sys.argv[1] if len(sys.argv)>1 else 3),2)
