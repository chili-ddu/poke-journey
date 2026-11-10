extends SceneTree
# Isolated placement review. No gameplay assets or collision modified.
const DIR := "res://docs/source_object_audit/center_masks/"
const OUT := DIR + "counter_restored/godot_review/"
const TOP := 0.5
var stage: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var props: Array[Sprite3D] = []
var records: Dictionary
var probe: MeshInstance3D
var results: Array = []
var casts_shadow := true

func texture(path: String, region := Rect2i()) -> ImageTexture:
	var im := Image.load_from_file(path)
	assert(im != null and not im.is_empty())
	if region.size != Vector2i.ZERO:
		im = im.get_region(region)
	return ImageTexture.create_from_image(im)

func surface(tex: Texture2D, size: Vector2, pos: Vector3, horizontal: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	stage.add_child(node)
	node.position = pos
	if horizontal:
		node.rotation_degrees.x = -90
	return node

func _init() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await CaptureWindow.park(self)
	stage = Node3D.new()
	root.add_child(stage)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "objects.json"))
	for item in data.objects:
		records[item.id] = item
	# Use production indoor light and camera constants, but no gameplay/post-process.
	var sk: Array = View3D.SKY["indoor"]
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = sk[0]
	sun.light_energy = sk[1]
	sun.light_color = sk[2]
	sun.shadow_opacity = sk[3]
	sun.shadow_enabled = true
	stage.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sk[6]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = sk[4]
	env.ambient_light_energy = sk[5]
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.fov = View3D.FOV
	var angle := deg_to_rad(View3D.elev_deg)
	var target := Vector3(0, TOP, 0)
	camera.position = target + Vector3(0, View3D.DIST * sin(angle), View3D.DIST * cos(angle))
	camera.look_at(target)
	camera.current = true
	# Source y24..55: tabletop; y55..63: front fascia. U opening remains transparent.
	surface(texture(DIR + "counter_restored/counter.png", Rect2i(0, 0, 112, 31)), Vector2(7, 31.0/16), Vector3(0, TOP, 0), true)
	surface(texture(DIR + "counter_restored/counter.png", Rect2i(0, 31, 112, 8)), Vector2(7, TOP), Vector3(0, TOP/2, 31.0/32), false)
	var floor_image := Image.create(160, 80, false, Image.FORMAT_RGBA8)
	for y in 80:
		for x in 160:
			floor_image.set_pixel(x, y, Color("666e78") if (x/16 + y/16) % 2 == 0 else Color("7b838d"))
	surface(ImageTexture.create_from_image(floor_image), Vector2(10, 5), Vector3(0, -0.01, 0), true)
	for id in ["vase_left", "vase_right", "counter_nameplate"]:
		var sprite := Sprite3D.new()
		sprite.name = id
		sprite.texture = texture(DIR + "objects/" + id + ".png")
		sprite.pixel_size = 1.0/16
		sprite.shaded = true
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		stage.add_child(sprite)
		props.append(sprite)
	probe = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.35, 0.25)
	probe.mesh = box
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("40d9e6")
	probe.material_override = pm
	stage.add_child(probe)
	probe.visible = false
	for moved in [false, true]:
		place_props(moved)
		for shadows in [false, true]:
			casts_shadow = shadows
			for node in stage.get_children():
				if node is GeometryInstance3D:
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			await shot(("moved" if moved else "original") + ("_shadows" if shadows else "_no_shadows"))
	probe.visible = true
	probe.position = Vector3(0, 0.175, 0.65)
	await shot("depth_behind_front")
	probe.position.z = 1.3
	await shot("depth_in_front")
	var file := FileAccess.open(OUT + "review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "isolated_godot_review", "camera_elevation": View3D.elev_deg, "camera_fov": camera.fov, "camera_distance": View3D.DIST, "tabletop_height": TOP, "shots": results, "limitations": ["Tabletop/front split and height are review assumptions", "No side/back geometry", "No gameplay collision or production palette/postprocess validation", "Baked sprite shading retained"]}, "  "))
	print("Counter review: 6 rendered cases; prop base equals tabletop")
	quit()

func place_props(moved: bool) -> void:
	for i in props.size():
		var sprite := props[i]
		var bb: Array = records[String(sprite.name)].bounds_pixels
		var delta: int = [20, -20, -16][i] if moved else 0
		var h := sprite.texture.get_height() / 16.0
		sprite.position = Vector3(((bb[0] + bb[2])/2.0 + delta - 120)/16.0, TOP + h/2, (bb[3] - 24)/16.0 - 31.0/32)
		assert(is_equal_approx(sprite.position.y - h/2, TOP))

func shot(label: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	assert(not im.is_empty())
	assert(im.save_png(OUT + label + ".png") == OK)
	results.append({"name": label, "dynamic_shadow": casts_shadow})
	print(label)
