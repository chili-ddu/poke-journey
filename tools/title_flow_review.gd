extends SceneTree
const OUT := "res://docs/title_review/"
func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ViewScale.window_ready=true
	SaveData.slot_pattern="user://title_flow_review_%s.cfg"
	SaveData.allow_migrate=false
	for s in SaveData.STARTERS:SaveData.reset_slot(s)
	OS.set_environment("BOT","")
	OS.set_environment("DUNGEON","")
	var cf := ConfigFile.new()
	cf.set_value("mon","species","charmeleon")
	cf.set_value("mon","level",17)
	cf.set_value("where","map","kanto_north")
	cf.set_value("where","layout",DungeonDB.LAYOUTS.get("kanto_north",1))
	cf.set_value("where","x",190.5*Arena.TILE)
	cf.set_value("where","y",22.5*Arena.TILE)
	cf.save(SaveData.slot_path("charmander"))
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene=title
	await capture("records")
	# Click the new right-hand list, then use the same Continue command as the menu.
	var event := InputEventMouseButton.new()
	event.position=title._record_rect(0).get_center()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	title._gui_input(event)
	assert(title.starter()=="charmander" and title.menu_open)
	await capture("continue_menu")
	var old_stage: WeakRef = weakref(title.stage)
	title._choose("start")
	for i in 30:await process_frame
	var game: Node = current_scene
	game.set_process(false)
	assert(game.world.player.species_id=="charmeleon" and game.world.player.level==17,"Continue restores saved evolved Pokemon")
	assert(DungeonDB.current=="kanto_north","Continue restores saved location")
	assert(SaveData.path==SaveData.slot_path("charmander"))
	assert(not ViewScale.title_view,"Gameplay restores its own viewport scaling")
	assert(old_stage.get_ref()==null,"Title viewport is released when gameplay starts")
	await capture("loaded_game")
	game._save_and_title()
	for i in 90:
		await create_timer(0.01).timeout
		if current_scene!=game:break
	assert(current_scene is TitleScreen,"Return to title completes")
	title=current_scene
	assert(title.starter()=="charmander" and title._has_save("charmander"))
	await capture("returned_records")
	for s in SaveData.STARTERS:SaveData.reset_slot(s)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"list_click":true,"saved_species":"charmeleon","level":17,"location":"kanto_north","stage_released":true,"game_scaling_restored":true,"return_to_title":true},"  "))
	print("Title list -> Continue -> saved game -> title: passed")
	quit()
func capture(label: String) -> void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
