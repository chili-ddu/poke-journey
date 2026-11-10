"""Curated visual source inventory; run source_object_audit.py first. No runtime writes."""
import json, hashlib, html
from pathlib import Path
R=Path(__file__).resolve().parents[1]; O=R/'docs/source_object_audit'
inv=json.loads((O/'inventory.json').read_text()); specs={}
def group(names,items):
 for name in names: specs[name]=list(items)
# Each rectangle is a source TILE envelope, not a final alpha mask or physical footprint.
def e(label,category,box,parent=None,note=''):
 return dict(label=label,category=category,bounds_tiles=box,parent=parent,note=note)
def rects(label,cat,boxes):return [e(f'{label} {i+1}',cat,b) for i,b in enumerate(boxes)]
base_center=[e('위벽·몰딩·사선 벽','wallpaper',[0,0,15,3],note='사물 영역 제외 필요; 사선 벽은 구조물로 별도 절단'),e('카운터','floor_object',[4,2,11,4]),e('PC·받침','floor_object',[11,0,12,3]),e('책장/보관장','floor_object',[2,0,4,3]),e('화분','floor_object',[1,1,2,3]),e('회복 장치','surface_object',[5,1,7,3],'카운터', '원본에서 장치와 카운터 앞뒤 관계가 겹침. 정확한 받침 높이 재확인'),e('단말·명패 장치','surface_object',[9,1,10,3],'카운터'),e('벽걸이 화면','wall_object',[7,0,9,2]),e('벽걸이 지도','wall_object',[12,1,14,2]),e('왼쪽 계단','structure',[0,5,2,8]),e('출입구 깔개','floor_decal',[6,8,9,10]),e('바닥 중앙 문양','floor_decal',[6,4,9,8])]+rects('카운터 화병','surface_object',[[4,2,5,4],[10,2,11,4]])+[e('대기석·테이블 묶음','floor_object',[11,5,15,8],note='좌석 4개와 테이블을 개별 마스크로 나눌 것')]
group(['viridian_center','pewter_center'],base_center)
def home(offset,w,stairs=False,books=False):
 a=[e('위벽·걸레받이','wallpaper',[0,0,w,2]),e('주방 싱크·조리대','floor_object',[offset,1,offset+2,3],note='수전과 조리대의 표면/앞면 분리 필요'),e('수납장','floor_object',[offset+2,1,offset+4,3]),e('수납장 옆 작은 원통형 물체','floor_object',[offset+4,1,offset+5,3],note='정확한 종류 미확정; 쓰레기통/생활 소품 후보'),e('TV·받침대','floor_object',[offset+5,0,offset+6,3],note='이전 시계 설명을 정정. 화면 형태의 바닥 가전 후보'),e('창문','wall_object',[offset+6,0,offset+8,2]),e('식탁','floor_object',[offset+5,4,offset+7,6]),e('식탁 깔개','floor_decal',[offset+3,3,offset+9,7])]
 a+=rects('의자','floor_object',[[offset+4,y,offset+5,y+1] for y in [4,5,6]]+[[offset+7,y,offset+8,y+1] for y in [4,5,6]])
 a+=rects('화분','floor_object',[[offset,6,offset+1,8],[w-1,6,w,8]])
 a += [e('출입구 깔개','floor_decal',[offset+2,7 if w==11 else 8,offset+4,9 if w==11 else 10])]
 if stairs:a += [e('올라가는 계단·난간','structure',[10,1,13,4]),e('계단 앞 깔개','floor_decal',[10,2,11,4])]
 else:a += [e('벽걸이 지도/그림','wall_object',[9,0,11,2])]
 if books:a += [e('책장','floor_object',[11,0,13,3])]
 return a
