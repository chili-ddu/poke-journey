"""Bake Bill's original house, human sprite reproducibly."""
import json,sys
import frlg_map as fm
import frlg_npc
from cerulean_progression import definitions

def build():
    definitions()
    from bill_research_assets import main as research_assets
    research_assets()
    fm.bake(['Route25_SeaCottage'],'route25_sea_cottage',None,False)
    path=fm.ROOT/'assets/maps/route25_sea_cottage/map.json'
    data=json.loads(path.read_text());data['start']=[7*16+8,8*16+8]
    path.write_text(json.dumps(data,ensure_ascii=False,indent=0)+'\n')
    import hd2d_cards
    hd2d_cards.build('route25_sea_cottage')
    original=sys.argv
    try:
        sys.argv=['frlg_npc.py','bill:npc_blue'];frlg_npc.main()
    finally:sys.argv=original
if __name__=='__main__':build()
