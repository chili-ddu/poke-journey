"""Encode actual GPU comparisons as GIFs and lossless APNGs for direct viewing."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw, ImageFont
import argparse, hashlib, json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/skill_identity_review'
FONT=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',11)
NAMES={'electric':'전기쇼크','wind':'바람일으키기','psychic':'염동력'}


def package_case(job):
    kind,direction,entries,round_number=job
    before=next(c for c in entries if c['variant']=='existing')
    after=next(c for c in entries if c['variant']=='sample')
    assert before['trace']==after['trace'] and before['hit_frame']==after['hit_frame']
    assert before['target_visible']==after['target_visible']
    assert sum(before['material_metrics'].get(k,0) for k in ['prior_shader_frames','identity_frames','lens_frames'])>0
    assert after['material_metrics']['identity_frames']+after['material_metrics']['lens_frames']>0
    if 'shading_frames' in after['material_metrics']:
        assert after['material_metrics']['shading_frames']>0 and before['material_metrics']['shading_frames']==0
    count=len(before['trace']);assert count%3==0
    crop_x=max(0,min(192,round((192+before['centers'][0][0])/2-96)))
    dest=OUT/f'comparison-r{round_number}'/f'{kind}-{direction}'
    dest.mkdir(parents=True,exist_ok=True)
    frames=[]
    for i in range(count):
        canvas=Image.new('RGB',(384,216))
        for col,variant in enumerate(['existing','sample']):
            with Image.open(OUT/f'native-r{round_number}/{kind}-{direction}/{variant}/{i:03}.png') as im:
                assert im.size==(384,216)
                canvas.paste(im.convert('RGB').crop((crop_x,0,crop_x+192,216)),(192*col,0))
        draw=ImageDraw.Draw(canvas);draw.rectangle((0,0,383,18),fill='#222a28')
        draw.text((5,2),'앞선 시안',font=FONT,fill='#f1e8d5')
        draw.text((197,2),'수정 샘플',font=FONT,fill='#f1e8d5')
        draw.line((191,0,191,215),fill='#6f7e73')
        canvas.save(dest/f'{i:03}.png');frames.append(canvas)
    frames[0].save(dest/'comparison.png',save_all=True,append_images=frames[1:],duration=[33,33,34]*(count//3),loop=0,disposal=0,blend=0)
    # Shared palette for both sides and every frame, without resizing/dithering.
    atlas=Image.new('RGB',(384*6,216*((count+5)//6)))
    for i,im in enumerate(frames):atlas.paste(im,((i%6)*384,(i//6)*216))
    palette=atlas.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    quantized=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
    quantized[0].save(dest/'comparison.gif',save_all=True,append_images=quantized[1:],duration=[60,70,70]*(count//3),loop=0,optimize=False,disposal=1)
    with Image.open(dest/'comparison.gif') as im:
        duration=0
        for i in range(im.n_frames):im.seek(i);duration+=im.info['duration']
        assert im.size==(384,216) and duration==count*200/3
    return dict(kind=kind,name=NAMES[kind],direction=direction,frames=count,simulation_fps=30,gif_speed=0.5,
                gif=str((dest/'comparison.gif').relative_to(OUT)),apng=str((dest/'comparison.png').relative_to(OUT)),
                hit_frame=before['hit_frame'],damage=before['damage'],state_equal=True,feedback_equal=True,
                metrics=after['material_metrics'])


def main():
    global OUT
    parser=argparse.ArgumentParser();parser.add_argument('--round',type=int,default=3);parser.add_argument('--out',type=Path);args=parser.parse_args()
    if args.out:OUT=args.out.resolve()
    report=json.loads((OUT/f'native-r{args.round}/checks.json').read_text())
    groups=sorted({(c['kind'],c['direction']) for c in report})
    jobs=[(k,d,[c for c in report if c['kind']==k and c['direction']==d],args.round) for k,d in groups]
    with ThreadPoolExecutor(max_workers=2) as pool:comparisons=list(pool.map(package_case,jobs))
    (OUT/f'comparisons-r{args.round}.json').write_text(json.dumps(comparisons,ensure_ascii=False,indent=2)+'\n')
    if args.round>=3:
        assert len(report)==24 and len(comparisons)==12
        protected=json.loads((OUT/'protected-before.json').read_text())
        changed=[p for p,h in protected.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
        refs=[str(p.relative_to(ROOT)) for f in ['scripts','scenes'] for p in (ROOT/f).rglob('*')
              if p.is_file() and p.suffix in ['.gd','.tscn'] and any(s in p.read_text() for s in ['skill_identity_material','psychic_lens.gdshader','skill_identity_review','skill_projectile_shading','skill_glass_lens'])]
        assert not refs,refs
        (OUT/'qa-summary.json').write_text(json.dumps(dict(native_cases=len(report),comparisons=len(comparisons),
            state_equal=True,feedback_equal=True,game_connected=False,observed_production_hash_changes=changed,
            production_references_to_sample=refs,gif_speed=0.5,gif_palette='shared 256 colours, no dither; APNG originals retained'),indent=2)+'\n')
    print(f'Round {args.round}: {len(comparisons)} GIF/APNG comparisons; combat and hit feedback identical')


if __name__=='__main__':main()
