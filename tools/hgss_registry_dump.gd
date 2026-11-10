extends SceneTree

func _init() -> void:
	var maps: Dictionary = {}
	for id in DungeonDB.DUNGEONS:
		var cfg: Dictionary = DungeonDB.DUNGEONS[id]
		var theme: Dictionary = DungeonDB.THEMES[cfg.theme]
		if not theme.has("map"): continue
		maps[id] = {"map":theme.map,"name":cfg.get("name_ko",cfg.name),"indoor":cfg.get("indoor",false),"arena":cfg.get("arena_field",false)}
	var file := FileAccess.open("res://docs/visual_style_review/legacy_registry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"maps":maps,"warps":DungeonDB.WARP_MAPS}))
	file.close()
	quit()
