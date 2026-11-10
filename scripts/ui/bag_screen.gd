class_name BagScreen
extends Control

# 가방 화면 — 플래티넘 가방의 위 화면 그대로(사용자 결정 2026-10-28: 일단 원작 그대로 쓰고 천천히 고친다). tools/plat_bag.py 가 구운 그림:
#   bag_bg            256×192 배경. 왼쪽 "BAG"·가방 자리·주머니 이름판(POCKET), 오른쪽 초록 틀 = 목록 창, 아래 보라 띠 = 설명칸
#   bag_sprite        가방 그림 64×64 × 8(주머니마다 그 칸이 빨갛다)
#   bag_pocket_icons  주머니 아이콘 16×16 × 16(주머니마다 안 고름·고름 한 쌍)
#   bag_arrows        화살표(위 16×16 오른쪽, 아래 16×16 위쪽) — 뒤집어 왼쪽·아래로
#   bag_item_cursor   목록 선택 줄(빨간 둥근 틀 148×17), bag_pocket_cursor 아이콘 선택 틀
# 원작의 아래 화면(주머니 다이얼)은 한 화면이라 쓰지 않는다 → 주머니 이름판 양옆 화살표·좌우 키, 이름판 위 아이콘 줄로 바꾼다.
# 주머니는 우리가 쓰는 다섯만(사용자 결정): 도구·약·기술머신·열매·배틀 도구. 그림 번호는 원작 주머니 순서(ItemDB.POCKET_ORDER).
# 조작: ←→(A·D) 주머니, ↑↓(W·S) 고르기, Enter·Space·E 쓰기, 1~4 도구 편성(2026-11-02). 닫기는 B(또는 목록의 "가방 닫기")만 — 창 밖 클릭·우클릭·Esc 로는 안 닫힌다
# (사용자 결정 2026-10-28). 마우스: 아이콘·화살표·줄 클릭(고른 줄을 한 번 더 누르면 쓰기).
# 크기: Game._fit_ui 가 UI 배율을 되돌려(scale = k/m) 원본 1px = 게임 화면 1px 로 그린다.

signal used(id: String)
signal closed
signal hotbar_set(slot: int, id: String)      # 도구를 고른 채 숫자 키 1~4 — 그 칸에 편성(사용자 결정 2026-11-02)

const SCREEN := Vector2(256, 192)
const LIST := Rect2(108, 9, 142, 122)          # 목록 창 안쪽(투명 자리)
const ROW_H := 16.0
const ROWS := 7
const SLOT := Rect2(5, 106, 91, 16)            # 주머니 이름 칸
const ICON_ROW := Vector2(10, 87)              # 주머니 아이콘 줄(이름판 윗줄 위)
const DESC_ICON := Vector2(2, 151)             # 설명칸 흰 네모(30×30)에 아이콘 32×32
const DESC_TEXT := Rect2(40, 144, 210, 48)      # 세 줄(16px × 3)이 화면 아래 끝(192)에 딱 맞게
const CLOSE := "__close"

var bag: Dictionary = {}
var hotbar: Array = []                         # 도구 편성(Player.hotbar — 같은 배열). 편성된 도구 줄엔 칸 번호를 붙인다
var pocket := 0                                # BAG_POCKETS 의 번호
var cursor := 0
var scroll := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func open(bag_ref: Dictionary) -> void:
	bag = bag_ref
	pocket = clampi(pocket,0,_pockets().size()-1)
	cursor = 0
	scroll = 0
	# 처음엔 물건이 있는 첫 주머니.
	for i in _pockets().size():
		if _ids(i).size() > 1:
			pocket = i
			break
	visible = true
	queue_redraw()

func close() -> void:
	visible = false

func _pockets() -> Array:
	var keys:=ItemDB.BAG_POCKETS.duplicate()
	for id in bag:
		if int(bag[id])>0 and ItemDB.pocket_of(id)=="key":
			keys.append("key")
			break
	return keys

func _ids(p: int = pocket) -> Array:
	var out: Array = []
	var key: String = _pockets()[p]
	for id in ItemDB.all_items():
		if ItemDB.pocket_of(id) == key and int(bag.get(id, 0)) > 0:
			out.append(id)
	out.append(CLOSE)
	return out

