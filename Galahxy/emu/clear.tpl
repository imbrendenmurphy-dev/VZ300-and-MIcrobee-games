vz build/sd/GALAHXY.VZ
watch $stg_phase
watch $round
frames 1000
poke $trainer 1
poke $demo_t+1 60
frames 4000
poke $demo_t+1 60
frames 4400
poke $demo_t+1 60
frames 300
poke $boss_hp 3
frames 600
poke $demo_on 0
frames 200
screen build/shots/c1.ppm
frames 150
screen build/shots/c2.ppm
frames 250
screen build/shots/c3.ppm
frames 300
screen build/shots/c4.ppm
frames 300
screen build/shots/c5.ppm
frames 300
screen build/shots/c6.ppm
