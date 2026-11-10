"""Authoring assignments only; never consumed by MoveDB or gameplay."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/skill_fx_bases'
# Each explicit action gets a reviewed semantic group, not a type-only fallback.
GROUPS={
'normal':[
('contact','충돌','tackle headbutt pound take_down double_edge quick_attack skull_bash facade'),
('claw','발톱·연속 베임','scratch slash fury_swipes'),('jab','연속 찌르기','fury_attack'),
('spin','회전 접촉','rapid_spin'),('bind','조임','bind wrap'),
('voice','소리·노래','growl sing supersonic'),('gaze','시선·위협','leer scary_face'),
('gesture','몸짓','tail_whip splash'),('buff','표면 강화·성장','defense_curl harden growth'),
('protect','방어막','protect'),('heal','회복','recover'),('smoke','연막 영역','smoke_screen'),
('scent','향기','sweet_scent'),('transform','변신','transform')],
'fire':[('envelop','분사·화염 감싸임','ember flamethrower'),('bite','불꽃 물림','fire_fang'),('vortex','회전 화염 영역','fire_spin')],
'water':[('jet','물줄기·젖음','water_gun hydro_pump brine'),('bubble','방울','bubble'),('pulse','물 파동','water_pulse'),('tail','접촉 물막','aqua_tail'),('weather','강우','rain_dance'),('shell','껍질 방어','withdraw')],
'electric':[('current','전류·방전','thunder_shock'),('wave','전기 파동·윤곽 방전','thunder_wave')],
'grass':[('leaf','잎날','razor_leaf petal_dance'),('vine','덩굴 타격','vine_whip'),('seed','씨앗 부착','leech_seed worry_seed'),('seed_bomb','씨앗 충돌','seed_bomb'),('drain','생기 귀환','absorb mega_drain giga_drain'),('powder','가루','sleep_powder'),('beam','집광·광선','solar_beam'),('heal','빛 회복','synthesis')],
'ice':[('wind','결정 바람·서리 부착','icy_wind')],
'fighting':[('contact','발·주먹 접촉','low_kick brick_break'),('counter','접촉 반격','counter')],
'poison':[('liquid','점성 액체·부착','acid sludge_bomb'),('needle','침·국소 오염','poison_sting'),('powder','독가루','poison_powder')],
'ground':[('sand','모래 분사','sand_attack'),('mud','진흙 탄·부착','mud_slap'),('quake','지면 충격','bulldoze'),('burrow','잠복·돌출','dig')],
'flying':[('peck','부리 접촉','peck')],
'psychic':[('pressure','정신 압력','confusion'),('hypnosis','눈·최면 파동','hypnosis'),('reflect','특수 반사막','mirror_coat'),('teleport','이동 잔상','teleport')],
'bug':[('silk','실·휘감김','string_shot'),('bite','집게·물림','bug_bite')],
'rock':[('throw','돌 투척·파쇄','rock_throw smack_down'),('fall','낙석 영역','rock_tomb'),('roll','구름 접촉','rollout'),('polish','표면 연마','rock_polish')],
'ghost':[('contact','침투 접촉','astonish'),('lick','혀 접촉·잔향','lick')],
'dragon':[('breath','에너지 숨결','dragon_rage dragon_breath')],
'dark':[('bite','그림자 물림','bite')],
'steel':[('claw','금속 베임','metal_claw'),('beam','금속 집광','flash_cannon'),('surface','금속 표면','iron_defense')],
'fairy':[('voice','음색 파동·빛막','disarming_voice')],
}
# type, release, travel, response, decay, planned extensions without explicit action
DETAILS=[
('normal','노말','손·몸·입','충돌 / 발톱 / 음파','압축 충격 / 베임 / 진동','불티 감속·궤적 짧게 소멸',''),
('fire','불꽃','입·접촉 면','불씨 흐름 / 분사 / 회전 영역','몸에 붙어 흐르는 불막','아래부터 꺼지고 위에 잔염',''),
('water','물','입·꼬리·지면','물줄기 / 방울 / 파동','얇은 물막과 젖음','물줄기 분리·아래로 낙하',''),
('electric','전기','몸·접촉점','가지 전류 / 파동','몸 윤곽을 연결하는 방전','짧은 불규칙 단속 후 해제','thunderbolt'),
('grass','풀','잎·덩굴·씨앗','잎날 / 휘두름 / 포물선 / 귀환','절삭 / 휘감김 / 생기 추출','잎 낙하 / 부착 / 귀환 도착',''),
('ice','얼음','입·몸','결정 바람 / 냉기 선','부분 서리와 얇은 결정','결정 탈락·증발','ice_beam'),
('fighting','격투','주먹·발','접촉 / 짧은 방향 궤적','방향성 압축 충격','짧은 잔상·불티 감속',''),
('poison','독','입·침·몸','점성 탄 / 침 / 가루','표면 액체·국소 오염','흘러내림 / 얇아짐',''),
('ground','땅','발·지면','모래 / 진흙 / 지면 파동','흙먼지·토사','중력 낙하·먼지 가라앉음',''),
('flying','비행','부리·날개','접촉 / 바람 리본 / 칼날','국소 충격 / 지나가는 풍압','공기 리본 분리·소멸','gust air_slash'),
('psychic','에스퍼','눈·몸','집중 파동 / 반사 / 순간 이동','공간 압박·왜곡','수축·원래 공간으로 복귀',''),
('bug','벌레','입·집게','실 / 작은 절삭 / 접촉','휘감김·물림','실 잔류 / 작은 조각 낙하',''),
('rock','바위','몸·상공·지면','투척 / 낙석 / 구름','덩어리 충돌·각진 파쇄','큰 조각 낙하·작은 먼지',''),
('ghost','고스트','몸·혀·그림자','침투 / 접촉 / 영체 흐름','뒤로 빠져나오는 잔향','가늘어지며 흩어짐','shadow_ball'),
('dragon','드래곤','입·몸','압력 있는 에너지 숨결','휘감기는 압력·잔향','긴 흐름이 가늘게 끊어짐',''),
('dark','악','이빨·발톱·그림자','물림 / 그림자 궤적','국소 충격·암부 잔상','짧은 그림자 수축','dark_pulse'),
('steel','강철','발톱·몸','금속 궤적 / 집중 광선','금속 반사·단단한 충격','표면 반사 이동·빠른 소멸',''),
('fairy','페어리','입·몸','음색 파동 / 빛 리본','얇은 빛막','작은 빛 조각으로 풀림','moonblast'),
]

CATEGORIES = {'physical':'물리', 'special':'특수', 'status':'변화'}
# Each row gives the material's category-specific intent, even for empty groups.
CATEGORY_LOOKS = {
'normal':('충돌·베임·찌름의 접촉 방향','음파·에너지의 전달과 진동','몸짓·위협·방어·회복의 의미'),
'fire':('접촉 충격 + 맞은 부위의 국소 화염','불씨·분사 흐름 + 몸을 감싸는 불막','불씨 부착·화상 표시·자기 강화'),
'water':('꼬리·몸의 접촉 + 국소 물막','물줄기·방울·파동 + 젖음과 흘러내림','강우·수막·껍질 방어'),
'electric':('접촉 궤적 + 짧은 국소 방전','이동 전류 + 몸 윤곽을 잇는 방전','전기 파동·마비 부착·충전 표시'),
'grass':('잎날의 절삭·덩굴 접촉·씨앗 충돌','꽃잎 영역·광선·대상에서 돌아오는 생기','씨앗 부착·가루·빛 회복'),
'ice':('단단한 결정 접촉 + 작은 얼음 파쇄','결정 바람·냉기 선 + 표면 서리','냉기 막·결정 장벽·자기 강화'),
'fighting':('주먹·발의 접촉과 방향성 압축 충격','집중 기운의 흐름과 압력','자세·집중·신체 강화'),
'poison':('침의 국소 충격 + 작은 독 부착','점성 액체·분사 + 침식과 흘러내림','독가루·독 안개·상태 표시'),
'ground':('지면을 치는 충격·토사·잠복 돌출','진흙·모래 흐름 + 표면 부착','시야를 가리는 모래·지면 변화'),
'flying':('부리·날개 접촉 + 짧은 공기 궤적','바람 리본·회오리·공기 칼날','상승 기류·바람막·자기 강화'),
'psychic':('신체 접촉 + 국소 정신 압력','정신 파동·공간 압박·반사','시선·최면·순간 이동·집중'),
'bug':('집게·턱 접촉 + 작은 절단','벌레 소리·빛의 전달과 진동','실 휘감김·고치·자기 강화'),
'rock':('돌 충돌·낙석·구름 + 무거운 파쇄','광물 에너지·분진 흐름','연마·암석 장벽·자기 강화'),
'ghost':('혀·그림자 접촉 + 침투 잔향','영체 흐름 + 몸 뒤로 빠지는 잔향','저주·영적 표식·그림자 변화'),
'dragon':('신체·발톱 접촉 + 국소 압력','숨결·에너지 흐름 + 휘감기는 압력','기운 집중·자세·강화'),
'dark':('이빨·발톱 접촉 + 암부 잔상','어둠의 파동·에너지 침식','위협·도발·그림자 표식'),
'steel':('금속 접촉·베임 + 움직이는 반사','집중 광선 + 단단한 에너지 충격','금속 표면·방어막·자기 강화'),
'fairy':('몸·장식의 접촉 + 국소 빛 잔상','음색·빛 리본 + 얇게 감기는 빛막','빛의 보호·회복·약화 표시'),
}
SAMPLE_PHASES = {'ember':'hit','water_gun':'hit','thunder_shock':'hit','razor_leaf':'hit',
 'fire_fang':'contact','aqua_tail':'contact','withdraw':'buff','thunder_wave':'status_application',
 'petal_dance':'area','sleep_powder':'status_application'}
SAMPLE_MOVES = set(SAMPLE_PHASES)
# Geometry shared across types, with a separate material response layered on it.
SHARED_CONTACT = {
 'normal.claw':'contact.claw', 'steel.claw':'contact.claw',
 'fire.bite':'contact.bite', 'dark.bite':'contact.bite', 'bug.bite':'contact.bite',
 'normal.contact':'contact.body', 'fighting.contact':'contact.limb',
 'water.tail':'contact.tail', 'flying.peck':'contact.point',
}

def main():
    inventory=json.loads((OUT/'inventory.json').read_text())['moves']
    by_id={m['id']:m for m in inventory};assigned={};types=[]
    for kind,ko,cast,travel,hit,decay,extensions in DETAILS:
        families=[]
        for suffix,label,ids in GROUPS[kind]:
            legacy_key=f'{kind}.{suffix}'
            # Read the current category from MoveDB, never infer it from range.
            for category in CATEGORIES:
                moves=[id for id in ids.split() if by_id[id]['category']==category]
                if not moves:continue
                visual_suffix='petal' if kind=='grass' and suffix=='leaf' and category=='special' else suffix
                visual_label='꽃잎 영역' if visual_suffix=='petal' else label
                key=f'{kind}.{category}.{visual_suffix}'
                for id in moves:
                    assert by_id[id]['type']==kind and by_id[id]['explicit_shape'],id
                    assert id not in assigned,id
                    assigned[id]=dict(move=id,type=kind,category=category,family=key,legacy_family=legacy_key,
                        status='proposed',current=by_id[id],sample_hit_available=SAMPLE_PHASES.get(id) in ['hit','contact'],sample_available=id in SAMPLE_MOVES,
                        sample_phase=SAMPLE_PHASES.get(id),gameplay_linked=False)
                families.append(dict(id=key,category=category,label=visual_label,moves=moves,
                    sample_moves=sorted(SAMPLE_MOVES.intersection(moves)),
                    shared_geometry=SHARED_CONTACT.get(legacy_key),material_layer=kind,
                    asset_status='sample_only' if SAMPLE_MOVES.intersection(moves) else 'planned'))
        for id in extensions.split():assert id in by_id and by_id[id]['type']==kind
        categories=[]
        for index,(category,name) in enumerate(CATEGORIES.items()):
            members=[f for f in families if f['category']==category]
            categories.append(dict(category=category,name_ko=name,direction=CATEGORY_LOOKS[kind][index],
                assigned_count=sum(len(f['moves']) for f in members),families=members,
                status='proposed' if members else 'reserved_no_explicit_moves'))
        types.append(dict(type=kind,name_ko=ko,cast=cast,travel=travel,hit=hit,decay=decay,
            families=families,categories=categories,
            later_examples=[dict(move=id,category=by_id[id]['category'],explicit_shape=by_id[id]['explicit_shape'],
                status='needs_semantic_and_gameplay_review') for id in extensions.split()]))
    expected={m['id'] for m in inventory if m['explicit_shape']}
    assert set(assigned)==expected,(expected-set(assigned),set(assigned)-expected)
    for row in assigned.values():assert row['category']==row['current']['category']
    counts={category:sum(r['category']==category for r in assigned.values()) for category in CATEGORIES}
    out=dict(status='authoring_proposal_not_runtime',schema_version=2,
        hierarchy=['type','category','visual_family'],category_counts=counts,types=types,assignments=list(assigned.values()),
        pending=[dict(move=m['id'],type=m['type'],category=m['category'],reason='no_explicit_action_shape')
            for m in inventory if not m['explicit_shape']],
        fallback_samples=[dict(move='will_o_wisp',type='fire',category='status',proposed_family='fire.status.wisp',sample_phase='cast_visual_only',explicit_shape=False,gameplay_linked=False,burn_implemented=False),
            dict(move='thunder_punch',type='electric',category='physical',proposed_family='electric.physical.punch',sample_phase='contact',explicit_shape=False,gameplay_linked=False,gameplay='existing_physical_fallback')],
        special_reserve=dict(stellar='No matching runtime type or move in current inventory; special Tera FX design reserved, no combat implementation.',
            mystery='Legacy data category, no new type FX assigned.'))
    (OUT/'families.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
    lines=['# 18속성 스킬 기본형 배정표','',
        '구조는 **속성 → 물리·특수·변화 → 시각 기본형**이다. 개별 액션 형태가 지정된 89개 기술의 분류는 현재 MoveDB 데이터에서 가져온다. 사거리나 투사체 여부로 물리·특수를 추정하지 않는다. 게임 연결과 자산 완성 여부는 별개이며, 분류별 기본값을 쓰는 501개 기술은 미배정으로 남긴다.','',
        f"현재 배정: 물리 {counts['physical']}개, 특수 {counts['special']}개, 변화 {counts['status']}개.",'',
        '## 분류별 공통 규칙','',
        '| 분류 | 중심 | 피격 기본값 | 공유할 부분 |', '|---|---|---|---|',
        '| 물리 | 실제 몸·발톱·이빨 또는 날아가는 고체의 접촉 | 충돌·베임·찌름의 방향과 국소 반응 | 물림·발톱·충돌 구조 + 속성별 표면 효과 |',
        '| 특수 | 분사·탄·파동·광선·흡수의 전달 | 감싸임·젖음·방전·압력 등 물질 반응 | 경로·방출 위치·앞뒤 배치 + 속성별 흐름 |',
        '| 변화 | 강화·약화·상태·방어·날씨 | 상태 부착·표식·막·영역 | 대상 추적·막·가루·표시 수명 |','',
        '물리 전체에 불티를 붙이지 않는다. 물리 투사체인 잎날가르기·독침·돌떨구기는 각각 절삭·국소 독 부착·무거운 파쇄를 쓴다. 특수 전체에 감싸임을 강제하지 않고 광선·흡수·소리의 반응을 유지한다. 변화 효과는 실제 상태 성공·해제와 연결하고, 확률 실패 때 성공 표식을 보여주지 않는다.','',
        '카운터는 물리, 미러코트는 특수인 현재 데이터 분류를 유지한다. 두 기술은 먼저 반격 대기·수신·반격 해제로 구성하고 일반 공격 시전처럼 취급하지 않는다. 화상 같은 지속 상태와 짧은 불꽃 피격은 별도 수명이다.','',
        '## 속성과 분류별 제작 방향','',
        '아래 54칸은 전 속성의 제작 방향이다. 배정 0개인 칸은 예약이며, 관련 기술이나 연출이 구현됐다는 뜻이 아니다.','',
        '| 속성 | 물리 | 특수 | 변화 |', '|---|---|---|---|']
    for t in types:
        cells=[f"{c['direction']} · 배정 {c['assigned_count']}개" for c in t['categories']]
        lines.append('| '+' | '.join([t['name_ko'],*cells])+' |')
    lines+=['','## 기본형별 기술 목록','',
        '상태는 모두 제안이다. 자산 상태의 샘플은 명시한 기술을 검토한 결과다. 같은 기본형의 나머지 기술은 아직 검증하지 않았다. 피격·접촉·자기 강화·상태 부착·영역은 families.json의 sample_phase로 구분한다.','',
        '| 속성 | 분류 | 기본형 | 배정 기술 ID | 자산 상태 |', '|---|---|---|---|---|']
    for t in types:
        for c in t['categories']:
            for f in c['families']:
                state='별도 샘플: '+', '.join(f['sample_moves']) if f['sample_moves'] else '제작 예정'
                lines.append(f"| {t['name_ko']} | {c['name_ko']} | {f['label']} | {', '.join(f['moves'])} | {state} |")
    lines+=['','## 부품 공유와 표현 차이','',
        '| 공용 구조 | 적용 예 | 개별 표현 |','|---|---|---|',
        '| 물림 | 물기·불꽃엄니·벌레먹음 | 악의 국소 잔상 / 국소 화염 / 작은 절단 |',
        '| 발톱 | 할퀴기·메탈클로 | 발톱 자국 / 금속 반사 |',
        '| 앞뒤 추적 레이어 | 특수 불꽃·물·전기 | 불막 / 물막 / 전류를 별도 형태로 제작 |',
        '| 회전하는 작은 조각 | 잎날가르기·꽃잎댄스 | 물리 잎날 투사체 / 특수 꽃잎 영역. 궤적·분류·판정은 각각 유지 |','',
        '공용 구조는 시각 경로·배치의 재사용을 뜻한다. 캐릭터 공격 자세를 공통 동작으로 덮어쓰거나 위력·타수·판정을 바꾸지 않는다.','',
        '## 첫 샘플 재분류와 다음 검토','',
        '| 샘플 | 분류 | 다음 비교 짝 |', '|---|---|---|',
        '| 불꽃세례 | 불꽃 특수 | 불꽃엄니의 국소 화염과 비교 |',
        '| 물대포 | 물 특수 | 아쿠아테일의 접촉 물막과 비교 |',
        '| 전기쇼크 | 전기 특수 | 전기자석파의 변화 효과와 비교 |',
        '| 잎날가르기 | 풀 물리 | 꽃잎댄스의 특수 영역과 비교 |','',
        '첫 네 샘플은 특수 3개·물리 1개다. 후속 비교에서는 불꽃엄니·아쿠아테일·껍질에숨기·전기자석파·꽃잎댄스·수면가루를 별도로 제작했다. 꽃잎댄스는 잎날가르기 샘플을 재사용한 검증이 아니라 새 영역 샘플이다. [10개 기술의 분류별 샘플](category_samples/REVIEW.md)에서 제작·검증 범위를 확인할 수 있다. 게임에는 연결하지 않았다.','',
        '## 확장과 예외','',
        '냉동빔·바람일으키기·에어슬래시·섀도볼·악의파동·문포스·10만볼트는 후속 참고 기술이다. 현재 개별 액션 형태가 없는 기술을 완성된 기술로 간주하거나 자동 연결하지 않는다.','',
        '개별 액션이 없는 도깨비불·번개펀치는 별도의 기본형 후보 샘플로 추가했다. [빈칸 보완 샘플](category_fill/REVIEW.md)에 기록한다. 두 기술은 501개 미배정 기술에 그대로 남고 게임에 연결하지 않는다. 도깨비불은 화상 판정이 없는 시각 시안, 번개펀치는 기존 물리 기본값 위의 접촉 시안이다.', '',
        '스텔라는 현재 런타임 타입/기술에 없어 특수 테라 연출을 위한 예약 항목으로만 둔다. mystery는 기존 데이터 범주로 보류한다.','',
        '기본형은 작은/중간/큰 표현 변형을 가질 수 있지만 위력·타수·판정은 기존 기술이 결정한다.','',
        '재생성: `python3 tools/samples/build_skill_fx_catalog.py`. `families.json`은 제작용이며 MoveDB에서 읽지 않는다.']
    (OUT/'catalog.md').write_text('\n'.join(lines)+'\n')
    print(f'{len(types)} types / {sum(len(t["families"]) for t in types)} category-specific families / {len(assigned)} assigned / {len(out["pending"])} pending / {counts}')

if __name__=='__main__':main()
