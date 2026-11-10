# 소리 출처

원작 자료는 Nintendo / Game Freak — personal use 로만. 모두 원작 악보·악기를 도구로 합성한 흉내라 원작 소리와 똑같지는 않다.
사용자 결정 2026-10-29: **장소 곡은 파이어레드, 시스템·배틀·팡파르는 플래티넘**. 배치는 `scripts/bgm.gd`.

## 파이어레드 장소 곡 — `tools/frlg_music.py`

pret/pokefirered 의 `sound/songs/midi/<곡>.mid`(악보)·`midi.cfg`(악기 묶음·볼륨·리버브)·`sound/voice_groups.inc`·`sound/direct_sound_samples/*.wav`·
`sound/programmable_wave_samples/*.pcm` 을 GBA 사운드 엔진(m4a)처럼 합성(13379Hz). 처음 → 반복 두 번을 굽고 둘째 반복을 WAV smpl 루프로.

| 파일 | 원작 곡 | 쓰는 곳 |
|---|---|---|
| `mus_pallet.wav` | MUS_PALLET | 태초마을, 주인공·라이벌의 집 |
| `mus_oak_lab.wav` | MUS_OAK_LAB | 오박사 연구소 |
| `mus_route1.wav` | MUS_ROUTE1 | 1번도로·2번도로 |
| `mus_pewter.wav` | MUS_PEWTER | 상록시티·회색시티, 상록숲 관문, 박물관, 민가 |
| `mus_poke_center.wav` | MUS_POKE_CENTER | 포켓몬센터·프렌들리숍 |
| `mus_viridian_forest.wav` | MUS_VIRIDIAN_FOREST | 상록숲(야생 배틀도 그대로) |
| `mus_gym.wav` | MUS_GYM | 회색체육관 |
| `mus_celadon.wav` | MUS_CELADON | 무지개시티 |
| `mus_cinnabar.wav` | MUS_CINNABAR | 홍련섬 |
| `mus_evolution.wav` | MUS_EVOLUTION | 사파리존·휴게소 |
| `mus_game_corner.wav` | MUS_GAME_CORNER | 게임코너 |
| `mus_poke_mansion.wav` | MUS_POKE_MANSION | 포켓몬저택 |
| `mus_poke_tower.wav` | MUS_POKE_TOWER | 포켓몬타워 |
| `mus_rocket_hideout.wav` | MUS_ROCKET_HIDEOUT | 로켓단 아지트 |
| `mus_silph.wav` | MUS_SILPH | 실프주식회사 |
| `mus_slow_pallet.wav` | MUS_SLOW_PALLET | 전당등록실 |
| `mus_victory_road.wav` | MUS_VICTORY_ROAD | 석영고원·23번도로·리그 마지막 방 |

## 플래티넘 곡 — `tools/plat_music.py`

pret/pokeplatinum 의 `res/prebuilt/data/sound/sound_data.sdat`(원작 사운드 묶음: SSEQ 악보·SBNK 악기·SWAR 샘플) 하나를
NDS 사운드 드라이버처럼 해석해 합성(32728Hz, 모노).

| 파일 | 원작 곡 | 쓰는 곳 |
|---|---|---|
| `seq_title01.wav` | SEQ_TITLE01 | 시작 화면 |
| `seq_eye_boy.wav` | SEQ_EYE_BOY | 곤충채집소년·캠프보이와 눈이 마주쳤을 때 |
| `seq_ba_train.wav` | SEQ_BA_TRAIN | 트레이너 배틀 |
| `seq_ba_gym.wav` | SEQ_BA_GYM | 관장 배틀 |
| `seq_wintrain.wav` | SEQ_WINTRAIN | 트레이너에게 이긴 뒤 |
| `seq_wintgym.wav` | SEQ_WINTGYM | 관장에게 이긴 뒤 |
| `seq_badge.wav` | SEQ_BADGE | 배지를 받을 때(팡파르) |
| `seq_fanfa1.wav` | SEQ_FANFA1 | 레벨업(팡파르) |
| `seq_shinka.wav` | SEQ_SHINKA | 진화하는 동안 |
| `seq_fanfa5.wav` | SEQ_FANFA5 | 진화 완료(팡파르) |
| `seq_fanfa4.wav` | SEQ_FANFA4 | 도구를 받을 때(팡파르 — 상록시티 비주기의 변함없는돌) |
| `seq_waza.wav` | SEQ_WAZA | 기술머신을 받을 때(팡파르 — 새미·웅) |
| `seq_the_riv.wav` | SEQ_THE_RIV | 라이벌 등장(1번도로 그린) |
| `seq_ba_rival.wav` | SEQ_BA_RIVAL | 라이벌 배틀(1번도로 그린) |
| `seq_asa.wav` | SEQ_ASA | 포켓몬센터 회복(팡파르) |

