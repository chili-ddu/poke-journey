extends "res://tools/kanto_expansion_review.gd"

const Palette = preload("res://scripts/view/map_palette.gd")
const Game = preload("res://scripts/game.gd")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_map_palette_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	Game.starter="charmander"
	var report := []
	for fixture in [
		{"id":"road","place":"kanto_south","tile":Vector2i(23,209)},
		{"id":"forest","place":"viridian_forest","tile":Vector2i(-1,-1)},
		{"id":"city","place":"saffron_city","tile":Vector2i(24,40)},
		{"id":"cave","place":"mt_moon_1f","tile":Vector2i(-1,-1)},
		{"id":"interior","place":"oaks_lab","tile":Vector2i(-1,-1)},
		{"id":"arena","place":"arena_viridian_forest","tile":Vector2i(-1,-1)}]:
		var collision_before := []
		for phase in ["before","after"]:
			Palette.enabled=phase=="after"
			Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
			await open_fixture(fixture.place)
			game.set_process(false)
			game.ui_root.visible=false
			game.view3d.set_process(false)
			if fixture.tile.x>=0:
				game.world.player.position=Arena.resolve(Arena.tile_center(fixture.tile),game.world.player.radius)
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			for i in 45:
				game.advance(1.0/60.0)
				game.view3d._process(1.0/60.0)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			assert(DisplayServer.window_get_size()==Vector2i(384,216))
			var output: String = "res://docs/map_palette_review/"+phase+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			root.get_texture().get_image().save_png(output+fixture.id+".png")
			var collision := []
			var tile := Arena.tile_of(game.world.player.position)
			for y in range(tile.y-8,tile.y+9):
				for x in range(tile.x-8,tile.x+9): collision.append(Arena.solid_at(x,y))
			if phase=="before": collision_before=collision
			else: assert(collision==collision_before,"Map art cannot change collision")
			print("MAP PALETTE ",phase," ",fixture.id)
		report.append({"place":fixture.place,"collision_unchanged":true})
	FileAccess.open("res://docs/map_palette_review/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free()
	quit()
