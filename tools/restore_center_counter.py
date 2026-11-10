"""Reconstruct counter occlusions from intact source rows. Review output only."""
import json, hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from center_object_masks import S, mask
R=Path(__file__).resolve().parents[1]; D=R/'docs/source_object_audit/center_masks'; O=D/'counter_restored'

def main():
 O.mkdir(exist_ok=True)
 data=json.loads((D/'objects.json').read_text()); records={o['id']:o for o in data['objects']}
 counter=records['counter']; bb=counter['bounds_pixels']; x0,y0,x1,y1=bb
 before=Image.open(D/'objects/counter.png').convert('RGBA'); after=before.copy()
 source=Image.open(D/'source.png').convert('RGBA')
 shape=mask(next(o['polygon'] for o in S if o['id']=='counter'),source.size)
 changed=Image.new('L',before.size); inferred=Image.new('L',before.size); donors=[]
 # Whole occluder envelopes include their baked-in contact shadows, not just alpha holes.
 zones=[('vase_left',(66,38,79,53)),('vase_right',(162,38,175,53)),('counter_nameplate',(114,46,126,53))]
 for name,(a,b,c,d) in zones:
  samples=set()
  for y in range(b,d):
   for x in range(a,c):
    if not shape.getpixel((x,y)):continue
    # Rear arms: sample the same column above flowers, preserving their side trim.
    # Front bar: sample a clean same-height section between flower and nameplate.
    donor=(x,30) if y<=44 else (100,y)
    dx,dy=donor
    assert before.getpixel((dx-x0,dy-y0))[3]==255, 'Donor must be visible counter, not an inferred pixel'
    color=source.getpixel(donor); old=before.getpixel((x-x0,y-y0))
    after.putpixel((x-x0,y-y0),color);inferred.putpixel((x-x0,y-y0),255)
    if old!=color:changed.putpixel((x-x0,y-y0),255)
    samples.add(donor)
  donors.append({'occluder':name,'source_rect':[a,b,c,d],'donors':sorted(samples),'method':'same-column intact arm above object / same-row intact front bar'})
 after.save(O/'counter.png');inferred.save(O/'inferred_mask.png');changed.save(O/'changed_mask.png')
 # Verify no pixel outside declared reconstruction area changed.
 for y in range(before.height):
  for x in range(before.width):
   if not inferred.getpixel((x,y)):assert before.getpixel((x,y))==after.getpixel((x,y))
   else:assert after.getpixel((x,y))[3]==255
 assert all(before.getpixel((x,y))[3]==after.getpixel((x,y))[3] for y in range(31,before.height) for x in range(before.width)), 'Front face alpha stays untouched'
 restored_scene=Image.new('RGBA',source.size);restored_scene.alpha_composite(after,(x0,y0))
 for name in ['vase_left','vase_right','counter_nameplate']:
  o=records[name];restored_scene.alpha_composite(Image.open(D/'objects'/f'{name}.png').convert('RGBA'),tuple(o['bounds_pixels'][:2]))
 restored_scene.crop(bb).save(O/'with_objects.png')
 highlight=after.copy(); overlay=Image.new('RGBA',after.size,(35,185,255,255));highlight.paste(overlay,(0,0),inferred)
 panels=[('BEFORE: visible counter only',before),('RESTORED: inferred surface',after),('BLUE: reconstructed pixels',highlight),('OBJECTS REPLACED',restored_scene.crop(bb))]
 board=Image.new('RGB',(760,4*290),'#252a33');draw=ImageDraw.Draw(board)
 for i,(title,im) in enumerate(panels):
  yy=i*290;draw.text((16,yy+8),title,fill='white');z=im.resize((im.width*6,im.height*6),Image.Resampling.NEAREST)
  for y in range(yy+30,yy+270,12):
   for x in range(16,700,12):draw.rectangle((x,y,x+11,y+11),fill='#666e7a' if ((x-16)//12+(y-yy-30)//12)%2 else '#8d96a3')
  board.paste(z,(16,yy+30),z)
 board.save(O/'comparison.png')
 n=sum(inferred.histogram()[1:]);k=sum(changed.histogram()[1:])
 out={'source_counter_sha256':hashlib.sha256((D/'objects/counter.png').read_bytes()).hexdigest(),'bounds_pixels':bb,'status':'inferred_surface_review_only','inferred_pixels':n,'changed_pixels':k,'zones':donors,'limitations':['Hidden original art cannot be recovered exactly.','Only front bar / rear arms behind two vases and nameplate restored.','Central U opening remains transparent; it is not a missing counter surface.','No new side/back/bottom faces, collision changes or runtime import.'],'checks':['all donors visible in original counter','all inferred pixels opaque','outside inferred mask unchanged','front face alpha unchanged']}
 (O/'restoration.json').write_text(json.dumps(out,indent=2))
 (O/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>카운터 가림 영역 복원</title><style>body{background:#191e26;color:#eee;font:16px system-ui;margin:32px;max-width:1000px}img{max-width:100%;image-rendering:pixelated}a{color:#9cf}</style><h1>카운터 가림 영역 복원 검토</h1><p>화병 두 개와 명패 뒤의 윗면을 주변의 온전한 원본 픽셀로 채웠습니다. 파란색은 추정 복원 영역입니다. 앞면·하단 테두리·중앙 U자 빈 공간은 그대로입니다. 원본에 없는 면이므로 정확한 원화 복구가 아니라 주변 패턴에 따른 복원안입니다.</p><p><a href="placement/index.html">소품 이동 배치 검토</a> · <a href="godot_review/index.html">Godot 접지·깊이·음영 검토</a> · <a href="map_review/index.html">두 센터 지도 배치·통로 검토</a></p><img src="comparison.png"><p><a href="counter.png">복원 카운터 PNG</a> · <a href="inferred_mask.png">추정 영역 마스크</a> · <a href="restoration.json">복원 좌표·검증 기록</a></p><p>기존 분리 원본과 게임 에셋은 수정하지 않았습니다. 게임 배치·충돌은 아직 검토 대상입니다.</p>''')
 print(f'{n} inferred pixels, {k} changed; donor/alpha/unchanged-region checks passed')
if __name__=='__main__':main()
