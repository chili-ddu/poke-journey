@tool
extends RefCounted

## Resolve raw FileAccess/GLTF dependencies, including .gdignore directories.
const ROOTS := [
	"res://assets/maps/hgss_render/manifest.json",
	"res://assets/maps/johto_border_hgss/manifest.json",
	"res://assets/data/continent_world.json",
	"res://assets/maps/hgss_pallet_sample/models/terrain_0201_018/tree01gs.png",
]

static func collect() -> Dictionary:
	var files: Dictionary = {}
	_xml_files("res://assets/sprites", files)
	for path: String in ROOTS: _include(path, files)
	return files

static func _xml_files(directory: String, files: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".xml"): _include(directory.path_join(name), files)
	for name: String in DirAccess.get_directories_at(directory):
		_xml_files(directory.path_join(name), files)

static func _include(path: String, files: Dictionary) -> void:
	if files.has(path): return
	if not FileAccess.file_exists(path):
		push_error("Missing raw runtime asset: " + path)
		return
	files[path] = true
	if path.ends_with(".json"):
		_references(JSON.parse_string(FileAccess.get_file_as_string(path)), files)
	elif path.ends_with(".glb"):
		_glb_dependencies(path, files)

static func _references(value: Variant, files: Dictionary) -> void:
	if value is Dictionary:
		for entry: Variant in value.values(): _references(entry, files)
	elif value is Array:
		for entry: Variant in value: _references(entry, files)
	elif value is String and value.begins_with("res://"):
		if value.get_extension() in ["json", "png", "glb", "bin"]:
			_include(value, files)

static func _glb_dependencies(path: String, files: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file.get_32() != 0x46546c67 or file.get_32() != 2:
		push_error("Invalid GLB runtime asset: " + path)
		return
	file.get_32() # Total length.
	var length := file.get_32()
	if file.get_32() != 0x4e4f534a:
		push_error("Missing GLB JSON chunk: " + path)
		return
	var data: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	for group: String in ["images", "buffers"]:
		for entry: Dictionary in data.get(group, []):
			var uri: String = entry.get("uri", "")
			if not uri.is_empty() and not uri.begins_with("data:"):
				_include(path.get_base_dir().path_join(uri.uri_decode()).simplify_path(), files)

static func legacy_sheets() -> Dictionary:
	var result: Dictionary = {}
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/smooth/manifest.json"))
	for source: String in catalog:
		if source.begins_with("res://assets/sprites/"):
			result[String(catalog[source].sheet)] = true
	return result
