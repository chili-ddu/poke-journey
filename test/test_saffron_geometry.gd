extends GutTest

const DIR="res://assets/maps/saffron_city/"

func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR+"hd2d_cards.json"))

func test_original_paving_is_preserved_without_raised_road_fragments() -> void:
	var d:=data()
	var source: Image=(load(DIR+"preview.png") as Texture2D).get_image()
	var floor_image: Image=(load(DIR+"hd2d_floor.png") as Texture2D).get_image()
	var ground:={}
	var changed:=0
	var atlas: Image=(load(DIR+"hd2d_atlas.png") as Texture2D).get_image()
	for xy in d.saffron_outdoors.ground_tiles:
		var tile:=Vector2i(int(xy[0]),int(xy[1]));ground[tile]=true
		for y in 16:
			for x in 16:
				var px:=tile*16+Vector2i(160+x,160+y)
				if floor_image.get_pixelv(px)!=source.get_pixelv(px):changed+=1
	assert_eq(changed,0,"The original paving must not become flat blank patches")
	assert_gt(ground.size(),600)
	for card in d.cards:
		if card.size()>9 and int(card[9])==1:continue
		for row in int(card[2]):
			if not ground.has(Vector2i(int(card[0]),int(card[1])+row)):continue
			var opaque:=0
			for yy in 16:
				for xx in 16:
					if atlas.get_pixel(int(card[3])+xx,int(card[4])+row*16+yy).a>0:opaque+=1
			assert_eq(opaque,0,"Native ground is never an upright facade")

func test_silph_preserves_all_native_floors_and_a_continuous_roof() -> void:
	var d:=data()
	var columns:=0
	for c in d.cards:
		if c.size()<10 or int(c[9])!=3 or int(c[1])!=16:continue
		if int(c[0])<29 or int(c[0])>37:continue
		columns+=1
		assert_eq(int(c[2]),15)
		assert_eq(float(c[5]),5.0)
		assert_eq(float(c[2])-float(c[5]),10.0,"Window floors belong to the facade, not the roof")
	assert_eq(columns,9)

func test_sign_frames_and_letters_survive_the_rear_door_floor_mask() -> void:
	var source: Image=(load(DIR+"preview.png") as Texture2D).get_image()
	var sign_image: Image=(load(DIR+"hd2d_saffron_sign_29_14_front.png") as Texture2D).get_image()
	# This native sign fills its tile; pavement-derived masks must not remove
	# the navy frame shared with the southern gate's walkable rear threshold.
	for y in 16:
		for x in 16:
			assert_eq(sign_image.get_pixel(x,y),source.get_pixel(29*16+160+x,14*16+160+y),"Intact original sign silhouette and text")

func test_side_door_frames_cannot_become_full_opaque_walls() -> void:
	var count:=0
	for c in data().cards:
		if c.size()<12 or int(c[9])!=3 or int(c[1])!=25 or int(c[0]) not in [1,8,58,65]:continue
		count+=1
		assert_eq(float(c[11]),float(c[5]),"Keep the doorway open instead of stretching a frame pixel into a wall")
	assert_eq(count,4)

func test_blue_fence_turns_connect_to_vertical_runs() -> void:
	var cases=[
		[Vector2i(14,9),0x318,Vector2i(14,10),0x320],
		[Vector2i(14,42),0x320,Vector2i(14,43),0x328],
		[Vector2i(53,14),0x31a,Vector2i(53,15),0x322],
		[Vector2i(53,42),0x322,Vector2i(53,43),0x32a],
		[Vector2i(28,22),0x346,Vector2i(28,23),0x344],
		[Vector2i(38,22),0x347,Vector2i(38,23),0x345]]
	for pair in cases:
		var first:=View3D.fence_panels(pair[0],pair[1])
		var next:=View3D.fence_panels(pair[2],pair[3])
		assert_false(first.is_empty());assert_false(next.is_empty())
		assert_eq(first[0].b,next[0].a,"No gap where a native fence turns")
	var d:=data()
	for record in d.saffron_outdoors.fences:
		if not record.turned:continue
		var p:=Vector2i(int(record.tile[0]),int(record.tile[1]))
		var panels:=View3D.fence_panels(p,int(record.mid))
		assert_gt(panels.size(),0)
		for panel in panels:assert_gt(panel.a.distance_to(panel.b),0.0)

func test_forest_padding_uses_ground_below_complete_tree_crowns() -> void:
	var d:=data()
	var outside:=0
	for c in d.cards:
		if c.size()<10 or int(c[9])!=1:continue
		if int(c[0])<0 or int(c[0])>=66 or int(c[1])<0 or int(c[1])>=55:outside+=1
	assert_gt(outside,500,"The outer forest is upright scenery instead of a flat duplicate")
	var floor_image: Image=(load(DIR+"hd2d_floor.png") as Texture2D).get_image()
	var source: Image=(load(DIR+"preview.png") as Texture2D).get_image()
	for y in 16:
		for x in 16:
			assert_eq(floor_image.get_pixel(x,y),source.get_pixel(31*16+160+x,160+y),"Plain native lawn under the padding trees")
