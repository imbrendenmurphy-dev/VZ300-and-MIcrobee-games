# Render frames.bin (1 latch byte + 2048 VRAM per field) to PNGs / MP4
import sys, numpy as np
from PIL import Image
PAL=[(0,220,0),(255,255,80),(40,40,235),(215,0,0),(235,235,215),(0,210,190),(215,0,215),(255,130,0)]
def frame_img(latch, vr):
    W,H=256,192
    img=np.zeros((H,W,3),np.uint8)
    gfx=latch&8; css=(latch>>4)&1
    if not gfx:
        for cy in range(16):
            for cx in range(32):
                b=vr[cy*32+cx]
                if b&0x80:
                    col=PAL[(b>>4)&7]
                    for q,(qx,qy) in enumerate([(0,0),(4,0),(0,6),(4,6)]):
                        if b&(8>>q): img[cy*12+qy:cy*12+qy+6, cx*8+qx:cx*8+qx+4]=col
                else:
                    img[cy*12:cy*12+12,cx*8:cx*8+8]=(0,70,0)
                    img[cy*12+3:cy*12+9,cx*8+2:cx*8+6]=(0,200,0)
        border=(0,0,0)
    else:
        pal=PAL[4*css:4*css+4] if True else None
        pal=[PAL[0],PAL[1],PAL[2],PAL[3]] if css==0 else [PAL[4],PAL[5],PAL[6],PAL[7]]
        a=np.frombuffer(bytes(vr),np.uint8).reshape(64,32)
        px=np.zeros((64,128),np.uint8)
        for k in range(4): px[:,k::4]=(a>>(6-2*k))&3
        lut=np.array(pal,np.uint8)
        img=np.repeat(np.repeat(lut[px],3,axis=0),2,axis=1)
        border=pal[0]
    out=np.zeros((240,320,3),np.uint8); out[:]=border; out[24:216,32:288]=img
    return Image.fromarray(out)
if __name__=='__main__':
    fn=sys.argv[1]; data=open(fn,'rb').read(); n=len(data)//2049
    frames=[int(x) for x in sys.argv[2].split(',')]
    for f in frames:
        if f>=n: continue
        o=f*2049; im=frame_img(data[o],data[o+1:o+2049]); im.resize((640,480),Image.NEAREST).save('shot_%05d.png'%f)
