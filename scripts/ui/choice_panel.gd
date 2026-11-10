class_name ChoicePanel
extends Control

# "어느 기술을 잊게 할까?" 창. 기술 4칸이 찬 채로 새 기술을 배울 때 뜬다.
# 마우스 클릭 또는 숫자 키(1~5)로 고른다. 고르면 chosen(index) 을 보낸다 — 0~3 은 그 칸, 4 는 포기. 글·글꼴은 Lang(영어: 플래티넘 글꼴, 한국어: 갈무리11).

signal chosen(index: int)

var _buttons: Array = []
var _box: VBoxContainer
var _close_index := -1          # Esc 로 고를 칸(가방·상점의 "닫기"). -1 이면 Esc 무시

func _ready() -> void:
	# 크기는 Game._fit_ui 가 준다(UI 레이어 배율 때문에 앵커로 못 잡는다).
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	_close_index = -1

func _frame(title: String, subtitle: String, columns: int = 3) -> GridContainer:
	_clear()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4 * PixelUi.UI_SCALE)
	center.add_child(_box)
	# 제목은 원작 대화창처럼 종이 상자 안에.
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _paper_style(PixelUi.PAPER, PixelUi.FRAME_OUT, 4 * PixelUi.UI_SCALE))
	_box.add_child(head)
	var head_box := VBoxContainer.new()
	head_box.add_theme_constant_override("separation", PixelUi.UI_SCALE)
	head.add_child(head_box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_box.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_override("font", UiFont.small())
		s.add_theme_font_size_override("font_size", UiFont.SMALL_SIZE)
		head_box.add_child(s)
	# 카드는 한 줄에 3장(원작 글꼴이 커서 5장을 한 줄에 못 놓는다).
	var row := GridContainer.new()
	row.columns = columns
	row.add_theme_constant_override("h_separation", 4 * PixelUi.UI_SCALE)
	row.add_theme_constant_override("v_separation", 4 * PixelUi.UI_SCALE)
	var center_row := CenterContainer.new()
	center_row.add_child(row)
	_box.add_child(center_row)
	visible = true
	return row

func show_forget(mon_name: String, new_move: String, slots: Array) -> void:
	var nm := MoveDB.get_move(new_move)
	# 제목은 한 줄(원작 글꼴 32px 줄이라 두 줄이면 카드 두 단과 함께 360px 를 넘는다).
	var row := _frame(Lang.t("forget_title", [mon_name, MoveDB.move_name(new_move)]), "")
	# 카드 한 장: 번호 / 이름 / 타입·분류 — 32px 줄 셋.
	for i in slots.size():
		var m := MoveDB.get_move(slots[i])
		row.add_child(_card(i, [Lang.t("forget"), MoveDB.move_name(slots[i]), _move_meta(slots[i]), ""],
			TypeChart.type_color(m["type"]), Vector2(100, 54) * PixelUi.UI_SCALE))
	row.add_child(_card(slots.size(), [Lang.t("give_up"), Lang.t("dont_learn"), Lang.t("keep_four"), ""],
		PixelUi.INK_DIM, Vector2(100, 54) * PixelUi.UI_SCALE))
	var hint_box := PanelContainer.new()
	hint_box.add_theme_stylebox_override("panel", _paper_style(PixelUi.PAPER, PixelUi.FRAME_OUT, 2 * PixelUi.UI_SCALE))
	var hint := Label.new()
	hint.text = Lang.t("new_move", [MoveDB.move_name(new_move), _move_meta(new_move), _move_power(new_move)])
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", UiFont.SMALL_SIZE)
	hint.add_theme_font_override("font", UiFont.small())
	hint_box.add_child(hint)
	_box.add_child(hint_box)

# 도구 카드 격자(가방·상점). entries: [{name, sub, icon: Texture2D|null, accent: Color, enabled: bool}].
# 카드 위 줄 "번호. sub"(작게), 아래 줄 이름, 오른쪽에 아이콘. 꺼진 카드는 흐리고 눌리지 않는다. close_index 는 Esc 로 고를 칸.
func show_items(title: String, entries: Array, columns: int = 4, close_index: int = -1) -> void:
	var row := _frame(title, "", columns)
	for i in entries.size():
		var e: Dictionary = entries[i]
		var card := _card(i, [String(e.get("sub", "")), String(e.get("name", "")), "", ""], e.get("accent", Color("78b878")), Vector2(118, 40) * PixelUi.UI_SCALE)
		var tex: Texture2D = e.get("icon")
		if tex != null:
			var ic := TextureRect.new()
			ic.texture = tex
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			ic.offset_left = -32 * PixelUi.UI_SCALE
			ic.offset_right = 0
			ic.offset_top = -16 * PixelUi.UI_SCALE
			ic.offset_bottom = 16 * PixelUi.UI_SCALE
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(ic)
		if not e.get("enabled", true):
			# 못 고르는 카드: 같은 종이 상자(불투명)를 어둡게 — 반투명이면 뒤 지도가 비쳐 지저분했다.
			card.disabled = true
			card.add_theme_stylebox_override("disabled", _paper_style(PixelUi.PAPER, PixelUi.FRAME_OUT, 0))
			card.modulate = Color(0.62, 0.62, 0.66, 1.0)
		row.add_child(card)
	_close_index = close_index
	visible = true

func close() -> void:
	visible = false
	_clear()

func _move_meta(id: String) -> String:
	var m := MoveDB.get_move(id)
	return "%s · %s" % [TypeChart.type_name(m["type"]), Lang.t("cat_" + String(m["cat"]))]

func _move_power(id: String) -> String:
	var m := MoveDB.get_move(id)
	return Lang.t("power", [int(m["power"])]) if m["power"] > 1 else Lang.t("power_none")

func _card(index: int, lines: Array, accent: Color, size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("decide")
		chosen.emit(index))
	# 종이 상자. 마우스를 올리면 원작 커서처럼 빨간 테두리.
	b.add_theme_stylebox_override("normal", _paper_style(PixelUi.PAPER, PixelUi.FRAME_OUT, 0))
	b.add_theme_stylebox_override("hover", _paper_style(PixelUi.PAPER_HOVER, PixelUi.CURSOR_RED, 0))
	b.add_theme_stylebox_override("pressed", _paper_style(PixelUi.PAPER_HOVER, PixelUi.CURSOR_RED, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 왼쪽 위 타입색 띠
	var band := ColorRect.new()
	band.color = accent
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_left = PixelUi.UI_SCALE
	band.offset_right = -PixelUi.UI_SCALE
	band.offset_top = PixelUi.UI_SCALE
	band.offset_bottom = 3 * PixelUi.UI_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(band)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 4 * PixelUi.UI_SCALE
	v.offset_right = -4 * PixelUi.UI_SCALE
	v.offset_top = 3 * PixelUi.UI_SCALE
	v.offset_bottom = -2 * PixelUi.UI_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	# 번호(작게, 타입색) · 기술 이름(본문) · 타입·분류(작게, 흐리게) · 위력(작게). 원작 글꼴에 [ ] 가 없어 "1." 로 센다.
	var smalls := [true, false, true, true]
	var colors := [accent.darkened(0.15), PixelUi.INK, PixelUi.INK_DIM, PixelUi.INK]
	for li in lines.size():
		if lines[li] == "":
			continue
		var l := Label.new()
		l.text = "%d. %s" % [index + 1, lines[li]] if li == 0 else lines[li]
		if smalls[li]:
			l.add_theme_font_override("font", UiFont.small())
			l.add_theme_font_size_override("font_size", UiFont.SMALL_SIZE)
		l.add_theme_color_override("font_color", colors[li])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	_buttons.append(b)
	return b

# 플래티넘 시스템 창(assets/ui/plat/sys_window.png, 24×24, 8px 모서리)을 9분할로 늘린 창. 그림이 없으면 네모 상자.
static func _paper_style(fill: Color, line: Color, margin: int) -> StyleBox:
	var tex := PixelUi.ui_tex("plat/sys_window")
	if tex != null and line != PixelUi.CURSOR_RED:
		var t := StyleBoxTexture.new()
		t.texture = tex
		var m := 8.0 * PixelUi.UI_SCALE
		t.texture_margin_left = m
		t.texture_margin_right = m
		t.texture_margin_top = m
		t.texture_margin_bottom = m
		t.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height())
		t.set_content_margin_all(maxf(margin, 5.0 * PixelUi.UI_SCALE))
		return t
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = line
	s.set_border_width_all(PixelUi.UI_SCALE)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margin)
	return s

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE and _close_index >= 0:
			get_viewport().set_input_as_handled()
			Sfx.play("select")
			chosen.emit(_close_index)
			return
		var idx: int = event.physical_keycode - KEY_1
		if idx >= 0 and idx < _buttons.size() and not (_buttons[idx] as Button).disabled:
			get_viewport().set_input_as_handled()
			Sfx.play("decide")
			chosen.emit(idx)
