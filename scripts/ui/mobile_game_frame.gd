class_name MobileGameFrame
extends Control

## Root proxy owns the original scene, so stock reload/scene changes free it too.
var content: Node
var display: SubViewportContainer
var client: SubViewport
var pad: TouchControls
var logical_size := Vector2i(384,216)
var safe_override := Rect2()
var use_display_safe_area := true
var layout := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new()
	background.color = Color("111820")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	display = SubViewportContainer.new()
	display.stretch = true
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(display)
	client = SubViewport.new()
	client.world_2d = World2D.new()
	client.size_2d_override = logical_size
	client.size_2d_override_stretch = true
	client.oversampling = false
	client.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	client.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	display.add_child(client)
	pad = TouchControls.new()
	pad.mobile_override = 1
	add_child(pad)
	get_viewport().size_changed.connect(fit)
	client.size_changed.connect(_sync_content)
	fit()

static func unwrap(scene: Node) -> Node:
	return scene.content if scene is MobileGameFrame else scene

func adopt(scene: Node, game_size: Vector2i) -> void:
	content = scene
	scene_file_path = scene.scene_file_path
	logical_size = game_size
	client.size_2d_override = logical_size
	if scene.get_parent()!=client:scene.reparent(client,false)
	if scene is Control:
		scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.game = scene
	if scene.has_method("_fit_ui"):
		var old_pad = scene.touch_controls
		if is_instance_valid(old_pad):
			old_pad.game = null
			old_pad.queue_free()
		scene.touch_controls = pad
		pad.game = scene
		if pad.human()!=null and Input.is_action_pressed("move_click"):
			scene.world.player.controller.hold = true
			scene.world.player.controller.has_target = false
		if scene.world.cam != null:scene.world.cam.make_current()
		if scene.view3d != null:scene.view3d.ov.world_2d = client.world_2d
	fit()
	_sync_content.call_deferred()

func _safe_area() -> Rect2:
	if safe_override.has_area():return safe_override
	if not use_display_safe_area or not TouchControls.mobile_platform():return Rect2()
	var safe := DisplayServer.get_display_safe_area()
	return Rect2(Vector2(safe.position-DisplayServer.window_get_position()),Vector2(safe.size))

func fit() -> void:
	if client == null:return
	var surface := get_viewport_rect().size
	var previous: Rect2 = layout.get("controls",Rect2())
	layout = MobileScreenLayout.calculate(surface,Vector2(logical_size),_safe_area())
	display.position = layout.display.position
	display.size = layout.display.size
	client.set_meta("mobile_display_scale",float(layout.scale))
	if previous != layout.controls:pad.cancel_all()
	pad.control_area = layout.controls
	pad.display_area = layout.display
	pad.control_scale = layout.scale
	pad.refresh()
	_sync_content.call_deferred()

func set_game_size(value: Vector2i) -> void:
	logical_size = value
	client.size_2d_override = value
	fit()

func _sync_content() -> void:
	if not is_instance_valid(content):return
	if content.has_method("_fit_ui"):
		content._fit_ui()
		if content.view3d != null:content.view3d.fit_render_target()
