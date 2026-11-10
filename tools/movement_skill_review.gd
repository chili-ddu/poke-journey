extends SceneTree

# 점프·회피 선입력 / 기술 시작 직후 이동 입력: 4개 기술의 16개 조합.
#   godot --path . -s tools/movement_skill_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class MovingInput:
	extends RefCounted
	var frame := 0
	var trigger := 0
	var movement := "jump"
	func move_dir(_w) -> Vector2: return Vector2.DOWN
	func aim_point(w) -> Vector2: return w.player.position+Vector2.RIGHT*100.0
	func want_skill(i,_w) -> bool: return i==0
	func want_jump(_w) -> bool: return movement=="jump" and frame==trigger
	func want_dodge(_w) -> bool: return movement=="dodge" and frame==trigger
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
	game.banner_t = 0.0
	game.stream.clear()
	w.no_skills = false
	var unlocked := Player.dodge_unlocked
	Player.dodge_unlocked = true # Fixture only; never saved.
	var report := []
	for move in ["ember","flamethrower","fire_fang","scary_face"]:
		for action in ["jump_first","dodge_first","cast_jump","cast_dodge"]:
			for list in [w.fxs,w.projectiles,w.zones]:
				for node in list: node.queue_free()
				list.clear()
			for list in [w.bursts,w.pending_calls,w.pending_melee,w.pending_casts]: list.clear()
			p.setup_player("charmander",30,[move])
			p.position = Arena.tile_center(Vector2i(23,209))
			p.dash = {}; p.hop_t = 0; p.recover_t = 0; p.skill_lock_t = 0
			p.attack_anim_t = 0; p.dodge_cd = 0; p.hitstop_t = 0; p.invuln_t = 0
			p.use_t.fill(0.0)
			var input := MovingInput.new()
			input.movement = "jump" if action.contains("jump") else "dodge"
			input.trigger = 4 if action.begins_with("cast") else 0
			p.controller = input
			await _settle(8)
			var first_cast := -1
			var moved := false
			var moving_shots := 0
			var seen := {}
			var anchors := {}
			for frame in 90:
				input.frame = frame
				var previous_pp: int = p.pp[0]
				w.step(DT)
				if p.pp[0]<previous_pp and first_cast<0: first_cast=frame
				moved = moved or p.is_dashing()
				for shot in w.projectiles:
					if not seen.has(shot.get_instance_id()):
						seen[shot.get_instance_id()] = true
						if p.is_dashing(): moving_shots+=1
				await process_frame
				for shot in w.projectiles:
					if not shot.mouth_ready: continue
					var id: int = shot.get_instance_id()
					if anchors.has(id): assert(anchors[id].is_equal_approx(shot.mouth_delta))
					anchors[id] = shot.mouth_delta
				if frame in [0,4,8,12,20,30,42,60]: await _shot(move+"_"+action+"_%02d"%frame)
			assert(first_cast>=0)
			report.append({"move":move,"action":action,"first_cast_frame":first_cast,"movement_started":moved,"shots_during_movement":moving_shots,"fixed_anchors":anchors.size()})
	Player.dodge_unlocked = unlocked
	FileAccess.open(out+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("movement skill review OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