## 효과음·울음소리 (`assets/audio/se/`, `assets/audio/cry/`, tools/plat_sfx.py, 2026-10-30)

| 파일 | 원작 | 쓰임 |
|---|---|---|
| `se/select.wav` | SEQ_SE_DP_SELECT | 커서·글 넘김·취소 |
| `se/decide.wav` | SEQ_SE_DP_DECIDE | 결정 |
| `se/pinpon.wav` | SEQ_SE_DP_PINPON | "!"(알아챔) |
| `se/door.wav` | SEQ_SE_DP_DOOR | 문 |
| `se/dansa.wav` | SEQ_SE_DP_DANSA | 언덕 뛰어내리기·점프 |
| `se/save.wav` | SEQ_SE_DP_SAVE | 저장 |
| `se/regi.wav` | SEQ_SE_DP_REGI | 상점 계산 |
| `se/pc_login.wav` | SEQ_SE_DP_PC_LOGIN | 시작 화면(PC 박스) |
| `se/kouka_h.wav` · `kouka_m.wav` · `kouka_l.wav` | SEQ_SE_DP_KOUKA_H/M/L | 맞힘(효과가 굉장했다 / 보통 / 별로) |
| `se/bowa.wav` | SEQ_SE_DP_BOWA | 볼 열림 |
| `se/mv_<기술>.wav` | 각 기술의 `res/moves/<기술>/anim.s` 가 처음 울리는 SEQ_SE_DP_* | 기술을 쓸 때 |
| `cry/<종족>.wav` | SDAT `WAVE_ARC_PV<전국도감번호>` 의 파형(10512 Hz) | 울음소리(내보낼 때·나타날 때·상태창·쓰러질 때) |

전부 Nintendo / Game Freak 저작물의 디컴파일(pret/pokeplatinum) 결과에서 합성·추출 — personal use 로만.


## 2026-11-04 관동 신규 기술·종족 소리 보완

`tools/kanto_audio.py`는 빠져 있던 관동 기술 12개의 SE를 각 기술의 원본 `res/moves/<기술>/anim.s` 첫 SE와 기존 플래티넘 SDAT 합성기로 생성한다. 일반 도트가 추가된 관동 종족의 누락 울음소리도 같은 SDAT의 원본 SWAV에서 추출한다. 기존 WAV는 덮어쓰지 않는다. 차밍보이스는 플래티넘에 없는 기술이므로 하이퍼보이스의 종족 울음소리 연출 방식을 재사용하며, 별도의 원작 차밍보이스 SE라고 표기하지 않는다.

- `mus_route24.wav`: pret/pokefirered MUS_ROUTE24 원작 MIDI·악기 데이터에서 `tools/frlg_music.py mus_route24`로 변환, 원작 루프 구간 유지. 24·25번도로에 사용한다.

- 2026-11-06 관동 전체 야생: `assets/data/kanto_world_wild.json`에 등록한 80종의 누락 울음소리를 플래티넘 SDAT의 `WAVE_ARC_PV<도감 번호>`에서 추출했다. 박치기·핥기·진흙뿌리기·얼다바람·카운터·미러코트·변신·째려보기의 누락 SE는 각 원작 `res/moves/*/anim.s`의 첫 유효 시퀀스로 합성한다(`tools/kanto_world_wild_fx.py`, `tools/kanto_audio.py`). 변신 스크립트의 `SEQ_SE_PL_W100`은 현재 캐시 SDAT에 있는 공유 효과 `SEQ_SE_DP_W100`을 사용한다. 기존 WAV는 덮어쓰지 않는다.
