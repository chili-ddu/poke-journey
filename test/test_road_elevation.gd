extends GutTest
const LEDGE_HEIGHT := 0.35

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())

func test_road_terraces_have_height_and_shared_edges_except_native_ledge_faces() -> void:
	var seen := {}
	for place in ["kanto_south","kanto_east"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		assert_gt(Arena.max_elevation,LEDGE_HEIGHT)
		var discontinuities := 0
		for tile in Arena._elevated_ledges:
			var direction: Vector2i=Vector2i(Arena.LEDGE_DIRS[Arena.ledge_at(tile.x,tile.y)])
			var high := Arena.ground_height(Arena.tile_center(tile-direction))
			var low := Arena.ground_height(Arena.tile_center(tile+direction))
			if high-low>0.1:seen[Arena.area_at(Arena.tile_center(tile))]=true
		for y in int(Arena.map.height)-1:
			for x in int(Arena.map.width)-1:
				var here: Array=Arena._elevation[y][x]
				var right: Array=Arena._elevation[y][x+1]
				var below: Array=Arena._elevation[y+1][x]
				if maxf(absf(float(here[1])-float(right[0])),absf(float(here[2])-float(right[3])))>0.0001:
					discontinuities+=1
					fail_test("Full-cell banks must not break a shared east/west boundary")
				if maxf(absf(float(here[3])-float(below[0])),absf(float(here[2])-float(below[1])))>0.0001:
					discontinuities+=1
					fail_test("Full-cell banks must not break a shared north/south boundary")
		assert_eq(discontinuities,0,"Height changes happen inside the blocked bank, not through disconnected tile edges")
		for water in Arena._water:
			var corners := Arena.ground_corners(water)
			for height in corners:assert_almost_eq(float(height),float(corners[0]),0.0001,"Each water body has a level surface at its regional altitude")
			for dir in [Vector2i.RIGHT,Vector2i.DOWN]:
				if Arena.is_water(water+dir):assert_almost_eq(Arena.ground_height(Arena.tile_center(water)),Arena.ground_height(Arena.tile_center(water+dir)),0.0001)
	for route in ["route1","route2","route3","route4","route5","route6"]:assert_true(seen.has(route),route+" has an actual drop")

func test_height_interpolation_matches_triangle_diagonal_and_resets_on_map_change() -> void:
	Arena.configure({"map":"res://assets/maps/kanto_field"})
	var point := Arena.tile_center(Vector2i(24,185))
	assert_almost_eq(View3D.to3d(point,0.5).y,Arena.ground_height(point)+0.5,0.0001)
	Arena._elevation=[[[0.,1.,2.,3.]]]
	assert_almost_eq(Arena.ground_height(Vector2(0.75,0.25)*Arena.TILE),1.0,0.0001)
	assert_almost_eq(Arena.ground_height(Vector2(0.25,0.75)*Arena.TILE),2.0,0.0001)
	Arena.configure({"map":"res://assets/maps/oaks_lab"})
	assert_true(Arena._elevation.is_empty())
	assert_eq(Arena.ground_height(point),0.0)

func test_actual_road_floor_and_vertical_faces_are_built() -> void:
	for place in ["kanto_south","kanto_east"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		var dir: String=DungeonDB.theme().map
		var view := View3D.new()
		view.root3d=Node3D.new()
		view.add_child(view.root3d)
		view._build_floor(dir)
		assert_true(view.root3d.has_node("RoadElevationFloor"))
		var wall: MeshInstance3D=view.root3d.get_node("RoadLedgeWalls")
		assert_gt(int(wall.get_meta("faces")),10)
		var vertices: PackedVector3Array=wall.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var highest := 0.0
		var foot_depth := 0.0
		for v in vertices:
			highest=maxf(highest,v.y)
			var tile := Vector2i(int(floor(v.x)),int(floor(v.z)))
			if not Arena._ledge_patches.has(tile):continue
			var local := Vector2(v.x-tile.x,v.z-tile.y)
			if local.x<0.0001 or local.y<0.0001 or local.x>0.9999 or local.y>0.9999:continue
			var code: String=Arena._ledge_patches[tile].direction
			if code=="":continue
			var depth: float={"s":local.y,"n":1-local.y,"e":local.x,"w":1-local.x}[code]
			foot_depth=maxf(foot_depth,depth)
		assert_gt(highest,LEDGE_HEIGHT)
		assert_lte(foot_depth,0.8751,"The visible earth foot cannot bulge forward on an end ramp")
		var turf: MeshInstance3D=view.root3d.get_node("RoadLedgeRims")
		# The environment palette creates an ImageTexture without a resource path.
		var expected_ground: Texture2D=View3D.MapPalette.texture(View3D.HgssEnvironment.surface(dir, "elevation_floor.png"))
		assert_same((turf.material_override as StandardMaterial3D).albedo_texture,expected_ground,"Bank shoulders retain their own native grass/path instead of a repeated lawn tile")
		var arrays := turf.mesh.surface_get_arrays(0)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"/map.json"))
		var pad := float(source.pad)
		var size := Vector2(float(source.width)+pad*2,float(source.height)+pad*2)
		var error := 0.0
		var height_error := 0.0
		for i in points.size():
			var expected := (Vector2(points[i].x,points[i].z)+Vector2.ONE*pad)/size
			error=maxf(error,expected.distance_to(uv[i]))
			height_error=maxf(height_error,absf(points[i].y-Arena.ground_height(Vector2(points[i].x,points[i].z)*Arena.TILE)))
		assert_lt(error,0.000001,"Every bank ground pixel uses the same world-to-texture coordinates as the road floor")
		assert_lt(height_error,0.0002,"Clipped round closures stay on the original terrain surface")
		view.free()


