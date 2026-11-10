extends "res://scripts/battle/road_pursuit.gd"

const SIGHT_TILES := 3.0
const SIGHT_HALF_ANGLE := PI / 8.0 # 전체 시야각 45도: 정면에서 좌우 22.5도
const SEARCH_RADIUS := 6
const MAX_SEARCH_STEPS := 12
const LOOK_PAUSE := 0.4
var visited: Array[Vector2i] = []
var pause_t := 0.0
var search_leg := false

func spawn(world: World, view, excluded: Array) -> bool:
	if not super.spawn(world,view,excluded):return false
	actor.set_meta("roaming_trainer",true)
	phase="search"
	path.clear() # Search independently; never follow the hidden player's coordinates.
	return true

func player_cell(world: World) -> Vector2i:
	return Arena.tile_of(world.player.position+Vector2(0,world.player.feet_offset()))

func detects(world: World) -> bool:
	if not is_instance_valid(actor) or phase in ["leaving","engaged"]:return false
	var cell:=player_cell(world)
	if Arena.area_at(world.player.position)!=area:return false
	if Arena.tile_of(actor.position)==cell:return true
	if Arena.is_grass(cell):return false
	var delta:=world.player.position-actor.position
	if delta.length()>SIGHT_TILES*Arena.TILE:return false
	var facing:=Vector2(Npc.DIRS[actor.face])
	return facing.dot(delta.normalized())>=cos(SIGHT_HALF_ANGLE) and reachable_contact(actor.position,world.player.position)

func retire() -> void:
	if phase=="leaving" or not is_instance_valid(actor):return
	phase="leaving"
	path.clear()
	actor.walk_target=Vector2.INF
	pause_t=0.0
	search_leg=false

func choose_search_path(world: World) -> void:
	var start:=Arena.tile_of(actor.position)
	var grass: Array[Vector2i]=[]
	var open: Array[Vector2i]=[]
	var bounds:=Arena.area_rect(area)
	for y in range(maxi(bounds.position.y,start.y-SEARCH_RADIUS),mini(bounds.end.y,start.y+SEARCH_RADIUS+1)):
		for x in range(maxi(bounds.position.x,start.x-SEARCH_RADIUS),mini(bounds.end.x,start.x+SEARCH_RADIUS+1)):
			var cell:=Vector2i(x,y)
			if cell==start or visited.has(cell) or not walkable(cell):continue
			if Arena.is_grass(cell):grass.append(cell)
			else:open.append(cell)
	if grass.is_empty() and open.is_empty():
		visited.clear()
		pause_t=0.5
		return
	# An unreachable patch must not keep the trainer stuck beside reachable open ground.
	for candidates in [grass,open]:
		for attempt in mini(16,candidates.size()):
			var index:=world.rng.randi_range(0,candidates.size()-1)
			var goal: Vector2i=candidates.pop_at(index)
			var proposed:=route(start,goal)
			if not proposed.is_empty() and proposed.size()<=MAX_SEARCH_STEPS:
				path=proposed
				search_leg=true
				return
	path.clear()
	pause_t=0.5

func step(world: World, view, dt: float, _excluded: Array, _allow_spawn: bool) -> Npc:
	if not is_instance_valid(actor):return null
	if phase=="engaged":return null
	if Arena.area_at(world.player.position)!=area or Arena.is_water(Arena.tile_of(world.player.position))!=(terrain==1):retire()
	if phase=="leaving":
		if not visible_at(world,view,actor.position) or actor.position.distance_to(entry)<1.0:
			clear(world)
			return null
		if not actor.walking():
			if path.is_empty():path=route(Arena.tile_of(actor.position),Arena.tile_of(entry))
			walk_next()
		return null
	if detects(world):
		phase="engaged"
		actor.walk_target=Vector2.INF
		actor.face_toward(world.player.position)
		actor.emote_t=Npc.EMOTE_TIME
		return actor
	var cell:=Arena.tile_of(actor.position)
	if not visited.has(cell):
		visited.append(cell)
		if visited.size()>80:visited.pop_front()
	if actor.walking():return null
	if path.is_empty() and search_leg:
		search_leg=false
		pause_t=LOOK_PAUSE
		var turns: Array=["up","right","down","left"]
		var direction: int=turns.find(actor.face)
		actor.face=turns[(direction+(1 if world.rng.randf()<0.5 else 3))%4]
	pause_t=maxf(0.0,pause_t-dt)
	if pause_t>0.0:return null
	if path.is_empty():choose_search_path(world)
	walk_next()
	return null

func walk_next() -> void:
	if path.is_empty():return
	actor.walk_target=Arena.tile_center(path.pop_front())
	actor.face_toward(actor.walk_target)
