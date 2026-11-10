extends "res://tools/kanto_expansion_review.gd"

const Art = preload("res://scripts/view/item_palette.gd")
const Game = preload("res://scripts/game.gd")
const DEST := "res://docs/map_item_review/"
const ICONS := ["oran_berry","sitrus_berry","pecha_berry","leppa_berry","lum_berry","potion","revive","escape_rope","everstone"]

class Contact:
	extends Node2D
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0,0,720,360),Color("293530"))
		for index in ICONS.size()+1:
			var at := Vector2((index%5)*144,(index/5)*180)
			var id: String = ICONS[index] if index<ICONS.size() else "item_ball"
			var source: Texture2D=ItemDB.icon(id) if index<ICONS.size() else load("res://assets/fx/item_ball.png")
			var after := Art.texture(source,index==ICONS.size())
			draw_string(font,at+Vector2(8,22),id,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			for side in 2:
				var tex: Texture2D=source if side==0 else after
				var size := tex.get_size()*2.0
				draw_texture_rect(tex,Rect2(at+Vector2(36+side*72,84)-size/2.0,size),false)
			draw_string(font,at+Vector2(8,140),"BEFORE / AFTER",HORIZONTAL_ALIGNMENT_LEFT,-1,12)

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	var vp := SubViewport.new()
	vp.size=Vector2i(720,360)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp);vp.add_child(Contact.new())
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(DEST+"items-before-after.png")
	vp.queue_free();await process_frame
	SaveData.path="user://save_map_item_review.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	Game.starter="charmander"
	var report := []
	for fixture in [
		{"id":"road","place":"kanto_south","tile":Vector2i(23,209)},
		{"id":"ledge","place":"kanto_south","tile":Vector2i(19,202)},
		{"id":"trees","place":"kanto_south","tile":Vector2i(33,188)},
		{"id":"grass","place":"kanto_south","tile":Vector2i(23,209)},
		{"id":"forest","place":"viridian_forest","tile":Vector2i(5,16)},
		{"id":"city","place":"saffron_city","tile":Vector2i(24,40)},
		{"id":"cave","place":"mt_moon_1f","tile":Vector2i(-1,-1)},
		{"id":"lab","place":"oaks_lab","tile":Vector2i(-1,-1)},
		{"id":"center","place":"viridian_center","tile":Vector2i(7,4)},
		{"id":"house","place":"players_house_2f","tile":Vector2i(7,4)},
		{"id":"coast","place":"kanto_world","tile":Vector2i(-1,-1)}]:
		if "--grass-only" in OS.get_cmdline_user_args() and fixture.id!="grass": continue
		Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
		await open_fixture(fixture.place)
		game.ui_root.visible=false
		game.view3d.set_process(false)
		if fixture.tile.x>=0: game.world.player.position=Arena.resolve(Arena.tile_center(fixture.tile),game.world.player.radius)
		if fixture.id=="grass":
			var selected := Vector2.INF
			var reference := Arena.tile_center(Vector2i(23,209))
			for y in range(200,211):
				for x in range(15,36):
					var tile := Vector2i(x,y)
					var at := Arena.tile_center(tile)
					if not Arena.is_grass(tile) or Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1: continue
					if selected==Vector2.INF or at.distance_squared_to(reference)<selected.distance_squared_to(reference): selected=at
			assert(selected!=Vector2.INF,"Grass fixture must be actual walkable tall grass")
			game.world.player.position=selected
		if fixture.id=="coast":
			game.world.player.position=game.bird_event.arrival_point("cinnabar_island")
			assert(game.world.player.position!=Vector2.INF)
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		var placed := []
		for index in 5:
			var desired: Vector2=game.world.player.position+Vector2((index-2)*20,-30)
			var chosen := Vector2.INF
			for dy in range(-2,3):
				for dx in range(-2,3):
					var candidate := desired+Vector2(dx,dy)*8.0
					if Arena.blocks(candidate,2.0) or Arena.is_water(Arena.tile_of(candidate)): continue
					if not placed.is_empty() and placed.any(func(p): return p.distance_to(candidate)<14.0): continue
					if chosen==Vector2.INF or candidate.distance_squared_to(desired)<chosen.distance_squared_to(desired): chosen=candidate
			if chosen==Vector2.INF: continue
			placed.append(chosen)
			var item := LootItem.new()
			item.setup(ICONS[index],chosen)
			item.age=1.0;item.update_visual(0.0)
			game.world.add_child(item);game.world.drops.append(item)
		for i in 24:
			# Visual-only stepping prevents automatic collection during inspection.
			game.world._step_tall_grass()
			game.world.step_visual(1.0/60.0)
			game.view3d._process(1.0/60.0)
			await process_frame
		await RenderingServer.frame_post_draw
		assert(DisplayServer.window_get_size()==Vector2i(384,216))
		root.get_texture().get_image().save_png(DEST+fixture.id+".png")
		for item in game.world.drops:
			assert(item.texture.get_meta("world_item_palette",false))
			var sprite: Sprite3D=game.view3d._sprites[item.get_instance_id()].sprite
			assert(not sprite.no_depth_test,"Items respect native scene occlusion")
			assert(sprite.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		report.append({"fixture":fixture.id,"place":fixture.place,"items":placed.size(),"depth_test":true,"window":[384,216]})
		print("MAP ITEM AUDIT ",fixture.id," items=",placed.size())
	var report_name := "grass-consistency-checks.json" if "--grass-only" in OS.get_cmdline_user_args() else "native-checks.json"
	FileAccess.open(DEST+report_name,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free()
	quit()
