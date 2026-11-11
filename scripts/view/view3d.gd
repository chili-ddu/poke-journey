class_name View3D
extends CanvasLayer

# HD-2D 2단계 시제품(사용자 요청 2026-11-02: 탑뷰에서 각도를 낮추고 지도 오브젝트를 세워 입체감). 태초마을부터.
# 판정·이동·기술은 지금의 2D World 그대로 두고, 그 상태를 3D 로 '비춰' 그린다(2D 화면은 이 층 아래에서 그대로 그려진다 —
# 포켓몬 도트의 현재 프레임을 2D 그리기가 정하므로).
#   바닥      지도 아래층 그림(bottom.png) 한 장을 바닥 판으로. 1칸 = 1m, 2D 좌표 (x, y)px → (x/TILE, 0, y/TILE).
#   세운 물체  tools/hd2d_cards.py 가 묶은 물체 한 줄(나무 한 그루·집 한 채의 세로 한 줄·울타리·표지판)을 그 밑단에 카드 한 장으로.
#             높이는 고정(STAND, 1칸 = 1m) — 낮은 각도에서 우뚝 서고 뒤를 가린다(처음엔 칸마다 세워 각도에 맞춰 줄였더니 각도를 낮춰도 서 보이지 않았다).
#             나무는 원본 조각들을 한 그루로 묶어 공통 접지 높이와 폭·깊이가 있는 수관으로 만든다(TreeCanopy).
#   포켓몬·사람  지금 프레임을 세로 빌보드(Y축 고정)로 발밑에 세운다(높이도 tan(높이각) 배). 발밑에 둥근 그림자 + 해 그림자.
#   효과      바닥 표시(호·점선 고리·예고원·장판·풀숲 흔들림·떨어진 도구)는 2D 세계를 공유하는 작은 뷰포트가 그 노드들만
#             그려(렌더 레이어 Look.GROUND_LAYER) 바닥에 깐 판에 입힌다 — 2D 그리기 코드를 그대로 쓴다.
#             공중에 뜨는 것(sprite 효과·투사체·피해 숫자·글자·타격 별·섬광·프레임 애니)은 카메라를 보는 판·3D 글자로.
#   조명      해(그림자) + 하늘빛(주변광). 꼬리불·불꽃 투사체는 점 조명.
# 켜고 끄기: 게임 안에서 F9(비교용). 기본은 Look.view3d. 3D 를 쓸 수 있는 지도는 hd2d_cards.json 이 있는 곳(지금은 kanto_south)뿐.
const ELEV_DEG := 40.0        # 카메라 높이각(90 = 바로 위에서). 처음 55° → 사용자 '각도 더 낮게' → 40° 확정(2026-11-02)
# 비교용: 실행할 때 환경 변수 V3D_ELEV=35 처럼 바꿔 볼 수 있다(카드 높이도 그 각도에 맞춰 다시 세운다).
static var elev_deg := float(OS.get_environment("V3D_ELEV")) if OS.get_environment("V3D_ELEV") != "" else ELEV_DEG
const ARENA_YAW := 25.0       # Right-oblique view; projection basis keeps court edges level.
const ARENA_INTRO_ELEV := 20.0
const ARENA_INTRO_DIST := 10.0
const FOV := 30.0             # 좁은 화각 — 원근은 은은하게(HD-2D 느낌)
const DIST := 13.0            # 카메라 거리(m). 2D 화면(가로 16칸)과 비슷한 크기로 보이게
const FOLLOW := 9.75          # 카메라가 따라가는 빠르기(초당 — 60fps 에서 프레임마다 0.15 와 같다, 프레임이 흔들려도 같은 느낌)
# 3D 렌더 레이어: 포켓몬·사람 빌보드는 2번 — 꼬리불·불꽃 점 조명(light_cull_mask 1)은 바닥·벽만 밝히고 도트는 물들이지 않는다
# (2D 의 light_mask 2 와 같은 뜻 — 꼬리 조명이 파이리 몸을 주황으로 물들였다). 해는 모두 비춘다.
const SPRITE_LAYER := 2
const MapPalette = preload("res://scripts/view/map_palette.gd")
const ContactMoveArt = preload("res://scripts/view/contact_move_art.gd")
const EmberHeat = preload("res://scripts/view/ember_heat.gd")
const TreeCanopy = preload("res://scripts/view/tree_canopy_3d.gd")
const NestBranches = preload("res://scripts/view/nest_branches_3d.gd")
const HgssEnvironment = preload("res://scripts/view/hgss_environment.gd")

const NativeRenderer = preload("res://scripts/johto/game_map_renderer.gd")
var native_renderer: NativeRenderer
var continent_backdrop: Node3D
const KantoTerrainStream = preload("res://scripts/view/kanto_terrain_stream.gd")
var kanto_terrain: KantoTerrainStream
var _road_materials := {}
var _scenery_parent: Node3D
var _card_atlas: Texture2D
var _fence_image: Image
var _fence_profiles := {}

var world: World
var vp: SubViewport
var rect: TextureRect
var root3d: Node3D
var cam: Camera3D
var _sun: DirectionalLight3D
# 서 있는 것의 높이 배율(1칸 그림 = 이만큼 m). 물체 단위 카드라 각도와 상관없이 고정 — 낮은 각도일수록 우뚝 서 보이고 뒤를 가린다.
# 단 tan(높이각)보다 낮으면 카드가 제 발자국을 다 못 가려 바닥에 깔린 원래 그림이 뒤로 비치므로 그보다는 크게.
const STAND := 1.0
const CONTACT_SHADOW_HEIGHT := 0.02
var k := maxf(STAND, tan(deg_to_rad(elev_deg)))
# 포켓몬·사람 빌보드의 키 배율: 세로로 선 판은 높이각만큼 눌려 보여서(40° 에서 77%) 그만큼 늘려 원래 비율로 보이게
# (사용자 '파이리가 입체감이 조금 떨어지는데' 2026-11-02 — 납작해 보였다).
var bill := 1.0 / cos(deg_to_rad(elev_deg))
var _cam_target := Vector3.ZERO
var _cam_ready := false
var _cam_distance := DIST
var _starter_table_height := 0.0
var _opening_warm_glow: Sprite3D
var _ground_static_geometry := false
var _terrain_normals := {}
var _ground_anchor := Vector2.INF
var _overlay_elevation_origin := Vector2.INF
var _healing_bed := Vector3.INF
var _sprites := {}            # 2D 노드 instance id → { sprite, blob?, light? }
var _fx_quads := {}           # Fx / Projectile instance id → MeshInstance3D·Sprite3D
var _blob_mesh: PlaneMesh
var _blob_mat: StandardMaterial3D

static func supported(map_dir: String) -> bool:
	return map_dir != "" and (FileAccess.file_exists(map_dir.path_join("manifest.json")) or FileAccess.file_exists(map_dir.path_join("hd2d_cards.json")))

func render_target_size() -> Vector2i:
	var parent_view := get_viewport()
	return parent_view.size if parent_view is SubViewport and parent_view.has_meta("mobile_display_scale") else get_window().size

func fit_render_target() -> void:
	if vp != null:vp.size = render_target_size()

func build(w: World, map_dir: String) -> void:
	world = w
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.size = render_target_size()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)
	rect = TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.texture = vp.get_texture()
	var sound_material := ShaderMaterial.new()
	sound_material.shader = load("res://assets/shaders/sound_refraction.gdshader")
	rect.material = sound_material
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	get_window().size_changed.connect(fit_render_target)
	root3d = Node3D.new()
	vp.add_child(root3d)
	if Arena.is_native():
		native_renderer=NativeRenderer.new()
		root3d.add_child(native_renderer)
		native_renderer.setup(Arena.native_collection,Arena.native_data)
		native_renderer.stream(world.player.position/Arena.TILE)
		Arena.native_height=native_renderer.height
	else:
		var scenery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/hd2d_cards.json"))
		_ground_static_geometry = not Arena._elevation.is_empty()
		if Arena.is_continent():
			kanto_terrain = KantoTerrainStream.new()
			root3d.add_child(kanto_terrain)
			kanto_terrain.setup(self, map_dir, scenery)
			kanto_terrain.stream(world.player.position / Arena.TILE)
		else:
			_build_floor(map_dir)
			_build_cards(map_dir, scenery)
			_build_houses(map_dir, scenery)
			HgssEnvironment.build(self,map_dir)
		_ground_static_geometry = false
		if Arena.is_continent():
			native_renderer=NativeRenderer.new()
			var shift:=Arena.Continent.offset()
			native_renderer.position=Vector3(shift.x,0,shift.y)
			root3d.add_child(native_renderer)
			native_renderer.setup(Arena.native_collection,Arena.continent_data)
			native_renderer.stream(world.player.position/Arena.TILE)
			Arena.native_height=native_renderer.height
			continent_backdrop=preload("res://scripts/view/continent_backdrop.gd").new()
			root3d.add_child(continent_backdrop)
			continent_backdrop.setup()
			continent_backdrop.stream(world.player.position/Arena.TILE)
	_build_sky()
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.5
	cam.far = 120.0
	root3d.add_child(cam)
	cam.current = true
	_blob_mesh = PlaneMesh.new()
	_blob_mesh.size = Vector2(1, 1)
	_blob_mat = StandardMaterial3D.new()
	_blob_mat.albedo_color = Color(0, 0, 0, 0.35)
	_blob_mat.albedo_texture = Look.light_texture()
	_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.aim_override = mouse_world
	world.move_override = screen_move_world
	_build_overlay()
	text_layer = CanvasLayer.new()
	text_layer.layer = 3                    # 후처리(2) 위, UI(4) 아래
	add_child(text_layer)
	_text_node = Node2D.new()
	_text_node.draw.connect(_draw_texts)
	text_layer.add_child(_text_node)
	visibility_changed.connect(func() -> void: text_layer.visible = visible)

# ── 바닥 오버레이 ──
const OV_TILES := Vector2(32, 24)     # 오버레이가 덮는 범위(칸) — 화면보다 넉넉히
const OV_SCALE := 2.0                 # 2D 1px 을 오버레이 2px 로(선이 뭉개지지 않게)
var ov: SubViewport
var ov_quad: MeshInstance3D

func _build_overlay() -> void:
	ov = SubViewport.new()
	ov.world_2d = get_viewport().world_2d
	ov.canvas_cull_mask = Look.GROUND_LAYER
	ov.transparent_bg = true
	ov.disable_3d = true
	ov.size = Vector2i(OV_TILES * Arena.TILE * OV_SCALE)
	ov.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(ov)
	ov_quad = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = OV_TILES
	ov_quad.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ov.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ov_quad.material_override = mat
	ov_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root3d.add_child(ov_quad)

func _step_overlay() -> void:
	var half := OV_TILES * Arena.TILE / 2.0
	var origin := (world.player.position - half).snapped(Vector2(Arena.TILE, Arena.TILE))
	ov.canvas_transform = Transform2D(0.0, Vector2(OV_SCALE, OV_SCALE), 0.0, -origin * OV_SCALE)
	if Arena._elevation.is_empty() and not Arena.native_at(Arena.tile_of(world.player.position)):
		ov_quad.position = to3d(origin + half, 0.03)
		return
	ov_quad.position=Vector3((origin.x+half.x)/Arena.TILE,0.03,(origin.y+half.y)/Arena.TILE)
	if origin==_overlay_elevation_origin:return
	_overlay_elevation_origin=origin
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Arena.tile_of(origin)
	for y in int(OV_TILES.y):
		for x in int(OV_TILES.x):
			var tile: Vector2i = base+Vector2i(x,y)
			if Arena._ledge_patches.has(tile):continue
			var heights: Array=Arena._elevation[tile.y][tile.x] if tile.x>=0 and tile.y>=0 and tile.y<Arena._elevation.size() and tile.x<(Arena._elevation[tile.y] as Array).size() else Arena.ground_corners(tile)
			var points := [Vector3(x-OV_TILES.x/2,heights[0],y-OV_TILES.y/2),Vector3(x+1-OV_TILES.x/2,heights[1],y-OV_TILES.y/2),Vector3(x+1-OV_TILES.x/2,heights[2],y+1-OV_TILES.y/2),Vector3(x-OV_TILES.x/2,heights[3],y+1-OV_TILES.y/2)]
			var uv := [Vector2(x/OV_TILES.x,y/OV_TILES.y),Vector2((x+1)/OV_TILES.x,y/OV_TILES.y),Vector2((x+1)/OV_TILES.x,(y+1)/OV_TILES.y),Vector2(x/OV_TILES.x,(y+1)/OV_TILES.y)]
			_poly(st,[points[0],points[1],points[2]],[uv[0],uv[1],uv[2]])
			_poly(st,[points[0],points[2],points[3]],[uv[0],uv[2],uv[3]])
	ov_quad.mesh=st.commit()

# Shared corner heights form walkable ramps; native blocked banks are separate.
func _build_elevated_road(map_dir: String, source: Dictionary, bounds := Rect2i(), patch_tiles: Array = [], parent: Node3D = root3d) -> void:
	_terrain_normals.clear()
	var w := int(source.width)
	var h := int(source.height)
	var pad := int(source.pad)
	var tw := float(w+pad*2)
	var th := float(h+pad*2)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not bounds.has_area():
		bounds = Rect2i(-pad, -pad, w+pad*2, h+pad*2)
		patch_tiles = Arena._ledge_patches.keys()
	for y in range(bounds.position.y, bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			if Arena._ledge_patches.has(Vector2i(x,y)):
				x+=1
				continue
			var heights: Array=Arena._elevation[y][x] if x>=0 and y>=0 and x<w and y<h else Arena.ground_corners(Vector2i(x,y))
			var end_x := x+1
			# Most of the world is flat. Keep those pixels in long strips instead
			# of allocating two triangles for every empty forest/border tile.
			if heights[0]==heights[1] and heights[0]==heights[2] and heights[0]==heights[3]:
				while end_x < bounds.end.x:
					if Arena._ledge_patches.has(Vector2i(end_x,y)):break
					var next: Array=Arena._elevation[y][end_x] if end_x>=0 and y>=0 and end_x<w and y<h else Arena.ground_corners(Vector2i(end_x,y))
					if next[0]!=heights[0] or next[1]!=heights[0] or next[2]!=heights[0] or next[3]!=heights[0]:break
					end_x+=1
			var vertices := [Vector3(x,heights[0],y),Vector3(end_x,heights[1],y),Vector3(end_x,heights[2],y+1),Vector3(x,heights[3],y+1)]
			var uv := [Vector2((x+pad)/tw,(y+pad)/th),Vector2((end_x+pad)/tw,(y+pad)/th),Vector2((end_x+pad)/tw,(y+pad+1)/th),Vector2((x+pad)/tw,(y+pad+1)/th)]
			# Match Arena.ground_height's diagonal exactly, including non-planar quads.
			_terrain_triangle(surface,[vertices[0],vertices[1],vertices[2]],[uv[0],uv[1],uv[2]])
			_terrain_triangle(surface,[vertices[0],vertices[2],vertices[3]],[uv[0],uv[2],uv[3]])
			x=end_x
	var floor := MeshInstance3D.new()
	floor.name="RoadElevationFloor"
	floor.mesh=surface.commit()
	floor.material_override = road_material(map_dir, false)
	floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor)
	_build_cliff_banks(map_dir, source, patch_tiles, parent)
	_terrain_normals.clear()

func road_material(map_dir: String, rock: bool) -> Material:
	var file := "ledge_rock.png" if rock else "elevation_floor.png"
	var key := map_dir.path_join(file)
	if _road_materials.has(key): return _road_materials[key]
	var texture := MapPalette.texture(HgssEnvironment.surface(map_dir, file))
	var result: Material
	if rock:
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://assets/shaders/ledge_rock.gdshader")
		shader.set_shader_parameter("rock_texture", texture)
		result = shader
	else:
		result = road_ground_material(texture)
	_road_materials[key] = result
	return result

static func road_ground_material(texture: Texture2D) -> StandardMaterial3D:
	var ground := StandardMaterial3D.new()
	ground.albedo_texture = texture
	ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground.roughness = 1.0
	ground.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ground.cull_mode = BaseMaterial3D.CULL_DISABLED
	return ground

# A low bank owns the impassable cell: rounded turf shoulder, earth face, and toe.
# Patch boundaries are baked once and shared by straight runs, elbows, and ends.
func _build_cliff_banks(map_dir: String, source: Dictionary, patch_tiles: Array, parent: Node3D) -> void:
	if patch_tiles.is_empty():return
	var pad := float(source.pad)
	var texture_size := Vector2(float(source.width)+pad*2.0,float(source.height)+pad*2.0)
	var rock := SurfaceTool.new()
	var turf := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	turf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_faces := 0
	var turf_faces := 0
	var res := Arena._ledge_resolution
	var kinds := {}
	for tile in patch_tiles:
		var patch: Dictionary=Arena._ledge_patches[tile]
		var grid: Array=patch.heights
		kinds[patch.kind]=int(kinds.get(patch.kind,0))+1
		var corner: Array=[grid[0][0],grid[0][res],grid[res][res],grid[res][0]]
		var high := float(corner.max())
		var low := float(corner.min())
		for y in res:
			for x in res:
				var points := [Vector3(tile.x+float(x)/res,grid[y][x],tile.y+float(y)/res),Vector3(tile.x+float(x+1)/res,grid[y][x+1],tile.y+float(y)/res),Vector3(tile.x+float(x+1)/res,grid[y+1][x+1],tile.y+float(y+1)/res),Vector3(tile.x+float(x)/res,grid[y+1][x],tile.y+float(y+1)/res)]
				for indices in [[0,1,2],[0,2,3]]:
					var triangle: Array=[points[indices[0]],points[indices[1]],points[indices[2]]]
					var upper := _ledge_boundary(triangle,patch,Vector2(tile),high,high-low,false)
					var lower := _ledge_boundary(triangle,patch,Vector2(tile),high,high-low,true)
					var fields := []
					for i in 3:fields.append(Vector2(float(upper[i]),float(lower[i])))
					var face := _clip_ledge_data(triangle,fields,1,true)
					face=_clip_ledge_data(face.points,face.fields,0,true)
					rock_faces+=_emit_ledge_polygon(rock,face.points,true,high,high-low,pad,texture_size,res)
					turf_faces+=_emit_ledge_polygon(turf,_clip_ledge_polygon(triangle,upper,false),false,high,high-low,pad,texture_size,res)
					turf_faces+=_emit_ledge_polygon(turf,_clip_ledge_polygon(triangle,lower,false),false,high,high-low,pad,texture_size,res)
	for entry in [[rock,"RoadLedgeWalls",rock_faces],[turf,"RoadLedgeRims",turf_faces]]:
		if int(entry[2])==0:continue
		var node := MeshInstance3D.new()
		node.name=entry[1]
		node.mesh=entry[0].commit()
		node.material_override = road_material(map_dir, node.name == &"RoadLedgeWalls")
		node.set_meta("faces",entry[2])
		node.set_meta("kinds",kinds)
		parent.add_child(node)

static func ledge_face_toe(patch: Dictionary, local_uv: Vector2) -> float:
	var fixed_foot: Array=patch.get("toe_drop",[])
	if not fixed_foot.is_empty():
		var tangent := local_uv.x if patch.direction in ["s","n"] else local_uv.y
		var at := clampf(tangent*float(fixed_foot.size()-1),0.0,float(fixed_foot.size()-1))
		var index := int(floor(at))
		return lerpf(float(fixed_foot[index]),float(fixed_foot[mini(index+1,fixed_foot.size()-1)]),at-index)
	var outline: Array=patch.get("cap_toe",[])
	if outline.is_empty():return float(patch.get("toe_level",0.98))
	var tangent := local_uv.x if patch.direction in ["s","n"] else local_uv.y
	var at := clampf(tangent*outline.size()-0.5,0.0,float(outline.size()-1))
	var index := int(floor(at))
	return lerpf(float(outline[index]),float(outline[mini(index+1,outline.size()-1)]),at-index)

static func ledge_face_rim(patch: Dictionary, local_uv: Vector2) -> float:
	var outline: Array=patch.get("rim_top",[])
	if outline.is_empty():return 0.22
	var tangent := local_uv.x if patch.direction in ["s","n"] else local_uv.y
	var gain := 1.0
	if patch.direction=="":
		var u := clampf(local_uv.x,0.0,1.0)
		var v := clampf(local_uv.y,0.0,1.0)
		tangent=(u+v)*0.5
		gain=16.0*u*(1.0-u)*v*(1.0-v)
	var at := clampf(tangent*float(outline.size()-1),0.0,float(outline.size()-1))
	var index := int(floor(at))
	var rim := lerpf(float(outline[index]),float(outline[mini(index+1,outline.size()-1)]),at-index)
	return 0.22+(rim-0.22)*gain

static func _ledge_boundary(points: Array, patch: Dictionary, tile: Vector2, high: float, height: float, toe: bool) -> Array:
	var result := []
	for point: Vector3 in points:
		var drop := (high-point.y)/maxf(height,0.00001)
		result.append(ledge_face_toe(patch,Vector2(point.x,point.z)-tile)-drop if toe else drop-ledge_face_rim(patch,Vector2(point.x,point.z)-tile))
	return result

static func _clip_ledge_polygon(points: Array, values: Array, positive: bool) -> Array:
	var fields := []
	for value in values:fields.append(Vector2(float(value),0.0))
	return _clip_ledge_data(points,fields,0,positive).points

static func _clip_ledge_data(points: Array, fields: Array, field: int, positive: bool) -> Dictionary:
	var result := {"points":[],"fields":[]}
	if points.is_empty():return result
	var previous: Vector3=points[-1]
	var previous_field: Vector2=fields[-1]
	var previous_value: float=previous_field[field]*(1.0 if positive else -1.0)
	for i in points.size():
		var current: Vector3=points[i]
		var current_field: Vector2=fields[i]
		var value: float=current_field[field]*(1.0 if positive else -1.0)
		if (value>=0.0)!=(previous_value>=0.0):
			var t := previous_value/(previous_value-value)
			result.points.append(previous.lerp(current,t))
			# Carry both sampled boundaries through each cut. Re-sampling a curved
			# rim at a new vertex would leave slivers between earth and turf.
			result.fields.append(previous_field.lerp(current_field,t))
		if value>=0.0:
			result.points.append(current)
			result.fields.append(current_field)
		previous=current
		previous_field=current_field
		previous_value=value
	return result

