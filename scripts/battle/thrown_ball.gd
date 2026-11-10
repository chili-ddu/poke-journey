class_name ThrownBall
extends Node2D
const ItemPalette = preload("res://scripts/view/item_palette.gd")

# 트레이너가 던진 몬스터볼: 손(from)에서 내보낼 자리(to)까지 포물선으로 날아가며 돈다. 다 날아가면 Game 이 터뜨리고 치운다.
# 그림은 시작 연출 탁자 위 볼과 같은 파이어레드 지도 물건 볼(assets/fx/item_ball.png)을 지도 배율로.

const SPIN := 14.0               # 라디안/초

var from := Vector2.ZERO
var to := Vector2.ZERO
var height := 0.0                # px. 꼭대기 높이
var k := 0.0                     # 0 → 1 (Game 이 넣는다)
var _tex: Texture2D = null

func setup(a: Vector2, b: Vector2, h: float) -> void:
	from = a
	to = b
	height = h
	z_index = 6                  # 포켓몬·사람·연출 위
	_tex = ItemPalette.ground_ball()

func at() -> Vector2:
	return from.lerp(to, k) - Vector2(0, height * 4.0 * k * (1.0 - k))

func _draw() -> void:
	if _tex == null:
		return
	var size := Vector2(16, 16) * Arena.MAP_SCALE * 0.75
	draw_set_transform(at(), k * SPIN * 0.45)
	draw_texture_rect(_tex, Rect2(-size / 2.0, size), false)
	draw_set_transform(Vector2.ZERO)
