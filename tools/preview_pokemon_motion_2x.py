"""Build the local, lazy-loaded 493-species comparison and pixelfx inputs."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image,ImageDraw
from audit_pokemon_motion_2x import source,cached,frames,REPRESENTATIVES

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/pokemon_2x_rollout'


def sprite(im):
    a=np.array(im.convert('RGBA'));colors=np.unique(a[a[...,3]>0,:3],axis=0)
    palette={};indices={};symbols='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,-/:;<=>?@[]^_`{|}~'
    assert len(colors)<len(symbols)
    for i,c in enumerate(colors):
        symbol=symbols[i];indices[tuple(c)]=symbol;palette[symbol]='#'+''.join(f'{int(v):02x}' for v in c)
    return dict(width=im.width,height=im.height,rows=[''.join(indices[tuple(p[:3])] if p[3] else '.' for p in row) for row in a],palette=palette)


def main():
    species=json.loads((ROOT/'assets/data/species.json').read_text());names=json.loads((ROOT/'assets/data/names_ko.json').read_text())['species']
    sizes=json.loads((ROOT/'assets/data/pokemon_sizes.json').read_text())['species'];roster=[]
    folder=OUT/'roster';folder.mkdir(exist_ok=True)
    for sid,sp in sorted(species.items(),key=lambda x:x[1]['dex']):
        dex=sp['dex'];variants={}
        for shiny in [False,True]:
            base=ROOT/'assets/sprites'/f'{dex:04}'
            if shiny:base/='shiny'
            nodes={a.findtext('Name'):a for a in ET.parse(base/'AnimData.xml').findall('.//Anim')};actions={}
            for action,node in nodes.items():
                name=action;seen=set()
                while name in nodes and nodes[name].findtext('CopyOf') and name not in seen:
                    seen.add(name);name=nodes[name].findtext('CopyOf')
                if name not in nodes:continue
                src=base/(name+'-Anim.png')
                if not src.exists():continue
                n=nodes[name];w,h=int(n.findtext('FrameWidth')),int(n.findtext('FrameHeight'))
                im=Image.open(src);rows=im.height//h
                actions[action]=dict(source='res://'+src.relative_to(ROOT).as_posix(),physical=name,size=[w,h],rows=rows,
                    ticks=[int(v.text) for v in n.findall('./Durations/Duration')],loop=action in {'Walk','Idle','Sleep','Charge','Shoot','Dance','Rotate','Hover','FlapAround','Float','EventSleep','Eat'})
            walk=source(dex,'Walk',shiny);im=Image.open(walk[0]).convert('RGBA');a=actions['Walk'];w,h=a['size'];span=1
            for row in range(a['rows']):
                for k in range(len(a['ticks'])):
                    box=im.crop((k*w,row*h,(k+1)*w,(row+1)*h)).getbbox()
                    if box:span=max(span,box[2]-box[0],box[3]-box[1])
            variants['shiny' if shiny else 'normal']=dict(actions=actions,span=span)
        metadata=dict(dex=dex,sid=sid,name=names.get(sid,sid),display_span=sizes[sid]['display_span'],variants=variants)
        (folder/f'{dex:04}.json').write_text(json.dumps(metadata,separators=(',',':'),ensure_ascii=False)+'\n')
        roster.append({k:metadata[k] for k in ['dex','sid','name']})
    (OUT/'roster.json').write_text(json.dumps(roster,ensure_ascii=False)+'\n')
    (OUT/'index.html').write_text((ROOT/'tools/samples/pokemon_motion_2x_review.html').read_text())
    # All-roster overview: one native source key and its passing pose per row.
    boards=OUT/'overview';boards.mkdir(exist_ok=True);items=[]
    for page in range((len(roster)+23)//24):
        board=Image.new('RGB',(1152,720),'#222a28');draw=ImageDraw.Draw(board)
        for index,sp in enumerate(roster[page*24:(page+1)*24]):
            dex=sp['dex'];f,node=source(dex,'Walk');record=cached(f);original,added,ticks=frames(f,node,record,min(2,record['rows']-1),True)
            x=(index%6)*192;y=(index//6)*180
            draw.text((x+5,y+4),f'{dex:03} {sp["sid"]}',fill='#f1e8d5')
            w,h=original[0].size;sc=min(2,70/max(w,h))
            for side,im in enumerate([original[0],added[1]]):
                im=im.resize((max(1,round(w*sc)),max(1,round(h*sc))),Image.Resampling.NEAREST)
                board.paste(im,(x+side*96+(96-im.width)//2,y+28+(100-im.height)//2),im)
            draw.text((x+5,y+155),'KEY        MID',fill='#aab7ac')
            # Actual pixelfx supplied-pixel rendering, with a transparent-only
            # shared crop for large padded canvases. No model generation.
            if dex in REPRESENTATIVES:
                for action in ['Walk','Attack','Hop']:
                    data=source(dex,action)
                    if not data:continue
                    file,n=data;r=cached(file);keys,mids,ts=frames(file,n,r,min(2,r['rows']-1),action=='Walk')
                    for k in range(len(keys)):
                        if k==len(keys)-1 and action!='Walk':continue
                        pair=[keys[k],mids[2*k+1]];box=pair[0].getbbox();other=pair[1].getbbox()
                        if not box or not other:continue
                        box=(min(box[0],other[0]),min(box[1],other[1]),max(box[2],other[2]),max(box[3],other[3]))
                        variants=[sprite(im.crop(box)) for im in pair]
                        if max(v['width'] for v in variants)>180 or max(v['height'] for v in variants)>170:continue
                        items.append(dict(id=f'{dex:04}-{action}-{k:03}',variants=variants))
        board.save(boards/f'{page+1:02}.png')
    (OUT/'pixelfx-input.json').write_text(json.dumps(items,separators=(',',':'))+'\n')
    print(f'Preview: {len(roster)} species x 2 variants; {page+1} overview boards; {len(items)} native pairs for pixelfx',flush=True)


if __name__=='__main__':main()
