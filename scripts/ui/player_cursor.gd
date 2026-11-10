class_name PlayerCursor
extends Node

const DATA_PATH := "res://assets/ui/cursors/footprints.json"
const SHAPES := [Input.CURSOR_ARROW,Input.CURSOR_POINTING_HAND]
static var _entries: Dictionary={}
static var _textures: Dictionary={}
var player: Player
var current_species := ""
var current_texture: Texture2D
var hotspot := Vector2.ZERO
var _initialized := false
var _mouse_inside := false
var _window: Window

func _ready() -> void:
	_window=get_window()
	_window.mouse_entered.connect(_on_mouse_entered)
	_window.mouse_exited.connect(_on_mouse_exited)
	_window.focus_exited.connect(_on_mouse_exited)
	_window.focus_entered.connect(_check_mouse_inside)
	_check_mouse_inside()

func _check_mouse_inside() -> void:
	_mouse_inside=_window.get_visible_rect().has_point(_window.get_mouse_position())
	_apply_window_cursor()

func _on_mouse_entered() -> void:
	_mouse_inside=true
	_apply_window_cursor()

func _on_mouse_exited() -> void:
	_mouse_inside=false
	_apply_window_cursor()

func using_custom_cursor() -> bool:
	return _mouse_inside and current_texture!=null

static func entry_for(species: String) -> Dictionary:
	if _entries.is_empty():
		_entries=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _entries.get(species,{})

func setup(owner: Player) -> void:
	player=owner
	refresh()

func _process(_dt: float) -> void:
	if is_instance_valid(player):refresh()

func refresh() -> void:
	if not is_instance_valid(player):return
	var species:=player.species_id
	if _initialized and current_species==species:return
	_initialized=true
	current_species=species
	var entry:=entry_for(species)
	current_texture=null
	hotspot=Vector2.ZERO
	if not entry.is_empty():
		if not _textures.has(species):_textures[species]=load(entry.texture)
		current_texture=_textures[species]
		hotspot=Vector2(entry.hotspot[0],entry.hotspot[1])
	_apply_window_cursor()

func _apply_window_cursor() -> void:
	if DisplayServer.get_name()=="headless":return
	var texture:=current_texture if using_custom_cursor() else null
	var point:=hotspot if texture!=null else Vector2.ZERO
	for shape in SHAPES:Input.set_custom_mouse_cursor(texture,shape,point)

func _exit_tree() -> void:
	# Restore the system pointer when returning to the title or closing gameplay.
	if DisplayServer.get_name()!="headless":
		for shape in SHAPES:Input.set_custom_mouse_cursor(null,shape)
