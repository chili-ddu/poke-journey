"""Plot both implemented regions and their real reception-gate links in one atlas.

Existing map rasters are plotted at the same tile scale. Dotted links represent
scene transitions, not fabricated terrain. No gameplay or source art is edited.
"""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import kanto_world as k

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/world_overview'
FONT=ImageFont.truetype(str(ROOT/'assets/fonts/Galmuri11.ttf'),16)
BG='#172f3a'
GOLD='#f0cc7e'
BLUE='#94d8ed'


def label(canvas,xy,text,scale=1.5,anchor='mm',color='#e8f1ec',fill=BG):
    probe=ImageDraw.Draw(canvas)
    bounds=probe.textbbox((0,0),text,font=FONT)
    w,h=bounds[2]-bounds[0]+16,bounds[3]-bounds[1]+12
    plate=Image.new('RGBA',(w,h),(0,0,0,0));draw=ImageDraw.Draw(plate)
    draw.rounded_rectangle((0,0,w-1,h-1),radius=3,fill=fill,outline=color,width=1)
    draw.text((8-bounds[0],6-bounds[1]),text,font=FONT,fill=color)
    plate=plate.resize((round(w*scale),round(h*scale)),Image.Resampling.NEAREST)
    x,y=xy
    if anchor=='mm':x-=plate.width/2;y-=plate.height/2
    elif anchor=='mt':x-=plate.width/2
    canvas.paste(plate,(round(x),round(y)),plate)


def dotted(draw,points,color,width=5):
    for a,b in zip(points,points[1:]):
        dist=math.dist(a,b)
        for offset in range(0,round(dist),16):
            t=offset/max(1,dist);u=min(1,(offset+9)/max(1,dist))
            p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
            q=(a[0]+(b[0]-a[0])*u,a[1]+(b[1]-a[1])*u)
            draw.line((p,q),fill=color,width=width)


