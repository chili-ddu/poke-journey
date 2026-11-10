"""Native outdoor ledge banks and their impassable solid elbows."""
from north_terrain import source_cells, CLIFF_IDS
LEDGE_HEIGHT=0.35
DIRS={'s':(0,1),'n':(0,-1),'e':(1,0),'w':(-1,0)}
CITIES={'pallet_town':'PalletTown','viridian_city':'ViridianCity','pewter_city':'PewterCity','cerulean_city':'CeruleanCity','vermilion_city':'VermilionCity'}
CITIES.update({'lavender_town':'LavenderTown','celadon_city':'CeladonCity','fuchsia_city':'FuchsiaCity',
               'cinnabar_island':'CinnabarIsland','indigo_plateau_exterior':'IndigoPlateau_Exterior',
               'route21_north':'Route21_North','route21_south':'Route21_South'})

def topology(j):
    folders=[j.get('native_folders',{}).get(a['id'],CITIES.get(a['id'],a['id'].replace('route','Route'))) for a in j['areas']]
    mids=source_cells(j,folders)
    roads=[a for a in j['areas'] if a['id'].startswith('route')]
    ledges={xy:j['ledge'][xy[1]][xy[0]] for xy in mids if j['ledge'][xy[1]][xy[0]]!='0' and any(a['x']<=xy[0]<a['x']+a['w'] and a['y']<=xy[1]<a['y']+a['h'] for a in roads)}
    turns={xy for xy,mid in mids.items() if mid in {0x8d,0x8e} and j['solid'][xy[1]][xy[0]]=='1' and any((xy[0]+dx,xy[1]+dy) in ledges for dx,dy in DIRS.values())}
    band=set(ledges)|turns
    for xy,mid in mids.items():
        if xy in band or mid not in CLIFF_IDS or j['solid'][xy[1]][xy[0]]!='1':continue
        x,y=xy;attached=[(dx,dy) for dx,dy in DIRS.values() if (x+dx,y+dy) in band]
        if any(ax*bx+ay*by==0 for ax,ay in attached for bx,by in attached):turns.add(xy)
    return ledges,turns,mids
