import sys
data=open(sys.argv[1],'rb').read(); name=sys.argv[3].encode()[:16]; start=int(sys.argv[4],16)
hdr=b'VZF0'+name.ljust(17,b'\0')+bytes([0xF1, start&255, start>>8])
open(sys.argv[2],'wb').write(hdr+data)
print('%s: %d bytes, $%04X-$%04X'%(sys.argv[2],len(data),start,start+len(data)-1))
