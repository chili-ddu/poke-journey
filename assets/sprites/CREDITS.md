# 도트 출처

(2026-10-27 정리: 파이리 계열과 상록숲 포켓몬만 남겼다. 꼬렛·뚜벅쵸·발챙이·갸라도스는 삭제.)

[PMD Sprite Collab](https://github.com/PMDCollab/SpriteCollab) 저장소의 `sprite/<도감번호>/`에서 2026-10-26에 받았다. 걷기·대기·피격·공격 시트와 `AnimData.xml`만 가져왔다.

| 번호 | 포켓몬 | 작업자 (각 폴더 `credits.txt`) |
|---|---|---|
| 0004 | 파이리 | CHUNSOFT |
| 0005 | 리자드 | CHUNSOFT, PMDCollab 기여자 3명 (Discord ID 193530896211509248, 199989579682414592, 217653022094786560) |
| 0006 | 리자몽 | CHUNSOFT, PMDCollab 기여자 1명 (Discord ID 237286997645983744) |

- CHUNSOFT 표기는 "포켓몬 불가사의 던전" 원작 게임에서 추출한 도트다. 저작권은 닌텐도·춘소프트·포켓몬컴퍼니에 있다.
- 기여자 작업분은 CC BY-NC 4.0 조건이다. 비상업 용도로만 쓸 수 있고 출처를 밝혀야 한다.
- 포켓몬 IP라서 이 게임은 개인 용도로만 쓰고 배포하지 않는다.

## 상록숲 (2026-10-26 추가)

| 번호 | 포켓몬 | 작업자 |
|---|---|---|
| 0010 | 캐터피 | CHUNSOFT |
| 0011 | 단데기 | CHUNSOFT |
| 0013 | 뿔충이 | CHUNSOFT |
| 0014 | 딱충이 | CHUNSOFT |
| 0015 | 독침붕 | CHUNSOFT (대기 동작 시트 없음 → 걷기로 대신) |
| 0025 | 피카츄 | CHUNSOFT |
- 2026-10-27 추가: 0015 독침붕 Jab-Anim/Offsets, Shoot-Anim/Offsets; 0013 뿔충이 Shoot-Anim/Offsets (같은 출처 PMDCollab/SpriteCollab, CC BY-NC 4.0 — 기여자는 각 폴더의 credits 참고).

## 1번도로 (2026-10-28 추가)

| 번호 | 포켓몬 | 작업자 |
|---|---|---|
| 0016 | 구구 | CHUNSOFT (Trip·HitGround 는 기여자 CC BY-NC 4.0 — 폴더의 credits.txt) |
| 0019 | 꼬렛 | CHUNSOFT |
- 2026-10-28 추가: 0004 파이리·0005 리자드 Eat-Anim/Offsets(열매 먹기 동작, CHUNSOFT, 같은 출처 PMDCollab/SpriteCollab). 0006 리자몽은 원본에 Eat 시트가 없다.

## 이로치 (2026-10-28 추가)

같은 저장소의 이로치 폴더 `sprite/<도감번호>/0000/0001/` 에서 받아 각 폴더의 `shiny/` 에 넣었다(`python3 -I tools/pmd_fetch.py --shiny …`). 작업자와 조건은 `shiny/credits.txt` 에 있다(CHUNSOFT 원작 추출분 또는 CC BY-NC 4.0 기여자 작업). 게임 동작을 보통 시트와 같게 하려고 보통 시트에 없는 동작은 지웠다. 0016 구구 이로치엔 넘어짐(Trip·HitGround)이 없어서, 같은 폴더의 다른 시트 8장에서 어긋남 0 으로 확인한 보통→이로치 색 대응표로 보통 시트를 칠해 만들었다(오프셋 시트와 AnimData.xml 은 보통 것 그대로).

## 이상해씨·꼬북이 계열 (2026-10-28 추가)

시작 화면에서 고르는 스타팅 두 계열(사용자 결정). 같은 저장소의 `sprite/<번호>/`(보통)과 `sprite/<번호>/0000/0001/`(이로치, 각 폴더 `shiny/`)에서 받았다.

| 번호 | 포켓몬 | 작업자 |
|---|---|---|
| 0001 | 이상해씨 | 각 폴더 `credits.txt` |
| 0002 | 이상해풀 | 각 폴더 `credits.txt` |
| 0003 | 이상해꽃 | 각 폴더 `credits.txt` |
| 0007 | 꼬북이 | 각 폴더 `credits.txt` |
| 0008 | 어니부기 | 각 폴더 `credits.txt` |
| 0009 | 거북왕 | 각 폴더 `credits.txt` |

- 기술 동작용으로 Dance(꽃잎댄스·달콤한향기, Shake 의 복사본)·Rotate(고속스핀)·Withdraw(껍질에숨기)·Double(덩굴채찍) 시트도 받았다.
- CHUNSOFT 표기분은 원작 게임 추출(닌텐도·춘소프트·포켓몬컴퍼니), 기여자 작업분은 CC BY-NC 4.0. 개인 용도로만.

## 회색체육관 트레이너 포켓몬 (2026-10-29 추가)

트레이너 배틀(사용자 결정)로 캠프보이 리암·관장 웅의 포켓몬. 같은 저장소의 `sprite/<번호>/`(보통)과 `sprite/<번호>/0000/0001/`(이로치, 각 폴더 `shiny/`).

| 번호 | 포켓몬 | 작업자 |
|---|---|---|
| 0027 | 모래두지 | 각 폴더 `credits.txt` |
| 0074 | 꼬마돌 | 각 폴더 `credits.txt` |
| 0095 | 롱스톤 | 각 폴더 `credits.txt` |

- CHUNSOFT 표기분은 원작 게임 추출(닌텐도·춘소프트·포켓몬컴퍼니), 기여자 작업분은 CC BY-NC 4.0. 개인 용도로만.

### 2026-11-04 관동 야생 11종 추가

PMDCollab/SpriteCollab의 기존 PMD 도트를 사용했다. 일반·이로치 각각의 원본 `AnimData.xml`, 오프셋 및 `credits.txt`를 보존했다. 기존 커스텀 도트는 덮어쓰지 않는다.

| 번호 | 포켓몬 | 기여자·원본 출처 |
|---|---|---|
| 0021 | 깨비참 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0021), 각 폴더와 shiny/credits.txt |
| 0023 | 아보 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0023), 각 폴더와 shiny/credits.txt |
| 0029 | 니드런♀ | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0029), 각 폴더와 shiny/credits.txt |
| 0032 | 니드런♂ | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0032), 각 폴더와 shiny/credits.txt |
| 0035 | 삐삐 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0035), 각 폴더와 shiny/credits.txt |
| 0039 | 푸린 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0039), 각 폴더와 shiny/credits.txt |
| 0041 | 주뱃 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0041), 각 폴더와 shiny/credits.txt |
| 0043 | 뚜벅쵸 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0043), 각 폴더와 shiny/credits.txt |
| 0046 | 파라스 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0046), 각 폴더와 shiny/credits.txt |
| 0052 | 나옹 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0052), 각 폴더와 shiny/credits.txt |
| 0056 | 망키 | [원본](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0056), 각 폴더와 shiny/credits.txt |

