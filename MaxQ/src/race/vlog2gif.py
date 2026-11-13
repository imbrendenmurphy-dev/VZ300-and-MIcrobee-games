import sys, subprocess
from PIL import Image
sys.path.insert(0,'.'); sys.path.insert(0,'../tools')
import build_race as B
P0=[(0,224,0),(240,240,64),(32,48,224),(224,40,32)]
P1=[(224,224,192),(64,200,200),(224,64,224),(240,128,32)]
def frame(buf, latch):
    pal = P1 if latch & 16 else P0
    im = Image.new('RGB',(128,64))
    px = im.load()
    for y in range(64):
        for xb in range(32):
            b = buf[y*32+xb]
            for q in range(4):
                px[xb*4+q,y] = pal[(b >> (6-2*q)) & 3]
    return im.resize((512,256), Image.NEAREST)
if __name__ == '__main__':
    B.HALF_INIT = 1
    src,_ = B.source(); asm, org, data, vz = B.assemble(src, 'MAXQ.VZ')
    secs = 14
    subprocess.run([B.EMU, vz, str(70630*50*secs), '--vramlog', 'v.log', '2'], capture_output=True, stdin=subprocess.DEVNULL)
    d = open('v.log','rb').read(); n = len(d)//2049
    frames = [frame(d[i*2049:i*2049+2048], d[i*2049+2048]) for i in range(n)]
    frames = frames[n//4:]          # skip the title screen
    frames[0].save(sys.argv[1], save_all=True, append_images=frames[1:], duration=40, loop=0)
    frames[len(frames)//2].save(sys.argv[2])
    print(n, 'frames')
