# 관동 신규 기술 파티클 추가분

2026-11-05의 `kanto_absorb_*.png`, `kanto_mega_drain_*.png`, `kanto_acid_*.png`, `kanto_supersonic_*.png`는 [pret/pokeplatinum의 원본 파티클](https://github.com/pret/pokeplatinum/tree/main/res/graphics/battle/particles)에서 `tools/kanto_move_fx.py`로 추출했다. 원작 자료의 권리자는 Nintendo / Game Freak / The Pokémon Company다. 프로젝트 기존 개인용 원본 리소스 사용 범위를 따른다.

| 파일 접두사 | 원본 SPA | 텍스처 번호 |
|---|---|---|
| kanto_absorb | absorb.spa | 0~3 |
| kanto_mega_drain | mega_drain.spa | 0~3 |
| kanto_acid | acid.spa | 0~1 |
| kanto_supersonic | supersonic.spa | 0 |

새 AI 생성 그림은 사용하지 않았다. 기본 모양은 추출본이며, 실시간 연출에서 색·크기·이동을 조정한다. `g4_glow`·`g4_streak` 등 기존 공통 원본 파티클도 함께 재사용한다.


2026-11-05 두 번째 추가분은 같은 원본 파티클 저장소에서 `tools/kanto_voice_fx.py`로 추출했다.

| 파일 접두사 | 원본 SPA | 텍스처 번호 |
|---|---|---|
| kanto_sing | sing.spa | 0~4 |
| kanto_hypnosis | hypnosis.spa | 0~3 |
| kanto_disarming_voice | hyper_voice.spa | 0~1 |

차밍보이스는 플래티넘에 없으므로 하이퍼보이스 텍스처를 빌려 분홍빛 실시간 연출로 재구성했다. 파일 접두사는 게임에서 쓰는 기술명이며 원본 애니메이션명을 뜻하지 않는다. 권리자와 개인용 리소스 사용 범위는 위와 같다.

2026-11-05 근접 기술 추가분도 같은 원본 파티클 저장소에서 `tools/kanto_contact_fx.py`로 추출했다. 권리자와 개인용 리소스 사용 범위는 위와 같다.

| 파일 접두사 | 원본 SPA | 텍스처 번호 |
|---|---|---|
| kanto_pound | pound.spa | 0~1 |
| kanto_peck | peck.spa | 0~1 |
| kanto_astonish | astonish.spa | 0~1 |

그림 모양은 추출본이며 색·크기·배치·타이밍을 실시간 접촉 연출에 맞춰 재구성했다. 새 AI 생성 이미지나 사지 이미지는 사용하지 않았다.

2026-11-05 김밥말이 추가분: `tools/kanto_wrap_fx.py`가 같은 저장소의 `wrap.spa` 텍스처 0을 `kanto_wrap_0.png`로 추출했다. `kanto_wrap_soft.png`는 해당 사분면 마스크를 기존 `plat_fx.mirror(..., 'quad')` 방식으로 대칭 복원한 것이다. 원본 마스크의 가운데 부분을 띠의 단면으로 쓰며 코드로 나선 배치를 만든다. 새로운 그림을 생성한 것은 아니다. 권리자와 개인용 리소스 사용 범위는 위와 같다.

2026-11-05 독침 형태 보정: `poison_needle.svg`는 가는 축과 좁은 끝을 코드로 구성한 프로젝트 커스텀 벡터 자산이다. 플래티넘/SV 추출본이나 최신작 원본 이미지가 아니다. 기존 `g4_needle`은 다른 참조를 위해 보존하고 독침의 비행·착탄 표시만 커스텀 자산으로 교체했다.

2026-11-05 SV 화면 조합 참고 보정: 노래하기·차밍보이스의 음표는 기존 플래티넘 `kanto_sing_1~3`, 파문은 기존 물의파동 추출 마스크 `g4_ring_q`를 재사용한다. 차밍보이스 착탄의 `kanto_disarming_voice_0`은 위에 적힌 하이퍼보이스 출처를 유지한다. SV에서 새 자산을 추출한 것은 아니며, 조합의 시각적 근거는 `docs/sv-fx-audit.md`에 별도 기록한다.

2026-11-05 최면술 주변 기운 보정: 푸른 고리는 기존 `g4_ring_q`(물의파동), 연보라색 초승달은 기존 `g4_vine_arc`(덩굴채찍)의 곡선 마스크를 재사용한다. 기존 `kanto_hypnosis_*` 추출 파일은 보존한다. 조합의 외형은 SV 게임 정지 화면을 참고했지만 자산·궤도·시간을 SV에서 추출한 것은 아니다. 출처 대조는 `docs/sv-fx-audit.md`에 기록했다.

2026-11-06 관동 야생: `world_{headbutt,lick,mud_slap,icy_wind,counter,mirror_coat}_*.png`는 pret/pokeplatinum의 같은 이름 `res/graphics/battle/particles/*.spa`에서 `tools/kanto_world_wild_fx.py`로 추출한 원본 마스크다. 색·크기·방향·지속시간을 실시간 기술에 맞춰 배치한다. 메타몽 변신은 원래 포켓몬 도트와 공통 틴트·빛 표시를 사용한다. 원본 권리자와 개인용 리소스 사용 범위는 위와 같다.

2026-11-08 파이리 기술 보정: `pixelfx/scratch.png`, `pixelfx/ember.png`는 patch-gg/pixelfx의 `impacts/hit-spark`, `pixelfx/smoke.png`는 `spawn/poof`를 색상·프레임 구간·크기를 조정해 렌더한 것이다. Copyright (c) 2026 Patch, Copyright (c) 2026 Hugo Duprez, MIT. 원본은 Sprite Fusion의 MIT impact/explosion 코드를 일부 활용한다. 전체 라이선스는 `pixelfx/LICENSE.txt`, 고정 원본 리비전과 옵션은 `pixelfx/manifest.json`, 재생성 도구는 `tools/export_pixelfx.mjs`에 보존한다. 갤러리 글꼴과 캐릭터는 포함하지 않는다.

2026-11-08 불꽃세례 기준 이펙트: `pixelfx/flame.png`는 patch-gg/pixelfx `fire/spirit-flame`의 따뜻한 팔레트 변형을 24×40, 90프레임으로 잘라 내보낸 것이다. 발사·비행·몸통 앞뒤 착탄·바닥 잔불이 같은 애니메이션을 공유한다. 원본·옵션·자르기 영역은 `pixelfx/manifest.json`, MIT 고지는 같은 폴더의 `LICENSE.txt`에 포함한다. 캐릭터 도트와 갤러리 글꼴은 포함하지 않는다.

2026-11-08 도구 입수 반짝임: `pixelfx/pickup.png`는 patch-gg/pixelfx의 `pickups/collect-burst`에서 큰 섬광·링이 끝난 16~31프레임을 48×48로 잘라 차분한 크림색 팔레트로 내보낸 것이다. Copyright (c) 2026 Patch, Copyright (c) 2026 Hugo Duprez, MIT. 옵션·리비전·자르기 영역은 `pixelfx/manifest.json`, 전체 MIT 고지는 `pixelfx/LICENSE.txt`, 재생성은 `tools/export_pixelfx.mjs`를 따른다.
