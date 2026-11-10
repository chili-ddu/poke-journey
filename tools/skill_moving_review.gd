extends SceneTree

# 이동 중 조준 전환과 실제 입력 경로를 통한 연속 기술 시전 캡처.
#   godot --path . -s tools/skill_moving_review.gd -- <출력디렉터리> <포켓몬 ID> <기술 ID>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.DOWN
	var direction := Vector2.RIGHT
	func aim_point(w) -> Vector2: return w.player.position + direction * 80.0
	var firing := false
	var move := "ember"
	func want_skill(i: int, w) -> bool: return firing and w.player.slots[i] == move
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
	var species := OS.get_cmdline_user_args()[1]
	var move := OS.get_cmdline_user_args()[2]
	p.setup_player(species,30,[move])
	p.controller = Still.new()
	p.controller.move = move
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
	var anchor_cache := {}
	var effect_count := 0
	var effect_seen := {}
	var old_velocity := {}
	for frame in 180:
		p.controller.direction = [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN][int(frame/30)%4]
		w.step(DT)
		for fx in w.fxs:
			if not effect_seen.has(fx.get_instance_id()):
				effect_seen[fx.get_instance_id()] = true
				effect_count += 1
		for projectile in w.projectiles:
			var key: int = projectile.get_instance_id()
			if old_velocity.has(key): assert(projectile.vel.is_equal_approx(old_velocity[key]))
			old_velocity[key] = projectile.vel
		for projectile in w.projectiles:
			if seen.has(projectile.get_instance_id()): continue
			seen[projectile.get_instance_id()] = true
			var volley: int = projectile.hit.get("volley", 0)
			volleys[volley] = int(volleys.get(volley, 0)) + 1

		await process_frame
		for projectile in w.projectiles:
			if not projectile.mouth_ready: continue
			var key: int = projectile.get_instance_id()
			if anchor_cache.has(key): assert(projectile.mouth_delta.is_equal_approx(anchor_cache[key]))
			anchor_cache[key] = projectile.mouth_delta
		if frame % 15 == 0: await _shot("moving_%03d" % frame)
	var distance := p.position.distance_to(start_position)
	assert(distance>2.0)
	assert(effect_count>0 or seen.size()>0)
	var file := FileAccess.open(out+"/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"species":species,"move":move,"distance":distance,"projectiles":seen.size(),"volleys":volleys,"effects":effect_count,"anchors_checked":anchor_cache.size()},"  "))
	print("moving skill review OK ",species," ",move)
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
