class_name StarterBalls
extends Node2D
const ItemPalette = preload("res://scripts/view/item_palette.gd")

# 오박사 연구소 탁자 위 스타팅 볼 세 개(파이어레드 연구소 지도의 물건 ITEM_BALL 자리 그대로: 이상해씨 (8,4) · 꼬북이 (9,4) · 파이리 (10,4)).
# 그림은 파이어레드 지도 물건 볼(assets/fx/item_ball.png, tools/frlg_npc.py --ball)을 지도 배율(1.5)로.
# 내 스타팅의 볼은 시작 연출(Game "opening") 동안만 보이고 — 탁자 위에서 버둥대듯 흔들리다 터지듯 열린다 — 그 뒤로는 빈자리다.
# 연출 상태는 Game 이 wobble(흔들림 각도)·taken(열려서 사라짐)으로 넣어 준다.

const TILES := {"bulbasaur": Vector2i(8, 4), "squirtle": Vector2i(9, 4), "charmander": Vector2i(10, 4)}

var starter := ""
var intro := false          # 연출 중이면 내 볼도 그린다
var wobble := 0.0           # 라디안. 볼 밑동을 축으로
var taken := false
var _tex: Texture2D = null

func setup(starter_id: String) -> void:
	starter = starter_id
	_tex = ItemPalette.ground_ball()
	position = Vector2.ZERO           # World y 정렬에서 맨 앞(y 0) — 지도 위, 포켓몬·사람 밑에 그려진다

# 내 볼이 열릴 바닥 자리(탁자 바로 앞 칸).
static func floor_of(starter_id: String) -> Vector2:
	return Arena.tile_center(TILES.get(starter_id, TILES["charmander"]) + Vector2i.DOWN)

static func ball_of(starter_id: String) -> Vector2:
	return Arena.tile_center(TILES.get(starter_id, TILES["charmander"]))

func _draw() -> void:
	if _tex == null:
		return
	var s := Arena.MAP_SCALE
	var size := Vector2(16, 16) * s
	for id in TILES:
		var mine: bool = id == starter
		if mine and (not intro or taken):
			continue
		var at := Arena.tile_center(TILES[id])
		var ang := wobble if mine else 0.0
		# 볼 밑동(그림의 아래 끝 y=15)을 축으로 기울인다.
		var pivot := at + Vector2(0, 7.0 * s)
		draw_set_transform(pivot, ang)
		draw_texture_rect(_tex, Rect2(at - pivot - size / 2.0, size), false)
		draw_set_transform(Vector2.ZERO)
