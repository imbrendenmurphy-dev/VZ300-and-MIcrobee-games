import sys
b=open(sys.argv[1],'rb').read()
name=sys.argv[3].encode()[:16].ljust(17,b'\0')
hdr=b'VZF0'+name+bytes([0xF1])+(0x8000).to_bytes(2,'little')
open(sys.argv[2],'wb').write(hdr+b)
print('VZ size',len(hdr+b),'code bytes',len(b),'end $%04x'%(0x8000+len(b)))