group(['players_house_1f'],home(1,13,True));group(['rivals_house'],home(0,13,False,True));group(['pewter_house1','pewter_house2'],home(0,11))
group(['players_house_2f'],[e('위벽','wallpaper',[0,0,12,2]),e('PC·책상','floor_object',[1,0,3,3]),e('의자','floor_object',[3,1,4,3]),e('책장','floor_object',[4,0,6,3]),e('달력','wall_object',[11,0,12,2]),e('내려가는 계단·난간','structure',[8,1,10,4]),e('계단 깔개','floor_decal',[10,2,11,4]),e('TV·받침','floor_object',[6,3,7,6]),e('게임기·조작기','floor_object',[6,5,7,7],note='TV와 겹치는 범위. 기기별 마스크 확인'),e('침대','floor_object',[1,4,4,7]),e('방 깔개','floor_decal',[4,4,10,8])])
group(['oaks_lab'],[e('위벽','wallpaper',[0,0,13,2]),e('왼쪽 장비·캐비닛 묶음','floor_object',[0,0,2,3],note='장비 종류별 세분화 필요'),e('컴퓨터 책상','floor_object',[2,1,4,3]),e('책상 위 PC','surface_object',[2,0,4,2],'컴퓨터 책상'),e('옆 책상','floor_object',[4,1,6,3]),e('녹색 탁자','floor_object',[8,4,11,6]),e('독립 기계','floor_object',[1,3,3,6]),e('왼쪽 작은 패널 두 개','structure',[0,3,1,5],note='벽 부착/바닥 배치 의도 재확인; 이전 사용자 배치 지시와 대조'),e('중앙 책장 왼쪽','floor_object',[0,7,5,10]),e('중앙 책장 오른쪽','floor_object',[8,7,13,10]),e('뒤 책장 왼쪽','floor_object',[9,1,11,3]),e('뒤 책장 오른쪽','floor_object',[11,1,13,3]),e('창문/유리 패널','wall_object',[8,0,9,2])]+rects('벽걸이 문서','wall_object',[[6,0,7,2],[7,0,8,2]])+rects('화분','floor_object',[[0,11,1,13],[12,11,13,13]])+[e('출입구 깔개','floor_decal',[5,12,7,14])])
mart=[e('위벽·사선 벽','wallpaper',[0,0,11,3]),e('벽걸이 게시물','wall_object',[2,0,3,2]),e('창문 묶음','wall_object',[4,0,7,2],note='3개 창 개별 분리'),e('카운터·뒤 계산대','floor_object',[0,2,4,5]),e('계산기','surface_object',[3,1,4,3],'카운터·뒤 계산대'),e('화분','floor_object',[1,1,2,3]),e('뒤 진열장','floor_object',[7,0,10,3],note='두 개 진열장 분리'),e('작은 진열대','floor_object',[1,5,3,7]),e('중앙 양면 진열대','floor_object',[7,3,9,7]),e('오른쪽 양면 진열대','floor_object',[10,3,11,7],note='지도 경계에서 잘림'),e('출입구 깔개','floor_decal',[3,7,5,9])]
group(['viridian_mart','pewter_mart'],mart)
gate=[e('위벽','wallpaper',[0,0,15,2]),e('윗문·출입구','structure',[6,0,9,2]),e('아래 출입구','floor_decal',[6,10,9,12]),e('긴 중앙 깔개','floor_decal',[6,3,9,9])]+rects('창문','wall_object',[[2,0,4,2],[11,0,13,2]])+rects('화분','floor_object',[[x,y,x+1,y+2] for x,y in [(1,1),(5,1),(9,1),(13,1),(1,4),(2,4),(1,7),(2,7)]])+rects('테이블','floor_object',[[11,4,13,6],[11,7,13,9]])+[e('좌석 묶음','floor_object',[10,4,14,9],note='테이블을 제외한 의자 4개로 세분화')]
group(['forest_gate_north','forest_gate_south'],gate)
group(['pewter_gym'],[e('상단·옆벽','wallpaper',[0,0,13,16],note='방 전체 외곽 범위; 바닥 제외 마스크 필요'),e('상단 원형 표식','wall_object',[6,0,7,1],note='문양인지 부착물인지 확인 필요'),e('뒤 벽 패널/좌석','structure',[4,1,9,2],note='작은 4개 형상의 의미 미확정'),e('중앙 바위·단상','structure',[4,4,9,8]),e('바닥 길·단차','structure',[1,3,12,15]),e('출입구','floor_decal',[5,14,8,16])]+rects('바위','floor_object',[[x,y,x+1,y+1] for x,y in [(5,3),(7,3),(4,5),(8,5),(3,7),(5,7),(7,7),(9,7),(1,8),(11,8),(4,9),(8,9),(1,10),(11,10)]])+rects('석상·받침','floor_object',[[4,11,5,13],[8,11,9,13]]))
museum1=[e('위벽','wallpaper',[0,0,28,2]),e('계단·난간','structure',[9,5,12,10]),e('L자 칸막이','structure',[15,2,18,10]),e('작은 의자/받침','floor_object',[22,3,23,5],note='의미 미확정'),e('오른쪽 전시기기','floor_object',[27,3,28,8],note='지도 끝에서 잘림; 두 기기 분리'),e('둥근 바닥 표식','floor_decal',[16,3,27,8],note='원형 4개 각각 확인; 사물로 올리지 않음')]+rects('전시 케이스','floor_object',[[3,3,7,6],[3,6,7,9]])+rects('위벽 기둥','structure',[[1,0,2,3],[5,0,6,3],[9,0,10,3]])+rects('창문','wall_object',[[3,0,4,2],[7,0,8,2]])+rects('벽걸이 표지','wall_object',[[11,0,12,2],[13,0,14,2]])+rects('책장','floor_object',[[17,0,19,3],[19,0,21,3],[24,0,26,3],[26,0,28,3]])+rects('화분','floor_object',[[0,1,1,3],[0,8,1,10],[16,8,17,10],[24,8,25,10],[25,8,26,10]])+rects('출입구','floor_decal',[[13,9,15,11],[20,9,22,11]])
group(['pewter_museum_1f'],museum1)
group(['pewter_museum_2f'],[e('위벽','wallpaper',[0,0,19,2]),e('전시 케이스','floor_object',[2,4,6,8]),e('모형·받침','floor_object',[14,4,17,6],note='우주선 모형은 받침 위 사물로 추가 분리'),e('계단·난간','structure',[8,5,11,10])]+rects('기둥','structure',[[x,0,x+1,3] for x in [1,5,9,17]])+rects('창문','wall_object',[[x,0,x+1,2] for x in [3,7,11,13,15]])+rects('화분','floor_object',[[0,1,1,3],[18,1,19,3],[0,8,1,10],[17,8,18,10],[18,8,19,10]]))
labels={'wallpaper':'벽지','wall_object':'벽걸이','floor_object':'바닥 사물','surface_object':'가구 위 사물','structure':'구조물','floor_decal':'바닥 무늬'}
records=[]
for row in inv:
 name=row['map']; w,h=row['size_tiles']; objects=[]
 for i,item in enumerate(specs[name]):
  b=item['bounds_tiles']; assert 0<=b[0]<b[2]<=w and 0<=b[1]<b[3]<=h,(name,item)
  item.update(id=f'{name}:{i+1:02}',bounds_pixels=[v*16 for v in b],bounds_status='tile_envelope_not_pixel_mask',mask_status='pending',footprint_status='pending',placement_height=None)
  # Collision data is evidence, never equated with object's true footprint.
  j=json.loads((R/'assets/maps'/name/'map.json').read_text())
  item['source_solid_tiles']=[[x,y] for y in range(b[1],b[3]) for x in range(b[0],b[2]) if j['solid'][y][x]=='1']
  objects.append(item)
 row.update(review='source_visual_reviewed',objects=objects);records.append(row)
