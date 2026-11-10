"""원작 배치로 회색→블루→갈색 지도/시설을 재현한다. 기존 남부 지도는 가장자리 연결만 갱신한다."""
import json
import sys
import frlg_map as fm
import kanto_wild
ROOT=fm.ROOT
REGIONS={'kanto_north':['Route3','Route4','CeruleanCity','Route5'], 'kanto_east':['Route6','VermilionCity']}
SINGLES=['MtMoon_1F','MtMoon_B1F','MtMoon_B2F','Route4_PokemonCenter_1F',
 'UndergroundPath_NorthEntrance','UndergroundPath_NorthSouthTunnel','UndergroundPath_SouthEntrance',
 'Route5_PokemonDayCare','Route5_SouthEntrance','Route6_NorthEntrance']
for city in ['CeruleanCity','VermilionCity']:
 for suffix in (['House1','House2','House3','House4','House5','PokemonCenter_1F','Gym','BikeShop','Mart'] if city=='CeruleanCity' else ['House1','House2','House3','PokemonCenter_1F','Gym','PokemonFanClub','Mart']):
  SINGLES.append(city+'_'+suffix)
NAMES={'kanto_north':'관동 북부','kanto_east':'관동 동부','route3':'3번도로','route4':'4번도로','route5':'5번도로','route6':'6번도로','cerulean_city':'블루시티','vermilion_city':'갈색시티',
 'mt_moon_1f':'달맞이산 1층','mt_moon_b1f':'달맞이산 지하 1층','mt_moon_b2f':'달맞이산 지하 2층',
 'underground_path_north_entrance':'지하통로 북쪽 입구','underground_path_south_entrance':'지하통로 남쪽 입구','underground_path_north_south_tunnel':'지하통로',
 'route5_pokemon_day_care':'포켓몬 키우미집','route5_south_entrance':'5번도로 관문','route6_north_entrance':'6번도로 관문'}
def load(name): return json.loads((ROOT/'assets/maps'/name/'map.json').read_text())
def save(name,j): (ROOT/'assets/maps'/name/'map.json').write_text(json.dumps(j,ensure_ascii=False,indent=0)+'\n')
def definitions():
 themes=[]; warps=[]; places=[]; music=[]
 for name,folders in list(REGIONS.items())+[(fm.snake(f),[f]) for f in SINGLES]:
  themes.append(f'\t"{name}": {{"map": "res://assets/maps/{name}", "tiles": {{}}}},')
  for f in folders:
   warps.append(f'\t"{fm.snake(f)}": "{name}",')
   music.append(f'\t"{fm.snake(f)}": "{fm.map_json(f)["music"].lower()}",')
  title=NAMES.get(name)
  if title is None:
   city='블루시티' if name.startswith('cerulean') else '갈색시티'
   title=city+(' 포켓몬센터' if 'center' in name else ' 프렌들리숍' if 'mart' in name else ' 체육관' if 'gym' in name else ' 자전거가게' if 'bike' in name else ' 포켓몬 애호가클럽' if 'fan_club' in name else ' 민가')
   if name.startswith('route4'): title='4번도로 포켓몬센터'
  outdoor=name in REGIONS or name.startswith('mt_moon')
  cfg=f'"name": "{name.upper().replace("_"," ")}", "name_ko": "{title}", "theme": "{name}", "'+('overworld' if outdoor else 'indoor')+'": true, "count": 0, "encounters": []'
  if name.startswith('mt_moon'): cfg+=', "battle_style": "room"'
  if name in REGIONS or name.startswith('mt_moon'):
   areas=', '.join(f'"{fm.snake(f)}": '+kanto_wild.area(f,NAMES[fm.snake(f)]) for f in folders)
   cfg+=', "areas": {'+areas+'}'
  if 'pokemon_center_1f' in name:
   cfg+=', "npcs": [{"id": "nurse", "sprite": "nurse", "tile": Vector2i(7, 2), "face": "down", "talk": "nurse", "talk_tile": Vector2i(7, 4), "heal_spot": Vector2(6.0, 1.7)}]'
  if name.endswith('_mart'):
   cfg+=', "npcs": [{"id": "clerk", "sprite": "clerk", "tile": Vector2i(2, 3), "face": "right", "talk": "shop", "talk_tile": Vector2i(4, 3)}]'
  places.append(f'\t"{name}": {{'+cfg+'},')
 text='''# tools/kanto_expansion.py로 원본 지도와 함께 생성. 이야기/관장전은 별도 단계.
extends RefCounted
'''
 for key,lines in [('THEMES',themes),('WARP_MAPS',warps),('DUNGEONS',places),('MUSIC',music)]: text+='const '+key+' := {\n'+'\n'.join(lines)+'\n}\n'
 (ROOT/'scripts/data/kanto_expansion.gd').write_text(text)
def edge_link():
 # 원래 지역을 재배치하지 않고 회색시티 동쪽 통로와 3번도로 서쪽 통로만 연결.
 a=load('kanto_south'); b=load('kanto_north')
 pa=next(x for x in a['areas'] if x['id']=='pewter_city'); pb=next(x for x in b['areas'] if x['id']=='route3')
 for j in (a,b): j['warps']=[w for w in j['warps'] if not w.get('edge_transition')]
 lanes=[]
 for y in range(1,pb['h']-1):
  ax,ay=pa['x']+pa['w']-2,pa['y']+10+y
  bx,by=pb['x']+1,pb['y']+y
  if all(a['solid'][ay][ax-d]=='0' and b['solid'][by][bx+d]=='0' for d in (0,1)):
   i=1000+y;lanes.append(y)
   a['warps'].append(dict(x=ax,y=ay,map='pewter_city',index=i,to='route3',to_warp=i,arrival_dir=[-1,0],edge_transition=True))
   b['warps'].append(dict(x=bx,y=by,map='route3',index=i,to='pewter_city',to_warp=i,arrival_dir=[1,0],edge_transition=True))
 assert lanes, '회색시티–3번도로 연결 통로가 없음'
 save('kanto_south',a);save('kanto_north',b); print('Pewter edge lanes',lanes,flush=True)
def main():
 definitions()
 for name,folders in REGIONS.items():
  fm.bake(folders,name,None,True)
  j=load(name); area=next(a for a in j["areas"] if a["id"]==("route3" if name=="kanto_north" else "vermilion_city"))
  tx,ty=(3,10) if name=="kanto_north" else (21,22)
  j["start"]=[(area["x"]+tx)*16+8,(area["y"]+ty)*16+8]; save(name,j)
 for f in SINGLES:
  name=fm.snake(f);fm.bake([f],name,None,False)
  j=load(name)
  # 통신용 2층은 기존 센터와 동일하게 제외. 원작 출입구를 시작점으로 쓴다.
  if 'pokemon_center_1f' in name: j['warps']=[w for w in j['warps'] if not w['to'].endswith('_2f')]
  if j['warps']:
   spawn=next((w for w in j['warps'] if w['index']==1),j['warps'][0])
   if name=='mt_moon_1f': spawn=j['warps'][3]
   j['start']=[spawn['x']*16+8,spawn['y']*16+8]
  save(name,j)
 edge_link()
 if "--cards" in sys.argv:
  import hd2d_cards
  for name in list(REGIONS)+[fm.snake(f) for f in SINGLES]: hd2d_cards.build(name)
if __name__=='__main__':main()
