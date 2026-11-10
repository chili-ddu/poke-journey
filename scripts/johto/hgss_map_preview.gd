extends Node3D

## Isolated map explorer: no battles, progress flags, user saves or global cursor.
const Collection = preload("res://scripts/johto/hgss_map_collection.gd")
var collection := Collection.new()
var data: Dictionary
var scene_id := ""
var header := 60
var position_2d := Vector2.ZERO
var ground_y := 1.0
var surf := false
var automatic_portals := true
var portal_latch := Vector2i(-1, -1)
var loaded_chunks: Dictionary = {}
var model_cache: Dictionary = {}
var camera: Camera3D
var actor: Sprite3D
var info: Label
var status: Label
var picker: Window
var map_list: ItemList
var filter: LineEdit
var header_list: Array[int] = []
var _sheet: Dictionary
var _clock := 0.0
var last_message := ""

func _ready() -> void:
	_build_camera()
	_build_actor()
	_build_ui()
	var requested := OS.get_environment("HGSS_HEADER")
	visit(int(requested) if requested.is_valid_int() else 60)

func _build_camera() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202d32")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 1.0
	env.environment = settings
	add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.near = 0.05
	camera.far = 160.0
	add_child(camera)
	camera.current = true

func _build_actor() -> void:
	actor = Sprite3D.new()
	actor.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	actor.pixel_size = 1.0 / 24.0
	actor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	actor.shaded = false
	actor.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sheet = MonSprite.load_set(4)
	add_child(actor)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var font := load("res://assets/fonts/Galmuri11.ttf") as Font
	info = Label.new()
	info.position = Vector2(6, 4)
	info.size = Vector2(372, 34)
	info.add_theme_color_override("font_color", Color.WHITE)
	info.add_theme_font_override("font", font)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_shadow_color", Color.BLACK)
	info.add_theme_constant_override("shadow_offset_x", 1)
	info.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(info)
	status = Label.new()
	status.position = Vector2(6, 180)
	status.size = Vector2(372, 30)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_font_override("font", font)
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 1)
	status.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(status)
	picker = Window.new()
	picker.title = "HGSS 맵 목록"
	picker.size = Vector2i(364, 196)
	picker.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	picker.transient = true
	picker.exclusive = true
	# Embedded popup stays within the fixed 384×216 review viewport.
	get_viewport().gui_embed_subwindows = true
	add_child(picker)
	picker.hide()
	picker.close_requested.connect(picker.hide)
	picker.window_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: picker.hide())
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.add_child(box)
	filter = LineEdit.new()
	filter.placeholder_text = "지역 이름 / MAP ID 검색"
	filter.add_theme_font_override("font", font)
	filter.add_theme_font_size_override("font_size", 16)
	box.add_child(filter)
	map_list = ItemList.new()
	map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_list.add_theme_font_override("font", font)
	map_list.add_theme_font_size_override("font_size", 16)
	box.add_child(map_list)
	filter.text_changed.connect(_fill_list)
	map_list.item_activated.connect(func(index: int) -> void:
		visit(header_list[index])
		picker.hide())
	_fill_list("")

func _fill_list(query: String) -> void:
	map_list.clear()
	header_list.clear()
	for key in collection.manifest.headers:
		var id := int(key)
		var text := "%03d  %s" % [id, collection.title(id)]
		var original: String = collection.manifest.headers[key].constant
		if not query.is_empty() and not (text + original).to_lower().contains(query.to_lower()): continue
		header_list.append(id)
		map_list.add_item(text)

func visit(target_header: int, arrival: Dictionary = {}) -> void:
	var target_scene := collection.scene_for(target_header)
	if target_scene.is_empty(): return
	if target_scene != scene_id:
		for chunk in loaded_chunks.values(): chunk.free()
		loaded_chunks.clear()
		model_cache.clear()
		scene_id = target_scene
		data = collection.scene_data(scene_id)
	header = target_header
	position_2d = Vector2(float(arrival.x) + 0.5, float(arrival.z) + 0.5) if not arrival.is_empty() else collection.spawn(header)
	if not position_2d.is_finite():
		last_message = "통행 가능한 시작점 없음: 지형 목록에서 다른 맵 선택"
		position_2d = Vector2(16, 16)
	portal_latch = Vector2i(position_2d.floor())
	_stream_chunks()
	_update_ui()

func _load_model(key: String) -> PackedScene:
	if model_cache.has(key): return model_cache[key]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(collection.manifest.assets[key], state)
	assert(error == OK, "HGSS model could not be read: " + key)
	var instance := document.generate_scene(state)
	_prepare_materials(instance)
	var packed := PackedScene.new()
	packed.pack(instance)
	instance.free()
	model_cache[key] = packed
	return packed

func _prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is BaseMaterial3D:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.get_children(): _prepare_materials(child)

func _add_floor_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		body.add_child(shape)
		node.add_child(body)
	for child in node.get_children():
		if child is not StaticBody3D: _add_floor_collision(child)

