# render speaker events at 221.7 kHz (CPU/16), low-pass (speaker-ish), decimate to 44.1 kHz
import sys, numpy as np, wave
from scipy.signal import butter, sosfiltfilt, resample_poly
raw=np.fromfile(sys.argv[1],dtype=np.dtype([('t','<u8'),('lv','i1')]))
cut=float(sys.argv[3]) if len(sys.argv)>3 else 7000
DIV=16; fs=3546894/DIV
n=int(raw['t'][-1]//DIV)+1
lv=np.zeros(n,dtype=np.float32)
idx=(raw['t']//DIV).astype(np.int64)
# step function: value holds from idx[i] to idx[i+1]
vals=raw['lv'].astype(np.float32)
lv[idx]=np.diff(np.concatenate([[0],vals]))
lv=np.cumsum(lv)
lv-=lv.mean()
sos=butter(4,cut,fs=fs,output='sos'); y=sosfiltfilt(sos,lv)
sos2=butter(2,60,btype='high',fs=fs,output='sos'); y=sosfiltfilt(sos2,y)
y=resample_poly(y,44100,int(fs))
y=y/np.max(np.abs(y))*0.8
w=wave.open(sys.argv[2],'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
w.writeframes((y*32767).astype(np.int16).tobytes()); w.close()
f=np.abs(np.fft.rfft(y[44100*2:44100*6])); fr=np.fft.rfftfreq(len(y[44100*2:44100*6]),1/44100)
print('centroid %.0f Hz'%((f*fr).sum()/f.sum()))
