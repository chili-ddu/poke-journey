extends RefCounted

# Route22 rescue. Keep the original event/arena/save IDs for existing saves.
const ID := "forest_scyther_rescue"
const PLACE := "kanto_world"
const AREA := "route22"
const LEGACY_PLACE := "viridian_forest"
const ARENA := "arena_forest_rescue"
const WON := "forest_scyther_battle_won"
const FRIEND := "friend_scyther_cut"
const SCYTHER_TILE := Vector2i(23,6)
const PLAYER_TILE := Vector2i(25,6)
const DISCOVERY := Rect2i(21,4,7,4)
const COUNT := 12
const INTERVAL := 3.0
const GRUNT_LEVEL := 4
const BOSS_LEVEL := 8
const AMBUSH_SPOTS := [Vector2i(27,4),Vector2i(29,4),Vector2i(30,5),Vector2i(29,6),Vector2i(27,6)]
const AMBUSH_ENTRIES := [Vector2i(31,4),Vector2i(32,4),Vector2i(33,5),Vector2i(32,6),Vector2i(30,6)]
var game: Node
var actor: Mon
var target: Npc
var ambushers: Array[Mon] = []
var phase := "idle"
var elapsed := 0.0
var spawned := 0
var grunts_defeated := 0
var boss_spawned := false
var spawn_t := 1.0
var focus := Vector2.ZERO

static func tile(local: Vector2i) -> Vector2i:
	return Arena.area_rect(AREA).position+local

func _unlocked() -> bool:
	return game.events.has("visited_area_saffron_city")

func near_scyther() -> bool:
	return DISCOVERY.has_point(Arena.tile_of(game.world.player.position)-Arena.area_rect(AREA).position) and game.world.player.position.distance_to(Arena.tile_center(tile(SCYTHER_TILE)))<=Arena.TILE*3.0

func setup(owner: Node) -> void:
	game=owner
	# Pending old rewards remain recoverable even if a legacy save lacks the visit.
	if not _unlocked() and not game.events.has(WON) and not game.events.has(FRIEND):return
	if DungeonDB.current in [ARENA,LEGACY_PLACE]:return
	focus=Arena.tile_center(tile(Vector2i(25,6)))
	actor=_bystander("scyther",SCYTHER_TILE)
	target=Npc.new()
	target.setup({"id":ID,"sprite":"bill","talk":ID,"tile":tile(SCYTHER_TILE),"talk_tile":tile(SCYTHER_TILE+Vector2i.RIGHT)})
	target.visible=false
	target.set_meta("roaming_trainer",true)
	game.world.add_child(target);game.world.npcs.append(target)
	if not game.events.has(FRIEND):
		actor.hp=1
		actor.hurt_t=99999.0

func arrive() -> void:
	if DungeonDB.current==ARENA:
		phase="battle"
		game.total_enemies=COUNT+1;game.defeated=0
		game.world.start_battle(Arena.center(),0.0)
		game.world.arena_cam=false
		game._say_pages([Lang.t("rescue_battle_start")],_fight)
	elif DungeonDB.current==LEGACY_PLACE:
		_befriend() # An already-won old forest save keeps its reward without another battle.
	elif game.events.has(WON) and not game.events.has(FRIEND) and near_scyther():
		_aftermath()

func _fight() -> void:
	game.state="fight"
	game.world.no_skills=false
	Bgm.play("seq_ba_train")

func _bystander(species: String, local: Vector2i) -> Mon:
	var mon:=Mon.new()
	mon.setup(species,8,Mon.TEAM_ENEMY)
	mon.position=Arena.tile_center(tile(local))-Vector2(0,mon.feet_offset())
	mon.facing=Vector2(1,1).normalized()
	mon.set_meta("screen_facing",true)
	game.world.add_child(mon);game.world.bystanders.append(mon)
	return mon

func _page(key: String, speaker: Mon) -> Dictionary:
	return {"text":speaker.display_name()+": "+Lang.t(key),"speaker":weakref(speaker)}

func check_discovery() -> bool:
	if actor==null or phase!="idle" or game.events.has(FRIEND) or game.world.player.dead:return false
	if not _unlocked() and not game.events.has(WON):return false
	if not near_scyther():return false
	if game.events.has(WON):_aftermath()
	else:talk()
	return true

func talk() -> void:
	if actor==null or phase!="idle":return
	if not _unlocked() and not game.events.has(WON) and not game.events.has(FRIEND):return
	if game.events.has(FRIEND):
		game._say_pages([_page("rescue_friend_repeat",actor)])
		return
	if game.events.has(WON):_aftermath();return
	game.world.field_water.cancel(game.world,false)
	game.world.scatter_enemies()
	game.world.player.set_meta("screen_facing",true)
	game.world.player.vel=Vector2.ZERO
	game.world.player.facing=(actor.position-game.world.player.position).normalized()
	phase="discovered"
	game._say_pages([_page("rescue_ask",game.world.player),_page("rescue_champion_road",actor),_page("rescue_warning",actor)],_ambush)

func _ambush() -> void:
	for entry in AMBUSH_ENTRIES:ambushers.append(_bystander("mankey",entry))
	for mon in ambushers:mon.facing=Vector2(-1,1).normalized()
	phase="ambush";elapsed=0.0
	game.state="forest_event"
	game.world.hold_cam=true

