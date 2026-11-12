import collections, sys
L=[l.split() for l in open(sys.argv[1] if len(sys.argv)>1 else 'build/tm.txt')]
fr=[int(l[0]) for l in L]
d=collections.Counter(b-a for a,b in zip(fr,fr[1:]) if b-a<10)
n=sum(d.values()); print('fields/frame:', ', '.join('%d:%.0f%%'%(k,100*v/n) for k,v in sorted(d.items())))
