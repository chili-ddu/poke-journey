"""Center source segmentation review. Only writes docs; no inpainting or runtime edits."""
import json, hashlib, html
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
R=Path(__file__).resolve().parents[1]; O=R/'docs/source_object_audit/center_masks'
# Polygon vertices are source pixel boundaries (end exclusive); masks are rendered pixel-center based.
# Child objects are assigned first; the counter owns only remaining visible pixels.
def obj(id,kind,poly,foot=(),parent=None):return dict(id=id,kind=kind,polygon=poly,proposed_footprint=list(foot),parent=parent)
def box(x0,y0,x1,y1):return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
S=[
obj('wall_screen','wall_object',[(115,9),(138,9),(140,11),(140,24),(114,24),(114,10)]),
obj('wall_map','wall_object',box(196,12,219,24)),
obj('pc','floor_object',[(180,8),(188,8),(190,10),(192,12),(192,38),(190,40),(178,40),(176,38),(176,12),(178,10)],[(11,2)]),
obj('shelf','floor_object',box(33,11,64,40),[(2,2),(3,2)]),
obj('plant','floor_object',[(22,12),(26,12),(26,14),(29,14),(29,18),(32,18),(32,21),(30,21),(30,25),(27,26),(27,30),(29,32),(29,36),(27,39),(21,39),(18,36),(18,32),(21,30),(21,26),(18,25),(18,22),(16,22),(16,19),(18,18),(18,15),(22,15)],[(1,2)]),
obj('healing_device','surface_object',[(88,16),(104,16),(104,18),(106,18),(106,21),(109,21),(109,24),(111,24),(111,44),(80,44),(80,25),(82,25),(82,22),(85,22),(85,18),(88,18)],parent='counter'),
obj('counter_terminal','surface_object',[(149,24),(159,24),(159,40),(145,40),(145,30),(149,30)],parent='counter'),
obj('vase_left','surface_object',[(69,38),(74,38),(74,40),(77,40),(77,43),(78,43),(78,50),(76,52),(68,52),(66,50),(66,43),(67,43),(67,40),(69,40)],parent='counter'),
obj('vase_right','surface_object',[(165,38),(170,38),(170,40),(173,40),(173,43),(174,43),(174,50),(172,52),(164,52),(162,50),(162,43),(163,43),(163,40),(165,40)],parent='counter'),
obj('counter_nameplate','surface_object',box(114,46,126,53),parent='counter'),
obj('counter','floor_object',[(64,24),(80,24),(80,44),(160,44),(160,24),(176,24),(176,60),(173,63),(67,63),(64,60)],[(x,3) for x in range(4,11)]+[(4,2),(10,2)]),
obj('seat_yellow_north','floor_object',[(177,80),(189,80),(191,82),(191,95),(177,95),(176,93),(176,82)],[(11,5)]),
obj('seat_blue_north','floor_object',[(193,80),(205,80),(207,82),(207,95),(193,95),(192,93),(192,82)],[(12,5)]),
obj('seat_yellow_east','floor_object',[(225,96),(237,96),(239,98),(239,111),(225,111),(224,109),(224,98)],[(14,6)]),
obj('seat_blue_east','floor_object',[(225,112),(237,112),(239,114),(239,127),(225,127),(224,125),(224,114)],[(14,7)]),
obj('waiting_table','floor_object',[(180,97),(202,97),(207,102),(207,124),(205,127),(176,127),(174,124),(174,103)],[(11,6),(12,6),(11,7),(12,7)]),
obj('stairs','structure',[(0,80),(5,80),(5,82),(8,82),(8,85),(28,85),(31,88),(31,120),(0,120)],[(x,y) for x in [0,1] for y in [5,6,7]]),
obj('entry_mat','floor_decal',box(107,132,133,148)),
]

def mask(poly,size):
    # Pixel-center scan avoids the inclusive edge convention of ImageDraw.polygon.
    m=Image.new('L',size);p=m.load()
    for y in range(size[1]):
        hits=[]
        for (x0,y0),(x1,y1) in zip(poly,poly[1:]+poly[:1]):
            if min(y0,y1)<=y+.5<max(y0,y1):hits.append(x0+(y+.5-y0)*(x1-x0)/(y1-y0))
        hits.sort()
        for a,b in zip(hits[::2],hits[1::2]):
            for x in range(max(0,int(a)),min(size[0],int(b)+1)):
                if a<=x+.5<b:p[x,y]=255
    return m

