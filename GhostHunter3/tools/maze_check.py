import sys
MZ = {
"A": ["###########","#o........#","#.##.####.#","#..........","#.##.#.##--","T....#.#GGG","#.##.#.####","#....#....P","#.##.####.#","#o........#","###########"],
"B": ["###########","#o....#....","#.###.#.##.","#..........","##.##.###--","T......#GGG","#.##.#.####","#.#..#....P","#.#.###.##.","#o.........","###########"],
"C": ["###########","#X...#...o.","#.##.#.#.#.","#.#........","#.#.##.##--","T...#..#GGG","#.#.#.#####","#.#.......P","#.##.#.##.#","#o...#...X#","###########"],
"D": ["###########","#o........#","#.#.##.##.#","#.#........","#...##.##--","##.#...#GGG","#..#.#.####","#.#..#....P","#.#.##.##.#","#o.......o.","###########"],
"E": ["###########","#o..#.....#","#.#.#.###.#","#..........","#.#.#.###--","T.#.#.##GGG","#.....#####","##.#......P","#..#.#.####","#o...#.....","###########"],
"F": ["###########","#....X#o...","#.###.#.##.","#.#........","#.#.##.##--","T...#..#GGG","###.#.#####","#......#..P","#.####.#.#.","#o...X.....","###########"],
}
def full(h): return [list(r[:10]+r[10]+r[9::-1]) for r in h]
def check(name,g):
    H=11;W=21
    path=lambda c:c not in "#-G"
    st=None
    for y in range(H):
        for x in range(W):
            if g[y][x]=='P': st=(x,y)
    seen={st};s=[st]
    while s:
        x,y=s.pop()
        for dx,dy in((1,0),(-1,0),(0,1),(0,-1)):
            nx,ny=(x+dx)%W,y+dy
            if 0<=ny<H and path(g[ny][nx]) and (nx,ny) not in seen: seen.add((nx,ny));s.append((nx,ny))
    allp={(x,y) for y in range(H) for x in range(W) if path(g[y][x])}
    dead=[];junc=0
    for (x,y) in allp:
        n=sum(1 for dx,dy in((1,0),(-1,0),(0,1),(0,-1)) if 0<=y+dy<H and path(g[y+dy][(x+dx)%W]))
        if n<2: dead.append((x,y))
        if n>=3: junc+=1
    pel=sum(1 for y in range(H) for x in range(W) if g[y][x] in '.o')
    # 2x2 open blocks (bad)
    blocks=[(x,y) for y in range(H-1) for x in range(W-1) if all(path(g[y+a][x+b]) for a in(0,1) for b in(0,1))]
    print(name,"unreach",sorted(allp-seen),"dead",sorted(dead),"junctions",junc,"pellets",pel,"open2x2",blocks)
    for r in g: print("   ","".join(r))
if __name__=="__main__":
    for k,v in MZ.items(): check(k,full(v))
