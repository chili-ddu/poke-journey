extends SceneTree
const OUT := "res://docs/title_review/"
func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ViewScale.window_ready=true
	SaveData.slot_pattern="user://multi_save_review_%s.cfg"
	SaveData.allow_migrate=false
	TitleScreen.last="charmander"
	TitleScreen.last_records={}
	for s in SaveData.STARTERS:
		for id in SaveData.record_ids(s):SaveData.reset_slot(s,id)
	OS.set_environment("BOT","")
	OS.set_environment("DUNGEON","")
	for id in range(1,5):
		var cf := ConfigFile.new()
		cf.set_value("mon","species","charizard" if id==2 else "charmeleon")
		cf.set_value("mon","level",36 if id==2 else 15+id)
		cf.set_value("where","map","kanto_north")
		cf.set_value("where","layout",DungeonDB.LAYOUTS.get("kanto_north",1))
		cf.set_value("where","x",190.5*Arena.TILE)
		cf.set_value("where","y",22.5*Arena.TILE)
		cf.save(SaveData.slot_path("charmander",id))
	var original := FileAccess.get_file_as_bytes(SaveData.slot_path("charmander",1))
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene=title
	await capture("multiple_records")
	var event := InputEventMouseButton.new()
	event.position=title._record_rect(1).get_center()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	title._gui_input(event)
	assert(title.record_id()==2 and title.menu_open)
	await capture("record2_continue")
	title._choose("start")
	for i in 30:await process_frame
	var game: Node = current_scene
	game.set_process(false)
	assert(game.world.player.species_id=="charizard" and game.world.player.level==36)
	assert(SaveData.path==SaveData.slot_path("charmander",2))
	assert(not ViewScale.title_view)
	game._save_and_title()
	await returned(game)
	title=current_scene
	assert(title.record_id()==2)
	assert(FileAccess.get_file_as_bytes(SaveData.slot_path("charmander",1))==original,"Continue/save never touches record 1")
	title._select_record(4)
	assert(title.record_id()==5 and not title._slot_taken() and SaveData.next_record_id("charmander")==5)
	title._open_menu()
	await capture("new_record")
	title._choose("start")
	for i in 30:await process_frame
	game=current_scene
	game.set_process(false)
	assert(SaveData.path==SaveData.slot_path("charmander",5))
	assert(game.world.player.species_id=="charmander" and game.world.player.level==5,"New record has fresh starter growth")
	game._save_and_title()
	await returned(game)
	title=current_scene
	assert(title.record_id()==5 and title._has_save("charmander"))
	assert(SaveData.record_ids("charmander")==[1,2,3,4,5])
	assert(SaveData.next_record_id("charmander")==0,"No sixth save after filling all slots")
	assert(SaveData.peek("charmander",2).level==36)
	assert(FileAccess.get_file_as_bytes(SaveData.slot_path("charmander",1))==original,"New/save never overwrites original")
	await capture("record5_saved")
	for s in SaveData.STARTERS:
		for id in SaveData.record_ids(s):SaveData.reset_slot(s,id)
	FileAccess.open(OUT+"multi_save_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"continue_record":2,"continued_species":"charizard","continued_level":36,"created_record":5,"fresh_starter":true,"original_unchanged":true,"remembered_record_on_return":true},"  "))
	print("Multiple saves: continue record 2, create record 5, return and preserve record 1 passed")
	quit()
func returned(game: Node) -> void:
	for i in 90:
		await create_timer(0.01).timeout
		if current_scene!=game:break
	assert(current_scene is TitleScreen,"Return to title completes")
func capture(label: String) -> void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
