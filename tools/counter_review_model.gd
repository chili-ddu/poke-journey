extends RefCounted
# Review-only inferred perimeter faces; original art remains untouched.
const D := "res://docs/source_object_audit/center_masks/"
const HEIGHT := 0.5
const BACK := 2.0625
const FRONT := 4.0
const INNER := 3.3125

static func material(im: Image) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(im)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat

static func quad(parent: Node3D, points: Array, mat: Material, label: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	for i in [0,1,2,0,2,3]:
		st.set_uv(uv[i])
		st.add_vertex(points[i])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)

static func build() -> Node3D:
	var result := Node3D.new()
	result.name = "ReviewCounter"
	var im := Image.load_from_file(D + "counter_restored/counter.png")
	quad(result, [Vector3(4,HEIGHT,FRONT),Vector3(11,HEIGHT,FRONT),Vector3(11,HEIGHT,BACK),Vector3(4,HEIGHT,BACK)], material(im.get_region(Rect2i(0,0,112,31))), "SourceTop")
	# Clockwise U perimeter: outer sides, back endcaps, inner sides and inner back.
	var contour := [Vector2(4,FRONT),Vector2(11,FRONT),Vector2(11,BACK),Vector2(10,BACK),Vector2(10,INNER),Vector2(5,INNER),Vector2(5,BACK),Vector2(4,BACK)]
	var front_mat := material(im.get_region(Rect2i(0,31,112,8)))
	# Hidden surfaces cannot be recovered: repeat a clean interior column of front trim.
	var inferred_mat := material(im.get_region(Rect2i(40,31,1,8)))
	for i in contour.size():
		var a: Vector2 = contour[i]
		var b: Vector2 = contour[(i+1)%contour.size()]
		quad(result, [Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(b.x,HEIGHT,b.y),Vector3(a.x,HEIGHT,a.y)], front_mat if i==0 else inferred_mat, "SourceFront" if i==0 else "InferredFace%d" % i)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(D + "objects.json"))
	for item in data.objects:
		if item.id not in ["vase_left","vase_right","counter_nameplate"]:
			continue
		var sp := Sprite3D.new()
		sp.name = item.id
		sp.texture = ImageTexture.create_from_image(Image.load_from_file(D + "objects/" + item.id + ".png"))
		sp.pixel_size = 1.0/16
		sp.shaded = true
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var bb: Array = item.bounds_pixels
		sp.position = Vector3((bb[0]+bb[2])/32.0,HEIGHT+sp.texture.get_height()/32.0,FRONT+(bb[3]-55)/16.0)
		result.add_child(sp)
	return result
