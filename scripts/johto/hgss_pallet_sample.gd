extends "res://scripts/johto/hgss_map_preview.gd"

## Review-only Pallet Town: native HGSS geometry with the existing player/HUD.
const Game = preload("res://scripts/game.gd")
const SAMPLE_BASE := "res://assets/maps/hgss_pallet_sample/"
var sample_game: Node2D
var player_view: SubViewport
var hud: Hud
var raw_art := false
var post: ColorRect
const Palette = preload("res://scripts/view/map_palette.gd")
const Style = preload("res://scripts/johto/visual_style_rules.gd")
var _last_profile := ""

func collection_directory() -> String:
	return SAMPLE_BASE

func initial_header() -> int:
	return 49

func current_profile() -> String:
	return Style.profile(collection.manifest.headers.get(str(header), {}))

func _ready() -> void:
	collection = Collection.new(collection_directory())
	_build_camera()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(Style.data().camera.fov)
	_build_actor()
	_build_ui()
	info.hide()
	status.hide()
	_build_current_ui()
	_build_post()
	visit(initial_header())

func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	post = ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/hd2d_post.gdshader")
	post.material = material
	layer.add_child(post)

func _prepare_materials(node: Node) -> void:
	super._prepare_materials(node)
	if raw_art: return
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is BaseMaterial3D and material.albedo_texture != null:
				material.albedo_texture = Palette.texture(material.albedo_texture)

func _build_current_ui() -> void:
	# Game is deliberately never added to the tree: no opening, persistence,
	# events, NPC spawning or gameplay initialization runs in this sample.
	sample_game = Game.new()
	sample_game.mode = "sample"
	sample_game.bot = true
	sample_game.hub = false
	sample_game.world = World.new()
	var player := Player.new()
	player.setup_player("charmander", 5, ["scratch", "growl"])
	player.position = Vector2(48, 48)
	sample_game.world.player = player
	player_view = SubViewport.new()
	player_view.size = Vector2i(96, 96)
	player_view.world_2d = World2D.new()
	player_view.disable_3d = true
	player_view.transparent_bg = true
	player_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(player_view)
	player_view.add_child(sample_game.world)
	sample_game.world.add_child(player)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.game = sample_game
	hud.size = Vector2(384, 216)
	layer.add_child(hud)
	sample_game.banner_text = "태초마을"
	sample_game.banner_kind = "town"
	sample_game.banner_t = 2.0

func _follow_camera(target: Vector3) -> void:
	var angle := deg_to_rad(float(Style.data().camera.elevation))
	camera.position = target + Vector3(0, sin(angle), cos(angle)) * float(Style.data().camera.distance)
	camera.look_at(target)

func _process(delta: float) -> void:
	if sample_game == null: return
	var previous := position_2d
	super._process(delta)
	var player: Player = sample_game.world.player
	player.anim_t += delta
	player.vel = (position_2d - previous) * Arena.TILE / maxf(delta, 0.0001)
	if player.vel.length_squared() > 1.0:
		player.facing = player.vel.normalized()
		player._walk_visual_time += delta
	player.queue_redraw()
	# Use the frame/anchor actually drawn by Mon, just as View3D does. This
	# preserves the approved current animation rather than selecting raw PMD frames.
	var so: StatOverlay = player.stat_overlay
	if so == null or so.tex == null: return
	var kind := current_profile()
	var frame := Look.selout_frame(so.tex, so.src, "forest" if kind == "forest" else "indoor" if kind in ["indoor", "cave"] else "day")
	actor.texture = frame.tex
	actor.region_rect = frame.src
	actor.region_enabled = true
	actor.pixel_size = so.xform.get_scale().x / Arena.TILE
	var center := so.dst.get_center()
	var feet := float(player._sprites.get("feet_dy", 0.0)) - 1.0
	actor.offset = Vector2(center.x, -(center.y - feet))
	actor.scale.y = so.xform.get_scale().y / so.xform.get_scale().x / cos(deg_to_rad(float(Style.data().camera.elevation)))
	actor.position = Vector3(position_2d.x, ground_y + 0.025, position_2d.y)
	if kind == "indoor":
		sample_game.mode = "indoor"
		sample_game.banner_kind = "indoors"
	else:
		sample_game.mode = "sample"
		sample_game.banner_kind = "town"
	sample_game.banner_text = collection.title(header)
	if post != null:
		post.visible = not raw_art
		if kind != _last_profile:
			Style.apply(post.material as ShaderMaterial, kind)
			_last_profile = kind

func _exit_tree() -> void:
	if sample_game != null:
		sample_game.free()
		sample_game = null
