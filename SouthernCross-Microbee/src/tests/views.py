import sys, os
sys.path.insert(0, os.getcwd()); sys.path.insert(0, 'tools'); sys.path.insert(0, 'tests')  # run from src: python3 tests/views.py OUTDIR
from view import view
V = {'runway':(0,20,0,0,0,0),'approach':(0,-1500,100,0,-3,0),'climb':(300,600,124,50,4,5),'turn':(-1141,-2900,244,118,5,25),'low':(457,2946,69,113,8,23),
     'ne500':(0,-1500,500,32,-10,0),'east':(300,2000,300,64,-6,0),'isles':(3000,-2000,600,24,-12,0),'lhouse':(2000,1000,250,10,-4,0),'turtle':(4500,2200,120,64,-3,0)}
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
for det in (2, 3):
    tot = 0
    for n, st in V.items():
        t = view(st, os.path.join(out, '%s_%d.png' % (n, det)), det); tot += t
        print('det %d %-9s %5.2f fps' % (det, n, 3375000 / t))
    print('det %d average %5.2f fps' % (det, 3375000 / (tot / len(V))))
