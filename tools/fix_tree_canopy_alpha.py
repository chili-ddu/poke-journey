"""Patch only shared tree UVs from the corrected generator; preserve all map geometry."""
import hashlib
import json
from PIL import Image
import hd2d_cards as cards

OUT = cards.ROOT / 'docs/tree_canopy_alpha_review'
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records=[]
    for name in cards.TREE_DEFS:
        directory=cards.ROOT/'assets/maps'/name
        protected={p: digest(directory/p) for p in ['map.json','hd2d_cards.json','hd2d_floor.png','bottom.png','top.png']}
        layout=json.loads((directory/'hd2d_cards.json').read_text())
        atlas=Image.open(directory/'hd2d_atlas.png').convert('RGBA')
        before=atlas.copy()
        tree,tip,width,height=cards._tree_template(name)
        old_tree=Image.new('RGBA',tree.size)
        rects=sorted({(c[3],c[4],c[2]) for c in layout['cards'] if len(c)>9 and c[9]==1})
        assert len(rects)==width,(name,'Expected one shared strip per column')
        edits=0
        for x,y,h in rects:
            old=atlas.crop((x,y,x+16,y+h*16))
            matches=[]
            for col in range(width):
                new=tree.crop((col*16,0,(col+1)*16,height*16))
                if old.size==new.size and all(old.getpixel((px,py))==new.getpixel((px,py)) for py in range(old.height) for px in range(16) if old.getpixel((px,py))[3]):
                    matches.append((col,new))
            assert len(matches)==1,(name,'Ambiguous or mismatched native tree',x,y)
            col,new=matches[0]
            old_tree.paste(old,(col*16,0))
            for py in range(old.height):
                for px in range(16):
                    a,b=old.getpixel((px,py)),new.getpixel((px,py))
                    if a!=b:
                        assert a[3]==0 and b[3]==255,'Only missing opacity may be restored'
                        edits+=1
            atlas.paste(new,(x,y))
        # Placement detection must keep the pre-fix fingerprint despite restored tip shades.
        if edits:
            assert tip==[(x,y,old_tree.getpixel((x,y))) for y in range(16) for x in range(width*16) if old_tree.getpixel((x,y))[3]]
        else:
            assert old_tree.tobytes()==tree.tobytes()
        changed=sum(a!=b for a,b in zip(before.getdata(),atlas.getdata()))
        assert changed==edits,'No non-tree atlas pixels may change'
        if edits:atlas.save(directory/'hd2d_atlas.png')
        for file,sha in protected.items():assert digest(directory/file)==sha,(name,file,'must remain unchanged')
        if not (OUT/(name+'_template_before.png')).exists():old_tree.save(OUT/(name+'_template_before.png'))
        tree.save(OUT/(name+'_template_after.png'))
        record={'map':name,'restored_pixels':edits,'tree_strips':sum(len(c)>9 and c[9]==1 for c in layout['cards']),'protected_sha256':protected,'checks':['opaque source colors preserved','only transparent tree pixels restored','matching fingerprint unchanged','map/cards/floor/source images unchanged']}
        records.append(record)
        print(name,edits,'native shading pixels restored')
    if any(r['restored_pixels'] for r in records) or not (OUT/'report.json').exists():
        (OUT/'report.json').write_text(json.dumps(records,indent=2)+'\n')
    print('TREE ALPHA PATCH PASSED:',len(records),'maps')

if __name__=='__main__':main()