func _stream_chunks() -> void:
	if data.is_empty(): return
	var center := Vector2i(position_2d / 32.0)
	var keep: Dictionary = {}
	for chunk in data.chunks:
		var cell := Vector2i(int(chunk.x), int(chunk.z))
		if absi(cell.x - center.x) > 1 or absi(cell.y - center.y) > 1: continue
		var key := "%d,%d" % [cell.x, cell.y]
		keep[key] = true
		if loaded_chunks.has(key): continue
		var parent := Node3D.new()
		parent.position = Vector3(cell.x * 32 + 16, float(chunk.altitude), cell.y * 32 + 16)
		add_child(parent)
		var terrain := _load_model(chunk.asset).instantiate() as Node3D
		terrain.scale = Vector3.ONE / 16.0
		parent.add_child(terrain)
		_add_floor_collision(terrain)
		for prop in chunk.props:
			var object := _load_model(prop.asset).instantiate() as Node3D
			object.position = Vector3(prop.translation[0], prop.translation[1], prop.translation[2]) / 16.0
			object.scale = Vector3(prop.scale[0], prop.scale[1], prop.scale[2]) / 16.0
			# Original ordinary props use identity rotation (map_prop_manager.c).
			parent.add_child(object)
		loaded_chunks[key] = parent
	for key in loaded_chunks.keys():
		if not keep.has(key):
			loaded_chunks[key].queue_free()
			loaded_chunks.erase(key)
	# Packed resources only survive while live chunks reference them.
	model_cache.clear()

func _process(delta: float) -> void:
	if data.is_empty(): return
	_clock += delta
	var direction := Vector2.ZERO
	if not picker.visible:
		direction = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
		move_by(direction * delta * (7.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.5))
	_stream_chunks()
	var query := PhysicsRayQueryParameters3D.create(Vector3(position_2d.x, 100, position_2d.y), Vector3(position_2d.x, -50, position_2d.y))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): ground_y = float(hit.position.y)
	actor.position = Vector3(position_2d.x, ground_y + 0.65, position_2d.y)
	var anim: Dictionary = _sheet.get("Walk" if direction != Vector2.ZERO else "Idle", {})
	if not anim.is_empty():
		actor.texture = anim.tex
		actor.region_enabled = true
		var frame := MonSprite.frame_at(anim, _clock, true)
		var row := 0
		if direction != Vector2.ZERO: row = int(posmod(roundi(direction.angle() / (PI / 4.0)) - 2, 8))
		actor.region_rect = Rect2(frame * int(anim.fw), mini(row, int(anim.rows) - 1) * int(anim.fh), int(anim.fw), int(anim.fh))
	var target := Vector3(position_2d.x, ground_y + 0.5, position_2d.y)
	_follow_camera(target)
	var tile := Vector2i(position_2d.floor())
	var current := collection.header_at(data, tile)
	if current != 0: header = current
	if tile != portal_latch:
		var warp := collection.portal(data, tile)
		if automatic_portals and not warp.is_empty(): use_portal(warp)
		else: portal_latch = Vector2i(-1, -1)
	_update_ui()

func _follow_camera(target: Vector3) -> void:
	camera.position = target + Vector3(0, 14, 16)
	camera.look_at(target)

func move_by(amount: Vector2) -> void:
	# Small substeps prevent crossing walls when a slow model load causes a long frame.
	var count := maxi(1, ceili(amount.length() / 0.15))
	for i in count:
		var step := amount / float(count)
		for axis in [Vector2(step.x, 0), Vector2(0, step.y)]:
			var next: Vector2 = position_2d + axis
			var clear := true
			for offset in [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(-0.18, 0.18), Vector2(0.18, 0.18)]:
				if not collection.can_stand(data, Vector2i((next + offset).floor()), surf): clear = false
			if clear: position_2d = next

func use_portal(warp: Dictionary) -> bool:
	portal_latch = Vector2i(int(warp.x), int(warp.z))
	var destination := collection.arrival(int(warp.to_header), int(warp.to_index))
	if destination.is_empty():
		last_message = "이 출구는 외부 지역 / 동적 이동 대상입니다. F1로 맵 선택"
		return false
	last_message = ""
	visit(int(warp.to_header), destination)
	return true

func _update_ui() -> void:
	info.text = "%s [%d]\nHGSS · 맵 탐색" % [collection.title(header).left(23), header]
	status.text = "F1 지도 · Tab 수상 %s · Shift 달리기\n%s" % ["ON" if surf else "OFF", last_message.left(32) if not last_message.is_empty() else "WASD 이동 · +/- 줌 · 문 자동 이동"]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_F1:
			picker.popup_centered(Vector2i(364, 196))
			filter.grab_focus()
		KEY_TAB:
			surf = not surf
		KEY_MINUS:
			camera.size = minf(28, camera.size + 2)
		KEY_EQUAL, KEY_PLUS:
			camera.size = maxf(6, camera.size - 2)
		KEY_ESCAPE:
			picker.hide()
