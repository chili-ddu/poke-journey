extends SceneTree

const OUT := "res://docs/charmander_motion_review/"
const CLIPS := ["Idle", "Walk", "Charge", "Strike", "Hop"]
var actors: Array[Mon] = []

class Labels:
	extends Node2D
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 960, 800), Color("18232c"))
		draw_string(font, Vector2(18, 26), "CHARMANDER MOTION / BEFORE - AFTER / FRONT, SIDE, BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
		for row in 5:
			var y := 46 + row * 148
			draw_rect(Rect2(0, y, 960, 154 if row == 4 else 140), Color("39463f") if row % 2 == 0 else Color("323e40"))
			draw_string(font, Vector2(12, y + 22), CLIPS[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f7c78a"))
			for col in 6:
				draw_string(font, Vector2(110 + col * 140, y + 22), "BEFORE" if col % 2 == 0 else "AFTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("bbcbc8"))

func _init() -> void: call_deferred("run")

func pose(mon: Mon, clip: String, elapsed: float) -> void:
	var length := MonSprite.anim_length(mon._sprites[clip])
	var time := elapsed
	mon.vel = Vector2.ZERO
	mon.hop_t = 0.0
	mon.attack_anim_t = 0.0
	mon.landing_t = 0.0
	if clip == "Walk":
		mon.vel = mon.facing * mon.move_speed()
		var cycles := mon.vel.length() / (Mon.CharmanderMotion.STRIDE_PIXELS * mon.sprite_scale)
		mon._walk_visual_time = fposmod(elapsed * cycles * length, length)
	elif clip == "Strike":
		time = fposmod(elapsed, 1.3)
		mon.attack_full_recovery = true
		mon.play_attack("Strike")
		mon._attack_start = 0.0
		mon.attack_anim_t = maxf(0.0, mon.attack_anim_t - time)
	elif clip == "Charge":
		mon.attack_anim = "Charge"
		mon.attack_anim_t = 10.0
		mon._attack_start = 0.0
	elif clip == "Hop":
		time = fposmod(elapsed, 1.2)
		mon.hop_t = maxf(0.0, length - time)
		if time >= length: mon.landing_t = maxf(0.0, Mon.LANDING_DURATION - (time - length))
	mon.anim_t = time
	mon._anim_name = clip if clip not in ["Hop", "Strike"] or time < length else "Idle"
	# Scratch's extra contact hold is part of its existing action duration.
	if clip == "Strike" and mon.attack_anim_t > 0.0: mon._anim_name = "Strike"
	mon._anim_start = 0.0 if mon._anim_name == clip else length
	mon.queue_redraw()

func run() -> void:
	await CaptureWindow.park(self)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 800)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Labels.new())
	for row in 5:
		for col in 6:
			var mon := Mon.new()
			mon.setup("charmander", 5, Mon.TEAM_PLAYER)
			mon.set_meta("legacy_motion", col % 2 == 0)
			mon.facing = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP][col / 2]
			mon.position = Vector2(142 + col * 140, 134 + row * 148 + (14 if row == 4 else 0))
			mon.scale = Vector2.ONE * 3.0
			viewport.add_child(mon)
			actors.append(mon)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	for frame in 72:
		for i in actors.size(): pose(actors[i], CLIPS[i / 6], float(frame) / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT + "frames/%03d.png" % frame)
	assert(DisplayServer.window_get_size() == Vector2i(384, 216))
	print("Saved 72 motion frames; minimum window ", DisplayServer.window_get_size())
	quit()
