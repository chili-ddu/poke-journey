extends World

# Review-only rules for the first four level-up moves.
var focused := false
var crowd_damage := false
var limited_opponents: Array
var limiting_team := -1

func opponents(team: int) -> Array:
	if team == limiting_team:
		return limited_opponents
	return super.opponents(team)

func _melee_arc(mon: Mon, move: Dictionary, hit: Dictionary, direction: Vector2) -> void:
	if focused and not crowd_damage and hit.move == "scratch":
		var best: Mon
		var best_angle := INF
		var best_distance := INF
		for foe: Mon in opponents(mon.team):
			var delta := foe.position - mon.position
			var distance := delta.length()
			var angle := absf(direction.angle_to(delta))
			if distance > mon.radius + foe.radius + float(move.range) or angle > deg_to_rad(55.0):
				continue
			if angle < best_angle or (is_equal_approx(angle, best_angle) and distance < best_distance):
				best_angle = angle
				best_distance = distance
				best = foe
		limited_opponents = [best] if best != null else []
		limiting_team = mon.team
	super._melee_arc(mon, move, hit, direction)
	limiting_team = -1

func _smoke_land_for_team(team: int, stat: Dictionary, land: Vector2, radius: float, player_cast: bool) -> void:
	if focused:
		var best: Mon
		var nearest := INF
		for foe: Mon in opponents(team):
			var distance := land.distance_to(foe.position)
			if distance <= radius + foe.radius * 0.5 and distance < nearest:
				best = foe
				nearest = distance
		limited_opponents = [best] if best != null else []
		limiting_team = team
	super._smoke_land_for_team(team, stat, land, radius, player_cast)
	limiting_team = -1

func cast(mon: Mon, id: String, direction: Vector2, aim: Vector2, opts: Dictionary = {}) -> void:
	var before := bursts.size()
	super.cast(mon, id, direction, aim, opts)
	if focused and id == "ember" and bursts.size() > before:
		bursts.back().hit["sample_forward"] = bursts.back().dir
		if crowd_damage:
			bursts.back().hit["sample_contacts"] = {}

func _spawn_projectile(mon: Mon, hit: Dictionary, move: Dictionary, velocity: Vector2, scale: float = 1.0) -> void:
	if hit.has("sample_forward"):
		velocity = Vector2(hit.sample_forward) * velocity.length()
	super._spawn_projectile(mon, hit, move, velocity, scale)
	if crowd_damage and hit.has("sample_forward"):
		projectiles.back().pierce = true

func apply_hit(target: Mon, hit: Dictionary, from_pos: Vector2) -> bool:
	if hit.has("sample_contacts") and hit.sample_contacts.has(target.get_instance_id()):
		return true
	if not crowd_damage and hit.has("sample_forward") and hit.has("sample_recipient") and hit.sample_recipient != target.get_instance_id():
		return false
	var landed := super.apply_hit(target, hit, from_pos)
	if landed and hit.has("sample_contacts"):
		hit.sample_contacts[target.get_instance_id()] = true
	if landed and not crowd_damage and hit.has("sample_forward"):
		hit.sample_recipient = target.get_instance_id()
	return landed
