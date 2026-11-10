extends RefCounted
## Swept contact of two travelling attacks, including linearly growing projectiles.

const PAUSE := 2.0 / 30.0

static func eligible(p: Projectile) -> bool:
	return not p.dead and float(p.hit.get("power", 0.0)) > 0.0 and int(p.hit.get("fixed", 0)) <= 0 and p.hit.get("cat", "") != "status"

static func held(p: Projectile, now: float) -> bool:
	return float(p.hit.get("clash_resume", 0.0)) > now

static func growth(p: Projectile, speed: float) -> float:
	return p.radius * maxf(0.0, p.grow - 1.0) * speed / p.range_full if p.range_full > 0.0 else 0.0

static func contact_time(a: Projectile, b: Projectile, now: float, horizon: float) -> float:
	var va := Vector2.ZERO if held(a, now) else a.vel
	var vb := Vector2.ZERO if held(b, now) else b.vel
	var va_len := va.length()
	var vb_len := vb.length()
	if va_len > 0.0: horizon = minf(horizon, a.range_left / va_len)
	if vb_len > 0.0: horizon = minf(horizon, b.range_left / vb_len)
	var gap := a.position - b.position
	var radius := a.hit_radius() + b.hit_radius()
	var outside := gap.length_squared() - radius * radius
	if outside <= 0.0: return 0.0
	var velocity := va - vb
	var expansion := growth(a, va_len) + growth(b, vb_len)
	# |gap + velocity*t|² == (radius + expansion*t)².
	var closing := gap.dot(velocity) - radius * expansion
	var square := closing * closing - (velocity.length_squared() - expansion * expansion) * outside
	if square < 0.0: return INF
	var divisor := -closing + sqrt(square)
	if divisor <= 0.0: return INF
	var t := outside / divisor
	return t if t <= horizon else INF

static func swept_bounds(p: Projectile, now: float, horizon: float) -> Rect2:
	var motion := Vector2.ZERO if held(p, now) else (p.vel * horizon).limit_length(p.range_left)
	var envelope := p.hit_radius()
	if p.range_full > 0.0:
		envelope += p.radius * maxf(0.0, p.grow - 1.0) * motion.length() / p.range_full
	return Rect2(p.position, motion).abs().grow(envelope)

static func next_event(projectiles: Array, now: float, end: float) -> Dictionary:
	var players: Array[Projectile] = []
	var enemies: Array[Projectile] = []
	var horizon := end - now
	for p: Projectile in projectiles:
		if not eligible(p): continue
		var resume := float(p.hit.get("clash_resume", 0.0))
		if resume > now: horizon = minf(horizon, resume - now)
		if p.team == Mon.TEAM_PLAYER: players.append(p)
		else: enemies.append(p)
	var pair := {"time": horizon}
	if players.is_empty() or enemies.is_empty(): return pair
	var enemy_bounds: Array[Rect2] = []
	for b in enemies:
		enemy_bounds.append(swept_bounds(b, now, horizon))
	for a in players:
		var bounds := swept_bounds(a, now, horizon)
		for i in enemies.size():
			if not bounds.intersects(enemy_bounds[i], true): continue
			var b := enemies[i]
			var time := contact_time(a, b, now, horizon)
			if time < INF and (not pair.has("a") or time < horizon):
				pair = {"a": a, "b": b, "time": time}
				horizon = time
	return pair
