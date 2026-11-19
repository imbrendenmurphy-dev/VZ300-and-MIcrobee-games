import sys
data=open(sys.argv[1],'rb').read(); start=int(sys.argv[3],16)
name=sys.argv[4].encode()[:16].ljust(17,b'\0')
open(sys.argv[2],'wb').write(b'VZF0'+name+bytes([0xF1,start&255,start>>8])+data)
print('%s: %d bytes, load %04X-%04X'%(sys.argv[2],len(data),start,start+len(data)-1))
