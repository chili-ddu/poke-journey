class_name FxStyle

# 기술 연출 모드(사용자 요청 2026-11-02: 우리 컨셉에 맞춘 커스텀 연출, 원작으로 쉽게 돌아갈 수 있게).
#   original  기존 플래티넘 기반 키 선택. SV 원본 재현 모드가 아니다.
#   custom    이 게임 컨셉에 맞춘 연출 — 탑뷰 실시간 액션이라 '어디까지 맞는지'(판정 범위·방향)가 보이고 맞는 순간이 또렷하게.
#             기존 플래티넘 마스크와 프로젝트 커스텀 자산을 사용한다.
# SV 외형 근거와 의도적 차이: docs/sv-fx-audit.md (FX 모드와 자료 출처는 별개).
# 커스텀은 MoveShapes.CUSTOM_FX 에 적힌 기술의 그림 키(fx·hit_fx)만 바꾼다 — 판정·위력·타이밍은 두 모드가 같다.
# 되돌리기:
#   전부 기존 키로    DEFAULT_MODE = "original"  (또는 실행할 때 환경 변수 FX=original — 비교용)
#   한 기술만 기존 키로 MoveShapes.CUSTOM_FX 에서 그 기술 줄을 지우거나 주석 처리
#   게임 안에서 바꾸기  FxStyle.set_mode("original" / "custom")
const DEFAULT_MODE := "custom"

static var mode := _initial()

static func _initial() -> String:
	var env := OS.get_environment("FX")
	return env if env in ["original", "custom"] else DEFAULT_MODE

# 이 기술을 지금 커스텀 연출로 그리나.
static func custom(move_id: String) -> bool:
	return mode == "custom" and MoveShapes.CUSTOM_FX.has(move_id)

static func set_mode(m: String) -> void:
	assert(m in ["original", "custom"], "모르는 연출 모드 " + m)
	mode = m
	MoveDB.clear_cache()          # 기술 사전은 합쳐서 캐시해 두므로 다시 합치게
