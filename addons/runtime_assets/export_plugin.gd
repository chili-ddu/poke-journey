@tool
extends EditorExportPlugin

const RuntimeFiles = preload("res://addons/runtime_assets/runtime_files.gd")
var legacy: Dictionary = {}

func _get_name() -> String:
	return "PokeJourneyRuntimeAssets"

func _export_begin(features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	legacy = RuntimeFiles.legacy_sheets() if features.has("web") else {}
	var files := RuntimeFiles.collect().keys()
	files.sort()
	var records: Array = []
	for path: String in files:
		var data := FileAccess.get_file_as_bytes(path)
		add_file(path, data, false)
		records.append({"path":path, "bytes":data.size(), "sha256":FileAccess.get_sha256(path)})
	var manifest := {"format":1, "files":records, "excluded_legacy_sheets":legacy.size()}
	add_file("res://assets/data/export_runtime_files.json", JSON.stringify(manifest).to_utf8_buffer(), false)
	print("Runtime export: %d raw assets; %d unused legacy sheets excluded" % [records.size(), legacy.size()])

func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
	if features.has("web") and (legacy.has(path) or path.ends_with("/preview.png")):
		skip()
