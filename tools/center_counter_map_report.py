"""Publish the actual-map review captures and bounded collision results."""
import json
from pathlib import Path
R = Path(__file__).resolve().parents[1]
D = R / 'docs/source_object_audit/center_masks/counter_restored/map_review'
j = json.loads((D/'review.json').read_text())
routes = [r for r in j['checks'] if 'route' in r]
assert len(routes) == 6 and all(r['blocked_samples'] == 0 for r in routes)
assert all((D / f'{place}_{case}.png').is_file() for place in ['viridian_center','pewter_center'] for case in ['front','left','right','inside','rear_-1','rear_1'])
parts = ['''<!doctype html><meta charset="utf-8"><title>센터 지도 카운터 검토</title><style>body{background:#191e26;color:#eee;font:16px system-ui;margin:32px;max-width:1200px}img{width:100%;image-rendering:pixelated}a{color:#9cf}td,th{border:1px solid #777;padding:8px}table{border-collapse:collapse}</style><h1>센터 지도 카운터 검토</h1><p>상록·회색 센터를 실제 게임으로 로드하고, 실행 중 기존 카운터 하나만 검토 모델로 교체했습니다. 원본 지도·에셋·충돌 설정은 변경하지 않았습니다.</p><p>윗면과 원본 앞면에 더해 바깥 옆면·뒤 끝면·U자 안쪽 면 7개를 추가했습니다. 숨겨진 면은 원본 앞면의 온전한 한 열을 반복한 추정 디자인이며 원화 복원이 아닙니다. 기존 앞쪽 경계 z=4에 맞췄고 높이는 0.5칸입니다.</p><p>앞·좌·우 경로를 실제 플레이어 반경 8px와 Arena.resolve로 검사했습니다. 6개 경로 × 97지점에서 위치 보정 0. 통과 가능한 중심선 표본 검사이며, 모든 접근 각도·NPC 충돌·실제 이동 입력을 검증한 것은 아닙니다. 내부 장면은 가림 확인을 위해 직접 배치했으며 출입 경로를 보장하지 않습니다.</p><p>사선 검토 카메라 이동 후 캐릭터의 카메라 방향 보정도 재계산했습니다. 옆면·안쪽 면의 빈 구간이 채워지고 내부 캐릭터의 하체 가림을 확인했습니다. 화병 음영, 기존 회복 장치의 받침/배치, 장면 전체 광량은 이번 수정 대상이 아닙니다.</p><table><tr><th>지도</th><th>경로</th><th>표본</th><th>막힘</th></tr>''']
for r in routes:
 parts.append(f'<tr><td>{r["map"]}</td><td>{r["route"]}</td><td>{r["samples"]}</td><td>{r["blocked_samples"]}</td></tr>')
parts.append('</table>')
for place,label in [('viridian_center','상록 센터'),('pewter_center','회색 센터')]:
 parts.append(f'<h2>{label}</h2>')
 for case,title in [('front','앞쪽'),('left','왼쪽 통로'),('right','오른쪽 통로'),('inside','내부 가림 — 직접 배치'),('rear_-1','뒤쪽 사선 A'),('rear_1','뒤쪽 사선 B')]:
  parts.append(f'<h3>{title}</h3><img loading="lazy" src="{place}_{case}.png">')
parts.append('<p>재현: <code>godot --path . --script tools/center_counter_walk_review.gd</code> → <code>python3 tools/center_counter_map_report.py</code></p><a href="review.json">검사 좌표·결과</a>')
(D/'index.html').write_text(''.join(parts))
print('12 map captures; 582 collision samples; 0 blocked')
