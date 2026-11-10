class_name TitleBoxStage
extends SubViewport

# Native wallpaper/frame share one mesh; the banner folds forward at its original seam.
var actors: Array[Sprite3D] = []
var contact_shadows: Array[MeshInstance3D] = []
const ICON_SPACING := 2.7
const ICON_ROW_Z := 0.9
const ICON_DEPTH_STEP := 0.9
var frame_feet := {}
const SOURCE_BOX := Rect2i(0,0,168,160)
const BOX_WIDTH := 8.8
const BANNER_SOURCE := Rect2i(26,8,116,22)
const BANNER_OPEN_DEG := 90.0
var box_mesh: ArrayMesh
var box_texture: Texture2D
var wallpaper_texture: Texture2D
var wallpaper_index := -1
var _box_material: ShaderMaterial
var _floor_mesh: MeshInstance3D
var _box_shadow: MeshInstance3D
var _box_offset := Vector2.ZERO
const TYPE_WALLPAPERS := {
	"grass":0,"bug":0,"fire":5,"water":9,"ice":6,"electric":13,
	"ground":2,"rock":4,"poison":7,"ghost":7,"dark":7,
	"psychic":11,"flying":11,"dragon":4,"steel":13,"fighting":3,
	"normal":15,"fairy":14,
}
var camera: Camera3D
var species_keys: Array[String] = ["", "", ""]
var frame_bounds: Dictionary = {}

func _ready() -> void:
	size=Vector2i(672,520)
	transparent_bg=true
	own_world_3d=true
	render_target_update_mode=SubViewport.UPDATE_ALWAYS
	camera=Camera3D.new()
	add_child(camera)
	# A level lens with an off-axis frustum: view from the right at 45 degrees
	# without tilting the box's horizontal edges on screen.
	var pitch := deg_to_rad(40.0)
	var basis := Basis(Vector3.RIGHT,Vector3(0,cos(pitch),-sin(pitch)),Vector3(0,sin(pitch),cos(pitch)))
	var distance := 14.0
	var lateral := distance*cos(pitch)*tan(deg_to_rad(45.0))
	camera.position=Vector3(0,0.35,0)+basis.z*distance+Vector3.RIGHT*lateral
	camera.basis=basis
	camera.set_frustum(2.0*camera.near*tan(deg_to_rad(37.0)*0.5),Vector2(-lateral*camera.near/distance,0),camera.near,camera.far)
	for i in 3:
		var actor := Sprite3D.new()
		actor.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		actor.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		actor.shaded=false
		actor.region_enabled=true
		actor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		actor.position=Vector3((i-1)*ICON_SPACING,0.02,ICON_ROW_Z+(i-1)*ICON_DEPTH_STEP)
		add_child(actor)
		actors.append(actor)
	# Same soft contact shadow as the field renderer, on top of the unmodified wallpaper.
	for i in 3:
		var shadow := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size=Vector2(1.2,0.65)
		shadow.mesh=mesh
		shadow.position=Vector3((i-1)*ICON_SPACING,0.012,ICON_ROW_Z+(i-1)*ICON_DEPTH_STEP)
		var material := StandardMaterial3D.new()
		material.albedo_texture=Look.light_texture()
		material.albedo_color=Color(0,0,0,0.18)
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow.material_override=material
		shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shadow)
		contact_shadows.append(shadow)
	_align_icon_row()
	_floor_mesh=MeshInstance3D.new()
	box_mesh=_folded_box_mesh()
	_floor_mesh.mesh=box_mesh
	var mat := ShaderMaterial.new()
	mat.shader=load("res://assets/shaders/title_box_shading.gdshader")
	_box_material=mat
	_set_wallpaper(0)
	_floor_mesh.material_override=mat
	add_child(_floor_mesh)
	# A thin soft shadow gives the original frame separation without adding a new rim.
	_box_shadow=MeshInstance3D.new()
	_box_shadow.mesh=_ground_shadow_mesh()
	_box_shadow.position=Vector3(0,-0.14,0.10)
	var backing_mat := ShaderMaterial.new()
	backing_mat.shader=load("res://assets/shaders/title_box_shadow.gdshader")
	_box_shadow.material_override=backing_mat
	_box_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_box_shadow)

