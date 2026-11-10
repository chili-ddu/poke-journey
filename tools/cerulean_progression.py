"""Native FRLG Cerulean trainers and reachable Route24/25; preserve existing field art."""
import json,re
from pathlib import Path
import frlg_map as fm
import kanto_wild
from frlg_npc import fetch
ROOT=fm.ROOT
OUT=ROOT/'assets/maps'

def party(name):
    text=fetch('src/data/trainer_parties.h').read_text()
    body=re.search(r'\bsParty_'+name+r'\[\] = \{(.*?)\n\};',text,re.S)[1]
    result=[]
    for member in re.findall(r'\{(.*?)\}',body,re.S):
        level=re.search(r'\.lvl = (\d+)',member);species=re.search(r'\.species = SPECIES_(\w+)',member)
        if not level or not species:continue
        entry=[species[1].lower(),int(level[1])]
        moves=re.findall(r'MOVE_(\w+)',member)
        if moves:entry.append([m.lower() for m in moves if m!='NONE'])
        result.append(entry)
    assert result,name
    return result

def dump(value):
    return re.sub(r'"(tile|talk_tile)": \[\s*(\d+),\s*(\d+)\s*\]',lambda m:'"'+m[1]+'": Vector2i('+m[2]+', '+m[3]+')',json.dumps(value,ensure_ascii=False,indent=2))

