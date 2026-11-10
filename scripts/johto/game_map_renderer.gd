extends Node3D

## Streams original HGSS terrain/props under the normal View3D actors and UI.
const Collection = preload("res://scripts/johto/hgss_map_collection.gd")
const Art = preload("res://scripts/view/hgss_environment.gd")
var collection: Collection
var data: Dictionary
var chunks := {}
var _center := Vector2i(-100,-100)
var _heights := {}

func setup(c: Collection, scene: Dictionary) -> void:
	collection=c
	data=scene

func stream(at: Vector2) -> void:
	var center := Vector2i(((at-Vector2(position.x,position.z)) / 32.0).floor())
	if center == _center: return
	_center=center
	_heights.clear()
	var keep := {}
	for chunk in data.chunks:
		var cell := Vector2i(int(chunk.x),int(chunk.z))
		if absi(cell.x-center.x)>1 or absi(cell.y-center.y)>1: continue
		keep[cell]=true
		if chunks.has(cell): continue
		var parent := Node3D.new()
		parent.position=Vector3(cell.x*32+16,float(chunk.altitude),cell.y*32+16)
		add_child(parent)
		var terrain := Art.model(collection.manifest.assets[chunk.asset]).instantiate() as Node3D
		terrain.scale=Vector3.ONE/16.0
		parent.add_child(terrain)
		_add_floor_collision(terrain)
		_apply_scene_culling(terrain)
		for prop in chunk.props:
			var object := Art.model(collection.manifest.assets[prop.asset]).instantiate() as Node3D
			object.position=Vector3(prop.translation[0],prop.translation[1],prop.translation[2])/16.0
			object.scale=Vector3(prop.scale[0],prop.scale[1],prop.scale[2])/16.0
			parent.add_child(object)
			_apply_scene_culling(object)
		chunks[cell]=parent
	for cell in chunks.keys():
		if not keep.has(cell):
			chunks[cell].queue_free()
			chunks.erase(cell)

func _apply_scene_culling(node: Node) -> void:
	if not data.get("cull_back_faces",false):return
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original: Material=node.get_active_material(i)
			if original is BaseMaterial3D:
				# Instance-local: do not alter shared prefabs in the model cache.
				var material:=original.duplicate() as BaseMaterial3D
				material.cull_mode=BaseMaterial3D.CULL_BACK
				node.set_surface_override_material(i,material)
	for child in node.get_children():_apply_scene_culling(child)

func _add_floor_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape=node.mesh.create_trimesh_shape()
		body.add_child(shape)
		node.add_child(body)
	for child in node.get_children():
		if child is not StaticBody3D: _add_floor_collision(child)

func height(pos: Vector2) -> float:
	# Sample the rendered terrain, not roofs/trees. Cache at 1/16 tile, retaining
	# slopes while bounding repeated actor/shadow/aim queries in one frame.
	var at := pos / 24.0
	var key := Vector2i((at*16.0).round())
	if _heights.has(key): return _heights[key]
	var local:=at-Vector2(position.x,position.z)
	var cell := Vector2i((local/32.0).floor())
	var chunk: Dictionary=data.chunk_index.get(cell,{})
	var fallback := float(chunk.get("altitude",0.0))
	if not is_inside_tree(): return fallback
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x,fallback+100.0,at.y),Vector3(at.x,fallback-60.0,at.y))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return fallback # Physics registration may take the first frame.
	var value := float(hit.position.y)
	if _heights.size()>=8192: _heights.clear()
	_heights[key]=value
	return value

func _exit_tree() -> void:
	if Arena.native_height == height: Arena.native_height=Callable()
