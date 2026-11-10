extends Node3D

## Places original HGSS grass/cliff/tree/sea textures in the spaces between
## authored fields. Decorative land stays solid; original routes own movement.
const Continent=preload("res://scripts/data/continent_world.gd")
const Palette=preload("res://scripts/view/map_palette.gd")
var chunks: Dictionary={}
var _center:=Vector2i(9999,9999)
var _land:=PackedVector2Array()
var _ridge:=PackedVector2Array()
var _materials: Dictionary={}

func setup() -> void:
	for point in Continent.config().land_outline:_land.append(Vector2(point[0],point[1]))
	for point in Continent.config().ridge_outline:_ridge.append(Vector2(point[0],point[1]))
	for key in ["grass","rock","sea","tree"]:
		var image:=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes(Continent.config()[key+"_texture"]))
		if key=="tree":image=image.get_region(image.get_used_rect())
		var material:=StandardMaterial3D.new()
		material.albedo_texture=Palette.texture(ImageTexture.create_from_image(image))
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo=true
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		if key=="tree":
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold=0.5
		_materials[key]=material
	var sea:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	var bounds:=Arena.bounds().grow(96*Arena.TILE)
	plane.size=bounds.size/Arena.TILE
	sea.mesh=plane
	sea.position=Vector3(bounds.get_center().x/Arena.TILE,-0.25,bounds.get_center().y/Arena.TILE)
	var material: StandardMaterial3D=_materials.sea.duplicate()
	material.uv1_scale=Vector3(plane.size.x,plane.size.y,1)
	sea.material_override=material
	sea.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

func stream(at: Vector2) -> void:
	var center:=Vector2i((at/32.0).floor())
	if center==_center:return
	_center=center
	var keep: Dictionary={}
	for y in range(center.y-1,center.y+2):
		for x in range(center.x-1,center.x+2):
			if x>=0:continue
			var cell:=Vector2i(x,y)
			if Continent.scene().chunk_index.has(cell-Continent.offset()/32):continue
			keep[cell]=true
			if not chunks.has(cell):chunks[cell]=build_chunk(cell)
	for cell in chunks.keys():
		if not keep.has(cell):
			chunks[cell].queue_free();chunks.erase(cell)

func build_chunk(cell: Vector2i) -> Node3D:
	var node:=Node3D.new()
	add_child(node)
	var grass:=SurfaceTool.new();grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock:=SurfaceTool.new();rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trees:=SurfaceTool.new();trees.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts: Dictionary={"grass":0,"rock":0,"tree":0}
	for z in range(cell.y*32,cell.y*32+32,4):
		for x in range(cell.x*32,cell.x*32+32,4):
			var at:=Vector2(x+2,z+2)
			if not Geometry2D.is_point_in_polygon(at,_land):continue
			var ridge:=Geometry2D.is_point_in_polygon(at,_ridge)
			var h:=ridge_height(at) if ridge else 0.0
			if h<=2.0:ridge=false;h=0.0
			if ridge:
				var shade:=0.58+h*0.045
				_quad(rock,Vector3(x,h,z+4),Vector3(4,0,0),Vector3(0,0,-4),4,Color(shade,shade,shade));counts.rock+=1
				for edge in [[Vector3(x,0,z+4),Vector3(4,0,0)],[Vector3(x+4,0,z),Vector3(-4,0,0)],
					[Vector3(x,0,z),Vector3(0,0,4)],[Vector3(x+4,0,z+4),Vector3(0,0,-4)]]:
					_quad(rock,edge[0],edge[1],Vector3(0,h,0),4);counts.rock+=1
			else:
				_quad(grass,Vector3(x,h,z+4),Vector3(4,0,0),Vector3(0,0,-4),4);counts.grass+=1
				for dz in [0,2]:
					for dx in [0,2]:
						_quad(trees,Vector3(x+dx,0,z+dz+1.5),Vector3(2,0,0),Vector3(0,2.5,0),1)
						_quad(trees,Vector3(x+dx,2,z+dz+2),Vector3(2,0,0),Vector3(0,0,-2),1)
						counts.tree+=2
	for entry in [["grass",grass],["rock",rock],["tree",trees]]:
		if counts[entry[0]]==0:continue
		var mesh:=MeshInstance3D.new()
		mesh.mesh=entry[1].commit();mesh.material_override=_materials[entry[0]]
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mesh)
	return node

func ridge_height(at: Vector2) -> float:
	var height:=2.0
	for peak in Continent.config().ridge_peaks:
		height=maxf(height,float(peak[3])*(1.0-at.distance_to(Vector2(peak[0],peak[1]))/float(peak[2])))
	return floorf(height/2.0)*2.0

func _quad(st: SurfaceTool,at: Vector3,across: Vector3,up: Vector3,repeats: float,tint:=Color.WHITE) -> void:
	var points: Array=[at,at+across,at+across+up,at+up]
	var uv: Array=[Vector2(0,repeats),Vector2(repeats,repeats),Vector2(repeats,0),Vector2.ZERO]
	for i in [0,1,2,0,2,3]:
		st.set_color(tint);st.set_uv(uv[i]);st.add_vertex(points[i])
