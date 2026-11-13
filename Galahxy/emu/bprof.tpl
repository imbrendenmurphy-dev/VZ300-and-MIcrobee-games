vz build/sd/GALAHXY.VZ
tmark $tmark build/tmb.txt
frames 1000
poke $trainer 1
poke $demo_t+1 60
frames 4000
poke $demo_t+1 60
frames 4000
poke $demo_t+1 60
prof 1
frames 2000
profsave build/prof.txt
screen build/shots/bp.ppm
