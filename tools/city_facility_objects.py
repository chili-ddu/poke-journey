"""FRLG 고유 시설: 원본 픽셀 경계로 사물/벽/바닥을 분리한다. 새 그림을 생성하지 않는다."""
from collections import deque
import json
import math
from PIL import Image

MAPS = {'cerulean_city_bike_shop', 'vermilion_city_pokemon_fan_club',
        'cerulean_city_gym', 'vermilion_city_gym'}
T = 16

def specifications(name):
    objects = []
    def add(id, kind, rect, **kw):
        objects.append(dict(id=id, kind=kind, rect=rect, **kw))
    if name == 'cerulean_city_bike_shop':
        for i,x in enumerate([16,48]):
            add(f'spare_parts_shelf_{i}','box',[x,19,x+32,48],front=25,z1=3,depth=.6,wall=152,donor=[6,4])
        for i,(x,y) in enumerate([(26,48),(58,48),(10,64),(58,64),(26,80),(58,80),(26,112),(26,128)]):
            add(f'display_bicycle_{i}','card',[x,y,x+22,y+16],donor=[6,4],z1=(y+15)/T,height=1.0)
        add('potted_plant','card',[80,37,96,64],donor=[6,4],z1=4,height=1.6875)
        for i,r in enumerate([(96,19,111,29),(113,18,127,24)]):
            add(f'wall_spare_part_{i}','card',list(r),wall=144,base=.65,z1=2.01)
        add('glass_counter','box',[128,51,144,80],front=75,z1=5,depth=1.5,donor=[6,4])
        add('counter_extension','box',[144,64,176,80],front=76,z1=5,depth=.75,donor=[6,4])
        add('counter_cabinet','box',[160,80,176,96],front=82,z1=6,depth=.75,donor=[6,4])
        add('cash_register','card',[128,35,144,51],donor=[6,4],base=5/T,z1=3.45)
        for i,(x,y) in enumerate([(128,98),(144,128)]):
            add(f'repair_toolbox_{i}','card',[x,y,x+16,y+14],donor=[6,4],z1=(y+14)/T)
    elif name == 'vermilion_city_pokemon_fan_club':
        for i,x in enumerate([64,96]):
            add(f'bookshelf_{i}','box',[x,11,x+32,40],front=17,z1=2.5,depth=.6,wall=56)
        for i,x in enumerate([33,145]):
            add(f'wall_notice_{i}','card',[x,9,x+14,23],wall=56,base=.85,z1=2.01)
        # Table glass lies horizontally. Upholstered seats have separate cushions/backrests.
        add('club_table','table',[80,80,112,109],front=105,z0=5,z1=6.875,depth=1.5625,donor=[3,4],height=.25,base=.35,erase=[80,80,112,112])
        add('sofa_north_cushion','box',[80,70,112,80],front=77,z1=5,depth=.75,donor=[3,4],height=.35)
        add('sofa_north_back','card',[80,56,112,70],donor=[3,4],base=.35,z1=4.4,height=.875)
        for side,x in [('west',64),('east',112)]:
            # Source front/side view retained; do not invent a mirrored sofa drawing.
            add('sofa_'+side,'card',[x,80,x+16,112],donor=[3,4],z1=7,height=1.5)
        for i,(x,y) in enumerate([(0,52),(176,52),(0,148),(176,148)]):
            add(f'potted_plant_{i}','card',[x,y,x+16,y+28],donor=[1,4 if y<100 else 9],z1=(y+28)/T,height=1.75)
        for i,(x,y) in enumerate([(0,80),(0,112),(176,80),(176,112)]):
            add(f'flower_display_{i}','box',[x,y,x+16,y+32],front=y+27,z1=(y+32)/T,depth=1.6875,donor=[1,5],height=.3125)
    else:
        blue = name == 'cerulean_city_gym'
        for i,x in enumerate([96,160] if blue else [48,112]):
            add(f'statue_pedestal_{i}','box',[x,274,x+16,288],front=276,z1=18,depth=.75,donor=[8,17] if blue else [5,18],height=.75)
            add(f'gym_statue_{i}','card',[x,256,x+16,274],donor=[8,17] if blue else [5,18],z1=17.75,base=.75,height=1.125)
        if blue:
            for i,(x,y) in enumerate([(48,72),(208,72),(48,280),(208,280)]):
                add(f'pool_ladder_{i}','card',[x,y,x+16,y+16],z1=(y+16)/T,height=.75,donor=[4,4] if y<100 else [2,17],donor_after=[2,5] if y<100 else [4,18],donor_split=y+8)
            for i,x in enumerate([85,117,149,181]):
                add(f'wall_lamp_{i}','card',[x,22,x+11,33],wall=64,base=.875,z1=3.01)
            add('cascade_emblem','card',[128,5,144,22],wall=64,base=1.8,z1=3.01)
        else:
            for row,y in enumerate([160,192,224]):
                for col,x in enumerate([16,48,80,112,144]):
                    add(f'trash_can_{row}_{col}','box',[x+1,y+1,x+15,y+15],front=y+7,z1=(y+15)/T,depth=.75,donor=[5,18],height=.5)
            for i,x in enumerate([48,112]):
                add(f'power_column_{i}','box',[x,16,x+16,56],front=22,z1=3.4,depth=.375,wall=144,height=2.125)
            add('leader_platform','box',[64,27,112,52],front=49,z1=3.3,depth=1.375,donor=[5,4],height=.1875)
            for i,r in enumerate([(20,17,40,30),(132,17,152,30),(20,113,40,126),(148,113,168,126)]):
                add(f'wall_vent_{i}','card',list(r),wall=144 if i<2 else 16,base=.6,z1=2.01 if i<2 else 8.01)
            add('thunder_emblem','card',[80,6,96,16],wall=144,base=1.5,z1=2.01)
            for i,x in enumerate([32,128]):
                add(f'barrier_terminal_{i}','box',[x,103,x+16,142],front=119,z1=8.8,depth=.75,donor=[5,9],height=1.4375)
            add('electric_barrier','card',[56,102,120,121],donor=[5,9],z1=7.6,height=1.1875)
    return objects

