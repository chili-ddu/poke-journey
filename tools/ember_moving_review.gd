extends SceneTree

# 이동 중 조준 전환과 실제 입력 경로를 통한 연속 불꽃세례 캡처.
#   godot --path . -s tools/ember_moving_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.DOWN
	var direction := Vector2.RIGHT
	func aim_point(w) -> Vector2: return w.player.position + direction * 80.0
	var firing := false
	func want_skill(i: int, w) -> bool: return firing and w.player.slots[i] == "ember"
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
	game.stream.clear()
	p.position = Arena.tile_center(Vector2i(23, 209))
	p.facing = Vector2.RIGHT
	await _settle(30)
	w.no_skills = false
	p.controller.firing = true
	var seen := {}
	var volleys := {}
	var start_position := p.position
	for frame in 180:
		w.step(DT)
		for projectile in w.projectiles:
			if seen.has(projectile.get_instance_id()): continue
			seen[projectile.get_instance_id()] = true
			var volley: int = projectile.hit.get("volley", 0)
			volleys[volley] = int(volleys.get(volley, 0)) + 1
			p.controller.direction = Vector2.UP
		await process_frame
		if frame % 3 == 0: await _shot("moving_%03d" % frame)
	print("EMBER moving: volleys=", volleys, " distance=", p.position.distance_to(start_position))
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
