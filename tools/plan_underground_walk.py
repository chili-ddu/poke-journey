"""블루↔갈색 양방향 경로. 노랑시티를 통과하지 않고 원작 지하통로를 쓴다."""
import json
from plan_north_walk import plan,ROOT
NAMES=['kanto_north','kanto_east','underground_path_north_entrance','underground_path_north_south_tunnel','underground_path_south_entrance']
if __name__=='__main__':
    blue=('kanto_north',190,22);verm=('kanto_east',21,62)
    plans=dict(southbound=plan(NAMES,blue,verm),northbound=plan(NAMES,verm,blue))
    (ROOT/'docs/kanto_expansion_review/underground_walk_plan.json').write_text(json.dumps(plans,indent=2))
    for direction,p in plans.items():print(direction,p['walk_steps'],'steps',len(p['legs'])-1,'transitions',p['automatic_ledge_jumps'],'jumps')
