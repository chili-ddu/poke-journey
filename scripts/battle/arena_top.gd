class_name ArenaTop
extends Node2D

# 지도의 위층(나무 윗부분·지붕). 타일 행마다 띠(TopStrip)로 나눠 그려 World 의 y 정렬에 포켓몬과 함께 섞인다.
# 한 행을 두 띠로 나눈다(2026-10-28 사용자 지적: 지붕 바로 뒤에 바짝 붙으면 파이리가 지붕 위에 그려짐).
#   막힌 칸의 위층(나무 윗부분 등)  정렬 y = 행 바닥 − FEET_OFF. 같은 행 옆에 선 포켓몬은 발이 그보다 아래라 위에 그려진다 → 나무 옆에서 도트가 안 잘린다.
#                                    북쪽(뒤)의 포켓몬은 가려진다.
#   걸을 수 있는 칸의 위층(지붕 맨 윗줄처럼 원작에서 뒤로 들어가 숨는 칸)  정렬 y = 행 바닥. 그 행 안에 선 포켓몬(몸 중심이 행 안)은
#                                    언제나 덮는다 — 아래 막힌 칸에 붙어 중심이 바닥 −9px 까지 내려가도.
#   숨는 칸 바로 아래 막힌 칸의 바닥 그림(Arena.cover_cells)  정렬 y = 행 맨 위 + 1. 위 칸에 선 포켓몬의 칸 밖으로 내려온 발을 덮는다.

const FEET_OFF := 10.0

var arena: Arena

func _ready() -> void:
	y_sort_enabled = true
	if not Arena.has_map():
		return
	var b := Arena.bounds()
	if Arena.is_continent():b=Rect2(Vector2.ZERO,Vector2(Arena.map.width,Arena.map.height)*Arena.TILE)
	var rows := int(b.size.y / Arena.TILE)
	for r in rows:
		if not Arena.cover_cells(r).is_empty():
			var cover := CoverStrip.new()
			cover.row = r
			cover.position = Vector2(b.position.x, b.position.y + r * Arena.TILE + 1.0)
			add_child(cover)
		if not Arena.top_row_has_pixels(r):
			continue
		for walkable in [false, true]:
			var strip := TopStrip.new()
			strip.row = r
			strip.walkable = walkable
			var sort_off := 0.0 if walkable else FEET_OFF
			strip.position = Vector2(b.position.x, b.position.y + (r + 1) * Arena.TILE - sort_off)
			strip.dst_y = -(Arena.TILE - sort_off)
			add_child(strip)

class CoverStrip:
	extends Node2D
	var row := 0

	func _draw() -> void:
		Arena.draw_cover_cells(self, row, -1.0)

class TopStrip:
	extends Node2D
	var row := 0
	var walkable := false
	var dst_y := 0.0

	func _draw() -> void:
		# 띠 그림은 노드 위치(정렬 y)에서 dst_y 만큼 올라간 곳(행 위쪽)부터 한 행 높이. 이 띠가 맡은 칸(걸을 수 있음/막힘)만.
		Arena.draw_top_row(self, row, dst_y, 1 if walkable else 2)