def definitions():
    trainers={}
    def add(id,kind,name,ko,p,arena,**extra):
        trainers[id]=dict({'class':kind,'name':name,'name_ko':ko,'party':party(p),'arena':arena,
            'intro':{'ko':['여기까지 혼자 온 포켓몬이네!\n내 포켓몬과 겨뤄 볼래?'],'en':['A POKéMON traveling alone!\nWill you battle my team?']},
            'defeat':{'ko':['멋진 승부였어!\n이 열매를 받아 줘.'],'en':['That was a great battle!\nTake these berries.']},
            'after':{'ko':['다음 길에서도 힘내!'],'en':['Good luck on your journey!']}},**extra)
    add('route4_lass_crissy','lass','CRISSY','크리시','LassCrissy','arena_route1')
    add('cerulean_swimmer_luis','swimmer','LUIS','루이스','SwimmerMaleLuis','arena_cerulean_gym')
    add('cerulean_picnicker_diana','picnicker','DIANA','다이애나','PicnickerDiana','arena_cerulean_gym')
    add('leader_misty','leader','MISTY','이슬','LeaderMisty','arena_cerulean_gym',sprite='misty',gym={},
        cutin={'mugshot':'plat/enc_mugshot_misty','banner':'plat/enc_leader_banner_water'},
        berry_reward={'sitrus_berry':3,'leppa_berry':2,'lum_berry':1},
        intro={'ko':['어머? 트레이너는 어디 두고\n포켓몬 혼자 들어온 거야?','…나한테 도전하겠다고?\n후훗, 꽤 배짱이 있는데!','좋아! 나는 블루시티 체육관 관장,\n물 포켓몬 전문가 이슬이야!','귀엽다고 봐줄 생각은 없어!\n내 물 포켓몬들과 겨뤄 보자!'],
            'en':["Oh? Where's your TRAINER?\nYou came in all by yourself?","…You're challenging me?\nHehe! You've got some nerve!","I'm MISTY, CERULEAN's GYM LEADER,\nand a WATER POKéMON expert!","Being cute won't save you!\nLet's see you face my WATER team!"]},
        defeat={'ko':['아, 정말! 내가 지다니…\n혼자 왔다고 얕볼 게 아니었네!','좋아, 네 실력은 인정할게!\n이 열매들, 잘 챙겨 둬!'],
            'en':["Oh, come on! I lost…\nI underestimated you!","All right, I respect your skill!\nTake good care of these berries!"]},
        after={'ko':['다음에도 그렇게 쉽게\n이길 수 있을 거라고 생각하지 마!','여행하다 지치면 또 들러.\n내 물 포켓몬들도 기다릴 테니까!'],
            'en':["Don't think you'll beat me\nso easily next time!","Tired from traveling? Drop by!\nMy WATER POKéMON will be waiting!"]})
    for starter in ['Squirtle','Bulbasaur','Charmander']:
        add('rival_cerulean_'+starter.lower(),'rival','GREEN','그린','RivalCerulean'+starter,'arena_route1',
            berry_reward={'oran_berry':2,'sitrus_berry':1,'leppa_berry':1},
            intro={'ko':['또 만났네! 달맞이산도\n혼자 넘어왔단 말이지?','그동안 내 구구도 자랐어.\n이번엔 네 마리로 상대해 주지!'],'en':['You made it through MT MOON\non your own? Impressive!','My PIDGEY has grown too!\nFace my team of four!']},
            defeat={'ko':['쳇, 또 졌네!\n다음엔 꼭 내가 이길 거야.'],'en':["Hmph! I lost again!\nI'll win next time!"]},
            after={'ko':['북쪽에도 실력 좋은\n트레이너들이 기다리고 있어!'],'en':['Strong TRAINERS are waiting\non the northern routes!']})
    gym=dict(name='CERULEAN CITY GYM',name_ko='블루시티 체육관',theme='cerulean_city_gym',indoor=True,count=0,encounters=[],arena='arena_cerulean_gym',trainers=[
        {'trainer':'leader_misty','tile':[8,6],'face':'down','sight':0}],npcs=[
        {'id':'gym_luis','sprite':'swimmer_m_water','talk':'gym_surprised','tile':[10,12],'face':'left','talk_tile':[9,12]},
        {'id':'gym_diana','sprite':'picnicker','talk':'gym_surprised','tile':[4,7],'face':'right','talk_tile':[5,7]}])
    north=dict(name='CERULEAN NORTH',name_ko='블루시티 북부',theme='cerulean_north',overworld=True,count=0,encounters=[],areas={
        'route24':json.loads(kanto_wild.area('Route24','24번도로')),'route25':json.loads(kanto_wild.area('Route25','25번도로'))})
    data={'THEMES':{'cerulean_north':{'map':'res://assets/maps/cerulean_north','tiles':{}},'arena_cerulean_gym':{'map':'res://assets/maps/arena_cerulean_gym','tiles':{}}},
        'WARP_MAPS':{'route24':'cerulean_north','route25':'cerulean_north'},
        'DUNGEONS':{'cerulean_north':north,'cerulean_city_gym':gym,'arena_cerulean_gym':dict(name='CERULEAN GYM',name_ko='블루시티 체육관',theme='arena_cerulean_gym',battle_style='room',arena_field=True,count=0,encounters=[])},
        'TRAINERS':trainers,'FIELD_TRAINERS':[{'trainer':'route4_lass_crissy','area':'route4','tile':[75,3],'face':'right','sight':3}],
        'MUSIC':{'cerulean_north':'mus_route24','route24':'mus_route24','route25':'mus_route24'}}
    data['THEMES']['route25_sea_cottage']={'map':'res://assets/maps/route25_sea_cottage','tiles':{}}
    data['WARP_MAPS']['route25_sea_cottage']='route25_sea_cottage'
    data['DUNGEONS']['route25_sea_cottage']=dict(name="BILL'S COTTAGE",name_ko='이수재의 집',theme='route25_sea_cottage',indoor=True,count=0,encounters=[])
    data['MUSIC']['route25_sea_cottage']='mus_fuchsia'
    (ROOT/'scripts/data/cerulean_progression.gd').write_text('# Generated by tools/cerulean_progression.py; original FRLG parties and coordinates.\nextends RefCounted\n'+''.join('const '+k+' := '+dump(v)+'\n' for k,v in data.items()))
    print({k:v['party'] for k,v in trainers.items()})

def polish_bridge():
    # Native rail pairs are half-height fences, not two-metre standing billboards.
    d=OUT/'cerulean_north';f=d/'hd2d_cards.json';meta=json.loads(f.read_text())
    for card in meta['cards']:
        if card[0] in [9,13] and card[1]>=16 and card[1]+card[2]<=36:
            card[6]=0.25
    f.write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')

