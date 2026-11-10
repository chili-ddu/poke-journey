class_name PixelUi
extends RefCounted

# 플래티넘(4세대) 전투 화면 UI 를 그리는 공통 도구 — 원본 그림(assets/ui/plat/) 9분할·블릿, 원작 글꼴 글자(1px 그림자 / 풀밭 위 외곽선), 게이지.
# 모든 좌표는 정수로 맞춘다(DS 1px = 뷰포트 1px, 창은 정수 배라 반 픽셀이 생기면 번진다).

const PAPER := Color("f8f8f8")
const PAPER_HOVER := Color("fff4dc")
const INK := Color("4a4a4a")           # 밝은 판(이름 판·PP 판·기술 잊기 창) 위 글자
const INK_SHADOW := Color("d6d6d6")    # 그 그림자(연회색)
const INK_DIM := Color("9090a0")
const FRAME_OUT := Color("303038")
const TRACK := Color("505860")
const CURSOR_RED := Color("f85858")
const FIELD_OUTLINE := Color("283028")

const UI_SCALE := 1                     # DS 1px = 뷰포트 1px
# 플래티넘 전투 화면 색(healthbox/parts·글상자 팔레트에서)
const PLAT_TEXT := Color("ffffff")      # 어두운 판 위 글자(헬스박스·글상자)
const PLAT_SHADOW := Color("4a4a52")
const PLAT_HP := [Color("18c520"), Color("eeac00"), Color("ff4110")]   # 초록·노랑·빨강
const PLAT_EXP := Color("4194e6")
const PLAT_EXP_DARK := Color("1862bd")
const PLAT_OLIVE := Color("6a735a")     # 헬스박스 몸통
const PLAT_OLIVE_DARK := Color("293129")
const PLAT_LIGHT := Color("dedede")

static var _tex := {}

static func ui_tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := "res://assets/ui/%s.png" % name
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]

# 9분할. 원본 그림의 가장자리 margin(px)을 모서리로 쓰고 가운데를 늘린다. 모든 조각은 UI_SCALE 배.
static func nine(ci: CanvasItem, name: String, rect: Rect2, margin: int = 8, modulate: Color = Color.WHITE) -> bool:
	var tex := ui_tex(name)
	if tex == null:
		return false
	var r := snap_rect(rect)
	var tw := tex.get_width()
	var th := tex.get_height()
	var m := margin
	var ms := float(m * UI_SCALE)
	var xs := [0.0, ms, r.size.x - ms, r.size.x]
	var ys := [0.0, ms, r.size.y - ms, r.size.y]
	var sx := [0, m, tw - m, tw]
	var sy := [0, m, th - m, th]
	for j in 3:
		for i in 3:
			var dst := Rect2(r.position + Vector2(xs[i], ys[j]), Vector2(xs[i + 1] - xs[i], ys[j + 1] - ys[j]))
			var src := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			if dst.size.x > 0.0 and dst.size.y > 0.0:
				ci.draw_texture_rect_region(tex, dst, src, modulate)
	return true

# 그림을 주어진 네모에(크기 그대로 또는 늘려서) 그린다. size 가 음수면 뒤집힌다. 그렸으면 참.
static func blit_rect(ci: CanvasItem, name: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	var tex := ui_tex(name)
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false, modulate)
	return true

static func snap(v: Vector2) -> Vector2:
	return Vector2(floorf(v.x), floorf(v.y))

static func snap_rect(r: Rect2) -> Rect2:
	return Rect2(snap(r.position), snap(r.size))