func _emit_ledge_polygon(st: SurfaceTool, points: Array, earth: bool, high: float, height: float, pad: float, texture_size: Vector2, res: int) -> int:
	var uv := []
	for point: Vector3 in points:
		uv.append(Vector2(point.x,clampf(((high-point.y)/maxf(height,0.00001)-0.22)/0.76,0.0,1.0)) if earth else (Vector2(point.x,point.z)+Vector2.ONE*pad)/texture_size)
	var faces := 0
	for i in range(1,points.size()-1):
		if (points[i]-points[0]).cross(points[i+1]-points[0]).length_squared()<0.0000000001:continue
		_terrain_triangle(st,[points[0],points[i],points[i+1]],[uv[0],uv[i],uv[i+1]],1.0/res)
		faces+=1
	return faces

func _terrain_triangle(st: SurfaceTool, points: Array, uv: Array, step := 0.25) -> void:
	for i in 3:
		var p: Vector3=points[i]
		var key := Vector3(p.x,p.z,step)
		if not _terrain_normals.has(key):
			var at := Vector2(p.x,p.z)*Arena.TILE
			var dx := (Arena.ground_height(at+Vector2.RIGHT*step*Arena.TILE)-Arena.ground_height(at-Vector2.RIGHT*step*Arena.TILE))/(2.0*step)
			var dz := (Arena.ground_height(at+Vector2.DOWN*step*Arena.TILE)-Arena.ground_height(at-Vector2.DOWN*step*Arena.TILE))/(2.0*step)
			_terrain_normals[key]=Vector3(-dx,1,-dz).normalized()
		st.set_normal(_terrain_normals[key])
		st.set_uv(uv[i])
		st.add_vertex(p)

# Solid corner sprites are replaced too, including those inside taller columns.
static func _ledge_card_fragments(cards: Array) -> Array:
	if Arena._ledge_patches.is_empty():return cards
	var result: Array=[]
	for card in cards:
		var start := 0
		while start<int(card[2]):
			if Arena._ledge_patches.has(Vector2i(int(card[0]),int(card[1])+start)):
				start+=1
				continue
			var end := start+1
			while end<int(card[2]) and not Arena._ledge_patches.has(Vector2i(int(card[0]),int(card[1])+end)):end+=1
			if start==0 and end==int(card[2]):result.append(card)
			else:
				var part: Array=card.duplicate()
				part[1]=int(card[1])+start
				part[2]=end-start
				part[4]=int(card[4])+start*16
				part[5]=clampi(int(card[5])-start,0,end-start-1)
				if part.size()>8:part[8]=0
				result.append(part)
			start=end
	return result

func _build_floor(map_dir: String) -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/map.json"))
	var w := float(j["width"])
	var h := float(j["height"])
	var pad := float(j.get("pad", 0))
	if not Arena._elevation.is_empty():
		_build_elevated_road(map_dir,j)
		return
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w + pad * 2.0, h + pad * 2.0)
	floor.mesh = pm
	var mat := StandardMaterial3D.new()
	# 세운 물체 자리를 맨바닥으로 메운 바닥 그림(tools/hd2d_cards.py) — 원래 그림이 바닥에 남아 비치지 않게(사용자 지적 2026-11-02).
	mat.albedo_texture = HgssEnvironment.surface(map_dir,"hd2d_floor.png")
	if CenterPalette.applies(map_dir):
		mat.albedo_texture = ImageTexture.create_from_image(CenterPalette.floor_surface(mat.albedo_texture.get_image()))
	mat.albedo_texture = MapPalette.texture(mat.albedo_texture)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED      # 반사광이 바닥을 하얗게 날렸다
	mat.metallic_specular = 0.0
	floor.material_override = mat
	floor.position = Vector3(w / 2.0, 0.0, h / 2.0)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root3d.add_child(floor)

# 서 있는 물체 카드 전부를 메시 하나로(카드 수천 장 — 그리기 호출 한 번). 카드 = [x, 맨 위 y, 칸 수 n, 아틀라스 x, y, 지붕 칸 수 r]:
# 묶음 밑단(y + n 칸의 남쪽 가장자리)에 세운다. 건물·가구는 상자(앞면·윗면·옆면), 얇은 것은 세운 판(아래 주석).
# Terrain uses a shared height grid. Only boundaries with a lower neighbor
# produce a wall; adjacent cells share the same top and never add interior sides.
func _build_heightfield(map_dir: String, field: Dictionary) -> void:
	var atlas: Texture2D = MapPalette.texture(HgssEnvironment.surface(map_dir,"hd2d_atlas.png"))
	var size := Vector2(atlas.get_size())
	var heights: Array = field.heights
	var rows := heights.size()
	var cols := (heights[0] as Array).size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := 0
	for cell in field.tiles:
		var x := int(cell[0])
		var z := int(cell[1])
		var top := float(heights[z][x])
		var u := float(cell[2]) / size.x
		var v := float(cell[3]) / size.y
		_quad(st, Vector3(x,top,z+1), Vector3.RIGHT, Vector3.FORWARD, Vector3.UP,
			u, u+16.0/size.x, v, v+16.0/size.y)
		for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor: Vector2i = Vector2i(x,z)+dir
			var base := float(heights[neighbor.y][neighbor.x]) if neighbor.x>=0 and neighbor.y>=0 and neighbor.x<cols and neighbor.y<rows else float(field.wall_height)
			if base>=top:continue
			var origin := Vector3(x,base,z+1)
			var across := Vector3.RIGHT
			if dir==Vector2i.UP:
				origin=Vector3(x+1,base,z)
				across=Vector3.LEFT
			elif dir==Vector2i.LEFT:
				origin=Vector3(x,base,z)
				across=Vector3.BACK
			elif dir==Vector2i.RIGHT:
				origin=Vector3(x+1,base,z+1)
				across=Vector3.FORWARD
			var wu := float(field.wall_uv[0])/size.x
			var wv := float(field.wall_uv[1])/size.y
			_quad(st,origin,across,Vector3.UP*(top-base),Vector3(dir.x,0,dir.y),wu,wu+16.0/size.x,wv,wv+16.0/size.y)
			faces+=1
	# Continue the solid perimeter into decorative map padding at the same height.
	var pad := int(field.get("padding",0))
	var padding_faces := 0
	var cap_u := float(field.cap_uv[0])/size.x
	var cap_v := float(field.cap_uv[1])/size.y
	for z in range(-pad,rows+pad):
		for x in range(-pad,cols+pad):
			if x>=0 and z>=0 and x<cols and z<rows:continue
			_quad(st,Vector3(x,float(field.wall_height),z+1),Vector3.RIGHT,Vector3.FORWARD,Vector3.UP,cap_u,cap_u+16.0/size.x,cap_v,cap_v+16.0/size.y)
			padding_faces+=1
	var mesh := MeshInstance3D.new()
	mesh.name="TerrainHeightfield"
	mesh.mesh=st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture=atlas
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness=1.0
	material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=material
	mesh.set_meta("boundary_faces",faces)
	mesh.set_meta("top_faces",field.tiles.size()+padding_faces)
	root3d.add_child(mesh)

func _build_cards(map_dir: String, j: Dictionary = {}) -> void:
	if j.is_empty(): j = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/hd2d_cards.json"))
	if j.has("heightfield"):
		_build_heightfield(map_dir, j.heightfield)
		return
	var cards := HgssEnvironment.remaining_cards(map_dir, j.cards)
	_draw_cards(map_dir, j, cards, _ledge_card_fragments(cards), root3d)

static func box_profile(card: Array) -> Vector2:
	var roof := float(card[5])
	var wall_scale := float(card[6]) if card.size() > 6 else 1.0
	return Vector2((float(card[2]) - roof) * wall_scale, roof)

func _draw_cards(map_dir: String, j: Dictionary, cards: Array, fragments: Array, parent: Node3D, world_boxes: Dictionary = {}) -> void:
	var side_surfaces := {}
	var side_file := map_dir+"/hd2d_side_surfaces.json"
	if FileAccess.file_exists(side_file): side_surfaces = JSON.parse_string(FileAccess.get_file_as_string(side_file))
	if _card_atlas == null: _card_atlas = MapPalette.texture(HgssEnvironment.surface(map_dir,"hd2d_atlas.png"))
	var atlas := _card_atlas
	var tw := float(atlas.get_width())
	var th := float(atlas.get_height())
	var t := float(j["tile"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 상자로 세우기(사용자 2026-11-02: 오브젝트에 x·y(바닥 넓이)가 있어야 자연스럽다): 원작 그림은 상자를 비스듬히 내려다본 모습이라
	#   앞면 = 아래 칸들(벽·창문·문·책상 앞)을 세우고, 윗면 = 위 칸들(지붕·책상 윗면)을 그 깊이만큼 수평으로 덮고,
	#   옆면 = 물체 양 끝에 앞면 가장자리 픽셀 줄을 늘여 붙인다. 40° 카메라에서 앞면 1칸 0.77 · 윗면 1칸 0.64 로 원작 비율과 거의 같다.
	#   대상: 4칸 넘는 묶음(건물·절벽 — 지붕 칸 수는 도구가 줌), 건물 안 2~3칸 가구(위 칸이 윗면, 뒷벽 y ≤ 1 은 제외).
	#   울타리·표지판은 세운 판, 꽃·수풀은 기울인 잎, 나무는 한 그루 단위의 수관 메시로 만든다.
	var indoor := sky_kind(DungeonDB.current) == "indoor"
	var px_u := 1.0 / tw                                      # 아틀라스 1px(옆면 줄)
	var plan: Array = []                                      # [card, 윗면 칸 수 r, 상자?]
	var box_cols := world_boxes                                        # "x:밑단 z" — 옆 상자와 붙은 쪽은 옆면을 안 그린다
	# 건물 안 2~3칸 가구가 상자인지(윗면이 꽉 찬 판)는 도구가 정해 지붕 칸 수(c[5])로 준다 — 화분·의자는 0 이라 세운 판.
	# c[8] = 아래 걸을 수 있는 칸까지 이어 붙인 칸 수(가구 아랫단): 카드는 그만큼 위(막힌 칸 남쪽 끝)에 선다.
	var corner_columns := {}
	for corner in j.get("corner_walls", []):
		corner_columns[int(corner.column)] = true
		var a := Vector3(float(corner.a[0]), 0, float(corner.a[1]))
		var b := Vector3(float(corner.b[0]), 0, float(corner.b[1]))
		var height := Vector3.UP * float(corner.h) * k
		var uv: Array = corner.atlas
		_poly(st, [a, b, b + height, a + height], [Vector2(uv[0]/tw, (uv[1]+uv[3])/th), Vector2((uv[0]+uv[2])/tw, (uv[1]+uv[3])/th), Vector2((uv[0]+uv[2])/tw, uv[1]/th), Vector2(uv[0]/tw, uv[1]/th)])
	for c in fragments:
		if c.size()>9 and int(c[9])==1:continue
		if int(c[1]) == 0 and corner_columns.has(int(c[0])): continue
		var n := float(c[2])
		var r := float(c[5]) if c.size() > 5 else 0.0
		var terrain: bool = c.size() > 9 and int(c[9]) == 2
		var box: bool = r > 0.0 and (n >= 4.0 or indoor or terrain)
		plan.append([c, r, box])
		if box:
			box_cols["%d:%d" % [int(c[0]), int(c[1]) + int(n) - _ovf(c)]] = box_profile(c)
	for it in plan:
		var c: Array = it[0]
		var r: float = it[1]
		var x := float(c[0])
		var n := float(c[2])
		var z := float(c[1]) + n - float(_ovf(c))
		var u0 := float(c[3]) / tw
		var v0 := float(c[4]) / th
		var u1 := u0 + t / tw
		var v1 := v0 + t * n / th
		var low := float(c[6]) if c.size() > 6 else 1.0
		var tilt := float(c[7]) if c.size() > 7 else 0.0
		if c.size()>10 and int(c[9])==5:
			if _fence_image==null:_fence_image=atlas.get_image()
			for panel in fence_panels(Vector2i(int(x),int(c[1])),int(c[10])):
				var a: Vector2=panel.a
				var b: Vector2=panel.b
				var edge:=Vector3(b.x-a.x,0,b.y-a.y)
				var normal:=Vector3(-edge.z,0,edge.x).normalized()
				var origin:=Vector3(a.x,0,a.y)
				var depth:=0.14
				var offset:=normal*depth*0.5
				var pu0:=lerpf(u0,u1,panel.uv.x)
				var pu1:=lerpf(u0,u1,panel.uv.y)
				_quad(st,origin+offset,edge,Vector3.UP*k,normal,pu0,pu1,v0,v1)
				_quad(st,origin-offset,edge,Vector3.UP*k,-normal,pu0,pu1,v0,v1)
				# Close the opaque pixel outline so side rails remain visible
				# when the camera looks almost directly along their length.
				var clip:=Rect2i(int(c[3])+roundi(t*panel.uv.x),int(c[4]),roundi(t*(panel.uv.y-panel.uv.x)),int(t))
				if not _fence_profiles.has(clip):_fence_profiles[clip]=fence_profile(_fence_image,clip)
				for cap in _fence_profiles[clip]:
					var p: Vector2=cap[0]
					var q: Vector2=cap[1]
					var p3:=origin+edge*(p.x/clip.size.x)+Vector3.UP*k*(1.0-p.y/t)
					var q3:=origin+edge*(q.x/clip.size.x)+Vector3.UP*k*(1.0-q.y/t)
					var cu: float=(clip.position.x+cap[2].x+0.5)/tw
					var cv: float=(clip.position.y+cap[2].y+0.5)/th
					_quad(st,p3-offset,q3-p3,normal*depth,(q3-p3).cross(normal).normalized(),cu,cu,cv,cv)
			continue
		if tilt > 0.0 and (flora_pilot_tile(map_dir, Vector2i(int(x), int(c[1]))) or (c.size() > 9 and int(c[9]) == 4)):
			_build_layered_flora(st, x, z, u0, u1, v0, v1)
			continue
		if tilt > 0.0:
			# 꽃·수풀: 칸의 남쪽 가장자리를 바닥에 붙이고 북쪽으로 tilt° 만 들어 올린 판(위로 지나가는 느낌, 사용자 2026-11-02)
			# 판 길이는 화면에서 정확히 한 칸 크기로 보이게(sin 높이각 / sin(높이각 + 기울기)) — 한 칸 그대로면 1.4칸쯤으로 늘어
			# 앞뒤 줄이 겹쳐 풀숲이 빽빽한 융단처럼 이어졌다.
			var ta := deg_to_rad(tilt)
			var ea := deg_to_rad(elev_deg)
			var flen := n * sin(ea) / sin(ea + ta)
			_quad(st, Vector3(x, 0.01, z), Vector3(1, 0, 0), Vector3(0.0, sin(ta), -cos(ta)) * flen, Vector3(0.0, cos(ta), sin(ta)), u0, u1, v0, v1)
			continue
		if not bool(it[2]):
			_quad(st, Vector3(x, 0.0, z), Vector3(1, 0, 0), Vector3(0, n * k * low, 0), Vector3.BACK, u0, u1, v0, v1)
			continue
		var vm := v0 + t * r / th                                 # 윗면과 앞면의 경계
		var profile := box_profile(c)
		var hgt := profile.x * k
		_quad(st, Vector3(x, 0.0, z), Vector3(1, 0, 0), Vector3(0, hgt, 0), Vector3.BACK, u0, u1, vm, v1)        # 앞면
		var bz := int(z)
		# A shorter adjoining facade cannot close a tall building's upper side.
		var left: bool = box_cols.get("%d:%d" % [int(x) - 1, bz],Vector2.ZERO)!=profile
		var right: bool = box_cols.get("%d:%d" % [int(x) + 1, bz],Vector2.ZERO)!=profile
		_quad(st, Vector3(x, hgt, z), Vector3(1, 0, 0), Vector3(0, 0, -r), Vector3.UP, u0, u1, v0, vm)           # 윗면(평평한 지붕·가구 윗면)
		# Terrain/building c[10] selects an intact source column; the outer pixel can be lawn/path.
		var side_pixel: int = int(c[10]) if c.size() > 10 and int(c[9]) in [2, 3] else -1
		var side_left_u := u0 + side_pixel * px_u if side_pixel >= 0 else u0
		var side_right_u := side_left_u if side_pixel >= 0 else u1 - px_u
		var side_depth := maxf(0.0, r - (float(c[11]) if c.size() > 11 and int(c[9]) == 3 else 0.0))
		if left and side_depth > 0.0001:
			var side_def: Dictionary = side_surfaces.get("%d:%d:left" % [int(x), bz], {})
			if not side_def.is_empty():
				# Roof art can have transparent rear padding; the wall ends at its visible edge.
				var depth := maxf(0.0, r - float(side_def.get("rear_inset", 0.0)))
				_build_card_side(map_dir + "/" + String(side_def["texture"]), Vector3(x, 0, z), Vector3(0, 0, -depth), Vector3(0, hgt, 0), Vector3.LEFT, parent)
			else:
				_quad(st, Vector3(x, 0.0, z), Vector3(0, 0, -side_depth), Vector3(0, hgt, 0), Vector3.LEFT, side_left_u, side_left_u + px_u, vm, v1)   # 왼쪽 옆면
		if right and side_depth > 0.0001:
			_quad(st, Vector3(x + 1.0, 0.0, z - side_depth), Vector3(0, 0, side_depth), Vector3(0, hgt, 0), Vector3.RIGHT, side_right_u, side_right_u + px_u, vm, v1)   # 오른쪽 옆면
	if not plan.is_empty() or not corner_columns.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = atlas
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 1.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mat.metallic_specular = 0.0
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mi)
	var tree_mesh := TreeCanopy.build(cards,atlas,k,_ground_static_geometry,tan(deg_to_rad(elev_deg)),HgssEnvironment.tree_texture())
	if tree_mesh!=null:parent.add_child(tree_mesh)
	if j.has("nest_decor"):parent.add_child(NestBranches.build(j.nest_decor,atlas))

static func fence_panels(tile: Vector2i, metatile: int) -> Array:
	# White native fence: left/right rails run along the ground, with the same
	# upright front texture as horizontal spans. Corner posts share both planes.
	var x:=float(tile.x)
	var z:=float(tile.y)
	var out: Array=[]
	# Saffron's blue rails belong to its secondary tileset. Use the original
	# horizontal rail art along a connected ground path, including every turn.
	if metatile>=0x300:
		var spine:=0.25 if metatile in [0x318,0x320,0x326,0x328,0x32e,0x345,0x347] else 0.75
		if metatile in [0x318,0x31a,0x320,0x322,0x325,0x326,0x328,0x32a,0x32d,0x32e,0x344,0x345,0x346,0x347]:
			out.append({"a":Vector2(x+spine,z),"b":Vector2(x+spine,z+1),"uv":Vector2(0,1)})
		if metatile not in [0x320,0x322,0x344,0x345,0x346,0x347]:
			var lo:=spine if metatile in [0x318,0x328,0x32d,0x325] else 0.375 if metatile==0x323 else 0.0
			var hi:=spine if metatile in [0x31a,0x32a,0x32e,0x326] else 1.0
			out.append({"a":Vector2(x+lo,z+1),"b":Vector2(x+hi,z+1),"uv":Vector2(lo,hi)})
		return out
	if metatile in [0x0e7,0x0ed,0x0ee,0x0ef,0x0f6,0x0f7]:
		var left:=0.5 if metatile in [0x0ee,0x0f6] else 0.0
		var right:=0.5 if metatile in [0x0ef,0x0f7] else 1.0
		out.append({"a":Vector2(x+left,z+1),"b":Vector2(x+right,z+1),"uv":Vector2(left,right)})
	if metatile in [0x0f4,0x0f5,0x0f6,0x0f7]:
		var side:=0.25 if metatile in [0x0f4,0x0f7] else 0.75
		out.append({"a":Vector2(x+side,z),"b":Vector2(x+side,z+1),"uv":Vector2(0,1)})
	return out

static func fence_profile(image: Image, rect: Rect2i) -> Array:
	var edges: Array=[]
	for y in rect.size.y:
		for x in rect.size.x:
			var pixel:=Vector2i(x,y)
			if image.get_pixelv(rect.position+pixel).a<0.5:continue
			for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var neighbor: Vector2i=pixel+side
				if Rect2i(Vector2i.ZERO,rect.size).has_point(neighbor) and image.get_pixelv(rect.position+neighbor).a>=0.5:continue
				var a:=Vector2(x,y)
				var b:=a+Vector2.DOWN
				if side==Vector2i.RIGHT:a+=Vector2.ONE;b=a+Vector2.UP
				elif side==Vector2i.UP:b=a;a+=Vector2.RIGHT
				elif side==Vector2i.DOWN:a+=Vector2.DOWN;b=a+Vector2.RIGHT
				edges.append([a,b,Vector2(pixel)])
	return edges

# Small pilot only: original atlas pixels are partitioned, never duplicated.
# Bottom four pixel rows stay low; upper leaf/flower clusters rise independently.
static func flora_pilot_tile(map_dir: String, tile: Vector2i) -> bool:
	if map_dir == DungeonDB.theme().get("map", "") and Arena.is_grass(tile):
		return true
	return map_dir == "res://assets/maps/kanto_field" and (Rect2i(17, 232, 4, 2).has_point(tile) or Rect2i(16, 212, 5, 4).has_point(tile))

static func flora_ground_frame(tile: Vector2i) -> Transform3D:
	var heights := Arena.ground_corners(tile)
	var dx := (float(heights[1])+float(heights[2])-float(heights[0])-float(heights[3]))*0.5
	var dz := (float(heights[2])+float(heights[3])-float(heights[0])-float(heights[1]))*0.5
	# Shear along the ramp while preserving the original one-tile footprint.
	return Transform3D(Basis(Vector3(1,dx,0),Vector3.UP,Vector3(0,dz,1)),to3d(Arena.tile_center(tile)))

func _build_layered_flora(st: SurfaceTool, x: float, z: float, u0: float, u1: float, v0: float, v1: float, local_tile := Vector2i(-1,-1)) -> void:
	var grounded := _ground_static_geometry
	var follow_floor := grounded or local_tile.x>=0
	var tile := Vector2i(int(x),int(z)-1) if grounded else local_tile
	var frame := flora_ground_frame(tile) if follow_floor else Transform3D.IDENTITY
	_ground_static_geometry=false
	var origin := Vector3(-0.5,0,0.5) if follow_floor else Vector3(x,0,z)
	var split := lerpf(v0, v1, 0.75)
	_flora_quad(st,frame,origin+Vector3(0,0.015,0),Vector3.RIGHT,Vector3(0,0,-0.25),u0,u1,split,v1,follow_floor,not grounded)
	for part in 2:
		var angle := deg_to_rad(50.0 if part == 0 else 65.0)
		var length := 0.75 * sin(deg_to_rad(elev_deg)) / sin(deg_to_rad(elev_deg) + angle)
		var up := Vector3(0, sin(angle), -cos(angle)) * length
		_flora_quad(st,frame,origin+Vector3(part*0.5,0.015,-0.25),Vector3(0.5,0,0),up,
			lerpf(u0, u1, part * 0.5), lerpf(u0, u1, (part + 1) * 0.5), v0, split,follow_floor,not grounded)
	_ground_static_geometry=grounded

func _flora_quad(st: SurfaceTool, frame: Transform3D, origin: Vector3, across: Vector3, up: Vector3, u0: float, u1: float, v0: float, v1: float, follow_floor: bool, local_space: bool) -> void:
	var points: Array=[]
	var inverse := frame.affine_inverse()
	for local in [origin+up,origin+across+up,origin+across,origin]:
		var point: Vector3=frame*local
		if follow_floor:
			# A tile may bend across its diagonal. Sample each root independently
			# instead of allowing the best-fit ramp plane to bury a leaf corner.
			point.y=Arena.ground_height(Vector2(point.x,point.z)*Arena.TILE)+local.y
		points.append(inverse*point if local_space else point)
	var uv := [Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)]
	for triangle in [[0,1,2],[0,2,3]]:
		st.set_normal((points[triangle[2]]-points[triangle[0]]).cross(points[triangle[1]]-points[triangle[0]]).normalized())
		for index in triangle:
			st.set_uv(uv[index])
			st.add_vertex(points[index])

