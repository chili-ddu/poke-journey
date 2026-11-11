# 성도 지도 연결 회귀 목록

## 돌진·근접·긴 준비 방향 고정 — 2026-11-11

| 경로 / 재발 방지 | 검증 |
| --- | --- |
| 기본 돌진 무적 제거·기존 점프/회피 분리·직선 스윕·벽/첫 상대 앞 정지·근접 시작 방향 고정·긴 준비 시작 고정/취소 없음 | test_combat_commit.gd |
| 돌진 경로/끝점·2D 투영·메뉴/연출 숨김·시각 발 오프셋·HUD 읽기 전용·기존 범위 충전 보존 | test_combat_commit_ui.gd; test_area_charge_ui.gd |
| L스틱 조준 유지·모바일 R스틱의 표시/자리/접촉 영역 유지·R축 조준 무효 | test_touch_controls.gd; test_physical_gamepad.gd; test_aim_assist.gd |
| FRLG/HGSS 실제 돌진 경로와 끝점·벽 정지·근접·솔라빔/로케트박치기 준비와 자동 발사·유한 화염방사 | tools/combat_commit_review.gd |

최종 관련 헤드리스 **24개 스크립트·279/279·6,310개 단언 통과**. 기존 `test_rules.gd`의 Float/Int 비교 경고 3건과 대화/BGM `3 Orphans` 진단은 남아 있다. 첫 통합에서 `test_kanto_contact_fx.gd`의 접촉 앞 2px 전진을 0으로 기대하던 검사 한 곳을 새 요구인 틈 접근·몸 비겹침·후속 드리프트 없음으로 정정한 뒤 통과했다. 최종 네이티브는 **전투 7사례·16장**, 입력은 **모바일 16개·물리 패드 이벤트 11개 묶음** 통과. 모두 384×216 고정 창·격리 저장을 사용했다. [전투 조작 검증](../docs/combat_commit/README.md). 아래의 예전 R스틱 직접 조준 검증은 당시의 기록이며 최신 조작은 이동 방향 조준과 R스틱 표시 유지·조준 무효화이다.

## 인트로 구도·몬스터볼 로딩 — 2026-11-11

| 경로 / 재발 방지 | 검증 |
| --- | --- |
| 자료 준비 전 시작 차단·입력 예약 없음·에코/해제 차단·실패 후 재시도·중복 진입 방지 | test_intro_screen.gd; tools/web/test_intro_screen.mjs |
| 세 스타팅의 실제 기술·NPC 상호 피해·일반 능력치·진행/저장과 분리 | test_intro_screen.gd; tools/intro_screen_review.gd |
| 인트로 종료 뒤 다운로드가 인트로를 다시 열지 않음·이전 소유자의 늦은 종료 차단·시작 입력과 로딩 분리 | tools/web/test_intro_screen.mjs; test_title_screen.gd |
| 게임 진입 로더는 별도 전투·지도·시작 버튼을 생성하지 않음·중앙 원근 카메라와 실제 도트 영역으로 화면 맞춤 | test_intro_screen.gd; tools/intro_screen_review.gd |
| 엔진 시작용 팩만으로 스타팅 도트·보간 자료·전투맵 사용 가능 | tools/web/check_startup_pack.gd --intro; tools/web/check_content_build.py |
| 선택 입력 누출 없음·새 게임/이어하기 모두 동일한 전환·384×216 고정 창 | tools/intro_screen_review.gd; tools/title_transition_review.gd |

현재 UI 관련 헤드리스 3개 스크립트 **26/26·261개 단언**, 웹 로더/인트로 **11/11** 통과. 처음에는 고정 14초 안에 NPC 상호 피해를 요구하던 항목이 실패했고, 특정 승패 대신 플레이어가 쓰러진 뒤 두 NPC가 실제로 싸우는 경로로 분리해 통과했다. 선택 화면 최초 BGM·SFX 초기화의 기존 `12 Orphans` 진단은 남아 있다. 네이티브 인트로·새 게임·이어하기는 격리 저장과 `CaptureWindow.park()`로 384×216에서 통과했다. 이번 변경 뒤 전체 Web 재내보내기·실물 모바일/패드 검증은 하지 않았다.

## 범위 기술 거리 충전 — 2026-11-11

