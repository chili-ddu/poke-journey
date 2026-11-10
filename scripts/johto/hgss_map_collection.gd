class_name HgssMapCollection
extends RefCounted

## Read-only original HGSS map data. Independent of DungeonDB and SaveData.
const BASE := "res://assets/maps/johto_hgss/"
var manifest: Dictionary
var _scenes: Dictionary = {}
var base_dir := BASE

func _init(directory: String = BASE) -> void:
	base_dir = directory
	manifest = JSON.parse_string(FileAccess.get_file_as_string(base_dir + "manifest.json"))

func scene_for(header: int) -> String:
	return String(manifest.header_scene.get(str(header), ""))

func scene_data(id: String) -> Dictionary:
	if not _scenes.has(id):
		var path: String = manifest.get("scene_paths",{}).get(id,base_dir + "scenes/" + id + ".json")
		_scenes[id] = JSON.parse_string(FileAccess.get_file_as_string(path))
		var data: Dictionary = _scenes[id]
		data["chunk_index"] = {}
		data["portal_index"] = {}
		for chunk in data.chunks:
			data.chunk_index[Vector2i(int(chunk.x), int(chunk.z))] = chunk
		for warp in data.warps:
			var tile := Vector2i(int(warp.x), int(warp.z))
			# Original scripts choose variants at four shared entrance positions.
			# Explorer uses the first in-scope native variant; F1 exposes the rest.
			var existing: Dictionary = data.portal_index.get(tile, {})
			if existing.is_empty() or (String(existing.to).is_empty() and not String(warp.to).is_empty()):
				data.portal_index[tile] = warp
	return _scenes[id]

func attributes(scene: Dictionary, tile: Vector2i) -> int:
	if tile.x < 0 or tile.y < 0: return 32768
	var cell := Vector2i(tile.x / 32, tile.y / 32)
	var chunk: Dictionary = scene.chunk_index.get(cell, {})
	if not chunk.is_empty(): return int(chunk.attributes[(tile.y % 32) * 32 + tile.x % 32])
	return 32768

func can_stand(scene: Dictionary, tile: Vector2i, surf: bool = false) -> bool:
	var door := portal(scene, tile)
	if not door.is_empty() and not String(door.to).is_empty(): return true
	var value := attributes(scene, tile)
	var behavior := value & 255
	var water := behavior in [16, 17, 18, 19, 20, 21, 25, 42]
	if water: return surf and (value & 32768) == 0
	return (value & 32768) == 0

func header_at(scene: Dictionary, tile: Vector2i) -> int:
	for area in scene.areas:
		if Rect2i(int(area.x), int(area.z), int(area.width), int(area.height)).has_point(tile):
			return int(area.header)
	return 0

func portal(scene: Dictionary, tile: Vector2i) -> Dictionary:
	return scene.portal_index.get(tile, {})

func arrival(header: int, index: int) -> Dictionary:
	var id := scene_for(header)
	if id.is_empty(): return {}
	for warp in scene_data(id).warps:
		if int(warp.header) == header and int(warp.index) == index: return warp
	return {}

func spawn(header: int) -> Vector2:
	var scene := scene_data(scene_for(header))
	# Prefer a real entrance with an adjacent free tile, otherwise a walkable tile.
	for warp in scene.warps:
		if int(warp.header) != header: continue
		var at := Vector2i(int(warp.x), int(warp.z))
		for step in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			if can_stand(scene, at + step): return Vector2(at + step) + Vector2(0.5, 0.5)
	for area in scene.areas:
		if int(area.header) != header: continue
		for z in range(int(area.z), int(area.z + area.height)):
			for x in range(int(area.x), int(area.x + area.width)):
				if can_stand(scene, Vector2i(x, z)): return Vector2(x + 0.5, z + 0.5)
	return Vector2.INF

func title(header: int) -> String:
	var data: Dictionary = manifest.headers.get(str(header), {})
	return String(data.get("name_ko", data.get("constant", "HGSS"))).trim_prefix("MAP_").replace("_", " ")