def run():
    johto_path=OUT/'johto_overview.png'
    kanto_path=ROOT/'docs/kanto_world/mainland_routes.png'
    j=Image.open(johto_path).convert('RGB');raw_k=Image.open(kanto_path).convert('RGB')
    data=json.loads((ROOT/'assets/maps/johto_border_hgss/scenes/matrix_0000.json').read_text())
    left=min(c['x'] for c in data['chunks'])*32;right=(max(c['x'] for c in data['chunks'])+1)*32
    top=min(c['z'] for c in data['chunks'])*32;bottom=(max(c['z'] for c in data['chunks'])+1)*32
    cam_height=max(bottom-top,(right-left)*j.height/j.width)*1.12
    pixels_per_tile=j.height/cam_height
    def project(x,z):
        return (j.width/2+(x-(left+right)/2)*pixels_per_tile,
                j.height/2+(z-(top+bottom)/2)*pixels_per_tile)
    def native_anchor(header,index):
        w=next(w for w in data['warps'] if w['header']==header and w['index']==index)
        return project(w['x']+0.5,w['z']+0.5)
    legacy=json.loads((ROOT/'assets/maps/kanto_world/map.json').read_text())
    def frlg_anchor(source,index):
        w=next(w for w in legacy['warps'] if w['map']==source and w['index']==index)
        return ((w['x']+0.5)*pixels_per_tile,(w['y']+0.5)*pixels_per_tile)
    j_origin=(40,200)
    j26=native_anchor(30,2);j28=native_anchor(32,0)
    ka22=frlg_anchor('route22',0);ka23=frlg_anchor('route23',2)
    gap=290
    k_origin=(j_origin[0]+j.width+gap,round(j_origin[1]+j26[1]-ka22[1]))
    ksize=(round(legacy['width']*pixels_per_tile),round(legacy['height']*pixels_per_tile))
    kr=raw_k.resize(ksize,Image.Resampling.NEAREST)
    width=k_origin[0]+kr.width+40
    height=round(max(j_origin[1]+j.height,k_origin[1]+kr.height)+180)
    canvas=Image.new('RGB',(width,height),BG)
    canvas.paste(j,j_origin);canvas.paste(kr,k_origin)
    draw=ImageDraw.Draw(canvas)
    label(canvas,(width/2,38),'성도 + 관동 전체 배치와 연결',scale=3,anchor='mt',color=GOLD)
    label(canvas,(j_origin[0]+j.width/2,150),'성도 · HGSS 도시와 도로',scale=2,color=GOLD)
    label(canvas,(k_origin[0]+kr.width/2,k_origin[1]-45),'관동 · FRLG 진행 구성',scale=2,color=GOLD)
    # Restore readable city names after putting the Kanto raster at the common tile scale.
    manifest=json.loads((ROOT/'assets/data/kanto_world_manifest.json').read_text())
    areas={a['id']:a for a in legacy['areas']}
    for folder in manifest['scope']:
        if folder.startswith('Route'):continue
        area=areas[k.fm.snake(folder)]
        point=(k_origin[0]+(area['x']+area['w']/2)*pixels_per_tile,
               k_origin[1]+(area['y']+area['h']/2)*pixels_per_tile)
        label(canvas,point,k.title(folder),scale=1.25)
    sx,sy=manifest['positions']['SaffronCity_Connection']
    label(canvas,(k_origin[0]+(sx+24)*pixels_per_tile,k_origin[1]+(sy+20)*pixels_per_tile),'노랑시티',scale=1.25)
    def offset(origin,p):return (origin[0]+p[0],origin[1]+p[1])
    points={'route26':offset(j_origin,j26),'route28':offset(j_origin,j28),
            'route22':offset(k_origin,ka22),'route23':offset(k_origin,ka23)}
    gate=(j_origin[0]+j.width+gap/2,points['route22'][1])
    # Keep the links in the blank gutter. Pins identify the actual outdoor warps.
    for key,color,dy in [('route26',GOLD,30),('route28',BLUE,-85),('route22',GOLD,30),('route23',BLUE,-85)]:
        p=points[key]
        elbow=(gate[0]+(-82 if key in ['route26','route28'] else 82),p[1])
        port=(gate[0]+(-82 if key in ['route26','route28'] else 82),gate[1]+dy)
        dotted(draw,[p,elbow,port,(gate[0],gate[1]+dy)],color)
        draw.ellipse((p[0]-8,p[1]-8,p[0]+8,p[1]+8),fill=BG,outline=color,width=3)
    label(canvas,(gate[0],gate[1]-26),'리그 접수',scale=1.4,color=GOLD)
    label(canvas,(gate[0],gate[1]+18),'게이트',scale=1.4,color=GOLD)
    label(canvas,(gate[0],gate[1]+90),'남 26 · 서 28',scale=1,color=BLUE)
    label(canvas,(gate[0],gate[1]+125),'동 22 · 북 23',scale=1,color=BLUE)
    label(canvas,(width/2,height-116),'연두마을 ↔ 27번도로·동성폭포 ↔ 26번도로 ↔ 리그 게이트 ↔ 관동 22·23번도로',scale=1.5,color=GOLD)
    label(canvas,(width/2,height-62),'점선은 관문 이동 연결 · 실내·동굴은 별도 지도 · 관동 그림은 배치 확인용',scale=1.25,color=BLUE)
    path=OUT/'kanto_johto_overview.png';canvas.save(path)
    report={'art_source':'existing','kind':'combined atlas and actual gate-link plot, not a single continuous terrain render',
            'sources':[{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [johto_path,kanto_path]],
            'size':list(canvas.size),'pixels_per_tile':pixels_per_tile,'placements':{'johto':list(j_origin),'kanto':list(k_origin)},
            'gate_pins':{k:list(v) for k,v in points.items()},'native_window_opened':False,'gameplay_changed':False}
    (OUT/'combined_source.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    assert canvas.width>j.width and len(report['sources'])==2
    print(path,canvas.size)


if __name__=='__main__':run()
