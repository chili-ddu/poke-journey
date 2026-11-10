class_name SummaryScreen
extends Control

# 상태창 — 플래티넘 포켓몬 상세창(위 화면) 그대로(사용자 결정 2026-10-28: 가방처럼 원작 그대로 쓰고 천천히 고친다).
# 페이지는 셋: 정보(초록)·능력치(파랑)·기술(빨강) + 닫기 탭. 그림은 tools/plat_summary.py 가 구운 assets/ui/plat/sum_*.png,
# 글자 자리는 pret/pokeplatinum src/applications/pokemon_summary_screen/window.c 의 창 배치(타일 단위 × 8) 그대로.
#   공통: 쪽 제목 (8,0) · 이름 (24,24) · 레벨 (8,40) · 잡은 볼 (8,24) · 정면 그림 가운데 (52,104) · "지닌 물건" (8,160) · 물건 이름 (8,176)
#   탭: 가운데 x 188 에 모아 놓고 고른 탭만 24 폭(sprites.c CENTERED_TAB_POS_X·FOCUSED_TAB_WIDTH), y 24(가운데)
#   정보: 이름표 x 112, 값 (192,40) 도감 번호 · (184,56) 이름 · 타입 아이콘 가운데 (199,80)/(233,80), 하나면 (216,80) · (184,88) 어버이 ·
#         (200,104) ID(트레이너 ID 5자리) · (192,136) 경험치 · (192,168) 다음 레벨까지 · 경험치 막대 안쪽 x184~241 y186~188
#   능력치: "HP" (144,32) · HP 값 (184,32) · HP 막대 안쪽 x192~239 y50~53 · 이름표 (128,56+16i) · 값 (200,56+16i) 24 폭 ·
#         "특성" (112,144) · 특성 이름 (168,144) · 설명 (112,160) 144×32
#   기술(사용자 결정 2026-11-02: 기술은 네 칸 Q·W·E·R, 배운 기술 중에서 골라 끼운다): 위 네 줄 = 끼운 칸,
#         아래 세 줄 = 끼우지 않은 배운 기술(넘치면 스크롤). 원작의 기술 순서 바꾸기처럼 Enter 로 하나를 집고 다른 줄에서 Enter → 맞바꿈
#         (칸 ↔ 배운 기술이면 그 칸에 끼움). 원작 창 자리: 기술 칸 (168,32+32i) 88×32(이름 / PP) · 타입 아이콘 가운데 (151,42+32i) ·
#         커서 가운데 (194,48+32i) 와
#         왼쪽 상세 판(move_info, (0,24)) — 타입 아이콘 가운데 (63,52)/(97,52) · 분류 (8,64) · 위력 (8,80)·값 (96,80) ·
#         명중 (8,96)·값 (96,96) · 설명 (8,112) 120×80
# 조작: ←→(A·D) 쪽 넘기기, 기술 쪽에서 ↑↓(W·S) 기술 고르기, 고른 줄을 한 번 더(Enter·클릭) → 모달(Q·W·E·R·그만둔다): 끼우지 않은 기술은 끼우고 끼운 기술끼리는 맞바꾸기,
#       Esc 로 고르기·모달 취소, 닫기는 C(또는 닫기 탭)만, 탭 클릭. 탭은 2배 크기(TAB_SCALE).
# 크기: Game._fit_ui 가 UI 배율을 되돌려(scale = k/m) 원본 1px = 게임 화면 1px 로 그린다.

signal closed

const SCREEN := Vector2(256, 192)
const PAGES := ["info", "skills", "moves"]
const TAB_CELL := {"info": 0, "skills": 2, "moves": 4, "exit": 7}   # 원작 쪽 순서(SummaryPage) = 탭 그림 번호
# 탭은 원작의 1.5배(16 → 24px, 고른 탭 36px)로 — 작아서 누르기 불편했다(사용자 요청 2026-10-30). 2배는 위 띠(24px)를 넘어 아래 상자에
# 걸쳤다(사용자 지적) → 1.5배. 원작처럼 띠 아래 끝(y 32)에 붙인다(사용자 지적 2026-10-30: 위에 떠 있지 말고 아래에 붙게) → y 8.
# 네 탭이 화면 오른쪽 끝을 넘지 않게 가운데를 184 로.
const TAB_SCALE := 1.5
const TAB_CENTER_X := 184
const TAB_Y := 8
const LABEL := Color.WHITE
const LABEL_SHADOW := Color("50506a")

