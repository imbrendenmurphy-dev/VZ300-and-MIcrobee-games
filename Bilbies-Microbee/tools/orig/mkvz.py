import sys
def mkvz(binfile, out, start, name='FLYSHARK'):
    d=open(binfile,'rb').read()
    hdr=b'VZF0'+name.encode()[:16].ljust(17,b'\0')+bytes([0xF1])+bytes([start&255,start>>8])
    open(out,'wb').write(hdr+d)
if __name__=='__main__':
    mkvz(sys.argv[1],sys.argv[2],int(sys.argv[3],16),sys.argv[4] if len(sys.argv)>4 else 'TEST')
