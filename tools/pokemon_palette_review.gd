extends SceneTree

const Palette = preload("res://scripts/view/pokemon_palette.gd")
const OUT := "res://docs/pokemon_palette_review/"
const EXAMPLES := [[1,"BULBASAUR"],[7,"SQUIRTLE"],[25,"PIKACHU"],[10,"CATERPIE"],[16,"PIDGEY"],[19,"RATTATA"],[35,"CLEFAIRY"],[41,"ZUBAT"],[54,"PSYDUCK"],[74,"GEODUDE"],[113,"CHANSEY"],[133,"EEVEE"]]

class Contact:
	extends Node2D
	var time := 0.0
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,640),Color("27322f"))
		var font := ThemeDB.fallback_font
		for index in EXAMPLES.size():
			var entry: Array=EXAMPLES[index]
			var origin := Vector2((index%3)*320,(index/3)*160)
			draw_string(font,origin+Vector2(12,20),"%03d / %s"%entry,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e3dac5"))
			draw_string(font,origin+Vector2(16,42),"BEFORE",HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			draw_string(font,origin+Vector2(176,42),"AFTER",HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			var anim: Dictionary=MonSprite.load_set(int(entry[0])).Walk
			for direction in 2:
				var raw := MonSprite.visual_frame(anim,direction*2,time)
				var before := Look.selout_frame(raw.tex,raw.src)
				var after := Palette.frame(raw,int(entry[0]))
				# Same source box, same integer 2x scale and identical foot anchor.
				var size: Vector2 = raw.src.size*2.0
				var at: Vector2 = origin+Vector2(48+direction*72,104)-size/2.0
				draw_texture_rect_region(before.tex,Rect2(at,size),before.src)
				draw_texture_rect_region(after.tex,Rect2(at+Vector2(160,0),size),after.src)

func _init() -> void: call_deferred("run")

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size=Vector2i(960,640)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var contact := Contact.new()
	viewport.add_child(contact)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT+"comparison.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"motion"))
	for frame in 48:
		contact.time=float(frame)/30.0
		contact.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().get_region(Rect2i(0,0,960,160)).save_png(OUT+"motion/%03d.png"%frame)
	viewport.queue_free()
	await process_frame
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_pokemon_palette_review.cfg"
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.stream.clear();game.banner_t=0;game.ui_root.visible=false
	game.world.player.position=Arena.tile_center(Vector2i(23,209))
	for index in 5:
		var species: String=["bulbasaur","squirtle","pikachu","eevee","clefairy"][index]
		var mon := Enemy.new()
		mon.setup_enemy(species,12,game.world.rng)
		mon.position=game.world.player.position+Vector2((index-2)*25,-22)
		mon.facing=Vector2.DOWN;mon.frozen=true
		game.world.add_child(mon);game.world.enemies.append(mon)
	for i in 45:
		game.world.step_visual(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	root.get_texture().get_image().save_png(OUT+"in-game.png")
	for mon in game.world.enemies:
		if game.view3d._sprites.has(mon.get_instance_id()):
			assert(game.view3d._sprites[mon.get_instance_id()].sprite.texture.get_meta("authored_palette",false))
	game.free()
	print("Saved Pokemon palette contact sheet and native 384x216 scene")
	quit()