def build(d,j,name,specs=None):
    w,h,p=j['width'],j['height'],j.get('pad',0)
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p*T,p*T,(p+w)*T,(p+h)*T))
    clean=raw.copy(); specs=specifications(name) if specs is None else specs; tables=[]; provenance=[]
    def background(s,x,y):
        if y< (48 if name=='cerulean_city_gym' else 32) and 'wall' in s:
            return raw.getpixel((s['wall'],y))
        if 'floor_color' in s:
            return raw.getpixel(tuple(s['floor_color']))
        dx,dy=s.get('donor_after') if y>=s.get('donor_split',100000) else s.get('donor',[1,3])
        if x<s.get('donor_xsplit',-1) and y<s.get('donor_left_until',100000):dx,dy=s['donor_left']
        return raw.getpixel((dx*T+x%T,dy*T+y%T))
    for s in specs:
        x0,y0,x1,y1=s['rect']
        assert 0<=x0<x1<=w*T and 0<=y0<y1<=h*T, (name,s['id'],'source bounds')
        art=raw.crop((x0,y0,x1,y1)); candidates=set()
        for y in range(art.height):
            for x in range(art.width):
                if art.getpixel((x,y))==background(s,x0+x,y0+y): candidates.add((x,y))
        q=deque(c for c in candidates if c[0] in (0,art.width-1) or c[1] in (0,art.height-1));seen=set(q)
        while q:
            x,y=q.popleft();art.putpixel((x,y),(0,0,0,0))
            for nxt in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if nxt in candidates and nxt not in seen:seen.add(nxt);q.append(nxt)
        if s.get('remove_faucet'):
            for y in range(18,24):
                for x in range(7,15):art.putpixel((x-x0,y-y0),raw.getpixel((16,y)))
        tex='hd2d_facility_'+s['id']; z1=s.get('z1',y1/T)
        common=dict(id=s['id'],x0=x0/T,x1=x1/T,z0=z1,z1=z1,tex=tex,base=s.get('base',0))
        if s['kind'] in ('card','decal'):
            art.save(d/(tex+'_front.png'));common.update(card=True,h=s.get('height',(y1-y0)/T))
            if s['kind']=='decal':common.update(decal=True,z0=y0/T,z1=y1/T,base=.012)
        elif s['kind']=='table':
            split=s['front']-y0; under=s.get('under',s['front']+2)-y0
            depth=s.get('depth',split/T)
            art.crop((0,0,art.width,split)).save(d/(tex+'_top.png'))
            edge=art.crop((0,split,art.width,under));edge.save(d/(tex+'_edge.png'))
            edge.crop((1,0,2,edge.height)).resize((max(1,round(depth*T)),edge.height),Image.Resampling.NEAREST).save(d/(tex+'_eside.png'))
            legs=s.get('legs',[[x0+1,x0+4],[x1-4,x1-1]])
            leg=s.get('leg',.375); a,b=legs[0]
            art.crop((a-x0,under,b-x0,art.height)).resize((b-a,round(leg*T)),Image.Resampling.NEAREST).save(d/(tex+'_leg.png'))
            common.update(z0=s.get('z0',z1-depth),z1=z1,leg=leg,thick=(under-split)/T,
                          legs=[[a/T,b/T] for a,b in legs],leg_w=(b-a)/T,pedestal=None,apron=0,decor=None)
        else:
            split=s['front']-y0; top=art.crop((0,0,art.width,split));front=art.crop((0,split,art.width,art.height))
            top.save(d/(tex+'_top.png'));front.save(d/(tex+'_front.png'))
            depth=s.get('depth',split/T);side=front.crop((min(2,front.width-1),0,min(2,front.width-1)+1,front.height)).resize((max(1,round(depth*T)),front.height),Image.Resampling.NEAREST)
            side.save(d/(tex+'_side.png'));common.update(box=True,closed=True,z0=z1-depth,h=s.get('height',front.height/T))
        tables.append(common);provenance.append(dict(id=s['id'],kind=s['kind'],source=s['rect'],tex=tex))
        ex0,ey0,ex1,ey1=s.get('erase',s['rect'])
        assert 0<=ex0<ex1<=w*T and 0<=ey0<ey1<=h*T, (name,s['id'],'erase bounds')
        for y in range(ey0,ey1):
            for x in range(ex0,ex1):clean.putpixel((x,y),background(s,x,y))
    rows=3 if name=='cerulean_city_gym' else 2
    # Keep one rear plane; a shelf extending onto the floor must not pull the wall forward.
    atlas=clean.crop((0,0,w*T,rows*T));cards=[[x,0,rows,x*T,0,0,1,0,0] for x in range(w)]
    if name=='vermilion_city_gym':
        # Internal wall wings stop at the central opening. The electric beam is a separate object.
        wings=clean.crop((0,96,w*T,128));extended=Image.new('RGBA',(w*T,(rows+2)*T));extended.paste(atlas,(0,0));extended.paste(wings,(0,rows*T));atlas=extended
        cards += [[x,6,2,x*T,rows*T,0,1,0,0] for x in list(range(0,3))+list(range(8,11))]
    atlas.save(d/'hd2d_atlas.png')
    floor=Image.open(d/'bottom.png').convert('RGBA');floor.paste(clean,(p*T,p*T));floor.save(d/'hd2d_floor.png')
    # Source collision stays authoritative. Opening the statue's upper image row allows walking behind it.
    opened=[]
    for s in specs:
        if s['id'].startswith('gym_statue_'):opened.append([s['rect'][0]//T,16])
    (d/'collision_patch.json').write_text(json.dumps(dict(open=opened,block=[])))
    return dict(tile=T,cards=cards,houses=[],props=[],tables=tables,facility_objects=provenance,wall_rows=rows)
