class_name Npc
extends Node2D

# 지도 위 사람(간호순·점원·트레이너). 파이어레드 사람 도트(assets/npcs/<sprite>.png, 16×32 프레임: 0 아래·1 위·2 왼쪽 대기,
# 3·4 아래 걸음, 5·6 위 걸음, 7·8 왼쪽 걸음 — 오른쪽은 왼쪽 뒤집기, tools/frlg_npc.py)를 지도 배율(1.5)로 키워 칸 위에 세운다.
# 말 걸기(E)는 Game 이 talk 종류로 처리한다(nurse / shop / trainer). 위치는 칸 가운데 — World 의 y 정렬에 포켓몬과 함께 섞인다.
# 트레이너(사용자 결정 2026-10-29): 원작처럼 바라보는 쪽 sight 칸 안(벽에 막히지 않은 일직선)에 플레이어가 들어오면 "!" 를 띄우고
# 다가와 말을 건다(Game). sight_rect 가 있으면 그 칸 사각형에 들어와도 알아챈다(길을 막는 트레이너 — 통로 폭 전체를 본다).
# 사람은 막힌 칸처럼 지나갈 수 없다(World 가 밀어낸다).

const FRAME := Vector2(16, 32)
const FACE_FRAME := {"down": 0, "up": 1, "left": 2, "right": 2}
const WALK_FRAMES := {"down": [3, 4], "up": [5, 6], "left": [7, 8], "right": [7, 8]}
const DIRS := {"down": Vector2i.DOWN, "up": Vector2i.UP, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}
const WALK_SPEED := 90.0           # 원작 걷기: 한 칸(16px) 16프레임 = 초당 3.75칸 → 24px 칸이면 90px/s
const EMOTE_TIME := 0.6
const EMOTE_HEAD := 11.0           # 파이어레드 사람 도트(16×32)의 머리 꼭대기 줄(프레임 위 11px 는 비어 있다). 포켓몬의 "!" 도 이 높이에 맞춘다(Mon)

# "!" 의 아래 끝 y(그 칸에 선 사람 기준, 위치 상대): 사람과 포켓몬이 마주 보며 놀랄 때 같은 높이에 뜨게(사용자 지적 2026-10-30).
static func emote_bottom() -> float:
	var s := Arena.MAP_SCALE
	return Arena.TILE / 2.0 - FRAME.y * s + EMOTE_HEAD * s + 2.0
const TURN_EVERY := 2.0            # face "down_up"(앤서니): 아래 ↔ 위를 번갈아 본다
const BODY_R := 9.0                # 밀어내기 반지름

var id := ""
var talk := ""
var face := "down"
var tile := Vector2i.ZERO
var talk_tile := Vector2i.ZERO      # 말을 걸 수 있는 자리(카운터 앞 칸). 트레이너는 둘레 어디서나
var heal_spot := Vector2.INF       # 간호순: 회복 기계 위(월드 px). 없으면 INF
var trainer_id := ""
var sight := 0
var sight_rect := Rect2i()
var turning := false                # face "down_up"
var emote_t := 0.0                  # "!" 남은 시간
var walk_target := Vector2.INF      # 걸어갈 자리(월드 px)
var speed := WALK_SPEED             # px/s. 달려오는 라이벌은 더 빠르다(Game.RIVAL_RUN)
var _turn_t := 0.0
var _walk_t := 0.0
var _tex: Texture2D = null
const THROW_SHEETS := {"blue":preload("res://assets/npcs/throw/blue.png"),"brock":preload("res://assets/npcs/throw/brock.png")}
const THROW_TIMES := [0.0,0.035,0.075,0.115,0.175,0.20,0.265,0.34]
const THROW_HANDS := {
	"blue":[Vector2(10,25),Vector2(8,24),Vector2(6,22),Vector2(5,20),Vector2(5,22),Vector2(6,24),Vector2(9,25),Vector2(11,25)],
	"brock":[Vector2(10,24),Vector2(7,23),Vector2(6,21),Vector2(7,19),Vector2(6,21),Vector2(7,24),Vector2(11,25),Vector2(11,25)]
}
var sprite_id := ""
var throw_time := -1.0
var frame_size := FRAME
var _emote: Texture2D = null
var _head := 0.0                    # 첫 프레임에서 머리 끝(불투명한 첫 줄, 원본 px) — "!" 를 머리 바로 위에 띄운다

func setup(cfg: Dictionary) -> void:
	id = String(cfg["id"])
	talk = String(cfg.get("talk", ""))
	face = String(cfg.get("face", "down"))
	if face == "down_up":
		turning = true
		face = "down"
	tile = cfg["tile"]
	talk_tile = cfg.get("talk_tile", tile + Vector2i.DOWN)
	trainer_id = String(cfg.get("trainer", ""))
	if cfg.has("heal_spot"):
		heal_spot = (cfg["heal_spot"] as Vector2) * Arena.TILE
	sight = int(cfg.get("sight", 0))
	sight_rect = cfg.get("sight_rect", Rect2i())
	if trainer_id != "":
		talk = "trainer"
	position = Arena.tile_center(tile)
	var sprite := String(cfg.get("sprite", TrainerDB.sprite(trainer_id) if trainer_id != "" else id))
	sprite_id = sprite
	var dimensions: Array=TrainerDB.RoadData.SPRITE_FRAMES.get(sprite,[16,32])
	frame_size=Vector2(dimensions[0],dimensions[1])
	var path := "res://assets/npcs/%s.png" % sprite
	_tex = load(path) if ResourceLoader.exists(path) else null
	if _tex != null:
		var img := _tex.get_image()
		if img != null:
			_head = float(img.get_region(Rect2i(0, 0, int(frame_size.x), int(frame_size.y))).get_used_rect().position.y)
	_emote = load("res://assets/fx/emote_exclaim.png") if ResourceLoader.exists("res://assets/fx/emote_exclaim.png") else null

