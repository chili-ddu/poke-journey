extends GutTest
const Canopy = preload("res://scripts/view/tree_canopy_3d.gd")

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())

func test_native_tree_columns_form_exactly_one_whole_tree_each() -> void:
	for name in ["kanto_field","kanto_south","kanto_north","kanto_east","viridian_forest","arena_route1","arena_viridian_forest"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/"+name+"/hd2d_cards.json"))
		var source: Array=data.cards.filter(func(c):return c.size()>9 and int(c[9])==1)
		var trees := Canopy.groups(data.cards)
		var width := 3 if name in ["viridian_forest","arena_viridian_forest"] else 2
		assert_eq(trees.size()*width,source.size(),"Every original source column belongs to one tree: "+name)
		var index := 0
		for tree in trees:
			assert_eq(int(tree.width),width)
			for column in tree.columns:
				assert_true(column==source[index],"Column order and native coordinates stay intact")
				index+=1

func test_crown_has_width_and_depth_while_trunk_and_tip_stay_anchored() -> void:
	var root := Vector3(10,2,20)
	var slope := tan(deg_to_rad(40.0))
	for dimensions in [Vector2(2,3),Vector2(3,4)]:
		var width: float=dimensions.x
		var height: float=dimensions.y
		var trunk := Canopy.point(root,width,height,width*0.25,0.2,1.0,slope)
		assert_almost_eq(trunk,root+Vector3(-width*0.25,0.2,0),Vector3.ONE*0.00001,"Trunk keeps its original footprint")
		var left := Canopy.point(root,width,height,0,1.4,1.0,slope)
		var right := Canopy.point(root,width,height,width,1.4,1.0,slope)
		var front := Canopy.point(root,width,height,width*0.5,1.4,1.0,slope)
		assert_gt(right.x-left.x,width*1.1,"Only foliage gets a modest wider silhouette")
		assert_gt(front.z-root.z,0.15)
		assert_lt(left.z-root.z,-0.15)
		var projection_shift := (front.z-root.z)*sin(deg_to_rad(40.0))-(front.y-root.y-1.4)*cos(deg_to_rad(40.0))
		assert_lt(absf(projection_shift),0.06,"Depth preserves the native crown outline on screen")
		assert_almost_eq(Canopy.point(root,width,height,width*0.5,height,1.0,slope),root+Vector3.UP*height,Vector3.ONE*0.00001,"Tree tip stays at the original height")

func test_mesh_uses_one_ground_height_and_unbroken_source_column_joins() -> void:
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	var path: String=DungeonDB.theme().map
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
	var tree: Dictionary=Canopy.groups(data.cards).filter(func(t):return int(t.x)==12 and int(t.z)==202)[0]
	var old_left := Arena.ground_height(Vector2(12.5,202)*Arena.TILE)
	var old_right := Arena.ground_height(Vector2(13.5,202)*Arena.TILE)
	assert_gt(absf(old_left-old_right),0.02,"Fixture used to split one tree across different ground levels")
	var root := Canopy.root_of(tree,true)
	var atlas: Texture2D=load(path+"/hd2d_atlas.png")
	var node: MeshInstance3D=Canopy.build(tree.columns,atlas,1.0,true,tan(deg_to_rad(40.0)))
	var arrays := node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var size := atlas.get_size()
	var bottom := 0
	var seam := {}
	var uv_area := 0.0
	for i in vertices.size():
		assert_almost_eq(normals[i].length(),1.0,0.00001)
		for column in 2:
			var source: Array=tree.columns[column]
			var v0 := float(source[4])/size.y
			var v1 := (float(source[4])+float(source[2])*16.0)/size.y
			if absf(uv[i].y-v1)<0.000001:
				assert_almost_eq(vertices[i].y,root.y,0.00001)
				assert_almost_eq(vertices[i].z,root.z,0.00001)
				bottom+=1
			var join_u := (float(source[3])+(16.0 if column==0 else 0.0))/size.x
			if absf(uv[i].x-join_u)<0.000001 and uv[i].y>=v0-0.000001 and uv[i].y<=v1+0.000001:
				var key := roundi((uv[i].y*size.y-float(source[4]))*1024.0)
				if seam.has(key):assert_almost_eq(vertices[i],seam[key],Vector3.ONE*0.00001,"Native half-images share the same physical edge")
				else:seam[key]=vertices[i]
	for i in range(0,indices.size(),3):uv_area+=absf((uv[indices[i+1]]-uv[indices[i]]).cross(uv[indices[i+2]]-uv[indices[i]]))*0.5
	assert_gt(bottom,0)
	assert_eq(seam.size(),Canopy.ROWS.size())
	assert_almost_eq(uv_area,float(tree.width)*16.0*float(tree.height)*16.0/(size.x*size.y),0.0000001,"The source image is used once; no duplicate crown or trunk")
	node.free()

func test_tree_only_scenery_uses_one_batch_without_legacy_flat_duplicates() -> void:
	DungeonDB.set_current("arena_route1")
	Arena.configure(DungeonDB.theme())
	var view := View3D.new()
	view.root3d=Node3D.new()
	view.add_child(view.root3d)
	view._build_cards(DungeonDB.theme().map)
	var node: MeshInstance3D=view.root3d.get_node("TreeCanopies")
	assert_eq(int(node.get_meta("trees")),334)
	assert_eq(int(node.get_meta("source_columns")),668)
	assert_true(node.material_override is StandardMaterial3D)
	view.free()
