"""Make the VZ-ED 0.7 release folder and zip."""
import os, shutil, zipfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'testout','')
D = os.path.join(ROOT, 'dist', 'VZ-ED-0.7')
shutil.rmtree(os.path.join(ROOT, 'dist'), ignore_errors=True)
os.makedirs(os.path.join(D, 'SD')); os.makedirs(os.path.join(D, 'screenshots'))
for f in ('VZED.VZ', 'PLAYTXT.VZ', 'VZED.OVL'): shutil.copy(os.path.join(ROOT, 'out', f), os.path.join(D, 'SD', f))
shutil.copy(os.path.join(ROOT, 'README.md'), D)
shots = {'s_text0': '1-text-capitals-inverse', 's_text1': '2-text-lowercase-inverse', 's_gfx': '3-graphics',
         's_gfx_ovr': '4-graphics-overtype', 's_list_text': '5-open-file-list', 's_gfx_list': '6-save-changes-prompt',
         's_gfx_help1': '7-help', 's_gfx_saveas': '8-save-as', 'p1': '9-opened-from-vz-deck',
         's_sheet_nowrap_0_moved': '10-sheet-view', 's_sheet_wrap_0': '11-sheet-view-word-wrap',
         's_menu_file': '12-menu-bar', 's_menu_edit_gfx': '13-menu-bar-graphics',
         's_pdf_saved': '14-pdf-saved', 's_print_notready': '15-printer-not-ready',
         's_basic_open': '16-basic-program', 's_hex_vz': '17-hex-viewer',
         's_wordcount': '18-word-count'}
for k, v in shots.items():
    if os.path.exists(S + k + '.png'): shutil.copy(S + k + '.png', os.path.join(D, 'screenshots', v + '.png'))
src = os.path.join(D, 'source'); os.makedirs(os.path.join(src, 'src')); os.makedirs(os.path.join(src, 'tools'))
for f in os.listdir(os.path.join(ROOT, 'src')):
    if f.endswith(('.asm', '.py', '.inc')): shutil.copy(os.path.join(ROOT, 'src', f), os.path.join(src, 'src', f))
for f in os.listdir(os.path.join(ROOT, 'tools')):
    if f.endswith('.py') and f != 'package.py': shutil.copy(os.path.join(ROOT, 'tools', f), os.path.join(src, 'tools', f))
z = os.path.join(ROOT, 'dist', 'VZ-ED-0.7.zip')
with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
    for base, _, files in os.walk(D):
        for f in files:
            p = os.path.join(base, f); zf.write(p, os.path.relpath(p, os.path.dirname(D)))
print(z, os.path.getsize(z))
