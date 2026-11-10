extends SceneTree

# 근접 적 4방향 및 실제 건물 벽 불꽃세례 점검.
#   godot --path . -s tools/ember_proximity_review.gd -- <출력디렉터리>
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
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		if OS.get_environment("EMBER_FILM") == "1" and direction != (Vector2.DOWN if OS.get_environment("EMBER_FILM_DOWN") == "1" else Vector2.RIGHT): continue
		var label := str(int(direction.x))+"_"+str(int(direction.y))
		dummy.position = p.position + direction*22
		p.facing = direction
		p.controller.direction = direction
		p.play_attack("Charge",0.7)
		await _settle(4)
		w.cast(p,"ember",direction,dummy.position)
		for frame in 60:
			w.step(DT)
			await process_frame
			if frame in [0,4,8,16,28,36,44,52] or (OS.get_environment("EMBER_FILM") == "1" and frame%2==0): await _shot(label+"_"+str(frame))
		for i in 40:
			w.step(DT)
			await process_frame
	dummy.position = p.position + Vector2(0,160)
	# Find the first real building wall above of the review location.
	var wall := Vector2.INF
	var nearest := INF
	for y in range(201,215):
		for x in range(15,32):
			if not Arena.solid_at(x,y) or Arena.solid_at(x,y+1): continue
			var candidate := Vector2((x+0.5)*Arena.TILE,(y+1)*Arena.TILE-1)
			var distance := candidate.distance_to(p.position)
			if distance<nearest:
				nearest=distance
				wall=candidate
	p.position = wall + Vector2(0,20)
	p.facing = Vector2.UP
	p.controller.direction = Vector2.UP
	p.play_attack("Charge",0.7)
	await _settle(20)
	assert(Arena.blocks(wall,0), "Review requires a real wall")
	w.cast(p,"ember",Vector2.UP,wall)
	for frame in 60:
		w.step(DT)
		await process_frame
		if frame in [0,4,8,16,28,36,44,52]: await _shot("wall_"+str(frame))
	print("ember proximity capture OK wall=",wall)
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
