extends World
# Diagnostic-only subclass. Production code never reads the comparison switch.
var comparison_mode := "optimized"
var collision_usec := 0

func _step_projectiles(dt: float) -> void:
	var started := Time.get_ticks_usec()
	if comparison_mode=="optimized":
		super._step_projectiles(dt)
	else:
		# Before broad-phase optimization: rebuild opponents for every spatial step.
		for p in projectiles:
			if p.dead: continue
			var speed: float = p.vel.length()
			var travel_time := minf(dt,maxf(0.0,p.range_left)/speed) if speed>0.0 else dt
			var steps := maxi(1,ceili(speed*travel_time/clampf(p.radius,1.0,4.0)))
			var attempted := {}
			for i in steps:
				if p.dead: break
				_advance_projectile(p,travel_time/steps,attempted,opponents(p.team),i==0)
	collision_usec = Time.get_ticks_usec()-started