func _align_icon_row() -> void:
	# Equal world spacing appears unequal in perspective. Space the diagonal evenly
	# in the image, then place feet back on the actual floor with camera rays.
	var first := camera.unproject_position(actors[0].position)
	var middle := camera.unproject_position(actors[1].position)
	var last := camera.unproject_position(actors[2].position)
	var step := (last-first)*0.5
	for i in actors.size():
		var screen := middle+step*(i-1)
		var ground := _screen_on_plane(screen,Vector3(0,0.02,0),Vector3.UP)
		assert(camera.unproject_position(ground).distance_to(screen)<0.05,"Off-axis layout remains at the intended screen position")
		actors[i].position=ground
		contact_shadows[i].position=Vector3(ground.x,0.012,ground.z)

func show_slots(ids: Array[String], _shinies: Array[bool], selected: int, time: float) -> void:
	_set_wallpaper(wallpaper_for_species(ids[selected]))
	var layout_changed := false
	for i in actors.size():
		var key := ids[i]
		var actor := actors[i]
		if species_keys[i]!=key:
			layout_changed=true
			species_keys[i]=key
			var texture := PixelUi.ui_tex("plat/icons/"+key)
			actor.visible=texture!=null
			if texture==null:continue
			actor.texture=texture
			var union := Rect2i()
			var feet: Array[int] = []
			var image := texture.get_image()
			for frame in 2:
				var used := image.get_region(Rect2i(0,frame*32,32,32)).get_used_rect()
				if used.has_area():union=used if not union.has_area() else union.merge(used)
				feet.append(used.end.y)
			frame_bounds[key]=union
			frame_feet[key]=feet
			actor.pixel_size=minf(1.6/maxf(1,union.size.x),1.7/maxf(1,union.size.y))
			actor.offset=Vector2(0,union.size.y/2.0)
		if not actor.visible:continue
		var bounds: Rect2i = frame_bounds[key]
		var frame := int(time*6.0)%2 if i==selected else 0
		var texture := PixelUi.ui_tex("plat/icons/"+key)
		var source := Rect2(Vector2(bounds.position.x,frame*32+bounds.position.y),Vector2(bounds.size))
		var target := Rect2(Vector2(bounds.position.x,(1-frame)*32+bounds.position.y),Vector2(bounds.size))
		var visual := SmoothSprite.between(texture, source, target, fposmod(time*6.0,1.0) if i==selected else 0.0)
		actor.texture=visual.tex
		actor.region_rect=visual.src
		actor.offset.y=float(frame_feet[key][frame]-bounds.position.y)-bounds.size.y*0.5

	if layout_changed:_balance_box_margins()

func _silhouette_support(i: int, normal: Vector2) -> Vector2:
	# Measure opaque source pixels in both original icon frames, so the box does
	# not drift when a selected icon animates. Transparent bounding corners do not count.
	var actor := actors[i]
	var key := species_keys[i]
	var bounds: Rect2i = frame_bounds[key]
	var image := PixelUi.ui_tex("plat/icons/"+key).get_image()
	var screen_rect := icon_bounds_uv(i)
	var scale := screen_rect.size*Vector2(size)/Vector2(bounds.size)
	var foot := camera.unproject_position(actor.position)
	var support := Vector2(INF,-INF)
	for frame in 2:
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				if image.get_pixel(x,y+frame*32).a<0.5:continue
				var pixel := foot+Vector2((x-bounds.position.x-bounds.size.x*0.5)*scale.x,-float(frame_feet[key][frame]-y)*scale.y)
				support.x=minf(support.x,pixel.dot(normal))
				support.y=maxf(support.y,(pixel+scale).dot(normal))
	return support

