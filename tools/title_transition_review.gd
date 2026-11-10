extends SceneTree
const OUT := "res://docs/title_transition_review/"
var done := false
var failed := false
func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	ViewScale.window_ready=true
	OS.set_environment("BOT","");OS.set_environment("DUNGEON","");OS.set_environment("SEED","7")
	SaveData.slot_pattern="user://title_transition_review_%s.cfg"
	SaveData.allow_migrate=false
	var args := OS.get_cmdline_user_args()
	var mode: String=args[0] if not args.is_empty() else "continue"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+mode))
	TitleScreen.last="charmander";TitleScreen.last_records={"charmander":1}
	SaveData.reset_slot("charmander",1)
	if mode=="continue":
		var cf := ConfigFile.new()
		cf.set_value("mon","species","charmeleon");cf.set_value("mon","level",17)
		cf.set_value("where","map","kanto_south")
		cf.set_value("where","x",24.5*Arena.TILE);cf.set_value("where","y",180.5*Arena.TILE)
		cf.save(SaveData.slot_path("charmander",1))
	var title: TitleScreen=load("res://scenes/title.tscn").instantiate()
	root.add_child(title);current_scene=title
	for i in 15:await process_frame
	title._open_menu()
	await shot(mode+"/title")
	var started := Time.get_ticks_msec()
	title._choose("start")
	assert(title.launching)
	var transition: CanvasLayer=root.get_node("TitleGameTransition")
	transition.finished.connect(func():done=true)
	transition.failed.connect(func(_error):failed=true)
	var covered := false
	var reveal := false
	var covered_at := 0
	var active_at := 0
	while not done and not failed:
		await process_frame
		if Time.get_ticks_msec()-started>30000:
			assert(false,"Transition deadline")
			quit(1);return
		if not is_instance_valid(transition):continue
		var alpha: float=transition.overlay.modulate.a
		if alpha>=0.999 and not covered:
			covered=true;covered_at=Time.get_ticks_msec()-started
			await shot(mode+"/loading_cover")
		if current_scene!=null and current_scene!=title and alpha>0.25 and alpha<0.75 and not reveal:
			reveal=true;active_at=Time.get_ticks_msec()-started
			assert(not current_scene.is_processing(),"Gameplay pauses beneath reveal")
			await shot(mode+"/reveal")
	assert(done and not failed)
	assert(covered and reveal,"Both transitions rendered")
	var game: Node=current_scene
	assert(game.world!=null and game.is_processing())
	game.set_process(false)
	assert(SaveData.path==SaveData.slot_path("charmander",1))
	if mode=="continue":assert(game.world.player.species_id=="charmeleon" and game.world.player.level==17)
	else:assert(game.world.player.species_id=="charmander" and game._opening_pending==false)
	await shot(mode+"/game")
	var file := FileAccess.open(OUT+mode+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":mode,"cover_ms":covered_at,"reveal_ms":active_at,"finished_ms":Time.get_ticks_msec()-started,"species":game.world.player.species_id,"level":game.world.player.level,"selected_record":1,"game_ready":true},"\t"));file.close()
	SaveData.reset_slot("charmander",1)
	print("TITLE TRANSITION REVIEW PASSED: ",mode)
	quit()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
