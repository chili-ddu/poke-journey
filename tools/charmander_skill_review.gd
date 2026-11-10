extends SceneTree

const OUT := "res://docs/charmander_skill_review/"
const MOVES := ["scratch", "growl", "ember", "smoke_screen"]
const NAMES := ["SCRATCH", "GROWL", "EMBER", "SMOKESCREEN"]

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 48.0
	func want_skill(_i, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

class ReviewInput:
	extends Still
	var requested := false
	var target: Node2D
	func aim_point(w) -> Vector2:
		return target.position if is_instance_valid(target) else super.aim_point(w)
	func want_skill(index, _w) -> bool:
		if index != 0 or not requested: return false
		requested = false
		return true

func _init() -> void: call_deferred("run")

func run() -> void:
	await CaptureWindow.park(self)
	var correction := "--correction" in OS.get_cmdline_user_args()
	var destination := "res://docs/hd2d_skill_correction/" if correction else OUT
	var reference := "--reference" in OS.get_cmdline_user_args()
	var far := "--far" in OS.get_cmdline_user_args()
	var facing := Vector2.RIGHT
	var direction_name := "right"
	for pair in [["left",Vector2.LEFT],["up",Vector2.UP],["down",Vector2.DOWN]]:
		if ("--"+String(pair[0])) in OS.get_cmdline_user_args():
			facing=pair[1]
			direction_name=pair[0]
	if reference: destination="res://docs/ember_reference/"+direction_name+"/"
	if far: destination="res://docs/ember_reference/far/"
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "7")
	OS.set_environment("STARTER", "charmander")
	OS.set_environment("DUNGEON", "kanto_south")
	SaveData.path = "user://save_charmander_skill_review.cfg"
	for index in MOVES.size():
		if (reference or far) and index!=2: continue
		if correction and index not in [0,2]: continue
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_process(false)
		game.banner_t = 0.0
		game.stream.clear()
		game.hud.visible = false
		var world: World = game.world
		var input := ReviewInput.new()
		world.player.controller = input
		world.no_skills = false
		world.player.add_learned(MOVES[index])
		world.player.equip(0,MOVES[index])
		world.player.position = Arena.tile_center(Vector2i(23, 209))
		world.player.facing = facing
		var target := Enemy.new()
		target.setup_enemy("chansey", 25, world.rng)
		target.position = world.player.position + facing * (72.0 if far else (28.0 if index == 0 else 48.0))
		target.facing = Vector2.LEFT
		target.frozen = true
		world.add_child(target)
		world.enemies.append(target)
		input.target = target
		var label := Label.new()
		label.text = NAMES[index] + (" / HD-2D" if correction else " / SKILL REVIEW")
		if far: label.text = "EMBER / 3 TILES (72px)"
		label.position = Vector2(8, 8)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		var caption := CanvasLayer.new()
		caption.layer = 100
		root.add_child(caption)
		caption.add_child(label)
		for i in 12:
			world.step_visual(1.0 / 60.0)
			await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination + MOVES[index]))
		var observed := false
		var checked_depth := false
		var attack_seen := false
		var trace: Array = []
		for frame in 48:
			# Exercise the real controller -> input -> cast -> play_attack path.
			# Calling cast alone schedules hits/glide but never starts the pose.
			if frame == 4: input.requested = true
			world.step(1.0 / 30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			trace.append({"frame":frame,"animation":world.player._anim_name,"attack":world.player.attack_anim,
				"attack_left":world.player.attack_anim_t,"full_recovery":world.player.attack_full_recovery})
			if index == 0 and world.player._anim_name == "Strike":
				attack_seen = true
				assert(world.player.attack_full_recovery)
				assert(not world.player.attack_lunge,"Scratch must retain its downward strike, not a truncated body lunge")
			for effect in world.fxs:
				if effect.text.begins_with("pixelfx_") or effect.ember_coat or (index == 1 and effect.sound_fracture):
					observed = true
					if effect.text.begins_with("pixelfx_"):
						var visual: Dictionary = effect.anim_visual(0.4)
						assert(visual.tex != null)
						assert(visual.src.size == Vector2(64, 64))
				if effect.ember_coat and effect.age >= effect.delay and game.view3d._sprites.has(effect.get_instance_id()):
					var sprite: Sprite3D = game.view3d._sprites[effect.get_instance_id()].sprite
					assert(not sprite.no_depth_test,"Flames respect scene depth")
					var state: Dictionary = game.view3d._fx_sprite_state(effect,Fx.sheet(effect.text))
					var body: Sprite3D = game.view3d._sprites[target.get_instance_id()].sprite
					var center := body.position+Vector3.UP*body.offset.y*body.pixel_size*body.scale.y
					var delta: float = (Vector3(state.position)-center).dot(game.view3d.cam.global_basis.z)
					assert(is_equal_approx(delta,effect.body_depth),"Fire layers retain real front/back depth")
					checked_depth = true
			root.get_texture().get_image().save_png(destination + MOVES[index] + "/%03d.png" % frame)
		assert(observed, "New effect must actually play for " + MOVES[index])
		if far: assert(target.hp < target.max_hp,"The distant target must actually be hit")
		if index == 0: assert(attack_seen,"Capture must show the actual Strike animation, not just a gliding Idle pose")
		FileAccess.open(destination+MOVES[index]+"/animation-trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace,"  "))
		if index == 2: assert(checked_depth,"Ember must be verified in 3D, not in a screen overlay")
		assert(DisplayServer.window_get_size() == Vector2i(384, 216))
		print("Captured ", MOVES[index], "; HP ", target.hp, "/", target.max_hp, "; stages ", target.atk_stage, "/", target.acc_stage)
		caption.free()
		game.free()
		current_scene = null
		await process_frame
	print("Selected skills rendered at 384x216")
	quit()
