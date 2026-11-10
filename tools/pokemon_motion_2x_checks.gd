extends SceneTree

const REPORT := "res://docs/pokemon_2x_rollout/"
const Flight = preload("res://scripts/data/pokemon_flight.gd")
var checked := 0
var passing := 0

class CheckController:
	extends RefCounted
	var frame := 0
	var target: Mon
	func move_dir(_w): return Vector2.RIGHT if frame < 12 else Vector2.ZERO
	func aim_point(w): return target.position if is_instance_valid(target) else w.player.position + Vector2.RIGHT * 28
	func want_skill(i, _w): return i == 0 and frame in [25, 95]
	func want_jump(_w): return frame == 130
	func want_dodge(_w): return false
	func want_item(_w): return false

func _init() -> void: call_deferred("run")

func check_set(dex: int, shiny: bool) -> void:
	var sprites := MonSprite.load_set(dex, shiny)
	assert(sprites.has("Walk"), "Missing Walk: %d shiny=%s" % [dex, shiny])
	var seen := {}
	for name: String in MonSprite.ANIMS:
		if not sprites.has(name): continue
		var anim: Dictionary = sprites[name]
		if seen.has(anim.source_path): continue
		seen[anim.source_path] = true
		var entry: Dictionary = SmoothSprite._manifest.get(anim.source_path, {})
		assert(int(entry.get("steps", 0)) == 2, "Missing two-step profile: " + anim.source_path)
		assert(entry.has("centers") and entry.has("flight_centers"))
		var total := 0
		for value in anim.durations: total += int(value)
		assert(is_equal_approx(MonSprite.anim_length(anim), float(total) / 60.0))
		var size := Vector2(anim.fw, anim.fh)
		for row in int(anim.rows):
			for frame in anim.durations.size():
				var at := MonSprite.frame_start(anim, frame)
				var duration := float(anim.durations[frame]) / 60.0
				assert(MonSprite.frame_at(anim, at + 0.000001, true) == frame)
				var key := MonSprite.visual_frame(anim, row, at + duration * 0.0001, true)
				assert(key.tex == anim.tex and key.src.position == Vector2(frame * size.x, row * size.y))
				var next: int = (frame + 1) % anim.durations.size()
				var pair := "%d,%d,%d,%d" % [frame * int(size.x), row * int(size.y), next * int(size.x), row * int(size.y)]
				if next != frame:
					assert(entry.pairs.has(pair), "Missing pair: " + anim.source_path + ":" + pair)
					var mid := MonSprite.visual_frame(anim, row, at + duration * 0.999, true)
					assert(mid.tex != anim.tex and mid.src.size == size)
					assert(mid.src.end.x <= mid.tex.get_width() and mid.src.end.y <= mid.tex.get_height(), "Imported atlas geometry must match the profile: %s r%d f%d src=%s texture=%s" % [anim.source_path,row,frame,str(mid.src),str(mid.tex.get_size())])
					var delta: Array = entry.deltas[pair]
					assert(mid.body_center == anim.centers[row][frame] + Vector2(float(delta[0]), float(delta[1])))
					var torso := MonSprite.flight_anchor(anim, row, at + duration * 0.999, mid)
					var original: Array = entry.flight_centers[row][frame]
					assert(torso == Vector2(float(original[0]) + float(delta[2]), float(original[1]) + float(delta[3])))
					passing += 1
				checked += 1
		# One-shots keep the final source pose, even beyond its logical end.
		var end := MonSprite.visual_frame(anim, 0, MonSprite.anim_length(anim) + 1.0, false)
		assert(end.tex == anim.tex and end.src.position.x == (anim.durations.size() - 1) * size.x)
		# A truncated lunge and an explicit source-frame override also stay held.
		var held := MonSprite.visual_frame(anim, 0, 0.0, false, 0, 0)
		assert(held.tex == anim.tex)
	assert(MonSprite._cache.size() <= MonSprite.SET_CACHE_LIMIT)
	assert(SmoothSprite._textures.size() <= SmoothSprite.TEXTURE_LIMIT)
	assert(SmoothSprite._pokemon_profiles.size() <= SmoothSprite.PROFILE_LIMIT)

