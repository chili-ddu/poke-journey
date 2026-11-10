extends "res://scripts/battle/road_pursuit.gd"
const Driver = preload("res://scripts/battle/trainer_search.gd")
const RETREAT_BELOW := 30.0
const ROAD_GAIN := 2.0 # 야외: 기술 없이 50초 노출되면 게이지 100.
const CAVE_GAIN := 3.0 # 동굴: 약 34초 노출되면 게이지 100.
const GRASS_GAIN := 2.0
const HIDE_LOSS := 7.0
const HIDE_DELAY := 1.5
const LEVEL_GAP := 10
var visit_area := ""
var deployed: Array = []
var pursuits: Array = []
var retry_t := 0.0
var previous_position := Vector2.INF

func eligible(id: String, player_level: int) -> bool:
	var highest := 0
	for member in TrainerDB.get_trainer(id).party: highest=maxi(highest,int(member[1]))
	return highest>0 and player_level<highest+LEVEL_GAP

func sync_visit(region: String) -> void:
	if region==visit_area:return
	visit_area=region
	deployed.clear()
	attention=0.0
	noise_gate=0.0
	quiet_t=0.0
	retry_t=0.0
	previous_position=Vector2.INF
	for driver in pursuits:
		if is_instance_valid(driver.actor): driver.retire()

func notice(region: String, amount: float, is_move: bool = false) -> void:
	sync_visit(region)
	if not Data.POOLS.has(region):return
	if is_move and noise_gate>0.0:return
	if is_move:noise_gate=1.5
	attention=minf(ATTENTION_MAX,attention+maxf(0.0,amount))
	quiet_t=0.0

func searching() -> bool:
	for driver in pursuits:
		if is_instance_valid(driver.actor) and driver.area==visit_area and driver.terrain==terrain and driver.phase not in ["leaving","engaged"]:return true
	return false

func gauge_phase() -> String:
	if searching():return "hiding" if quiet_t>=HIDE_DELAY else "search"
	for driver in pursuits:
		if is_instance_valid(driver.actor) and driver.area==visit_area and driver.phase=="leaving":return "retreat"
	return "hiding" if quiet_t>=HIDE_DELAY and attention>0.0 else "idle"

func advance_gauge(dt: float, in_grass: bool, moving: bool) -> void:
	noise_gate=maxf(0.0,noise_gate-dt)
	if not in_grass or moving:
		quiet_t=0.0
		if not in_grass:
			var gain := CAVE_GAIN if DungeonDB.area_cfg(visit_area).get("encounter_terrain", "grass") == "cave" else ROAD_GAIN
			attention=ATTENTION_MAX if searching() else minf(ATTENTION_MAX,attention+gain*dt)
		return
	var before:=quiet_t
	quiet_t+=dt
	var hidden_time:=maxf(0.0,quiet_t-HIDE_DELAY)-maxf(0.0,before-HIDE_DELAY)
	attention=maxf(0.0,attention-HIDE_LOSS*hidden_time)

func remaining_ids(player_level: int) -> Array:
	var result: Array=[]
	for id in Data.POOLS.get(visit_area,[]):
		if deployed.has(id) or not eligible(id,player_level):continue
		if int(TrainerDB.get_trainer(id).get("terrain",0))!=terrain:continue
		var active:=false
		for driver in pursuits:
			if is_instance_valid(driver.actor) and driver.actor.trainer_id==id:active=true
		if is_instance_valid(actor) and actor.trainer_id==id:active=true
		if not active:result.append(id)
	return result

func step(world: World, view, dt: float, _beaten: Array, allow_spawn: bool) -> Npc:
	sync_visit(Arena.area_at(world.player.position))
	var current_terrain:=1 if Arena.is_water(Arena.tile_of(world.player.position)) else 0
	if terrain!=current_terrain:
		terrain=current_terrain;attention=0.0;quiet_t=0.0;retry_t=0.0
		for driver in pursuits:
			if driver.terrain!=terrain:driver.retire()
	var pos:=world.player.position
	var moving:=previous_position!=Vector2.INF and pos.distance_to(previous_position)>0.01
	previous_position=pos
	var grass:=Arena.is_grass(Arena.tile_of(pos+Vector2(0,world.player.feet_offset())))
	var available:=remaining_ids(world.player.level)
	if not available.is_empty() or searching():advance_gauge(dt,grass,moving)
	else:attention=0.0
	retry_t=maxf(0.0,retry_t-dt)
	if searching() and attention<RETREAT_BELOW:
		for driver in pursuits:
			if driver.area==visit_area:driver.retire()
	if allow_spawn and not searching() and attention>=ATTENTION_MAX and retry_t<=0.0 and not available.is_empty():
		var excluded: Array=[]
		for id in Data.POOLS.get(visit_area,[]):
			if not available.has(id):excluded.append(id)
		var driver=Driver.new()
		if driver.spawn(world,view,excluded):
			pursuits.append(driver)
			deployed.append(driver.actor.trainer_id)
		else:retry_t=2.0
	# Manual diagnostic spawns on the base driver are also supported.
	if is_instance_valid(actor):
		var caught: Npc=super.step(world,view,dt,[],false)
		if caught!=null:return caught
	for driver in pursuits.duplicate():
		if not is_instance_valid(driver.actor):
			pursuits.erase(driver)
			continue
		var caught: Npc=driver.step(world,view,dt,[],false)
		if caught!=null:return caught
	return null

func snapshot() -> Dictionary:
	var records: Array=[]
	for driver in pursuits:
		if is_instance_valid(driver.actor):
			records.append({"id":driver.actor.trainer_id,"position":[driver.actor.position.x,driver.actor.position.y],"entry":[driver.entry.x,driver.entry.y],"phase":driver.phase,"area":driver.area})
	return {"area":visit_area,"terrain":terrain,"deployed":deployed.duplicate(),"gauge":attention,"actors":records}

func restore_visit(world: World, saved: Dictionary) -> void:
	var region:=Arena.area_at(world.player.position)
	if String(saved.get("area",""))!=region:return
	visit_area=region
	terrain=1 if Arena.is_water(Arena.tile_of(world.player.position)) else 0
	deployed=saved.get("deployed",[]).duplicate()
	attention=clampf(float(saved.get("gauge",0.0)),0.0,ATTENTION_MAX)
	for record in saved.get("actors",[]):
		var id:=String(record.id)
		if not Data.TRAINERS.has(id) or not eligible(id,world.player.level):continue
		var driver=Driver.new()
		driver.area=String(record.area)
		driver.terrain=int(TrainerDB.get_trainer(id).get("terrain",0))
		driver.phase=String(record.phase)
		if driver.phase=="engaged":continue
		driver.entry=Vector2(record.entry[0],record.entry[1])
		driver.actor=Npc.new()
		driver.actor.set_meta("roaming_trainer",true)
		driver.actor.setup({"id":id,"trainer":id,"tile":Arena.tile_of(Vector2(record.position[0],record.position[1])),"face":"down"})
		driver.actor.position=Vector2(record.position[0],record.position[1])
		driver.actor.speed=72.0
		world.add_child(driver.actor)
		world.npcs.append(driver.actor)
		pursuits.append(driver)

func gauge_visible(player_level: int) -> bool:
	for id in Data.POOLS.get(visit_area,[]):
		if eligible(id,player_level) and int(TrainerDB.get_trainer(id).get("terrain",0))==terrain:return true
	return false
