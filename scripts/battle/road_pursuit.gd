extends RefCounted
const Data = preload("res://scripts/data/road_trainer_db.gd")
const CATCH_DISTANCE := 1.5 * Arena.TILE
const GIVE_UP_DISTANCE := 12.0 * Arena.TILE
const REPATH_SECONDS := 0.35
var actor: Npc
var area := ""
var terrain := 0 # 0: land trainers, 1: swimmers; never cross the shoreline.
var phase := "idle"
var cooldown := 0.0
static var battle_cooldown := 0.0
const ATTENTION_MAX := 100.0
const MOVE_ATTENTION := 6.0
const DEFEAT_ATTENTION := 18.0
const QUIET_DELAY := 4.0
const QUIET_DECAY := 1.0
const CALM_RATE := 1.0/240.0
const ALERT_RATE := 1.0/30.0
var attention := 0.0
var attention_area := ""
var quiet_t := 0.0
var noise_gate := 0.0
var lost_t := 0.0
var repath_t := 0.0
var entry := Vector2.ZERO
var path: Array[Vector2i] = []

func clear(world: World) -> void:
	if is_instance_valid(actor):
		world.npcs.erase(actor)
		actor.queue_free()
	actor = null
	phase = "idle"
	path.clear()
	cooldown = 0.0
	attention = 0.0
	quiet_t = 0.0
	noise_gate = 0.0

# Shared across map changes so a doorway cannot reset post-battle protection.
static func begin_battle_cooldown(rng: RandomNumberGenerator) -> void:
	battle_cooldown = rng.randf_range(90.0,150.0)

static func tick_battle_cooldown(dt: float) -> void:
	battle_cooldown = maxf(0.0,battle_cooldown-maxf(0.0,dt))

# Activity affects encounter probability, never a mandatory distance counter.
func notice(region: String, amount: float, is_move: bool = false) -> void:
	if not Data.POOLS.has(region) or is_instance_valid(actor): return
	if region!=attention_area:
		attention_area=region
		attention=0.0
		noise_gate=0.0
	if is_move and noise_gate>0.0: return
	if is_move: noise_gate=1.5
	attention=minf(ATTENTION_MAX,attention+maxf(0.0,amount))
	quiet_t=0.0

func tick_attention(dt: float, region: String) -> void:
	if region!=attention_area:
		attention_area=region
		attention=0.0
		quiet_t=0.0
		noise_gate=0.0
	noise_gate=maxf(0.0,noise_gate-dt)
	var before:=quiet_t
	quiet_t+=dt
	var quiet_dt:=maxf(0.0,quiet_t-QUIET_DELAY)-maxf(0.0,before-QUIET_DELAY)
	attention=maxf(0.0,attention-quiet_dt*QUIET_DECAY)

func spawn_probability(dt: float) -> float:
	var rate:=lerpf(CALM_RATE,ALERT_RATE,attention/ATTENTION_MAX)
	return 1.0-exp(-rate*maxf(0.0,dt))

func visible_at(world: World, view, pos: Vector2) -> bool:
	if view != null and view.visible:
		var point: Vector3 = view.to3d(pos,0.8)
		return not view.cam.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(view.vp.size)).grow(32).has_point(view.cam.unproject_position(point))
	var size := world.get_viewport_rect().size / world.cam.zoom
	return Rect2(world.cam.get_screen_center_position()-size*0.5,size).grow(32).has_point(pos)

func walkable(tile: Vector2i) -> bool:
	var pos := Arena.tile_center(tile)
	return not Arena.terrain_blocked(tile,terrain) and Arena.warp_at(pos).is_empty() and Arena.ledge_at(tile.x,tile.y)==0 and pos.distance_to(Arena.resolve(pos,Npc.BODY_R,false,terrain))<0.01

func route(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var bounds := Arena.area_rect(area)
	var frontier: Array[Vector2i] = [start]
	var parents := {start:start}
	var cursor := 0
	while cursor<frontier.size() and not parents.has(goal):
		var cell := frontier[cursor]
		cursor += 1
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i = cell+direction
			if not bounds.has_point(next) or parents.has(next) or not walkable(next): continue
			parents[next] = cell
			frontier.append(next)
	var result: Array[Vector2i] = []
	if not parents.has(goal): return result
	var cell := goal
	while cell!=start:
		result.push_front(cell)
		cell = parents[cell]
	return result

func reachable_contact(from: Vector2, to: Vector2) -> bool:
	for i in 9:
		if not walkable(Arena.tile_of(from.lerp(to,i/8.0))): return false
	return true

func spawn(world: World, view, excluded: Array) -> bool:
	area = Arena.area_at(world.player.position)
	terrain = 1 if Arena.is_water(Arena.tile_of(world.player.position)) else 0
	var pool: Array = Data.POOLS.get(area,[]).filter(func(id): return not excluded.has(id) and int(TrainerDB.get_trainer(id).get("terrain",0))==terrain)
	if pool.is_empty(): return false
	var at := Arena.tile_of(world.player.position)
	var candidates: Array[Vector2i] = []
	for y in range(at.y-18,at.y+19):
		for x in range(at.x-18,at.x+19):
			var tile := Vector2i(x,y)
			if not Arena.area_rect(area).has_point(tile) or not walkable(tile): continue
			var pos := Arena.tile_center(tile)
			if pos.distance_to(world.player.position)<6*Arena.TILE or visible_at(world,view,pos): continue
			candidates.append(tile)
	candidates.shuffle()
	for tile in candidates.slice(0,80):
		path = route(tile,at)
		if path.is_empty(): continue
		var id: String = pool[world.rng.randi_range(0,pool.size()-1)]
		actor = Npc.new()
		actor.setup({"id":id,"trainer":id,"tile":tile,"face":"down"})
		actor.speed = 72.0
		world.add_child(actor)
		world.npcs.append(actor)
		entry = actor.position
		phase = "approach"
		lost_t = 0.0
		repath_t = 0.0
		return true
	return false

# Returns the trainer only when pursuit actually reaches the player.
func step(world: World, view, dt: float, excluded: Array, allow_spawn: bool) -> Npc:
	var pos := world.player.position
	tick_attention(dt,Arena.area_at(pos))
	if not is_instance_valid(actor):
		actor = null
		cooldown = maxf(0.0,cooldown-dt)
		if allow_spawn and cooldown<=0.0 and battle_cooldown<=0.0 and Data.POOLS.has(attention_area) and world.rng.randf()<spawn_probability(dt):
			if not spawn(world,view,excluded): cooldown = 15.0
		return null
	if phase == "engaged": return null
	if phase=="approach" and visible_at(world,view,actor.position): phase="chase"
	if Arena.area_at(pos)!=area or (phase=="chase" and actor.position.distance_to(pos)>GIVE_UP_DISTANCE):
		lost_t += dt
	else: lost_t = 0.0
	if lost_t>=2.0: phase = "leaving"
	if phase=="leaving" and not visible_at(world,view,actor.position):
		clear(world)
		return null
	if phase=="chase" and actor.position.distance_to(pos)<=CATCH_DISTANCE and Arena.area_at(pos)==area:
		if reachable_contact(actor.position,pos):
			actor.walk_target = Vector2.INF
			actor.face_toward(pos)
			phase = "engaged"
			return actor
	repath_t -= dt
	if repath_t<=0.0:
		repath_t = REPATH_SECONDS
		path = route(Arena.tile_of(actor.position),Arena.tile_of(entry if phase=="leaving" else pos))
	if not actor.walking() and not path.is_empty():
		actor.walk_target = Arena.tile_center(path.pop_front())
		actor.face_toward(actor.walk_target)
	return null
