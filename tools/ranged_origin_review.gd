extends "res://tools/material_hit_fx_review.gd"

const CASES=[
	["charmander","ember",Vector2.RIGHT],
	["squirtle","water_gun",Vector2.LEFT],
	["glaceon","icy_wind",Vector2.UP],
	["charizard","dragon_rage",Vector2.DOWN]
]

class DirectionInput extends ReviewInput:
	var direction:=Vector2.RIGHT
	func aim_point(w) -> Vector2: return w.player.position+direction*100

func run() -> void:
	SaveData.path="user://ranged_origin_review_private.cfg"
	for pair in [["BOT","1"],["SEED","7"],["STARTER","charmander"],["DUNGEON","kanto_south"]]:
		OS.set_environment(pair[0],pair[1])
	await CaptureWindow.park(self)
	var stage: String=OS.get_cmdline_user_args()[0]
	for item in CASES:
		await record(item,stage)
	quit()

func record(item: Array,stage: String) -> void:
	seed(7)
	FxStyle.set_mode("custom")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	game.stream.clear()
	game.ui_root.hide()
	game.view3d.set_process(false)
	var old: World=game.world
	var world:=World.new()
	game.add_child(world)
	game.world=world
	game.view3d.world=world
	old.free()
	var input:=DirectionInput.new()
	input.direction=item[2]
	world.setup(7,item[0],40,[item[1]],input)
	world.player.position=open_cross()
	world.player.facing=item[2]
	world.aim_point=world.player.position+item[2]*100
	world.visibility_layer|=Look.GROUND_LAYER
	game.view3d._cam_ready=false
	var dest: String="res://docs/all_move_targets/"+stage+"/"+item[1]+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	for i in (56 if stage=="play" else 22):
		if stage=="play":
			if i==4: input.requested=true
			world.step(1.0/45)
		else:
			if i==4: world.cast(world.player,item[1],item[2],world.aim_point)
			world._step_bursts(1.0/45)
			world._step_projectiles(1.0/45)
		game.view3d._process(1.0/45)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.size==Vector2i(384,216))
		root.get_texture().get_image().save_png(dest+"%02d.png"%i)
	game.free()
	await process_frame
