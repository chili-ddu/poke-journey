# 플레이어 발자국 커서

- 원본 실루엣: pret/pokefirered `graphics/pokemon/<species>/footprint.png`의 원작 도감 발자국 16×16 도트. Nintendo / Game Freak / Creatures.
- 대상: 파이리·리자드·리자몽, 꼬부기·어니부기·거북왕, 이상해씨·이상해풀·이상해꽃.
- `tools/footprint_cursors.py`가 원작 픽셀 형태를 유지하고 승인된 포켓몬별 색상, 1px 크림색 테두리와 1px 검은 외곽선을 적용한다. 20×20 여백 포함 도트를 최근접 2배로 확대한 40×40 PNG이며 클릭 기준점은 맨 위 발가락의 색상 픽셀 중심이다.
- 원본은 생성기가 `third_party/pokefirered/`에 캐시하고, 각 출처·색상·클릭 기준점은 `footprints.json`에 기록한다.

재생성: `python3 tools/footprint_cursors.py`.
