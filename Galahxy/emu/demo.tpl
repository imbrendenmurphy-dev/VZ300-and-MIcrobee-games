vz build/sd/GALAHXY.VZ
tmark $tmark build/tm.txt
watch $stg_phase
watch $tl_hold
watch $demo_on
frames 1000
screen build/shots/d01.ppm
poke $trainer 1
poke $demo_t+1 40
frames 500
screen build/shots/d02.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d03.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d04.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d05.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d06.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d07.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d08.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d09.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d10.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d11.ppm
poke $demo_t+1 40
frames 500
screen build/shots/d12.ppm
regs
