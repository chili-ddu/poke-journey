"""3·4번도로 절벽/바위: 원본 메타타일로 분류해 불투명 바위색을 보존한다."""
from collections import deque
import json
import struct
from PIL import Image
import frlg_map as fm

CLIFF_IDS = {0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6f,0x70,0x71,0x72,0x73,0x75,
             0x78,0x79,0x7a,0x7b,0x7c,0x7d,0x80,0x81,0x82,0x88,0x8a,0x8d,0x8e,
             0x90,0x92,0xa1,0xa8,0xb2,0xb3,0xba,0xbb,0x1f1,0x1f2,0x1f3,0x1f4,0x20f}
ROCK_IDS={0x9f,0xb7}

def source_cells(j,folders):
    result={}
    for folder in folders:
        area=next(a for a in j['areas'] if a['id']==fm.snake(folder))
        lay=fm.layout_of(fm.map_json(folder)['layout'])
        vals=struct.unpack('<'+'H'*(lay['width']*lay['height']),fm.fetch(lay['blockdata_filepath']).read_bytes())
        for i,v in enumerate(vals): result[(i%lay['width']+area['x'],i//lay['width']+area['y'])]=v&1023
    return result

def remove_cells(cards,cells):
    result=[]
    for card in cards:
        if len(card)>9 and card[9]==1:result.append(card);continue
        offset=0
        while offset<card[2]:
            if (card[0],card[1]+offset) in cells:offset+=1;continue
            start=offset
            while offset<card[2] and (card[0],card[1]+offset) not in cells:offset+=1
            part=list(card);part[1]+=start;part[2]=offset-start;part[4]+=start*16
            part[5]=max(0,min(part[2]-1,card[5]-start))
            if offset<card[2] and len(part)>8:part[8]=0
            result.append(part)
    return result

def cut_background(art,colors):
    # Only exact source floor colors are candidates. Rock colors never enter this set.
    candidates={(x,y) for y in range(art.height) for x in range(art.width) if art.getpixel((x,y)) in colors}
    q=deque(c for c in candidates if c[0] in (0,art.width-1) or c[1] in (0,art.height-1));seen=set(q)
    while q:
        x,y=q.popleft();art.putpixel((x,y),(0,0,0,0))
        for c in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if c in candidates and c not in seen:seen.add(c);q.append(c)
    return art

def build(d,j,metadata):
    t=16;p=j.get('pad',0);w,h=j['width'],j['height']
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p*t,p*t,(p+w)*t,(p+h)*t))
    cells=source_cells(j,['Route3','Route4'])
    cliffs={xy for xy,mid in cells.items() if mid in CLIFF_IDS and j['ledge'][xy[1]][xy[0]]=='0'}
    props={xy:mid for xy,mid in cells.items() if mid in ROCK_IDS or mid==2}
    # Plain source ground only; signs/warps/ledge artwork cannot become a floor donor.
    donors={xy:xy for xy,mid in cells.items() if mid in (8,9,0xd9) and j['solid'][xy[1]][xy[0]]=='0'}
    colors=set()
    for x,y in donors:colors.update(raw.crop((x*t,y*t,(x+1)*t,(y+1)*t)).getdata())
    nearest=dict(donors);q=deque(nearest)
    while q:
        x,y=q.popleft()
        for n in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0<=n[0]<w and 0<=n[1]<h and n not in nearest:nearest[n]=nearest[x,y];q.append(n)
    metadata['cards']=remove_cells(metadata['cards'],cliffs|props.keys())
    old=Image.open(d/'hd2d_atlas.png').convert('RGBA');strips=[];columns=[];indices={}
    for x in range(w):
        y=0
        while y<h:
            if (x,y) not in cliffs:y+=1;continue
            start=y
            while y<h and (x,y) in cliffs:y+=1
            n=y-start;art=cut_background(raw.crop((x*t,start*t,(x+1)*t,y*t)),colors);key=(n,art.tobytes())
            if key not in indices:indices[key]=len(strips);strips.append(art)
            columns.append((x,start,n,indices[key]))
    stride=max(im.height for im in strips);cols=old.width//t
    atlas=Image.new('RGBA',(old.width,old.height+((len(strips)+cols-1)//cols)*stride));atlas.paste(old,(0,0))
    for i,im in enumerate(strips):atlas.paste(im,((i%cols)*t,old.height+(i//cols)*stride))
    atlas.save(d/'hd2d_atlas.png')
    for x,y,n,i in columns:
        face=strips[i].crop((0,(n-1)*t,t,n*t))
        side=max(range(t),key=lambda xx:sum(face.getpixel((xx,yy))[3]>0 and face.getpixel((xx,yy)) not in colors for yy in range(t)))
        metadata['cards'].append([x,y,n,(i%cols)*t,old.height+(i//cols)*stride,max(0,n-1),1,0,0,2,side])
    objects=[]
    for (x,y),mid in props.items():
        id=('rock' if mid in ROCK_IDS else 'sign')+f'_{x}_{y}';tex='hd2d_terrain_'+id
        cut_background(raw.crop((x*t,y*t,(x+1)*t,(y+1)*t)),colors).save(d/(tex+'_front.png'))
        metadata['tables'].append(dict(id=id,card=True,x0=x,x1=x+1,z0=y+1,z1=y+1,h=.875 if mid in ROCK_IDS else 1,base=0,tex=tex))
        objects.append(dict(id=id,tile=[x,y],mid=mid))
    floor=Image.open(d/'hd2d_floor.png').convert('RGBA')
    for x,y in cliffs|props.keys():
        a,b=nearest[x,y];floor.paste(raw.crop((a*t,b*t,(a+1)*t,(b+1)*t)),((x+p)*t,(y+p)*t))
    floor.save(d/'hd2d_floor.png')
    metadata['north_terrain']=dict(cliff_tiles=[list(c) for c in sorted(cliffs)],objects=objects,wall_height=1,
                                  source='Route3, Route4',entrances=[dict(x=a['x'],y=a['y'],to=a['to']) for a in j['warps'] if a['map']=='route4'])
    return metadata
