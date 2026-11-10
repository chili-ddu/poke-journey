extends World
## Review-only. Both normal hit detection and expiry still run before a clash.
var cancel_shots:=true
# When supplied, these are already-determined damage values for a cast in this fixture.
var cast_damage: Dictionary={}
var skill_power: Dictionary={}
var matchup_at_clash:=false
var linear_size:=false
var outcome: Dictionary={}

func _init() -> void:
	combat_clashes = false

func width_ratio(power_ratio: float) -> float:
	return power_ratio if linear_size else sqrt(power_ratio)

var landed: Array[Dictionary]=[]

func apply_hit(target: Mon,hit: Dictionary,from: Vector2) -> bool:
	var before:=target.hp
	var connected:=super.apply_hit(target,hit,from)
	if hit.has("original_power") and target.hp<before:
		landed.append({"power":hit.power,"hp_lost":before-target.hp,"fixed":hit.fixed,
			"type_mult":TypeChart.effectiveness(hit.type,target.types())})
	return connected

func make_hit(mon: Mon,move_id: String) -> Dictionary:
	var hit:=super.make_hit(mon,move_id)
	if cast_damage.has(move_id):
		hit["remaining_damage"]=int(cast_damage[move_id])
		hit["fixed"]=hit.remaining_damage
	if skill_power.has(move_id):
		hit.power=float(skill_power[move_id])
		hit["original_power"]=hit.power
	return hit

func consume(packet: Dictionary,amount: int) -> void:
	packet.remaining_damage-=amount
	packet.fixed=packet.remaining_damage
	if packet.remaining_damage>0: return
	cancel_packet(packet)

func cancel_packet(packet: Dictionary) -> void:
	# The whole cast shares one hit dictionary, including bursts still in flight or queued.
	for shot: Projectile in projectiles:
		if is_same(shot.hit,packet): shot.dead=true
	bursts=bursts.filter(func(b):return not is_same(b.hit,packet))

# The winner keeps its remaining base power; the advantage only changes how much
# of it must be spent, never the strength sent into the ordinary damage formula.
func match_power(a: Dictionary,b: Dictionary) -> void:
	var a_rate:=1.0
	var b_rate:=1.0
	if matchup_at_clash:
		a_rate=maxf(1.0,TypeChart.effectiveness(a.type,[b.type]))
		b_rate=maxf(1.0,TypeChart.effectiveness(b.type,[a.type]))
	var difference:=float(a.power)*a_rate-float(b.power)*b_rate
	update_power(a,maxf(0.0,difference/a_rate))
	update_power(b,maxf(0.0,-difference/b_rate))

func update_power(packet: Dictionary,remaining: float) -> void:
	var previous:=float(packet.power)
	packet.power=remaining
	outcome[packet.move]=remaining
	if remaining<=0:
		cancel_packet(packet)
		return
	for p: Projectile in projectiles:
		if not p.dead and is_same(p.hit,packet):
			p.radius*=width_ratio(remaining/previous)

func _spawn_projectile(mon: Mon,hit: Dictionary,m: Dictionary,v: Vector2,scale: float=1.0) -> void:
	if hit.has("original_power"):
		scale*=width_ratio(float(hit.power)/float(hit.original_power))
	super._spawn_projectile(mon,hit,m,v,scale)

var contacts: Array[Vector2]=[]
var incoming: Array[Dictionary]=[]
signal quenched(at: Vector2)

func collision_time(a: Projectile,b: Projectile,dt: float) -> float:
	var gap:=a.position-b.position
	var speed:=a.vel-b.vel
	var radius:=a.hit_radius()+b.hit_radius()
	var outside:=gap.length_squared()-radius*radius
	if outside<=0: return 0.0
	var closing:=gap.dot(speed)
	if closing>=0.0: return INF
	var square:=closing*closing-speed.length_squared()*outside
	if square<0: return INF
	var t:=outside/(-closing+sqrt(square))
	if t>dt or t*a.vel.length()>a.range_left or t*b.vel.length()>b.range_left: return INF
	return t

func _step_projectiles(dt: float) -> void:
	if not cancel_shots:
		super._step_projectiles(dt)
		return
	var left:=dt
	while left>0:
		var earliest:=INF
		var first: Projectile
		var second: Projectile
		for i in projectiles.size():
			var a: Projectile=projectiles[i]
			if a.dead: continue
			for j in range(i+1,projectiles.size()):
				var b: Projectile=projectiles[j]
				if b.dead or a.team==b.team: continue
				var t:=collision_time(a,b,left)
				if t<earliest:
					earliest=t
					first=a
					second=b
		if first==null:
			super._step_projectiles(left)
			return
		if earliest>0:
			super._step_projectiles(earliest)
			left-=earliest
		if first.dead or second.dead: continue
		var at:=first.position.move_toward(second.position,first.hit_radius())
		if first.hit.has("original_power") and second.hit.has("original_power"):
			match_power(first.hit,second.hit)
		elif first.hit.has("remaining_damage") and second.hit.has("remaining_damage"):
			var spent:=mini(first.hit.remaining_damage,second.hit.remaining_damage)
			consume(first.hit,spent)
			consume(second.hit,spent)
		else:
			first.dead=true
			second.dead=true
		incoming=[{"type":first.hit.type,"dir":first.vel.normalized(),"broken":first.dead},
			{"type":second.hit.type,"dir":second.vel.normalized(),"broken":second.dead}]
		contacts.append(at)
		quenched.emit(at)