func battle_snapshot(smooth: bool) -> Dictionary:
	SmoothSprite.enabled = smooth
	DungeonDB.set_current("test_meadow"); Arena.configure(DungeonDB.theme())
	seed(35791)
	var input := CheckController.new()
	var world := World.new(); root.add_child(world)
	world.setup(7, "charmander", 20, ["scratch"], input)
	world.player.repel_steps = 100000
	for enemy in world.enemies: enemy.queue_free()
	world.enemies.clear()
	var target := Enemy.new(); target.setup_enemy("chansey", 35, world.rng)
	target.frozen = true
	for move in target.cds: target.cds[move] = 99999.0
	world.add_child(target); world.enemies.append(target); input.target = target
	var initial_hp := target.hp
	var initial_pp: Array = world.player.pp.duplicate()
	var minimum_pp: int = int(initial_pp[0])
	for frame in 180:
		input.frame = frame
		if frame in [24, 94]: target.position = world.player.position + Vector2.RIGHT * 22
		world.step(1.0 / 60.0)
		minimum_pp = mini(minimum_pp,int(world.player.pp[0]))
		var anim: Dictionary = world.player._sprites.Attack
		MonSprite.display_frame(anim, 2, world.player.anim_t, false)
	assert(minimum_pp < int(initial_pp[0]), "Fixture must spend PP before regeneration")
	assert(target.hp < initial_hp, "Fixture must deal actual damage")
	var result := {"hp": world.player.hp, "target_hp": target.hp, "pp": world.player.pp.duplicate(),
		"minimum_pp":minimum_pp,"damage":initial_hp-target.hp,
		"position": world.player.position, "rng": str(world.rng.state), "attack_left": world.player.attack_anim_t, "hop_left": world.player.hop_t}
	world.free()
	return result

func custom_sequences() -> void:
	var anim: Dictionary = MonSprite.load_set(4).Strike
	var order: Array = Mon.SCRATCH_POSE_ORDER
	for k in order.size():
		var at := MonSprite.frame_start(anim, k) + float(anim.durations[k]) / 60.0 * 0.9
		var visual := MonSprite.visual_frame(anim, 2, at, false, -1, -1, order)
		assert(visual.src.size == Vector2(anim.fw, anim.fh))
	for sid in ["charizard", "pidgeotto", "zubat", "scyther", "lapras"]:
		var mon := Mon.new(); mon.setup(sid, 20, 0)
		var name := Flight.prepare_animation(mon)
		if name != "":
			var flight: Dictionary = mon._sprites[name]
			for row in int(flight.rows):
				for k in flight.durations.size():
					var at := MonSprite.frame_start(flight,k) + float(flight.durations[k]) / 60.0 * 0.9
					var visual := MonSprite.visual_frame(flight,row,at,true)
					assert(MonSprite.flight_anchor(flight,row,at,visual).is_finite())
		mon.free()
	# Non-Pokémon sprites retain their original four-phase interpolation.
	var source := "res://assets/npcs/balding_man.png"
	var entry: Dictionary = SmoothSprite._manifest[source]
	assert(int(entry.get("steps",4)) == 4)
	var texture: Texture2D = load(source)
	var size := Vector2(float(entry.size[0]),float(entry.size[1]))
	var values := String(entry.pairs.keys()[0]).split(",")
	var first := Rect2(Vector2(float(values[0]),float(values[1])),size)
	var next := Rect2(Vector2(float(values[2]),float(values[3])),size)
	assert(SmoothSprite.between(texture,first,next,0.2).tex==texture)
	var a := SmoothSprite.between(texture,first,next,0.3)
	var b := SmoothSprite.between(texture,first,next,0.6)
	var d := SmoothSprite.between(texture,first,next,0.9)
	assert(a.tex!=texture and a.src!=b.src and b.src!=d.src)

func run() -> void:
	OS.set_environment("BOT", "1")
	SaveData.path = "user://save_pokemon_motion_2x_checks.cfg"
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() else 1
	var last := int(args[1]) if args.size() > 1 else 493
	for dex in range(first, last + 1):
		check_set(dex, false); check_set(dex, true)
		if dex % 25 == 0: print("ROSTER 2X: ", dex, " species checked")
	custom_sequences()
	var on := battle_snapshot(true)
	var off := battle_snapshot(false)
	assert(on == off, "Visual interpolation must not change battle/PP/HP/position/RNG")
	SmoothSprite.enabled = true
	var result := {"first":first,"last":last,"sets":2*(last-first+1),"source_keys":checked,"passing_pairs":passing,
		"custom_sequences":"pass","battle_equal_with_interpolation_disabled":true,"battle":on}
	FileAccess.open(REPORT+"runtime-%04d-%04d.json" % [first,last],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("POKEMON 2X CHECKS ", JSON.stringify(result))
	quit()
