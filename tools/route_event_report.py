"""Write route/event reference data from the current read-only Godot inventory."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/continent_world/route_events'
INVENTORY = ROOT/'docs/continent_world/route_event_inventory.json'
# Traversal summaries, not automatic promises that every original story is ported.
LINKS = {
1:'태초마을 ↔ 상록시티',2:'상록시티 ↔ 상록숲 ↔ 회색시티; 디그다굴 서쪽 출구',
3:'회색시티 ↔ 달맞이산 서쪽/4번도로',4:'달맞이산 동쪽 ↔ 블루시티',
5:'블루시티 ↔ 노랑시티 북문; 지하통로 북쪽 입구',6:'노랑시티 남문 ↔ 갈색시티; 지하통로 남쪽 입구',
7:'무지개시티 ↔ 노랑시티 서문',8:'노랑시티 동문 ↔ 보라타운',9:'블루시티 ↔ 10번도로',
10:'9번도로 ↔ 돌산터널 ↔ 보라타운; 발전소 물길 분기',11:'갈색시티 ↔ 디그다굴 입구 ↔ 12번도로',
12:'보라타운 ↔ 13번도로; 11번도로 분기',13:'12번도로 ↔ 14번도로',14:'13번도로 ↔ 15번도로',
15:'14번도로 ↔ 연분홍시티',16:'무지개시티 ↔ 17번도로',17:'16번도로 ↔ 18번도로',18:'17번도로 ↔ 연분홍시티',
19:'연분홍시티 ↔ 20번수로',20:'19번수로 ↔ 쌍둥이섬 ↔ 홍련섬',21:'홍련섬 ↔ 태초마을',
22:'상록시티 ↔ 리그 접수 게이트; 23·26·28번도로로 분기',23:'리그 접수 게이트 ↔ 챔피언로드 ↔ 석영고원',
24:'블루시티 북쪽 다리 ↔ 25번도로',25:'24번도로 ↔ 이수재의 집',
26:'27번도로 동쪽 ↔ 리그 접수 게이트',27:'연두마을 동쪽 ↔ 동성폭포 ↔ 26번도로',28:'리그 접수 게이트 서쪽 ↔ 은빛산',
29:'연두마을 ↔ 무궁시티; 46번도로 남쪽 분기',30:'무궁시티 ↔ 31번도로',31:'30번도로 ↔ 도라지시티; 어둠의동굴 입구',
32:'도라지시티 ↔ 연결동굴; 알프의유적 분기',33:'연결동굴 ↔ 고동마을',34:'너도밤나무숲 ↔ 금빛시티',
35:'금빛시티 ↔ 자연공원/36번도로',36:'도라지시티·35번도로·자연공원 ↔ 37번도로; 알프의유적 분기',
37:'36번도로 ↔ 인주시티',38:'인주시티 ↔ 39번도로',39:'38번도로 ↔ 담청시티',
40:'담청시티 ↔ 41번수로; 배틀 시설 방향 관문',41:'40번수로 ↔ 진청시티; 소용돌이섬',
42:'인주시티 ↔ 황토마을; 절구산 입구들',43:'황토마을 ↔ 분노의호수',44:'황토마을 ↔ 얼음샛길',
45:'검은먹시티 ↔ 46번도로; 어둠의동굴 분기',46:'45번도로 ↔ 29번도로',
47:'진청시티/낭떠러지동굴 ↔ 48번도로',48:'47번도로 ↔ 사파리존 게이트'}


def event(number, name, place, condition, content, result, anchor, source, **extra):
    return dict(id=f'E{number:02}', name=name, place=place, condition=condition,
                content=content, result=result, anchor=anchor, source=source, **extra)


def build():
    data=json.loads(INVENTORY.read_text())
    mainland=json.loads((ROOT/'assets/maps/kanto_world/map.json').read_text())
    areas=mainland['areas']
    rects={a['id']:a for a in areas}
    def at(area,x=None,y=None):
        r=rects[area];return [r['x']+(r['w']/2 if x is None else x),r['y']+(r['h']/2 if y is None else y)]
    events=[
      event(1,'연구소 탈출','태초마을 오박사 연구소','새 기록의 첫 출발','몬스터볼 탈출·오박사와 대화','독립 여행 시작',at('pallet_town'),'scripts/game.gd'),
      event(2,'그린과 첫 승부','1번도로','첫 통과·미승리','상대 스타팅·구구·꼬렛과 승부','승리 기록과 보상',at('route1',11,2),'scripts/game.gd'),
      event(3,'신비로운 새 목격','1번도로','1세대 첫 진입; 노랑 방문 전에도 가능','무지갯빛 새 목격 → 구구에게 첫 단서','이야기 안내·오랭열매 2개; 칠색조 최종 조우는 미구현',at('route1',10,13),'scripts/story/campaign_quests.gd'),
      event(4,'비주기 첫 만남','상록시티 체육관 앞','체육관 문 접근·미완료','비주기와 대화','변함없는돌',at('viridian_city',32,4),'scripts/game.gd'),
      event(5,'그린 재전 두 시점','22번도로','초반: 웅에게 승리하기 전 / 후반: 여덟 관장 승리 후','초반 2마리·후반 6마리와 별도 승부','각 승리 기록·보상',at('route22',33,5),'scripts/story/rival_progression.gd'),
      event(6,'삐삐의 통과 도움','달맞이산 서쪽 입구','입구 근처 접근; 노랑 방문 불필요','손가락흔들기로 반대편 출구까지 이동','첫 통과용 이동 지원; 동쪽 해당 출구 재진입 차단',at('route3',78,5),'scripts/story/moon_passage.gd'),
      event(7,'달맞이산 채굴 조사·출구 배틀','달맞이산 지하/동쪽 출구','이슬 조사는 블루 체육관 안내인부터 / 로사·로이는 실제 동쪽 출구 접근 시','이슬과 불법 채굴 저지; 별도로 로사·로이·나옹 출구 배틀','채굴 운송 단서·이슬 복귀 / 출구 배틀 승리 기록',at('route4',28,10),'scripts/story/campaign_quests.gd; scripts/game.gd'),
      event(8,'블루시티 그린 재전','블루시티 북쪽','해당 승부 미승리','4마리 파티와 승부','승리 기록·보상',at('cerulean_city',21,4),'scripts/data/cerulean_progression.gd'),
      event(9,'상록숲의 작은 평화','남쪽 관문 → 숲 동쪽 공터','노랑 첫 방문 후 소년에게 부탁 수락','버터플·독침붕 양측 성충 제압 → 서식지 협상; 2세는 부모의 해결 기록에 따라 후손 재회','합의 후 일회 열매·이야기 경험치',at('route2',12,35),'scripts/story/regional_quests.gd'),
      event(10,'되살아난 화석','회색시티 박물관 1·2층','노랑 첫 방문 후 직원에게 부탁 수락','투구·암나이트·프테라 진정 → 직원에게 보고','열매·이야기 경험치·홍련 연구 소문',at('pewter_city',20,5),'scripts/story/regional_quests.gd'),
      event(11,'스라크 구출','22번도로 길가','노랑 첫 방문 후; 이미 얻은 친구는 유지','망키 무리와 우두머리를 물리치고 스라크와 화해','풀베기 습득 또는 스라크 도움',at('route22',23,6),'scripts/story/forest_rescue.gd'),
      event(12,'열매에 담은 마음','5번도로 교배집','노랑 첫 방문 후; 1세대 이야기','이성 포켓몬과 교류 → 오랭열매 2개·과사열매 1개 선물 → 알 맡기기','답례 열매·이야기 경험치·자식 계승 자격',at('route5',17,22),'scripts/story/regional_quests.gd'),
      event(13,'이수재 연구자료 보호·이브이 상담','25번도로 이수재의 집','노랑 첫 방문 후; 이브이 상담은 무지개 옥상 이야기와 자료 보호 완료 필요','로켓단 자료 탈취 저지 → 실프 연구 정황; 이브이는 스스로 연구 참여','서로 별도의 완료·열매·이야기 경험치; 티켓·옛 컬렉션 배틀 없음',at('route25',34,5),'scripts/story/regional_quests.gd; scripts/story/bill_event.gd'),
      event(14,'잠만보의 아침','11번도로 디그다굴 동쪽','노랑 첫 방문 후 서쪽 안내인 대화; 오랭열매 3개','열매 냄새와 일정한 소리로 깨우기; 전투 없음','동쪽 길 개방·답례 열매·이야기 경험치',at('route11',10,9),'scripts/story/regional_quests.gd; scripts/story/road_gates.gd'),
      event(15,'포켓몬타워·그린 재전','보라타운 타워 앞 / 타워 2~7층','그린: 미승리 / 유령 형제 신규 시작: 노랑 방문 후','입구 앞 그린 승부; 타워 안 네 유령 형제의 분신 시련','승리 기록·형제들의 인정·일회 이야기 보상·잠만보 힌트',at('lavender_town',17,7),'scripts/story/tower_brothers.gd; scripts/story/rival_progression.gd'),
      event(16,'이브이가 고른 강함','무지개시티 맨션 옥상 → 이수재 집','노랑 첫 방문 후; 마지막 상담은 이수재 구조 완료 필요','일곱 진화형과 순차 승부 → 이브이 임시 동행 → 연구 참여 결정','열매·이야기 경험치·이브이의 자발적 연구 참여',at('celadon_city',20,7),'scripts/story/regional_quests.gd'),
      event(17,'15번도로의 도플갱어','보라타운 센터 → 15번도로 동쪽 공터','노랑 첫 방문 후 여행자 괴담 수락','현재 모습·성장·장착 기술을 복제한 메타몽과 승부 → 약속·여행자 보고','열매·이야기 경험치·괴담 해결',at('route15',61,6),'scripts/story/regional_quests.gd'),
      event(18,'실프 도난 조사·그린 재전','노랑시티 실프 1층 / 7층','조사: 현장 접근으로 진행 가능; 이수재 정보는 수첩 발견 힌트 / 그린: 미승리','도난 포획 기술 조사·전투; 7층은 별도의 그린전','게임코너 운송 단서·각 승리 기록', [288,140],'scripts/story/campaign_quests.gd; scripts/story/rival_progression.gd',proxy=True),
      event(19,'게임코너 아래 제작실','무지개시티 로켓단 아지트 지하 4층','현장 조사 가능; 실프 완료는 수첩 목적지 공개 조건','로켓단 승부 → 마스터볼 시제품·암호명 M2 계획 확보','제작 계획 단서·열매·이야기 경험치',at('celadon_city',35,25),'scripts/story/campaign_quests.gd'),
      event(20,'홍련의 연구 기록','홍련섬 포켓몬저택 지하 1층','현장 조사 가능; 박물관 소문은 수첩 발견 힌트','뮤·뮤츠 연구 기록과 후속 목격담 조사','뮤츠 정체 단서·열매·이야기 경험치',at('cinnabar_island',8,5),'scripts/story/campaign_quests.gd'),
      event(21,'비주기 결전·세대 전환','상록시티 체육관 / 교배집','1세대: 네 본편 조사 단서 결합 / 2세대: 다른 일곱 관장 승리','포획 결말; 알을 남겼으면 Lv10 자식으로 시작; 2세대 결전 마지막 상대가 저장된 아버지','알이 없으면 배드엔딩; 2세대 승리 시 아버지 구출',at('viridian_city',32,4),'scripts/story/campaign_director.gd'),
      event(22,'뮤츠 최종전','블루시티 동굴 지하 1층','2세대·아버지 구출 후','자신의 의지로 뮤츠에게 도전하고 마지막 대화','진엔딩 기록',at('cerulean_city',3,4),'scripts/story/campaign_quests.gd'),
      event(23,'차가운 날개·프리져','15번도로 관문 2층 / 쌍둥이섬 입구·지하 4층','신비로운 새 목격 + 노랑 방문; 두 단서는 순서 자유','망원경 목격담·차가운 바람 → 바위/물살 퍼즐 → 프리져 승부','선택 이야기 완료·열매·경험치; 포획 없음',at('route20',29,9),'scripts/story/campaign_quests.gd; scripts/story/seafoam_puzzle.gd'),
      event(24,'우레의 울음·썬더','17번도로 / 10번도로 / 폐발전소','신비로운 새 목격 + 노랑 방문; 두 단서는 순서 자유','폐발전소 소문·비정상 방전 → 썬더 승부','선택 이야기 완료·열매·경험치; 포획 없음',at('route10',10,9),'scripts/story/campaign_quests.gd'),
      event(25,'불탄 깃털·파이어','홍련 연구실 / 챔피언로드 1·2층','신비로운 새 목격 + 노랑 방문; 두 단서는 순서 자유','전설 기록·불탄 깃털 → 챔피언로드 2층 파이어 승부','선택 이야기 완료·열매·경험치; 現 파이어 위치는 게임 각색',at('route23',12,18),'scripts/story/campaign_quests.gd')
    ]
    # Indoor events use actual exterior doors where available, not guessed city pins.
    entry_targets={1:'pallet_town_professor_oaks_lab',4:'viridian_city_gym',6:'mt_moon_1f',
      7:'mt_moon_b1f',9:'forest_gate_south',10:'pewter_city_museum_1f',12:'route5_pokemon_day_care',
      13:'route25_sea_cottage',15:'pokemon_tower_1f',16:'celadon_city_condominiums_1f',
      19:'celadon_city_game_corner',20:'pokemon_mansion_1f',21:'viridian_city_gym',
      22:'cerulean_cave_1f',23:'seafoam_islands_1f',24:'power_plant',25:'victory_road_1f'}
    for number,target in entry_targets.items():
        door=next((w for w in mainland['warps'] if w['to']==target),None)
        if door:
            events[number-1]['anchor']=[door['x']+0.5,door['y']+0.5]
            events[number-1]['entry_warp']={'map':door['map'],'index':door['index'],'to':door['to']}
    notes={1:'E02 그린 첫 승부·E03 새 목격과 첫 단서',2:'E09 상록숲 협상(숲은 별도 지도); 디그다굴 연결',
      3:'E06 달맞이산 서쪽 삐삐 통과 지원',4:'E07 달맞이산 출구 사건; 고정 크리시 도전',
      5:'E12 교배집 구애·선물·알; 노랑 북문·지하통로',6:'일반 도로 트레이너; 노랑 남문·지하통로',
      7:'무지개↔노랑 연결; 별도 고유 사건 없음',8:'일반 도로 트레이너·지하통로',9:'일반 도로 트레이너·돌산터널 방향',
      10:'E24 썬더 현장 단서·발전소; 돌산터널 조명 지원',11:'E14 잠만보 깨우기; 굴↔갈색 서쪽 통로 항상 유지',
      12:'해안 이동·수색 트레이너',13:'해안 이동·수색 트레이너',14:'해안 이동·수색 트레이너',
      15:'E17 메타몽 사건·E23 프리져 망원경 단서',16:'사이클링로드 북쪽 연결·수색 트레이너',17:'E24 썬더 목격담',
      18:'사이클링로드 남쪽 연결·수색 트레이너',19:'수상 이동·수영 트레이너',20:'E23 쌍둥이섬 퍼즐·프리져',21:'수상 이동·수영 트레이너',
      22:'E05 그린 초반/후반 재전·E11 스라크 구출',23:'E25 파이어 조사; 리그/챔피언전 스토리는 미구현',
      24:'노랑 첫 방문 후 공사 해제; 원작 기반 도로 수색 6팀',25:'E13 이수재 자료 보호·이브이 상담',
      26:'리그 게이트 왕복; 새 전투·NPC 사건 없음',27:'동성폭포 연결; 현재 지도 단계에서는 파도타기 통과, 폭포오르기 사건 미구현',
      28:'게이트↔은빛산 왕복; 레드전 미구현'}
    coverage=json.loads((ROOT/'assets/data/road_trainers.json').read_text())['coverage']
    for road in data['roads']:
        n=road['number'];keys=['route21_north','route21_south'] if n==21 else [f'route{n}']
        road.update(connection=LINKS[n],events=notes.get(n,'지도·출입구 구현. 성도 전용 야생·트레이너·스토리 미구현'),
          trainers=sum(len(coverage[k]['trainers'])+len(coverage[k]['fixed']) for k in keys if k in coverage) if n<=25 else 0,
          state='게임 내용 있음' if n<=25 else ('경계 이동 구현' if n<=28 else '지도 기반만 구현'))
    data['events']=events
    data['common_events']=[{'id':'F1','name':'피죤의 둥지와 1호 팬','place':'지정된 야외 지도에서 공중 Space 재입력','condition':'새 시작은 노랑 방문 후','content':'구구 Lv16 12마리(1.8초 간격) → 피죤 Lv25 → 화해','result':'날기 습득/피죤 지원; 구현된 방문 지역만 비행 가능'}]
    paths=['scripts/story/regional_quests.gd','scripts/story/campaign_quests.gd','scripts/story/campaign_director.gd','scripts/game.gd','scripts/story/gym_field_friends.gd','assets/data/road_trainers.json']
    data['source_hashes']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    write_markdown(data)
    print(json.dumps({'routes':len(data['roads']),'event_locations':len(events),'common_events':1,'general_road_trainers':sum(r['trainers'] for r in data['roads']),'output':str(OUT/'README.md')},ensure_ascii=False))


def write_markdown(data):
    lines=['# 도로번호와 현재 구현 이벤트','',
      '2026-11-10 현재 런타임 코드·퀘스트 목록과 원작 지도 자료를 대조했다. 후반 줄거리와 엔딩을 포함한다. 구현 표시는 코드·콘텐츠 연결 여부이며 이번 정리 작업에서 모든 사건을 다시 플레이했다는 뜻은 아니다.','',
      '![도로번호·사건번호 지도](route_event_atlas.png)','',
      '파란 숫자 1~48은 도로번호, 주황 E01~E25는 아래 사건 묶음이다. 사건번호는 진행 순서가 아니다. 실내 사건은 대응하는 야외 진입 지점/시설 주변에 표시한다. E18*은 별도 지도인 노랑시티·실프를 주변 네 관문 중심에 표시한 안내 위치이며 실제 야외 필드 좌표가 아니다. 피죤 F1은 고정 장소가 없어 지도에 한 곳으로 찍지 않는다.','',
      '**범위:** 관동 1~25번도로 + 경계 26~28번도로 + 성도 29~48번도로. 47·48번은 HGSS 기준이다. 원작 지리와 게임의 창작 사건은 구분한다. 이수재의 집은 25번도로다.','',
      '## 진행 조건 먼저 보기','',
      '- 노랑 첫 방문 전: 초반 여행·그린전·삐삐 통과 지원·새 목격 튜토리얼. 체육관은 잠겨 있고 야생/일반 도로 트레이너는 튜토리얼 레벨 제한을 따른다.',
      '- 노랑 첫 방문 후: 체육관 도전·지역 서브·세 전설의 새 조사. 24번도로 공사가 해제된다. 잠만보는 별도 깨우기 사건이 필요하다.',
      '- 본편 조사 네 곳은 순서 자유다. 실프/아지트/홍련의 `discover_requires`는 수첩 발견 힌트 조건이며 현장 조사를 막는 필수 선행 조건으로 쓰지 않는다.',
      '- 이슬은 달맞이산 채굴 조사 후 체육관으로 돌아온다. 관장전 승리 후 라프라스 수상 지원, 마티스 승리 후 피카츄 플래시 지원을 받는다. 기존 승리 저장의 지원 복원도 현재 Game에 연결되어 있다.',
      '- 새 지형 배치는 원작 길·수로·게이트를 따른다. 성도는 아직 지도 기반이며 원작 스토리까지 옮겨졌다는 뜻이 아니다.','',
      '## 관동 도로·수로 1~25','', '| 번호 | 연결 | 일반 트레이너 팀 | 사건·기능 |','|---:|---|---:|---|']
    for r in data['roads'][:25]:lines.append(f"| {r['number']} | {r['connection']} | {r['trainers']} | {r['events']} |")
    lines+=['','일반 도로 트레이너는 합계 **157팀**이다. 라이벌·로켓단·퀘스트 적·체육관은 별도다. 4번도로의 1팀은 고정 크리시이고 나머지는 기존 도로별 수색 방식이다. 1·2·5·7·22·23번도로의 0은 일반 도로 수색 팀이 없다는 뜻으로, 해당 지역의 이벤트 부재를 뜻하지 않는다.','',
      '## 관동·성도 경계 26~28','', '| 번호 | 연결 | 현재 상태 |','|---:|---|---|']
    for r in data['roads'][25:28]:lines.append(f"| {r['number']} | {r['connection']} | {r['events']} |")
    lines+=['','리그 게이트 동쪽은 관동 22번도로, 북쪽은 23번도로, 남쪽은 26번도로, 서쪽은 28번도로다. 갈색항↔담청항 연락선도 유지한다.','',
      '## 성도 도로·수로 29~48','', '| 번호 | 연결 | 이벤트 구현 |','|---:|---|---|']
    for r in data['roads'][28:]:lines.append(f"| {r['number']} | {r['connection']} | 지도·출입구 기반 |")
    lines+=['','**성도 공통 미구현:** 성도 전용 일반 트레이너·야생 출현표·8개 관장전·공박사 이야기·로켓단 라디오탑/야돈우물 사건·빨간 갸라도스·스이쿤/칠색조/루기아 본편·벌레잡기 대회·은빛산 레드전. 얼음 미끄럼·소용돌이·유적 퍼즐 등 동적 기믹도 지도 등록과 구분한다. 원작 민가나 시설이 보이더라도 해당 원작 보상/대사가 자동으로 있는 것은 아니다.','',
      '## 사건번호 E01~E25','', '| 번호 | 장소·사건 | 시작 조건 | 진행과 결과 |','|---|---|---|---|']
    for e in data['events']:lines.append(f"| {e['id']} | **{e['name']}** · {e['place']} | {e['condition']} | {e['content']} → {e['result']} |")
    lines+=['','## 고정 지점이 없는 사건 F1','',
      '**피죤의 둥지와 1호 팬:** 노랑 방문 후 해당 야외 지도에서 점프 중 Space를 다시 입력하면 발견한다. 구구 Lv16 12마리가 1.8초 간격으로 나오고 피죤 Lv25와 승부한 뒤 화해한다. 날기 호환 주인공은 기술을 배우고 비호환 종족은 도움을 받는다. 기존 방문 지역 제한과 도로 진행 조건은 유지한다.','',
      '## 체육관 8곳','', '| 위치 | 관장 | 조건·현재 역할 |','|---|---|---|']
    order=['pewter_gym','cerulean_city_gym','vermilion_city_gym','celadon_city_gym','fuchsia_city_gym','saffron_city_gym','cinnabar_island_gym','viridian_city_gym']
    for key in order:
        g=data['gyms'][key]
        note='노랑 첫 방문 후 도전'
        if key=='cerulean_city_gym':note+=' + 달맞이산 채굴 조사 완료; 승리 후 라프라스 수상 지원'
        if key=='vermilion_city_gym':note+='; 승리 후 플래시 습득/피카츄 조명 지원'
        if key=='viridian_city_gym':note='1세대: 본편 네 단서 결합 / 2세대: 다른 일곱 관장 승리 후; 아버지가 마지막 출전'
        lines.append(f"| {g['city']} | {g['name']} | {note} |")
    lines+=['','일반 체육관 멤버는 대화만 하고 관장만 배틀한다. 2세대 관장 회상은 부모가 실제로 상대해 본 관장만 발생한다. 세 전설의 새 완료는 비주기/아버지/뮤츠 진엔딩의 추가 조건이 아니다.','',
      '## 원작과 다른 점·폐기된 이벤트','',
      '- 도시·도로의 근거는 관동 FRLG, 성도 HGSS다. 포켓몬이 주인공인 이야기·친구 필드 지원·세대 계승·로사/로이 출구전 등은 이 게임의 각색이다.',
      '- 이수재의 옛 자동 포획/컬렉션 배틀과 승선 티켓 지급은 현재 진행에서 사용하지 않는다. 자료 탈취 저지와 이브이 상담이 현재 사건이다.',
      '- 10번도로 피카츄 독립 구출과 연분홍 라프라스 독립 구출은 폐기됐다. 현재 획득처는 마티스/이슬 관장 승리다.',
      '- 잠만보는 피리·포획 배틀 대신 오랭열매 3개와 대화로 깨운다. 타워 힌트는 존재하지만 현재 `snorlax_wake` 데이터의 필수 선행은 노랑 방문이며 타워 클리어는 강제하지 않는다.',
      '- 파이어의 현재 조우 위치는 챔피언로드 2층으로 각색했다. FRLG 원작 사건을 그대로 옮겼다고 표시하지 않는다.',
      '- 칠색조는 첫 목격 연출만 있다. 최종 칠색조 조우·전설 추적 전체 완료, 리그/챔피언전 진행은 미구현이다.',
      '- 지도 밖 임의 위치에 새 이벤트를 만들거나 기존 진행 조건을 바꾸지 않았다. 이번 변경은 번호·목록·안내용 렌더뿐이다.','',
      '## 확인 근거와 재생성','',
      '- [현재 코드 추출 목록](../route_event_inventory.json): 도로 48개, 지역 퀘스트 8개(2세대 숲 후손 포함), 캠페인 항목 15개(독립 목격담을 포함), 체육관 8곳. 퀘스트 개수와 E번호 개수는 사건 묶음 방식이 달라 같다거나 합산할 수 없다.',
      '- [통합 목록·좌표·소스 해시](catalog.json). 도로 위치는 실제 구역 사각형에서 추출한다. 사건 핀은 실내 좌표를 외부에 투영한 길찾기 안내다.',
      '- 실제 내용: `scripts/story/regional_quests.gd`, `campaign_quests.gd`, `campaign_director.gd`, `scripts/game.gd`, `scripts/data/rival_progression.gd`, `assets/data/road_trainers.json`.',
      '- 구현의 기존 검증 범위: [이벤트 기록](../../event_implementation_review/README.md), [통합 지형](../README.md), [도로 트레이너](../../road_trainers/README.md), [그린 재전](../../rival_progression/README.md). 이 문서 작성에서 이전 테스트를 새로 실행했다고 합산하지 않는다.','',
      '```sh',
      '/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/route_event_inventory.gd',
      'python3 tools/route_event_report.py',
      'ROUTE_EVENTS_ATLAS=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/run_visual_test.py tools/continent_overview_review.gd',
      '```','']
    (OUT/'README.md').write_text('\n'.join(lines))


if __name__=='__main__':build()