# 글자. pos 는 줄 상자의 왼쪽 위. 그린 너비를 돌려준다.
static func text(ci: CanvasItem, pos: Vector2, s: String, small: bool = false, color: Color = INK,
		shadow: Color = INK_SHADOW, align: int = HORIZONTAL_ALIGNMENT_LEFT, scale: int = 1) -> float:
	var f := UiFont.small() if small else UiFont.get_font()
	var size := (UiFont.SMALL_SIZE if small else UiFont.BASE_SIZE) * scale
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := snap(pos)
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= floorf(w / 2.0)
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	p.y += f.get_ascent(size)
	if shadow.a > 0.0:
		ci.draw_string(f, p + Vector2(UI_SCALE, UI_SCALE) * scale, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return w

# 풀밭 위에 바로 놓는 글자. 그림자 대신 어두운 외곽선.
static func field_text(ci: CanvasItem, pos: Vector2, s: String, small: bool = false, color: Color = Color.WHITE,
		outline: Color = FIELD_OUTLINE, align: int = HORIZONTAL_ALIGNMENT_LEFT, scale: int = 1) -> float:
	var f := UiFont.small() if small else UiFont.get_font()
	var size := (UiFont.SMALL_SIZE if small else UiFont.BASE_SIZE) * scale
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := snap(pos)
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= floorf(w / 2.0)
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	p.y += f.get_ascent(size)
	ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI_SCALE * scale, outline)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return w

# 여러 줄 글. 너비를 넘으면 낱말 단위로 줄을 바꾸고 max_lines 까지만 그린다. pos 는 첫 줄 상자의 왼쪽 위.
static func paragraph(ci: CanvasItem, pos: Vector2, s: String, width: float, max_lines: int = 2,
		color: Color = INK, shadow: Color = INK_SHADOW, scale: int = 1) -> void:
	var f := UiFont.get_font()
	var size := UiFont.BASE_SIZE * scale
	var p := snap(pos) + Vector2(0, f.get_ascent(size))
	var brk := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	if shadow.a > 0.0:
		ci.draw_multiline_string(f, p + Vector2(UI_SCALE, UI_SCALE) * scale, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, shadow, brk)
	ci.draw_multiline_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, color, brk)

# 폭 width 안에 줄바꿈하면 몇 줄인가(paragraph 와 같은 끊기).
static func line_count(s: String, width: float, scale: int = 1) -> int:
	var para := TextParagraph.new()
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.width = width
	para.add_string(s, UiFont.get_font(), UiFont.BASE_SIZE * scale)
	return para.get_line_count()

# Use the renderer's own wrapping ranges; each page fits the fixed dialogue box.
static func dialogue_pages(s: String, width: float, lines_per_page: int = 2) -> Array[String]:
	if line_count(s, width) <= lines_per_page:
		return [s]
	var para := TextParagraph.new()
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.width = width
	para.add_string(s, UiFont.get_font(), UiFont.BASE_SIZE)
	var pages: Array[String] = []
	var lines: Array[String] = []
	for i in para.get_line_count():
		var span := para.get_line_range(i)
		lines.append(s.substr(span.x, span.y - span.x).strip_edges())
		if lines.size() == lines_per_page:
			pages.append("\n".join(lines))
			lines.clear()
	if not lines.is_empty(): pages.append("\n".join(lines))
	return pages

static func text_width(s: String, small: bool = false, scale: int = 1) -> float:
	var f := UiFont.small() if small else UiFont.get_font()
	var size := (UiFont.SMALL_SIZE if small else UiFont.BASE_SIZE) * scale
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# 게이지. 어두운 홈 + 채움 + 밝은 윗줄. 0 이 아니면 최소 1px 은 남긴다.
static func gauge(ci: CanvasItem, rect: Rect2, ratio: float, fill: Color) -> void:
	var r := snap_rect(rect)
	ci.draw_rect(r.grow(1), FRAME_OUT)
	ci.draw_rect(r, TRACK)
	var w := int(floor(r.size.x * clampf(ratio, 0.0, 1.0)))
	if ratio > 0.0 and w == 0:
		w = 1
	if w > 0:
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), fill)
		ci.draw_rect(Rect2(r.position, Vector2(w, 1)), fill.lightened(0.5))
