extends View3D
# Diagnostic-only CPU timers; GPU draw time is not included in these counters.
var fx_usec := 0
var projectile_usec := 0
func _process(dt: float) -> void:
	fx_usec = 0
	projectile_usec = 0
	super._process(dt)
func _sync_fx(f: Fx, seen: Dictionary) -> void:
	var start := Time.get_ticks_usec()
	super._sync_fx(f,seen)
	fx_usec += Time.get_ticks_usec()-start
func _sync_projectile(p: Projectile, seen: Dictionary) -> void:
	var start := Time.get_ticks_usec()
	super._sync_projectile(p,seen)
	projectile_usec += Time.get_ticks_usec()-start
