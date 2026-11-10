extends SceneTree
const OUT := "res://docs/title_record_menu_review/"
var title: TitleScreen
func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	ViewScale.window_ready=true
	SaveData.slot_pattern="user://title_record_menu_review_%s.cfg"
	SaveData.allow_migrate=false
	TitleScreen.last="charmander"
	TitleScreen.last_records={}
	for s in SaveData.STARTERS:
		for id in range(1,6):SaveData.reset_slot(s,id)
	var cf := ConfigFile.new()
	cf.set_value("mon","species","charmeleon");cf.set_value("mon","level",17)
	cf.set_value("where","map","kanto_north")
	cf.save(SaveData.slot_path("charmander",1))
	var original := FileAccess.get_file_as_bytes(SaveData.slot_path("charmander",1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	title=load("res://scenes/title.tscn").instantiate();root.add_child(title)
	await shot("initial_no_hint")
	title.set_process(false)
	var point := title._slot_rect(2).get_center()
	var motion := InputEventMouseMotion.new();motion.position=point
	title._gui_input(motion)
	assert(title.starter()=="charmander","Hover must not select another Pokemon")
	var press := InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=point
	title._gui_input(press)
	assert(title.starter()=="squirtle","Click selects the Pokemon")
	press.position=title._slot_rect(1).get_center();title._gui_input(press)
	assert(title.starter()=="charmander")
	title.set_process(true)
	click(0)
	assert(title.menu_items[0].label==Lang.t("title_continue"))
	await shot("slot1_continue")
	click(1)
	assert(title.menu_open and title.record_id()==2 and title.menu_items[0].label==Lang.t("title_new"))
	await shot("slot2_new")
	click(0)
	assert(title.menu_items[0].label==Lang.t("title_continue"))
	title._choose("reset")
	assert(title.confirm)
	click(2)
	assert(not title.confirm and title.record_id()==3 and title.menu_items[0].label==Lang.t("title_new"))
	await shot("slot3_cancels_confirmation")
	assert(FileAccess.get_file_as_bytes(SaveData.slot_path("charmander",1))==original)
	assert(not SaveData.slot_exists("charmander",2) and not SaveData.slot_exists("charmander",3))
	for s in SaveData.STARTERS:
		for id in range(1,6):SaveData.reset_slot(s,id)
	print("TITLE RECORD MENU REVIEW PASSED: hint removed, live slot switch, confirmation cancelled, saves preserved")
	quit()
func click(index: int) -> void:
	var e := InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	e.position=title._record_rect(index).get_center();title._gui_input(e)
func shot(label: String) -> void:
	title.queue_redraw()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
