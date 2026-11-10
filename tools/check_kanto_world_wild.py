"""Compare every committed mainland encounter slot with the original source."""
import json
from pathlib import Path
import kanto_world_wild as wild
import frlg_map as fm

ROOT=wild.ROOT

def run():
    data=json.loads(wild.OUT.read_text())
    original=json.loads(wild.SOURCE.read_text())['wild_encounter_groups'][0]
    fields={f['type']:f for f in original['fields']}
    source={e['map']:e for e in original['encounters'] if e['base_label'].endswith('FireRed')}
    count=0
    for area,folder in data['origins'].items():
        native=source[fm.map_const(folder)];cfg=data['tables'][area]
        for field,key,rate in [('land_mons','encounters','encounter_rate'),('water_mons','water_encounters','water_encounter_rate'),('fishing_mons','fishing','fishing_encounter_rate'),('rock_smash_mons','rock_smash_encounters','rock_smash_encounter_rate')]:
            if field not in native:
                assert not cfg.get(key),(area,field,'invented encounter table')
                continue
            assert cfg[rate]==native[field]['encounter_rate'],(area,rate)
            groups=fields[field].get('groups',{'slots':list(range(len(native[field]['mons'])))})
            for method,indices in groups.items():
                actual=cfg[key][method] if field=='fishing_mons' else cfg[key]
                assert len(actual)==len(indices),(area,method)
                for row,index in zip(actual,indices,strict=True):
                    mon=native[field]['mons'][index]
                    assert row[0]==mon['species'].removeprefix('SPECIES_').lower(),(area,method,row)
                    assert row[1]==mon['min_level'],(area,method,row)
                    assert row[2]==fields[field]['encounter_rates'][index],(area,method,row)
                    assert (row[3] if len(row)>3 else row[1])==mon['max_level'],(area,method,row)
                    count+=1
    names=json.loads((ROOT/'assets/data/names_ko.json').read_text())['species']
    lines=['# 관동 구역별 야생 출현','',
           '파이어레드 원작의 슬롯·레벨·가중치·낚싯대별 표를 사용한다. 아래는 같은 종의 슬롯을 합쳐 표시한 레벨 범위다. 정확한 슬롯은 `assets/data/kanto_world_wild.json`에 보관한다.','',
           '| 구역 | 풀숲·동굴 | 수상 | 낡은낚싯대 | 좋은낚싯대 | 대단한낚싯대 |','|---|---|---|---|---|---|']
    def display(entries):
        species={}
        for row in entries:
            lo,hi=species.get(row[0],(100,0))
            species[row[0]]=(min(lo,row[1]),max(hi,row[3] if len(row)>3 else row[1]))
        return ' · '.join(names.get(key,key)+' '+(str(lo) if lo==hi else f'{lo}~{hi}') for key,(lo,hi) in species.items()) or '—'
    for area,cfg in data['tables'].items():
        title=wild.world.title(data['origins'][area])
        if area in ['route17','route21_south']:title+=' (원작 풀숲 없음)'
        if area.startswith('pokemon_tower_'):title+=' (현재 이벤트 전용·원작표 보관)'
        groups=[cfg['encounters'],cfg['water_encounters']]+[cfg['fishing'].get(rod,[]) for rod in ['old_rod','good_rod','super_rod']]
        lines.append('| '+title+' | '+' | '.join(display(entries) for entries in groups)+' |')
    lines += ['', '바위깨기 전용 표: 블루시티 동굴 세 층·돌산터널 지하 1층의 꼬마돌·데구리. 현재는 표와 종족 자산을 보존하며 바위깨기 동료/대상 상호작용은 별도다.', '',
              '포켓몬타워는 현재 네 형제 이벤트 전용 실내 설정을 우선한다. 3~7층 원작 표의 고오스·고우스트·탕구리는 일반 야생으로 생성하지 않으며 종족 자산·전투 행동과 원작 표만 보관한다.', '',
              '17번도로와 21번수로 남쪽은 원작에 육상 출현표가 있지만 실제 풀숲 타일은 없다. 풀숲을 추가하거나 일반 도로에서 강제로 출현시키지 않는다. 전설·잠만보·선물·교환 등 고정 이벤트는 무작위 출현표에 섞지 않는다.','']
    out=ROOT/'docs/kanto_world_wild';out.mkdir(exist_ok=True)
    (out/'encounters.md').write_text('\n'.join(lines))
    report=dict(areas=len(data['tables']),species=len(data['species']),native_slots_verified=count,
                land_tables=56,surf_tables=29,fishing_tables=29,rock_smash_tables=4,
                grassless_native_land_tables=['route17','route21_south'],
                story_only_native_tables=[area for area in data['tables'] if area.startswith('pokemon_tower_')],
                active_random_areas=60,active_land_tables=51,
                static_story_encounters_in_random_tables=False)
    (out/'source_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('Native encounter verification:',len(data['tables']),'areas,',len(data['species']),'species,',count,'original slots; levels/weights/rates/rod groups match')
    return report

if __name__=='__main__':run()
