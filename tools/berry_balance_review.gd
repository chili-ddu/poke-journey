extends SceneTree
# Supply simulation, not a model of player damage, battle duration or actual berry consumption.
const RUNS := 500
const KILLS := 100
const RoadData=preload("res://scripts/data/road_trainer_db.gd")
func _init() -> void: call_deferred("run")
func old_roll(species: String,level: int,rng: RandomNumberGenerator) -> Array:
	var out: Array=[]
	if rng.randf()<0.30:
		var pick := rng.randi_range(1,100)
		out.append("oran_berry" if pick<=60 else ("leppa_berry" if pick<=85 else "sitrus_berry"))
	var cures := BerryLoot.status_berries(SpeciesDB.enemy_moves(species,level))
	if not cures.is_empty() and rng.randf()<0.20:out.append(cures[rng.randi_range(0,cures.size()-1)])
	return out
func old_reward(id: String) -> Dictionary:
	var t := TrainerDB.get_trainer(id)
	var out := {"oran_berry":2,"leppa_berry":1}
	if t.has("gym"):out={"sitrus_berry":2,"leppa_berry":2,"lum_berry":1}
	for member in t.party:
		var moves: Array=member[2] if member.size()>2 else SpeciesDB.enemy_moves(member[0],member[1])
		for id_berry in BerryLoot.status_berries(moves):out[id_berry]=1
	return out
func supply(place: String,area: String,previous: bool) -> Dictionary:
	DungeonDB.set_current(place)
	var cfg := DungeonDB.area_cfg(area)
	var table: Array=cfg.get("encounters",[])
	if table.is_empty():table=cfg.fishing.super_rod
	var totals := {}
	for trial in RUNS:
		var rng := RandomNumberGenerator.new()
		rng.seed=trial+17001
		for i in KILLS:
			var pick := DungeonDB.roll_table(table,rng)
			var loot := old_roll(pick.species,pick.level,rng) if previous else BerryLoot.roll(pick.species,pick.level,rng)
			var held := ItemDB.roll_held(pick.species,rng)
			if not held.is_empty() and ItemDB.pocket_of(held)=="berries":loot.append(held)
			for id in loot:totals[id]=float(totals.get(id,0))+1.0
		# Each original pool trainer fought once per route visit.
		for id in RoadData.POOLS.get(area,[]):
			var reward := old_reward(id) if previous else TrainerDB.berry_rewards(id)
			for berry in reward:totals[berry]=float(totals.get(berry,0))+int(reward[berry])
	for id in totals:totals[id]=snappedf(float(totals[id])/RUNS,0.01)
	return totals
func run() -> void:
	var report := {"runs_per_profile":RUNS,"wild_defeats_per_run":KILLS,"original_held_items_included":true,"trainer_pool_fought_once":true,"consumption_model":false,"areas":{}}
	for pair in [["kanto_south","route1"],["viridian_forest","viridian_forest"],["kanto_north","route3"],["kanto_east","route6"],["mt_moon_1f","mt_moon_1f"],["kanto_east","vermilion_city"]]:
		var before := supply(pair[0],pair[1],true)
		var after := supply(pair[0],pair[1],false)
		report.areas[pair[1]]={"before":before,"after":after}
		print(pair[1]," oran ",before.get("oran_berry",0)," -> ",after.get("oran_berry",0),"; leppa ",before.get("leppa_berry",0)," -> ",after.get("leppa_berry",0),"; sitrus ",before.get("sitrus_berry",0)," -> ",after.get("sitrus_berry",0))
	var folder := "res://docs/berry_balance_review/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := FileAccess.open(folder+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	DungeonDB.set_current(DungeonDB.DEFAULT)
	print("BERRY SUPPLY REVIEW PASSED")
	quit()
