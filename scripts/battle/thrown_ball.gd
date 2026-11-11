class_name ThrownBall
extends Node2D
const ItemPalette = preload("res://scripts/view/item_palette.gd")

# 트레이너가 던진 몬스터볼: 손(from)에서 내보낼 자리(to)까지 포물선으로 날아가며 돈다. 다 날아가면 Game 이 터뜨리고 치운다.
# 그림은 시작 연출 탁자 위 볼과 같은 파이어레드 지도 물건 볼(assets/fx/item_ball.png)을 지도 배율로.

var sender: Npc
var release_3d := Vector3.INF
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
	var size := BallRelease.BALL_RECT.size*BallRelease.PIXEL
	var center := at()-Vector2.DOWN*5.0*BallRelease.PIXEL*k
	draw_set_transform(center, TAU*k)
	draw_texture_rect_region(_tex,Rect2(-size/2.0,size),BallRelease.BALL_RECT)
	draw_set_transform(Vector2.ZERO)
