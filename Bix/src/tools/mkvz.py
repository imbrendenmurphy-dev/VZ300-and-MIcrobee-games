import sys
data=open(sys.argv[1],'rb').read()
name=sys.argv[3].encode()[:16]
hdr=b'VZF0'+name+b'\0'*(17-len(name))+bytes([0xF1])+bytes([0x00,0x80])
open(sys.argv[2],'wb').write(hdr+data)
print(len(hdr+data),'bytes')
