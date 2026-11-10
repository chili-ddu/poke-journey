extends SceneTree
# Actual stair transition round-trip, isolated from the user's save.
var game: Node
func _init() -> void:
	call_deferred("run")
func run() -> void:
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("DUNGEON","players_house_1f")
	SaveData.path = "user://save_home_stair_smoke.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON","")
	for target in ["players_house_2f","players_house_1f"]:
		# Clear arrival suppression by stepping away, then approach through resolved positions.
		game.world.player.position = Arena.tile_center(Vector2i(10,3))
		for i in 20:
			game.advance(1.0/60)
		for i in 24:
			game.world.player.position = Arena.resolve(game.world.player.position + Vector2(0,-1),game.world.player.radius)
			game.advance(1.0/60)
			if game.state == "warp":
				break
		assert(game.state == "warp", "Walking onto mat triggers stair transition")
		for i in 120:
			await create_timer(0.01).timeout
			if current_scene != game:
				break
		game = current_scene
		game.set_process(false)
		await process_frame
		assert(DungeonDB.current == target, "Correct destination floor")
		assert(Arena.tile_of(game.world.player.position).x == 10, "Arrival aligned with landing")
		print("stairs arrived: ",target," tile=",Arena.tile_of(game.world.player.position))
	print("Stair round-trip passed")
	quit()
