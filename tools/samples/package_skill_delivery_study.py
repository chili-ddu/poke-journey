"""Package actual GPU comparison frames; no new FX are post-composited."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse,json,subprocess
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/skill_delivery_study'
KINDS=['fire','water','electric','leaf','wind','psychic']
NAMES=dict(fire='불꽃세례',water='물대포',electric='전기쇼크',leaf='잎날가르기',wind='바람일으키기',psychic='염동력')
FONT=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',11)


def package_case(case):
    kind,direction=case;folder=OUT/'native-r3'/f'{kind}-{direction}'
    report=json.loads((OUT/'native-r3/checks.json').read_text());entries=[r for r in report if r['kind']==kind and r['direction']==direction]
    assert len(entries)==2
    a=next(r for r in entries if r['variant']=='existing');b=next(r for r in entries if r['variant']=='sample')
    assert a['trace']==b['trace'] and a['hit_frame']==b['hit_frame'] and a['target_visible']==b['target_visible']
    crop_x=max(0,min(192,round((192+a['centers'][0][0])/2-96)))
    dest=OUT/'comparison'/f'{kind}-{direction}';dest.mkdir(parents=True,exist_ok=True)
    images=[]
    for frame in range(60):
        canvas=Image.new('RGB',(384,216))
        for side,variant in enumerate(['existing','sample']):
            im=Image.open(folder/variant/f'{frame:03}.png').convert('RGB');assert im.size==(384,216)
            canvas.paste(im.crop((crop_x,0,crop_x+192,216)),(side*192,0))
        draw=ImageDraw.Draw(canvas);draw.rectangle((0,0,383,18),fill='#222a28')
        draw.text((5,2),'기존 스킬 그림',font=FONT,fill='#f1e8d5');draw.text((197,2),'시전·이동 샘플',font=FONT,fill='#f1e8d5')
        draw.line((191,0,191,215),fill='#6f7e73')
        canvas.save(dest/f'{frame:03}.png');images.append(canvas)
    # Lossless APNG avoids palette quantisation of the map or character pixels.
    images[0].save(dest/'comparison.png',save_all=True,append_images=images[1:],duration=[33,33,34]*20,loop=0,disposal=0,blend=0)
    command=['ffmpeg','-y','-loglevel','error','-framerate','30','-i',str(dest/'%03d.png'),'-c:v','libvpx-vp9','-lossless','1','-pix_fmt','yuv444p','-deadline','good','-cpu-used','4','-row-mt','1','-an',str(dest/'comparison.webm')]
    p=subprocess.run(command,text=True,capture_output=True);assert p.returncode==0,p.stderr
    return dict(kind=kind,name=NAMES[kind],direction=direction,crop_x=crop_x,native_size=[384,216],frames=60,fps=30,
        hit_frame=a['hit_frame'],damage=a['damage'],projectiles=a['projectile_count'],state_equal=True,hit_feedback_equal=True,
        image=f'comparison/{kind}-{direction}/comparison.png',video=f'comparison/{kind}-{direction}/comparison.webm')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--directions',nargs='+',default=['right','left','up','down']);args=parser.parse_args()
    jobs=[(k,d) for k in KINDS for d in args.directions]
    with ThreadPoolExecutor(max_workers=3) as pool:cases=list(pool.map(package_case,jobs))
    (OUT/'comparisons.json').write_text(json.dumps(cases,indent=2,ensure_ascii=False)+'\n')
    (OUT/'index.html').write_text((ROOT/'tools/samples/skill_delivery_study.html').read_text())
    print(f'Packaged {len(cases)} actual GPU comparisons, native 384x216; identical combat and feedback',flush=True)


if __name__=='__main__':main()