| 경로 / 재발 방지 | 검증 |
| --- | --- |
| 적에게 거리 자동 맞춤 없이 방향만 보정·각도/벽/대상 제한·직접 조준 보존 | test_area_aim.gd; test_aim_assist.gd |
| 누르는 동안 거리 증가·최대 거리 무기한 유지·놓을 때 PP 한 번·최소 거리 빠른 탭·남은 준비 시간·고정 착지점 | test_area_charge.gd |
| 취소 비용 0·같은 홀드 재시작 차단·떼고 새로 누르기 허용·이동/점프·다른 기술 중첩과 일반 연사 보존 | test_area_charge.gd; test_controls.gd; test_touch_controls.gd; test_physical_gamepad.gd; test_mobile_gamepad.gd |
| 원형 가루·기존 면역/독 잠금·돌떨구기 1회·암석봉인 구분·회오리불꽃 고정 지점 초기 1회 및 기존 잔여 피해·공통 능력치 보존 | test_area_casting.gd; test_moves.gd; test_rules.gd |
| 실제 2D/3D 원 투영·충전 게이지·해제 후 가이드 제거 | test_area_charge_ui.gd |
| 기존 투사체 충돌/지연·사용 불가 피드백 | test_projectile_hitch.gd; test_projectile_clashes.gd; test_skill_denied_feedback.gd |
| 실제 사람 조작기 5기술의 짧은/최대 투척·실제 효과·PP·384×216 고정 창 | tools/area_charge_review.gd → docs/area_targeting/native.json |

최종 관련 헤드리스 14개 스크립트 **193/193·3,530개 단언 통과**. 기존 `test_rules.gd`의 Float/Int 비교 경고 3건은 남아 있다. 네이티브 최종 독립 재실행은 **5기술·실제 투척 10회·화면 20장·실패 0**이며 격리 저장과 `CaptureWindow.park()`를 사용했다. 앞선 확장 실행에서 회오리불꽃 최대 충전 가이드 소실이 1회 관찰됐고 같은 소스의 후속 두 실행에서는 재현되지 않았다. 해당 도구에 입력 문맥·충전 유효성 진단을 남겼으며 원인은 미확정이다. [조작·결과·한계](../docs/area_targeting/README.md).

## 대화 클릭·종료 입력 중복 방지 — 2026-11-11

- `test_dialogue_input.gd`: 좌클릭 한 쪽 진행·해제/우클릭/휠/키 반복 제외·등장 연출 잠금·해설/알림 수동 진행·마지막 Space의 점프 유출·같은 프레임 빠른 누름/해제·해제 후 새 점프/이동·콜백의 새 대화 중복 진행 방지.
- 관련 9개 스크립트 **165/165·5,284개 단언**. 기존 BGM 3 Orphans 진단 유지. 실제 루트 이벤트와 384×216 최소 창 검증 통과. [결과·한계](../docs/dialogue_input/README.md).

## 공격 방향 보정 — 2026-11-11

- `test_aim_assist.gd`: 발사 시 방향 보정, 입력별 각도 제한, 사거리·벽·아군/구경꾼/숨김/등장 제외, 카메라 변환, 대상 유지/해제, 작은 속도 예측, 충전/연사/고정 분산, 일반 피해와 PP, 중립 방향 누적 회전 방지, 이동·점프 보존과 문맥 정리.
- 최종 관련 7개 스크립트 **99/99·657개 단언**. 실제 네이티브 전후 비교는 384×216 고정 창·격리 저장으로 실행하며 도트·이펙트 자산을 바꾸지 않았다. [수치·검증·한계](../docs/aim_assist/README.md).

## 기기 언어 자동 선택 — 2026-11-11

- `test_language_settings.gd`: 최초 기기 언어 선택, 지역 코드, 미지원 언어의 영어 대체, 수동 선택 우선·유지, 이전 설정 호환, 자동값 비저장, 검증 환경변수 우선, 다른 환경 설정 보존. 테스트 설정 파일만 사용한다.
- 최종 `test_language_settings.gd`·`test_title_screen.gd`·`test_story_text.gd` **28/28 테스트·325개 단언 통과**. 기존 BGM·SFX 초기화의 `12 Orphans` 진단은 남아 있다. 실제 기기의 언어를 바꾸거나 모바일·웹에서 직접 실행한 검증은 하지 않았다.

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
