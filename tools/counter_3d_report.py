"""Summarize the isolated Godot captures without changing source assets."""
import json
from pathlib import Path
from PIL import Image, ImageChops
D = Path(__file__).resolve().parents[1] / 'docs/source_object_audit/center_masks/counter_restored/godot_review'
report = json.loads((D / 'review.json').read_text())
diffs = {}
for name in ['original', 'moved']:
    a = Image.open(D / f'{name}_shadows.png').convert('RGB')
    b = Image.open(D / f'{name}_no_shadows.png').convert('RGB')
    delta = ImageChops.difference(a, b)
    diffs[name] = {'difference_bounds': delta.getbbox(), 'maximum_channel_difference': max(v[1] for v in delta.getextrema())}
report['shadow_comparison'] = diffs
report['visual_findings'] = ['Prop bottoms meet tabletop in this isolated scene.', 'Cyan depth probe hidden behind fascia, visible in front.', 'Gray vase base outline persists with geometry shadow casting disabled.', 'Side/back faces and in-map character interactions remain unvalidated.']
(D / 'review.json').write_text(json.dumps(report, indent=2))
parts = ['''<!doctype html><meta charset="utf-8"><title>Godot 카운터 배치 검토</title><style>body{background:#191e26;color:#eee;font:16px system-ui;margin:32px;max-width:1152px}img{width:100%;image-rendering:pixelated}a{color:#9cf}section{margin-bottom:40px}</style><h1>Godot 카운터 배치 검토</h1><p>실제 Godot 렌더링. View3D의 카메라 각도·거리·화각과 실내 조명 설정을 사용했습니다. 윗면 높이 0.5칸과 윗면/앞면 분할은 검토용 가정입니다. 게임 지도·충돌·팔레트·후처리는 적용하지 않았습니다.</p><p>소품 밑단은 윗면에 맞닿습니다. 청록 표식은 카운터 뒤에서 가려지고 앞에서는 드러납니다. 화병 밑 회색 음영은 동적 그림자를 꺼도 남습니다. 옆면·뒷면은 아직 없어 시점을 바꾸면 빈 면이 드러날 수 있습니다.</p>''']
for name, label in [('original_no_shadows','원위치 · 동적 그림자 없음'),('original_shadows','원위치 · 동적 그림자 있음'),('moved_no_shadows','이동 · 동적 그림자 없음'),('moved_shadows','이동 · 동적 그림자 있음'),('depth_behind_front','청록 표식 · 카운터 뒤 (가려짐)'),('depth_in_front','청록 표식 · 카운터 앞 (보임)')]:
    parts.append(f'<section><h2>{label}</h2><img src="{name}.png"></section>')
parts.append('<p>재현: <code>godot --path . --script tools/counter_3d_review.gd</code> 후 <code>python3 tools/counter_3d_report.py</code></p><a href="review.json">검증 기록</a> · <a href="../index.html">복원 검토</a>')
(D / 'index.html').write_text(''.join(parts))
print(json.dumps(diffs))
