extends SceneTree

# 울음소리 HD-2D 네 방향: 세 음파와 공격력 하락 반응 점검.
#   godot --path . -s tools/status_condition_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node
var refraction_peak := 0

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	var direction := Vector2.RIGHT
	func aim_point(w) -> Vector2: return w.player.position + direction * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1")
	await CaptureWindow.park(self)
	OS.set_environment("DUNGEON", "kanto_south")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")
	var w = game.world
	var p: Player = w.player
	p.controller = Still.new()
	game.banner_t = 0.0
	game.dialog_text=""
	game.dialog_t=0.0
	game.stream.clear()
	p.position = Arena.tile_center(Vector2i(23, 209))
	p.facing = Vector2.RIGHT
	Lang.set_code("ko", false)
	game.wild_since = -10000.0
	game.mode = "indoor" # Disable outdoor spawning/despawning in this controlled battle fixture.
	for old in w.enemies: old.queue_free()
	w.enemies.clear()
	w.pending_spawns.clear()
	var targets: Array[Enemy] = []
	for i in 3:
		var foe := Enemy.new()
		foe.setup_enemy("caterpie", 4, w.rng)
		foe.max_hp = 99999
		foe.hp = 99999
		foe.frozen = true
		for key in foe.cds: foe.cds[key] = 9999.0
		foe.position = p.position + Vector2(40 + i * 18, 20)
		w.add_child(foe)
		w.enemies.append(foe)
		targets.append(foe)
	var report := []
	for waves in [1, 3]:
		var generated: Array = []
		var shown: Array = []
		var clock := 0.0
		var peak := 0
		var listener := func(message): generated.append({"text":message,"at":clock})
		# Capture the frame time through mutable storage for the signal callback.
		var now := [0.0]
		listener = func(message): generated.append({"text":message,"at":now[0]})
		w.status_message.connect(listener)
		for frame in 3600:
			clock = frame * DT
			now[0] = clock
			if frame % 120 == 0 and frame / 120 < waves:
				for foe in targets:
					foe.invuln_t = 0.0
					var hit: Dictionary = w.make_hit(p, "ember")
					hit["crit"] = 1.0
					hit["burn"] = 0.0
					w.apply_hit(foe, hit, p.position)
			peak = maxi(peak, game.status_messages.size() + (1 if not game.dialog_text.is_empty() else 0))
			var before: float = game.dialog_t
			var was_empty: bool = game.dialog_text.is_empty()
			game.advance(DT)
			if not game.dialog_text.is_empty() and (was_empty or before <= DT):
				var idx := shown.size()
				assert(idx < generated.size())
				assert(game.dialog_text == generated[idx]["text"], "FIFO preserved")
				shown.append({"at":clock,"seconds":game.dialog_t,"delay":clock-float(generated[idx]["at"]),"text":game.dialog_text})
			await process_frame
			if frame == 245 and waves == 3:
				root.get_texture().get_image().save_png(out+"/backlog.png")
			if frame > (waves-1)*120 and game.dialog_text.is_empty() and game.status_messages.is_empty():
				assert(shown.size() == generated.size())
				report.append({"waves":waves,"interval":2.0,"generated":generated.size(),"shown":shown.size(),"peak":peak,"drained_at":clock,"pages":shown})
				break
		w.status_message.disconnect(listener)
	assert(report.size() == 2, "Both scenarios drain within 60 seconds")
	var file := FileAccess.open(out+"/metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("combat backlog measurement OK")
	quit()