func test_route1_retains_height_above_its_ledges_instead_of_returning_to_zero() -> void:
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	var south := Arena.ground_height(Arena.tile_center(Arena.area_tile("route1",Vector2i(12,38))))
	var above_lower_ledge := Arena.ground_height(Arena.tile_center(Arena.area_tile("route1",Vector2i(12,30))))
	var farther_north := Arena.ground_height(Arena.tile_center(Arena.area_tile("route1",Vector2i(12,22))))
	var north := Arena.ground_height(Arena.tile_center(Arena.area_tile("route1",Vector2i(12,2))))
	var city := Arena.ground_height(Arena.tile_center(Arena.area_tile("viridian_city",Vector2i(24,20))))
	assert_gt(above_lower_ledge-south,LEDGE_HEIGHT*0.5,"First upper region rises")
	assert_gt(farther_north-south,LEDGE_HEIGHT*0.5,"High ground persists beyond the previous eight-tile falloff")
	assert_gt(north-south,LEDGE_HEIGHT*2.0,"Successive terraces accumulate toward the city")
	assert_almost_eq(north,city,0.2,"City keeps the incoming road altitude")
	for id in ["pallet_town","viridian_city","pewter_city","cerulean_city"]:
		var heights := []
		for area in Arena._areas:
			if area.id!=id:continue
			for offset in [Vector2i.ONE,area.rect.size-Vector2i(2,2),area.rect.size/2]:
				heights.append(Arena.ground_height(Arena.tile_center(area.rect.position+Vector2i(offset))))
		for height in heights:assert_almost_eq(float(height),float(heights[0]),0.0001,"City has one persistent regional elevation")
	assert_gt(Arena.ground_height(Arena.tile_center(Vector2i(24,160))),LEDGE_HEIGHT*2.0)
	assert_almost_eq(Arena.ground_height(Vector2(-Arena.TILE,160*Arena.TILE)),Arena.ground_height(Vector2(0,160*Arena.TILE)),0.0001,"Padding continues the elevated city")

