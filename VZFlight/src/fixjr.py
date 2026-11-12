"""repeatedly build; on 'relative jump out of range', turn that jr into jp in the right source file"""
import re, subprocess, sys
files = ['flight.asm', 'front.asm', 'engine.asm']
for it in range(40):
    r = subprocess.run([sys.executable, 'build.py'], capture_output=True, text=True)
    m = re.search(r'fs_pp\.asm:(\d+): relative jump out of range', r.stderr)
    if not m:
        print(r.stdout[-400:], r.stderr[-600:])
        break
    ln = int(m.group(1))
    pp = open('fs_pp.asm').read().split('\n')
    # find the nearest preceding global label in fs_pp to locate the line in a source file
    target = pp[ln - 1]
    k = ln - 1
    while k > 0 and not re.match(r'^[a-z_]\w*:', pp[k]):
        k -= 1
    glab = pp[k].split(':')[0]
    done = False
    for f in files:
        src = open(f).read().split('\n')
        for i, l in enumerate(src):
            if re.match(r'^%s:' % re.escape(glab), l):
                # count occurrences of target text from the label to the same offset
                off = ln - 1 - k
                if src[i + off] == target:
                    src[i + off] = target.replace('jr ', 'jp ', 1)
                    open(f, 'w').write('\n'.join(src))
                    print('fixed', f, i + off + 1, target.strip())
                    done = True
                break
        if done:
            break
    if not done:
        print('could not locate', glab, target)
        break
