class_name FieldWater
extends RefCounted

const RODS := ["old_rod","good_rod","super_rod"]
var fishing := {}
var wake_t := 0.0

func target(w) -> Vector2i:
	var origin := Arena.tile_of(w.player.position)
	var facing: Vector2=w.player.facing
	var delta := Vector2i(int(signf(facing.x)),0) if absf(facing.x)>absf(facing.y) else Vector2i(0,int(signf(facing.y)))
	if delta==Vector2i.ZERO: delta=Vector2i.DOWN
	var tile := origin+delta
	if Arena.is_water(tile) and Arena.area_at(Arena.tile_center(tile))==Arena.area_at(w.player.position): return tile
	return Vector2i(-1,-1)

func can_use(w) -> bool:
	return DungeonDB.is_overworld() and not w.player.dead and (Arena.is_water(Arena.tile_of(w.player.position)) or target(w)!=Vector2i(-1,-1))

func surf(w) -> bool:
	if not can_use(w): return false
	var tile := target(w)
	if Arena.is_water(Arena.tile_of(w.player.position)): return false
	if tile==Vector2i(-1,-1): return false
	var pos := Arena.tile_center(tile)
	if Arena.resolve(pos,w.player.radius,false,2).distance_to(pos)>0.1: return false
	cancel(w,false)
	w.player.dash.clear()
	w.player.glide.clear()
	w.player.travel_terrain=2
	w.player.position=pos
	w.player.vel=Vector2.ZERO
	w.status_message.emit(Lang.t("field_surf_start"))
	return true

func start_fishing(w,rod: String) -> bool:
	if not RODS.has(rod) or not can_use(w) or w.remaining()>0: return false
	var tile := target(w)
	if tile==Vector2i(-1,-1) and Arena.is_water(Arena.tile_of(w.player.position)): tile=Arena.tile_of(w.player.position)
	if tile==Vector2i(-1,-1): return false
	var cfg := DungeonDB.area_cfg(Arena.area_at(Arena.tile_center(tile)))
	if cfg.get("fishing",{}).get(rod,[]).is_empty(): return false
	fishing={"rod":rod,"tile":tile,"at":w.player.position,"hp":w.player.hp,"time":0.0,"wait":w.rng.randf_range(1.4,2.4)}
	w.player.vel=Vector2.ZERO
	w.player.play_attack("Shoot",0.0,false)
	w.player.dash.clear()
	w.player.glide.clear()
	if w.player.controller is Controllers.Human: w.player.controller.has_target=false
	w.status_message.emit(Lang.t("field_cast"))
	w.add_fx("sprite",Arena.tile_center(tile),{"text":"g4_bubble_blue","size":5.0,"lifetime":2.6,"color":Color("fff0d0")})
	return true

func cancel(w,notice: bool=true) -> void:
	if fishing.is_empty(): return
	fishing.clear()
	if notice: w.status_message.emit(Lang.t("field_fish_cancel"))

func step(w,dt: float) -> void:
	if not fishing.is_empty():
		if w.player.dead or w.player.hp<int(fishing.hp) or w.player.position.distance_to(fishing.at)>2.0 or w.remaining()>0:
			cancel(w)
		else:
			var c=w.player.controller
			var interrupted: bool=c.move_dir(w).length_squared()>0.01
			for slot in Player.SLOT_COUNT:
				if c.want_skill(slot,w): interrupted=true
			if interrupted:
				cancel(w)
			else:
				fishing.time+=dt
				if fishing.time>=fishing.wait:
					var cfg := DungeonDB.area_cfg(Arena.area_at(w.player.position))
					var table: Array=cfg.get("fishing",{}).get(fishing.rod,[])
					var tile: Vector2i=fishing.tile
					fishing.clear()
					if w.rng.randf()<0.7 and not table.is_empty():
						var pick := DungeonDB.roll_table(table,w.rng)
						var pos := Arena.tile_center(tile)
						var radius := float(SpeciesDB.get_species(pick.species).radius)
						if Arena.resolve(pos,radius,false,1).distance_to(pos)<0.1:
							w.pending_spawns.append({"species":pick.species,"level":w.wild_level(Arena.area_at(pos),int(pick.level)),"pos":pos,"t":0.3,"wild_area":Arena.area_at(pos),"terrain":1,"fished":true})
							w.status_message.emit(Lang.t("field_bite"))
						else: w.status_message.emit(Lang.t("field_no_bite"))
					else: w.status_message.emit(Lang.t("field_no_bite"))
	wake_t-=dt
	if Arena.is_water(Arena.tile_of(w.player.position)) and w.player.travel_terrain==2 and wake_t<=0.0:
		wake_t=0.3
		w.add_fx("sprite",w.player.position,{"text":"g4_ring_q","water_surface":true,"size":w.player.radius*2.0,"grow":1.7,"lifetime":0.6,"color":Color(0.7,0.95,1.0,0.5)})