func selected_id() -> String:
	var ids := _ids()
	return ids[clampi(cursor, 0, ids.size() - 1)]

func origin() -> Vector2:
	return ((size - SCREEN) / 2.0).floor()

# ── 조작 ──

func _switch(d: int) -> void:
	Sfx.play("select")
	pocket = posmod(pocket + d, _pockets().size())
	cursor = 0
	scroll = 0
	queue_redraw()

func _move(d: int) -> void:
	var n := _ids().size()
	var before := cursor
	cursor = clampi(cursor + d, 0, n - 1)
	if cursor != before:
		Sfx.play("select")
	if cursor < scroll:
		scroll = cursor
	elif cursor >= scroll + ROWS:
		scroll = cursor - ROWS + 1
	queue_redraw()

func _choose() -> void:
	var id := selected_id()
	if id == CLOSE:
		Sfx.play("select")
		closed.emit()
	else:
		Sfx.play("decide")
		used.emit(id)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed):
		return
	var handled := true
	match event.physical_keycode:
		KEY_LEFT, KEY_A: _switch(-1)
		KEY_RIGHT, KEY_D: _switch(1)
		KEY_UP, KEY_W: _move(-1)
		KEY_DOWN, KEY_S: _move(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			if not event.echo:
				_choose()
		KEY_B:
			if not event.echo:
				Sfx.play("select")
				closed.emit()
		KEY_ESCAPE:
			pass                     # Esc 로는 닫지 않는다(B 로만)
		KEY_1, KEY_2, KEY_3, KEY_4:
			if not event.echo and selected_id() != "":
				Sfx.play("decide")
				hotbar_set.emit(event.physical_keycode - KEY_1, selected_id())
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position - origin()
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_move(-1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_move(1)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		for i in _pockets().size():
			if Rect2(ICON_ROW + Vector2(i * 16, 0), Vector2(16, 16)).has_point(p):
				pocket = i
				cursor = 0
				scroll = 0
				queue_redraw()
				return
		if Rect2(SLOT.position, Vector2(16, SLOT.size.y)).has_point(p):
			_switch(-1)
		elif Rect2(SLOT.end.x - 16, SLOT.position.y, 16, SLOT.size.y).has_point(p):
			_switch(1)
		elif LIST.has_point(p):
			var row := scroll + int((p.y - LIST.position.y) / ROW_H)
			if row < _ids().size():
				if row == cursor:
					_choose()
				else:
					cursor = row
					queue_redraw()
	accept_event()             # 창 밖 클릭도 여기서 삼킨다(닫지 않음, 게임으로 새지 않음)

# ── 그리기 ──

func _process(_dt: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var o := origin()
	var bg := PixelUi.ui_tex("plat/bag_bg")
	if bg == null:
		draw_rect(Rect2(o, SCREEN), PixelUi.PAPER)
	else:
		draw_texture(bg, o)
	var key: String = _pockets()[pocket]
	var frame := ItemDB.POCKET_ORDER.find(key)
	# 가방 그림(주머니 칸이 빨갛다). 살짝 위아래로 흔들리지 않고 원작처럼 가만히.
	var spr := PixelUi.ui_tex("plat/bag_sprite")
	if spr != null:
		draw_texture_rect_region(spr, Rect2(o + Vector2(17, 10), Vector2(64, 64)), Rect2(0, frame * 64, 64, 64))
	# 주머니 아이콘 줄: 고른 것은 빨간 그림 + 빨간 틀.
	var icons := PixelUi.ui_tex("plat/bag_pocket_icons")
	for i in _pockets().size():
		var f := ItemDB.POCKET_ORDER.find(_pockets()[i])
		var at := o + ICON_ROW + Vector2(i * 16, 0)
		if icons != null:
			draw_texture_rect_region(icons, Rect2(at, Vector2(16, 16)), Rect2((f * 2 + (1 if i == pocket else 0)) * 16, 0, 16, 16))
		if i == pocket:
			PixelUi.blit_rect(self, "plat/bag_pocket_cursor", Rect2(at, Vector2(16, 16)))
	# 주머니 이름 + 양옆 화살표(원작 pocket_selector_arrows).
	PixelUi.text(self, o + Vector2(SLOT.position.x + SLOT.size.x / 2.0, SLOT.position.y - 1), Lang.t("pocket_" + key), false,
		Color.WHITE, Color("303048"), HORIZONTAL_ALIGNMENT_CENTER)
	var arrows := PixelUi.ui_tex("plat/bag_arrows")
	if arrows != null:
		var bob := 1.0 if int(Time.get_ticks_msec() / 300) % 2 == 0 else 0.0
		draw_texture_rect_region(arrows, Rect2(o + Vector2(SLOT.end.x - 14 + bob, SLOT.position.y), Vector2(16, 16)), Rect2(0, 0, 16, 16))
		# 왼쪽 화살표는 오른쪽 화살표를 좌우로 뒤집어(크기를 음수로 주면 Godot 는 안 뒤집는다 → 변환으로).
		draw_set_transform(o + Vector2(SLOT.position.x + 16 - bob, SLOT.position.y), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(arrows, Rect2(Vector2.ZERO, Vector2(16, 16)), Rect2(0, 0, 16, 16))
		draw_set_transform(Vector2.ZERO)
	# 목록: 이름(왼쪽)·개수(오른쪽), 마지막 줄은 "가방 닫기". 넘치면 위아래 화살표.
	var ids := _ids()
	for r in ROWS:
		var idx := scroll + r
		if idx >= ids.size():
			break
		var id: String = ids[idx]
		var y := o.y + LIST.position.y + r * ROW_H
		if id == CLOSE:
			PixelUi.text(self, Vector2(o.x + LIST.position.x + 4, y - 1), Lang.t("bag_close_row"), false)
		else:
			PixelUi.text(self, Vector2(o.x + LIST.position.x + 4, y - 1), ItemDB.name_of(id), false)
			PixelUi.text(self, Vector2(o.x + LIST.end.x - 4, y - 1), "×%d" % int(bag[id]), false, PixelUi.INK, PixelUi.INK_SHADOW, HORIZONTAL_ALIGNMENT_RIGHT)
			var hk := hotbar.find(id)
			if hk >= 0:
				# 편성된 칸 번호: 이름 왼쪽 끝 작은 숫자 딱지
				var tag := Rect2(Vector2(o.x + LIST.position.x - 10, y + 2), Vector2(9, 10))
				draw_rect(tag, Color("4a8a4a"))
				PixelUi.text(self, Vector2(tag.position.x + 5, tag.position.y - 2), str(hk + 1), true, Color.WHITE, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
		if idx == cursor:
			PixelUi.blit_rect(self, "plat/bag_item_cursor", Rect2(o.x + LIST.position.x - 3, y - 1, 148, 17))
	if arrows != null:
		var cx := o.x + LIST.position.x + LIST.size.x / 2.0 - 8
		if scroll > 0:
			draw_texture_rect_region(arrows, Rect2(cx, o.y + LIST.position.y - 9, 16, 16), Rect2(0, 16, 16, 16))
		if scroll + ROWS < ids.size():
			draw_set_transform(Vector2(cx, o.y + LIST.end.y + 9), 0.0, Vector2(1, -1))
			draw_texture_rect_region(arrows, Rect2(Vector2.ZERO, Vector2(16, 16)), Rect2(0, 16, 16, 16))
			draw_set_transform(Vector2.ZERO)
	# 설명칸: 고른 물건의 아이콘과 설명(흰 글자). "가방 닫기"면 안내.
	var sid := selected_id()
	if sid == CLOSE:
		PixelUi.paragraph(self, o + DESC_TEXT.position, Lang.t("bag_close_desc"), DESC_TEXT.size.x, 3, Color.WHITE, Color("383870"))
	else:
		var tex := ItemDB.icon(sid)
		if tex != null:
			draw_texture(tex, o + DESC_ICON)
		PixelUi.paragraph(self, o + DESC_TEXT.position, ItemDB.desc_of(sid), DESC_TEXT.size.x, 3, Color.WHITE, Color("383870"))