# Optional authored side art replaces the one-pixel edge extrusion for selected cards.
func _build_card_side(texture_path: String, origin: Vector3, across: Vector3, up: Vector3, normal: Vector3, parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st,origin,across,up,normal,0,1,0,1)
	var side := MeshInstance3D.new()
	side.mesh = st.commit()
	side.material_override = _house_mat(texture_path)
	parent.add_child(side)

static func _ovf(c: Array) -> int:
	return int(c[8]) if c.size() > 8 else 0

# ── 집(도트 재구성 시범, 사용자 2026-11-02) ──
# 카드에 억지로 x·y 를 주니 어색해서, 태초마을형 집은 면마다 새로 짠 도트(tools/hd2d_cards.py build_houses)로 상자 + 평평한 지붕판을
# 짓는다. 앞면은 원작 그대로, 옆벽·뒷벽은 앞면을 복사해 짠 것, 지붕판 윗면은 원작 지붕 그림. 모임지붕(경사)도 해 봤지만 평평한 게
# 낫다(사용자 2026-11-02). 집 = {x, z(앞면), w, d(지붕 깊이), tex}.
const EAVE := 0.0             # 처마가 벽보다 내미는 길이(m). 0 — 내밀면 집 사이 길이 좁아 보였다(사용자 2026-11-02: 위치는 원작과 같게)
const ROOF_T := 0.14          # 평평한 지붕판 두께(m)

func _build_houses(map_dir: String, j: Dictionary = {}) -> void:
	if j.is_empty(): j = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/hd2d_cards.json"))
	var houses: Array = []
	for i in j.get("houses", []).size():
		if not HgssEnvironment.replaces_house(map_dir, i): houses.append(j.houses[i])
	_draw_houses(map_dir, j, houses, root3d)

func _add_scenery(node: Node3D) -> void:
	var parent := _scenery_parent if _scenery_parent != null else root3d
	parent.add_child(node)

func _draw_houses(map_dir: String, j: Dictionary, houses: Array, parent: Node3D) -> void:
	_scenery_parent = parent
	if j.has("museum_stairs"):
		_build_museum_stairs(j.museum_stairs)
	for fence in j.get("log_fences", []):
		_build_log_fence(map_dir,fence)
	for house in houses: _build_house(map_dir, house)
	for pdef in j.get("props", []):
		_build_prop(map_dir, pdef)
	for tdef in j.get("tables", []):
		_build_table(map_dir, tdef)
		var tile := Vector2(StarterBalls.TILES["charmander"]) + Vector2(0.5, 0.5)
		if tile.x >= float(tdef["x0"]) and tile.x <= float(tdef["x1"]) and tile.y >= float(tdef["z0"]) and tile.y <= float(tdef["z1"]):
			_starter_table_height = float(tdef.get("leg", 0.0)) + float(tdef.get("thick", 0.0))

	_scenery_parent = null

