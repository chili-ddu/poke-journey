extends World
## Review only. Keep the accepted live moves and other moves' dictionaries untouched.
func configure(id: String) -> void:
	var m:=MoveDB.get_move(id)
	if id=="water_gun":
		m.pierce=true
		m.spread_deg=0.0
		m.vary=false
	elif id=="icy_wind":
		m.count=7
		m.spread_deg=54.0
		m.pierce=true

func make_hit(mon: Mon,id: String) -> Dictionary:
	var hit:=super.make_hit(mon,id)
	if id in ["icy_wind","water_gun"]: hit["shape_contacts"]={}
	return hit

func apply_hit(target: Mon,hit: Dictionary,from: Vector2) -> bool:
	if not hit.has("shape_contacts"): return super.apply_hit(target,hit,from)
	var key:=target.get_instance_id()
	if hit.shape_contacts.has(key): return true
	var connected:=super.apply_hit(target,hit,from)
	if connected: hit.shape_contacts[key]=true
	return connected