var mon: Player
var page := 0
var move_cursor := -1          # 기술 쪽에서 고른 줄(_entries 번호, -1 = 안 고름)
# 끼우기 모달(사용자 요청 2026-10-30): 고른 기술을 한 번 더 누르면(두 번째 클릭·Enter) "어느 칸에 끼울까?" — Q / W / E / R / 그만둔다.
# 끼우지 않은 기술이면 그 칸에 끼우고, 끼운 기술이면 고른 칸과 맞바꾼다(기술 네 칸, 사용자 결정 2026-11-02 — 처음엔 L / R 두 칸).
var modal := -1                # 모달이 끼우려는 줄(_entries 번호), -1 = 닫힘
var modal_cursor := 0          # 0~3 = Q·W·E·R, 4 = 그만둔다
const MODAL := Rect2(48, 36, 160, 116)
var spare_scroll := 0          # 아래 줄(끼우지 않은 기술)의 스크롤
const SPARE_ROWS := 5 - Player.SLOT_COUNT   # 화면은 다섯 줄 — 네 칸 아래 한 줄
var notice := ""               # 잠깐 띄우는 안내(제목 자리, 1.5초)
var notice_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func open(p: Player) -> void:
	mon = p
	page = 0
	move_cursor = -1
	modal = -1
	spare_scroll = 0
	visible = true

func close() -> void:
	visible = false

func origin() -> Vector2:
	return ((size - SCREEN) / 2.0).floor()

# ── 조작 ──

func _switch(d: int) -> void:
	Sfx.play("select")
	page = posmod(page + d, PAGES.size())
	move_cursor = -1
	modal = -1

# 기술 쪽 줄 목록: 끼운 두 칸(빈 칸은 "") 다음에 끼우지 않은 배운 기술.
func _entries() -> Array:
	var out: Array = mon.slots.duplicate()
	out.append_array(mon.spare_moves())
	return out

# 그 줄이 화면 몇째 줄(0~4)에 있나. 스크롤로 안 보이면 -1.
func _row_of(idx: int) -> int:
	if idx < Player.SLOT_COUNT:
		return idx
	var k := idx - Player.SLOT_COUNT - spare_scroll
	return Player.SLOT_COUNT + k if k >= 0 and k < SPARE_ROWS else -1

func _move(d: int) -> void:
	if PAGES[page] != "moves":
		return
	var n := _entries().size()
	move_cursor = 0 if move_cursor < 0 else clampi(move_cursor + d, 0, n - 1)
	Sfx.play("select")
	if move_cursor >= Player.SLOT_COUNT:
		var k := move_cursor - Player.SLOT_COUNT
		if k < spare_scroll:
			spare_scroll = k
		elif k >= spare_scroll + SPARE_ROWS:
			spare_scroll = k - SPARE_ROWS + 1

# 고른 줄을 한 번 더(Enter·두 번째 클릭): 모달 — 끼우지 않은 기술은 고른 칸에 끼우고, 끼운 기술은 고른 칸과 맞바꾼다.
func _pick() -> void:
	if move_cursor < 0:
		_move(0)
	else:
		modal = move_cursor
		modal_cursor = move_cursor if move_cursor < Player.SLOT_COUNT else 0

func _modal_choose(i: int) -> void:
	if i >= Player.SLOT_COUNT:
		Sfx.play("select")
		modal = -1
		return
	var e := _entries()
	if modal < 0 or modal >= e.size():
		modal = -1
		return
	if modal < Player.SLOT_COUNT:
		# 끼운 기술끼리 맞바꾸기(Q·W·E·R 칸 사이)
		var from := modal
		modal = -1
		if from != i:
			Sfx.play("decide")
			_swap(from, i)
			move_cursor = i
		return
	if not mon.can_swap(i):
		notice = Lang.t("swap_need_full")
		notice_t = 1.5
		return
	Sfx.play("decide")
	mon.equip(i, e[modal])
	modal = -1
	move_cursor = i

