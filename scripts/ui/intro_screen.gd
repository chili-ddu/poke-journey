extends Control
const Surface = preload("res://scripts/ui/intro_surface.gd")
const SELECTION := "res://scenes/title.tscn"
var surface: Control
var phase := "loading"
var launching := false
var prepare_override := Callable() # Test seam; never touches actual save files.

func _ready() -> void:
	ViewScale.init_window(get_tree())
	if not ViewScale.mobile_mode(get_tree()):get_window().content_scale_size=Vector2i(384,216)
	surface=Surface.new()
	add_child(surface)
	surface.activated.connect(activate)
	surface.start_battle()
	_prepare.call_deferred()

func _prepare() -> void:
	phase="loading"
	surface.set_phase("loading","모험을 준비하고 있습니다…")
	var error: int=await prepare_override.call() if prepare_override.is_valid() else await WebContent.prepare(get_tree(),"charmander")
	if not is_inside_tree():return
	phase="ready" if error==OK else "error"
	surface.set_phase(phase,"자료를 받지 못했습니다. 연결을 확인해 주세요." if error!=OK else "")

func _process(_dt: float) -> void:
	if phase=="loading" and surface!=null and not WebContent.message.is_empty():
		surface.set_phase("loading",WebContent.message,WebContent.current,WebContent.total)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:return
	var pressed := false
	if event is InputEventKey:pressed=event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]
	elif event is InputEventMouseButton:pressed=event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:pressed=event.pressed
	elif event is InputEventJoypadButton:pressed=event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_START]
	if pressed:activate()
	# Let the pad service track releases and suppress held buttons across scenes.
	if not event is InputEventJoypadButton:get_viewport().set_input_as_handled()

func activate() -> void:
	if launching or phase=="loading":return
	if phase=="error":
		_prepare()
		return
	launching=true
	surface.set_phase("loading","모험을 준비하고 있습니다…")
	# Defer scene replacement so the initiating event never reaches selection.
	_enter_selection.call_deferred()

func _enter_selection() -> void:
	surface.stop_battle()
	surface.dismiss()
	var error := get_tree().change_scene_to_file(SELECTION)
	if error!=OK:
		launching=false
		phase="error"
		surface.presentation_visible=true
		surface.set_phase("error","선택 화면을 열지 못했습니다.")
