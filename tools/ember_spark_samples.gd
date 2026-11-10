extends SceneTree

# Review only: screen-space particles demonstrate impact energy without
# changing World, damage, hit-stop or the installed skill effects.
const OUT := "res://docs/ember_spark_samples/"
const TITLES := ["A / CURRENT", "B / QUICK SPARKS", "C / STRONG SPARKS"]
const Still = preload("res://tools/charmander_skill_review.gd").Still

class SparkFan:
	extends Node2D
	var particles: Array = []
	var emitted := 0
	func burst(at: Vector2, strength: int) -> void:
		var count := 7 if strength == 1 else 10
		for i in count:
			var fraction := float(i) / float(count - 1)
			# A little rebound/upward scatter keeps sparks visible at the contact
			# surface instead of burying every orange pixel inside the victim.
			var angle := lerpf(1.1, 5.1, fraction) + sin(float(i) * 3.1) * 0.10
			var speed := lerpf(65.0, 110.0, float((i * 3) % count) / float(count - 1))
			speed *= 1.3 if strength == 1 else 1.9
			var life := 0.24 + float(i % 3) * 0.04 + (0.10 if strength == 2 else 0.0)
			particles.append({"position":at+Vector2(-3,0), "velocity":Vector2.from_angle(angle) * speed + Vector2(0,-15),
				"age":0.0, "life":life, "floor":at.y+18.0, "large":strength == 2,
				"tail":4 if strength == 1 else 8})
		emitted += count
		queue_redraw()
	func step(dt: float) -> void:
		for particle in particles:
			particle.age += dt
			particle.velocity *= exp(-3.0 * dt)
			particle.velocity.y += 140.0 * dt
			particle.position += particle.velocity * dt
			if particle.position.y > particle.floor and particle.velocity.y > 0.0:
				particle.position.y = particle.floor
				particle.velocity.y *= -0.25
				particle.velocity.x *= 0.65
		particles = particles.filter(func(p): return p.age < p.life)
		queue_redraw()
	func _draw() -> void:
		for particle in particles:
			var t: float = particle.age / particle.life
			var color := Color("fff8d6") if t < 0.28 else Color("ffd34b") if t < 0.55 else Color("ff792b") if t < 0.8 else Color("b64222")
			var alpha := 1.0 - smoothstep(0.65, 1.0, t)
			var forward: Vector2 = particle.velocity.normalized()
			var length: int = maxi(1, int(float(particle.tail) * (1.0 - t)))
			for i in range(length, 0, -1):
				var point: Vector2 = (particle.position - forward * float(i)).round()
				draw_rect(Rect2(point, Vector2.ONE), Color(1.0,0.31,0.07,alpha * (1.0-float(i)/float(length+1))))
			var size := 2.0 if particle.large and t < 0.55 else 1.0
			draw_rect(Rect2((particle.position as Vector2).round(),Vector2.ONE*size),Color(color,alpha))

func _init() -> void: call_deferred("run")

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "7")
	OS.set_environment("STARTER", "charmander")
	OS.set_environment("DUNGEON", "kanto_south")
	SaveData.path = "user://save_ember_spark_samples.cfg"
	for variant in 3:
		seed(7)
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_process(false)
		game.banner_t = 0.0
		game.stream.clear()
		game.hud.visible = false
		var world: World = game.world
		world.player.controller = Still.new()
		world.player.position = Arena.tile_center(Vector2i(23,209))
		world.player.facing = Vector2.RIGHT
		var target := Enemy.new()
		target.setup_enemy("chansey",25,world.rng)
		target.position = world.player.position + Vector2.RIGHT*48.0
		target.facing = Vector2.LEFT
		target.frozen = true
		world.add_child(target)
		world.enemies.append(target)
		var overlay := CanvasLayer.new()
		overlay.layer = 100
		root.add_child(overlay)
		var sparks := SparkFan.new()
		overlay.add_child(sparks)
		var caption := Label.new()
		caption.text = TITLES[variant]
		caption.position = Vector2(8,8)
		caption.add_theme_font_size_override("font_size",12)
		caption.add_theme_color_override("font_shadow_color",Color.BLACK)
		caption.add_theme_constant_override("shadow_offset_x",1)
		caption.add_theme_constant_override("shadow_offset_y",1)
		overlay.add_child(caption)
		for i in 12:
			world.step_visual(1.0/60.0)
			await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+str(variant)))
		var seen := {}
		var hits := 0
		for frame in 48:
			if frame == 4: world.cast(world.player,"ember",Vector2.RIGHT,target.position)
			world.step(1.0/30.0)
			sparks.step(1.0/30.0)
			await process_frame
			for effect in world.fxs:
				if effect.text != "pixelfx_ember" or seen.has(effect.get_instance_id()): continue
				var entries: Dictionary = game.view3d._sprites
				if not entries.has(effect.get_instance_id()): continue
				var sprite: Sprite3D = entries[effect.get_instance_id()].sprite
				seen[effect.get_instance_id()] = true
				hits += 1
				if variant > 0: sparks.burst(game.view3d.cam.unproject_position(sprite.global_position),variant)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+str(variant)+"/%03d.png"%frame)
		assert(hits > 0)
		assert(sparks.emitted == hits * ([0,7,10][variant]))
		assert(sparks.particles.is_empty(),"Sparks must clear before the loop ends")
		assert(DisplayServer.window_get_size() == Vector2i(384,216))
		print(TITLES[variant],": ",hits," impacts, ",sparks.emitted," sample sparks; HP ",target.hp,"/",target.max_hp)
		overlay.free()
		game.free()
		current_scene = null
		await process_frame
	quit()
