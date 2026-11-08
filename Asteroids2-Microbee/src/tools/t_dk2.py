from t_dk import enter, press, km
from harness import *
b,E=enter()
press(b,'Q')
b.key('LEFT'); 
for i in range(30):
    b.run(2); t=ttext(b).split('\n')[14]
    if i%3==0: print(i, t.strip(), km(b,E))
b.keys_up(); b.run(20); print(ttext(b).split('\n')[14].strip())
