extends SceneTree
var OUT := "res://docs/occlusion_bodies/"
const SPECIES := ["rattata", "venusaur", "onix", "charizard"]
class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT*80
	func want_skill(_i, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false
var game: Node
var checks: Array = []
var top_edges := {}
func _init() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("BODY_REVIEW_OUT") != "":
		OUT = OS.get_environment("BODY_REVIEW_OUT").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("DUNGEON","players_house_2f")
	SaveData.path = "user://save_occlusion_body_review.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON","")
	game.banner_t = 0
	game.stream.clear()
	var p: Mon = game.world.player
	p.controller = Still.new()
	var view: View3D = game.view3d
	for species in SPECIES:
		p.setup(species,5,Mon.TEAM_PLAYER)
		assert(p._sprites.has("Hop"),species+" needs real Hop sheet")
		for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]:
			p.position = Vector2(6.5,3.5)*Arena.TILE
			p.facing = direction
			p.hop_t = 0
			p.lift = 0
			for warmup in 30: await settle()
			await shot(species+"_idle_"+str(MonSprite.row_for(p._sprites["Idle"],direction)))
		p.facing = Vector2.RIGHT
		p.play_hop()
		await settle()
		var duration := MonSprite.anim_length(p._sprites["Hop"])
		for phase in [0.2,0.5,0.8]:
			# Sample the actual Hop animation sheet without moving through TV collision.
			p.anim_t = p._anim_start + duration*phase
			p.hop_t = duration*(1.0-phase)
			await settle()
			await shot(species+"_hop_"+str(int(phase*100)))
		p.hop_t = 0
		p.position = Vector2(7.5,5.5)*Arena.TILE
		await settle()
		await shot(species+"_clear")
		# Real World jump dash through a clear aisle, sampled each simulation frame.
		p.position = Vector2(7.5,5.5)*Arena.TILE
		p.facing = Vector2.RIGHT
		var plan: Dictionary = game.world.plan_hop(p.position,Vector2.RIGHT)
		assert(plan["ok"],species+" clear aisle jump allowed")
		game.world._start_hop(plan["to"])
		var frames := 0
		while not p.dash.is_empty() or p.hop_t>0:
			game.world.step(1.0/60)
			await settle()
			check_geometry(species+"_moving_hop")
			frames += 1
			assert(frames<180,"Jump must finish")
		assert(p.position.distance_to(plan["to"])<1.0,"Jump reaches planned landing")
		checks.append({"species":species,"jump_frames":frames,"landing_error":p.position.distance_to(plan["to"])})
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	FileAccess.open(OUT+"top_edges.json",FileAccess.WRITE).store_string(JSON.stringify(top_edges,"  "))
	print("Body review complete: ",checks)
	game.queue_free()
	await process_frame
	quit()
func settle() -> void:
	# Render pose changes without advancing animation time; then sync the 3D frame explicitly.
	game.view3d.set_process(false)
	for i in 2: await process_frame
	game.view3d._follow_camera()
	game.view3d._sync_mon(game.world.player,{})
	await process_frame
func check_geometry(label: String) -> void:
	var view: View3D = game.view3d
	var ent: Dictionary = view._sprites[game.world.player.get_instance_id()]
	var s: Sprite3D = ent["sprite"]
	var cue: MeshInstance3D = ent["occlusion_cue"]
	var size: Vector2 = (cue.mesh as QuadMesh).size
	assert(size.is_equal_approx(s.region_rect.size*s.pixel_size),label+" frame size")
	assert(cue.basis.get_scale().is_equal_approx(s.scale),label+" scale")
	var expected := s.position + cue.basis*Vector3(s.offset.x,s.offset.y,0)*s.pixel_size
	assert(cue.position.distance_to(expected)<0.00001,label+" offset")
	assert(cue.material_override.get_shader_parameter("sprite_tex")==s.texture,label+" current sheet")
	var used := s.texture.get_image().get_region(Rect2i(s.region_rect)).get_used_rect()
	var top := INF
	for x in [used.position.x,used.end.x]:
		var local := Vector3(float(x)-s.region_rect.size.x/2.0,s.region_rect.size.y/2.0-used.position.y,0)*s.pixel_size
		top = minf(top,view.cam.unproject_position(cue.transform*local).y/float(view.vp.size.y))
	var species: String = game.world.player.species_id
	top_edges[species] = minf(float(top_edges.get(species,1.0)),top)
	assert(top>=0.0,label+" opaque frame stays below screen top")
func shot(label: String) -> void:
	check_geometry(label)
	var ent: Dictionary = game.view3d._sprites[game.world.player.get_instance_id()]
	for on in [false,true]:
		ent["occlusion_cue"].visible = on
		for i in 2: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+label+("_on.png" if on else "_off.png"))
	checks.append({"pose":label,"animation":game.world.player._anim_name,"frame":str(game.world.player.stat_overlay.src)})
