extends GutTest

func test_outdoor_sprites_retain_source_pixels_and_do_not_merge_vertically() -> void:
	for place in ["kanto_north", "kanto_east"]:
		var dir: String = "res://assets/maps/"+place+"/"
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"hd2d_cards.json"))
		var source := (load(dir+"preview.png") as Texture2D).get_image()
		var atlas := (load(dir+"hd2d_atlas.png") as Texture2D).get_image()
		var selected := {}
		for obj in d.city_outdoor_props.objects:
			for xy in obj.tiles:selected[Vector2i(int(xy[0]),int(xy[1]))]=obj.kind
		var checked := 0
		for card in d.cards:
			# Trees are independently authored above their footprint; their anchor may share a fence cell.
			if card.size()>9 and int(card[9])==1:continue
			var tile := Vector2i(int(card[0]),int(card[1]))
			if not selected.has(tile):continue
			assert_eq(int(card[2]),1,"Fence, bicycle and flower cannot become vertical strips")
			assert_true(card.size()>9 and int(card[9]) in [4,5],"No duplicate generic card")
			if card.size()<10 or int(card[9]) not in [4,5]:continue
			checked+=1
			var opaque := 0
			var transparent := 0
			for y in 16:
				for x in 16:
					var pixel := atlas.get_pixel(int(card[3])+x,int(card[4])+y)
					if pixel.a==0:
						transparent+=1
					else:
						opaque+=1
						assert_eq(pixel,source.get_pixel(tile.x*16+160+x,tile.y*16+160+y),"Original sprite color")
			assert_gt(opaque,0)
			if selected[tile]!="sign":
				assert_gt(transparent,0,"Native lawn is removed around object")
		assert_gt(checked,20)
