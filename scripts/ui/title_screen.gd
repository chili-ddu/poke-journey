class_name TitleScreen
extends Control

# 시작 화면 — 원본 PC 박스 + HD-2D 정면 도트 + 오른쪽 스타팅별 저장 목록.
# 포켓몬을 고르면 오른쪽에 해당 스타팅의 여러 기록이 표시된다. 기존 파일은 기록 1로 유지한다.
# 그림은 tools/plat_box.py 가 box.narc 에서 원작 순서대로 구운 것:
#   box_bg     256×192: 줄무늬 바탕 + 벽지(FOREST, x 88~256 y 0~160) + 왼쪽 미리보기 판·아래 이름 칸
#   box_hand 원본 손 커서. 박스는 plat/icons, 왼쪽 도감 그림은 plat/front(진화·이로치 반영).
# 조작: ←→(A·D) 고르기, Enter·Space·E(또는 아이콘 클릭)로 메뉴, 메뉴는 ↑↓ + Enter, Esc 는 메뉴 닫기, L 은 언어.
# 384×216 기준에서 박스와 저장 목록을 함께 중앙 배치하고, 남는 곳은 원본 줄무늬로 채운다.

const SCREEN := Vector2(256, 192)
const LAYOUT := Vector2(384,192)
const RECORDS := Rect2(264,0,120,192)
const STAGE := Rect2(88,28,168,130)
const BOX_X := 88.0                  # 벽지(박스) 왼쪽
const SLOT0 := Vector2(92, 42)      # 세 포켓몬 선택 영역: 원본 벽지 안에서 52px 간격
const SLOT := 52.0
const PREVIEW := Vector2(44, 84)     # 왼쪽 미리보기 창 가운데(정면 그림 80×80)
const NAME_BOX := Rect2(10, 166, 98, 18)
const MENU_X := 118.0                # 메뉴 창: 오른쪽 아래, 줄 수만큼 위로 자란다
const MENU_W := 132.0
const GameTransition=preload("res://scripts/ui/title_game_transition.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const START_LEVEL := 5               # 새로 시작하는 레벨(Game.START_LEVEL 과 같게)

var cursor := 1                      # 처음엔 가운데(파이리)
static var last_records := {}         # 스타팅별 선택한 슬롯 번호(1~5)
static var last := ""                # 게임에서 돌아오면 하던 스타팅 칸에 커서를 둔다
var launching := false
var menu_open := false
var menu_items: Array = []           # [{key, label}]
var menu_cursor := 0
var confirm := false                 # 리셋 확인 중(메뉴 대신 예/아니오)
var t := 0.0
var stage: TitleBoxStage
var _places := {}
var _records := {}

var _info := {}                      # 스타팅 → peek 결과(세이브 요약)

func _ready() -> void:
	Controllers.ensure_input_map()
	get_viewport().oversampling = false
	Lang.load_saved()
	ViewScale.init_window(get_tree())
	ViewScale.use_title(get_tree())        # 박스와 오른쪽 저장 목록을 함께 표시
	SaveData.migrate_legacy()
	Bgm.play(Bgm.TITLE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if SaveData.STARTERS.has(last):
		cursor = SaveData.STARTERS.find(last)
	stage=TitleBoxStage.new()
	add_child(stage)
	_refresh()

func _refresh() -> void:
	_info.clear()
	_places.clear()
	_records.clear()
	for s in SaveData.STARTERS:
		var entries := []
		for id in range(1,SaveData.RECORD_LIMIT+1):
			var exists := SaveData.slot_exists(s,id)
			var summary := SaveData.peek(s,id) if exists else {}
			var place := _place_name(String(summary.get("map","")),summary.get("pos",Vector2(-1,-1)),int(summary.get("layout",1)))
			entries.append({"id":id,"summary":summary,"place":place,"exists":exists})
		_records[s]=entries
		var chosen := clampi(int(last_records.get(s,1)),1,SaveData.RECORD_LIMIT)
		last_records[s]=chosen
		_sync_summary(s)

func record_id(s: String = "") -> int:
	return int(last_records.get(starter() if s=="" else s,1))

func _sync_summary(s: String) -> void:
	_info[s]={}
	_places[s]="---"
	for entry in _records.get(s,[]):
		if int(entry.id)==record_id(s):
			_info[s]=entry.summary
			_places[s]=entry.place
			break

func _select_starter(index: int) -> void:
	cursor=posmod(index,SaveData.STARTERS.size())

func _select_record(index: int) -> void:
	last_records[starter()]=posmod(index,SaveData.RECORD_LIMIT)+1
	_sync_summary(starter())
	if menu_open:_open_menu()

func _record_index() -> int:
	return record_id()-1

func _slot_taken(s: String = "") -> bool:
	var who := starter() if s=="" else s
	var entries: Array = _records.get(who,[])
	var index := record_id(who)-1
	return index>=0 and index<entries.size() and bool(entries[index].exists)

func origin() -> Vector2:
	var vs := get_viewport_rect().size
	return ((vs - LAYOUT) / 2.0).floor()

func starter() -> String:
	return SaveData.STARTERS[cursor]

func _has_save(s: String) -> bool:
	var d: Dictionary = _info.get(s, {})
	return not d.is_empty() and int(d.get("level",0))>0 and SpeciesDB.has_species(String(d.get("species","")))

# 그 칸에 보여 줄 포켓몬(진화했으면 진화한 모습).
func _shown_species(s: String) -> String:
	var d: Dictionary = _info.get(s, {})
	var sp := String(d.get("species", ""))
	return sp if _has_save(s) and SpeciesDB.has_species(sp) else s

func _slot_rect(i: int) -> Rect2:
	if is_instance_valid(stage) and stage.actors.size()>i and stage.actors[i].texture!=null:
		var bounds := stage.icon_bounds_uv(i)
		return Rect2(origin()+STAGE.position+bounds.position*STAGE.size,bounds.size*STAGE.size).grow(5)
	return Rect2(origin()+SLOT0+Vector2(SLOT*i,0),Vector2(SLOT,106))

func _process(dt: float) -> void:
	t += dt
	if is_instance_valid(stage):
		var ids: Array[String] = []
		var shinies: Array[bool] = []
		for s in SaveData.STARTERS:
			ids.append(_shown_species(s))
			shinies.append(_is_shiny(s))
		stage.show_slots(ids,shinies,cursor,t)
	queue_redraw()

# ── 입력 ──

func _unhandled_input(event: InputEvent) -> void:
	if launching:return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.physical_keycode
	if menu_open:
		match k:
			KEY_UP, KEY_W:
				menu_cursor = posmod(menu_cursor - 1, menu_items.size())
				Sfx.play("select")
			KEY_DOWN, KEY_S:
				menu_cursor = posmod(menu_cursor + 1, menu_items.size())
				Sfx.play("select")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				Sfx.play("decide")
				_choose(menu_items[menu_cursor]["key"])
			KEY_ESCAPE, KEY_B:
				Sfx.play("select")
				_close_menu()
		return
	match k:
		KEY_LEFT, KEY_A:
			_select_starter(cursor-1)
			Sfx.play("select")
		KEY_RIGHT, KEY_D:
			_select_starter(cursor+1)
			Sfx.play("select")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			Sfx.play("decide")
			_open_menu()
		KEY_UP, KEY_W:
			_select_record(posmod(_record_index()-1,SaveData.RECORD_LIMIT))
			Sfx.play("select")
		KEY_DOWN, KEY_S:
			_select_record(posmod(_record_index()+1,SaveData.RECORD_LIMIT))
			Sfx.play("select")
		KEY_L:
			Lang.toggle()             # 게임 안 L 키와 같다(저장됨)

func _gui_input(event: InputEvent) -> void:
	if launching:return
	if event is InputEventMouseMotion:
		if menu_open:
			var i := _menu_hit(event.position)
			if i>=0:menu_cursor=i
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index!=MOUSE_BUTTON_LEFT:return
		# Save slots stay selectable while the action/confirmation menu is open.
		var entries: Array = _records[starter()]
		for i in entries.size():
			if _record_rect(i).has_point(event.position):
				_select_record(i)
				if not menu_open:_open_menu()
				Sfx.play("decide")
				return
		if menu_open:
			var i := _menu_hit(event.position)
			if i>=0:
				menu_cursor=i
				Sfx.play("decide")
				_choose(menu_items[i]["key"])
			elif not _menu_rect().has_point(event.position):_close_menu()
			return
		for i in SaveData.STARTERS.size():
			if _slot_rect(i).has_point(event.position):
				_select_starter(i)
				Sfx.play("select")
				return

func _menu_hit(p: Vector2) -> int:
	for i in menu_items.size():
		if _menu_row(i).has_point(p):
			return i
	return -1

func _menu_rect() -> Rect2:
	var o := origin()
	var h := 16.0 + 16.0 * menu_items.size()
	return Rect2(o.x + MENU_X, o.y + SCREEN.y - h - 2.0, MENU_W, h)

func _menu_row(i: int) -> Rect2:
	var r := _menu_rect()
	return Rect2(r.position + Vector2(8, 8 + 16 * i), Vector2(r.size.x - 16, 16))

# ── 메뉴 ──

func _open_menu() -> void:
	menu_open = true
	confirm = false
	menu_cursor = 0
	menu_items=[]
	if not _slot_taken() or _has_save(starter()):
		menu_items.append({"key":"start","label":Lang.t("title_continue" if _has_save(starter()) else "title_new")})
	if _slot_taken():
		menu_items.append({"key":"reset","label":Lang.t("title_delete_record")})
	menu_items.append({"key": "cancel", "label": Lang.t("title_cancel")})

func _close_menu() -> void:
	menu_open = false
	confirm = false

func _choose(key: String) -> void:
	if launching:return
	match key:
		"start":
			start_game(starter())
		"reset":
			confirm = true
			menu_cursor = 1
			menu_items = [{"key": "reset_yes", "label": Lang.t("title_yes")}, {"key": "cancel", "label": Lang.t("title_no")}]
		"reset_yes":
			SaveData.reset_slot(starter(),record_id())
			_refresh()
			_close_menu()
		"cancel":
			_close_menu()

# 고른 스타팅의 세이브로 게임을 연다. 같은 실행 안에서 저장·자리·반짝임 기록을 새로 시작한다.
func start_game(s: String) -> void:
	if launching:return
	var chosen := record_id(s)
	var previous_path := SaveData.path
	if not SaveData.use_slot(s,chosen):return
	launching=true
	var transition := GameTransition.new()
	transition.name="TitleGameTransition"
	get_tree().root.add_child(transition)
	transition.failed.connect(func(_error: int) -> void:
		launching=false
		SaveData.path=previous_path
	)
	transition.begin(MAIN_SCENE,func() -> void:
		# The game script is already cached by the threaded scene resource load.
		var g = load("res://scripts/game.gd")
		g.starter=s
		g.destination={}
		g.came_from_faint=false
		last=s
		last_records[s]=chosen
	,String(_info.get(s,{}).get("species",s)))

# ── 그리기 ──

func _draw() -> void:
	var o := origin()
	var vs := get_viewport_rect().size
	var bg := PixelUi.ui_tex("plat/box_bg")
	# 화면 밖은 박스 바탕(바탕색 + 8px 줄무늬)으로 채운다 — 줄무늬 칸은 원본 오른쪽 아래(248,184) 8×8.
	if bg != null:
		var base := bg.get_image().get_pixel(250, 186)
		draw_rect(Rect2(Vector2.ZERO, vs), base)
		var cell := Rect2(248, 184, 8, 8)
		var start := Vector2(fposmod(o.x, 8.0) - 8.0, fposmod(o.y, 8.0) - 8.0)
		var y := start.y
		while y < vs.y:
			var x := start.x
			while x < vs.x:
				draw_texture_rect_region(bg, Rect2(x, y, 8, 8), cell)
				x += 8.0
			y += 8.0
		draw_texture(bg, o)
		# Remove the old flat wallpaper frame; the stage draws the entire tilted box.
		for yy in range(0,160,8):
			for xx in range(88,256,8):
				draw_texture_rect_region(bg,Rect2(o+Vector2(xx,yy),Vector2(8,8)),cell)
	if is_instance_valid(stage):
		draw_texture_rect(stage.get_texture(),Rect2(o+STAGE.position,STAGE.size),false)
	_draw_records(o)
	# 손 커서: 고른 칸 위에서 위아래로 살짝(원작 커서처럼). 손 그림자는 그리지 않는다 — 아이콘 발밑에 깔려 포켓몬이 떠 보였다(사용자 지적 2026-10-30).
	var hand := PixelUi.ui_tex("plat/box_hand")
	if hand != null and not menu_open:
		var r := _slot_rect(cursor)
		var bob := floorf(2.0 * absf(sin(t * 4.0)))
		var at := r.position+Vector2(10,-6-bob)
		if is_instance_valid(stage) and stage.actors.size()>cursor:
			at=(o+STAGE.position+stage.head_uv(cursor)*STAGE.size-Vector2(16,28+bob)).floor()
		draw_texture_rect_region(hand,Rect2(at,Vector2(32,32)),Rect2(0,0,32,32))
	_draw_preview(o)
	if menu_open:
		_draw_menu(o)


func _preview_texture(s: String) -> Texture2D:
	return PixelUi.ui_tex("plat/front/"+_shown_species(s)+("_shiny" if _is_shiny(s) else ""))

func _draw_preview(o: Vector2) -> void:
	var s := starter()
	var sp := _shown_species(s)
	var d: Dictionary = _info.get(s, {})
	var shiny := _is_shiny(s)
	var front := _preview_texture(s)
	if front!=null:
		draw_texture(front,o+PREVIEW-Vector2(40,40))
	PixelUi.text(self, o + NAME_BOX.position + Vector2(4, 1), Lang.species_name(sp), false, PixelUi.INK, PixelUi.INK_SHADOW)
	var lv := int(d.get("level", START_LEVEL)) if _has_save(s) else START_LEVEL
	PixelUi.text(self, o + Vector2(8, 128), "Lv%d" % lv, false, Color.WHITE, Color(0, 0, 0, 0.5))
	if shiny:
		PixelUi.blit_rect(self, "plat/sum_shiny", Rect2(o + Vector2(74, 44), Vector2(8, 8)))

func _draw_menu(o: Vector2) -> void:
	var r := _menu_rect()
	if not PixelUi.nine(self, "plat/sys_window", r, 8):
		draw_rect(r, PixelUi.PAPER)
	if confirm:
		var q := Rect2(o + Vector2(4, r.position.y - o.y - 36), Vector2(SCREEN.x - 8, 34))
		if not PixelUi.nine(self, "plat/msgbox", q, 10):
			draw_rect(q, PixelUi.PAPER)
		PixelUi.paragraph(self, q.position + Vector2(10, 1), Lang.t("title_reset_record_q",[record_id(),Lang.species_name(_shown_species(starter()))]), q.size.x - 20, 2, PixelUi.INK, PixelUi.INK_SHADOW)
	for i in menu_items.size():
		var row := _menu_row(i)
		if i == menu_cursor:
			# 원작 메뉴 화살표(▶) 자리 — 빨간 삼각형.
			var a := row.position + Vector2(2, 4)
			draw_colored_polygon(PackedVector2Array([a, a + Vector2(5, 4), a + Vector2(0, 8)]), Color("e04040"))
		PixelUi.text(self, row.position + Vector2(12, 0), menu_items[i]["label"], false, PixelUi.INK, PixelUi.INK_SHADOW)

# 저장된 자리의 이름: 바깥 세계면 그 칸이 속한 구역(1번도로·회색시티…), 건물이면 장소 이름.
func _place_name(map_id: String, pos: Vector2, layout: int=1) -> String:
	if map_id == "" or not DungeonDB.has_location(map_id):
		return "---"
	if DungeonDB.Johto.has(map_id): return DungeonDB.Johto.title_at(map_id,pos)
	if map_id=="kanto_world" and pos.x<0.0 and pos!=Vector2(-1,-1):
		return preload("res://scripts/data/continent_world.gd").title_at(pos)
	var keep := DungeonDB.current
	DungeonDB.set_current(map_id)
	var n := DungeonDB.display_name()
	var theme: Dictionary = DungeonDB.theme()
	if DungeonDB.is_overworld() and theme.has("map") and pos.x >= 0.0:
		# Match Game's arrival migration when previewing a save from an older map layout.
		var shifts: Dictionary=DungeonDB.LAYOUT_SHIFT.get(map_id,{})
		while layout<int(DungeonDB.LAYOUTS.get(map_id,1)):
			pos+=Vector2(shifts.get(layout,Vector2i.ZERO))*Arena.TILE
			layout+=1
		var j = JSON.parse_string(FileAccess.get_file_as_string(String(theme["map"]) + "/map.json"))
		if j is Dictionary:
			var tile := Vector2i(floori(pos.x / Arena.TILE), floori(pos.y / Arena.TILE))
			for a in j.get("areas", []):
				if Rect2i(int(a["x"]), int(a["y"]), int(a["w"]), int(a["h"])).has_point(tile):
					n = DungeonDB.area_name(String(a["id"]))
	DungeonDB.set_current(keep)
	return n

# 칸 세이브의 트레이너 ID·비밀 ID(이로치 판정용). 없으면 [0, 0].
func _trainer_of(s: String) -> Array:
	var cf := ConfigFile.new()
	if cf.load(SaveData.slot_path(s,maxi(1,record_id(s)))) != OK:
		return [0, 0]
	return [int(cf.get_value("trainer", "tid", 0)), int(cf.get_value("trainer", "sid", 0))]


func _is_shiny(s: String) -> bool:
	var d: Dictionary = _info.get(s,{})
	if not _has_save(s) or int(d.get("pid",-1))<0:return false
	# Cache the IDs with the save summary; do not read files every animation frame.
	if not d.has("trainer_ids"):d["trainer_ids"]=_trainer_of(s)
	var tr: Array = d["trainer_ids"]
	return Individual.shiny_value(int(d.pid),tr[0],tr[1])<Individual.SHINY_THRESHOLD

func _record_rect(i: int) -> Rect2:
	return Rect2(origin()+RECORDS.position+Vector2(4,44+i*28),Vector2(112,26))

func _draw_records(o: Vector2) -> void:
	var panel := Rect2(o+RECORDS.position,RECORDS.size)
	PixelUi.nine(self,"plat/sys_window",panel,8)
	PixelUi.text(self,panel.position+Vector2(12,8),Lang.t("title_records"))
	_draw_fitted(panel.position+Vector2(12,26),Lang.species_name(starter()),72)
	var entries: Array = _records[starter()]
	var used := 0
	for entry in entries:
		if entry.exists:used+=1
	PixelUi.text(self,panel.position+Vector2(108,27),"%d/5"%used,true,PixelUi.INK_DIM,PixelUi.INK_SHADOW,HORIZONTAL_ALIGNMENT_RIGHT)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var r := _record_rect(i)
		if int(entry.id)==record_id():
			draw_rect(r,Color("d9e9df"))
			draw_rect(Rect2(r.position,Vector2(3,r.size.y)),Color("ba543c"))
		var d: Dictionary = entry.summary
		PixelUi.text(self,r.position+Vector2(8,0),Lang.t("title_slot_number",[entry.id]),true)
		if not entry.exists:
			PixelUi.text(self,r.position+Vector2(8,13),Lang.t("title_empty_slot"),true,PixelUi.INK_DIM)
		elif int(d.get("level",0))>0 and SpeciesDB.has_species(String(d.get("species",""))):
			PixelUi.text(self,r.position+Vector2(106,0),"Lv%d"%int(d.level),true,PixelUi.INK,PixelUi.INK_SHADOW,HORIZONTAL_ALIGNMENT_RIGHT)
			_draw_fitted(r.position+Vector2(8,13),Lang.species_name(String(d.species))+" · "+String(entry.place),98)
		else:
			_draw_fitted(r.position+Vector2(8,13),Lang.t("title_record_unreadable"),98)
		if i<entries.size()-1:draw_line(r.position+Vector2(6,27),r.position+Vector2(106,27),Color("c5cbc7"))

func _draw_fitted(at: Vector2, value: String, width: float) -> void:
	var font := UiFont.small()
	var fitted := value
	while fitted.length()>0 and font.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,UiFont.SMALL_SIZE).x>width:
		fitted=fitted.left(fitted.length()-1)
	if fitted!=value:fitted=fitted.left(maxi(0,fitted.length()-1))+"…"
	PixelUi.text(self,at,fitted,true)
