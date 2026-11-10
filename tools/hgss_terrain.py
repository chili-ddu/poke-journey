"""Retile terrain surfaces with existing HGSS textures; preserve masks/layout.

No generated art and no collision edits. Process one image at a time.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
import hgss_maps as hg

OUT = hg.ROOT / 'assets/maps/hgss_render'
PALETTE = hg.ROOT / 'assets/maps/hgss_pallet_sample/models/terrain_0201_018'
CAVE = hg.ROOT / 'assets/maps/johto_hgss/models/terrain_0479_087'


def pattern(path, size, crop=None):
    image = Image.open(path).convert('RGBA')
    if crop: image = image.crop(crop)
    a = np.asarray(image)
    h, w = size
    return np.tile(a, ((h+a.shape[0]-1)//a.shape[0], (w+a.shape[1]-1)//a.shape[1], 1))[:h,:w]


def convert(source, target, kind, atlas=False, regions=None):
    im = Image.open(source).convert('RGBA')
    a = np.array(im)
    r,g,b,alpha = [a[:,:,i] for i in range(4)]
    valid = (alpha>0)&(np.maximum(np.maximum(r,g),b)>35)
    if regions is not None:
        permitted=np.zeros(a.shape[:2],dtype=bool)
        for x,y,w,h in regions:permitted[y:y+h,x:x+w]=True
        valid &= permitted
    applied = 0
    if kind == 'cave':
        mask = valid & (np.maximum(np.maximum(r,g),b)-np.minimum(np.minimum(r,g),b)<85)
        tile = pattern(CAVE/('dwall_s.png' if atlas else 'droad01.png'),a.shape[:2])
        mask &= tile[:,:,3]>0
        applied += int(np.count_nonzero(mask));a[mask,:3]=tile[mask,:3]
    elif kind == 'outdoor':
        # Source terrain's own color masks preserve every road edge, shadow,
        # water edge and landmark silhouette; only their surface art changes.
        green = valid & (g.astype('int16')-r>4) & (g.astype('int16')-b>4)
        near=np.asarray(Image.fromarray(green.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
        green |= near & (r==238) & (g==255) & (b==255)
        tile = pattern(PALETTE/'grass01gs.png',a.shape[:2])
        applied += int(np.count_nonzero(green));a[green,:3]=tile[green,:3]
        del tile
        path = valid & (r>120) & (g>100) & (r.astype('uint16')*10 > g.astype('uint16')*9) & (g.astype('uint16')*10 > b.astype('uint16')*13)
        tile = pattern(PALETTE/'road01_r.png',a.shape[:2],(13,0,29,8))
        applied += int(np.count_nonzero(path));a[path,:3]=tile[path,:3]
    else:
        # Tile only walkable-looking plain floor tones; furnishings retain
        # their semantic colors and existing footprint.
        mask = valid & (abs(r.astype('int16')-g)<24) & (abs(g.astype('int16')-b)<24) & (r>100)
        floor = hg.ROOT/'assets/maps/hgss_game_source/models/terrain_0366_043/o_kido_yuka1.png'
        tile = pattern(floor,a.shape[:2])
        mask &= tile[:,:,3]>0
        applied += int(np.count_nonzero(mask));a[mask,:3]=tile[mask,:3]
    # Keep the exact original alpha. Never replace object silhouettes.
    target.parent.mkdir(parents=True,exist_ok=True)
    Image.fromarray(a).save(target)
    return applied


def main():
    registry = json.loads((hg.ROOT/'docs/visual_style_review/legacy_registry.json').read_text())
    manifest_path = OUT/'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    terrain, reports = {}, []
    seen=set()
    for place,cfg in registry['maps'].items():
        d=hg.ROOT/cfg['map'].removeprefix('res://')
        if d in seen or not (d/'hd2d_cards.json').exists():continue
        seen.add(d)
        cave=any(place.startswith(n) for n in ['mt_moon','rock_tunnel','digletts_cave','seafoam_islands','victory_road','cerulean_cave','arena_mt_moon'])
        kind='cave' if cave else 'indoor' if cfg['indoor'] else 'outdoor'
        files=['hd2d_floor.png','elevation_floor.png']
        if kind!='indoor': files+=['hd2d_atlas.png','ledge_rock.png','ledge_grass.png']
        entries={}
        metadata=json.loads((d/'hd2d_cards.json').read_text())
        for filename in files:
            p=d/filename
            if not p.exists():continue
            target=OUT/d.name/filename
            regions=None
            if filename=='hd2d_atlas.png' and kind=='outdoor':
                # Shared atlases also contain foliage and object faces. Paint
                # only terrain columns; never turn a tree canopy into lawn.
                regions=[(int(c[3]),int(c[4]),16,int(c[2])*16) for c in metadata.get('cards',[]) if len(c)>9 and c[9]==2]
            changed=convert(p,target,kind,filename in ['hd2d_atlas.png','ledge_rock.png'],regions)
            entries[filename]='res://'+str(target.relative_to(hg.ROOT))
            reports.append(dict(map=d.name,file=filename,pixels=changed,profile=kind))
        if entries:terrain[d.name]=entries
    manifest['terrain']=terrain
    hg.write(manifest_path,manifest)
    hg.write(OUT/'terrain_checks.json',dict(art_source='existing',source='HGSS native terrain textures',maps=len(terrain),files=reports))
    print(json.dumps(dict(maps=len(terrain),textures=len(reports),pixels=sum(r['pixels'] for r in reports))))


def clean_highlights():
    manifest=json.loads((OUT/'manifest.json').read_text())
    records=json.loads((OUT/'terrain_checks.json').read_text())
    fixes=[]
    for item in records['files']:
        if item['profile']!='outdoor' or item['file'] not in ['hd2d_floor.png','elevation_floor.png']:continue
        path=hg.ROOT/manifest['terrain'][item['map']][item['file']].removeprefix('res://')
        a=np.array(Image.open(path).convert('RGBA'))
        green=(a[:,:,0]==115)&((a[:,:,1]==222)|(a[:,:,1]==214))&(a[:,:,2]==173)
        near=np.asarray(Image.fromarray(green.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
        mask=near&(a[:,:,0]==238)&(a[:,:,1]==255)&(a[:,:,2]==255)
        count=int(np.count_nonzero(mask))
        if not count:continue
        tile=pattern(PALETTE/'grass01gs.png',a.shape[:2]);a[mask,:3]=tile[mask,:3]
        Image.fromarray(a).save(path)
        fixes.append(dict(map=item['map'],file=item['file'],pixels=count))
    hg.write(OUT/'highlight_cleanup.json',fixes)
    print(json.dumps(dict(files=len(fixes),pixels=sum(x['pixels'] for x in fixes))))


if __name__=='__main__':
    import sys
    clean_highlights() if '--clean-highlights' in sys.argv else main()
