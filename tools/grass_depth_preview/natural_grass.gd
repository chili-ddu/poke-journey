extends View3D

var leaves: SurfaceTool
var leaf_material: ShaderMaterial
var has_leaves := false

func _draw_cards(map_dir: String, scenery: Dictionary, cards: Array, fragments: Array, parent: Node3D, boxes: Dictionary = {}) -> void:
	leaves = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	has_leaves = false
	super._draw_cards(map_dir, scenery, cards, fragments, parent, boxes)
	if has_leaves:
		if leaf_material == null:
			leaf_material = ShaderMaterial.new()
			leaf_material.shader = preload("res://tools/grass_depth_preview/natural_grass.gdshader")
			leaf_material.set_shader_parameter("atlas", _card_atlas)
			leaf_material.set_shader_parameter("actor_depth", SPRITE_LIFT)
		var patch := MeshInstance3D.new()
		patch.mesh = leaves.commit()
		patch.material_override = leaf_material
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(patch)
	leaves = null

func _build_layered_flora(st: SurfaceTool, x: float, z: float, u0: float, u1: float, v0: float, v1: float, local_tile := Vector2i(-1,-1)) -> void:
	var tile := Vector2i(int(x), int(z)-1)
	if not _ground_static_geometry or not Arena.is_grass(tile):
		super._build_layered_flora(st, x, z, u0, u1, v0, v1, local_tile)
		return
	has_leaves = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile)
	var center := Vector2(x + 0.5, z - 0.5)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var back := center + Vector2(0.085 * side, rng.randf_range(-0.16,-0.03))
	var front := center + Vector2(-0.16 * side, rng.randf_range(0.17,0.30))
	_tuft(back,rng.randf_range(0.76,0.87),rng.randf_range(0.53,0.66),rng.randf_range(-0.09,0.09),u0,u1,v0,v1)
	_tuft(front,rng.randf_range(0.48,0.59),rng.randf_range(0.30,0.40),-0.06*side,u0,u1,v0,v1)

func _tuft(root: Vector2, width: float, height: float, lean: float, u0: float, u1: float, v0: float, v1: float) -> void:
	var uv := [Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)]
	var up := Vector3(lean,height,-0.13)
	var normal := Vector3.RIGHT.cross(up).normalized()
	# Front-facing cards use the same winding as the terrain renderer.
	for index in [0,1,2,0,2,3]:
		var is_tip: bool = index < 2
		var at := root + Vector2(width * (0.5 if index in [1,2] else -0.5), 0)
		var vertex := to3d(at * Arena.TILE,0.016)
		if is_tip: vertex += up
		leaves.set_uv(uv[index])
		leaves.set_uv2(root)
		leaves.set_color(Color.WHITE if is_tip else Color.BLACK)
		leaves.set_normal(normal)
		leaves.add_vertex(vertex)

func _sync_fx_grass(f: Fx, seen: Dictionary) -> void:
	if f.kind == "tallgrass" and kanto_terrain != null:
		return # Contact bends the existing visible mesh for this walking sample.
	super._sync_fx_grass(f, seen)

func _process(dt: float) -> void:
	super._process(dt)
	if leaf_material != null:
		var player := world.player
		leaf_material.set_shader_parameter("feet", (player.position + Vector2(0,player.feet_offset())) / Arena.TILE)
