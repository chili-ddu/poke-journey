extends SceneTree
const OUT := "res://docs/title_review/"
func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	ViewScale.window_ready=true
	SaveData.slot_pattern="user://wallpaper_review_%s.cfg"
	SaveData.allow_migrate=false
	TitleScreen.last_records={}
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	for i in 3:
		title._select_starter(i)
		for frame in 15:await process_frame
		await RenderingServer.frame_post_draw
		var kind: String = SpeciesDB.get_species(title.starter()).types[0]
		root.get_texture().get_image().save_png(OUT+"wallpaper_"+kind+".png")
		assert(title.stage.wallpaper_index==[0,5,9][i])
	print("Native Forest/Volcano/Seafloor wallpapers and headers captured")
	quit()
