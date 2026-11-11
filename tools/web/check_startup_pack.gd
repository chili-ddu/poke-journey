extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var intro_only := args.has("--intro")
	for pack: String in args.slice(1):
		if pack=="--intro":continue
		if not ProjectSettings.load_resource_pack(pack):quit(1);return
	var failures: Array[String]=[]
	var sheets: Dictionary={}
	var checked: Array=[1,4,7] if intro_only else plan.startup_dex
	if intro_only and not ResourceLoader.exists("res://assets/maps/arena_viridian_forest/bottom.png"):
		failures.append("intro arena floor")
	if intro_only:
		for path: String in ["res://assets/maps/hgss_render/arena_viridian_forest/hd2d_floor.png","res://assets/maps/hgss_render/arena_viridian_forest/hd2d_atlas.png","res://assets/maps/hgss_pallet_sample/models/terrain_0201_018/tree01gs.png"]:
			if not FileAccess.file_exists(path):failures.append(path)
	for dex: int in checked:
		for suffix: String in ["/AnimData.xml","/shiny/AnimData.xml"]:
			var path := "res://assets/sprites/%04d"%dex+suffix
			if not FileAccess.file_exists(path):failures.append(path)
		var path := "res://assets/motion_2x/%04d.json"%dex
		if not FileAccess.file_exists(path):failures.append(path);continue
		var entries: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for source: String in entries:
			if not ResourceLoader.exists(source):failures.append(source)
			sheets[String(entries[source].sheet)]=true
	for sheet: String in sheets:
		if not ResourceLoader.exists(sheet):failures.append(sheet)
	print(JSON.stringify({"startup_species_checked":checked.size(),"intro_only":intro_only,"startup_sheets_checked":sheets.size(),"failures":failures.slice(0,20),"failure_count":failures.size()}))
	quit(0 if failures.is_empty() else 1)