func _swap(a: int, b: int) -> void:
	if a == b:
		return
	var e := _entries()
	var ida: String = e[a]
	var idb: String = e[b]
	var sc := Player.SLOT_COUNT
	# PP 가 가득인 기술만 칸에서 빼거나 옮길 수 있다(사용자 결정 2026-10-28). 빼 둔 기술은 늘 가득.
	if (a < sc and not mon.can_swap(a)) or (b < sc and not mon.can_swap(b)):
		notice = Lang.t("swap_need_full")
		notice_t = 1.5
		return
	if a < sc and b < sc:
		if idb != "":
			mon.equip(a, idb)          # 다른 칸에 있으면 equip 이 맞바꾼다
		elif ida != "":
			mon.equip(b, ida)
	elif a < sc:
		mon.equip(a, idb)
	elif b < sc:
		mon.equip(b, ida)
	else:
		# 둘 다 끼우지 않은 기술: 배운 기술 목록에서 순서만 바꾼다.
		var ia := mon.learned.find(ida)
		var ib := mon.learned.find(idb)
		mon.learned[ia] = idb
		mon.learned[ib] = ida

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed):
		return
	var handled := true
	match event.physical_keycode:
		KEY_LEFT, KEY_A:
			if modal >= 0: pass
			else: _switch(-1)
		KEY_RIGHT, KEY_D:
			if modal >= 0: pass
			else: _switch(1)
		KEY_Q, KEY_W, KEY_E, KEY_R when modal >= 0:
			if not event.echo:
				_modal_choose(Controllers.SKILL_KEYS.find(event.physical_keycode))   # 모달에선 Q·W·E·R 로 바로 그 칸
		KEY_UP, KEY_W:
			if modal >= 0:
				modal_cursor = posmod(modal_cursor - 1, Player.SLOT_COUNT + 1)
				Sfx.play("select")
			else:
				_move(-1)
		KEY_DOWN, KEY_S:
			if modal >= 0:
				modal_cursor = posmod(modal_cursor + 1, Player.SLOT_COUNT + 1)
				Sfx.play("select")
			else:
				_move(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			if event.echo:
				pass
			elif modal >= 0:
				_modal_choose(modal_cursor)
			elif PAGES[page] == "moves":
				Sfx.play("decide")
				_pick()
		KEY_C:
			if not event.echo:
				Sfx.play("select")
				closed.emit()
		KEY_ESCAPE:
			# Esc 는 모달·고르기만 취소한다 — 닫기는 C(또는 닫기 탭)만(사용자 결정 2026-10-28).
			if modal >= 0:
				modal = -1
				Sfx.play("select")
			elif move_cursor >= 0:
				move_cursor = -1
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position - origin()
	if event.button_index == MOUSE_BUTTON_LEFT:
		if modal >= 0:
			for i in Player.SLOT_COUNT + 1:
				if _modal_row(i).has_point(p):
					_modal_choose(i)
					accept_event()
					return
			if not MODAL.has_point(p):
				modal = -1          # 바깥을 누르면 닫는다
				Sfx.play("select")
			accept_event()
			return
		for t in _tabs():
			if Rect2(t["x"], TAB_Y, t["w"], 16.0 * TAB_SCALE).has_point(p):
				Sfx.play("select")
				if t["id"] == "exit":
					closed.emit()
				else:
					page = PAGES.find(t["id"])
					move_cursor = -1
					modal = -1
				accept_event()
				return
		if PAGES[page] == "moves":
			var n := _entries().size()
			for idx in n:
				var r := _row_of(idx)
				if r >= 0 and Rect2(130, 32 + 32 * r, 126, 32).has_point(p):
					if idx == move_cursor:
						Sfx.play("decide")
						_pick()            # 첫 클릭은 고르기, 두 번째 클릭은 끼우기·맞바꾸기 모달
					else:
						Sfx.play("select")
						move_cursor = idx
	accept_event()             # 창 밖 클릭도 삼킨다(닫지 않음)

# 탭 줄: 원작처럼 가운데에 모으고 고른 탭은 24 폭 — 전부 TAB_SCALE 배.
func _tabs() -> Array:
	var ids: Array = PAGES.duplicate()
	ids.append("exit")
	var wf := 24.0 * TAB_SCALE
	var wn := 16.0 * TAB_SCALE
	var x := float(TAB_CENTER_X) - (wf + float(ids.size() - 1) * wn) / 2.0 - wn / 2.0
	var out: Array = []
	for id in ids:
		var focused: bool = id == PAGES[page]
		out.append({"id": id, "x": x, "w": wf if focused else wn, "focused": focused})
		x += wf if focused else wn
	return out

func _modal_row(i: int) -> Rect2:
	return Rect2(MODAL.position.x + 10, MODAL.position.y + 26 + 16 * i, MODAL.size.x - 20, 16)

# ── 그리기 ──

func _process(dt: float) -> void:
	notice_t = maxf(0.0, notice_t - dt)
	if visible:
		queue_redraw()

func _t(pos: Vector2, s: String, color: Color = PixelUi.INK, shadow: Color = PixelUi.INK_SHADOW, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	PixelUi.text(self, origin() + pos, s, false, color, shadow, align)

func _label(pos: Vector2, s: String) -> void:
	_t(pos, s, LABEL, LABEL_SHADOW)

# 값: 창(x, w) 안에서 오른쪽 맞춤.
func _value(x: float, y: float, w: float, s: String) -> void:
	_t(Vector2(x + w, y), s, PixelUi.INK, PixelUi.INK_SHADOW, HORIZONTAL_ALIGNMENT_RIGHT)

func _type_icon(center: Vector2, type_id: String) -> void:
	var r := Rect2(origin() + center - Vector2(16, 8), Vector2(32, 16))
	if not Lang.is_ko() and PixelUi.blit_rect(self, "plat/types/%s" % type_id, r):
		return
	var col: Color = TypeChart.type_color(type_id)
	draw_rect(r, col.darkened(0.45))
	draw_rect(r.grow(-1), col)
	PixelUi.text(self, Vector2(floorf(r.position.x + 16), r.position.y), Lang.type_name(type_id), true, Color.WHITE, col.darkened(0.5), HORIZONTAL_ALIGNMENT_CENTER)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	if mon == null:
		return
	var o := origin()
	var key: String = PAGES[page]
	var bg := PixelUi.ui_tex("plat/sum_" + key)
	if bg != null:
		draw_texture(bg, o)
	else:
		draw_rect(Rect2(o, SCREEN), PixelUi.PAPER)
	# 탭
	var tabs_tex := PixelUi.ui_tex("plat/sum_tabs")
	if tabs_tex != null:
		for t in _tabs():
			var cell: int = TAB_CELL[t["id"]]
			var src := Rect2(cell * 24, 16, 24, 16) if t["focused"] else Rect2(cell * 24, 0, 16, 16)
			draw_texture_rect_region(tabs_tex, Rect2(o + Vector2(t["x"], TAB_Y), src.size * TAB_SCALE), src)
	# 공통: 쪽 제목, 이름·레벨·볼, 정면 그림, 지닌 물건
	_label(Vector2(8, 0), notice if notice_t > 0.0 else Lang.t("sum_title_" + key))
	PixelUi.blit_rect(self, "plat/sum_ball", Rect2(o + Vector2(8, 24), Vector2(16, 16)))
	_t(Vector2(24, 24), mon.display_name())
	_t(Vector2(8, 40), "Lv%d" % mon.level)
	if not (key == "moves" and move_cursor >= 0):
		var front := PixelUi.ui_tex("plat/front/" + mon.species_id + ("_shiny" if mon.shiny else ""))
		if front != null:
			draw_texture(front, o + Vector2(52, 104) - Vector2(40, 40))
		# 이로치 별: sprites.c SUMMARY_SPRITE_SHINY_ICON (98,72) 가운데, 8×8.
		if mon.shiny:
			PixelUi.blit_rect(self, "plat/sum_shiny", Rect2(o + Vector2(94, 68), Vector2(8, 8)))
	if not (key == "moves" and move_cursor >= 0 and _entries()[move_cursor] != ""):
		_label(Vector2(8, 160), Lang.t("sum_item"))
		_t(Vector2(8, 176), ItemDB.name_of(mon.hold) if "hold" in mon and String(mon.hold) != "" else Lang.t("sum_none"))
	match key:
		"info": _draw_info()
		"skills": _draw_skills()
		"moves": _draw_moves()

func _draw_info() -> void:
	var sp := SpeciesDB.get_species(mon.species_id)
	_label(Vector2(112, 40), Lang.t("sum_dex"))
	_value(192, 40, 48, "%03d" % int(sp.get("dex", 0)))
	_label(Vector2(112, 56), Lang.t("sum_name"))
	_t(Vector2(184, 56), Lang.species_name(mon.species_id))
	_label(Vector2(112, 72), Lang.t("sum_type"))
	var types: Array = sp.get("types", [])
	if types.size() >= 2 and types[1] != types[0]:
		_type_icon(Vector2(199, 80), types[0])
		_type_icon(Vector2(233, 80), types[1])
	elif types.size() >= 1:
		_type_icon(Vector2(216, 80), types[0])
	_label(Vector2(112, 88), Lang.t("sum_ot"))
	_t(Vector2(184, 88), "---")
	_label(Vector2(112, 104), Lang.t("sum_id"))
	_value(200, 104, 32, "%05d" % Individual.tid)   # IDNo.: 트레이너 ID(비밀 ID 는 원작처럼 안 보임)
	_label(Vector2(112, 120), Lang.t("sum_exp"))
	_value(192, 136, 48, str(mon.exp_total))
	_label(Vector2(112, 152), Lang.t("sum_next"))
	var next := SpeciesDB.exp_for_level(mon.level + 1, SpeciesDB.growth_of(mon.species_id)) - mon.exp_total
	_value(192, 168, 48, str(maxi(0, next)))
	var w := floorf(58.0 * mon.exp_progress())
	if w > 0.0:
		draw_rect(Rect2(origin() + Vector2(184, 186), Vector2(w, 2)), PixelUi.PLAT_EXP)
		draw_rect(Rect2(origin() + Vector2(184, 188), Vector2(w, 1)), PixelUi.PLAT_EXP_DARK)

func _draw_skills() -> void:
	_label(Vector2(144, 32), "HP")
	_value(184, 32, 56, "%d/%d" % [mon.hp, mon.max_hp])
	var ratio := mon.hp_ratio()
	var w := floorf(48.0 * clampf(ratio, 0.0, 1.0))
	if ratio > 0.0:
		w = maxf(w, 1.0)
		var c: Color = PixelUi.PLAT_HP[0] if ratio > 0.5 else (PixelUi.PLAT_HP[1] if ratio > 0.2 else PixelUi.PLAT_HP[2])
		draw_rect(Rect2(origin() + Vector2(192, 50), Vector2(w, 3)), c)
		draw_rect(Rect2(origin() + Vector2(192, 53), Vector2(w, 1)), c.darkened(0.35))
	var keys := ["atk", "def", "spa", "spd", "spe"]
	for i in keys.size():
		_label(Vector2(128, 56 + 16 * i), Lang.stat_label(keys[i]))
		_value(200, 56 + 16 * i, 24, str(int(mon.stats.get(keys[i], 0))))
	_label(Vector2(112, 144), Lang.t("sum_ability"))
	var ab := AbilityDB.of_species(mon.species_id)
	if ab != "":
		_t(Vector2(168, 144), AbilityDB.name_of(ab))
		PixelUi.paragraph(self, origin() + Vector2(112, 160), AbilityDB.desc_of(ab), 144, 2)

func _draw_moves() -> void:
	var o := origin()
	var e := _entries()
	for idx in e.size():
		var r := _row_of(idx)
		if r < 0:
			continue
		var id: String = e[idx]
		var y := 32.0 + 32.0 * r
		if idx < Player.SLOT_COUNT:
			_t(Vector2(138, y + 16), Player.SLOT_KEYS[idx], Color.WHITE, LABEL_SHADOW)
		if id == "":
			_t(Vector2(168, y), "---", PixelUi.INK_DIM)
			continue
		var m := MoveDB.get_move(id)
		_type_icon(Vector2(151, 42 + 32 * r), m["type"])
		_t(Vector2(168, y), MoveDB.move_name(id))
		_t(Vector2(176, y + 16), "PP", PixelUi.INK)
		_value(168, y + 16, 84, "%d/%d" % [mon.pp_of_move(id), MoveDB.pp_of(id)])   # 창은 88 폭이지만 화면 끝에 붙지 않게 4px 안쪽
	# 아래 줄이 넘치면 위·아래 화살표(가방 화살표 그림).
	var arrows := PixelUi.ui_tex("plat/bag_arrows")
	var spare_n := e.size() - Player.SLOT_COUNT
	if arrows != null:
		if spare_scroll > 0:
			draw_texture_rect_region(arrows, Rect2(o + Vector2(236, 22 + 32 * Player.SLOT_COUNT), Vector2(16, 16)), Rect2(0, 16, 16, 16))
		if spare_scroll + SPARE_ROWS < spare_n:
			draw_set_transform(o + Vector2(236, 194), 0.0, Vector2(1, -1))
			draw_texture_rect_region(arrows, Rect2(Vector2.ZERO, Vector2(16, 16)), Rect2(0, 16, 16, 16))
			draw_set_transform(Vector2.ZERO)
	if move_cursor < 0 or move_cursor >= e.size():
		return
	if _row_of(move_cursor) >= 0:
		PixelUi.blit_rect(self, "plat/sum_move_cursor", Rect2(o + Vector2(194, 48 + 32 * _row_of(move_cursor)) - Vector2(64, 16), Vector2(128, 32)))
	var mid: String = e[move_cursor]
	if mid == "":
		return
	# 왼쪽 상세 판: 내 타입 · 분류 · 위력 · 명중 · 설명
	var panel := PixelUi.ui_tex("plat/sum_move_info")
	# 설명 자리(판 아래 ~ 화면 끝)는 밝은 바탕으로 덮는다 — 정면 그림 상자·지닌 물건 판과 글이 겹치지 않게.
	draw_rect(Rect2(o + Vector2(0, 96), Vector2(130, 96)), Color("f0f4ec"))
	if panel != null:
		draw_texture(panel, o + Vector2(0, 24))
	var types: Array = SpeciesDB.get_species(mon.species_id).get("types", [])
	if types.size() >= 1:
		_type_icon(Vector2(63, 52), types[0])
	if types.size() >= 2 and types[1] != types[0]:
		_type_icon(Vector2(97, 52), types[1])
	var mv := MoveDB.get_move(mid)
	_label(Vector2(8, 64), Lang.t("sum_category"))
	_value(64, 64, 60, Lang.t("cat_" + String(mv["cat"])))
	_label(Vector2(8, 80), Lang.t("sum_power"))
	_value(96, 80, 24, str(int(mv["power"])) if int(mv["power"]) > 1 else "---")
	_label(Vector2(8, 96), Lang.t("sum_accuracy"))
	_value(96, 96, 24, str(int(mv.get("accuracy", 0))) if int(mv.get("accuracy", 0)) > 0 else "---")
	PixelUi.paragraph(self, o + Vector2(8, 112), MoveDB.desc_of(mid), 120, 5)
	if modal >= 0 and modal < e.size():
		_draw_modal(o, String(e[modal]))

# 끼우기 모달: "어느 칸에 끼울까?" + Q·W·E·R(지금 기술) / 그만둔다. 글상자 틀, 빨간 ▶ 커서.
func _draw_modal(o: Vector2, move_id: String) -> void:
	var r := Rect2(o + MODAL.position, MODAL.size)
	draw_rect(Rect2(o, SCREEN), Color(0, 0, 0, 0.35))
	if not PixelUi.nine(self, "plat/msgbox", r, 10):
		draw_rect(r, PixelUi.PAPER)
	PixelUi.text(self, r.position + Vector2(10, 6), Lang.t("swap_which", [MoveDB.move_name(move_id)]), false, PixelUi.INK, PixelUi.INK_SHADOW)
	for i in Player.SLOT_COUNT + 1:
		var row := _modal_row(i)
		var label: String
		if i < Player.SLOT_COUNT:
			var cur: String = mon.slots[i]
			label = "%s  %s" % [Player.SLOT_KEYS[i], MoveDB.move_name(cur) if cur != "" else "---"]
		else:
			label = Lang.t("trade_no")
		PixelUi.text(self, o + row.position + Vector2(12, 0), label, false, PixelUi.INK if i == modal_cursor else PixelUi.INK_DIM, PixelUi.INK_SHADOW)
		if i == modal_cursor:
			var a := o + row.position + Vector2(2, 5)
			draw_colored_polygon(PackedVector2Array([a, a + Vector2(0, 7), a + Vector2(5, 3.5)]), PixelUi.CURSOR_RED)
