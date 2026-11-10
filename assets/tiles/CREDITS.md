# 타일 출처

`frlg_general.png` — 포켓몬스터 파이어레드·리프그린의 기본 타일셋(general)을 16×16 메타타일 640개로 펼친 것. 가로 16칸, 세로 40줄이고 메타타일 번호 n 은 (n % 16, n / 16) 칸에 있다.

- 원본 데이터: [pret/pokefirered](https://github.com/pret/pokefirered) 디컴파일 저장소의 `data/tilesets/primary/general/` (`tiles.png`, `metatiles.bin`, `palettes/00~06.pal`). 2026-10-26 에 받아 파이썬으로 팔레트를 입혀 합쳤다.
- 저작권은 닌텐도·게임프리크·크리처스에 있다. 개인 용도로만 쓰고 배포하지 않는다.
- 이 게임이 쓰는 번호: 0x001 깎은 잔디(바닥), 0x008·0x009 잔디 무늬, 0x00D 풀숲(출현 지점, 원작의 야생 포켓몬 풀), 0x014·0x015 / 0x024·0x025 넓은 나무(위·아래), 0x012 나무 벽(둘레 바깥).

## 지도 (assets/maps/)

`kanto_world/`, `world_*/` 및 `assets/data/kanto_world_manifest.json`에 등록한 관동 본토의 신규 실내·동굴·사파리존 맵 — pret/pokefirered의 원작 `data/maps/*/map.json`, `data/layouts/*/{map.bin,border.bin}` 및 타일셋·팔레트를 `tools/kanto_world.py`와 기존 FRLG/HD-2D 변환기로 구성했다(2026-11-06). 타일셋의 그림·팔레트 공유 관계는 원본 `src/data/tilesets/{headers,graphics}.h`와 `src/graphics.c`를 따른다. 기존에 점검한 지역의 HD-2D 사물은 재사용하며, 전체 맵의 위치·고도·나무 아래 지면을 다시 합성했다. 원본 저작권은 Nintendo / Game Freak / Creatures에 있다.

`saffron_city/`, `saffron_city_pokemon_center_1f/`, `saffron_city_mart/` — pret/pokefirered의 SaffronCity, SaffronCity_PokemonCenter_1F, SaffronCity_Mart 원작 레이아웃·타일·팔레트. `tools/saffron_access.py`로 생성하고 기존 공통 센터·숍 HD-2D 사물 변환을 적용한다. 원본 저작권은 Nintendo / Game Freak / Creatures에 있다.

`arena_bird_nest/` — 주변 수관은 위 상록숲 원본 도트를 `tools/hd2d_cards.py::_tree_template("viridian_forest")`로 분리해 같은 픽셀 그대로 재사용한다. 둥지·짚·깃털·수피 픽셀과 입체 장식 배치는 `tools/bird_nest_map.py`, `tools/nest_pixel_art.py`로 만든 자체 절차적 아트다. FRLG 원본 수관의 저작권은 Nintendo / Game Freak / Creatures에 있다.

`viridian_forest/` — 파이어레드·리프그린 상록숲 지도(54×69칸)를 그대로 구운 것. `bottom.png` 는 포켓몬 아래에 깔리는 층, `top.png` 는 포켓몬 위에 덮이는 층(나무 윗부분), `map.json` 은 칸별 통행 불가(solid)·풀숲(grass) 격자와 시작 좌표.
원본: pret/pokefirered 의 `data/layouts/ViridianForest/map.bin` + 기본 타일셋 + `data/tilesets/secondary/viridian_forest/`. 저작권은 닌텐도·게임프리크·크리처스에 있다.

## 기술 효과 (assets/fx/)

`small_ember.png` — 파이어레드·리프그린 전투 애니메이션의 불꽃세례 불씨(ANIM_TAG_SMALL_EMBER, 32×32 5프레임: 작은 불씨 → 커지는 불꽃). pret/pokefirered `graphics/battle_anims/sprites/small_ember.png` 를 PNG 자체 팔레트로 색 입힘. 저작권은 닌텐도·게임프리크·크리처스.
`oran_berry_small.png` — 파이어레드·리프그린 도구 아이콘 오랭열매(24×24)를 12×12 로 줄인 것(원본 크기 파일은 삭제). pret/pokefirered `graphics/items/icons/oran_berry.png` + `icon_palettes/oran_berry.pal`.
`tall_grass.png` — 파이어레드·리프그린 필드 효과 '풀숲 흔들림'(16×16 5프레임: 밑동, 풀 전체, 벌어짐 3단계). pret/pokefirered `graphics/field_effects/pics/tall_grass.png` + `palettes/general_1.pal`.

`maps/pallet_town/` — 파이어레드·리프그린 태초마을(LAYOUT_PALLET_TOWN 24×20, gTileset_General + gTileset_PalletTown)을 `tools/frlg_map.py` 로 구운 것(bottom/top/map.json). 출처 pret/pokefirered `data/layouts/PalletTown/map.bin`, `data/tilesets/{primary/general,secondary/pallet_town}`. 자료는 `third_party/pokefirered/`.

## UI 조각 (assets/ui/plat/)

플래티넘 전투 화면 원본 그림. `python3 -I tools/plat_ui.py` 가 third_party/pokeplatinum 에서 뽑는다(Nintendo / Game Freak 저작물 — personal use 로만).
- `healthbox_player.png`·`healthbox_enemy.png`·`hb_parts.png`: `res/graphics/battle/healthbox/{player_singles,enemy,healthbox_parts}.png`(팔레트 PNG → RGBA).
- `sys_window.png`: `res/graphics/windows/standard_system.png`(24×24 셀, 투명 여백을 걷고 가운데를 늘려 다시 24×24) — 레벨업 능력치 창·기술 잊기 창·결과 창. `cursor.png`: `res/graphics/battle/interface/cursor.png`(왼쪽 위 꺾쇠)를 네 모서리로 뒤집어 34×34 에 모음.
- `msgbox.png`: `res/graphics/windows/message_box_00.png`(기본 대화창 틀: 흰 테·어두운 선·갈색 띠)의 왼쪽 10px 을 거울로 써 대칭 24×24 로 조립(9분할 여백 10). `fight_button.png`·`fight_frame.png`·`name_plate.png`·`pp_plate.png`·`fight_cancel.png`: 같은 NARC 027(타일 026, 팔레트 221) 아래 화면 '싸운다' 메뉴의 버튼 한 개(128×80, 자리표시 글자 지움)와 그 조각. 디코더는 `tools/nitro_dump.py`(NARC·LZ10·NCLR·NCGR·NSCR).
- `types/*.png`: `res/graphics/battle/type_icons/*.png`(32×16).
- `evo_bg.png`(진화 화면 배경, 256×192): `res/graphics/egg_hatch/background.png` + `background.NSCR`(원작 진화 장면이 쓰는 알 부화 배경). 같이 `assets/fx/evo_*.png`: `res/prebuilt/demo/shinka/data/particle/shinka_demo_particle.narc` 의 SPA 텍스처. `tools/plat_evolution.py`.
(예전 FRLG 조각 battle_textbox·move_windows·healthbox_*·hp_bar·frame 은 삭제.)

## 글꼴 (assets/fonts/)
- `plat_message.*`, `plat_system.*`: pret/pokeplatinum `res/fonts/font_message.png`·`font_system.png`(+ 폭 .json, `tools/msgenc/charmap.txt`)를 `tools/plat_font.py` 로 변환. 원작 글꼴은 Nintendo / Game Freak 저작물 — personal use 로만. (예전 frlg_* 글꼴은 삭제.)
- `fx/fang_upper.png`, `fx/fang_lower.png`, `fx/fire_fang_puff.png`, `fx/fire_fang_flame.png`: pret/pokeplatinum `res/graphics/battle/particles/fire_fang.spa`(Nitro 파티클) 안의 텍스처(A3I5/A5I3)를 `tools/plat_fx.py` 로 꺼낸 것. 움직임은 게임이 직접.
- `fx/stat_up_def.png`, `fx/stat_down_spe.png`: pret `graphics/battle_anims/masks/stat.png` 의 상승(0~3열)·하강(4~7열) 32×32 무늬에 `stat1.pal`(DEFENSE 초록)·`stat4.pal`(SPEED 파랑)을 입힌 것.
- `fx/stat_up_atk.png`, `fx/stat_down_atk.png`: stat.png 무늬 + stat2.pal. (예전 claw_slash·noise_line·fire_plume·scary_face·small_ember 는 플래티넘 자산으로 바꾸며 삭제.)
- `fx/g4_*.png`: pret/pokeplatinum `res/graphics/battle/particles/{scratch,growl,ember,smoke_screen,dragon_rage,slash,fire_spin,harden,poison_sting,thunder_shock,horn_attack,fury_attack}.spa` 안의 텍스처(흰 마스크; 반쪽·사분면은 거울로 완성)를 `tools/plat_fx.py` 로 꺼낸 것. `fx/g4_claw_strike.png`: `res/graphics/battle/moves/claw.png` + `claw.pal`(5프레임). `fx/g4_scary_face.png`: `moves/scary_face.png` 의 눈·이빨 조각을 거울로 얼굴 4프레임으로 조립. `fx/g4_thread.png`: `moves/string_shot.png`(실 가닥 여덟 줄) 그대로. (예전 horn_hit.png 삭제.) 전부 Nintendo / Game Freak — personal use.

## 플래티넘 데이터·자산 (third_party/pokeplatinum/, assets/data/)
- pret/pokeplatinum 디컴파일의 `res/pokemon/*/data.json`, `res/moves/*/data.json`, `res/items/data/tm*.json`, `res/pokemon/.shared/exp_tables.csv`, `generated/species.txt` 를 `tools/plat_fetch.py` 로 받아 `tools/gen_gen4.py` 가 `assets/data/*.json` 으로 변환. 글꼴(`tools/plat_font.py`)·전투 UI(`tools/plat_ui.py`)도 같은 곳에서. 전부 Nintendo / Game Freak 저작물 — personal use 로만.

## 글꼴·이름 (한국어)
- `fonts/Galmuri11.ttf`: 갈무리11 비트맵 TTF(quiple/galmuri v2.40.4, SIL Open Font License 1.1 — `fonts/Galmuri-LICENSE.txt`). 한국어 모드의 모든 글자.
- `data/names_ko.json`: PokeAPI (github PokeAPI/pokeapi `data/v2/csv/`, BSD-3) 의 한국어 이름 CSV 를 `tools/ko_names.py` 로 pret id 에 맞춘 것. 원본 CSV 는 `third_party/pokeapi/`.

- `cerulean_north`: pret/pokefirered Route24·Route25 원작 배치·타일·팔레트. `tools/cerulean_progression.py --maps`로 생성. `arena_cerulean_gym`: CeruleanCity_Gym 타일 기반 공통 전투 필드, `tools/frlg_arena.py`로 생성. 이슬 컷인 얼굴은 파이어레드 leader_misty 원본, 물색 배너는 pret/pokeplatinum leader_wake 원본을 `tools/plat_encounter.py`로 변환.

- 이수재의 집 `route25_sea_cottage`: pret/pokefirered `Route25_SeaCottage` 원작 배치·타일·팔레트. `tools/bill_cottage.py`로 생성하고 `tools/bill_cottage_objects.py`에서 원본 전송 장치·PC·수납장·화분 픽셀을 입체 화면용으로 분리한다. 이벤트는 원작 집의 scripts.inc·text.inc를 참고해 새 대사로 각색.
