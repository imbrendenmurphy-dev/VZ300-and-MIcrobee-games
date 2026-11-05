import sys
data=open(sys.argv[1],'rb').read(); name=sys.argv[3].encode()[:16]; start=int(sys.argv[4],0)
hdr=b'  \x00\x00'+name+b'\x00'*(17-len(name))+bytes([0xF1,start&255,start>>8])
open(sys.argv[2],'wb').write(hdr+data)
print("VZ: %d bytes, %04X-%04X"%(len(data),start,start+len(data)-1))
