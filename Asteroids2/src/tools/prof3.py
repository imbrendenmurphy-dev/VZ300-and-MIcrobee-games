import sys
FT=70938; lo=int(sys.argv[2]) if len(sys.argv)>2 else 0
copies=[]; 
for l in open(sys.argv[1]):
    f,t,n=l.split()
    if n=='copy_buf' and int(f)>=lo: copies.append(int(f)*FT+int(t))
iv=[(b-a)/FT for a,b in zip(copies,copies[1:])]
print('fields>=%d: frames %d slow %.1f%%  effective fps %.1f'%(lo,len(iv),100*sum(1 for x in iv if x>2.5)/len(iv), 50*len(iv)/sum(iv)))