result={'scope':'15 indoor maps only; excludes exterior and battle arenas','status':'semantic inventory complete; pixel masks, grouped instances, physical footprints and placement heights pending','coordinate_system':'unpadded source pixels; rectangles [x0,y0,x1,y1), tile=16px','categories':labels,'maps':records}
(O/'catalog.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
parts=['<!doctype html><meta charset="utf-8"><title>원본 사물 분석</title><style>body{font:15px system-ui;background:#151a22;color:#e5e9ef;margin:32px;max-width:1400px}a{color:#9ecbff}table{border-collapse:collapse;width:100%;margin-bottom:40px}td,th{padding:8px;border:1px solid #48505d;text-align:left}img{image-rendering:pixelated;max-width:100%}small{color:#afb9c7}</style><h1>실내 원본 사물 분석</h1><p>원본 bottom.png + top.png 기준, 실내 15개. 게임/생성 에셋 변경 없음. 범위는 타일 단위 후보 영역이며 정확한 누끼·충돌·배치 높이는 미확정입니다. 범위가 겹치는 부모/자식 및 묶음 항목이 있으므로 행 수는 사물 개수가 아닙니다.</p><p>TV·받침대를 시계로 설명했던 이전 판단을 정정합니다. 벽 옆에 있다는 이유로 벽걸이로 분류하지 않습니다. 공간 한 칸 확장은 이 분석 다음 단계입니다.</p><p><a href="center_masks/index.html">센터 픽셀 경계 검토</a></p><nav>']
parts+=['<a href="#'+r['map']+'">'+r['map']+'</a> · ' for r in records];parts+=['</nav>']
for r in records:
 parts += [f'<section id="{r["map"]}"><h2>{r["map"]}</h2><img src="{r["map"]}.png"><table><tr><th>항목</th><th>분류</th><th>원본 타일 범위</th><th>부착 대상/검토 사항</th></tr>']
 for o in r['objects']:parts += [f'<tr><td>{html.escape(o["label"])}</td><td>{labels[o["category"]]}</td><td>{o["bounds_tiles"]}</td><td>{html.escape((o["parent"] or "")+" "+o["note"])}</td></tr>']
 parts+=['</table></section>']
(O/'index.html').write_text(''.join(parts))
print('maps',len(records),'candidate rows',sum(len(r['objects']) for r in records))
# Source fingerprints captured before review must still match.
for r in records:
 for f,h in r['sha256'].items():assert hashlib.sha256((R/'assets/maps'/r['map']/f).read_bytes()).hexdigest()==h
print('source hashes and all bounds verified')
