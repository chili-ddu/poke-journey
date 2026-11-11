extends CanvasLayer
# Lives on SceneTree.root so the cover survives the title scene being freed.
signal finished
signal failed(error: int)
const FADE_OUT := 0.18
const FADE_IN := 0.28
var active := false
var scene_path := ""
var overlay: Control

const Cover = preload("res://scripts/ui/loading_cover.gd")

func _ready() -> void:
	layer=128
	process_mode=Node.PROCESS_MODE_ALWAYS
	overlay=Cover.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	overlay.modulate.a=0.0
	add_child(overlay)

func _input(event: InputEvent) -> void:
	# The pad service tracks releases while this cover blocks its commands.
	if active and not (event is InputEventJoypadButton or event is InputEventJoypadMotion):get_viewport().set_input_as_handled()

func begin(path: String,prepare: Callable=Callable(),species: String="charmander") -> void:
	if active:return
	active=true
	scene_path=path
	var tree := get_tree()
	await _fade(1.0,FADE_OUT)
	# Submit an opaque loading frame before any main-thread scene construction.
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	var error := await WebContent.prepare(tree,species)
	if error==OK:
		error=ResourceLoader.load_threaded_request(path,"PackedScene") if ResourceLoader.exists(path) else ERR_FILE_NOT_FOUND
	if error!=OK:
		await _restore(error)
		return
	var status := ResourceLoader.load_threaded_get_status(path)
	while status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
		status=ResourceLoader.load_threaded_get_status(path)
	if status!=ResourceLoader.THREAD_LOAD_LOADED:
		await _restore(ERR_CANT_OPEN)
		return
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed==null:
		await _restore(ERR_INVALID_DATA)
		return
	if prepare.is_valid():prepare.call()
	prepare=Callable()
	var previous := tree.current_scene
	error=tree.change_scene_to_packed(packed)
	if error!=OK:
		await _restore(error)
		return
	while tree.current_scene==null or tree.current_scene==previous:await tree.process_frame
	var game := MobileGameFrame.unwrap(tree.current_scene)
	var was_processing := game.is_processing()
	game.set_process(false)
	# Let camera, sprites and the first rendered frame settle under the cover.
	for i in 2:await tree.process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	await _fade(0.0,FADE_IN)
	if is_instance_valid(game):game.set_process(was_processing)
	active=false
	finished.emit()
	queue_free()

func _fade(alpha: float,duration: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay,"modulate:a",alpha,duration)
	await tween.finished

func _restore(error: int) -> void:
	await _fade(0.0,FADE_IN)
	active=false
	failed.emit(error)
	queue_free()
