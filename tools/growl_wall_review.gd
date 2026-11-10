extends SceneTree

# 울음소리 HD-2D 네 방향: 세 음파와 공격력 하락 반응 점검.
#   godot --path . -s tools/growl_wall_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node
var refraction_peak := 0

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
	var wall := Vector2(516,4991)
	assert(Arena.blocks(wall,0))
	p.position=wall+Vector2(0,20)
	p.controller.direction=Vector2.UP
	p.facing=Vector2.UP
	await _settle(30)
	p.play_attack("Charge",0.7)
	w.cast(p,"growl",Vector2.UP,wall)
	var peak := 0
	for frame in 70:
		w.step(DT)
		await process_frame
		peak=maxi(peak,int(game.view3d.rect.material.get_shader_parameter("fracture_count")))
		if frame%2==0: await _shot("wall_%03d"%frame)
	assert(peak==0,"Wall sound must not refract facade")
	print("wall refraction peak=",peak)
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	if OS.get_environment("CHECK_REFRACTION")=="1":
		refraction_peak=maxi(refraction_peak,int(game.view3d.rect.material.get_shader_parameter("fracture_count")))
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

	if OS.get_environment("CHECK_REFRACTION")=="1" and name=="0_1_12":
		var view = game.view3d
		view.set_process(false)
		var material: ShaderMaterial = view.rect.material
		var count: int = material.get_shader_parameter("fracture_count")
		material.set_shader_parameter("fracture_count",0)
		for i in 3: await process_frame
		root.get_texture().get_image().save_png(out+"/refraction_off.png")
		material.set_shader_parameter("fracture_count",count)
		view.set_process(true)
