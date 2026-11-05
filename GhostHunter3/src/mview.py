import sys, mazes
def show(n):
    g = mazes.build(n); H=len(g); W=len(g[0])
    PATH=mazes.PATH
    def path(x,y): return 0<=y<H and g[y][x%W] in PATH
    mark={}
    for y in range(H):
        for x in range(W):
            if path(x,y):
                k=sum(1 for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)) if path((x+dx)%W,y+dy))
                if k<2: mark[(x,y)]='D'
    for y in range(H-1):
        for x in range(W-1):
            if all(path(a,b) for a,b in ((x,y),(x+1,y),(x,y+1),(x+1,y+1))): mark[(x,y)]='S'
    print(n)
    print("    "+"".join(str(x%10) for x in range(W)))
    for y in range(H):
        print("%2d  "%y+"".join(mark.get((x,y),g[y][x]) for x in range(W)))
for n in sys.argv[1:]: show(n)