def trim_background(m, source, id):
    # Only remove known background colors connected to a mask edge, never enclosed detail.
    from collections import deque
    colors={(230,222,156),(246,246,205),(238,238,172),(197,180,139),(213,205,156),(230,139,98),(246,238,164)}
    if id.startswith('vase') or id=='counter_nameplate': colors.add((255,131,115))
    p=m.load(); src=source.load(); w,h=m.size; q=deque(); seen=set()
    for y in range(h):
        for x in range(w):
            if p[x,y] and src[x,y][:3] in colors and any(not(0<=xx<w and 0<=yy<h) or not p[xx,yy] for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]):
                q.append((x,y));seen.add((x,y))
    while q:
        x,y=q.popleft();p[x,y]=0
        for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if 0<=xx<w and 0<=yy<h and p[xx,yy] and (xx,yy) not in seen and src[xx,yy][:3] in colors:
                seen.add((xx,yy));q.append((xx,yy))
    return m

# Source-space corrections reviewed against the outer contour. Do not color-key
# the whole image: the same colors occur in books and the device's red cross.
EDGE_EXCLUSIONS = {
    'shelf': [(63, y) for y in range(11, 40)],  # backdrop shadow outside dark right border at x=62
    'healing_device': [(86, 19), (105, 19)],  # wallpaper specks above shoulders
    'stairs': [(29,91),(30,92),(30,93),(30,94),(29,115),(30,116),(30,117),(30,118)],
}

def review_edges(m, id):
    for xy in EDGE_EXCLUSIONS.get(id, []):
        m.putpixel(xy, 0)
    return m