### 2026-11-04 낚시·수상 11종 추가

`tools/kanto_water_assets.py`로 같은 PMDCollab/SpriteCollab 원본의 일반·이로치 시트, 오프셋, 메타데이터와 기여자 기록을 보존했다. 각 폴더와 `shiny/credits.txt`가 상세 출처다.

| 번호 | 포켓몬 | 원본 |
|---|---|---|
| 0054 | 고라파덕 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0054) |
| 0060 | 발챙이 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0060) |
| 0061 | 슈륙챙이 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0061) |
| 0072 | 왕눈해 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0072) |
| 0090 | 셀러 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0090) |
| 0098 | 크랩 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0098) |
| 0116 | 쏘드라 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0116) |
| 0117 | 시드라 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0117) |
| 0118 | 콘치 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0118) |
| 0129 | 잉어킹 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0129) |
| 0130 | 갸라도스 | [PMDCollab](https://github.com/PMDCollab/SpriteCollab/tree/master/sprite/0130) |

- 달맞이산 트레이너 파티 추가: 0069 모다피·0081 코일·0100 찌리리공 및 이로치. PMDCollab/SpriteCollab의 해당 번호 일반·`0000/0001` 시트. 작업자·동작별 기여는 각 폴더 `credits.txt` 참조(CHUNSOFT 원작 추출분 또는 CC BY-NC 4.0 기여자 작업). 기존 `tools/pmd_fetch.py`와 같은 동작·오프셋 원본을 사용.

- 그린 첫 배틀·달맞이산 졸업 배틀: 0133 이브이·0109 또가스 및 이로치. PMDCollab/SpriteCollab의 해당 번호 일반/`0000/0001` 시트, 동작별 작업자는 각 `credits.txt` 참조(CHUNSOFT 원작 추출 또는 CC BY-NC 4.0).

- 블루시티·북쪽 도로 구간: 0017 피죤, 0047 파라섹트, 0063 캐이시, 0066 알통몬, 0079 야돈, 0120 별가사리, 0121 아쿠스타 및 이로치. PMDCollab/SpriteCollab 해당 번호 일반 및 `0000/0001` 시트. 동작별 원작 추출(CHUNSOFT)·CC BY-NC 4.0 기여자 이름은 각 폴더 `credits.txt`에 기록되어 있다.

- 이수재 연구 배틀: 윤겔라(0064)·샤미드(0134)·쥬피썬더(0135)·부스터(0136)의 일반·이로치 PMDCollab/SpriteCollab 동작 및 중심점 시트. `tools/bill_research_assets.py`로 누락 파일만 추가하며, 각 폴더의 `credits.txt`에 기여자를 보존한다. 이브이(0133)는 기존 시트를 사용한다.

- 2026-11-06 관동 전체 야생: `assets/data/kanto_world_wild.json`의 `species` 목록 80종이 사용하는 누락 일반·이로치 동작 및 오프셋 시트를 `tools/kanto_world_wild_assets.py`로 PMDCollab/SpriteCollab 해당 도감 번호 폴더와 `0000/0001`에서 보충했다. 기존 파일·커스텀 동작은 유지한다. 원본별 기여자와 CHUNSOFT 추출/CC BY-NC 4.0 기여 기록은 각 일반·이로치 폴더의 `credits.txt`에 있다. C 보간 프레임은 기존 `tools/bake_smooth_sprites.py`로 이 원본 도트에서 파생했다.
