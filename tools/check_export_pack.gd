extends SceneTree

## Run from an empty project so loose source files cannot hide missing exports.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0]):
		push_error("Usage: check_export_pack.gd -- /absolute/path/index.pck")
		quit(1)
		return
	var path := "res://assets/data/export_runtime_files.json"
	if not FileAccess.file_exists(path):
		push_error("Runtime export manifest is missing")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var failures: Array[String] = []
	for entry: Dictionary in manifest.files:
		if not FileAccess.file_exists(entry.path) or FileAccess.get_sha256(entry.path) != entry.sha256:
			failures.append(entry.path)
	for required: String in ["res://assets/data/species.json", "res://assets/sprites/0004/AnimData.xml", "res://assets/maps/johto_border_hgss/manifest.json", "res://assets/maps/hgss_render/manifest.json"]:
		if not FileAccess.file_exists(required): failures.append(required)
	if not ResourceLoader.exists("res://assets/ui/plat/front/charmander.png"):
		failures.append("Starter portrait texture")
	var sheets: Dictionary = {}
	for dex in range(1, 494):
		var profile := "res://assets/motion_2x/%04d.json" % dex
		if not FileAccess.file_exists(profile):
			failures.append(profile)
			continue
		var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile))
		for entry: Dictionary in entries.values(): sheets[String(entry.sheet)] = true
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/smooth/manifest.json"))
	for source: String in catalog:
		if not source.begins_with("res://assets/sprites/"): sheets[String(catalog[source].sheet)] = true
	for sheet: String in sheets:
		if not ResourceLoader.exists(sheet): failures.append(sheet)
	print(JSON.stringify({"checked_raw_files":manifest.files.size(), "checked_animation_sheets":sheets.size(), "excluded_legacy_sheets":manifest.excluded_legacy_sheets, "failure_count":failures.size(), "failures":failures.slice(0, 20)}))
	quit(0 if failures.is_empty() else 1)
