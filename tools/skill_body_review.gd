extends SceneTree

# 무서운얼굴 커스텀 HD-2D: 네 방향의 응시·위협 확대·소멸 캡처.
#   godot --path . -s tools/scary_face_review.gd -- <출력디렉터리>
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
	var dummy := Enemy.new()
	dummy.setup_enemy("rattata", 4, w.rng)
	dummy.max_hp = 9999; dummy.hp = 9999
	dummy.position = p.position + Vector2(50,0)
	dummy.facing = Vector2.LEFT
	dummy.frozen = true
	for k in dummy.cds:
		dummy.cds[k] = 999.0
	w.add_child(dummy)
	w.enemies.append(dummy)
	await _settle(30)
	var species := OS.get_cmdline_user_args()[1]
	p.setup_player(species,30,["scratch","ember","fire_fang","scary_face"])
	assert(not p._sprites.is_empty(),"Visual audit requires an installed species sprite")
	var report: Array = []
	for move in MoveShapes.CUSTOM_FX:
		if OS.get_cmdline_user_args().size()>2 and move!=OS.get_cmdline_user_args()[2]: continue
		var directions := [0,2,4,6] if move in ["fire_fang","scary_face"] else [0,6]
		for row in directions:
			for list in [w.fxs,w.projectiles,w.zones]:
				for node in list:
					if is_instance_valid(node): node.queue_free()
				list.clear()
			for list in [w.bursts,w.pending_calls,w.pending_melee,w.pending_casts]: list.clear()
			p.position = Arena.tile_center(Vector2i(23,209))
			p.hp = p.max_hp
			p.dead = false
			var direction := Vector2.UP.rotated(row*PI/4.0)
			dummy.position = p.position+direction*(p.radius+dummy.radius+20.0)
			dummy.hp = dummy.max_hp
			dummy.dead = false
			dummy.burn_t = 0.0
			for stat in ["atk","def","spa","spd","spe","acc","eva"]: dummy.set(stat+"_stage",0)
			p.facing = direction
			p.controller.direction = direction
			p.play_attack("Attack" if move in ["scratch","fire_fang"] else "Charge",0.4)
			await _settle(4)
			w.cast(p,move,direction,dummy.position)
			for frame in 90:
				w.step(DT)
				if frame in [0,12,36,60]:
					await process_frame
					if frame!=0 and (frame!=60 or move=="smoke_screen"):
						await _shot("%s_%d_%d"%[move,row,frame])
			assert(p.position.is_finite())
			report.append({"species":species,"move":move,"direction":row,"radius":p.radius,"has_sprite":not p._sprites.is_empty()})
	var file := FileAccess.open(out+("/metrics_"+OS.get_cmdline_user_args()[2]+".json" if OS.get_cmdline_user_args().size()>2 else "/metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("body skill review OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
