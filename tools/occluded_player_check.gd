extends SceneTree
const OUT := "res://docs/occluded_player/"
var game: Node
func _init() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("DUNGEON","players_house_2f")
	SaveData.path = "user://save_occluded_player_check.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON","")
	game.banner_t = 0
	game.stream.clear()
	var view: View3D = game.view3d
	var player: Mon = game.world.player
	for entry in [["hidden",Vector2(6.5,3.5)],["partial",Vector2(6.0,3.5)],["clear",Vector2(7.5,4.5)]]:
		view.set_process(true)
		player.position = entry[1]*Arena.TILE
		player.facing = Vector2.RIGHT
		for i in 45:
			game.world.step_visual(1.0/60)
			await process_frame
		view.set_process(false)
		var ent: Dictionary = view._sprites[player.get_instance_id()]
		var cue: MeshInstance3D = ent["occlusion_cue"]
		for on in [false,true]:
			cue.visible = on
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+entry[0]+("_on.png" if on else "_off.png"))
	var ent: Dictionary = view._sprites[player.get_instance_id()]
	player.dead = true
	view._sync_mon(player,{})
	assert(not ent["occlusion_cue"].visible,"Dead player has no cue")
	player.dead = false
	player.burrow = {"test":true}
	view._sync_mon(player,{})
	assert(not ent["occlusion_cue"].visible,"Burrow has no cue")
	player.burrow = {}
	view._sync_mon(player,{})
	assert(ent["occlusion_cue"].visible,"Restored player has cue")
	DungeonDB.set_current("kanto_south")
	view._sync_mon(player,{})
	assert(not ent["occlusion_cue"].visible,"Outdoor cue disabled")
	DungeonDB.set_current("players_house_2f")
	view._sync_mon(player,{})
	assert(ent["occlusion_cue"].visible,"Indoor cue restored")
	print("Cue lifecycle: death, burrow, restore, outdoor, indoor OK")
	game.queue_free()
	await process_frame
	quit()
