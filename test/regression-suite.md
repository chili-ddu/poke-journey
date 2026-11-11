# 성도 지도 연결 회귀 목록

## Web 다운로드 분리 회귀 — 2026-11-11

| 경로 / 재발 방지 | 검증 |
| --- | --- |
| 시작 화면에서 엔진·시작 자료만 요청, 게임 진입 전 맵→포켓몬 준비, 중복 요청 방지 | tools/web/test_content_loader.mjs |
| 다른 종족 저장의 진화 계열, 404 후 재시도, 손상된 캐시·응답, 캐시 사용 불가 | tools/web/test_content_loader.mjs |
| 선택 화면의 조작·장면 전환과 키보드·가상 패드·물리 패드 입력 보존 | test_title_screen.gd; test_touch_controls.gd; test_physical_gamepad.gd |
| 선택 다운로드 없이 현재 등장 종족의 원본·부드러운 움직임 자료 완비 | tools/web/check_startup_pack.gd |
| 전체 493종·원시 맵/GLB/텍스처 참조·압축 무결성·초기 용량 검사 | tools/web/check_content_build.py; tools/check_export_pack.gd |

검증 창은 384×216, 브라우저 저장은 전용 이름으로 격리한다. 빌드별 실제 용량은 Web 결과의 `download-sizes.json`에 기록한다.

## 모바일 컨트롤러 배치 회귀 — 2026-11-11

기존 목록을 보존한다. 이번 변경의 기록은 [모바일 패드](../docs/touch_controls/controller_layout/README.md)를 따른다.

| 경로 / 재발 방지 | 검증 |
| --- | --- |
| 터치와 키보드의 독립적인 기술·도구 누름, 빠른 탭·사용 불가·OS 취소, 양쪽 스틱·버튼 접촉 영역 분리 | test_mobile_gamepad.gd |
| A 행동/B 취소·X/Y/LB/RB 기술 배정, L스틱 첫 프레임 발사·R스틱 보조 조준/해제 후 L 복귀·카메라 방향, RT+방향패드 도구 등록·드래그 취소 | test_touch_controls.gd |
| SELECT 타운맵 보기·미방문 지역 열람·이동/진행 보존·원래 공중날기 조건, HM 상호작용·물가 행동 메뉴 | test_fly_map.gd; test_field_hms.gd |
| 물리 L스틱 첫 프레임 발사·R 보조 조준/해제 후 L 복귀, 버튼·축·트리거 중립/해제, 키보드·터치 독립, 실제 PP·점프·도구, 메뉴 반복, 포커스·연결·로딩/장면 해제 입력과 동시 기기 분리 | test_physical_gamepad.gd |
| 원래 HUD·게임 메뉴 유지와 실제 A/B 확인·닫기 | test_touch_field_actions.gd |
| 논리 뷰포트·원래 장면 전환·휴대폰 비율 | test_mobile_screen.gd; tools/mobile_screen_review.gd |
| 실제 제목 화면·결과 재시작·A 대화·어깨 기술·SELECT 타운맵, 물리 루트 이벤트·가방 등록·모바일 내부 뷰포트, 세로/가로 및 PC 배치 | tools/physical_gamepad_review.gd; tools/mobile_screen_review.gd; tools/touch_ui_restore_review.gd |

최종 관련 회귀는 10개 스크립트 108/108·5,820개 단언이다. 이전 키 배정의 전체 회귀 스냅샷 919개 중 910개 통과·기존 실패 9개를 [현재 기록](../docs/touch_controls/active_gamepad/validation.json)의 새 결과와 구분했다. 실물 패드·휴대폰 검증을 뜻하지 않는다. 네이티브 창은 384×216을 유지하고 전용 저장을 사용한다.

## 이야기 이벤트 회귀 추가 — 2026-11-10

기존 목록을 보존하고 신규 이야기 검증을 추가한다. [실행별 결과와 한계](../docs/event_implementation_review/README.md).

| 경로 / 재발 방지 | 검증 |
| --- | --- |
| 단계 저장·대화 후 완료·열매 비용·보상 중복·패배 재개 | test_quest_runtime.gd |
| 실내 이야기 경험치 표시·장면 전환 전 기술 저장 | test_quest_runtime.gd: test_story_growth_saves_every_crossed_level_move_without_changing_slots; test_indoor_story_xp_display_converges_to_real_growth_without_slot_changes |
| 단서 전 아지트 노출·작은 수첩 카드 잘림 | test_quest_runtime.gd: test_journal_does_not_reveal_hideout_until_evidence_or_acceptance; test_journal_cards_keep_readable_titles_and_short_state_with_full_details |
| 상록숲 양쪽 성충·협상·후손·박물관·알·이브이 정착·메타몽 | test_regional_quests.gd |
| 이수재 기존 포획 전투 제거 | test_bill_event.gd |
| 단서 24순서·세대·일곱 승리·부모 마지막 출전·교배기·저장 분리 | test_campaign_director.gd |
| 실제 양쪽 엔딩·세대 장면 재생성·아버지·뮤츠 저장 | tools/campaign_flow_check.gd — 31개 확인, 실패 0 |
| 기존 스라크·피죤·타워의 노랑 방문 조건과 보상 재개 | test_forest_rescue.gd; test_bird_event.gd; test_tower_brothers.gd |
| 이슬·마티스 승리 및 과거 승리 기록의 라프라스·피카츄 지원 | test_gym_field_friends.gd; test_field_hms.gd; test_lapras_escape.gd |
| 도로·레벨·트레이너·관장·날기 기존 동작 | test_road_gates.gd; test_level_progression.gd; test_story_trainers.gd; test_gym_conversations.gd; test_fly_map.gd; test_gym_growth.gd |