func _balance_box_margins() -> void:
	if not actors[0].visible or not actors[2].visible:return
	_box_offset=Vector2.ZERO
	var corners := _floor_corners()
	var along := (corners[1]-corners[0]).normalized()
	var side := (corners[3]-corners[0]).normalized()
	var normal := Vector2(side.y,-side.x)
	if normal.dot(along)<0:normal=-normal
	var left := _silhouette_support(0,normal).x-corners[0].dot(normal)
	var right := corners[1].dot(normal)-_silhouette_support(2,normal).y
	var shift := (right-left)/(2.0*normal.dot(along))
	# Keep the complete original banner/floor inside the title viewport.
	var all_points := PackedVector2Array(corners)
	var height := corners[0].distance_to(corners[1])*float(BANNER_SOURCE.size.y)/float(BANNER_SOURCE.size.x)
	all_points.append(corners[0]+Vector2.UP*height)
	all_points.append(corners[1]+Vector2.UP*height)
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	for point in all_points:
		lo=lo.min(point);hi=hi.max(point)
	var max_shift := minf((lo.x-6.0)/along.x,(lo.y-6.0)/along.y)
	var min_shift := maxf((hi.x-size.x+6.0)/along.x,(hi.y-size.y+6.0)/along.y)
	_box_offset=-along*clampf(shift,min_shift,max_shift)
	box_mesh=_folded_box_mesh()
	_floor_mesh.mesh=box_mesh
	_box_shadow.mesh=_ground_shadow_mesh()

func head_uv(i: int) -> Vector2:
	var actor := actors[i]
	var top := actor.position+camera.global_basis.y*(actor.offset.y+actor.region_rect.size.y*0.5)*actor.pixel_size
	return camera.unproject_position(top)/Vector2(size)

func icon_bounds_uv(i: int) -> Rect2:
	var actor := actors[i]
	var half := actor.region_rect.size*0.5
	var at := actor.position+camera.global_basis.x*actor.offset.x*actor.pixel_size+camera.global_basis.y*actor.offset.y*actor.pixel_size
	var top_left := at-camera.global_basis.x*half.x*actor.pixel_size+camera.global_basis.y*half.y*actor.pixel_size
	var bottom_right := at+camera.global_basis.x*half.x*actor.pixel_size-camera.global_basis.y*half.y*actor.pixel_size
	var start := camera.unproject_position(top_left)/Vector2(size)
	var end := camera.unproject_position(bottom_right)/Vector2(size)
	return Rect2(start,end-start)

static func wallpaper_for_species(species: String) -> int:
	if not SpeciesDB.has_species(species):return 0
	var types: Array = SpeciesDB.get_species(species).get("types",[])
	return int(TYPE_WALLPAPERS.get(String(types[0]),0)) if not types.is_empty() else 0

func _set_wallpaper(index: int) -> void:
	if wallpaper_index==index:return
	wallpaper_index=index
	wallpaper_texture=PixelUi.ui_tex("plat/box_wallpapers/%02d"%index)
	box_texture=wallpaper_texture
	_box_material.set_shader_parameter("wallpaper_tex",box_texture)

# Compensate row widths for depth, keeping upper/lower edges equally long on screen.
# Lateral parallax still gives the 45-degree right-hand view.
func _view_point(point: Vector3) -> Vector3:
	var distance := camera.position.z/camera.basis.z.z
	var depth := (camera.position-point).dot(camera.basis.z)
	return Vector3(point.x*depth/distance,point.y,point.z)

func _screen_ray(screen: Vector2) -> Array[Vector3]:
	# Invert the actual shifted lens; Camera3D ray helpers omit its offset.
	var uv := screen/Vector2(size)
	var inverse := camera.get_camera_projection().inverse()
	var a: Vector4 = inverse*Vector4(uv.x*2.0-1.0,1.0-uv.y*2.0,0,1)
	var b: Vector4 = inverse*Vector4(uv.x*2.0-1.0,1.0-uv.y*2.0,0.99,1)
	var origin := camera.global_transform*(Vector3(a.x,a.y,a.z)/a.w)
	var end := camera.global_transform*(Vector3(b.x,b.y,b.z)/b.w)
	return [origin,(end-origin).normalized()]