func step(dt: float) -> void:
	elapsed+=dt
	game.world.step_fx(dt)
	game.world.player.anim_t+=dt
	game.world.player.attack_anim_t=maxf(0.0,game.world.player.attack_anim_t-dt)
	game._set_cam(focus,World.CAM_ZOOM)
	if phase=="ambush":
		for i in ambushers.size():
			var mon:=ambushers[i]
			var end:=Arena.tile_center(tile(AMBUSH_SPOTS[i]))
			end-=Vector2(0,mon.feet_offset())
			mon.vel=(end-mon.position).normalized()*72.0 if mon.position.distance_to(end)>1.0 else Vector2.ZERO
			mon.position=mon.position.move_toward(end,72.0*dt)
		if elapsed>=1.5:
			for mon in ambushers:mon.vel=Vector2.ZERO
			game.world.hold_cam=false
			game._say_pages([_page("rescue_gang_taunt",ambushers[0]),_page("rescue_wrong_way",game.world.player),
				_page("rescue_help",game.world.player),_page("rescue_angry",ambushers[0])],_enter_arena)
	elif phase=="release" and elapsed>=0.8:
		actor.hurt_t=0.0;actor.hp=actor.max_hp
		game.world.hold_cam=false
		game._say_pages([_page("rescue_thanks",actor),_page("rescue_mankey_after",ambushers[0]),
			_page("rescue_promise",actor)],_befriend)

func _enter_arena() -> void:
	var snap: Texture2D=null
	if DisplayServer.get_name()!="headless":
		var img:=game.get_viewport().get_texture().get_image()
		if img!=null and not img.is_empty():snap=ImageTexture.create_from_image(img)
	var layer:=CanvasLayer.new();layer.layer=90;game.add_child(layer)
	game.encounter=EncounterFx.new()
	game.encounter.setup("low",snap,{})
	game.encounter.size=game.get_viewport().get_visible_rect().size
	layer.add_child(game.encounter)
	game.arena_trip={"event":ID,"arena":ARENA,"back":{"map":PLACE,"pos":game.world.player.position,"layout":1,
		"pursuit_visit":game.road_pursuit.snapshot()}}
	game.state="encounter";game.world.player.vel=Vector2.ZERO
	Bgm.play("seq_ba_train")

func step_battle(dt: float) -> void:
	if phase!="battle" or game.world.player.dead:return
	spawn_t-=dt
	if spawned<COUNT and spawn_t<=0.0:
		_queue_enemy("mankey",GRUNT_LEVEL)
		spawned+=1;spawn_t=INTERVAL
	elif spawned==COUNT and grunts_defeated==COUNT and not boss_spawned and game.world.remaining()==0:
		boss_spawned=true
		_queue_enemy("mankey",BOSS_LEVEL)
		game._say(Lang.t("rescue_boss_arrives"))
	elif boss_spawned and game.defeated==COUNT+1 and game.world.remaining()==0:
		phase="won"
		game.world.end_battle();game.world.clear_enemy_projectiles()
		game.world.no_skills=true
		_flag(WON);game._save_here()
		game._say_pages([Lang.t("rescue_battle_won")],game._leave_arena)

func _queue_enemy(species: String, level: int) -> void:
	var best:=Arena.tile_center(Vector2i(5,5))
	var best_distance:=-1.0
	# Pick a visible entry at the square's perimeter, never on the player's body.
	for _i in 12:
		var edge: int=game.world.rng.randi_range(0,3)
		var along: int=game.world.rng.randi_range(5,18)
		var tile: Vector2i=[Vector2i(along,5),Vector2i(18,along),Vector2i(along,18),Vector2i(5,along)][edge]
		var point:=Arena.tile_center(tile)
		var distance:=point.distance_to(game.world.player.position)
		if distance>best_distance:best=point;best_distance=distance
		if distance>=Arena.TILE*5.0 and distance<=Arena.TILE*9.0:best=point;break
	game.world.add_fx("spawn",best,{"lifetime":1.0,"size":8.0,"color":Color("e0efaf")})
	game.world.pending_spawns.append({"species":species,"level":level,"pos":best,"t":0.8,"no_exp":true})

func defeated_enemy(enemy: Enemy) -> void:
	if enemy.species_id=="mankey" and enemy.level==GRUNT_LEVEL:grunts_defeated+=1

func enemies_left() -> int:
	return COUNT-spawned+game.world.remaining()+(0 if boss_spawned else 1)

func boss() -> Enemy:
	for enemy in game.world.enemies:
		if enemy.species_id=="mankey" and enemy.level==BOSS_LEVEL and not enemy.dead:return enemy
	return null

func _aftermath() -> void:
	phase="release";elapsed=0.0
	game.world.player.set_meta("screen_facing",true)
	if game.world.player.position.distance_to(actor.position)>Arena.TILE*5.0:
		game.world.player.position=Arena.tile_center(tile(PLAYER_TILE))
	game.world.player.vel=Vector2.ZERO
	game.world.player.facing=(actor.position-game.world.player.position).normalized()
	ambushers.append(_bystander("mankey",Vector2i(26,6)))
	game.state="forest_event";game.world.hold_cam=true
	game.world.player.play_attack("Charge",0.8,false)

func _befriend() -> void:
	_flag(FRIEND)
	var learned: Array=game.learn_field_hms()
	game.world.player.set_meta("screen_facing",false)
	phase="idle"
	for mon in ambushers:
		game.world.bystanders.erase(mon);mon.queue_free()
	ambushers.clear()
	game.world.no_skills=false
	game.state="fight"
	game._save_here()
	Bgm.fanfare(Bgm.ITEM)
	game._say_pages([Lang.t("rescue_friend_gained")]+learned+[Lang.t("field_cut_self_hint") if game.FieldHMs.can_use(game.world.player,"cut") else Lang.t("rescue_friend_hint")])

func _flag(id: String) -> void:
	if not game.events.has(id):game.events.append(id)
	if not game.bot:SaveData.store_progress("events",id)
