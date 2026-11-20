"""Make the VZ-ED 0.1 release folder and zip."""
import os, shutil, zipfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = '/tmp/claude-0/-home-claude/adf4e5cf-05f8-5588-870b-3eb47f98e014/scratchpad/'
D = os.path.join(ROOT, 'dist', 'VZ-ED-0.1')
shutil.rmtree(os.path.join(ROOT, 'dist'), ignore_errors=True)
os.makedirs(os.path.join(D, 'SD')); os.makedirs(os.path.join(D, 'screenshots'))
for f in ('VZED.VZ', 'PLAYTXT.VZ'): shutil.copy(os.path.join(ROOT, 'out', f), os.path.join(D, 'SD', f))
shutil.copy(os.path.join(ROOT, 'README.md'), D)
shots = {'s_text0': '1-text-capitals-inverse', 's_text1': '2-text-lowercase-inverse', 's_gfx': '3-graphics',
         's_gfx_ovr': '4-graphics-overtype', 's_list_text': '5-open-file-list', 's_gfx_list': '6-save-changes-prompt',
         's_gfx_help1': '7-help', 's_gfx_saveas': '8-save-as', 'p1': '9-opened-from-vz-deck'}
for k, v in shots.items():
    if os.path.exists(S + k + '.png'): shutil.copy(S + k + '.png', os.path.join(D, 'screenshots', v + '.png'))
src = os.path.join(D, 'source'); os.makedirs(os.path.join(src, 'src')); os.makedirs(os.path.join(src, 'tools'))
for f in ('vzed.asm', 'files.asm', 'ui.asm', 'gen.py', 'build.py'): shutil.copy(os.path.join(ROOT, 'src', f), os.path.join(src, 'src', f))
for f in os.listdir(os.path.join(ROOT, 'tools')):
    if f.endswith('.py') and f != 'package.py': shutil.copy(os.path.join(ROOT, 'tools', f), os.path.join(src, 'tools', f))
z = os.path.join(ROOT, 'dist', 'VZ-ED-0.1.zip')
with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
    for base, _, files in os.walk(D):
        for f in files:
            p = os.path.join(base, f); zf.write(p, os.path.relpath(p, os.path.dirname(D)))
print(z, os.path.getsize(z))
