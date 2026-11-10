class_name WildActions
extends RefCounted

# Wild Ditto keeps its own HP, level, PID, name and encounter rewards.
# Copied form/stats/moves live on this enemy instance and disappear with it.
static func transform(w,enemy: Enemy,target: Mon) -> bool:
	if enemy.dead or target.dead or not enemy.form_species_id.is_empty() or not target.form_species_id.is_empty():return false
	var moves: Array=target.slots.filter(func(m):return not String(m).is_empty()) if target is Player else (target.cds.keys() if target is Enemy else [])
	moves=moves.filter(func(m):return MoveDB.is_shaped(String(m)) and String(m)!="transform")
	if moves.is_empty():return false
	enemy.form_species_id=target.appearance_id()
	enemy._sprites=target._sprites
	enemy._apply_species_size(SpeciesDB.get_species(enemy.form_species_id))
	for stat in ["atk","def","spa","spd","spe"]:enemy.stats[stat]=target.stats[stat]
	for stat in ["atk_stage","def_stage","spa_stage","spd_stage","spe_stage","acc_stage","eva_stage"]:enemy.set(stat,target.get(stat))
	enemy.cds.clear()
	for move_id in moves:enemy.cds[move_id]=0.6
	enemy.ai="wild"
	enemy.dash.clear();enemy.glide.clear()
	enemy.position=w.resolve_mon(enemy,enemy.position)
	enemy.start_tint(Color("e4b7ff"),0.7,0.5)
	enemy.shine_t=0.4
	return true

static func stance(w,mon: Mon,kind: String) -> void:
	mon.counter_kind=kind
	mon.counter_t=2*Mon.TURN
	mon.shine_t=0.4
	w.add_fx("sprite",mon.position,{"text":"world_counter_1" if kind=="physical" else "world_mirror_coat_1","color":Color("ffb0a6") if kind=="physical" else Color("b8d8ff"),"size":mon.radius*3.0,"grow":1.15,"lifetime":mon.counter_t,"follow":mon,"offset":Vector2(0,-mon.radius*0.3),"fade_in":0.12,"fade_out":0.6})

# Return twice the HP actually lost to one matching-category direct attack.
# The ordinary hit path still handles Protect, type immunity and fainting.
static func reflect(w,target: Mon,hit: Dictionary,lost: int) -> void:
	if target.dead or target.counter_t<=0.0 or lost<=0 or hit.get("counter_return",false):return
	if String(hit.get("cat",""))!=target.counter_kind:return
	var source=hit.get("src")
	if not is_instance_valid(source) or not source is Mon or source.dead or source.team==target.team:return
	var move_id: String="counter" if target.counter_kind=="physical" else "mirror_coat"
	target.counter_t=0.0
	var returned: Dictionary=w.make_hit(target,move_id)
	returned.merge({"fixed":lost*2,"power":0.0,"mult":1.0,"crit":0.0,"knock":0.0,"counter_return":true},true)
	w.apply_hit(source,returned,target.position)

static func hit_fx(w,target: Mon,kind: String,dir: Vector2) -> void:
	var texture: String={"lick":"world_lick_0","mud":"world_mud_slap_0","ice":"world_icy_wind_2","headbutt":"world_headbutt_0"}[kind]
	var tint: Color={"lick":Color("ffacd5"),"mud":Color("b48a60"),"ice":Color("b7edff"),"headbutt":Color("ffe0a0")}[kind]
	var offset:=Vector2(0,-target.radius*0.45)
	w.add_fx("sprite",target.position+offset,{"text":texture,"color":tint,"body_impact":true,"follow":target,"offset":offset,"size":target.radius*2.8,"grow":1.3,"rot":dir.angle()+PI/2 if kind=="lick" else 0.0,"lifetime":0.27,"fade_out":0.7})
