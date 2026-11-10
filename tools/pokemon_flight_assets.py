"""Fetch missing native flight poses for installed species; preserve existing art."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import xml.etree.ElementTree as ET
from PIL import Image
from kanto_wild_assets import fetch
from pmd_fetch import ROOT, RAW

def main():
    rules=json.loads((ROOT/'assets/data/pokemon_flight.json').read_text())
    species=json.loads((ROOT/'assets/data/species.json').read_text())
    jobs=[];sheets=[]
    for sid,sp in species.items():
        if sid in rules['excluded'] or not (sid in rules['additional'] or 'HM02' in sp.get('tms',[])):continue
        preferred=rules['hover_animation'] if sid in rules['hover'] else rules['wing_animation']
        preferred=rules.get('animation_overrides',{}).get(sid,preferred)
        for shiny in [False,True]:
            local=ROOT/'assets/sprites'/f'{sp["dex"]:04d}'
            remote=RAW+f'{sp["dex"]:04d}/'
            if shiny:local=local/'shiny';remote+='0000/0001/'
            if not (local/'AnimData.xml').exists():continue
            anims={a.findtext('Name'):a for a in ET.parse(local/'AnimData.xml').findall('.//Anim')}
            name=preferred;seen=set()
            while name in anims and anims[name].findtext('CopyOf'):
                assert name not in seen;seen.add(name);name=anims[name].findtext('CopyOf')
            if name not in anims:continue
            a=anims[name]
            for suffix in ['-Anim.png','-Offsets.png']:
                path=local/(name+suffix)
                if not path.exists():jobs.append((remote+path.name,path))
                sheets.append((path,a))
    with ThreadPoolExecutor(max_workers=8) as pool:list(pool.map(fetch,jobs))
    for path,a in sheets:
        fw,fh=int(a.findtext('FrameWidth')),int(a.findtext('FrameHeight'))
        n=len(a.findall('./Durations/Duration'))
        with Image.open(path) as image:
            assert image.width==fw*n and image.height%fh==0,(path,image.size,fw,fh,n)
    print(f'Flight poses ready: {len(jobs)} missing native files added, {len(sheets)} sheets validated; existing files preserved')

if __name__=='__main__':main()
