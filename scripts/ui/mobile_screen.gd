extends Node

## Desktop does nothing. Mobile adopts each newly loaded scene into its own frame.
var active := false

func _ready() -> void:
	if TouchControls.mobile_platform():activate()

func activate() -> void:
	if active:return
	active = true
	get_tree().root.set_meta("mobile_presentation",true)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.child_entered_tree.connect(_root_child_entered)
	_adopt_current.call_deferred()

func _root_child_entered(_node: Node) -> void:
	_adopt_current.call_deferred()

func _adopt_current() -> void:
	var tree := get_tree()
	var scene := tree.current_scene
	if not active or not is_instance_valid(scene) or scene is MobileGameFrame:return
	if scene.get_parent()!=tree.root or scene.scene_file_path.is_empty():return
	if scene.scene_file_path.ends_with("/intro.tscn"):return
	var logical := ViewScale.TITLE_VIEW if scene.scene_file_path.ends_with("/title.tscn") else ViewScale.size()
	var frame := MobileGameFrame.new()
	frame.name = "MobileGameFrame"
	frame.scene_file_path = scene.scene_file_path
	tree.root.add_child(frame)
	# current_scene must stay a direct child of root before the original moves.
	tree.current_scene = frame
	frame.adopt(scene,logical)