func _screen_on_plane(screen: Vector2, at: Vector3, normal: Vector3) -> Vector3:
	var ray := _screen_ray(screen)
	return ray[0]+ray[1]*(normal.dot(at-ray[0])/normal.dot(ray[1]))

func _floor_corners() -> PackedVector2Array:
	var first := camera.unproject_position(actors[0].position)
	var last := camera.unproject_position(actors[2].position)
	var along := (last-first).normalized()
	# Project the actual ground-depth direction, rather than using a screen-right
	# angle that makes the wallpaper look like an upright rotated frame.
	var world_along := (actors[2].position-actors[0].position).normalized()
	var forward := Vector3(-world_along.z,0,world_along.x)
	var row_center := actors[1].position
	var back := camera.unproject_position(row_center-forward*2.56)
	var front := camera.unproject_position(row_center+forward*2.56)
	var projected_depth := (front-back)*0.6
	var inward := projected_depth.normalized()
	var left := camera.unproject_position(_view_point(Vector3(-BOX_WIDTH*0.5,0,0)))
	var right := camera.unproject_position(_view_point(Vector3(BOX_WIDTH*0.5,0,0)))
	var width := right.distance_to(left)
	var depth := projected_depth.length()
	var center := camera.unproject_position(actors[1].position)-inward*depth*0.17+_box_offset
	return PackedVector2Array([center-along*width*0.5-inward*depth*0.5,
		center+along*width*0.5-inward*depth*0.5,center+along*width*0.5+inward*depth*0.5,
		center-along*width*0.5+inward*depth*0.5])

func _folded_box_mesh() -> ArrayMesh:
	var corners := _floor_corners()
	var vertices: Array[Vector3] = []
	for corner in corners:vertices.append(_screen_on_plane(corner,Vector3.ZERO,Vector3.UP))
	var edge := (vertices[1]-vertices[0]).normalized()
	var ground_inward := Vector3(-edge.z,0,edge.x)
	if ground_inward.dot(vertices[3]-vertices[0])<0:ground_inward=-ground_inward
	var fold := deg_to_rad(180.0-BANNER_OPEN_DEG)
	var normal := Vector3.UP*cos(fold)+ground_inward*sin(fold)
	var height := corners[0].distance_to(corners[1])*float(BANNER_SOURCE.size.y)/float(BANNER_SOURCE.size.x)
	vertices.append(_screen_on_plane(corners[0]+Vector2.UP*height,vertices[0],normal))
	vertices.append(_screen_on_plane(corners[1]+Vector2.UP*height,vertices[0],normal))
	vertices.append(vertices[1]);vertices.append(vertices[0])
	var tex_size := Vector2(168,160)
	var a := Vector2(BANNER_SOURCE.position)/tex_size
	var b := Vector2(BANNER_SOURCE.end)/tex_size
	var uv := [Vector2(0,0.2),Vector2(1,0.2),Vector2(1,1),Vector2(0,1),a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,1,2,0,2,3,4,5,6,4,6,7]:
		st.set_uv(uv[index]);st.add_vertex(vertices[index])
	return st.commit()

func _ground_shadow_mesh() -> ArrayMesh:
	var corners := _floor_corners()
	var along := (corners[1]-corners[0]).normalized()
	var inward := Vector2(-along.y,along.x)
	var points := [corners[0]-along*7-inward*7,corners[1]+along*7-inward*7,
		corners[2]+along*7+inward*7,corners[3]-along*7+inward*7]
	var uv := [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0,1,2,0,2,3]:
		st.set_uv(uv[i]);st.add_vertex(_screen_on_plane(points[i],Vector3.ZERO,Vector3.UP))
	return st.commit()
