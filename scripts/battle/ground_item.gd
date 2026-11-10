class_name GroundItem
extends Node2D
const ItemPalette = preload("res://scripts/view/item_palette.gd")

# 바닥에 떨어진 물건(원작 지도 물건 볼 그림 assets/fx/item_ball.png, 지도 배율). 새미가 달아나며 흘린 기술머신(사용자 결정 2026-10-30).
# 밟으면 Game 이 줍는다(_check_drops).

var move := ""            # 기술머신의 기술 id
var from_id := ""         # 떨어뜨린 트레이너
var berries := 0          # 함께 떨어진 오랭열매 수
var _tex: Texture2D = null
const DROP_TIME := 0.38
const FALL_TIME := 0.24
var drop_age := DROP_TIME

static func drop_height(age: float) -> float:
	if age < FALL_TIME:
		var t := clampf(age/FALL_TIME,0.0,1.0)
		return 14.0*(1.0-t*t)
	if age < DROP_TIME:
		return 3.0*sin(PI*(age-FALL_TIME)/(DROP_TIME-FALL_TIME))
	return 0.0

func step_drop(dt: float) -> void:
	drop_age = minf(DROP_TIME,drop_age+dt)
	queue_redraw()

func _process(dt: float) -> void:
	if drop_age < DROP_TIME: step_drop(dt)

func setup(tile: Vector2i, move_id: String, trainer_id: String, falling: bool = false) -> void:
	position = Arena.tile_center(tile)
	drop_age = 0.0 if falling else DROP_TIME
	move = move_id
	from_id = trainer_id
	z_index = -1              # 지도 위, 포켓몬·사람 아래
	_tex = ItemPalette.ground_ball()

func _draw() -> void:
	if _tex == null:
		return
	var size := Vector2(16, 16) * Arena.MAP_SCALE
	draw_texture_rect(_tex, Rect2(-Vector2(8,15)*Arena.MAP_SCALE-Vector2(0,drop_height(drop_age)), size), false)
