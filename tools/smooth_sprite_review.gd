extends SceneTree

class Review:
	extends Node2D
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,720),Color("161b25"))
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(24,34),"C / GAME RENDERER SAMPLES",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		var names := ["BULBASAUR", "CHARMANDER", "SQUIRTLE", "ONIX", "GYARADOS", "SHINY CHARMANDER", "NPC WALK", "CLAW EFFECT", "GRASS"]
		for i in 9:
			var origin := Vector2((i%3)*320,60+(i/3)*215)
			draw_string(font,origin+Vector2(20,24),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("5bdcdf"))
			var visual: Dictionary
			if i<6:
				var dex: int = [1,4,7,95,130,4][i]
				var anim: Dictionary = MonSprite.load_set(dex,i==5).Walk
				visual=MonSprite.visual_frame(anim,2,float(anim.durations[0])*MonSprite.TICK*0.6)
			elif i==6:
				var tex: Texture2D=load("res://assets/npcs/prof_oak.png")
				visual=SmoothSprite.horizontal(tex,Npc.FRAME,7,8,0.6)
			elif i==7:
				var fx:=Fx.new()
				fx.text="g4_claw_strike"
				fx.frames=5
				visual=fx.anim_visual(0.32)
				fx.free()
			else:
				var fx:=Fx.new()
				fx.kind="rustle"
				fx.age=0.06
				visual=fx.grass_visual()
				fx.free()
			if i < 7:
				visual=Look.selout_frame(visual.tex,visual.src)
			var image: Image=visual.tex.get_image().get_region(Rect2i(visual.src))
			var used:=image.get_used_rect()
			var region: Rect2=visual.src
			region.position+=Vector2(used.position)
			region.size=Vector2(used.size)
			var scale:=minf(5.0,minf(270.0/maxf(1,region.size.x),145.0/maxf(1,region.size.y)))
			var size:=region.size*floorf(scale)
			draw_texture_rect_region(visual.tex,Rect2(origin+Vector2(160-size.x/2,55),size),region)

func _init() -> void: call_deferred("run")

func run() -> void:
	await CaptureWindow.park(self)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(960,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	viewport.add_child(Review.new())
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	image.save_png("res://docs/smooth_sprite_review/renderer-samples.png")
	print("Saved C renderer samples")
	quit()