func test_cliff_banks_share_every_edge_at_straights_turns_and_ends() -> void:
	var kinds := {}
	for place in ["kanto_south","kanto_east"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		var res := Arena._ledge_resolution
		for tile in Arena._ledge_patches:
			var patch: Dictionary=Arena._ledge_patches[tile]
			kinds[patch.kind]=true
			if patch.direction=="":assert_true(Arena.solid_at(tile.x,tile.y),"Turning pieces keep their solid native footprint")
			else:assert_ne(Arena.ledge_at(tile.x,tile.y),0,"Straight banks keep their native jump direction")
			for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var neighbor: Vector2i=tile+side
				for i in res+1:
					var t := float(i)/res
					var own: float
					var other: float
					if side==Vector2i.UP:own=patch.heights[0][i]
					elif side==Vector2i.DOWN:own=patch.heights[res][i]
					elif side==Vector2i.LEFT:own=patch.heights[i][0]
					else:own=patch.heights[i][res]
					if Arena._ledge_patches.has(neighbor):
						var grid: Array=Arena._ledge_patches[neighbor].heights
						if side==Vector2i.UP:other=grid[res][i]
						elif side==Vector2i.DOWN:other=grid[0][i]
						elif side==Vector2i.LEFT:other=grid[i][res]
						else:other=grid[i][0]
					else:
						var c := Arena.ground_corners(neighbor)
						if side==Vector2i.UP:other=lerpf(c[3],c[2],t)
						elif side==Vector2i.DOWN:other=lerpf(c[0],c[1],t)
						elif side==Vector2i.LEFT:other=lerpf(c[1],c[2],t)
						else:other=lerpf(c[0],c[3],t)
					assert_almost_eq(own,other,0.00002,"Shared bank boundary has no corner crack")
			# Queries within the blocked band use the actual tessellated surface.
			for y in res:
				for x in res:
					var expected := (float(patch.heights[y][x])+float(patch.heights[y+1][x+1]))*0.5
					var pos := (Vector2(tile)+Vector2((x+0.5)/res,(y+0.5)/res))*Arena.TILE
					assert_almost_eq(Arena.ground_height(pos),expected,0.00002)
	for kind in ["straight","end","outer","inner"]:assert_true(kinds.has(kind),kind+" geometry is covered")

func test_native_corner_cards_are_removed_without_erasing_adjacent_art() -> void:
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/hd2d_cards.json"))
	var expected := 0
	for card in source.cards:
		for row in int(card[2]):
			if not Arena._ledge_patches.has(Vector2i(int(card[0]),int(card[1])+row)):expected+=1
	var actual := 0
	for card in View3D._ledge_card_fragments(source.cards):
		assert_lt(int(card[5]),int(card[2]))
		for row in int(card[2]):
			assert_false(Arena._ledge_patches.has(Vector2i(int(card[0]),int(card[1])+row)),"No old corner post behind the rebuilt bank")
			actual+=1
	assert_eq(actual,expected,"Every non-cliff source row is preserved")


func test_entire_banks_keep_flat_rims_and_full_height_at_their_ends() -> void:
	for place in ["kanto_south","kanto_east"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/elevation.json"))
		assert_eq(data.solver.method,"full_cell_terrace_levels")
		assert_eq(float(data.height),LEDGE_HEIGHT,"Jumpable banks use the tuned low-step height")
		for bank in data.solver.banks:
			assert_almost_eq(float(bank.upper)-float(bank.lower),LEDGE_HEIGHT,0.00002,"Each connected bank has one exact height step")
			for xy in bank.cells:
				var tile := Vector2i(int(xy[0]),int(xy[1]))
				var code := Arena.ledge_at(tile.x,tile.y)
				if code==0:continue
				var corners := Arena.ground_corners(tile)
				var high: Array
				var low: Array
				if code==4:high=[corners[0],corners[1]];low=[corners[3],corners[2]]
				elif code==3:high=[corners[3],corners[2]];low=[corners[0],corners[1]]
				elif code==1:high=[corners[0],corners[3]];low=[corners[1],corners[2]]
				else:high=[corners[1],corners[2]];low=[corners[0],corners[3]]
				for height in high:assert_almost_eq(float(height),float(bank.upper),0.00002,"Upper rim stays level through the last bank cell")
				for height in low:assert_almost_eq(float(height),float(bank.lower),0.00002,"Lower rim cannot sag in the middle or collapse at an end")
				var dir: Vector2i = Vector2i(Arena.LEDGE_DIRS[code])
				for sign in [-1,1]:
					var landing: Vector2i = tile+dir*sign
					if Arena.solid_at(landing.x,landing.y) or Arena.is_water(landing) or Arena._ledge_patches.has(landing):continue
					var expected := float(bank.upper) if sign<0 else float(bank.lower)
					for height in Arena.ground_corners(landing):assert_almost_eq(float(height),expected,0.00002,"Walkable landing ground does not form a hollow below the bank")

func test_raised_rustle_uses_the_static_grass_mesh_and_ramp() -> void:
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	for tile in [Vector2i(33,186),Vector2i(29,206)]:_assert_grass_alignment(tile)

func _assert_grass_alignment(tile: Vector2i) -> void:
	assert_true(Arena.is_grass(tile))
	var view := View3D.new()
	add_child(view)
	view.root3d=Node3D.new()
	view.add_child(view.root3d)
	view.cam=Camera3D.new()
	view.root3d.add_child(view.cam)
	view.cam.position=View3D.to3d(Arena.tile_center(tile))+Vector3(0,9,12)
	var effect := Fx.new()
	effect.kind="tallgrass"
	effect.tile=tile
	view._sync_fx_grass(effect,{})
	var entry: Dictionary=view._sprites[effect.get_instance_id()]
	assert_true(entry.has("layered_grass"),"Seamless map aliases use the actual floor theme")
	assert_false(entry.has("grass"),"No second, ungrounded fallback card")
	var node: MeshInstance3D=entry.layered_grass
	var ground := View3D.flora_ground_frame(tile)
	assert_gt(ground.origin.y,0.0)
	assert_gt(absf(ground.basis.z.y),0.001,"This fixture exercises a real walkable incline")
	# Build the static atlas card at the same tile, independently of the effect.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	view._ground_static_geometry=true
	view._build_layered_flora(st,tile.x,tile.y+1,0,1,0,1)
	var static_vertices: PackedVector3Array=st.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var local_vertices: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(local_vertices.size(),static_vertices.size())
	for i in local_vertices.size():
		assert_almost_eq(static_vertices[i],ground*local_vertices[i],Vector3.ONE*0.00002,"Static leaves and rustle share one slope frame")
	for i in 6:
		var vertex := static_vertices[i]
		assert_almost_eq(vertex.y,Arena.ground_height(Vector2(vertex.x,vertex.z)*Arena.TILE)+0.015,0.00002,"Low leaves follow the actual bent tile, not an approximate plane")
	effect.free()
	view.free()

func test_tail_pixel_anchor_follows_billboard_and_local_height() -> void:
	var view := View3D.new()
	add_child(view)
	view.cam=Camera3D.new()
	view.add_child(view.cam)
	view.cam.rotation.x=-0.6
	var sprite := Sprite3D.new()
	sprite.region_rect=Rect2(0,0,32,40)
	sprite.offset=Vector2(2,14)
	sprite.pixel_size=1.0/24.0
	var pixel := Vector2(9,28)
	for billboard in [BaseMaterial3D.BILLBOARD_FIXED_Y,BaseMaterial3D.BILLBOARD_ENABLED]:
		sprite.billboard=billboard
		var vertical: Vector3=view.cam.basis.y if billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
		var expected := view.cam.basis.x*(-5.0/24.0)+vertical*(6.0/24.0)
		assert_almost_eq(view.sprite_pixel_position(sprite,pixel),expected,Vector3.ONE*0.00001)
		var height := view.sprite_pixel_position(sprite,pixel).y-sprite.position.y
		var radius := View3D.tail_light_range(height,false)
		sprite.position.y+=4.0
		assert_almost_eq(View3D.tail_light_range(view.sprite_pixel_position(sprite,pixel).y-sprite.position.y,false),radius,0.00001,"Regional altitude cannot enlarge the flame glow")
		sprite.position=Vector3.ZERO
	sprite.free()
	view.free()

func test_native_tile_audit_and_restored_city_road_border() -> void:
	for name in ["kanto_field","kanto_east"]:
		var audit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/"+name+"/terrain_tile_audit.json"))
		assert_true(audit.unexplained_differences.is_empty())
		assert_gt(int(audit.native_tiles_checked),2000)
		assert_eq(int(audit.remaining_wrong_floor_copies),0)
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	for tile in [Vector2i(47,42),Vector2i(47,43),Vector2i(48,39),Vector2i(48,42)]:
		assert_false(Arena.solid_at(tile.x,tile.y),"Former artificial boundary matches the native source")

func test_bank_ends_close_upwards_only_at_open_native_ends() -> void:
	var checked := 0
	for place in ["kanto_south","kanto_east"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		for tile in Arena._ledge_patches:
			var patch: Dictionary=Arena._ledge_patches[tile]
			if patch.direction=="":continue
			var horizontal: bool=patch.direction in ["s","n"]
			var axis := Vector2i.RIGHT if horizontal else Vector2i.DOWN
			for side in [-1,1]:
				var exposed := not Arena._ledge_patches.has(tile+axis*side)
				assert_eq((patch.get("caps",[]) as Array).has(float(side)),exposed,"Connected bank pieces do not get a false end cap")
				var end := Vector2(0 if side<0 else 1,0.5) if horizontal else Vector2(0.5,0 if side<0 else 1)
				var outline: Array=patch.toe_depth
				assert_almost_eq(float(outline[0 if side<0 else -1]),0.625 if exposed else 0.875,0.00001,"Native round closure ends inside the shared foot depth")
				if exposed:
					checked+=1
					var previous := 0.0
					for i in 6:
						var toe := float(outline[i if side<0 else 16-i])
						assert_gte(toe,previous,"Round return joins the full-height face without downward teeth")
						previous=toe
					assert_almost_eq(previous,0.875,0.00001)
	assert_gt(checked,100,"All six roads' exposed ends are covered")

func _polygon_area(points: Array) -> float:
	var area := 0.0
	for i in range(1,points.size()-1):area+=(points[i]-points[0]).cross(points[i+1]-points[0]).length()*0.5
	return area

func test_curved_face_clipping_leaves_no_gap_or_double_surface() -> void:
	var patch := {"direction":"s","cap_toe":[0.6,0.79,0.885,0.885,0.98,0.98,0.98,0.98,0.98,0.98,0.98,0.98,0.98,0.98,0.98,0.98],"rim_top":[0.22,0.22,0.2675,0.315,0.3625,0.315,0.2675,0.22,0.22,0.22,0.2675,0.315,0.315,0.315,0.315,0.2675,0.22]}
	for triangle in [[Vector3(0,1,0),Vector3(0.2,1,0),Vector3(0,0.65,1)],[Vector3(0.2,1,0),Vector3(0.2,0.65,1),Vector3(0,0.65,1)]]:
		var upper := View3D._ledge_boundary(triangle,patch,Vector2.ZERO,1.0,0.35,false)
		var lower := View3D._ledge_boundary(triangle,patch,Vector2.ZERO,1.0,0.35,true)
		var fields := []
		for i in 3:fields.append(Vector2(float(upper[i]),float(lower[i])))
		var face := View3D._clip_ledge_data(triangle,fields,1,true)
		face=View3D._clip_ledge_data(face.points,face.fields,0,true)
		var top := View3D._clip_ledge_polygon(triangle,upper,false)
		var toe := View3D._clip_ledge_polygon(triangle,lower,false)
		assert_gt(_polygon_area(face.points),0.0)
		assert_almost_eq(_polygon_area(top)+_polygon_area(face.points)+_polygon_area(toe),_polygon_area(triangle),0.000001,"Curved rim and toe partition the original triangle exactly")

func test_native_rim_is_gently_uneven_and_joins_straights_and_corners() -> void:
	for place in ["kanto_south","kanto_east"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		for tile in Arena._ledge_patches:
			var patch: Dictionary=Arena._ledge_patches[tile]
			var outline: Array=patch.rim_top
			assert_eq(outline.size(),17)
			assert_gte(float(outline.min()),0.22)
			assert_lte(float(outline.max()),0.410001,"Native lip variation stays within two source pixels")
			assert_gt(float(outline.max())-float(outline.min()),0.04,"The old completely flat rim cannot return")
			var edges := [Vector2(0,0.5),Vector2(1,0.5)] if patch.direction in ["s","n"] else [Vector2(0.5,0),Vector2(0.5,1)]
			if patch.direction=="":edges=[Vector2(0,0.5),Vector2(1,0.5),Vector2(0.5,0),Vector2(0.5,1)]
			for at in edges:assert_almost_eq(View3D.ledge_face_rim(patch,at),0.22,0.00001,"Every turning/straight join shares one turf edge level")
