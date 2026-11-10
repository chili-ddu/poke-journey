extends SceneTree

# 동시 시전: 1/3/6 연막과 6마리 연막·화염방사·용의분노 중첩 비교.
#   godot --path . -s tools/crowded_skill_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

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
	FxStyle.set_mode("custom")
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
	game.stream.clear()
	p.position = Arena.tile_center(Vector2i(23, 209))
	p.facing = Vector2.RIGHT
	var actors: Array = []
	var center := p.position
	for i in 6:
		var actor := Enemy.new()
		actor.setup_enemy("charmander",30,w.rng)
		actor.max_hp = 99999
		actor.hp = 99999
		actor.position = center+Vector2.from_angle(TAU*i/6.0)*52.0
		actor.frozen = true
		actor.facing = actor.position.direction_to(center)
		for key in actor.cds: actor.cds[key] = 999.0
		w.add_child(actor)
		w.enemies.append(actor)
		actors.append(actor)
	await _settle(30)
	var report := []
	for scenario in ["smoke_1","smoke_3","smoke_6","mixed_6"]:
		for list in [w.fxs,w.projectiles,w.zones]:
			for node in list: node.queue_free()
			list.clear()
		for list in [w.bursts,w.pending_calls,w.pending_melee,w.pending_casts]: list.clear()
		var count := 1 if scenario=="smoke_1" else 3 if scenario=="smoke_3" else 6
		var peak_fx := 0
		var peak_projectiles := 0
		var peak_shade := 0.0
		for i in count:
			var actor: Mon = actors[i]
			w.cast(actor,"smoke_screen",actor.position.direction_to(center),center)
		for frame in 150:
			if scenario=="mixed_6" and frame in [24,48]:
				for i in 6:
					var actor: Mon = actors[i]
					var skill := "flamethrower" if frame==24 else "dragon_rage"
					w.cast(actor,skill,actor.position.direction_to(center),center)
			w.step(DT)
			await process_frame
			peak_fx = maxi(peak_fx,w.fxs.size())
			peak_projectiles = maxi(peak_projectiles,w.projectiles.size())
			peak_shade = maxf(peak_shade,w.smoke_body_shade(center))
			if frame in [12,24,36,48,60,72,90,120,149]: await _shot("%s_%03d"%[scenario,frame])
		assert(peak_shade<=0.32)
		report.append({"scenario":scenario,"peak_fx":peak_fx,"peak_projectiles":peak_projectiles,"peak_body_shade":peak_shade,"remaining_projectiles":w.projectiles.size()})
	var file := FileAccess.open(out+"/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("crowded skill review OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
