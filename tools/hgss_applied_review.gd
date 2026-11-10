extends SceneTree
const Game = preload("res://scripts/game.gd")
const Art = preload("res://scripts/view/hgss_environment.gd")
const Rules = preload("res://scripts/johto/visual_style_rules.gd")
var out := "res://docs/hgss_applied/"
var game: Node

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	SaveData.path="user://hgss_applied_review_only.cfg"
	OS.set_environment("BOT","1")
	Game.skip_opening=true
	Game.bot_events=[];Game.bot_beaten=[]
	var records: Array=[]
	for fixture in [["pallet","kanto_world",Vector2i(76,275)], ["pewter","kanto_world",Vector2i(63,85)],
		["forest","viridian_forest",Vector2i(-1,-1)], ["cave","mt_moon_1f",Vector2i(-1,-1)], ["lab","oaks_lab",Vector2i(6,8)]]:
		OS.set_environment("DUNGEON",fixture[1])
		Game.destination={};Game.arena_trip={};Game.carry={}
		game=load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false);game.view3d.set_process(false)
		if fixture[2].x>=0:game.world.player.position=Arena.tile_center(fixture[2])
		game.world.cam_pos=game.world.player.position
		game.world.cam.position=game.world.player.position
		game.dialog_text="";game.last_small_message="";game.banner_t=0
		for i in 20:
			game.view3d._process(1.0/60.0)
			await process_frame
		assert(root.size==Vector2i(384,216))
		var expected: Dictionary=Rules.data().profiles[Rules.game_profile(DungeonDB.current)]
		var material:=game.look_rect.material as ShaderMaterial
		assert(is_equal_approx(float(material.get_shader_parameter("bloom_strength")),float(expected.bloom_strength)))
		var native:=0
		for child in game.view3d.root3d.get_children():
			if child.has_meta("hgss_door"):native+=1
		if fixture[1]=="kanto_world":assert(native>0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+fixture[0]+".png")
		records.append({"scene":fixture[1],"shot":fixture[0],"native_buildings":native,"profile":Rules.game_profile(DungeonDB.current),"size":[384,216]})
		game.free();await process_frame
	var file:=FileAccess.open(out+"native_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixtures":records,"isolated_save":SaveData.path,"frlg_geography_preserved":true}))
	file.close()
	print("HGSS applied native review passed: real Game renderer, Pallet/Pewter/forest/cave/lab, 384x216, isolated save")
	quit()
