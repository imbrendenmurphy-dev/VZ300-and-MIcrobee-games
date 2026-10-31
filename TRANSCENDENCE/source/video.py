import numpy as np, subprocess, sys
PAL=np.array([(0,220,0),(255,255,80),(40,40,235),(215,0,0),(235,235,215),(0,210,190),(215,0,215),(255,130,0)],np.uint8)
data=open('frames.bin','rb').read(); n=len(data)//2049
# precompute mode0 quadrant masks
qy=np.array([0]*6+[1]*6); qx=np.array([0]*4+[1]*4)
bitmap=np.zeros((12,8),np.uint8)
for y in range(12):
    for x in range(8):
        bitmap[y,x]=8>>(qy[y]*2+qx[x])
def img(latch, vr):
    out=np.zeros((240,320,3),np.uint8)
    if latch&8:
        css=(latch>>4)&1; pal=PAL[4*css:4*css+4]
        a=np.frombuffer(vr,np.uint8).reshape(64,32)
        px=np.zeros((64,128),np.uint8)
        for k in range(4): px[:,k::4]=(a>>(6-2*k))&3
        im=np.repeat(np.repeat(pal[px],3,0),2,1); out[:]=pal[0]
    else:
        a=np.frombuffer(vr[:512],np.uint8).reshape(16,32)
        col=PAL[(a>>4)&7]; sg=(a&0x80)!=0; bits=a&15
        big=np.repeat(np.repeat(bits,12,0),8,1)
        bm=np.tile(bitmap,(16,32))
        on=(big&bm)!=0
        sgb=np.repeat(np.repeat(sg,12,0),8,1)
        colb=np.repeat(np.repeat(col,12,0),8,1)
        im=np.zeros((192,256,3),np.uint8)
        m=on&sgb; im[m]=colb[m]
        im[~sgb]=(0,70,0)
    out[24:216,32:288]=im
    return out
p=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','320x240','-r','50','-i','-',
   '-i','out.wav','-vf','scale=640:480:flags=neighbor','-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p',
   '-c:a','aac','-b:a','128k','-shortest',sys.argv[1]],stdin=subprocess.PIPE)
for f in range(n):
    o=f*2049; p.stdin.write(img(data[o],data[o+1:o+2049]).tobytes())
p.stdin.close(); p.wait()
