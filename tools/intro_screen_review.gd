extends SceneTree
const OUT := "res://docs/intro_screen_review/"
signal download_finished
var intro: Control
var visual := false
var issues: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(value: bool,text: String) -> void:
	if not value:issues.append(text)
func shot(name: String) -> void:
	if not visual:return
	await process_frame
	await RenderingServer.frame_post_draw
	check(DisplayServer.window_get_size()==Vector2i(384,216),"384×216 native window stays at 1×")
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	visual=DisplayServer.get_name()!="headless"
	create_timer(45).timeout.connect(func():push_error("Intro review timed out");quit(1))
	if visual:await CaptureWindow.park(self)
	ViewScale.window_ready=true
	SaveData.path="user://intro_review_private.cfg"
	SaveData.slot_pattern="user://intro_review_private_%s.cfg"
	SaveData.allow_migrate=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	intro=load("res://scenes/intro.tscn").instantiate()
	intro.prepare_override=func():
		await download_finished
		return OK
	root.add_child(intro);current_scene=intro
	await process_frame
	intro.activate()
	check(not intro.launching,"Loading input ignored")
	for frame in 150:await process_frame
	await shot("01_downloading")
	download_finished.emit()
	check(intro.phase=="ready" and intro.surface.phase=="ready","Ready prompt after download")
	await shot("02_press_start")
	for frame in 120:await process_frame
	await shot("03_live_battle")
	var world: World=intro.surface.world
	if visual:
		var camera: Camera3D=intro.surface.view.cam
		check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Intro uses normal perspective, not the arena's off-axis frustum")
		check(camera.basis.x.is_equal_approx(Vector3.RIGHT),"Intro keeps a level, centred horizontal axis")
	var casts: Dictionary=world.casts.duplicate()
	for mon: Mon in [world.player]+world.enemies:
		check(mon.max_hp==int(SpeciesDB.stats_at(mon.species_id,12,mon.ivs).hp),"Common stats")
	var event := InputEventKey.new()
	event.keycode=KEY_SPACE;event.pressed=true
	Input.parse_input_event(event)
	for frame in 20:await process_frame
	var title := MobileGameFrame.unwrap(current_scene) as TitleScreen
	check(title!=null,"Start enters Pokémon selection")
	if title!=null:
		check(not title.menu_open,"Start input does not open a selection menu")
		await shot("04_selection")
	var report := {"issues":issues,"native_window":"384x216" if visual else "headless","actual_saves_used":false,"actual_combat":true,"casts":casts,"camera":"centred perspective at 40 degrees","loading":"corner ball, no intro"}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("INTRO REVIEW: ",JSON.stringify(report))
	if current_scene!=null:current_scene.free()
	quit(0 if issues.is_empty() else 1)
