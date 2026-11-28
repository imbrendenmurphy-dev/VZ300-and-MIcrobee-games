"""Instruction-level checks for native keyboard and joystick translation."""
import smoke
from verify_port import call

p=smoke.machine()
smoke.boot(p)
S=smoke.S
for name,mask in [('Q',8),('A',4),('O',1),('P',2),('UP',8),
                  ('DOWN',4),('LEFT',1),('RIGHT',2),('SPACE',16)]:
    p.keys={smoke.ppmodel.KEY[name]}
    call(p,'read_controls')
    assert p.m.a==mask,(name,p.m.a)
p.keys=set()
for bit,mask in [(0,8),(1,4),(2,1),(3,2),(7,16)]:
    p.joy=255^(1<<bit)
    call(p,'read_controls')
    assert p.m.a==mask,(bit,p.m.a)
p.joy=255
for digit in range(1,9):
    p.keys={smoke.ppmodel.KEY[str(digit)]}
    call(p,'mb_scan')
    call(p,'skill_keys')
    assert p.peek(S['v_sel'])==digit+1
p.keys=set()
print('PASS: QAOP, arrows, Space, 8 direct skill keys, joystick directions/fire')