def link_north():
    """Add reversible edge transitions; never shift old save coordinates or rebake old art."""
    north_dir=OUT/'cerulean_north';j=json.loads((north_dir/'map.json').read_text())
    city_native=fm.bake_layout(fm.layout_of(fm.map_json('CeruleanCity')['layout']))
    road_native=fm.bake_layout(fm.layout_of(fm.map_json('Route24')['layout']))
    # Bottom of Route24 x corresponds to city x+12. Both sides need two clear rows.
    lanes=[x for x in range(1,23) if all(road_native['solid'][39-y][x]==0 and city_native['solid'][y][x+12]==0 for y in [0,1])]
    assert lanes, 'Native Cerulean/Route24 connection is missing'
    rows=[list(r) for r in j['solid']]
    j['warps']=[w for w in j['warps'] if not w.get('cerulean_north_link')]
    for x in lanes:
        rows[39][x]='0'
        j['warps'].append(dict(x=x,y=39,map='route24',index=2000+x,to='cerulean_city',to_warp=2000+x,arrival_dir=[0,-1],edge_transition=True,cerulean_north_link=True))
    j['solid']=[''.join(r) for r in rows]
    j['start']=[(lanes[len(lanes)//2])*16+8,38*16+8]
    (north_dir/'map.json').write_text(json.dumps(j,ensure_ascii=False,indent=0)+'\n')
    for name in ['kanto_field','kanto_north']:
        d=OUT/name;m=json.loads((d/'map.json').read_text());city=next(a for a in m['areas'] if a['id']=='cerulean_city')
        m['warps']=[w for w in m['warps'] if not w.get('cerulean_north_link')]
        rows=[list(r) for r in m['solid']]
        pf=d/'collision_patch.json';patch=json.loads(pf.read_text()) if pf.exists() else {'open':[],'block':[]}
        cells={(city['x']+x+12,city['y']) for x in lanes}
        patch['block']=[c for c in patch.get('block',[]) if tuple(c) not in cells]
        patch['open']=[c for c in patch.get('open',[]) if tuple(c) not in cells]+[list(c) for c in sorted(cells)]
        for x in lanes:
            xx=city['x']+x+12;yy=city['y'];rows[yy][xx]='0'
            m['warps'].append(dict(x=xx,y=yy,map='cerulean_city',index=2000+x,to='route24',to_warp=2000+x,arrival_dir=[0,1],edge_transition=True,cerulean_north_link=True))
        m['solid']=[''.join(r) for r in rows]
        (d/'map.json').write_text(json.dumps(m,ensure_ascii=False,indent=0)+'\n');pf.write_text(json.dumps(patch,ensure_ascii=False,indent=2)+'\n')
        # Remove the artificial border cards over the newly restored source walking lanes.
        from north_terrain import remove_cells
        cf=d/'hd2d_cards.json';cards=json.loads(cf.read_text());cards['cards']=remove_cells(cards['cards'],cells);cf.write_text(json.dumps(cards,ensure_ascii=False,indent=2)+'\n')
    print('Cerulean/Route24 walking lanes',lanes)

if __name__=='__main__':
    definitions()
    import sys
    if '--maps' in sys.argv:
        fm.bake(['Route24','Route25'],'cerulean_north',None,True)
        from kanto_water import rows as water_rows
        d=OUT/'cerulean_north';j=json.loads((d/'map.json').read_text());mask=[list('0'*j['width']) for _ in range(j['height'])]
        for a in j['areas']:
            for y,row in enumerate(water_rows('Route24' if a['id']=='route24' else 'Route25')):
                mask[y+a['y']][a['x']:a['x']+a['w']]=list(row)
        (d/'water.json').write_text(json.dumps({'water':[''.join(r) for r in mask]})+'\n')
        import hd2d_cards
        hd2d_cards.build('cerulean_north')
        polish_bridge()
        link_north()
        from road_elevation import bake
        bake('cerulean_north')