def main():
 O.mkdir(parents=True,exist_ok=True);(O/'objects').mkdir(exist_ok=True)
 d=R/'assets/maps/viridian_center';j=json.loads((d/'map.json').read_text());w,h=j['width']*16,j['height']*16;p=j['pad']*16
 source=Image.open(d/'bottom.png').convert('RGBA').crop((p,p,p+w,p+h));source.alpha_composite(Image.open(d/'top.png').convert('RGBA'))
 source.save(O/'source.png'); occupied=Image.new('L',source.size); overlay=source.convert('RGB'); cells=[]; records=[]
 for i,o in enumerate(S):
  m=review_edges(trim_background(ImageChops.subtract(mask(o['polygon'],source.size),occupied),source,o['id']),o['id']);occupied=ImageChops.lighter(occupied,m)
  assert all(m.getpixel(xy)==0 for xy in EDGE_EXCLUSIONS.get(o['id'], []))
  preserved={'shelf':[(44,25)], 'healing_device':[(95,43),(96,43)]}
  assert all(m.getpixel(xy)==255 for xy in preserved.get(o['id'], []))
  cut=source.copy();cut.putalpha(m);bb=m.getbbox();assert bb is not None
  cut.crop(bb).save(O/'objects'/(o['id']+'.png'));m.crop(bb).save(O/'objects'/(o['id']+'_mask.png'))
  color=((i*67+70)%220+25,(i*103+60)%220+25,(i*43+100)%220+25)
  overlay.paste(Image.blend(overlay,Image.new('RGB',source.size,color),.35),(0,0),m)
  x0,y0,x1,y1=bb;record=dict(o,bounds_pixels=list(bb),mask_status='manual_visible_silhouette_review',hidden_surface='not_reconstructed',footprint_status='proposed_not_playtested')
  record['source_blocked_in_proposed']=[list(t) for t in o['proposed_footprint'] if j['solid'][t[1]][t[0]]=='1']
  record['source_open_in_proposed']=[list(t) for t in o['proposed_footprint'] if j['solid'][t[1]][t[0]]=='0']
  record['reviewed_background_exclusions'] = EDGE_EXCLUSIONS.get(o['id'], [])
  records.append(record)
  cell=Image.new('RGB',(480,240),'#242933');draw=ImageDraw.Draw(cell);draw.text((8,8),o['id']+' '+str(bb),fill='white')
  scale=min(4,210//max(x1-x0,y1-y0));scale=max(1,scale)
  raw=source.crop(bb).resize(((x1-x0)*scale,(y1-y0)*scale),Image.Resampling.NEAREST)
  c=cut.crop(bb).resize(raw.size,Image.Resampling.NEAREST);cell.paste(raw,(8,30))
  for yy in range(30,230,8):
   for xx in range(248,472,8):draw.rectangle((xx,yy,xx+7,yy+7),fill='#747b85' if ((xx-248)//8+(yy-30)//8)%2 else '#aab2bd')
  cell.paste(c,(248,30),c);cells.append(cell)
 # Keep unassigned backdrop; missing pixels are holes, not invented clean wallpaper.
 remainder=source.copy();remainder.putalpha(ImageChops.invert(occupied));remainder.save(O/'unassigned_backdrop.png')
 reconstruct=remainder.copy()
 for o in records:
  cut=Image.open(O/'objects'/(o['id']+'.png')).convert('RGBA');reconstruct.alpha_composite(cut,tuple(o['bounds_pixels'][:2]))
 assert reconstruct.tobytes()==source.tobytes(), 'Visible-source pixel reconstruction must be lossless'
 for k in range(0,len(cells),6):
  sheet=Image.new('RGB',(960,720),'#242933')
  for i,c in enumerate(cells[k:k+6]):sheet.paste(c,((i%2)*480,(i//2)*240))
  sheet.save(O/f'review_{k//6+1}.png')
 # Separate black/white previews expose stray pixels hidden by the checkerboard.
 for batch in range(3):
  board=Image.new('RGB',(1152,900),'#303540');bd=ImageDraw.Draw(board)
  for i,o in enumerate(records[batch*6:batch*6+6]):
   cut=Image.open(O/'objects'/(o['id']+'.png')).convert('RGBA')
   scale=min(8,270//max(cut.size));scale=max(1,scale)
   cut=cut.resize((cut.width*scale,cut.height*scale),Image.Resampling.NEAREST)
   xx=(i%2)*576;yy=(i//2)*300
   bd.text((xx+8,yy+4),o['id'],fill='white')
   for dx,color in [(0,'black'),(288,'white')]:
    panel=Image.new('RGB',(280,276),color);panel.paste(cut,(4,4),cut);board.paste(panel,(xx+dx,yy+20))
  board.save(O/f'edge_review_{batch+1}.png')
 overlay.resize((w*4,h*4),Image.Resampling.NEAREST).save(O/'ownership.png')
 foot=source.resize((w*4,h*4),Image.Resampling.NEAREST).convert('RGB');draw=ImageDraw.Draw(foot)
 for o in records:
  for x,y in o['proposed_footprint']:
   c='#ff5566' if j['solid'][y][x]=='0' else '#55e5ae';draw.rectangle((x*64,y*64,x*64+63,y*64+63),outline=c,width=3)
 foot.save(O/'footprints.png')
 payload={'source':'viridian_center bottom+top (unpadded)','shared_with':'pewter_center','scope':'18 visible objects; backdrop/decal source remains unassigned','status':'review artifact only, not import-ready or collision-authoritative','footprint_legend':'green: source solid; red: proposed footprint currently open; requires placement review','objects':records,'validation':{'lossless_visible_reconstruction':True,'nonoverlapping_ownership':True}}
 for f in ['bottom.png','top.png']:
  assert (d/f).read_bytes()==(R/'assets/maps/pewter_center'/f).read_bytes()
 (O/'objects.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2))
 report=['<!doctype html><meta charset="utf-8"><title>센터 객체 경계 검토</title><style>body{background:#181d25;color:#eee;font:16px system-ui;margin:32px}img{max-width:100%;image-rendering:pixelated}td,th{border:1px solid #666;padding:9px}table{border-collapse:collapse}a{color:#9cf}</style><h1>센터 원본 객체 경계 검토</h1><p>18개 객체. 왼쪽 원본 영역 / 오른쪽 분리 결과. 보이는 픽셀만 분리했으며 가려진 면은 복원하지 않았습니다. 픽셀 좌표 끝값은 제외합니다. 마스크는 수동 실루엣 검토본이며 최종 임포트용 확정본은 아닙니다.</p>']
 report += [f'<img src="review_{n}.png">' for n in range(1,4)]
 report += ['<h2>경계 재검토: 검정·흰색 배경</h2><p>책장 오른쪽 외곽 띠, 회복 장치 벽지색 점, 계단 바깥 음영을 배경으로 재분류했습니다. 위 비교표 왼쪽은 배경을 포함한 원본이고 오른쪽이 분리 결과입니다.</p>']
 report += [f'<img src="edge_review_{n}.png">' for n in range(1,4)]
 report += ['<h2>바닥 점유 제안</h2><p>초록: 원본도 막힘 / 빨강: 원본은 열려 있음. 빨간 칸을 자동으로 막지 않습니다. 벽걸이는 바닥 충돌 없음, 카운터 위 물건은 부모 점유 영역을 공유합니다. 실제 이동 검증 전에는 확정할 수 없습니다.</p><img src="footprints.png"><h2>픽셀 소유 영역</h2><img src="ownership.png"><p><a href="objects.json">좌표·부착 대상·마스크·점유 데이터</a></p><p>검증: 분리된 객체와 잔여 배경을 다시 합치면 원본 모든 픽셀이 정확히 동일합니다. 이는 의미상 누끼가 완벽하다는 뜻은 아닙니다. 런타임·원본·충돌 데이터는 변경하지 않았습니다.</p>']
 report.append('<p><a href="counter_restored/index.html">별도 검토: 가려진 카운터 윗면 복원안</a> — 원본 분리 마스크와 구분한 추정 복원입니다.</p>')
 (O/'index.html').write_text(''.join(report));print(len(records),'objects; lossless reconstruction; source pair identical')
if __name__=='__main__':main()
