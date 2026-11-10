class_name UiFont
extends RefCounted

# 원작(플래티넘, 4세대) 글꼴. pret/pokeplatinum 의 font_message / font_system 을 tools/plat_font.py 로 BMFont 로 바꾼 것(assets/fonts/).
#   plat_message: 대사·기술 이름·능력치. 줄 높이 16px, 영문 대문자 9px·폭 6px.
#   plat_system : 체력 상자의 이름·Lv·HP 숫자 같은 HUD 글자(영문은 message 와 같은 꼴, 전각 글자만 좁다).
# DS 1px = 뷰포트 1px(PixelUi.UI_SCALE 1) 이므로 16 으로 그린다 — 비트맵이라 정수 배로만 늘어난다.
# 언어가 한국어(Lang.code "ko")면 두 자리 모두 갈무리11(assets/fonts/Galmuri11.ttf, OFL, 16px 비트맵 TTF) — 플래티넘 한국어판 글꼴은
# 디컴파일에 없어 가장 닮은 무료 글꼴로(사용자 결정 2026-10-27). 파일이 없으면 엔진 기본 글꼴로 대신한다(헤드리스 테스트에서 안전).

const BASE_PATH := "res://assets/fonts/plat_message.fnt"
const SMALL_PATH := "res://assets/fonts/plat_system.fnt"
const KO_PATH := "res://assets/fonts/Galmuri11.ttf"
const STRIKE := 16                                   # 원본 셀 높이
const BASE_SIZE := STRIKE * PixelUi.UI_SCALE
const SMALL_SIZE := STRIKE * PixelUi.UI_SCALE

static var _base: Font = null
static var _small: Font = null
static var _ko: Font = null

static func get_font() -> Font:
	if Lang.is_ko():
		return ko_font()
	if _base == null:
		_base = _load(BASE_PATH)
	return _base

static func small() -> Font:
	if Lang.is_ko():
		return ko_font()
	if _small == null:
		_small = _load(SMALL_PATH)
	return _small

static func ko_font() -> Font:
	if _ko == null:
		_ko = _load(KO_PATH)
	return _ko

# 언어를 바꾼 뒤 부른다(테마를 다시 만드는 쪽에서).
static func reset() -> void:
	pass

static func _load(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var f: FontFile = load(path)
	if f == null:
		return ThemeDB.fallback_font
	f.fixed_size = STRIKE
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	f.generate_mipmaps = false
	return f

# Control 노드(기술 잊기 창 등)에 씌우는 테마. 원작처럼 어두운 글자 + 원본 1px(화면 2px) 밝은 그림자.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = get_font()
	t.default_font_size = BASE_SIZE
	for cls in ["Label", "Button"]:
		t.set_color("font_color", cls, PixelUi.INK)
		t.set_color("font_shadow_color", cls, PixelUi.INK_SHADOW)
		t.set_constant("shadow_offset_x", cls, PixelUi.UI_SCALE)
		t.set_constant("shadow_offset_y", cls, PixelUi.UI_SCALE)
	t.set_color("font_hover_color", "Button", PixelUi.INK)
	t.set_color("font_pressed_color", "Button", PixelUi.INK)
	t.set_color("font_focus_color", "Button", PixelUi.INK)
	return t