관련 178개 테스트의 최신 결과는 통과다. 마지막 통합 177개 실행의 오래된 기대 1개 실패와 수정 후 27개 재검증을 구분해 위 기록에 남겼다. 실제 사용자 저장을 사용하지 않았으며 화면 검증은 384×216을 유지했다.

## 기존 성도 검증 기록

2026-11-10. 이번 기능의 회귀 목록이며 프로젝트 전체 테스트 커버리지 평가를 뜻하지 않는다. 설계·현재 범위는 docs/johto_gameplay/README.md를 따른다.

| 경로 / 재발 방지 | 검증 |
|---|---|
| 모든 성도 장소 등록·현재 Game 저장 가능 지도·원본 시작점 | test_johto_gameplay.gd: test_all_301_maps_are_registered_with_original_geometry_and_clear_start |
| 원본 문·계단 앵커·공유 입구·외부 동적 목적지 | test_johto_gameplay.gd: test_game_warps_keep_all_original_anchors_and_canonical_shared_entrances |
| 벽·물·언덕·큰 이동의 충돌 | test_johto_gameplay.gd: test_native_water_wall_and_ledge_permissions_feed_normal_world_collision; test_hgss_maps.gd |
| 성도 문 잠금 오류·이동 중 HP 초기화 | test_johto_gameplay.gd: test_normal_game_uses_native_map_and_preserves_mon_between_real_door_requests |
| 실제 World 보행이 연구소 문 앞에서 막히지 않음 | test_johto_gameplay.gd: test_normal_world_walks_two_clear_tiles_into_elms_lab_door |
| 원본 언덕 bit 15가 hop까지 막던 오류 | test_johto_gameplay.gd: test_native_directional_ledges_allow_the_existing_hop_but_never_ordinary_walking |
| 선원 접근·승선 취소·공중날기 방문 제한 | test_johto_gameplay.gd: test_ferry_endpoints_are_clear_cancellation_is_reversible_and_flight_stays_visit_only; test_fly_map.gd |
| 관동 저장 좌표 이전·관동 출입구 계약·시작 화면·트레이너 | test_kanto_world.gd; test_kanto_expansion.gd; test_title_screen.gd; test_story_trainers.gd |
| HGSS 환경 교체·캐릭터 및 효과 렌더·구역별 그래픽·체육관 대화 | test_hgss_environment.gd; test_view3d.gd; test_visual_style_rules.gd; test_gym_conversations.gd |
| 실제 연락선 왕복·보행 출입·저장 복원 | tools/johto_gameplay_review.gd → docs/johto_gameplay/checks.json |
| 실제 자동 언덕 점프·발 위치·가림 상태 가독성 | tools/johto_ledge_review.gd → docs/johto_gameplay/ledge_checks.json |

최종 헤드리스 11개 스크립트 137/137·209,349개 단언 통과. 기존 전역 SFX/BGM 12 Orphans 경고는 남아 있다. 네이티브 검사는 384×216 창과 격리 저장을 사용한다. 미검증: 전체 301곳의 수동 경로, 동적 이벤트·퍼즐 동작, 성도 전투 콘텐츠, 성능 예산, 내보내기.

## 관동·성도 경계 확장

- test/test_johto_border.gd: 원본 301개 불변·311개 합성, 기존 관문 출입구/저장 일회성 이전, FRLG 22·23번도로 및 26·28번도로 연결, 파도타기 전용 폭포 통과, 개체·성장·가방 유지, 재질 격리, 동굴 출입구 안쪽 도착.
- tools/check_johto_border.py: 원본 타일 경로 7쌍(14개) 정적 연결.
- tools/johto_border_review.gd: 실제 World 보행·기존 Surf 입수·언덕 점프, 문 암전과 장면 재생성, 접수 게이트 4분기, 은빛산 왕복, HP·가방·저장 복원, 실제 스트리밍 재질 확인.
- 최종 12개 스크립트 144/144·211,529개 단언. 기존 BGM 3/SFX 9 Orphans 경고 기록. 네이티브는 384×216, 격리 저장, 장면 전환 12회·1,152타일 보행. 동성폭포 앞벽의 뒷면과 동굴 출입구에 야외용 한 칸 전진이 적용되던 문제를 화면 검증으로 발견해 보완했다.
