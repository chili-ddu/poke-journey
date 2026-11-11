extends SceneTree

# Run in an empty project. Classify imported files by their original source path,
# so a late-mounted pack carries both the remap and its actual texture/audio.
var files: Array[String] = []
var sources: Dictionary = {}
var motion: Dictionary = {}
var startup: Dictionary = {}
var packs: Dictionary = {}
var output := ""
var failed := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=3 or not ProjectSettings.load_resource_pack(args[0]):
		push_error("Usage: split_pack.gd -- full.pck plan.json output-directory")
		quit(1)
		return
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	for dex: int in plan.startup_dex:startup[dex]=true
	output=args[2]
	DirAccess.make_dir_recursive_absolute(output)
	_walk("res://")
	for path: String in files:
		if path.ends_with(".import"):
			var cfg := ConfigFile.new()
			if cfg.parse(FileAccess.get_file_as_string(path))!=OK:
				push_error("Invalid import: "+path);quit(1);return
			for key: String in cfg.get_section_keys("remap"):
				if key=="path" or key.begins_with("path."):
					sources[String(cfg.get_value("remap",key))]=path.trim_suffix(".import")
	for dex in range(1,494):
		var profile := "res://assets/motion_2x/%04d.json"%dex
		if not FileAccess.file_exists(profile):continue
		var entries: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profile))
		for entry: Dictionary in entries.values():motion[String(entry.sheet)]=dex
	files.sort()
	var counts: Dictionary={}
	for path: String in files:
		var group := _group(String(sources.get(path,path)))
		if not packs.has(group):
			var pack := PCKPacker.new()
			if pack.pck_start(output.path_join(group+".pck"))!=OK:
				push_error("Cannot create "+group);quit(1);return
			packs[group]=pack
			counts[group]=0
		var data := FileAccess.get_file_as_bytes(path)
		if packs[group].add_file_from_buffer(path,data)!=OK:
			push_error("Cannot pack "+path);quit(1);return
		counts[group]+=1
	for group: String in packs:
		if packs[group].flush()!=OK:failed=true
	print(JSON.stringify({"files":files.size(),"bundles":packs.size(),"boot_files":counts.get("boot",0),"world_files":counts.get("world",0)}))
	quit(1 if failed else 0)

func _group(path: String) -> String:
	var source := path.trim_suffix(".import")
	var dex := 0
	if source.begins_with("res://assets/sprites/"):
		dex=int(source.trim_prefix("res://assets/sprites/").get_slice("/",0))
	elif source.begins_with("res://assets/motion_2x/"):
		if source.ends_with(".json"):dex=int(source.get_file().get_basename())
		else:dex=int(motion.get(source,0))
	if dex in [1,4,7]:return "boot"
	if source.begins_with("res://assets/maps/arena_viridian_forest/"):return "boot"
	if source.begins_with("res://assets/maps/hgss_render/arena_viridian_forest/"):return "boot"
	if source=="res://assets/maps/hgss_pallet_sample/models/terrain_0201_018/tree01gs.png":return "boot"
	if dex>0:return "actors" if startup.has(dex) else "pokemon-%04d"%dex
	if source.begins_with("res://assets/maps/") and source.get_extension() not in ["json","xml"]:return "world"
	if source.begins_with("res://assets/audio/"):
		if source not in ["res://assets/audio/seq_title01.wav","res://assets/audio/se/select.wav","res://assets/audio/se/decide.wav"]:return "world"
	return "boot"

func _walk(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir==null:return
	dir.include_hidden=true
	for name: String in dir.get_directories():_walk(path.path_join(name))
	for name: String in dir.get_files():
		var next := path.path_join(name)
		# The empty host project and this external script are not exported content.
		if next!="res://project.godot":files.append(next)
