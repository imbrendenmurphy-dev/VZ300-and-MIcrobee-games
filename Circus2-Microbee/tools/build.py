from pathlib import Path
import subprocess,argparse
import art
from build_disk import build_disk
R=Path(__file__).resolve().parents[1]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--assembler',default='sjasmplus');a=ap.parse_args()
 (R/'build').mkdir(exist_ok=True)
 art.build()
 subprocess.run([a.assembler,'--sym=../build/circus2.sym','--lst=../build/circus2.lst','main.asm'],cwd=R/'src',check=True)
 files={p.name:p.read_bytes() for p in sorted((R/'build').glob('B??.DAT'))}
 files.update({'CIRCUS2.COM':(R/'build/CIRCUS2.COM').read_bytes(),'CCP.SYS':(R/'resources/CCP.SYS').read_bytes(),'README.TXT':b'CIRCUS 2 SPECTACLE - Microbee Premium Plus 1MB, 32K PCG\r\nType CIRCUS2 to play. Z/X or arrows move, SPACE flips.\r\nTitle: S sound, D level, M colour/monochrome, H help, T top clowns.\r\nP pauses; Q at pause returns to title.\r\n\x1a'})
 build_disk((R/'resources/boot_tracks.bin').read_bytes(),files,R/'build/CIRCUS2.DS8')
 print('Built native Microbee program and 819200-byte DS80 CP/M disk')
if __name__=='__main__':main()
