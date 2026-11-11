"""Package the checked native-combat milestone, preserving hardware-tested disks."""
from pathlib import Path
import hashlib,json,shutil,zipfile,argparse

ROOT=Path(__file__).resolve().parent.parent

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',default='release/maze-speed-test')
    args=parser.parse_args()
    build=ROOT/'build';release=ROOT/args.output
    assert (ROOT/'archive/hardware-tested-2026-11-09/DRACULA.DS8').stat().st_size==819200
    report=json.loads((build/'validation.json').read_text())
    report['native_validation']=json.loads((build/'native-validation.json').read_text())
    report['frontend_validation']=json.loads((build/'frontend-validation.json').read_text())
    report['combat_validation']=json.loads((build/'combat-validation.json').read_text())
    report['combat_paths_validation']=json.loads((build/'combat-paths-validation.json').read_text())
    report['pcg_validation']=json.loads((build/'native/pcg-validation.json').read_text())
    report['world_validation']=json.loads((build/'world-validation.json').read_text())
    report['world_pcg_validation']=json.loads((build/'world/pcg-validation.json').read_text())
    report['expanded_animation']=json.loads((build/'animation-validation.json').read_text())
    report['live_perspective']=json.loads((build/'pixel-runtime-validation.json').read_text())
    assert report['live_perspective']['exact_live_scene_checks']==288
    report['maze_speed']=json.loads((build/'maze-speed-validation.json').read_text())
    report['decoder_validation']=json.loads((build/'unpack-validation.json').read_text())
    assert report['maze_speed']['pixel_identical_turns']==48
    assert report['maze_speed']['turn_time_reduction_percent']>=50
    assert report['decoder_validation']['exact_z80_decode_checks']==84
    assert report['expanded_animation']['pose_count']==8
    assert report['expanded_animation']['max_cached_transition_frames']<=4
    assert report['expanded_animation']['late_plane_writes']==0
    assert report['world_validation']['scene_checks']==50
    assert report['combat_wins']==report['monochrome_combat_wins']==12
    assert report['native_validation']['images']==74
    assert report['native_validation']['max_cached_idle_frames']<=3
    assert report['native_validation']['max_redraw_frames']<=8
    assert report['combat_validation']['native_scene_checks']==72
    assert report['combat_validation']['integrated_transfer_checks']>=1000
    assert report['combat_validation']['late_plane_writes']==0
    report['disk_sha256']=hashlib.sha256((build/'DRACULA.DS8').read_bytes()).hexdigest()
    assert report['maze_speed']['disk_sha256']==report['disk_sha256'],'Speed report does not match packaged disk'
    report['release']='2026-11-11 faster live perspective: direct cache drawing, compact masks and recent-view cache'
    report['native_font']='Original Dracula-style alphabet; native UI uses two 8x8 PCGs per 8x16 character'
    delta_report=build/'mode32/delta32-validation.json'
    if delta_report.exists():
        delta=json.loads(delta_report.read_text())
        report['mode32_transfer_prototype']={k:delta[k] for k in ('status','max_changed_cells','max_transfer_tstates','late_transitions','hardware_tested','caveat')}
    report['remaining']='New-view rendering speed; four remaining maze areas; native object redraws; progression and hardware checks'
    report['hardware_tested']=False
    report['previous_hardware_evidence']='Previous 40x32 release confirmed running great on original hardware; archived in hardware-tested-40x32-2026-11-10'
    report['artwork_remaining']='Four maze areas retain the previous renderer; floor objects retain original silhouettes; expanded animation and environmental detail remain'
    release.mkdir(parents=True,exist_ok=True)
    shutil.copy2(build/'DRACULA.DS8',release/'DRACULA.DS8')
    shutil.copy2(ROOT/'README.md',release/'README.md')
    (release/'validation.json').write_text(json.dumps(report,indent=2))
    shutil.copy2(build/'native/ghoulies-colour.png',release/'native-gallery-preview.png')
    shutil.copy2(build/'combat-04-colour.png',release/'native-combat-preview.png')
    shutil.copy2(build/'ghost-eight-poses.gif',release/'ghost-eight-poses.gif')
    for source,dest in (('world/map-colour.png','native-map-preview.png'),('world/story-colour.png','native-story-preview.png'),('world/area0-colour.png','native-exploration-preview.png')):
        shutil.copy2(build/source,release/dest)
    with zipfile.ZipFile(release/'Dracula2-Microbee-40x32.zip','w',zipfile.ZIP_DEFLATED) as z:
        for name in ('DRACULA.DS8','README.md','validation.json','native-gallery-preview.png','native-combat-preview.png','native-map-preview.png','native-story-preview.png','native-exploration-preview.png','ghost-eight-poses.gif'):
            z.write(release/name,name)
    with zipfile.ZipFile(release/'Dracula2-Microbee-source.zip','w',zipfile.ZIP_DEFLATED) as z:
        for folder in ('src','tools','original','baseline-release','reference','resources','docs'):
            for p in sorted((ROOT/folder).rglob('*')):
                if p.is_file() and '__pycache__' not in p.parts and p.suffix.lower() not in ('.dll','.lib','.pdb','.obj','.pyc'):
                    z.write(p,p.relative_to(ROOT))
        z.write(ROOT/'README.md','README.md')
    with zipfile.ZipFile(release/'Dracula2-Microbee-40x32.zip') as z:
        assert z.testzip() is None
        assert hashlib.sha256(z.read('DRACULA.DS8')).hexdigest()==report['disk_sha256']
    print('Packaged native 40x32 disk, validation, artwork previews and rebuild sources.')
    print('DS8 SHA256:',report['disk_sha256'])

if __name__=='__main__':main()
