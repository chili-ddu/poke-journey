extends GutTest

const Palette = preload("res://scripts/view/pokemon_palette.gd")

func test_outline_preserves_internal_ink_and_fire_marker() -> void:
	var source := Image.create(7,7,false,Image.FORMAT_RGBA8)
	source.fill_rect(Rect2i(1,1,5,5),Color.BLACK)
	source.fill_rect(Rect2i(2,2,3,3),Color.hex(0x5fb727ff))
	source.set_pixel(3,3,Color.BLACK)
	source.set_pixel(4,3,Color.hex(0xfff700ff))
	var bytes := source.get_data()
	var result := Palette.process(source,5)
	assert_eq(result.get_pixel(3,3),Color.BLACK,"Internal eye/mouth ink stays dark")
	assert_ne(result.get_pixel(2,1),Color.BLACK,"Exposed outline inherits the body hue")
	assert_eq(result.get_pixel(4,3),source.get_pixel(4,3),"Fire-tail light marker stays exact")
	assert_eq(source.get_data(),bytes)

func test_all_available_species_keep_alpha_anchors_and_animation_timing() -> void:
	var count := 0
	for directory in DirAccess.get_directories_at("res://assets/sprites"):
		if not directory.is_valid_int(): continue
		var dex := int(directory)
		var sprites := MonSprite.load_set(dex)
		if sprites.is_empty() or dex==4: continue
		count+=1
		for name in ["Walk","Idle","Attack"]:
			if not sprites.has(name): continue
			var anim: Dictionary=sprites[name]
			var length := MonSprite.anim_length(anim)
			for row in range(0,int(anim.rows),2):
				for phase in [0.0,0.5]:
					var time: float=float(anim.durations[0])*MonSprite.TICK*phase
					var raw := MonSprite.visual_frame(anim,row,time)
					var polished := MonSprite.display_frame(anim,row,time)
					assert_eq(polished.body_center,raw.body_center)
					assert_eq(polished.src.size,raw.src.size)
					var before: PackedByteArray = raw.tex.get_image().get_region(Rect2i(raw.src)).get_data()
					var after: PackedByteArray = polished.tex.get_image().get_region(Rect2i(polished.src)).get_data()
					var same: bool = before.size()==after.size()
					if same:
						for p in range(3,before.size(),4):
							if before[p]!=after[p]: same=false;break
					assert_true(same,"Dex %d %s: exact source silhouette/alpha"%[dex,name])
					assert_true(polished.tex.get_meta("authored_palette",false))
			assert_eq(MonSprite.anim_length(anim),length)
	assert_gte(count,120,"Retouch every available species, not just preview examples")

func test_shiny_palette_and_original_switch_remain_available() -> void:
	for dex in [1,7,25,133]:
		var shiny: Dictionary=MonSprite.load_set(dex,true).Walk
		var raw := MonSprite.visual_frame(shiny,0,0.0)
		assert_same(MonSprite.display_frame(shiny,0,0.0).tex,raw.tex)
	var normal: Dictionary=MonSprite.load_set(7).Walk
	var previous := Palette.enabled
	Palette.enabled=false
	assert_same(MonSprite.display_frame(normal,0,0.0).tex,normal.tex)
	Palette.enabled=previous
