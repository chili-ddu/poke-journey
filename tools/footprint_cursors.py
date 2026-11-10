"""Bake the approved native Pokedex footprints into colored hardware cursors."""
import json
from PIL import Image, ImageFilter
from frlg_npc import ROOT, fetch

COLORS = {
    'charmander':'#ee8938', 'charmeleon':'#d95e4d', 'charizard':'#e68a41',
    'squirtle':'#5abbd1', 'wartortle':'#77a7d3', 'blastoise':'#4f86b5',
    'bulbasaur':'#61b780', 'ivysaur':'#4ba78b', 'venusaur':'#428f76',
}
OUT = ROOT/'assets/ui/cursors'

def build():
    OUT.mkdir(parents=True,exist_ok=True)
    entries={}
    for species,color in COLORS.items():
        source=f'graphics/pokemon/{species}/footprint.png'
        original=Image.open(fetch(source)).convert('L')
        assert original.size==(16,16),species
        mask=Image.new('L',(20,20))
        mask.paste(original.point(lambda value:255 if value<128 else 0),(2,2))
        icon=Image.new('RGBA',(20,20))
        icon.paste('#252020',(0,0,20,20),mask.filter(ImageFilter.MaxFilter(5)))
        icon.paste('#fff1cf',(0,0,20,20),mask.filter(ImageFilter.MaxFilter(3)))
        icon.paste(color,(0,0,20,20),mask)
        icon.resize((40,40),Image.Resampling.NEAREST).save(OUT/(species+'.png'))
        top=next((x,y) for y in range(20) for x in range(20) if mask.getpixel((x,y)))
        entries[species]={'texture':f'res://assets/ui/cursors/{species}.png',
                          'hotspot':[top[0]*2+1,top[1]*2+1], 'color':color,'source':source}
    (OUT/'footprints.json').write_text(json.dumps(entries,indent=2)+'\n')
    print(f'Footprint cursors: {len(entries)} native shapes, 40x40, exact nearest-neighbor pixels')

if __name__=='__main__':build()
