extends RefCounted
## Shared cast assistance. Never changes movement, stats or live projectiles.

const PATH := "res://assets/data/aim_assist.json"
const SHAPES := ["arc", "projectile", "burst", "beam", "cone", "drain", "status_cone", "dash"]
static var _defaults: Dictionary = {}
var settings: Dictionary
var _target: WeakRef

func _init() -> void:
	if _defaults.is_empty(): _defaults = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	settings = _defaults.duplicate()

func clear() -> void:
	_target = null

## Charged area skills preserve manual distance while sharing direction assistance.
static func is_area_move(move: Dictionary) -> bool:
	return String(move.get("targeting", "")) == "charged_area"

func resolve(world, move_id: String, raw_point: Vector2, precise: bool) -> Vector2:
	var move := MoveDB.get_move(move_id)
	if is_area_move(move):return resolve_area(world,world.player,move,raw_point,precise)
	if not SHAPES.has(move.shape):
		clear()
		return raw_point
	return _resolve_direction(world,world.player,move,raw_point,precise)

func _resolve_direction(world, caster: Mon, move: Dictionary, raw_point: Vector2, precise: bool, ground: bool=false) -> Vector2:
	var origin: Vector2 = caster.position
	var raw := raw_point - origin
	if not bool(settings.enabled) or raw.length_squared() < 1.0:
		clear()
		return raw_point
	var cone := deg_to_rad(float(settings.precise_cone_degrees if precise else settings.cone_degrees))
	var limit := deg_to_rad(float(settings.precise_correction_degrees if precise else settings.correction_degrees))
	var held: Mon = _target.get_ref() if _target != null else null
	var best: Mon
	var score := INF
	for actor: Mon in world.opponents(caster.team):
		if not is_instance_valid(actor) or actor.dead or actor.team == caster.team or not actor.visible or actor.appear < 1.0: continue
		var offset := actor.position - origin
		var reach := _area_reach(move) if ground else _reach(move, caster, actor)
		var angle := absf(raw.angle_to(offset))
		if offset.length_squared() < 1.0 or offset.length() > reach or angle > cone: continue
		var candidate := angle / cone + offset.length() / reach * float(settings.distance_weight)
		if actor == held: candidate -= float(settings.sticky_bonus)
		if candidate >= score or not _clear_line(origin, actor.position): continue
		best = actor
		score = candidate
	if best == null:
		clear()
		return raw_point
	_target = weakref(best)
	var lead := Vector2.ZERO
	if ground or String(move.shape) in ["projectile", "burst"]:
		lead = (best.vel * float(settings.lead_seconds)).limit_length(float(settings.lead_cap_pixels))
		if ground and not _clear_line(origin,best.position+lead):lead=Vector2.ZERO
	var correction := clampf(raw.angle_to(best.position + lead - origin), -limit, limit)
	return origin + raw.rotated(correction)

## Only direction is assisted: an enemy three tiles away cannot lengthen a
## one-tile throw. The ordinary cone/angle limits and target scoring also apply.
func resolve_area(world, caster: Mon, move: Dictionary, raw_point: Vector2, precise: bool=false) -> Vector2:
	var origin: Vector2=caster.position
	var bounded:=origin+(raw_point-origin).limit_length(_area_reach(move))
	return _safe_area_point(origin,_resolve_direction(world,caster,move,bounded,precise,true))

func _area_reach(move: Dictionary) -> float:
	return maxf(0.0,minf(float(move.get("range",0.0)),float(settings.range_cap_tiles)*Arena.TILE))

func _safe_area_point(origin: Vector2, point: Vector2) -> Vector2:
	var steps:=maxi(1,ceili(origin.distance_to(point)/float(settings.wall_sample_pixels)))
	var safe:=origin
	for step in range(1,steps+1):
		var next:=origin.lerp(point,float(step)/steps)
		if Arena.blocks(next,0.0):return safe
		safe=next
	return safe

func _reach(move: Dictionary, player: Mon, other: Mon) -> float:
	var reach := float(move.get("distance", 0.0) if move.shape == "dash" else move.get("range", 0.0))
	if move.shape == "arc": reach += float(move.get("glide", move.get("step", 0.0)))
	return minf(float(settings.range_cap_tiles) * Arena.TILE, reach + player.radius + other.radius)

func _clear_line(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / float(settings.wall_sample_pixels)))
	for step in range(1, steps + 1):
		if Arena.blocks(from.lerp(to, float(step) / steps), 0.0): return false
	return true
