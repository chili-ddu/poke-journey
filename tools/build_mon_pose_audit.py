"""Render every installed species/skin from the real Godot audit selections."""
from pathlib import Path
import json,csv,html,math
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/all_mon_pose_audit'
poses=json.loads((OUT/'previews.json').read_text());report=json.loads((OUT/'report.json').read_text())
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
font=lambda s:ImageFont.truetype(font_path,s)
BG=(22,27,37);FG=(230,236,245);MUTED=(163,178,196);CYAN=(91,220,223);LINE=(53,65,80)
cache={}
def sprite(e):
 p=e['path']
 if p not in cache:cache[p]=Image.open(ROOT/p.removeprefix('res://')).convert('RGBA')
 x,y,w,h=map(int,e['rect']);return cache[p].crop((x,y,x+w,y+h))
def ground(e):
 p=sprite(e);b=p.getbbox()
 return b[3]-1-e['anchor'][1] if b else 0

def scale_for(entries,width,height,foot):
 left=right=up=1
 for e in entries:
  b=sprite(e).getbbox()
  if not b:continue
  ax,ay=e['anchor'];left=max(left,ax-b[0]);right=max(right,b[2]-ax);up=max(up,ay+foot-b[1])
 return max(1,min(5,int((width/2-7)/max(left,right)),int((height-22)/up)))

def draw_pose(im,e,x,baseline,scale,foot):
 p=sprite(e);b=p.getbbox()
 if not b:return
 p=p.crop(b).resize(((b[2]-b[0])*scale,(b[3]-b[1])*scale),Image.Resampling.NEAREST)
 ax,ay=e['anchor']
 im.paste(p,(round(x+(b[0]-ax)*scale),round(baseline+(b[1]-ay-foot)*scale)),p)

# Full eight-direction contact sheets for all 84 sets, fixed world origin.
for st in poses:
 name=f"{st['dex']:04}-{'shiny' if st['shiny'] else 'normal'}"
 im=Image.new('RGB',(960,1260),BG);d=ImageDraw.Draw(im)
 d.text((20,14),f"{st['species'].upper()} / {'SHINY' if st['shiny'] else 'NORMAL'} / {st['action']}",font=font(23),fill=FG)
 d.text((20,46),'8 directions x 4 poses / stable ground origin',font=font(17),fill=MUTED)
 entries=[v['fixed'] for row in st['directions'] for v in row];foot=ground(entries[0]);scale=scale_for(entries,210,125,foot)
 for row,dir in enumerate(['DOWN','DOWN-RIGHT','RIGHT','UP-RIGHT','UP','UP-LEFT','LEFT','DOWN-LEFT']):
  y=80+row*146
  d.text((12,y+10),dir,font=font(14),fill=CYAN)
  for j,s in enumerate(st['directions'][row]):
   cx=150+j*230;baseline=y+120
   d.line((cx-65,baseline+1,cx+65,baseline+1),fill=LINE)
   draw_pose(im,s['fixed'],cx,baseline,scale,foot)
 im.save(OUT/(name+'.png'))
 cache.clear()

