extends SceneTree
func _init() -> void:
	var results := {}
	for path in ["res://assets/sprites/0004/Idle-Anim.png", "res://assets/sprites/0004/Walk-Anim.png", "res://assets/sprites/0004/Strike-Anim.png", "res://assets/sprites/0001/Walk-Anim.png", "res://assets/sprites/0007/Walk-Anim.png", "res://assets/npcs/prof_oak.png"]:
		var tex: Texture2D = load(path)
		for mode in [true, false]:
			Look._selout_cache.clear()
			Look.sprite_tone = mode
			var data := Look.selout_texture(tex).get_image().get_data()
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(data)
			results[path + str(mode)] = hash.finish().hex_encode()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t", true))
	quit()