# Museum stairs follow the original left-to-right rise and gold/white rails.
func _build_museum_stairs(spec: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "MuseumStairs"
	_add_scenery(group)
	var width := (float(spec.x1)-float(spec.x0))/int(spec.steps)
	var z0 := float(spec.z0)
	var depth := float(spec.z1)-z0
	for i in int(spec.steps):
		var x := float(spec.x0)+i*width
		var h := float(spec.height)*(i+1)/int(spec.steps)
		_museum_step_box(group,Vector3(x,0,z0),Vector3(width,h,depth),Color8(180,148,74))
		_museum_step_box(group,Vector3(x,h,z0+0.0625),Vector3(width,0.03125,depth-0.125),Color8(213,189,98))
		for z in [z0,float(spec.z1)-0.0625]:
			_museum_step_box(group,Vector3(x,h,z),Vector3(width,0.1875,0.0625),Color8(213,189,98))
			_museum_step_box(group,Vector3(x,h+0.1875,z),Vector3(width,0.0625,0.0625),Color8(230,230,213))

func _museum_step_box(group: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(size.x,size.y*k,size.z)
	var node := MeshInstance3D.new()
	node.mesh = box
	node.position = Vector3(at.x,at.y*k,at.z)+box.size*0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	node.material_override = mat
	group.add_child(node)

# Preserve the original pixel silhouette; posts are independent, fixed cutout meshes.
func _build_log_fence(map_dir: String, spec: Dictionary) -> void:
	# Log mesh vertices are local; their world-space node gets the altitude.
	var grounded := _ground_static_geometry
	_ground_static_geometry=false
	_build_log_fence_geometry(map_dir,spec)
	_ground_static_geometry=grounded

func _build_log_fence_geometry(map_dir: String, spec: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "LogFence_"+String(spec.id)
	_add_scenery(group)
	if spec.has("source_cells"):
		_build_source_log_cells(map_dir,spec,group)
		return
	var material := _house_mat(map_dir+"/hd2d_log_front.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var height := float(spec.height)*k
	for tile in spec.posts:
		for offset in spec.get("bundle_offsets",spec.get("offsets",[0.0])):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			_poly(surface,[Vector3(-0.5,0,0),Vector3(0.5,0,0),Vector3(0.5,height,0),Vector3(-0.5,height,0)],
				[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2.ZERO])
			var node := MeshInstance3D.new()
			node.name = "Log_%s_%s_%s" % [tile[0],tile[1],offset]
			node.mesh = surface.commit()
			node.material_override = material
			node.position = Vector3(float(tile[0])+0.5+(0.0 if spec.has("bundle_offsets") else float(offset)),0,float(tile[1])+0.5+(float(offset) if spec.has("bundle_offsets") else 0.5))
			node.position.y+=Arena.ground_height(Vector2(node.position.x,node.position.z)*Arena.TILE)
			group.add_child(node)

# Split each original tile into two independently placed half-width pixel objects.
# UVs preserve partial/staggered source posts instead of repeating one new design.
func _build_source_log_cells(map_dir: String, spec: Dictionary, group: Node3D) -> void:
	var materials := {}
	for cell in spec.source_cells:
		var path := map_dir+"/"+String(cell.tex)+".png"
		if not materials.has(path):
			materials[path] = _house_mat(path)
			materials[path].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		for half in 2:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var u0 := half*0.5
			var u1 := u0+0.5
			_poly(st,[Vector3(-0.25,0,0),Vector3(0.25,0,0),Vector3(0.25,k,0),Vector3(-0.25,k,0)],
				[Vector2(u0,1),Vector2(u1,1),Vector2(u1,0),Vector2(u0,0)])
			var node := MeshInstance3D.new()
			node.name = "SourceLog_%s_%s_%d"%[cell.tile[0],cell.tile[1],half]
			node.mesh = st.commit()
			node.material_override = materials[path]
			node.position = Vector3(float(cell.tile[0])+0.25+half*0.5,0,float(cell.tile[1])+1.0)
			node.position.y+=Arena.ground_height(Vector2(node.position.x,node.position.z)*Arena.TILE)
			group.add_child(node)

# 탁자(사용자 2026-11-02 오박사 연구소: '다리를 0.5 정도 축으로 만들고 위에 판을 평평하게'): 다리(leg 0.5m) 위에 평평한 판.
# 판 = 윗면(원작 윗판 그림)·앞뒤(원작 앞 띠)·옆(앞 띠 가장자리 색) — 두께는 원작 앞 띠 줄 수. 다리 = 네 모서리 기둥(원작 다리 열),
# 다리가 하나만 정의되면 왼쪽 앞뒤 다리 + 오른쪽은 바닥까지 닿는 서랍장 상자. 다리 사이에 판 밑에 매달린 틀(apron),
# 판 위 물건(컴퓨터)은 판 가운데에 세운 판(decor). 도구: tools/hd2d_cards.py build_tables. 단위는 칸(m).
func _build_table(map_dir: String, t: Dictionary) -> void:
	_ground_anchor=Vector2((float(t.x0)+float(t.x1))*0.5,float(t.z1))
	_build_table_geometry(map_dir,t)
	_ground_anchor=Vector2.INF

func _build_table_geometry(map_dir: String, t: Dictionary) -> void:
	var base := map_dir + "/" + String(t["tex"])
	var x0 := float(t["x0"])
	var x1 := float(t["x1"])
	var z0 := float(t["z0"])
	var z1 := float(t["z1"])
	if bool(t.get("chair", false)):
		_build_gate_chair(t)
		return
	if bool(t.get("display_rack", false)):
		_build_display_rack(base, t)
		return
	if float(t.get("recess", 0.0)) > 0.0:
		_build_recessed_machine(base, t)
		return
	if bool(t.get("counter", false)):
		_build_counter(map_dir, t)
		return
	if bool(t.get("counter_vase", false)):
		_build_counter_vase(Vector3((x0+x1)*0.5,0.5*k,z1))
	if bool(t.get("planter", false)):
		_build_planter(Vector3((x0+x1)*0.5,0,z1))
	if bool(t.get("card", false)):
		var base_y := float(t.get("base", 0.0)) * k
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points: Array
		if bool(t.get("decal", false)):
			points = [Vector3(x0,base_y,z1),Vector3(x1,base_y,z1),Vector3(x1,base_y,z0),Vector3(x0,base_y,z0)]
		elif bool(t.get("side_card", false)):
			points = [Vector3(x0,base_y,z1),Vector3(x0,base_y,z0),Vector3(x0,base_y+float(t.h)*k,z0),Vector3(x0,base_y+float(t.h)*k,z1)]
		else:
			points = [Vector3(x0, base_y, z1), Vector3(x1, base_y, z1), Vector3(x1, (float(t["h"]) * k) + base_y, z1), Vector3(x0, (float(t["h"]) * k) + base_y, z1)]
		_poly(st, points, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var mat := _house_mat(base + "_front.png")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mi.material_override = mat
		if bool(t.get("decal", false)):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_scenery(mi)
		if float(t.get("thickness", 0.0)) > 0.0:
			_build_card_body(base, t)
		return
	if bool(t.get("box", false)):
		_build_furniture_box(base, x0, x1, z0, z1, float(t["h"]) * k, float(t.get("base", 0.0)) * k, bool(t.get("closed", false)))
		return
	var yb := float(t["leg"])
	var yt := yb + float(t["thick"])
	var faces := {
		"top": [[Vector3(x0, yt, z1), Vector3(x1, yt, z1), Vector3(x1, yt, z0), Vector3(x0, yt, z0)]],
		"edge": [[Vector3(x0, yb, z1), Vector3(x1, yb, z1), Vector3(x1, yt, z1), Vector3(x0, yt, z1)],
			[Vector3(x1, yb, z0), Vector3(x0, yb, z0), Vector3(x0, yt, z0), Vector3(x1, yt, z0)]],
		"eside": [[Vector3(x0, yb, z0), Vector3(x0, yb, z1), Vector3(x0, yt, z1), Vector3(x0, yt, z0)],
			[Vector3(x1, yb, z1), Vector3(x1, yb, z0), Vector3(x1, yt, z0), Vector3(x1, yt, z1)]],
		"leg": [],
	}
	var lw := float(t.get("leg_w", 0.0))
	var legs: Array = t.get("legs", [])
	var spots: Array = []                                    # [x 왼쪽, x 오른쪽, z 뒤, z 앞]
	for l in legs:
		spots.append([float(l[0]), float(l[1]), z1 - lw, z1])
		spots.append([float(l[0]), float(l[1]), z0, z0 + lw])
	for sp in spots:
		faces["leg"].append_array(_box_sides(sp[0], sp[1], 0.0, yb, sp[2], sp[3]))
	if t.get("pedestal") != null:
		var p: Array = t["pedestal"]
		var b := _box_sides(float(p[0]), float(p[1]), 0.0, yb, z0 + 0.02, z1 - 0.02)
		faces["ped"] = [b[0], b[1]]
		faces["pedside"] = [b[2], b[3]]
	var ah := float(t.get("apron", 0.0))
	if ah > 0.0:
		var az := z1 - 0.03
		faces["apron"] = [[Vector3(x0, yb - ah, az), Vector3(x1, yb - ah, az), Vector3(x1, yb, az), Vector3(x0, yb, az)]]
	if t.get("decor") != null:
		var dz := (z0 + z1) / 2.0
		var dh := float(t["decor"]["h"]) * k
		faces["decor"] = [[Vector3(x0, yt, dz), Vector3(x1, yt, dz), Vector3(x1, yt + dh, dz), Vector3(x0, yt + dh, dz)]]
	var mesh := ArrayMesh.new()
	for key in faces:
		if faces[key].is_empty() or not ResourceLoader.exists(base + "_" + key + ".png"):
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for q in faces[key]:
			_poly(st, q, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		st.commit(mesh)
		var mat := _house_mat(base + "_" + key + ".png")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_add_scenery(mi)

# Gate seats retain the source blue cushion, a side backrest and grounded legs.
func _build_gate_chair(t: Dictionary) -> void:
	var x0 := float(t.x0)
	var x1 := float(t.x1)
	var z0 := float(t.z0)
	var z1 := float(t.z1)
	var frame := Color8(82,82,106)
	var parts := []
	for x in [x0+0.0625,x1-0.125]:
		for z in [z0+0.0625,z1-0.125]:
			parts.append([Vector3(x,0,z),Vector3(0.0625,0.15625,0.0625),frame])
	parts.append([Vector3(x0,0.15625,z0),Vector3(x1-x0,0.0625,z1-z0),frame])
	parts.append([Vector3(x0+0.0625,0.21875,z0+0.0625),Vector3(x1-x0-0.125,0.0625,z1-z0-0.125),Color8(139,205,238)])
	var back_x := x0 if t.side=="left" else x1-0.125
	parts.append([Vector3(back_x,0.21875,z0),Vector3(0.125,0.34375,z1-z0),frame])
	parts.append([Vector3(back_x+0.01,0.3125,z0+0.0625),Vector3(0.105,0.1875,z1-z0-0.125),Color8(106,180,213)])
	for part in parts:
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size: Vector3 = part[1]
		box.size = Vector3(size.x,size.y*k,size.z)
		node.mesh = box
		var start: Vector3 = part[0]
		node.position = Vector3(start.x,start.y*k,start.z)+box.size*0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[2]
		mat.roughness = 1.0
		node.material_override = mat
		_add_scenery(node)

# Small source-colored flower vase rests directly on the counter top.
func _build_counter_vase(at: Vector3) -> void:
	var heights := [0.0,0.0625,0.25,0.3125]
	var radii := [0.23,0.27,0.3125,0.3125]
	var colors := [Color8(90,90,106),Color8(180,172,100),Color8(123,123,123)]
	for i in 3:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.bottom_radius = radii[i]
		mesh.top_radius = radii[i+1]
		mesh.height = (heights[i+1]-heights[i])*k
		var node := MeshInstance3D.new()
		node.name = "CounterVaseBand%d" % i
		node.mesh = mesh
		node.position = at + Vector3.UP*(heights[i]+heights[i+1])*0.5*k
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.roughness = 1.0
		node.material_override = mat
		_add_scenery(node)

# Eight-sided pot with a broad rim and a narrower foot, grounded at y=0.
func _build_planter(at: Vector3) -> void:
	var heights := [0.0,0.0625,0.125,0.375,0.4375,0.5625]
	var radii := [0.22,0.24,0.26,0.32,0.35,0.35]
	var colors := [Color8(74,74,90),Color8(148,148,140),Color8(180,180,164),Color8(90,90,98),Color8(180,180,164)]
	for i in 5:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.bottom_radius = radii[i]
		mesh.top_radius = radii[i+1]
		mesh.height = (heights[i+1]-heights[i])*k
		var node := MeshInstance3D.new()
		node.name = "PlanterBand%d" % i
		node.mesh = mesh
		node.position = at + Vector3.UP*(heights[i]+heights[i+1])*0.5*k
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.roughness = 1.0
		node.material_override = mat
		_add_scenery(node)

	var soil := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.radial_segments = 8
	disk.top_radius = 0.27
	disk.bottom_radius = 0.27
	disk.height = 0.01
	soil.mesh = disk
	soil.position = at + Vector3.UP * (0.5625*k+0.006)
	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Color8(74,66,58)
	soil_mat.roughness = 1.0
	soil.material_override = soil_mat
	_add_scenery(soil)

# Recovery machine: raised housing surrounds a lower horizontal operating bed.
# UVs keep the original controls on the bed; both end panels share the cross.
func _build_recessed_machine(base: String, t: Dictionary) -> void:
	var x0 := float(t.x0)
	var x1 := float(t.x1)
	var z0 := float(t.z0)
	var z1 := float(t.z1)
	var bottom := float(t.base) * k
	var rim := bottom + float(t.h) * k
	var bed := rim - float(t.recess) * k
	var ix0 := lerpf(x0, x1, 8.0/31.0)
	var ix1 := lerpf(x0, x1, 24.0/31.0)
	var iz0 := lerpf(z0, z1, 8.0/28.0)
	var iz1 := lerpf(z0, z1, 23.0/28.0)
	_healing_bed = Vector3((ix0 + ix1) * 0.5, bed, (iz0 + iz1) * 0.5)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Four rim strips plus the lowered bed; no surface covers the recess.
	for patch in [[x0,x1,z0,iz0,rim], [x0,x1,iz1,z1,rim], [x0,ix0,iz0,iz1,rim], [ix1,x1,iz0,iz1,rim], [ix0,ix1,iz0,iz1,bed]]:
		var a := float(patch[0])
		var b := float(patch[1])
		var back := float(patch[2])
		var front := float(patch[3])
		var height := float(patch[4])
		_poly(st, [Vector3(a,height,front),Vector3(b,height,front),Vector3(b,height,back),Vector3(a,height,back)],
			[Vector2((a-x0)/(x1-x0),(front-z0)/(z1-z0)),Vector2((b-x0)/(x1-x0),(front-z0)/(z1-z0)),Vector2((b-x0)/(x1-x0),(back-z0)/(z1-z0)),Vector2((a-x0)/(x1-x0),(back-z0)/(z1-z0))])
	st.commit(mesh)
	var top_material := _house_mat(base + "_top.png")
	top_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh.surface_set_material(0, top_material)
	var outer := _box_sides(x0,x1,bottom,rim,z0,z1)
	var inner := _box_sides(ix0,ix1,bed,rim,iz0,iz1)
	var groups := [[outer[0],outer[1]], [outer[2],outer[3], [Vector3(x0,bottom,z0),Vector3(x1,bottom,z0),Vector3(x1,bottom,z1),Vector3(x0,bottom,z1)]], inner]
	for i in groups.size():
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in groups[i]: _poly(st,face,[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
		st.commit(mesh)
		var mat := _house_mat(base + ("_front.png" if i == 0 else "_side.png"))
		if i == 2:
			mat.albedo_texture = null
			mat.albedo_color = Color8(131,131,139)
		mesh.surface_set_material(i + 1, mat)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	_add_scenery(node)

# 상자 가구(책장, 사용자 2026-11-02 '바닥이 꺾여 이상하다'): 원작 앞면 전체를 세우고 원작 윗단을 평평한 윗면으로, 옆면은 앞면 둘째 열 색.
# U-shaped counter: transparent top opening and all eight perimeter faces.
func _build_counter(map_dir: String, t: Dictionary) -> void:
	var x0 := float(t.x0)
	var x1 := float(t.x1)
	var back := float(t.z0)
	var front := float(t.z1)
	var inner := float(t.inner_z)
	var arm := float(t.arm)
	var height := float(t.h) * k
	var contour := [Vector2(x0,front),Vector2(x1,front),Vector2(x1,back),Vector2(x1-arm,back),Vector2(x1-arm,inner),Vector2(x0+arm,inner),Vector2(x0+arm,back),Vector2(x0,back)]
	var mesh := ArrayMesh.new()
	for i in 9:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points: Array
		if i == 0:
			points = [Vector3(x0,height,front),Vector3(x1,height,front),Vector3(x1,height,back),Vector3(x0,height,back)]
		else:
			var a: Vector2 = contour[i-1]
			var b: Vector2 = contour[i%8]
			points = [Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(b.x,height,b.y),Vector3(a.x,height,a.y)]
		_poly(st, points, [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
		st.commit(mesh)
		var face := "top" if i == 0 else ("front" if i == 1 else "side")
		var mat := _house_mat(map_dir + "/" + String(t.tex) + "_" + face + ".png")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(i, mat)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	_add_scenery(node)

# Merchandise sits on sloping trays beside a narrow raised divider.
# Extrude only opaque sprite pixels, preserving the register's stepped silhouette.
func _build_card_body(base: String, t: Dictionary) -> void:
	var img := (load(base+"_front.png") as Texture2D).get_image()
	var width := img.get_width()
	var height := img.get_height()
	var dx := (float(t.x1)-float(t.x0))/width
	var dy := float(t.h)*k/height
	var front := float(t.z1)-0.001
	var back := front-float(t.thickness)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
	for y in height:
		for x in width:
			if img.get_pixel(x,y).a < 0.5: continue
			var left := float(t.x0)+x*dx
			var right := left+dx
			var top := (float(t.base)+float(t.h))*k-y*dy
			var bottom := top-dy
			_poly(st,[Vector3(left,bottom,back),Vector3(right,bottom,back),Vector3(right,top,back),Vector3(left,top,back)],uv)
			if x == 0 or img.get_pixel(x-1,y).a < 0.5:
				_poly(st,[Vector3(left,bottom,back),Vector3(left,bottom,front),Vector3(left,top,front),Vector3(left,top,back)],uv)
			if x == width-1 or img.get_pixel(x+1,y).a < 0.5:
				_poly(st,[Vector3(right,bottom,front),Vector3(right,bottom,back),Vector3(right,top,back),Vector3(right,top,front)],uv)
			if y == 0 or img.get_pixel(x,y-1).a < 0.5:
				_poly(st,[Vector3(left,top,front),Vector3(right,top,front),Vector3(right,top,back),Vector3(left,top,back)],uv)
			if y == height-1 or img.get_pixel(x,y+1).a < 0.5:
				_poly(st,[Vector3(left,bottom,back),Vector3(right,bottom,back),Vector3(right,bottom,front),Vector3(left,bottom,front)],uv)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(145,147,135)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = material
	_add_scenery(body)
	var plinth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(float(t.x1)-float(t.x0),0.0625*k,float(t.thickness)+0.125)
	plinth.mesh = box
	plinth.material_override = material
	plinth.position = Vector3((float(t.x0)+float(t.x1))*0.5,(float(t.base)-0.03125)*k,(front+back)*0.5)
	_add_scenery(plinth)

func _build_display_rack(base: String, t: Dictionary) -> void:
	var x0 := float(t.x0)
	var x1 := float(t.x1)
	var mid := (x0+x1)*0.5
	var z0 := float(t.z0)
	var z1 := float(t.z1)
	var profile := [Vector2(x0,0.5),Vector2(mid-0.125,0.6875),Vector2(mid-0.125,0.875),Vector2(mid+0.125,0.875),Vector2(mid+0.125,0.6875),Vector2(x1,0.5)]
	var mesh := ArrayMesh.new()
	for surface in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in profile.size()-1:
			var a: Vector2 = profile[i]
			var b: Vector2 = profile[i+1]
			if (surface == 0 and i in [0,4]) or (surface == 1 and i in [1,2,3]):
				_poly(st,[Vector3(a.x,a.y*k,z0),Vector3(a.x,a.y*k,z1),Vector3(b.x,b.y*k,z1),Vector3(b.x,b.y*k,z0)],[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
			if surface == 2 and b.x > a.x:
				for z in [z0,z1]:
					_poly(st,[Vector3(a.x,0,z),Vector3(b.x,0,z),Vector3(b.x,b.y*k,z),Vector3(a.x,a.y*k,z)],[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
		if surface == 2:
			for x in [x0,x1]:
				_poly(st,[Vector3(x,0,z0),Vector3(x,0,z1),Vector3(x,0.5*k,z1),Vector3(x,0.5*k,z0)],[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
		st.commit(mesh)
		var mat := _house_mat(base + ["_side.png","_top.png","_front.png"][surface])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(surface,mat)
	var node := MeshInstance3D.new()
	node.name = "DisplayRack"
	node.mesh = mesh
	_add_scenery(node)

func _build_furniture_box(base: String, x0: float, x1: float, z0: float, z1: float, hh: float, base_y: float = 0.0, closed: bool = false) -> void:
	hh += base_y
	var b := _box_sides(x0, x1, base_y, hh, z0, z1)
	var faces := {
		"front": [b[0]],
		"top": [[Vector3(x0, hh, z1), Vector3(x1, hh, z1), Vector3(x1, hh, z0), Vector3(x0, hh, z0)]],
		"side": [b[2], b[3]],
	}
	if closed:
		faces["side"].append(b[1])
		faces["side"].append([Vector3(x0, base_y, z0), Vector3(x1, base_y, z0), Vector3(x1, base_y, z1), Vector3(x0, base_y, z1)])
	var mesh := ArrayMesh.new()
	for key in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for q in faces[key]:
			_poly(st, q, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		st.commit(mesh)
		var mat := _house_mat(base + "_" + key + ".png")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_add_scenery(mi)

# 상자의 네 옆면 [앞, 뒤, 왼쪽, 오른쪽] — 바깥에서 볼 때 왼쪽 아래부터 반시계.
func _box_sides(x0: float, x1: float, y0: float, y1: float, zb: float, zf: float) -> Array:
	return [[Vector3(x0, y0, zf), Vector3(x1, y0, zf), Vector3(x1, y1, zf), Vector3(x0, y1, zf)],
		[Vector3(x1, y0, zb), Vector3(x0, y0, zb), Vector3(x0, y1, zb), Vector3(x1, y1, zb)],
		[Vector3(x0, y0, zb), Vector3(x0, y0, zf), Vector3(x0, y1, zf), Vector3(x0, y1, zb)],
		[Vector3(x1, y0, zf), Vector3(x1, y0, zb), Vector3(x1, y1, zb), Vector3(x1, y1, zf)]]

# 작은 물체(우체통, 사용자 2026-11-02: 집과 같은 구조로): 앞면(원작 몸통)·윗면(원작 뚜껑을 수평으로)·옆면(앞면 복사)·뒷면(앞면),
# 몸통 아래 가는 기둥(post). 원작 앞면 아래의 바닥 그림자 줄은 빼고 3D 해 그림자에 맡긴다(옆면에 그림자가 칠해졌다 — 사용자 지적).
# prop = {x0, x1(가로), z(앞면), d(깊이), h(앞면 높이), tex} — 단위는 칸(m).
func _build_prop(map_dir: String, pdef: Dictionary) -> void:
	var base := map_dir + "/" + String(pdef["tex"])
	var x0 := float(pdef["x0"])
	var x1 := float(pdef["x1"])
	var zf := float(pdef["z"]) - 0.06
	var zb := zf - float(pdef["d"])
	var y0 := float(pdef.get("post", 0.0)) * k                 # 몸통은 기둥 높이만큼 띄운다(원작의 바닥 그림자 줄은 빼고)
	var hh := y0 + float(pdef["h"]) * k
	var px0 := float(pdef.get("px0", (x0 + x1) / 2.0 - 0.06))
	var px1 := float(pdef.get("px1", (x0 + x1) / 2.0 + 0.06))
	_ground_anchor=Vector2((x0+x1)*0.5,zf)
	var pz := (zf + zb) / 2.0
	var mesh := ArrayMesh.new()
	var faces := {
		"front": [[Vector3(x0, y0, zf), Vector3(x1, y0, zf), Vector3(x1, hh, zf), Vector3(x0, hh, zf)],
			[Vector3(x1, y0, zb), Vector3(x0, y0, zb), Vector3(x0, hh, zb), Vector3(x1, hh, zb)]],
		"side": [[Vector3(x0, y0, zb), Vector3(x0, y0, zf), Vector3(x0, hh, zf), Vector3(x0, hh, zb)],
			[Vector3(x1, y0, zf), Vector3(x1, y0, zb), Vector3(x1, hh, zb), Vector3(x1, hh, zf)]],
		"top": [[Vector3(x0, hh, zf), Vector3(x1, hh, zf), Vector3(x1, hh, zb), Vector3(x0, hh, zb)],
			[Vector3(x0, y0, zb), Vector3(x1, y0, zb), Vector3(x1, y0, zf), Vector3(x0, y0, zf)]],
	}
	if y0 > 0.0 and FileAccess.file_exists(base + "_post.png"):
		var d2 := (px1 - px0) / 2.0
		faces["post"] = [[Vector3(px0, 0, pz + d2), Vector3(px1, 0, pz + d2), Vector3(px1, y0, pz + d2), Vector3(px0, y0, pz + d2)],
			[Vector3(px1, 0, pz - d2), Vector3(px0, 0, pz - d2), Vector3(px0, y0, pz - d2), Vector3(px1, y0, pz - d2)],
			[Vector3(px0, 0, pz - d2), Vector3(px0, 0, pz + d2), Vector3(px0, y0, pz + d2), Vector3(px0, y0, pz - d2)],
			[Vector3(px1, 0, pz + d2), Vector3(px1, 0, pz - d2), Vector3(px1, y0, pz - d2), Vector3(px1, y0, pz + d2)]]
	for key in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for q in faces[key]:
			_poly(st, q, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		st.commit(mesh)
		var mat := _house_mat(base + "_" + key + ".png")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_add_scenery(mi)
	_ground_anchor=Vector2.INF

const CenterPalette = preload("res://scripts/view/center_palette.gd")
const HousePalette = preload("res://scripts/view/house_palette.gd")
const FurniturePalette = preload("res://scripts/view/furniture_palette.gd")

func _house_mat(path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	if CenterPalette.applies(path.get_base_dir()) and path.get_file().begins_with("hd2d_table"):
		mat.albedo_texture = ImageTexture.create_from_image(CenterPalette.counter(mat.albedo_texture.get_image(), path.ends_with("_top.png")))
	if "hd2d_house" in path.get_file():
		var source := mat.albedo_texture.get_image()
		var surface := HousePalette.roof(source) if path.ends_with("_rooftop.png") else HousePalette.wall(source)
		mat.albedo_texture = ImageTexture.create_from_image(surface)
	if path.begins_with("res://assets/maps/oaks_lab/hd2d_") and ("table" in path or "wallobj" in path):
		var source := mat.albedo_texture.get_image()
		mat.albedo_texture = ImageTexture.create_from_image(FurniturePalette.surface(source, path.ends_with("_top.png")))
	mat.albedo_texture = MapPalette.texture(mat.albedo_texture)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _build_house(map_dir: String, hdef: Dictionary) -> void:
	var base := map_dir + "/" + String(hdef["tex"])
	var front_tex: Texture2D = load(base + "_front.png")
	var X := float(hdef["x"])
	var Zf := float(hdef["z"])
	var W := float(hdef["w"])
	var D := float(hdef["d"])
	_ground_anchor=Vector2(X+W*0.5,Zf)
	var hw := float(front_tex.get_height()) / 16.0 * k        # 벽 높이(도트 16px = 1m)
	var mesh := ArrayMesh.new()
	var faces := {
		"front": [[Vector3(X, 0, Zf), Vector3(X + W, 0, Zf), Vector3(X + W, hw, Zf), Vector3(X, hw, Zf)]],
		"back": [[Vector3(X + W, 0, Zf - D), Vector3(X, 0, Zf - D), Vector3(X, hw, Zf - D), Vector3(X + W, hw, Zf - D)]],
		"side": [[Vector3(X, 0, Zf - D), Vector3(X, 0, Zf), Vector3(X, hw, Zf), Vector3(X, hw, Zf - D)],
			[Vector3(X + W, 0, Zf), Vector3(X + W, 0, Zf - D), Vector3(X + W, hw, Zf - D), Vector3(X + W, hw, Zf)]],
	}
	for key in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for q in faces[key]:
			_poly(st, q, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _house_mat(base + "_" + key + ".png"))
	# 평평한 지붕판(사용자 2026-11-02: 삼각으로 올리지 않고 평평하게): 벽보다 EAVE 내민 판, 두께 ROOF_T. 윗면은 원작 지붕 그림,
	# 처마 끝은 지붕 마감색의 3단계 도트 띠를 별도 재질로 사용한다.
	var top_y := hw + ROOF_T
	var x0 := X - EAVE
	var x1 := X + W + EAVE
	var zf := Zf + EAVE
	var zb := Zf - D - EAVE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_poly(st, [Vector3(x0, top_y, zf), Vector3(x1, top_y, zf), Vector3(x1, top_y, zb), Vector3(x0, top_y, zb)],
		[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])                                       # 윗면
	st.commit(mesh)
	var roof_mat := _house_mat(base + "_rooftop.png")
	roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh.surface_set_material(mesh.get_surface_count() - 1, roof_mat)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	_poly(st, [Vector3(x0, hw, zf), Vector3(x1, hw, zf), Vector3(x1, top_y, zf), Vector3(x0, top_y, zf)], edge)   # 앞 처마 끝
	_poly(st, [Vector3(x0, hw, zb), Vector3(x0, hw, zf), Vector3(x0, top_y, zf), Vector3(x0, top_y, zb)], edge)   # 왼쪽
	_poly(st, [Vector3(x1, hw, zf), Vector3(x1, hw, zb), Vector3(x1, top_y, zb), Vector3(x1, top_y, zf)], edge)   # 오른쪽
	_poly(st, [Vector3(x0, hw, zf), Vector3(x0, hw, zb), Vector3(x1, hw, zb), Vector3(x1, hw, zf)], edge)          # 처마 밑
	_poly(st, [Vector3(x1, hw, zb), Vector3(x0, hw, zb), Vector3(x0, top_y, zb), Vector3(x1, top_y, zb)], edge) # 뒤 처마
	st.commit(mesh)
	var edge_mat := _house_mat(base + "_rooftop.png")
	var original: Texture2D = load(base + "_rooftop.png")
	var eave := HousePalette.eave(original.get_image())
	edge_mat.albedo_texture = ImageTexture.create_from_image(MapPalette.surface(eave) if MapPalette.enabled else eave)
	mesh.surface_set_material(mesh.get_surface_count() - 1, edge_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_add_scenery(mi)
	_ground_anchor=Vector2.INF

# 볼록 다각형 하나(부채꼴 삼각형). 점은 바깥에서 볼 때 반시계로 주고, 법선은 앞의 세 점으로(바깥).
# 삼각형은 거꾸로(시계 방향) 넣는다 — Godot 는 시계 방향이 앞면이라, 반시계로 넣었더니 양면 재질이 뒷면으로 보고 법선을 뒤집어
# 집·가구·우체통의 모든 면이 해를 등졌다(사용자 2026-11-02: 그림자는 왼쪽 위로 지는데 정면이 햇볕을 받는 느낌이 없다 — 해를 아무리
# 세게 해도 정면만 그대로였다).
func _poly(st: SurfaceTool, v: Array, uv: Array) -> void:
	if _ground_static_geometry:
		var center: Vector3=(v[0]+v[1])*0.5
		var height := Arena.ground_height((_ground_anchor if _ground_anchor!=Vector2.INF else Vector2(center.x,center.z))*Arena.TILE)
		v=v.duplicate()
		for i in v.size():v[i]+=Vector3.UP*height
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	var nrm: Vector3 = (b - a).cross(c - a).normalized()
	st.set_normal(nrm)
	for i in range(1, v.size() - 1):
		for idx in [0, i + 1, i]:
			st.set_uv(uv[idx])
			st.add_vertex(v[idx])

# 사각형 하나: 밑변 시작점 o, 가로 ex, 세로 ey(밑 → 위), uv 는 위쪽이 v_top.
func _quad(st: SurfaceTool, o: Vector3, ex: Vector3, ey: Vector3, normal: Vector3, u0: float, u1: float, v_top: float, v_bot: float) -> void:
	if _ground_static_geometry:
		o.y+=Arena.ground_height((_ground_anchor if _ground_anchor!=Vector2.INF else Vector2(o.x+ex.x*0.5,o.z+ex.z*0.5))*Arena.TILE)
	var bl := o
	var br := o + ex
	var tr := o + ex + ey
	var tl := o + ey
	st.set_normal(normal)
	for vtx in [[tl, Vector2(u0, v_top)], [tr, Vector2(u1, v_top)], [br, Vector2(u1, v_bot)], [tl, Vector2(u0, v_top)], [br, Vector2(u1, v_bot)], [bl, Vector2(u0, v_bot)]]:
		st.set_uv(vtx[1])
		st.add_vertex(vtx[0])

# 해(서쪽 낮은 데서 — 그림자가 물체 오른쪽 뒤로 비스듬히 길게 떨어져 포켓몬 그림자도 몸 옆으로 보인다) + 하늘빛.
# 처음엔 거의 뒤(남쪽 높이)에서 비춰 포켓몬 그림자가 몸 뒤에 숨어 납작해 보였다(2026-11-02).
# 밝기 맞춤(계측 2026-11-02, 바닥을 unshaded 로 그린 색과 비교): 하늘빛 1.0 이면 원래 지도 색과 같고, 해는 같은 수치에 훨씬 세게 들어간다.
# 해 0.11 + 하늘빛 0.42 ≈ 원래 색(양지), 그늘 ≈ 원래 색의 60%. 처음 값(해 0.6·하늘빛 0.62)은 바닥이 하얗게 날아갔다.
const SUN_ENERGY := 0.13
const SKY_ENERGY := 0.42

# 장소별 빛(사용자 요청 2026-11-02: 건물 안도 HD-2D): 바깥 낮 / 건물 안(위에서 내리는 실내광, 그림자 옅게) / 숲(나뭇잎 그늘, 초록빛).
# 각 값은 [해 방향, 해 세기, 해 색, 그림자 짙기, 하늘빛 색, 하늘빛 세기, 바탕색].
const SKY := {
	# 낮 해(사용자 2026-11-02: 그림자는 왼쪽 위로 지는데 정면은 햇볕을 받는 느낌이 없다): 처음엔 동남동 낮은 데서(-38°, 62°) 옆으로 비춰
	# 정면 벽이 해를 0.37 밖에 못 받고(바닥 0.62) 밝은 바닥 옆에서 칙칙했다. 남동(45°)·조금 낮게(-32°)로 돌려 정면 0.6 · 바닥 0.53 —
	# 그림자는 그대로 왼쪽 위로, 바닥 밝기는 해 세기를 0.13 으로 올려 맞춘다.
	"day": [Vector3(-32.0, 45.0, 0.0), SUN_ENERGY, Color(1.0, 0.96, 0.88), 0.75, Color(0.96, 0.98, 1.0), SKY_ENERGY, Color(0.55, 0.75, 0.95)],
	"indoor": [Vector3(-72.0, 25.0, 0.0), 0.045, Color(1.0, 0.98, 0.95), 0.28, Color(1.0, 0.99, 0.98), 0.56, Color(0.02, 0.02, 0.03)],
	"forest": [Vector3(-55.0, 40.0, 0.0), 0.09, Color(1.0, 0.95, 0.8), 0.8, Color(0.78, 0.92, 0.82), 0.33, Color(0.1, 0.2, 0.12)],
}

static func sky_kind(location: String) -> String:
	if DungeonDB.is_indoor(location) or DungeonDB.DUNGEONS.get(location,{}).get("battle_style","")=="room":
		return "indoor"
	if String(DungeonDB.DUNGEONS.get(location, {}).get("theme", "")) == "forest" or location.begins_with("arena_viridian_forest") or location=="arena_forest_rescue":
		return "forest"
	return "day"

static func local_light_gain() -> float:
	return 0.35 if sky_kind(DungeonDB.current) == "indoor" else 1.0

func _build_sky() -> void:
	var sk: Array = SKY[sky_kind(DungeonDB.current)]
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = sk[0]
	sun.light_energy = sk[1]
	if OS.get_environment("V3D_SUN") != "":                # 맞춤용(캡처 도구): 해·하늘빛 세기
		sun.light_energy = float(OS.get_environment("V3D_SUN"))
	sun.light_color = sk[2]
	sun.shadow_enabled = true
	sun.shadow_opacity = sk[3]
	sun.directional_shadow_max_distance = 45.0
	root3d.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sk[6]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = sk[4]
	env.ambient_light_energy = sk[5]
	if OS.get_environment("V3D_SKY") != "":
		env.ambient_light_energy = float(OS.get_environment("V3D_SKY"))
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)

static func to3d(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x / Arena.TILE, y+Arena.ground_height(p), p.y / Arena.TILE)

# 마우스가 가리키는 바닥 자리(2D 좌표) — 조준이 3D 화면에서도 맞게(Controllers.Human).
func mouse_world() -> Vector2:
	if not visible or cam == null:
		return world.get_global_mouse_position()
	var uv := rect.get_local_mouse_position() / rect.size
	var sp := uv * Vector2(vp.size)
	return ground_at_screen(sp)

func ground_at_screen(screen: Vector2) -> Vector2:
	# Use the actual shifted projection; Camera3D ray helpers can omit its lens offset.
	var uv := screen/Vector2(vp.size)
	var inverse := cam.get_camera_projection().inverse()
	var a: Vector4=inverse*Vector4(uv.x*2.0-1.0,1.0-uv.y*2.0,0.0,1.0)
	var b: Vector4=inverse*Vector4(uv.x*2.0-1.0,1.0-uv.y*2.0,0.5,1.0)
	var origin := cam.global_transform*(Vector3(a.x,a.y,a.z)/a.w)
	var point := cam.global_transform*(Vector3(b.x,b.y,b.z)/b.w)
	var ray := point-origin
	if absf(ray.y)<0.000001: return Vector2(origin.x,origin.z)*Arena.TILE
	if not Arena._elevation.is_empty():
		var near_t := maxf(0.0,(Arena.max_elevation+0.1-origin.y)/ray.y)
		var far_t := maxf(near_t,-origin.y/ray.y)
		var previous := near_t
		for i in range(1,129):
			var t := lerpf(near_t,far_t,float(i)/128.0)
			var sample := origin+ray*t
			if sample.y<=Arena.ground_height(Vector2(sample.x,sample.z)*Arena.TILE):
				var lo := previous
				var hi := t
				for iteration in 14:
					var mid := (lo+hi)*0.5
					var at := origin+ray*mid
					if at.y>Arena.ground_height(Vector2(at.x,at.z)*Arena.TILE):lo=mid
					else:hi=mid
				var at := origin+ray*((lo+hi)*0.5)
				return Vector2(at.x,at.z)*Arena.TILE
			previous=t
	var hit := origin+ray*(-origin.y/ray.y)
	return Vector2(hit.x,hit.z)*Arena.TILE

func _process(dt: float) -> void:
	if world == null or not is_instance_valid(world) or not visible:
		return
	if kanto_terrain != null: kanto_terrain.stream(world.player.position / Arena.TILE)
	if native_renderer != null: native_renderer.stream(world.player.position/Arena.TILE)
	if continent_backdrop != null:continent_backdrop.stream(world.player.position/Arena.TILE)
	_follow_camera(dt)
	var game=world.get_parent()
	_texts.clear()
	var seen := {}
	_sync_starter_balls(seen)
	_sync_ground_items(seen)
	_sync_loot_items(seen)
	var ride=world.player.get_meta("lapras_ride") if world.player.has_meta("lapras_ride") else null
	if ride!=null:ride.sync_carrier_3d(self,seen)
	_sync_mon(world.player, seen)
	for e in world.enemies:
		_sync_mon(e, seen)
	for mon in world.bystanders:
		if not mon.get_meta("lapras_carrier",false):_sync_mon(mon, seen)
	if game!=null and game.get("pikachu_rescue")!=null:game.pikachu_rescue.update_light()
	for n in world.npcs:
		_sync_npc(n, seen)
	_sync_thrown_balls(seen)
	var smoke := _batchable_smoke()
	for f in world.fxs:
		if not smoke.is_empty() and _is_batch_smoke(f): continue
		_sync_fx(f, seen)
	_sync_smoke_batch(smoke)
	for p in world.projectiles:
		_sync_projectile(p, seen)
	for z in world.zones:
		if z is World.FireField and not z.dead: ContactMoveArt.spin(self,z,_entry(z,seen))
	for id in _sprites.keys():
		if not seen.has(id):
			for node in (_sprites[id] as Dictionary).values():
				if is_instance_valid(node):
					node.queue_free()
			_sprites.erase(id)
	_sync_sound_refraction()
	if game.has_method("_update_combat_focus"): game._update_combat_focus()
	_step_overlay()
	_text_node.queue_redraw()

# Conservative wall margin; viewport distortion has no per-pixel scene depth.
static func sound_refraction_clear(at: Vector2) -> bool:
	for y in [-1,0,1]:
		for x in [-1,0,1]:
			if Arena.blocks(at+Vector2(x,y)*Arena.TILE,0.0): return false
	return true

# Project the live bright fracture segments after camera movement; reset every frame.
func _sync_sound_refraction() -> void:
	var points := PackedVector4Array()
	for f in world.fxs:
		if not f.sound_fracture or f.color.r < 0.5 or f.dead or f.age <= f.delay: continue
		if not sound_refraction_clear(f.position): continue
		var t := _fx_t(f)
		if t >= 1.0: continue
		var at := to3d(f.position+Vector2(0,8.0),8.0/Arena.TILE*k)
		if cam.is_position_behind(at): continue
		var uv := cam.unproject_position(at)/Vector2(vp.size)
		if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0: continue
		var strength: float = f.color.a*minf(t/0.08,1.0)*minf((1.0-t)/0.6,1.0)
		points.append(Vector4(uv.x,uv.y,strength,t))
		if points.size()==15: break
	var count := points.size()
	points.resize(15)
	var material := rect.material as ShaderMaterial
	material.set_shader_parameter("fracture_count",count)
	material.set_shader_parameter("fractures",points)
	material.set_shader_parameter("viewport_pixels",Vector2(vp.size))

# 따라갈 자리는 cam_anchor(달려드는 동안 앞으로 나간 몸, 사용자 지적 2026-11-02: 공격할 때 카메라가 부자연스럽다) — 처음엔 position 을
# 따라가 동작이 끝나 자리가 한 번에 옮겨지는 순간 목표가 튀어, 파이리가 멈춘 뒤에도 화면이 혼자 미끄러졌다.
# Reserve headroom for the entire idle/walk/hop cycle, not the current frame:
# otherwise the camera bobs on every jump. Alpha bounds exclude transparent sheet padding.
var _body_headroom := {}
func _indoor_headroom(p: Mon) -> float:
	if not DungeonDB.is_indoor(DungeonDB.current):
		return 0.0
	var key := str(p._sprites.get("Walk", {}).get("tex", ""))
	if not _body_headroom.has(key):
		var height_px := 0.0
		for name in ["Idle", "Walk", "Hop"]:
			if not p._sprites.has(name):
				continue
			var anim: Dictionary = p._sprites[name]
			var img: Image = anim["tex"].get_image()
			var top := int(anim["fh"])
			for y in img.get_height():
				if y % int(anim["fh"]) >= top:
					continue
				for x in img.get_width():
					if img.get_pixel(x,y).a > 0.5:
						top = y % int(anim["fh"])
						break
			var feet := float(p._sprites.get("feet_dy",0.0))-1.0
			height_px = maxf(height_px, MonSprite.anchor_of(p._sprites,anim).y + feet - top)
		_body_headroom[key] = height_px
	var height := float(_body_headroom[key]) * p.sprite_scale * bill / Arena.TILE
	return maxf(0.0, height - 3.0) * 0.65

# Every arena style shares the same camera choreography.
static func arena_camera_angles(phase: String, progress: float = 0.0) -> Vector2:
	var blend := smoothstep(0.0,1.0,clampf(progress,0.0,1.0)) if phase=="back" else (1.0 if phase=="fight" else 0.0)
	return Vector2(lerpf(ARENA_INTRO_ELEV,elev_deg,blend),ARENA_YAW)

# Level lens, with a physical camera offset to the right. No camera roll.
static func arena_camera_basis(pitch: float) -> Basis:
	var e := deg_to_rad(pitch)
	return Basis(Vector3.RIGHT,Vector3(0,cos(e),-sin(e)),Vector3(0,sin(e),cos(e)))

# Fit feet and headroom inside the usable HUD area with true perspective depth.
static func arena_fight_distance(delta: Vector2, aspect: float) -> float:
	var basis := arena_camera_basis(elev_deg)
	var half := Vector3(delta.x/Arena.TILE,0,delta.y/Arena.TILE)*0.5
	var tangent := tan(deg_to_rad(FOV)*0.5)
	var lateral_ratio := cos(deg_to_rad(elev_deg))*tan(deg_to_rad(ARENA_YAW))
	var distance := 5.8/(2.0*tangent)
	for ground in [-half,half]:
		for height in [0.0,1.8]:
			var relative: Vector3=ground+Vector3.UP*(height-0.65)
			var depth := relative.dot(basis.z)
			var vertical := relative.dot(basis.y)
			distance=maxf(distance,(vertical+0.90*tangent*depth)/(0.56*tangent))
			distance=maxf(distance,(0.28*tangent*depth-vertical)/(0.62*tangent))
			distance=maxf(distance,depth+absf(relative.x-lateral_ratio*depth)/(tangent*maxf(aspect,0.5)*0.80))
	return distance

func _set_arena_camera(target: Vector3, angles: Vector2, distance: float) -> void:
	var basis := arena_camera_basis(angles.x)
	var lateral := distance*cos(deg_to_rad(angles.x))*tan(deg_to_rad(angles.y))
	cam.position=target+basis.z*distance+Vector3.RIGHT*lateral
	cam.basis=basis
	# Shift the lens to centre the action without aiming diagonally or rolling it.
	cam.set_frustum(2.0*cam.near*tan(deg_to_rad(FOV)*0.5),Vector2(-lateral*cam.near/distance,0),cam.near,cam.far)

func screen_move_world(direction: Vector2) -> Vector2:
	if not visible or cam==null or direction==Vector2.ZERO: return direction
	if is_instance_valid(world) and is_instance_valid(world.player):
		var at := world.player.cam_anchor()
		var screen := cam.unproject_position(to3d(at))+direction*32.0
		return (ground_at_screen(screen)-at).normalized()*direction.length()
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var ground_to_screen := Transform2D(Vector2(right.x,-up.x),Vector2(right.z,-up.z),Vector2.ZERO)
	return ground_to_screen.affine_inverse().basis_xform(direction).normalized()*direction.length()

func _follow_camera(dt: float = 1.0/60.0) -> void:
	var p := world.player
	var target := to3d(p.cam_anchor(), _indoor_headroom(p))
	if p.dash.has("ground_from"):
		var hop_progress := clampf(1.0-float(p.dash.get("left",0.0))/float(p.dash.ground_length),0.0,1.0)
		target.y+=lerpf(float(p.dash.ground_from),float(p.dash.ground_to),hop_progress)-Arena.ground_height(p.cam_anchor())
	var game = world.get_parent()
	if game!=null and game.get("seafoam")!=null and game.get("state")=="seafoam_event":
		target=to3d(game.seafoam.focus,0.7)
	# Let the friendly bird sweep across the screen. Following the passenger
	# here would turn a diagonal fly-by back into a stationary upward lift.
	if game!=null and game.get("bird_event")!=null and game.bird_event.camera_locked and _cam_ready:return
	if game!=null and game.get("bill_event")!=null and game.bill_event.phase!="idle":
		target=to3d(game.bill_event.focus,0.7)
	if game!=null and game.get("tower_brothers")!=null and game.tower_brothers.phase in ["intro","ready","cloning","aftermath","won"]:
		target=to3d(game.tower_brothers.focus,0.7)
	if game!=null and game.get("lapras_escape")!=null:
		if game.get("state")=="lapras_event":
			target=to3d(game.lapras_escape.focus,0.7)
	if game!=null and game.get("forest_rescue")!=null and not game.is_event_battle():
		if game.get("state")=="forest_event" or (game.get("state")=="talk" and game.forest_rescue.phase in ["discovered","ambush","release"]):
			target=to3d(game.forest_rescue.focus,0.7)
	if game!=null and game.get("state")=="field_cut" and game.get("field_friends")!=null and is_instance_valid(game.field_friends.helper):
		target=to3d(game.field_friends.focus,0.7)
	if game!=null and game.get("bird_event")!=null:
		if game.bird_event.nest_camera_active():
			target=to3d(game.bird_event.origin,0.6)
		elif not game.bird_event.landing_camera_active() and (game.get("state")=="bird_event" or (game.get("state")=="talk" and game.bird_event.phase=="caught") or (game.get("state")=="warp" and game.bird_event.phase=="transition")):
			target=to3d(game.bird_event.focus, maxf(0.7,p.lift/Arena.TILE*bill+0.5))
	var zoom := 1.0
	if game!=null and game.get("state")=="field_cut" and game.get("field_friends")!=null:
		zoom=game.field_friends.camera_zoom
	var angles := Vector2(elev_deg,0.0)
	var distance := DIST
	if game!=null and game.get("tower_brothers")!=null and game.tower_brothers.phase=="cloning":
		target=to3d(game.tower_brothers.focus,0.6)
		distance=lerpf(DIST,18.0,game.tower_brothers.camera_wide)
	if game!=null and DungeonDB.current=="arena_bird_nest":
		distance=25.5
		target=to3d(game.bird_event.nest_center()+Vector2(0,Arena.TILE),0.6)
	var arena_view: bool = game != null and game.get("mode")=="arena" and not game.is_event_battle()
	if arena_view:
		var phase := "fight"
		var progress := 0.0
		var focus := Vector3.ZERO
		var active_battle: Dictionary = game.battle
		var send: Dictionary = game.sendout
		if not active_battle.is_empty():
			var trainer: Npc = null
			if is_instance_valid(active_battle.get("trainer")): trainer=active_battle["trainer"]
			if is_instance_valid(trainer): focus=to3d(trainer.get_meta("formation_center",trainer.position),0.85)
			if int(active_battle.get("idx",0))==0: phase="intro"
		var enemy: Mon = null
		if is_instance_valid(active_battle.get("mon")): enemy=active_battle["mon"]
		var fight_target := to3d(p.cam_anchor(),0.65)
		if is_instance_valid(enemy):
			var player_feet := p.cam_anchor()+Vector2(0,p.feet_offset())
			var enemy_feet := enemy.cam_anchor()+Vector2(0,enemy.feet_offset())
			fight_target=(to3d(player_feet,0.65)+to3d(enemy_feet,0.65))*0.5
			distance=arena_fight_distance(enemy_feet-player_feet,float(vp.size.x)/maxf(1.0,vp.size.y))
		if not send.is_empty():
			phase=String(send.phase)
			var flight := clampf((float(send.t)-game.SEND_THROW_AT)/game.SEND_THROW,0.0,1.0)
			if bool(send.get("direct",false)):
				flight=clampf((float(send.t)-game.SEND_PAN)/maxf(0.01,float(send.ready_at)-game.SEND_PAN),0.0,1.0)
			focus=to3d(Vector2(send.trainer_at).lerp(Vector2(send.focus),smoothstep(0.0,1.0,flight)),0.85)
			if phase=="back": progress=clampf(float(send.t)/game.ARENA_SEND_BACK,0.0,1.0)
		angles=arena_camera_angles(phase,progress)
		if phase=="show" and int(active_battle.get("idx",0))>1:
			angles.x=lerpf(elev_deg,ARENA_INTRO_ELEV,smoothstep(0.0,1.0,clampf(float(send.t)/game.SEND_PAN,0.0,1.0)))
		var blend := smoothstep(0.0,1.0,progress) if phase=="back" else (1.0 if phase=="fight" else 0.0)
		target=focus.lerp(fight_target,blend)
		distance=lerpf(ARENA_INTRO_DIST,distance,blend)
		var up := arena_camera_basis(angles.x).y
		target-=up*distance*tan(deg_to_rad(FOV)*0.5)*0.34
	elif game != null and game.get("balls") != null and game.balls.intro:
		zoom = world.cam.zoom.x if world.cam != null else 1.0
		var ball_at := BallRelease.center_3d(self,StarterBalls.ball_of(game.starter),true)
		if not game.balls.taken:
			target = ball_at
		elif game.opening.get("phase","") == "wobble":
			var age := float(game.opening.t)-float(game._opening_open_at())
			target = ball_at.lerp(target,smoothstep(0.045,0.45,age))
	# At the low trainer close-up, off-screen tree silhouettes read as stray
	# wedges. Keep contact shadows and fade sun shadows in as the camera rises.
	if _sun != null:
		var shadow_gain := smoothstep(ARENA_INTRO_ELEV,elev_deg,angles.x) if arena_view else 1.0
		_sun.shadow_opacity = float(SKY[sky_kind(DungeonDB.current)][3])*shadow_gain
	bill=1.0/cos(deg_to_rad(angles.x))
	cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(FOV) * 0.5) / maxf(1.0, zoom)))
	var a := 1.0-exp(-FOLLOW*maxf(dt,0.0))
	_cam_target=target if not _cam_ready else _cam_target.lerp(target,a)
	_cam_distance=distance if not _cam_ready else lerpf(_cam_distance,distance,a)
	_cam_ready=true
	if arena_view:
		_set_arena_camera(_cam_target,angles,_cam_distance)
	else:
		var e := deg_to_rad(angles.x)
		cam.set_perspective(cam.fov,cam.near,cam.far)
		cam.position=_cam_target+Vector3(0,sin(e),cos(e))*_cam_distance
		cam.look_at(_cam_target,Vector3.UP)
	var impact := world.impact_camera_offset()/Arena.TILE
	cam.position+=cam.basis.x*impact.x-cam.basis.y*impact.y

# A thrown ball moves on the ground plane with a separate height arc.
# Align the sprite to the camera so rotation never stretches its round shape.
func _sync_thrown_balls(seen: Dictionary) -> void:
	for child in world.get_children():
		if not child is ThrownBall: continue
		var ball := child as ThrownBall
		var ent := _entry(ball,seen)
		if not ent.has("sprite"):
			var sprite := _new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
			sprite.texture = ball._tex
			sprite.region_rect = BallRelease.BALL_RECT
			sprite.pixel_size = BallRelease.PIXEL/Arena.TILE
			ent.sprite = sprite
			ent.shadow = _new_blob()
		var sprite: Sprite3D = ent.sprite
		var palm := to3d(ball.from,0.65)
		var body: Sprite3D = _sprites.get(ball.sender.get_instance_id(),{}).get("sprite")
		if body != null:
			palm = sprite_pixel_position(body,ball.sender.throw_hand(ball.k > 0.0))+cam.global_basis.z*0.04
		if ball.k > 0 and ball.release_3d == Vector3.INF: ball.release_3d = palm
		var origin := ball.release_3d if ball.k > 0 else palm
		var end := BallRelease.center_3d(self,ball.to,false)
		sprite.position = origin.lerp(end,ball.k)+Vector3.UP*(ball.height/Arena.TILE*4.0*ball.k*(1.0-ball.k))
		sprite.basis = cam.global_basis.orthonormalized()*Basis(Vector3.FORWARD,TAU*ball.k)
		sprite.visible = ball.visible
		BallRelease.draw_shadow(self,ent.shadow,sprite.position,1.0 if ball.visible and ball.k>0.0 else 0.0)

# Submit the first transparent effect and the starter's lighting pass while the
# opening monologue covers the lab. Compatibility compiles these on first draw.
func prepare_starter_reveal(player: Player) -> void:
	var at := to3d(player.position, _starter_table_height + 0.3)
	var glow := _new_unlit_sprite(BaseMaterial3D.BILLBOARD_DISABLED, SpriteBase3D.ALPHA_CUT_DISABLED)
	glow.position = at
	glow.texture = BallRelease.ATLAS
	glow.region_enabled = true
	glow.region_rect = BallRelease.frame(0.10)
	glow.pixel_size = 1.0 / Arena.TILE
	# Oak's exclamation uses an unlit cutout billboard, distinct from the glow.
	var emote := _new_unlit_sprite(BaseMaterial3D.BILLBOARD_FIXED_Y, SpriteBase3D.ALPHA_CUT_DISCARD)
	emote.texture = Fx.sheet("g4_shiny")
	emote.pixel_size = glow.pixel_size
	emote.reparent(glow, false)
	_opening_warm_glow = glow

# Keep the material variants alive between the monologue and their first live draw.
func hide_starter_preview() -> void:
	if _opening_warm_glow != null: _opening_warm_glow.hide()

func release_starter_preview() -> void:
	if _opening_warm_glow == null: return
	_opening_warm_glow.queue_free()
	_opening_warm_glow = null

# StarterBalls owns the opening state; mirror it above the authored tabletop.
func _sync_starter_balls(seen: Dictionary) -> void:
	for child in world.get_children():
		if not child is StarterBalls:
			continue
		var balls := child as StarterBalls
		var ent := _entry(balls, seen)
		for id in StarterBalls.TILES:
			if not ent.has(id):
				var sprite := _new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
				sprite.texture = balls._tex
				sprite.region_enabled = false
				sprite.pixel_size = BallRelease.PIXEL / Arena.TILE
				sprite.offset = Vector2(0, 7)
				ent[id] = sprite
			var s: Sprite3D = ent[id]
			var mine: bool = id == balls.starter
			s.visible = balls.visible and balls._tex != null and not (mine and (not balls.intro or balls.taken))
			s.position = to3d(StarterBalls.ball_of(id), _starter_table_height + 0.015)
			# Rotate in the camera plane: a rigid ball must not stretch as it tilts.
			s.basis = cam.global_basis.orthonormalized() * Basis(Vector3.FORWARD, balls.wobble if mine else 0.0)

# Ground-item balls stay circular in the camera plane while falling in world height.
func _sync_ground_items(seen: Dictionary) -> void:
	for child in world.get_children():
		if not child is GroundItem: continue
		var item := child as GroundItem
		var ent := _entry(item,seen)
		if not ent.has("sprite"):
			var sprite := _new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
			sprite.texture = item._tex
			sprite.region_enabled = false
			sprite.pixel_size = Arena.MAP_SCALE/Arena.TILE
			sprite.offset = Vector2(0,7)
			ent["sprite"] = sprite
			ent["blob"] = _new_blob()
		var sprite: Sprite3D = ent.sprite
		var height := GroundItem.drop_height(item.drop_age)
		sprite.visible = item.visible and item._tex != null
		sprite.position = to3d(item.position,height/Arena.TILE*k+0.015)
		sprite.basis = cam.global_basis.orthonormalized()
		var blob: MeshInstance3D = ent.blob
		blob.visible = sprite.visible
		blob.position = to3d(item.position,0.02)
		var shadow := contact_shadow(height,true)
		blob.scale = Vector3(0.45*shadow.x,1,0.28*shadow.x)
		(blob.material_override as StandardMaterial3D).albedo_color = Color(0,0,0,shadow.y)

func _opening_game():
	var game = world.get_parent()
	return game if game != null and game.get("opening") is Dictionary and not game.opening.is_empty() else null

# Blend the legacy 2D healing destination onto the actual 3D operating bed.
static func healing_bed_weight(time: float, hop: float, rest: float) -> float:
	return clampf(minf(time / hop, (hop * 2.0 + rest - time) / hop), 0.0, 1.0)

func _healing_offset(m: Mon) -> Vector3:
	var game = world.get_parent()
	if m != world.player or _healing_bed == Vector3.INF or game == null or game.get("heal") is not Dictionary or game.heal.is_empty():
		return Vector3.ZERO
	var weight := healing_bed_weight(float(game.heal.t), game.HEAL_HOP, game.heal_sleep)
	var old_feet: Vector2 = game.heal.spot + Vector2(0, m.feet_offset())
	return (_healing_bed - to3d(old_feet)) * weight

func _entry(node: Object, seen: Dictionary) -> Dictionary:
	var id := node.get_instance_id()
	seen[id] = true
	if not _sprites.has(id):
		_sprites[id] = {}
	return _sprites[id]

func _new_sprite(billboard: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.billboard = billboard
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	s.region_enabled = true
	s.layers = SPRITE_LAYER
	root3d.add_child(s)
	return s

func _new_unlit_sprite(billboard: int, alpha_cut: SpriteBase3D.AlphaCutMode) -> Sprite3D:
	var sprite := _new_sprite(billboard)
	sprite.shaded = false
	sprite.region_enabled = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.alpha_cut = alpha_cut
	return sprite

# 빛무리: 카메라를 보는 작은 판에 둥근 빛을 가산 합성으로.
var _halo_mesh: QuadMesh = null
const TAIL_HALO_SIZE := 0.17
const TAIL_HALO_COLOR := Color(1.0, 0.48, 0.12, 0.28)

static func tail_light_range(height: float, indoor: bool) -> float:
	return minf(0.7 if indoor else 1.0, maxf(0.01, height * 0.85))

func sprite_pixel_position(sprite: Sprite3D, pixel: Vector2) -> Vector3:
	var vertical := cam.global_basis.y if sprite.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var offset := Vector2(pixel.x-sprite.region_rect.size.x*0.5+sprite.offset.x,sprite.region_rect.size.y*0.5-pixel.y+sprite.offset.y)
	return sprite.position+cam.global_basis.x*offset.x*sprite.pixel_size*sprite.scale.x+vertical*offset.y*sprite.pixel_size*sprite.scale.y

func _new_halo(color: Color, size: float) -> MeshInstance3D:
	if _halo_mesh == null:
		_halo_mesh = QuadMesh.new()
		_halo_mesh.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = Fx.sheet("g4_glow")
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.no_depth_test = false
	var h := MeshInstance3D.new()
	h.mesh = _halo_mesh
	h.material_override = mat
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.scale = Vector3(size, size, size)
	root3d.add_child(h)
	return h

func _new_blob() -> MeshInstance3D:
	var b := MeshInstance3D.new()
	b.mesh = _blob_mesh
	b.material_override = _blob_mat.duplicate()
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root3d.add_child(b)
	return b

# 높이(px)에 따른 접지 그림자. 최대 높이에서도 착지 위치가 보이도록 남긴다.
static func contact_shadow(height: float, indoor: bool = false) -> Vector2:
	var t := clampf(height / Arena.TILE, 0.0, 1.0)
	return Vector2(lerpf(1.0, 0.55, t), lerpf(0.24, 0.08, t) if indoor else lerpf(0.35, 0.12, t))

static func shadow_height(m: Mon) -> float:
	return m.visual_shadow_height()

# 포켓몬: 2D 그리기가 방금 정한 프레임(StatOverlay 에 남겨 둔 텍스처·영역·변환)을 그대로 세운다.
func _sync_mon(m: Mon, seen: Dictionary) -> void:
	if m == null or not is_instance_valid(m) or m.stat_overlay == null or m.stat_overlay.tex == null:
		return
	var ent := _entry(m, seen)
	if not ent.has("sprite"):
		ent["sprite"] = _new_sprite(BaseMaterial3D.BILLBOARD_FIXED_Y)
		ent["blob"] = _new_blob()
	var s: Sprite3D = ent["sprite"]
	var b: MeshInstance3D = ent["blob"]
	if ent.has("front"):ent.front.visible=false
	var so := m.stat_overlay
	var hidden := not m.visible or m.visual_appear() <= 0.0 or not m.burrow.is_empty() or (m.dead and m.faint_t <= 0.0)
	s.visible = not hidden
	b.visible = not hidden
	if hidden:
		for key in ["light", "halo", "rank_overlay", "flash_lamp", "native_cue","release_mask"]:
			if ent.has(key):
				ent[key].visible = false
		if ent.has("twin"):
			(ent["twin"] as Sprite3D).visible = false
		return
	var xf: Transform2D = so.xform
	var sx := xf.get_scale().x
	var sy := xf.get_scale().y
	var shaded := Look.selout_frame(so.tex, so.src, sky_kind(DungeonDB.current))
	s.texture = shaded.tex
	s.region_rect = shaded.src
	s.pixel_size = sx / Arena.TILE
	# 2D 는 몸 중심을 발 기준점(ground)에 맞춰 그림의 아래 절반이 그 아래로 내려온다 — 3D 에선 그 절반이 바닥 판 밑으로 묻혀
	# 작아 보였다(캡처 확인 2026-11-02). 발끝(그림자 자리, feet_dy)을 바닥(y=0)에 맞춘다.
	var c: Vector2 = so.dst.get_center()
	var feet_px := float(m._sprites.get("feet_dy", 0.0)) - 1.0       # ground 에서 발끝까지(원본 px)
	s.offset = Vector2(c.x, -(c.y - feet_px))
	# Native HGSS tiles anchor actors at their collision/feet position. The
	# baked FRLG art uses the original 2D body's extra forward feet offset.
	var native_feet:=Arena.native_at(Arena.tile_of(m.position))
	var feet := m.position + Vector2(xf.origin.x, (0.0 if native_feet else m.feet_offset())+m.hit_feedback_offset().y)
	s.position = to3d(feet, maxf(0.0, m.lift) / Arena.TILE * bill)
	if m.dash.has("ground_from"):
		var progress := clampf(1.0-float(m.dash.get("left",0.0))/float(m.dash.ground_length),0.0,1.0)
		s.position.y+=lerpf(float(m.dash.ground_from),float(m.dash.ground_to),progress)-Arena.ground_height(feet)    # 점프(Hop) 높이는 3D 높이로
	var healing_offset := _healing_offset(m)
	if m.travel_terrain>0 and Arena.is_water(Arena.tile_of(m.position)):
		s.position.y += 0.025+sin(Time.get_ticks_msec()*0.004+float(m.get_instance_id()%11))*0.025
	s.position += healing_offset
	var opening_game = _opening_game()
	if m.preview_reveal:
		s.position.y += _starter_table_height
	elif m == world.player and opening_game != null and opening_game.opening.get("phase", "") == "wobble":
		var start := StarterBalls.ball_of(opening_game.starter)
		var end := StarterBalls.floor_of(opening_game.starter)
		var progress := clampf((m.position.y - start.y) / (end.y - start.y), 0.0, 1.0)
		s.position.y += _starter_table_height * (1.0 - progress)
	# Keep the rescue cast legible across the wide stage, including its corners.
	var game = world.get_parent()
	var event_arena: bool = game!=null and game.has_method("is_event_battle") and game.is_event_battle()
	var screen_facing: bool = cam.projection==Camera3D.PROJECTION_FRUSTUM or m.get_meta("screen_facing",false) or m.has_meta("lapras_ride") or event_arena
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED if screen_facing else BaseMaterial3D.BILLBOARD_FIXED_Y
	var actor_bill := 1.0 if screen_facing else bill
	s.scale = Vector3(1.0, actor_bill * sy / maxf(0.001, sx), 1.0)
	# The shared walk anchor comes from the first south-facing frame. Indoor
	# billboards sit at their true depth, so longer back-facing feet can cross
	# the floor. Correct only the part of the current pose that penetrates it.
	if DungeonDB.is_indoor() and m.burrow.is_empty() and not m.dead:
		var bottom := MonSprite.visual_bottom({"tex":so.tex, "src":so.src}) + 1.0
		var lowest_y := sprite_pixel_position(s, Vector2(0, bottom)).y
		s.position.y += maxf(0.0, Arena.ground_height(feet) + CONTACT_SHADOW_HEIGHT + 0.001 - lowest_y)

	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if m.dead or m.modulate.a<0.999 else SpriteBase3D.ALPHA_CUT_DISCARD
	s.modulate = Color(1,1,1,m.faint_alpha()*m.modulate.a)
	var smoke_shade: float = world.smoke_body_shade(m.position)
	var hit_tint := Color(4,4,4,1) if m.appear < 1.0 else m.hit_feedback_tint()
	s.modulate = Color(hit_tint.r*(1.0-smoke_shade),hit_tint.g*(1.0-smoke_shade),hit_tint.b*(1.0-smoke_shade*0.88),s.modulate.a)
	var releasing := is_instance_valid(m.release_fx)
	if releasing:
		s.modulate = Color.WHITE
		BallRelease.align_body(self,m.release_fx,s)
	_lift_to_camera(ent, s)
	var strength := BallRelease.strength(m.release_fx.age) if releasing else 0.0
	if strength > 0.0:
		if not ent.has("release_mask"):
			ent.release_mask = _new_unlit_sprite(s.billboard,SpriteBase3D.ALPHA_CUT_DISABLED)
		var overlay: Sprite3D = ent.release_mask
		overlay.texture = BallRelease.mask(s.texture,Rect2i(s.region_rect))
		overlay.pixel_size = s.pixel_size
		overlay.offset = s.offset
		overlay.scale = s.scale
		overlay.billboard = s.billboard
		overlay.position = s.position+cam.global_basis.z*0.008
		overlay.modulate = Color(BallRelease.CREAM,strength)
		overlay.visible = true
	elif ent.has("release_mask"):
		ent.release_mask.hide()
	if m == world.player:
		var indoor_outline := DungeonDB.current in ["pewter_museum_1f", "pokemon_mansion_1f"]
		if native_feet or indoor_outline:
			_sync_native_player_cue(ent,s,indoor_outline)
		elif ent.has("native_cue"):
			ent.native_cue.hide()
	(ent["twin"] as Sprite3D).visible = s.visible and not m.dead
	if m.has_meta("lapras_ride"):m.get_meta("lapras_ride").place_rider_3d(self,ent,s)
	_sync_rank_overlay(m, ent, s)
	var r := m.radius * 1.9 / Arena.TILE
	var shadow := contact_shadow(shadow_height(m), sky_kind(DungeonDB.current) == "indoor")
	b.position = to3d(m.cam_anchor() + Vector2(0, 0.0 if native_feet else m.feet_offset()), CONTACT_SHADOW_HEIGHT) + healing_offset
	b.scale = Vector3(r * shadow.x, 1.0, r * 0.6 * shadow.x)
	(b.material_override as StandardMaterial3D).albedo_color = Color(0, 0, 0, shadow.y*m.faint_alpha()*m.modulate.a)
	if m.travel_terrain>0 and Arena.is_water(Arena.tile_of(m.position)):
		(b.material_override as StandardMaterial3D).albedo_color=Color(0.55,0.85,0.95,0.45*m.faint_alpha())
	if m.has_meta("lapras_ride"):b.visible=false
	if m.get_meta("flash_helper",false):
		if not ent.has("flash_lamp"):
			var lamp:=OmniLight3D.new()
			lamp.light_color=Color("fff2be");lamp.light_energy=0.22;lamp.omni_range=6.5
			lamp.light_cull_mask=1
			root3d.add_child(lamp);ent["flash_lamp"]=lamp
		var lamp_up:=cam.global_basis.y if s.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
		ent.flash_lamp.position=s.position+cam.global_basis.x*s.offset.x*s.pixel_size*s.scale.x+lamp_up*s.offset.y*s.pixel_size*s.scale.y
		if game!=null and game.get("pikachu_rescue")!=null:ent.flash_lamp.light_energy=0.22*game.pikachu_rescue.brightness
		ent.flash_lamp.visible=s.visible
	elif ent.has("flash_lamp"):
		ent.flash_lamp.visible=false
	if not Look.TAIL_FLAME.has(m.appearance_id()):
		for key in ["light","halo"]:
			if ent.has(key): ent[key].visible = false
	# 꼬리불: 꼬리 끝(지금 프레임의 불꽃 픽셀 자리)에 작은 빛무리 + 좁은 점 조명(사용자 2026-11-02: 빛은 꼬리에만).
	if Look.TAIL_FLAME.has(m.appearance_id()):
		if not ent.has("light"):
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.62, 0.28)
			l.omni_range = 0.7 if sky_kind(DungeonDB.current) == "indoor" else 1.0
			l.light_cull_mask = 1
			l.shadow_enabled = true
			root3d.add_child(l)
			ent["light"] = l
			ent["halo"] = _new_halo(TAIL_HALO_COLOR, TAIL_HALO_SIZE)
		var lt: OmniLight3D = ent["light"]
		var halo: MeshInstance3D = ent["halo"]
		var flame := Look.flame_point(so.tex, so.src)
		var on := not m.dead and flame.x >= 0.0
		lt.visible = on
		halo.visible = on
		if on:
			# Flame coordinates are local to the source frame, as is the displayed region.
			var pixel := flame
			var at := sprite_pixel_position(s,pixel)
			ent["tail_pixel"]=pixel
			lt.position = at
			# Keep tail illumination above the floor, including low sideways walk frames.
			var local_height := maxf(0.01,at.y-s.position.y)
			lt.omni_range = tail_light_range(local_height, sky_kind(DungeonDB.current) == "indoor")
			lt.light_energy = (0.4 + 0.08 * sin(m.anim_t * 9.0)) * local_light_gain()
			# 빛무리는 도트 바로 뒤에 — 몸 픽셀이 가리고 꼬리 둘레로만 번진다(앞에 두면 뒷모습에서 몸을 덮었다).
			halo.position = at-(cam.global_position-at).normalized()*0.015
			(halo.material_override as StandardMaterial3D).billboard_mode=s.billboard
			var hs := TAIL_HALO_SIZE * (1.0 + 0.06 * sin(m.anim_t * 11.0))
			halo.scale = Vector3(hs, hs, hs)

# 후처리 초점: 실제 렌더링된 NPC의 중심과 반경을 뷰포트 UV로 돌려준다.
func mon_focus_bounds(m: Mon) -> Rect2:
	if not is_instance_valid(m) or not _sprites.has(m.get_instance_id()): return Rect2()
	var sprite: Sprite3D=_sprites[m.get_instance_id()].get("sprite")
	if sprite==null or not sprite.visible or sprite.modulate.a<=0.0: return Rect2()
	var vertical := cam.global_basis.y if sprite.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var center := sprite.position+cam.global_basis.x*sprite.offset.x*sprite.pixel_size*sprite.scale.x+vertical*sprite.offset.y*sprite.pixel_size*sprite.scale.y
	if cam.is_position_behind(center): return Rect2()
	var screen := cam.unproject_position(center)
	var top := cam.unproject_position(center+vertical*sprite.region_rect.size.y*sprite.pixel_size*sprite.scale.y*0.5)
	var right := cam.unproject_position(center+cam.global_basis.x*sprite.region_rect.size.x*sprite.pixel_size*sprite.scale.x*0.5)
	var radius := Vector2(maxf(8.0,absf(right.x-screen.x))+8.0,maxf(8.0,absf(top.y-screen.y))+8.0)
	return Rect2(screen/Vector2(vp.size),radius/Vector2(vp.size))

func npc_focus_bounds(n: Npc) -> Rect2:
	if not is_instance_valid(n) or not n.visible or not _sprites.has(n.get_instance_id()):
		return Rect2()
	var ent: Dictionary = _sprites[n.get_instance_id()]
	if not ent.has("sprite"):
		return Rect2()
	var sprite: Sprite3D = ent["sprite"]
	var height := n.frame_size.y * sprite.pixel_size * sprite.scale.y
	var center := sprite.position + Vector3.UP * height * 0.5
	if cam.is_position_behind(center):
		return Rect2()
	var screen := cam.unproject_position(center)
	var top := cam.unproject_position(center + Vector3.UP * height * 0.5)
	var right := cam.unproject_position(center + cam.global_basis.x * n.frame_size.x * sprite.pixel_size * sprite.scale.x * 0.5)
	var radius := Vector2(maxf(8.0, absf(right.x - screen.x)) + 8.0, maxf(12.0, absf(top.y - screen.y)) + 8.0)
	return Rect2(screen / Vector2(vp.size), radius / Vector2(vp.size))

func _sync_npc(n: Npc, seen: Dictionary) -> void:
	if n == null or not is_instance_valid(n) or n._tex == null:
		return
	var ent := _entry(n, seen)
	if not ent.has("sprite"):
		ent["sprite"] = _new_sprite(BaseMaterial3D.BILLBOARD_FIXED_Y)
		ent["blob"] = _new_blob()
	var s: Sprite3D = ent["sprite"]
	var b: MeshInstance3D = ent["blob"]
	var visual := n.visual_frame()
	var shaded := Look.selout_frame(visual.tex, visual.src, sky_kind(DungeonDB.current))
	s.texture = shaded.tex
	s.region_rect = shaded.src
	s.flip_h = n.face == "right"
	s.pixel_size = Arena.MAP_SCALE / Arena.TILE
	s.offset = Vector2(0, n.frame_size.y / 2.0)
	s.position = to3d(n.position + Vector2(0, Arena.TILE / 2.0 - 2.0 * Arena.MAP_SCALE))
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED if cam.projection==Camera3D.PROJECTION_FRUSTUM else BaseMaterial3D.BILLBOARD_FIXED_Y
	s.scale = Vector3(1.0, 1.0 if cam.projection==Camera3D.PROJECTION_FRUSTUM else bill, 1.0)
	s.visible = n.visible
	_lift_to_camera(ent, s)
	s.modulate=n.modulate
	s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED if n.modulate.a<0.999 else SpriteBase3D.ALPHA_CUT_DISCARD
	s.scale*=Vector3(n.scale.x,n.scale.y,1.0)
	b.position = to3d(n.position + Vector2(0, Arena.TILE / 2.0 - 3.0), 0.02)
	b.scale = Vector3(0.6, 1.0, 0.35)
	b.visible = n.visible
	_sync_npc_emote(n,ent,s)
	(b.material_override as StandardMaterial3D).albedo_color = Color(0,0,0,contact_shadow(0,sky_kind(DungeonDB.current) == "indoor").y)

# Match the 2D NPC's timed, rising exclamation bubble above the visible head.
func _sync_npc_emote(n: Npc, ent: Dictionary, body: Sprite3D) -> void:
	if n.emote_t<=0.0 or not n.visible or n._emote==null:
		if ent.has("emote"):ent.emote.visible=false
		return
	if not ent.has("emote"):
		ent.emote = _new_unlit_sprite(body.billboard, SpriteBase3D.ALPHA_CUT_DISCARD)
	var bubble: Sprite3D=ent.emote
	bubble.visible=true
	bubble.texture=n._emote
	bubble.pixel_size=body.pixel_size
	bubble.billboard=body.billboard
	bubble.position=body.position
	bubble.scale=body.scale
	var pop:=minf(1.0,(Npc.EMOTE_TIME-n.emote_t)/0.12)
	bubble.offset=Vector2(0,n.frame_size.y-n._head+16.0*pop-8.0-2.0/Arena.MAP_SCALE)

# Reuse the exact rank pattern/timer from 2D on an alpha-masked body quad.
func _sync_rank_overlay(m: Mon, ent: Dictionary, s: Sprite3D) -> void:
	var so := m.stat_overlay
	if m.dead or (not so.heal_active() and so.rank_strength() <= 0.0):
		if ent.has("rank_overlay"): ent["rank_overlay"].visible=false
		return
	if not ent.has("rank_overlay"):
		var overlay := MeshInstance3D.new()
		overlay.mesh=QuadMesh.new()
		var shader_material := ShaderMaterial.new()
		shader_material.shader=load("res://assets/shaders/stat_rank_3d.gdshader")
		overlay.material_override=shader_material
		overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlay.layers=SPRITE_LAYER
		root3d.add_child(overlay)
		ent["rank_overlay"]=overlay
	var overlay: MeshInstance3D = ent["rank_overlay"]
	overlay.visible=s.visible
	(overlay.mesh as QuadMesh).size=s.region_rect.size*s.pixel_size
	var right := Vector3(cam.global_basis.x.x,0,cam.global_basis.x.z).normalized()
	overlay.basis=Basis(right,Vector3.UP,right.cross(Vector3.UP)).scaled_local(s.scale)
	overlay.position=s.position+overlay.basis*Vector3(s.offset.x,s.offset.y,0)*s.pixel_size+(cam.global_position-s.position).normalized()*0.008
	var material := overlay.material_override as ShaderMaterial
	var tex_size := Vector2(so.tex.get_size())
	material.set_shader_parameter("sprite_tex",so.tex)
	material.set_shader_parameter("frame_uv",Vector4(so.src.position.x/tex_size.x,so.src.position.y/tex_size.y,so.src.size.x/tex_size.x,so.src.size.y/tex_size.y))
	material.set_shader_parameter("local_rect",Vector4(so.dst.position.x,so.dst.position.y,so.dst.size.x,so.dst.size.y))
	material.set_shader_parameter("pattern_tex",so.pattern)
	material.set_shader_parameter("period",32.0*so.pattern_scale)
	material.set_shader_parameter("scroll",(StatOverlay.TOTAL-so.t)*StatOverlay.SCROLL_SPEED*so.pattern_scale*(1.0 if so.up else -1.0))
	material.set_shader_parameter("heal", so.heal_active())
	material.set_shader_parameter("bands", so._heal_bands() if so.heal_active() else Vector4.ZERO)
	material.set_shader_parameter("heal_top", -so.body_r * 1.2)
	material.set_shader_parameter("heal_height", maxf(0.001, so.body_r * 2.4))
	material.set_shader_parameter("strength", (0.85 if so.heal_active() else so.rank_strength()) * s.modulate.a)

# Native terrain can hide the whole player behind a tall foreground ledge.
# Reuse the existing depth-masked cue: only occluded pixels become translucent.
func _sync_native_player_cue(ent: Dictionary, sprite: Sprite3D, outline: bool) -> void:
	if not ent.has("native_cue"):
		var mesh := MeshInstance3D.new()
		mesh.mesh=QuadMesh.new()
		var material := ShaderMaterial.new()
		material.shader=load("res://assets/shaders/occluded_player.gdshader")
		mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root3d.add_child(mesh)
		ent.native_cue=mesh
	var cue: MeshInstance3D=ent.native_cue
	(cue.mesh as QuadMesh).size=sprite.region_rect.size*sprite.pixel_size
	cue.position=sprite.position+cam.global_basis.x*sprite.offset.x*sprite.pixel_size*sprite.scale.x+Vector3.UP*sprite.offset.y*sprite.pixel_size*sprite.scale.y
	cue.rotation.y=cam.rotation.y
	cue.scale=sprite.scale
	cue.visible=sprite.visible and sprite.modulate.a>0.0
	var size := Vector2(sprite.texture.get_size())
	var region := sprite.region_rect
	var material := cue.material_override as ShaderMaterial
	material.set_shader_parameter("outline",outline)
	material.set_shader_parameter("sprite_tex",sprite.texture)
	material.set_shader_parameter("frame_uv",Vector4(region.position.x/size.x,region.position.y/size.y,region.size.x/size.x,region.size.y/size.y))

# 포켓몬·사람은 맵과 따로 그려지는 느낌으로(사용자 2026-11-02: 포켓몬이 잘려 보인다 — 포켓몬과 맵은 별도로 렌더링되는 느낌이어야
# 깨지지 않는다): 서 있는 판을 카메라 쪽으로 SPRITE_LIFT 만큼 당겨, 바로 옆 벽·가구·나무 판이 몸을 가르지 않게 한다. 화면 위 자리는
# 같고(카메라를 향한 선 위로만 옮김) 크기는 거리만큼 되돌린다. 정말 앞에 있는 건물·나무는 여전히 가린다(원작 2D 의 '위층'처럼).
# 그림자는 원래 자리의 그림자 전용 쌍둥이가 드리운다(당긴 판의 그림자는 어긋난다).
const SPRITE_LIFT := 0.6

func _lift_to_camera(ent: Dictionary, s: Sprite3D) -> void:
	var at := s.position
	var to_cam := cam.global_position - at
	var d := to_cam.length()
	if not ent.has("twin"):
		var tw := Sprite3D.new()
		tw.billboard = s.billboard
		tw.texture_filter = s.texture_filter
		tw.alpha_cut = s.alpha_cut
		tw.region_enabled = true
		tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		root3d.add_child(tw)
		ent["twin"] = tw
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t: Sprite3D = ent["twin"]
	t.billboard = s.billboard
	t.modulate = s.modulate
	t.alpha_cut = s.alpha_cut
	t.texture = s.texture
	t.region_rect = s.region_rect
	t.pixel_size = s.pixel_size
	t.offset = s.offset
	t.flip_h = s.flip_h
	t.scale = s.scale
	t.position = at
	t.visible = s.visible
	var lift := 0.0 if DungeonDB.is_indoor(DungeonDB.current) else SPRITE_LIFT
	if d > lift + 0.01:
		s.position = at + to_cam / d * lift
		s.scale = s.scale * ((d - lift) / d)

# 풀숲 흔들림(원작 필드 효과 tall_grass.png): 2D 는 바닥 오버레이에 그렸는데, 수풀이 기울인 판이 된 뒤로 그 밑에 깔려 안 보였다
# (사용자 2026-11-02: 수풀을 지나가거나 몹이 나올 때 풀이 흔들리는 연출이 적용되고 있나?). 수풀 판과 같은 기울기(FLORA_TILT)의
# 판으로 그 칸 위에 세우고, 포켓몬을 당긴 만큼(SPRITE_LIFT)보다 조금 더 카메라 쪽으로 — 풀이 몸 아랫도리를 덮는 원작 느낌.
const FLORA_TILT_DEG := 25.0
static var _grass_fx_tex: Texture2D = null
var _layered_grass_meshes := {}
var _layered_grass_material: StandardMaterial3D

func _sync_fx_grass(f: Fx, seen: Dictionary) -> void:
	var t: Vector2i = f.tile if f.kind == "tallgrass" else Arena.tile_of(f.position)
	if kanto_terrain != null and not kanto_terrain.shows_grass_at(t): return
	if _grass_fx_tex == null:
		_grass_fx_tex = Fx.grass_cutout_texture()
	if _grass_fx_tex == null:
		return
	var visual := f.grass_visual()
	# Rustling foliage uses separate source/subframe sheets from the static atlas.
	# Apply the same environment palette so stepping into grass cannot brighten it.
	visual.tex = MapPalette.texture(visual.tex)
	var ent := _entry(f, seen)
	var pilot := flora_pilot_tile(DungeonDB.theme().get("map",""), t)
	if ent.has("layered_grass"): ent.layered_grass.visible = pilot
	if ent.has("grass"): ent.grass.visible = not pilot
	if pilot:
		_sync_layered_grass(ent, t, visual)
		return
	if not ent.has("grass"):
		var sp := Sprite3D.new()
		sp.texture = _grass_fx_tex
		sp.region_enabled = true
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false
		sp.layers = SPRITE_LAYER
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root3d.add_child(sp)
		ent["grass"] = sp
	var sp: Sprite3D = ent["grass"]
	sp.texture = visual.tex
	sp.region_rect = visual.src
	sp.pixel_size = 1.0 / 16.0
	var ta := deg_to_rad(FLORA_TILT_DEG)
	var ea := deg_to_rad(elev_deg)
	var flen := sin(ea) / sin(ea + ta)
	var up := Vector3(0.0, sin(ta), -cos(ta))
	var nrm := Vector3(0.0, cos(ta), sin(ta))
	var ground := flora_ground_frame(t)
	sp.basis = ground.basis*Basis(Vector3(1, 0, 0), up * flen, nrm)
	var at := ground*(Vector3(0,0,0.5)+up*flen*0.5+nrm*0.02)
	var to_cam := cam.global_position - at
	var pull := minf(SPRITE_LIFT+0.08,to_cam.length()*0.5)
	sp.position = at + to_cam.normalized() * pull
	sp.basis *= (to_cam.length()-pull)/maxf(to_cam.length(),0.001)
	sp.visible = true

# Use the same split geometry as the pilot foliage for every rustle frame.
func _sync_layered_grass(ent: Dictionary, tile: Vector2i, visual: Dictionary) -> void:
	var frame := "%d:%s:%s" % [visual.tex.get_instance_id(), str(visual.src), str(tile)]
	if _layered_grass_material == null:
		_layered_grass_material = StandardMaterial3D.new()
		_layered_grass_material.albedo_texture = _grass_fx_tex
		_layered_grass_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_layered_grass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_layered_grass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_layered_grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not _layered_grass_meshes.has(frame):
		if _layered_grass_meshes.size()>=96:_layered_grass_meshes.erase(_layered_grass_meshes.keys()[0])
		var image: Image = visual.tex.get_image().get_region(Rect2i(visual.src))
		var material := _layered_grass_material.duplicate() as StandardMaterial3D
		material.albedo_texture = ImageTexture.create_from_image(image)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_build_layered_flora(st, -0.5, 0.5, 0.0, 1.0, 0.0, 1.0,tile)
		st.set_material(material)
		_layered_grass_meshes[frame] = st.commit()
	if not ent.has("layered_grass"):
		var mesh := MeshInstance3D.new()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = SPRITE_LAYER
		root3d.add_child(mesh)
		ent["layered_grass"] = mesh
	var node: MeshInstance3D = ent.layered_grass
	node.mesh = _layered_grass_meshes[frame]
	var ground := flora_ground_frame(tile)
	var at := ground.origin
	var toward := cam.global_position - at
	var distance := toward.length()
	var lift := minf(SPRITE_LIFT + 0.08, distance * 0.5)
	# Preserve the projected footprint while placing foreground leaves before feet.
	node.position = at + toward.normalized() * lift
	node.basis = ground.basis * ((distance - lift) / maxf(distance, 0.001))
	node.visible = true

# 공중 효과의 3D 자리: 2D 에서 '위로'(−y) 그린 것은 높이로 — 2D 자리를 lift px 만큼 아래로 내리고 그만큼 띄운다.
func _air(p: Vector2, lift: float) -> Vector3:
	return to3d(p + Vector2(0, lift), lift / Arena.TILE * bill)

# 효과: 바닥 표시는 오버레이가 그리고, 여기선 공중에 뜨는 것만.
const ClashArt = preload("res://scripts/view/clash_art.gd")

func _sync_fx(f: Fx, seen: Dictionary) -> void:
	if f == null or not is_instance_valid(f) or f.age < f.delay:
		return
	match f.kind:
		"ball_release":
			BallRelease.draw_3d(self,f,_entry(f,seen))
		"forward_cut", "clash_chip":
			if not f.dead: ClashArt.draw_3d(self,f,_entry(f,seen))
		"flare_coat":
			if is_instance_valid(f.follow): ContactMoveArt.coat(self,f,_entry(f,seen))
		"pickup_trail":
			_sync_fx_pickup_trail(f,seen)
		"wrap":
			_sync_fx_wrap(f, seen)
		"sprite":
			_sync_fx_sprite(f, seen)
		"text":
			_sync_fx_text(f, seen)
		"impact", "burst", "anim":
			_sync_fx_flash(f, seen)
		"tallgrass", "rustle":
			_sync_fx_grass(f, seen)
		"light":
			_sync_fx_light(f, seen)
		"fang", "fangfire", "fang_directional":
			_sync_fx_fang(f, seen)

const PICKUP_FILAMENT = preload("res://assets/shaders/pickup_trail.gdshader")
const PICKUP_STAR = preload("res://assets/shaders/pickup_trail_star.gdshader")
var _pickup_quad_mesh: QuadMesh

func _pickup_quad(ent: Dictionary, key: String, shader: Shader) -> MeshInstance3D:
	if not ent.has(key):
		if _pickup_quad_mesh==null:
			_pickup_quad_mesh=QuadMesh.new()
			_pickup_quad_mesh.size=Vector2.ONE
		var node := MeshInstance3D.new()
		node.mesh=_pickup_quad_mesh
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader=shader
		node.material_override=material
		root3d.add_child(node)
		ent[key]=node
	return ent[key]

func _pickup_point(point: Dictionary) -> Vector3:
	return to3d(point.at,float(point.height)/Arena.TILE*k+0.025)+cam.global_basis.z*0.008

func _sync_fx_pickup_trail(f: Fx, seen: Dictionary) -> void:
	if f.pickup_trail==null: return
	var ent := _entry(f,seen)
	for node in ent.values(): node.visible=false
	var trail := f.pickup_trail
	for i in maxi(0,trail.history.size()-1):
		var a := _pickup_point(trail.history[i])
		var b := _pickup_point(trail.history[i+1])
		var delta := b-a
		var length := delta.length()
		if length<0.005: continue
		var x := delta/length
		var z := cam.global_basis.z.normalized()
		var y := z.cross(x).normalized()
		var fade: float=pow(1.0-float(trail.history[i].age)/trail.LIFE,1.5)
		var segment := _pickup_quad(ent,"segment%d"%i,PICKUP_FILAMENT)
		segment.basis=Basis(x*(length+0.015),y*0.14,z)
		segment.position=(a+b)*0.5
		segment.visible=true
		(segment.material_override as ShaderMaterial).set_shader_parameter("strength",fade*0.75)
	for i in trail.motes.size():
		var mote: Dictionary=trail.motes[i]
		var pulse := trail.star_pulse(mote.age)
		var star := _pickup_quad(ent,"star%d"%i,PICKUP_STAR)
		var scale: float=mote.size*lerpf(0.4,1.0,pulse)
		star.basis=cam.global_basis*Basis.from_scale(Vector3.ONE*scale)
		star.position=_pickup_point(mote)+cam.global_basis.x*float(mote.side)*0.045+cam.global_basis.y*(0.035+float(mote.age)*0.08)
		star.visible=true
		(star.material_override as ShaderMaterial).set_shader_parameter("pulse",pulse)

# 송곳니·불길은 같은 카메라 평면에서 움직인다. 위아래 간격을 지도 깊이로 바꾸면
# 아랫니가 바닥에 묻히므로 Sprite3D.offset(텍스처 픽셀 단위)으로 원작 동작을 옮긴다.
func _fang_sprite(ent: Dictionary, key: String, tex: Texture2D) -> Sprite3D:
	if not ent.has(key):
		var s := _new_sprite(BaseMaterial3D.BILLBOARD_ENABLED)
		s.shaded = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s.region_enabled = false
		s.no_depth_test = false
		ent[key] = s
	var s: Sprite3D = ent[key]
	s.texture = tex
	s.visible = tex != null
	return s

func _sync_fx_wrap(f: Fx, seen: Dictionary) -> void:
	if not f.binding_live() or not _sprites.has(f.follow.get_instance_id()):return
	var ent := _entry(f,seen)
	if not ent.has("ribbon"):
		var ribbon := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.vertex_color_use_as_albedo=true
		material.albedo_texture=Fx.sheet("kanto_wrap_soft")
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		ribbon.material_override=material
		ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.layers=SPRITE_LAYER
		root3d.add_child(ribbon)
		ent.ribbon=ribbon
	var node: MeshInstance3D=ent.ribbon
	var body: Sprite3D=_sprites[f.follow.get_instance_id()].sprite
	var target: Mon=f.follow
	node.position=body.position+cam.global_basis.y*(maxf(10.0,target.radius*1.8)*0.5+1.0)/Arena.TILE
	node.basis=cam.global_basis.orthonormalized()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bands := f.binding_ribbon()
	for band in bands:
		var a: Vector3=band.a
		var b: Vector3=band.b
		var tangent := Vector2(b.x-a.x,b.y-a.y).normalized()
		var side := Vector3(-tangent.y,tangent.x,0)*float(band.width)*0.5
		var overlap := Vector3(tangent.x,tangent.y,0)*float(band.width)*0.25
		var corners := [a-side-overlap,a+side-overlap,b+side+overlap,b-side+overlap]
		var uv := [Vector2(0.4,0),Vector2(0.4,1),Vector2(0.6,1),Vector2(0.6,0)]
		for index in [0,1,2,0,2,3]:
			surface.set_color(band.color)
			surface.set_uv(uv[index])
			surface.add_vertex(Vector3(corners[index])/Arena.TILE)
	node.visible=not bands.is_empty()
	if node.visible:node.mesh=surface.commit()

func _sync_fx_fang(f: Fx, seen: Dictionary) -> void:
	var ent := _entry(f, seen)
	var t := _fx_t(f)
	var at := _air(f.position, 10.0)
	if f.kind == "fang_directional":
		var ratio := ClashArt.residual_scale(f)
		if ratio <= 0.0 or f.dead:
			for jaw in ent.values(): jaw.hide()
			return
		var atlas := Fx.sheet("fang_eight_hd2d")
		if atlas == null: return
		at = ClashArt.residual_center_3d(self, f, at, ratio)
		var cell := Vector2(atlas.get_width()/2.0, atlas.get_height()/8.0)
		var close := f.fang_close_progress()
		var gap := f.size * lerpf(0.22, 0.01, close*close)
		var sc := f.size / cell.x
		for jaw in 2:
			var sprite := _fang_sprite(ent, "jaw%d" % jaw, atlas)
			sprite.region_enabled = true
			sprite.region_rect = Rect2(Vector2(jaw*cell.x,f.fang_row*cell.y),cell)
			sprite.pixel_size = sc * ratio / Arena.TILE
			sprite.position = at
			sprite.scale = Vector3.ONE
			sprite.offset = Vector2(0, gap/sc*(1.0 if jaw==0 else -1.0))
			sprite.no_depth_test = false
			sprite.modulate = Color(1,1,1,minf(1.0,(1.0-t)*4.0))
			_lift_effect_to_camera(sprite)
		return
	if f.kind == "fang":
		var close := clampf(f.age / 0.12, 0.0, 1.0)
		var gap := lerpf(f.size * 1.1, f.size * 0.08, close * close)
		var sc := maxf(f.size / 40.0, 0.001)
		for key in ["fang_upper", "fang_lower"]:
			var s := _fang_sprite(ent, key, Fx.sheet(key))
			s.position = at
			s.pixel_size = sc / Arena.TILE
			s.offset = Vector2(0, gap / sc * (1.0 if key == "fang_upper" else -1.0))
			s.modulate = Color(1, 1, 1, 1.0 if t < 0.65 else (1.0 - t) / 0.35)
			s.scale = Vector3.ONE
			_lift_effect_to_camera(s)
	else:
		var flame := f.text == "flame"
		var tex := Fx.sheet("ff_flame" if flame else "ff_puff")
		var sc := maxf(f.size / 32.0 * (1.0 if flame else 0.5 + 0.9 * t), 0.001)
		var shift := Vector2(0, -f.size * 0.8 * t) if flame else f.dir * f.size * 0.5 * t
		for i in 2:
			var s := _fang_sprite(ent, "fire%d" % i, tex)
			s.position = at
			s.pixel_size = sc / Arena.TILE
			s.scale = Vector3(1.0 - t * 0.5 if flame else 1.0, 1.0, 1.0)
			s.offset = Vector2(shift.x / sc, -shift.y / sc + (8.0 if flame else 0.0))
			s.modulate = Color(1.0, 0.7, 0.3, 1.0 - t * t) if i == 0 else Color(1.0, 0.9 if flame else 0.85, 0.5 if flame else 0.4, (1.0 - t * t) * 0.8)
			s.render_priority = i
			_lift_effect_to_camera(s)

# 효과를 제한된 거리만 당겨 근접 겹침을 줄인다. 깊이 검사는 유지하므로 앞의 벽은 효과를 가린다.
# 원근 크기와 텍스처 간격을 함께 보정한다. 호출 전에 scale을 재설정해 축소 누적을 막는다.
func _lift_effect_to_camera(s: Sprite3D, lift: float = SPRITE_LIFT + 0.08) -> void:
	var to_cam := cam.global_position - s.position
	var distance := to_cam.length()
	if distance > lift + 0.01:
		s.position += to_cam / distance * lift
		s.scale *= (distance - lift) / distance

func _fx_t(f: Fx) -> float:
	return clampf((f.age - f.delay) / maxf(0.001, f.lifetime - f.delay), 0.0, 1.0)

# 피해 숫자·글자: 3D 자리를 화면 좌표로 바꿔 후처리(틸트시프트) 위 층에 2D 픽셀 글꼴로 — 3D 글자로 두면 화면 위쪽 흐림에
# 같이 뭉개졌다(캡처 확인 2026-11-02). 2D 화면의 떠오르는 글자와 똑같이 보인다.
var _texts: Array = []         # 이번 프레임에 그릴 [화면 자리, 글, 작은 글자, 색]
var text_layer: CanvasLayer
var _text_node: Node2D

func _sync_fx_text(f: Fx, seen: Dictionary) -> void:
	seen[f.get_instance_id()] = true
	var at3 := _air(f.position + Vector2(0, -12), 24.0)
	if cam.is_position_behind(at3):
		return
	var sp := cam.unproject_position(at3) * rect.size / Vector2(vp.size)
	var t := _fx_t(f)
	_texts.append([sp, f.text, f.font_size < 9, Color(f.color, 1.0 - t * t)])

func _draw_texts() -> void:
	for it in _texts:
		var c: Color = it[3]
		PixelUi.field_text(_text_node, it[0], it[1], it[2], c, Color(PixelUi.FIELD_OUTLINE, c.a), HORIZONTAL_ALIGNMENT_CENTER)

# 타격 별(impact)·섬광(burst)·프레임 애니(anim: 발톱·겁나는얼굴): 카메라를 보는 판.
func _sync_fx_flash(f: Fx, seen: Dictionary) -> void:
	var ent := _entry(f, seen)
	if not ent.has("sprite"):
		var s0 := _new_sprite(BaseMaterial3D.BILLBOARD_ENABLED)
		s0.shaded = false
		s0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s0.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s0.no_depth_test = false
		ent["sprite"] = s0
	var s: Sprite3D = ent["sprite"]
	var t := _fx_t(f)
	match f.kind:
		"impact":
			var tex := Fx.sheet("g4_spark")
			s.texture = tex
			s.region_enabled = false
			s.modulate = Color(f.color.r, f.color.g, f.color.b, 1.0 - t)
			if tex != null:
				s.pixel_size = f.size * (0.6 + 0.9 * t) * 2.0 / float(tex.get_width()) / Arena.TILE
		"burst":
			var tex := Fx.sheet("g4_glow")
			s.texture = tex
			s.region_enabled = false
			s.modulate = Color(f.color.r, f.color.g, f.color.b, 0.8 * (1.0 - t))
			if tex != null:
				s.pixel_size = f.size * (0.4 + t) * 2.4 / float(tex.get_width()) / Arena.TILE
		"anim":
			var tex := Fx.sheet(f.text)
			if tex == null:
				s.visible = false
				return
			var fh := tex.get_height() / maxi(1, f.frames)
			var visual := f.anim_visual(t)
			s.texture = visual.tex
			s.region_enabled = true
			s.region_rect = visual.src
			s.modulate = Color(f.color.r, f.color.g, f.color.b, f.anim_alpha_at(t))
			s.pixel_size = f.size * f.anim_scale_at(t) / float(tex.get_width()) / Arena.TILE
	s.scale = Vector3.ONE
	s.position = _air(f.position, 10.0)
	var lift := SPRITE_LIFT + 0.08
	if f.scare_snap and is_instance_valid(f.follow) and _sprites.has(f.follow.get_instance_id()):
		# 머리 위치에는 캐릭터 전방 보정이 이미 포함되어 있어 중복 적용하지 않는다.
		lift = 0.08
		var body: Sprite3D = _sprites[f.follow.get_instance_id()]["sprite"]
		var head := body.position+Vector3.UP*(body.offset.y+body.region_rect.size.y*0.2)*body.pixel_size*body.scale.y
		var face_half := float(s.region_rect.size.y)*s.pixel_size*0.5
		s.position = head+cam.global_basis.y*(face_half*0.25+2.0/Arena.TILE)
		# Tall bodies must not push the surprise out of the viewport.
		var screen := cam.unproject_position(s.position)
		var half_pixels := absf(cam.unproject_position(s.position+cam.global_basis.y*face_half).y-screen.y)
		if screen.y < half_pixels+12.0:
			screen.y = half_pixels+12.0
			s.position = cam.project_position(screen,-cam.to_local(s.position).z)
		# 세로로 선 큰 몸의 윗부분이 카메라 평면의 눈을 자르지 않도록 몸 앞면 깊이를 기준으로 한다.
		var body_top := body.position+Vector3.UP*(body.offset.y+body.region_rect.size.y*0.5)*body.pixel_size*body.scale.y
		var toward_camera := (cam.global_position-s.position).normalized()
		var depth_gap := maxf(0.0,(body_top-s.position).dot(cam.global_basis.z))
		lift = (depth_gap+0.08)/maxf(0.1,toward_camera.dot(cam.global_basis.z))
	if f.body_impact and is_instance_valid(f.follow) and _sprites.has(f.follow.get_instance_id()):
		var target := f.follow as Mon
		var body: Sprite3D = _sprites[target.get_instance_id()]["sprite"]
		s.position = body.position + cam.global_basis.x * f.offset.x / Arena.TILE + cam.global_basis.y * (target.feet_offset() - f.offset.y) / Arena.TILE
		lift = 0.04
	if f.pickup_height>=0.0:
		s.position=to3d(f.position,f.pickup_height/Arena.TILE*k+0.025)
	else:
		_lift_effect_to_camera(s, lift)

func _sync_fx_light(f: Fx, seen: Dictionary) -> void:
	var ent := _entry(f, seen)
	if not ent.has("light"):
		var l := OmniLight3D.new()
		l.light_cull_mask = 1
		l.light_color = Color(f.color.r, f.color.g, f.color.b)
		l.omni_range = f.size / Arena.TILE * 1.4
		root3d.add_child(l)
		ent["light"] = l
	var lt: OmniLight3D = ent["light"]
	lt.light_energy = f.color.a * 0.9 * (1.0 - _fx_t(f)) * local_light_gain()
	lt.position = to3d(f.position, 0.5 + (_starter_table_height if f.starter_table else 0.0))

# sprite 효과: 카메라를 보는 판. 크기·색·투명도·회전은 Fx 의 2D 그리기와 같은 식.
func _sync_fx_sprite(f: Fx, seen: Dictionary) -> void:
	var tex := f.sprite_texture()
	if tex == null:
		return
	var ent := _entry(f, seen)
	if not ent.has("sprite"):
		ent["sprite"] = _new_unlit_sprite(BaseMaterial3D.BILLBOARD_DISABLED, SpriteBase3D.ALPHA_CUT_DISABLED)
	var s: Sprite3D = ent["sprite"]
	var state := _fx_sprite_state(f,tex)
	s.texture = tex
	s.modulate = state.tint
	s.pixel_size = state.pixels
	s.position = state.position
	s.basis = state.basis
	s.visible = true
	if f.text=="g4_flame" and (f.ember_coat or f.grounded_flame):
		var t := clampf((f.age-f.delay)/maxf(0.001,f.lifetime-f.delay),0.0,1.0)
		EmberHeat.apply(s,f.age-f.delay,f.ember_phase,1.0-t*0.85)
	elif f.material is CanvasItemMaterial:
		s.material_override = null

var _smoke_batch_entry := {}

func _is_batch_smoke(f: Fx) -> bool:
	return f.smoke_veil and f.kind=="sprite" and f.text=="g4_smoke" and f.material==null

# A MultiMesh sorts as a single transparent object. Preserve interleaving by
# falling back whenever other air effects/projectiles are active in this world.
func _batchable_smoke() -> Array:
	for p in world.projectiles:
		if not p.dead: return []
	var smoke := []
	for f in world.fxs:
		if f.dead or f.age<f.delay: continue
		if _is_batch_smoke(f): smoke.append(f)
		elif f.kind not in ["text","light","tallgrass","rustle"]: return []
	return smoke if smoke.size()>=8 else []

func _sync_smoke_batch(smoke: Array) -> void:
	if smoke.is_empty():
		if _smoke_batch_entry.has("smoke"): _smoke_batch_entry.smoke.visible = false
		return
	var tex := Fx.sheet("g4_smoke")
	if tex==null: return
	var states := []
	var center := Vector3.ZERO
	for f in smoke:
		var state := _fx_sprite_state(f,tex)
		states.append(state)
		center += Vector3(state.position)
	center /= states.size()
	states.sort_custom(func(a,b):return Vector3(a.position).dot(cam.global_basis.z)<Vector3(b.position).dot(cam.global_basis.z))
	var batch := _projectile_batch(_smoke_batch_entry,"smoke",tex,states.size())
	if batch.instance_count!=states.size(): batch.instance_count = states.size()
	var node: MultiMeshInstance3D = _smoke_batch_entry.smoke
	node.position = center
	node.visible = true
	for i in states.size():
		var state: Dictionary = states[i]
		var size := Vector2(tex.get_size())*float(state.pixels)
		batch.set_instance_transform(i,Transform3D(state.basis*Basis.from_scale(Vector3(size.x,size.y,1)),Vector3(state.position)-center))
		batch.set_instance_color(i,state.tint)

# Both rendering paths share the exact smoke shape, fade and depth placement.
func _fx_sprite_state(f: Fx, tex: Texture2D) -> Dictionary:
	var tint := Color.WHITE
	var pixels := 1.0
	var position := Vector3.ZERO
	var basis := Basis.IDENTITY
	var t := clampf((f.age - f.delay) / maxf(0.001, f.lifetime - f.delay), 0.0, 1.0)
	var kk := f.sprite_scale_at(t)
	if f.grounded_flame:
		kk = lerpf(0.65,1.15,smoothstep(0.0,0.25,t))*lerpf(1.0,f.grow,smoothstep(0.4,1.0,t))
	var a := f.color.a * f.smoke_alpha_gain * ((1.0 - t * t) if f.fade_out >= 1.0 else clampf((1.0 - t) / f.fade_out, 0.0, 1.0))
	if f.fade_in > 0.0:
		a *= clampf(t / f.fade_in, 0.0, 1.0)
	tint = Color(f.color.r, f.color.g, f.color.b, a)
	pixels = f.size / float(tex.get_width()) * kk / Arena.TILE
	var lift := -f.arc_h * 4.0 * t * (1.0 - t) if f.arc_h > 0.0 else 0.0
	# 2D 의 '위로'(−y)는 3D 에선 높이로: 몸 위에 뜨는 효과가 바닥에 묻히지 않게.
	var sprite_lift := 8.0
	if f.text == "scary_face_hd2d":
		# Keep the lower teeth above the ground even at the intimidation peak.
		sprite_lift = maxf(8.0,f.size*kk*float(tex.get_height())/float(tex.get_width())*0.5+2.0)
	position = to3d(f.position + Vector2(0, sprite_lift), (sprite_lift - lift) / Arena.TILE * k)
	basis = cam.global_transform.basis * Basis(Vector3.BACK, -(f.rot + f.spin * f.age)) * Basis.from_scale(Vector3(1.0, f.sprite_stretch_at(), 1.0))
	if f.aimed_wave:
		var forward := to3d(f.position+f.dir,0)-to3d(f.position,0)
		var projected := Vector2(forward.dot(cam.global_basis.x),forward.dot(cam.global_basis.y))
		basis=cam.global_basis.orthonormalized()*Basis(Vector3.BACK,projected.angle()-PI/2.0)*Basis.from_scale(Vector3(1.0,f.sprite_stretch_at(),1.0))
	if f.claw_downstroke or f.body_impact:
		if is_instance_valid(f.follow) and f.follow is Mon and _sprites.has(f.follow.get_instance_id()):
			var target := f.follow as Mon
			var body: Sprite3D = _sprites[target.get_instance_id()]["sprite"]
			# Attach to the rendered body, including its existing depth correction.
			var offset := f.position-target.position if f.body_impact else f.offset
			position = body.position + cam.global_basis.x * offset.x / Arena.TILE + cam.global_basis.y * (target.feet_offset() - offset.y - (lift if f.body_impact else 0.0)) / Arena.TILE
			position += cam.global_basis.z * f.body_depth
			if f.ember_coat:
				# Use the current rendered torso, not the generic impact/feet
				# offset: otherwise tall targets wear all the flames as a crown.
				var center := body.position+Vector3.UP*body.offset.y*body.pixel_size*body.scale.y
				var span: float = target._sprites.get("reference_span",body.region_rect.size.x)
				var lateral := f.offset.x/maxf(target.radius,0.1)*span*body.pixel_size*0.42
				var rise := -(f.position.y-target.position.y-f.offset.y)/Arena.TILE
				position=center+cam.global_basis.x*lateral+cam.global_basis.y*rise+cam.global_basis.z*f.body_depth
		var drawn_offset := f.sprite_draw_offset(float(tex.get_height()) / tex.get_width(), kk) / Arena.TILE
		position += cam.global_basis.x * drawn_offset.x - cam.global_basis.y * drawn_offset.y
	if f.smoke_veil:
		# Stagger thin layers in height and depth; retain normal wall depth testing.
		var phase := f.rot*13.0+f.delay*21.0
		var rise := (5.0+sin(phase)*3.0+t*10.0)/Arena.TILE
		position += Vector3.UP*rise
		position += cam.global_basis.z*(0.25+0.22*sin(phase))
		basis = cam.global_basis * Basis(Vector3.BACK, -(f.rot+sin(t*5.0+phase)*0.12)) * Basis.from_scale(Vector3(1.0+sin(t*7.0+phase)*0.12,f.stretch,1.0))

	if f.grounded_flame or f.landing_dust:
		var half_height := float(tex.get_height())*pixels*f.stretch*0.5
		position = to3d(f.position,0.025)+cam.global_basis.y*half_height
	if f.material is CanvasItemMaterial:
		tint = Color(f.color.r * 1.2, f.color.g * 1.2, f.color.b * 1.2, a)

	if f.starter_table:
		position.y += _starter_table_height
	if f.water_surface:
		position=to3d(f.position,0.025)
		basis=Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
	return {"tint":tint,"pixels":pixels,"position":position,"basis":basis}

# Cache the release pose once. The visual correction tapers to zero at max range.
func _projectile_release_offset(p: Projectile) -> Vector3:
	if not p.mouth_ready:
		p.mouth_ready=true
		var source: Mon=p.emitter.get_ref() if p.emitter!=null else null
		if is_instance_valid(source) and _sprites.has(source.get_instance_id()):
			var body: Sprite3D=_sprites[source.get_instance_id()].get("sprite")
			if body!=null and body.texture!=null:
				var dir:=p.vel.normalized()
				var forward:=Vector3(dir.x,0,dir.y)
				var plane:=cam.global_basis
				var projected: Vector3=plane.x*forward.dot(plane.x)+plane.y*forward.dot(plane.y)
				var bounds:=MonSprite.release_bounds(body.texture,Rect2i(body.region_rect))
				if body.flip_h: bounds.position.x=body.region_rect.size.x-bounds.end.x
				var center:=sprite_pixel_position(body,bounds.get_center())
				var corner:=sprite_pixel_position(body,bounds.position)-center
				var ray:=projected.normalized()
				var half_w:=absf(corner.dot(plane.x))
				var half_h:=absf(corner.dot(plane.y))
				# Intersect the facing ray with the current pose's visible bounds in screen space.
				var edge:=minf(half_w/maxf(.0001,absf(ray.dot(plane.x))),half_h/maxf(.0001,absf(ray.dot(plane.y))))
				var tip:=center+ray*(edge+Projectile.RELEASE_GAP/Arena.TILE)

				var origin:=to3d(p.launch_position+Vector2.DOWN*6,6.0/Arena.TILE*k)
				p.mouth_delta=tip-origin
	return p.mouth_delta*clampf(p.range_left/maxf(1.0,p.range_full),0.0,1.0)

func _sync_projectile(p: Projectile, seen: Dictionary) -> void:
	if p == null or not is_instance_valid(p) or p.dead:
		return
	var ent := _entry(p, seen)
	if not ent.has("sprite"):
		var s0 := _new_sprite(BaseMaterial3D.BILLBOARD_ENABLED)
		s0.shaded = false
		s0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s0.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s0.region_enabled = false
		ent["sprite"] = s0
		if Look.PROJECTILE_LIGHT.has(p.style):
			var l := OmniLight3D.new()
			l.light_cull_mask = 1
			l.light_color = Look.PROJECTILE_LIGHT[p.style]
			l.light_energy = (0.11 if p.style == "ember_c" else (0.14 if p.style == "dragon_c" else (0.035 if p.style == "flame_c" else 0.55))) * local_light_gain()
			root3d.add_child(l)
			ent["light"] = l
	var s: Sprite3D = ent["sprite"]
	var release_offset:=_projectile_release_offset(p)
	if ent.has("light"):
		var full_range := 1.4 if p.style in ["ember_c", "dragon_c", "flame_c"] else 3.0
		var light: OmniLight3D = ent.light
		light.omni_range = full_range * float(p.hit.get("clash_fraction", 1.0))
	if p.style in ["acid","voice","needle","water","pulse"]:
		_sync_layered_projectile(p,ent)
		return
	if p.style == "dragon_c":
		s.visible = false
		var all_layers := p.dragon_layers()
		# Keep the two bright head layers independently sorted across projectiles.
		var layers := all_layers.slice(0,4)
		# Transparent instances are not sorted by MultiMesh: preserve the previous
		# back-to-front Sprite3D order within this projectile explicitly.
		layers.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			return to3d(a["offset"],0).dot(cam.global_basis.z)<to3d(b["offset"],0).dot(cam.global_basis.z))
		var tex := Fx.sheet("g4_glow")
		var batch := _projectile_batch(ent,"dragon_batch",tex,layers.size())
		var origin := to3d(p.position+Vector2(0,6),6.0/Arena.TILE*k)
		(ent["dragon_batch"] as MultiMeshInstance3D).position = origin+release_offset
		for i in layers.size():
			var layer: Dictionary = layers[i]
			var width := float(layer["size"])/Arena.TILE
			var height := width*float(tex.get_height())/float(tex.get_width())
			var at := to3d(p.position+layer["offset"]+Vector2(0,6),6.0/Arena.TILE*k)
			batch.set_instance_transform(i,Transform3D(cam.global_basis.scaled_local(Vector3(width,height,1)),at-origin))
			batch.set_instance_color(i,layer["color"])
		for i in range(4,6):
			var layer: Dictionary = all_layers[i]
			var glow := _fang_sprite(ent,"dragon_%d"%i,tex)
			glow.modulate = layer["color"]
			glow.pixel_size = float(layer["size"])/float(tex.get_width())/Arena.TILE
			glow.position = to3d(p.position+layer["offset"]+Vector2(0,6),6.0/Arena.TILE*k)+release_offset
		if ent.has("light"):
			(ent["light"] as OmniLight3D).position = to3d(p.position,0.5)+release_offset
		return
	var flame := p.style in ["ember", "ember_c", "flame"]
	var tex := p.visual_flame_texture() if p.style=="ember_c" else Fx.sheet("g4_flame" if flame else "g4_glow")
	s.texture = tex
	s.modulate = Color(1.0, 0.55, 0.15) if flame else p.color
	if tex != null:
		s.pixel_size = p.radius * 3.6 * p.scale_now() / float(tex.get_width()) / Arena.TILE
	s.position = to3d(p.position + Vector2(0, 6.0), 6.0 / Arena.TILE * k)+release_offset
	if p.style in ["ember_c", "flame_c"]:
		if p.style == "flame_c":
			_sync_flame_stream(p,ent,s.position)
			s.visible = false
			if ent.has("light"):
				(ent["light"] as OmniLight3D).position = s.position+Vector3(0,0.25,0)
			return
		s.pixel_size *= p.flame_envelope() * p.flame_size
		var flicker := sin(p.age*23.0+p.flame_phase)
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.flip_h = p.flame_mirror
		s.basis = cam.global_basis * Basis(Vector3.BACK,p.flame_tilt+flicker*0.08) * Basis.from_scale(Vector3(p.flame_aspect.x*(1.0+flicker*0.07),p.flame_aspect.y*(1.0-flicker*0.09),1.0))
		EmberHeat.apply(s,p.age,p.flame_phase,1.0)

	if ent.has("light"):
		(ent["light"] as OmniLight3D).position = s.position + Vector3(0, 0.4, 0)

func _sync_flame_stream(p: Projectile, ent: Dictionary, at: Vector3) -> void:
	var tex := Fx.sheet("g4_flame")
	if tex == null: return
	var velocity3 := to3d(p.position+p.vel.normalized(),0)-to3d(p.position,0)
	var screen_dir := Vector2(velocity3.dot(cam.global_basis.x),velocity3.dot(cam.global_basis.y))
	var rotation := screen_dir.angle()-PI/2.0
	var layers := p.stream_layers()
	var batch := _projectile_batch(ent,"stream_batch",tex,layers.size())
	(ent["stream_batch"] as MultiMeshInstance3D).position = at
	for i in layers.size():
		var layer: Dictionary = layers[i]
		var width := float(layer["width"])/Arena.TILE
		var height := float(layer["length"])*float(tex.get_height())/float(tex.get_width())/Arena.TILE
		var basis := cam.global_basis*Basis(Vector3.BACK,rotation)*Basis.from_scale(Vector3(width,height,1.0))
		batch.set_instance_transform(i,Transform3D(basis,cam.global_basis.z*float(i)*0.002))
		batch.set_instance_color(i,layer["color"])

# Batch only the layers of one projectile. Separate projectiles retain independent
# transparent-object sorting and lights; collisions and shared 2D layer data stay intact.
var _projectile_quad: QuadMesh
var _projectile_materials := {}

func _projectile_batch(ent: Dictionary, key: String, tex: Texture2D, count: int) -> MultiMesh:
	if not ent.has(key):
		if _projectile_quad == null:
			_projectile_quad = QuadMesh.new()
			_projectile_quad.size = Vector2.ONE
		if not _projectile_materials.has(tex):
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = true
			material.albedo_texture = tex
			_projectile_materials[tex] = material
		var node := MultiMeshInstance3D.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.layers = SPRITE_LAYER
		node.material_override = _projectile_materials[tex]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = _projectile_quad
		batch.instance_count = count
		node.multimesh = batch
		root3d.add_child(node)
		ent[key] = node
	return (ent[key] as MultiMeshInstance3D).multimesh

# Native item icons remain circular in the camera plane during their curved pickup flight.
func _sync_loot_items(seen: Dictionary) -> void:
	for item in world.drops:
		if not is_instance_valid(item) or item.done:continue
		var ent := _entry(item,seen)
		if not ent.has("sprite"):
			ent["sprite"]=_new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
			ent["blob"]=_new_blob()
		var sprite: Sprite3D=ent.sprite
		sprite.texture=item.texture
		sprite.region_enabled=false
		sprite.pixel_size=0.5/Arena.TILE
		sprite.position=to3d(item.draw_at,item.height/Arena.TILE*k+0.025)
		sprite.basis=cam.global_basis.orthonormalized()*item.draw_scale
		sprite.modulate=Color(1,1,1,item.alpha)
		sprite.visible=item.texture!=null
		var blob: MeshInstance3D=ent.blob
		blob.visible=item.flight<0.0
		blob.position=to3d(item.position,0.02)
		var shadow := contact_shadow(item.height,sky_kind(DungeonDB.current)=="indoor")
		blob.scale=Vector3(0.3*shadow.x,1,0.18*shadow.x)
		(blob.material_override as StandardMaterial3D).albedo_color=Color(0,0,0,shadow.y*0.65)

func _sync_layered_projectile(p: Projectile,ent: Dictionary) -> void:
	var mouth_weight := clampf(p.range_left/maxf(1.0,p.range_full),0.0,1.0)
	(ent.sprite as Sprite3D).visible=false
	var texture := Fx.sheet("kanto_disarming_voice_1" if p.style=="voice" else "g4_glow")
	var layers := p.layered_layers()
	for i in layers.size():
		var layer: Dictionary=layers[i]
		var layer_texture: Texture2D=Fx.sheet(layer.texture) if layer.has("texture") else texture
		var sprite := _fang_sprite(ent,"%s_%d"%[p.style,i],layer_texture)
		if p.style in ["voice","needle","water","pulse"]:sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		var layer_mouth_weight := mouth_weight
		if p.style=="pulse":
			# Each trailing ring stays above its own point on the launch path.
			layer_mouth_weight=clampf((p.range_left-Vector2(layer.offset).dot(p.vel.normalized()))/maxf(1.0,p.range_full),0.0,1.0)
		sprite.position=to3d(p.position+Vector2(layer.offset)+Vector2(0,6),6.0/Arena.TILE*k)+p.mouth_delta*layer_mouth_weight
		sprite.pixel_size=float(layer.size)/layer_texture.get_width()/Arena.TILE
		sprite.modulate=layer.color
		sprite.basis=cam.global_basis.orthonormalized()
		if p.style=="voice" and not bool(layer.get("aimed",false)):
			sprite.basis=cam.global_basis.orthonormalized()*Basis(Vector3.BACK,-float(layer.get("rot",0.0)))
		elif p.style in ["voice","needle","water","pulse"]:
			var vector := to3d(p.position+p.vel.normalized(),0)-to3d(p.position,0)
			var projected := Vector2(vector.dot(cam.global_basis.x),vector.dot(cam.global_basis.y))
			var facing_angle := projected.angle()-PI/2.0-float(layer.get("rot",0.0))
			sprite.basis=cam.global_basis.orthonormalized()*Basis(Vector3.BACK,facing_angle)*Basis.from_scale(Vector3(1.0,float(layer.get("stretch",1.0)),1.0))

