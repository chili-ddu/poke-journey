"""Fetch only missing, declared PMD animations for the new Kanto wild species.
Never overwrites existing/custom art. Native metadata resolves animation aliases.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from pmd_fetch import ROOT, RAW, ANIMS
DEXES=[21,23,29,32,35,39,41,43,46,52,56]

def fetch(job):
    url,path=job
    if path.exists():return
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url,timeout=30) as response:data=response.read()
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
            return
        except urllib.error.HTTPError as error:
            # Some older/custom local metadata declares optional poses that
            # the upstream sheet no longer supplies. Runtime pose fallbacks
            # handle those; the required Walk sheet is validated below.
            if error.code==404 and path.suffix=='.png':return
            if attempt==2:raise RuntimeError(f'Unable to fetch {url}: {error}') from error
        except Exception as error:
            if attempt==2:raise RuntimeError(f'Unable to fetch {url}: {error}') from error

def main(dexes=None):
    dexes=DEXES if dexes is None else dexes
    variants=[(dex,shiny) for dex in dexes for shiny in [False,True]]
    def base(dex,shiny):
        local=ROOT/'assets/sprites'/f'{dex:04d}'
        remote=RAW+f'{dex:04d}/'
        return (local/'shiny',remote+'0000/0001/') if shiny else (local,remote)
    with ThreadPoolExecutor(max_workers=8) as pool:
        jobs=[]
        for dex,shiny in variants:
            local,remote=base(dex,shiny)
            jobs.extend((remote+name,local/name) for name in ['AnimData.xml','credits.txt'])
        list(pool.map(fetch,jobs))
        jobs=[]
        for dex,shiny in variants:
            local,remote=base(dex,shiny)
            anims={a.findtext('Name'):a for a in ET.parse(local/'AnimData.xml').findall('.//Anim')}
            needed=set()
            for name in ANIMS:
                seen=set()
                while name in anims and name not in seen:
                    seen.add(name)
                    alias=anims[name].findtext('CopyOf')
                    if not alias:
                        needed.add(name);break
                    name=alias
            for name in sorted(needed):
                for suffix in ['-Anim.png','-Offsets.png']:
                    file=name+suffix;jobs.append((remote+file,local/file))
        list(pool.map(fetch,jobs))
    for dex,shiny in variants:
        local,_=base(dex,shiny)
        assert (local/'Walk-Anim.png').exists(),local
    print(f'Wild species assets ready: {len(dexes)} species, normal + shiny; {len(jobs)} declared sheets (existing files preserved)',flush=True)
if __name__=='__main__':main()