func is_trainer() -> bool:
	return trainer_id != ""

# 플레이어가 말을 걸 수 있는 거리인가. 사람은 말 거는 칸 가운데에서 한 칸 안, 트레이너는 몸에서 한 칸 반 안.
func can_talk(pos: Vector2) -> bool:
	if talk == "":
		return false                    # 말이 없는 사람(문 앞 장면의 오박사처럼)
	if is_trainer():
		return pos.distance_to(position) <= Arena.TILE * 1.5
	return pos.distance_to(Arena.tile_center(talk_tile)) <= Arena.TILE * 1.0

# 플레이어(pos)를 보았나: 바라보는 쪽 일직선 sight 칸(막힌 칸에서 끊김) 또는 sight_rect 안.
func sees(pos: Vector2) -> bool:
	if not is_trainer():
		return false
	var pt := Arena.tile_of(pos)
	if sight_rect.size != Vector2i.ZERO and sight_rect.has_point(pt):
		return true
	var my := Arena.tile_of(position)
	var d: Vector2i = DIRS[face]
	for k in range(1, sight + 1):
		var t := my + d * k
		if Arena.solid_at(t.x, t.y):
			return false
		if t == pt:
			return true
	return false

func face_toward(pos: Vector2) -> void:
	var v := pos - position
	if absf(v.x) > absf(v.y):
		face = "right" if v.x > 0.0 else "left"
	else:
		face = "down" if v.y > 0.0 else "up"

func step(dt: float) -> void:
	emote_t = maxf(0.0, emote_t - dt)
	if walk_target != Vector2.INF:
		var to := walk_target - position
		if to.length() <= speed * dt:
			position = walk_target
			walk_target = Vector2.INF
		else:
			position += to.normalized() * speed * dt
			_walk_t += dt * speed / WALK_SPEED
	elif turning and emote_t <= 0.0:
		_turn_t += dt
		if _turn_t >= TURN_EVERY:
			_turn_t = 0.0
			face = "up" if face == "down" else "down"
	queue_redraw()

func walking() -> bool:
	return walk_target != Vector2.INF

func _draw() -> void:
	var s := Arena.MAP_SCALE
	var visual := visual_frame()
	var w := float(visual.src.size.x) * s
	var h := frame_size.y * s
	# 발이 칸 아래쪽(가운데 + 반 칸 − 2px)에 오게.
	var dst := Rect2(Vector2(-w / 2.0, Arena.TILE / 2.0 - 2.0 * s - h + 2.0 * s), Vector2(w, h))
	draw_set_transform(Vector2(0, Arena.TILE / 2.0 - 3.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	if _tex == null:
		draw_rect(Rect2(-8, -20, 16, 28), Color("f0a0b0"))
		return
	if face == "right":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(visual.tex, dst, visual.src)
	draw_set_transform(Vector2.ZERO)
	# "!"(원작 graphics/misc/emoticons.png): 머리 위로 톡 튀어나온다.
	if emote_t > 0.0 and _emote != null:
		var pop := minf(1.0, (EMOTE_TIME - emote_t) / 0.12)
		var es := 16.0 * s
		draw_texture_rect(_emote, Rect2(Vector2(-es / 2.0, dst.position.y + _head * s - es * pop + 2.0), Vector2(es, es)), false)

# Shared by the flat and 3D renderers; facing/step state remains unchanged.
func throw_pose() -> int:
	if throw_time < 0.0 or throw_time >= 0.44 or face != "down" or not THROW_SHEETS.has(sprite_id): return -1
	var index := 0
	while index+1 < THROW_TIMES.size() and throw_time >= float(THROW_TIMES[index+1]): index += 1
	return index

func throw_hand(releasing := false) -> Vector2:
	var pose := throw_pose()
	if pose >= 0: return Vector2(THROW_HANDS[sprite_id][5 if releasing else pose])+Vector2(0.5,-1)
	var side := 0.8 if face=="right" else 0.20
	return Vector2(frame_size.x*side,frame_size.y-9.0)

func throw_hand_world(releasing := false) -> Vector2:
	var width := 32.0 if throw_pose() >= 0 else frame_size.x
	return position + Vector2.DOWN*Arena.TILE/2.0 + (throw_hand(releasing)-Vector2(width/2.0,frame_size.y))*Arena.MAP_SCALE

func visual_frame() -> Dictionary:
	var pose := throw_pose()
	if pose >= 0: return {"tex":THROW_SHEETS[sprite_id],"src":Rect2(32*pose,0,32,32)}
	var frame: int = FACE_FRAME.get(face, 0)
	if walking() and _tex != null and _tex.get_width() >= 9 * frame_size.x:
		var wf: Array = WALK_FRAMES[face]
		var step := int(_walk_t * 6.0) % 2
		return SmoothSprite.horizontal(_tex, frame_size, wf[step], wf[1-step], fposmod(_walk_t * 6.0, 1.0))
	return {"tex": _tex, "src": Rect2(Vector2(frame * frame_size.x, 0), frame_size)}
