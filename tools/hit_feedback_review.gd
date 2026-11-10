extends SceneTree

# 기술별 피격 반응: 실제 apply_hit 경로와 상태 기술을 비교.
#   godot --path . -s tools/hit_feedback_review.gd -- <출력디렉터리>
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
	var report := []
	for move in ["scratch","ember","fire_fang","dragon_rage","growl"]:
		for node in w.fxs: node.queue_free()
		w.fxs.clear()
		dummy.position = p.position+Vector2(30,0)
		dummy.hp = dummy.max_hp
		dummy.dead = false
		dummy.knock = Vector2.ZERO
		dummy.hit_visual_t = 0.0
		dummy.flinch_t = 0.0
		dummy.hitstop_t = 0.0
		dummy.flash_t = 0.0
		dummy.hurt_t = 0.0
		dummy.burn_t = 0.0
		await _settle(4)
		if move=="growl": w.cast(p,move,Vector2.RIGHT,dummy.position)
		else: w.apply_hit(dummy,w.make_hit(p,move),p.position)
		report.append({"move":move,"damage":dummy.max_hp-dummy.hp,"feedback":dummy.hit_visual_t,"flinch":dummy.flinch_t,"knock":str(dummy.knock)})
		for frame in 36:
			if frame in [0,2,4,6,9,12,18,30]: await _shot(move+"_%02d"%frame)
			w.step(DT)
			await process_frame
	FileAccess.open(out+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("hit feedback review OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
