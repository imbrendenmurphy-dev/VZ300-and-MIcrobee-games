import sys, pickle, numpy as np
sys.path.insert(0,'/home/claude/ubtype/tools')
import mbee
from PIL import Image
FR=pickle.load(open('out/frames.pkl','rb')); FR.update(pickle.load(open('out/frames_boss.pkl','rb')))
order=[('title',40),('hof',18),('howto',18),('powerups',18),('intro',18),('s0',30),('b0',30),('s1',30),('s3',30),('b2',30),('s4',30),('b4',30),('s6',28),('mono5',28),('b7',34)]
frames=[f for k,n in order for f in FR[k][:n]]
pal=list(mbee.PALETTE)+[(255,176,0)]
flat=[c for rgb in pal for c in rgb]; flat+= [0]*(768-len(flat))
P=Image.new('P',(1,1)); P.putpalette(flat)
ims=[Image.fromarray(f).quantize(palette=P,dither=Image.Dither.NONE) for f in frames]
ims[0].save(sys.argv[1],save_all=True,append_images=ims[1:],duration=80,loop=0,optimize=False,disposal=1)
print(len(ims),'frames', len(ims)*0.08,'s')
# an MP4 too
import subprocess, os
os.makedirs('mp4f',exist_ok=True)
for i,f in enumerate(frames): Image.fromarray(f).resize((1024,768),Image.NEAREST).save('mp4f/%04d.png'%i)
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate','12.5','-i','mp4f/%04d.png','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p',sys.argv[2]],check=True)
