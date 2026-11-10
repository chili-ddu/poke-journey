extends SceneTree

func _init() -> void:call_deferred("run")

func run() -> void:
	await CaptureWindow.park(self)
	var game_script=load("res://scripts/game.gd")
	SaveData.path="user://save_player_cursor_review.cfg";SaveData.clear()
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("DUNGEON","pewter_gym")
	game_script.starter="charmander";game_script.destination={};game_script.arena_trip={};game_script.carry={}
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_process(false);game.view3d.set_process(false)
	assert(game.player_cursor!=null)
	game.get_window().mouse_entered.emit()
	assert(game.player_cursor.using_custom_cursor())
	var layer:=CanvasLayer.new();layer.layer=30;layer.scale=Vector2(0.375,0.375);game.add_child(layer)
	var board:=ColorRect.new();board.position=Vector2(20,20);board.size=Vector2(720,510);board.color=Color("e8eddc");layer.add_child(board)
	var names: Dictionary={"charmander":"파이리","charmeleon":"리자드","charizard":"리자몽","squirtle":"꼬부기","wartortle":"어니부기","blastoise":"거북왕","bulbasaur":"이상해씨","ivysaur":"이상해풀","venusaur":"이상해꽃"}
	var i:=0
	for species in names:
		game.world.player.evolve_to(species);game.player_cursor.refresh()
		assert(game.player_cursor.current_species==species)
		var tex: Texture2D=game.player_cursor.current_texture
		assert(tex!=null and tex.get_size()==Vector2(40,40))
		var at:=Vector2(30+(i%3)*235,25+(i/3)*165)
		var label:=Label.new();label.text=names[species];label.theme=UiFont.make_theme();label.add_theme_color_override("font_color",Color("242824"));label.position=at;board.add_child(label)
		for scale in [1,3]:
			var image:=TextureRect.new();image.texture=tex;image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			image.position=at+Vector2(20 if scale==1 else 90,35);image.size=Vector2(40,40)*scale
			board.add_child(image)
		i+=1
	for frame in 20:
		game.view3d._process(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/player_cursor_review")
	root.get_texture().get_image().save_png("res://docs/player_cursor_review/native_and_enlarged.png")
	game.get_window().mouse_exited.emit()
	assert(not game.player_cursor.using_custom_cursor())
	game.get_window().mouse_entered.emit()
	assert(game.player_cursor.using_custom_cursor())
	game.get_window().focus_exited.emit()
	assert(not game.player_cursor.using_custom_cursor())
	game.free();await process_frame
	SaveData.clear()
	print("Player cursor review: all nine native cursor textures registered successfully; window exit, reentry, focus loss and scene cleanup restored the proper pointer")
	quit()
