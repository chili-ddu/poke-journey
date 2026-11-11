extends World
## Preview-only three-way targeting. Casting, animation and damage stay in World/Enemy.

var elapsed := 0.0
var casts := {}
var damage_pairs := {}

class AiContext:
	extends RefCounted
	var player: Mon
	var world: World
	var rng: RandomNumberGenerator:
		get: return world.rng
	func cast(actor: Mon, move: String, direction: Vector2, at: Vector2) -> void:
		world.cast(actor, move, direction, at)
	func full_paralysis(actor: Mon) -> bool:
		return world.full_paralysis(actor)

class SparringEnemy:
	extends Enemy
	var context: AiContext
	var choose_t := 0.0
	var choice := 0
	func think(dt: float, world) -> void:
		var others: Array = world.opponents(team)
		if others.is_empty():
			vel = Vector2.ZERO
			return
		choose_t -= dt
		if context.player == null or not is_instance_valid(context.player) or context.player.dead or choose_t <= 0.0:
			context.player = others[posmod(choice + team, others.size())]
			choice += 1
			choose_t = 2.8
		super.think(dt, context)

class SparringInput:
	extends Controllers.Bot
	func _nearest(world) -> Mon:
		var others: Array = world.opponents(Mon.TEAM_PLAYER)
		return null if others.is_empty() else others[posmod(int(world.elapsed / 2.8), others.size())]
	func want_item(_world) -> bool: return false
	func want_dodge(_world) -> bool: return false
	func want_skill(index: int, world) -> bool:
		return world.elapsed >= 1.2 and super.want_skill(index, world)

func opponents(team: int) -> Array:
	var result: Array = []
	for actor: Mon in [player] + enemies:
		if is_instance_valid(actor) and not actor.dead and actor.team != team:
			result.append(actor)
	return result

func step(dt: float) -> void:
	elapsed += dt
	super.step(dt)

func cast(actor: Mon, move: String, direction: Vector2, at: Vector2, opts: Dictionary = {}) -> void:
	var key := actor.species_id + ":" + move
	casts[key] = int(casts.get(key, 0)) + 1
	super.cast(actor, move, direction, at, opts)

func apply_hit(target: Mon, hit: Dictionary, from_pos: Vector2) -> bool:
	var before := target.hp
	var result := super.apply_hit(target, hit, from_pos)
	if target.hp < before:
		var key := str(hit.team) + ">" + str(target.team)
		damage_pairs[key] = int(damage_pairs.get(key, 0)) + before - target.hp
	return result

func add_starter(species: String, team: int, moves: Array, at: Vector2) -> Enemy:
	var actor := SparringEnemy.new()
	actor.setup_trainer_mon(species, 12, moves, rng)
	actor.team = team
	actor.position = at
	actor.context = AiContext.new()
	actor.context.world = self
	add_child(actor)
	enemies.append(actor)
	return actor