# Four cardinal directions in the mid-attack pose; every set appears once.
pages=[]
for shiny in [False,True]:
 items=[p for p in poses if p['shiny']==shiny]
 for page in range(math.ceil(len(items)/12)):
  group=items[page*12:(page+1)*12]
  im=Image.new('RGB',(1280,850),BG);d=ImageDraw.Draw(im)
  title=f"ALL MON POSE AUDIT / {'SHINY' if shiny else 'NORMAL'} / {page+1}"
  d.text((20,14),title,font=font(25),fill=FG)
  d.text((20,50),'Each card: UP / RIGHT / DOWN / LEFT | same mid-action sample',font=font(17),fill=MUTED)
  for i,st in enumerate(group):
   x=(i%4)*320;y=90+(i//4)*250
   d.rectangle((x+8,y,x+312,y+238),outline=LINE)
   d.text((x+20,y+12),f"{st['dex']:03} {st['species']}",font=font(18),fill=CYAN)
   d.text((x+20,y+38),st['action'],font=font(14),fill=MUTED)
   entries=[st['directions'][r][2]['fixed'] for r in [4,2,0,6]];foot=ground(entries[0]);scale=scale_for(entries,74,150,foot)
   for j,(e,label) in enumerate(zip(entries,['U','R','D','L'])):
    cx=x+43+j*78;baseline=y+207
    d.text((cx-5,y+64),label,font=font(14),fill=MUTED)
    d.line((cx-28,baseline+1,cx+28,baseline+1),fill=LINE)
    draw_pose(im,e,cx,baseline,scale,foot)
  filename=f"overview-{'shiny' if shiny else 'normal'}-{page+1}.png"
  im.save(OUT/filename);pages.append(filename);cache.clear()

# Outliers under the OLD positioning, using the identical baked images.
ranked=sorted((r for r in report['records'] if not r['shiny']),key=lambda r:r['max_old_side_bias'],reverse=True)
wanted=[]
for r in ranked:
 if r['species'] not in wanted:wanted.append(r['species'])
 if len(wanted)==8:break
for page in range(2):
 im=Image.new('RGB',(1200,1020),BG);d=ImageDraw.Draw(im)
 d.text((20,14),'UP ATTACK / SAME POSES / BEFORE vs CORRECTED',font=font(24),fill=FG)
 for i,species in enumerate(wanted[page*4:(page+1)*4]):
  st=next(s for s in poses if s['species']==species and not s['shiny']);y=65+i*235
  d.text((18,y+5),species.upper(),font=font(20),fill=CYAN)
  entries=[s[k] for s in st['directions'][4] for k in ['before','fixed']];foot=ground(st['directions'][4][0]['fixed']);scale=scale_for(entries,140,175,foot)
  for j,pair in enumerate(st['directions'][4]):
   for side,key in enumerate(['before','fixed']):
    cx=95+j*290+side*140;baseline=y+205
    d.text((cx-30,y+35),'before' if side==0 else 'fixed',font=font(14),fill=MUTED)
    d.line((cx-52,baseline+1,cx+52,baseline+1),fill=LINE)
    draw_pose(im,pair[key],cx,baseline,scale,foot)
 im.save(OUT/f'outliers-{page+1}.png');cache.clear()

with (OUT/'actions.csv').open('w',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=list(report['records'][0]));writer.writeheader();writer.writerows(report['records'])
links=[]
for st in poses:
 name=f"{st['dex']:04}-{'shiny' if st['shiny'] else 'normal'}.png"
 links.append(f'<a href="{name}">{html.escape(st["species"])} {"이로치" if st["shiny"] else "일반"}</a>')
counts=report['counts']
(OUT/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>포켓몬 자세 점검</title><style>body{background:#161b25;color:#e6ecf5;font:16px system-ui;max-width:1280px;margin:32px auto;padding:20px}a{color:#5bdcdf;display:inline-block;margin:8px}img{width:100%;height:auto}p{line-height:1.6}</style><h1>포켓몬 자세 점검</h1>'''+f'<p>42종 · 일반/이로치 84세트 · {counts["actions"]}개 동작 · {counts["samples"]:,}개 자세 검사. 보간 누락·범위 초과·빈 프레임·지면 공격 기준점 검사 오류 {len(report["errors"])}건.</p><p>아래는 실제 게임 렌더 선택 함수로 뽑은 그림입니다. 자동 검사는 수치·영역을 확인하며 모든 기술의 실제 전투 플레이를 의미하지 않습니다. 날개·꼬리 등의 optical flow 왜곡은 별도의 화질 개선 대상입니다.</p>' + ''.join(f'<a href="{p}"><img loading="lazy" src="{p}"></a>' for p in pages)+'<h2>이전 기준점 오차가 큰 종</h2>'+''.join(f'<img loading="lazy" src="outliers-{i}.png">' for i in [1,2])+'<h2>전체 8방향 / 4자세 개별 시트</h2>'+''.join(links),encoding='utf-8')
print('Rendered',len(poses),'contact sheets,',len(pages),'overview pages, 2 outlier comparisons.')
print('Outliers:',wanted)
