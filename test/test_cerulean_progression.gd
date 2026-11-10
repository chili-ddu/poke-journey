extends GutTest
const Game=preload("res://scripts/game.gd")
const Story=preload("res://scripts/data/cerulean_progression.gd")
const Exposure=preload("res://scripts/battle/trainer_exposure.gd")
var old_beaten: Array=[]
func before_each() -> void:old_beaten=Game.bot_beaten.duplicate()
func after_each() -> void:
	Game.bot_beaten=old_beaten
	Game.destination={};Game.arena_trip={};Game.carry={};Game.rival_leaving=""
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())
func game_at(place: String,trainer: String=""):
	var old_bot:=OS.get_environment("BOT");var old_map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.arena_trip={} if trainer=="" else {"trainer":trainer,"arena":place,"back":{"map":"cerulean_city_gym"}}
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	return game
func test_original_cerulean_parties_and_water_gym_resources() -> void:
	assert_eq(Story.TRAINERS.leader_misty.party,[["staryu",18,["tackle","harden","recover","water_pulse"]],["starmie",21,["swift","recover","rapid_spin","water_pulse"]]])
	assert_eq(TrainerDB.for_battle("leader_misty",12).party.map(func(row):return row[0]),["psyduck","horsea","poliwag","staryu"])
	assert_eq(TrainerDB.get_trainer("cerulean_swimmer_luis").party,[["horsea",16],["shellder",16]])
	assert_eq(TrainerDB.get_trainer("cerulean_picnicker_diana").party,[["goldeen",19]])
	for starter in ["charmander","squirtle","bulbasaur"]:
		var rival:=TrainerDB.get_trainer(TrainerDB.cerulean_rival_for(starter))
		assert_eq(rival.party.size(),4)
		assert_eq(rival.party[0][0],"pidgeotto")
		assert_eq(rival.party[0][1],17)
		assert_eq(rival.party[1],["abra",16,["teleport"]])
		assert_eq(rival.party[3][0],TrainerDB.get_trainer(TrainerDB.rival_for(starter)).party[0][0])
	var misty:=TrainerDB.get_trainer("leader_misty")
	assert_true(ResourceLoader.exists("res://assets/npcs/misty.png"))
	assert_true(ResourceLoader.exists("res://assets/ui/"+misty.cutin.mugshot+".png"))
	assert_true(ResourceLoader.exists("res://assets/ui/"+misty.cutin.banner+".png"))
	assert_eq(TrainerDB.battle_music("leader_misty"),"seq_ba_gym")
	assert_true(View3D.supported("res://assets/maps/arena_cerulean_gym"))
func test_northern_rosters_have_renderable_legal_parties() -> void:
	for area in ["route24","route25"]:
		var e=Exposure.new();e.sync_visit(area)
		assert_eq(e.remaining_ids(15).size(),6 if area=="route24" else 9)
		for id in TrainerDB.RoadData.POOLS[area]:
			for member in TrainerDB.get_trainer(id).party:
				var dex:=int(SpeciesDB.get_species(member[0]).dex)
				assert_true(MonSprite.load_set(dex).has("Walk"),member[0])
				assert_true(MonSprite.load_set(dex,true).has("Walk"),member[0]+" shiny")
				assert_false(SpeciesDB.enemy_moves(member[0],member[1]).is_empty(),id)
func walk_path(start: Vector2i,goal: Vector2i) -> bool:
	var q: Array[Vector2i]=[start];var seen={start:true};var cursor:=0
	while cursor<q.size():
		var at:=q[cursor];cursor+=1
		if at==goal:return true
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i=at+d
			if seen.has(next) or Arena.solid_at(next.x,next.y) or Arena.is_water(next):continue
			seen[next]=true;q.append(next)
	return false
func test_city_and_northern_routes_have_reciprocal_walkable_links() -> void:
	var links: Array=[]
	DungeonDB.set_current("kanto_south");Arena.configure(DungeonDB.theme())
	var city:=Arena.area_rect("cerulean_city")
	for x in range(city.position.x,city.end.x):
		var tile:=Vector2i(x,city.position.y)
		var warp:=Arena.warp_at(Arena.tile_center(tile))
		if warp.get("to","")!="route24":continue
		assert_false(Arena.solid_at(tile.x,tile.y))
		assert_true(walk_path(city.position+Vector2i(23,6),tile),"The bridge link is reachable from the rival trigger")
		links.append(warp.to_warp)
	assert_gt(links.size(),0)
	DungeonDB.set_current("cerulean_north");Arena.configure(DungeonDB.theme())
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/cerulean_north/map.json"))
	for warp in native.warps:
		if not warp.get("cerulean_north_link",false):continue
		assert_has(links,warp.index)
		assert_eq(warp.to,"cerulean_city")
		assert_true(walk_path(Vector2i(warp.x,warp.y),Vector2i(11,20)),"City arrival reaches the bridge")
	assert_true(walk_path(Vector2i(11,20),Vector2i(28,5)),"Bridge reaches Route25 without crossing blocked water")
	assert_eq(DungeonDB.WARP_MAPS.route24,"kanto_world")
	assert_eq(DungeonDB.WARP_MAPS.route25,"kanto_world")
func test_cerulean_rival_trigger_is_independent_of_first_battle_victory() -> void:
	var game=game_at("kanto_south")
	game.beaten=[TrainerDB.rival_for(game.starter)]
	var city:=Arena.area_rect("cerulean_city")
	game.world.player.position=Arena.tile_center(city.position+Vector2i(23,6))
	game.state="fight"
	assert_true(game._check_cerulean_rival())
	assert_eq(game.state,"spotted")
	var n: Npc=game.spot.trainer
	assert_eq(n.trainer_id,TrainerDB.cerulean_rival_for(game.starter))
	n.emote_t=0.0;game._step_spotted(0.0)
	n.position=n.walk_target;n.walk_target=Vector2.INF;game._step_spotted(0.0)
	assert_eq(game.state,"talk")
	for i in 20:
		if game.state!="talk":break
		game._talk_next()
	assert_eq(Game.arena_trip.trainer,n.trainer_id)
	assert_eq(Game.arena_trip.arena,"arena_route1")
	game.state="fight";game.beaten.append(n.trainer_id)
	assert_false(game._check_cerulean_rival(),"The city rival is a one-time story encounter")
func test_only_misty_battles_and_victory_records_only_the_leader() -> void:
	var game=game_at("cerulean_city_gym")
	assert_eq(game.trainers.size(),1)
	var misty: Npc
	for n in game.trainers:
		assert_eq(TrainerDB.arena_of(n.trainer_id),"arena_cerulean_gym")
		if n.trainer_id=="leader_misty":misty=n
	assert_not_null(misty)
	assert_true(walk_path(Vector2i(8,17),Vector2i(8,7)),"The leader is reachable from the gym entrance")
	game.world.player.position=Arena.tile_center(Vector2i(8,7));game._talk(misty)
	assert_eq(game.state,"talk")
	var arena=game_at("arena_cerulean_gym","leader_misty")
	arena._trainer_defeated()
	assert_has(arena.beaten,"leader_misty")
	for id in ["cerulean_swimmer_luis","cerulean_picnicker_diana"]:assert_false(arena.beaten.has(id))
func test_recover_and_teleport_have_functional_trainer_battle_effects() -> void:
	var game=game_at("arena_cerulean_gym","leader_misty")
	var w: World=game.world
	var starmie:=w.send_out("starmie",21,["recover"],w.player.position+Vector2.UP*Arena.TILE*3,true)
	starmie.hp=1;w.weather="rain"
	w._self_heal(starmie,MoveDB.get_move("recover"))
	assert_eq(starmie.hp,1+int(starmie.max_hp*0.5),"Recover retains half-HP healing in rain")
	var abra:=w.send_out("abra",16,["teleport"],w.player.position+Vector2.UP*Arena.TILE*2,true)
	var old:=abra.position
	w._teleport_mon(abra,MoveDB.get_move("teleport"))
	assert_gt(abra.position.distance_to(w.player.position),old.distance_to(w.player.position))
	assert_false(Arena.solid_at(Arena.tile_of(abra.position).x,Arena.tile_of(abra.position).y))
	assert_eq(abra.hp,abra.max_hp)
	assert_true(abra.trainer_owned)

func test_new_party_ai_can_complete_recovery_and_teleport_windups() -> void:
	var game=game_at("arena_cerulean_gym","leader_misty")
	var w: World=game.world
	var starmie:=w.send_out("starmie",21,["recover"],w.player.position+Vector2.UP*Arena.TILE*3,true)
	starmie.hp=1;starmie.cds.recover=0.0
	starmie.think(0.01,w)
	assert_gt(starmie.windup_t,0.0)
	starmie.think(0.5,w)
	assert_gt(starmie.hp,1,"Recover finishes its windup instead of restarting every frame")
	var abra:=w.send_out("abra",16,["teleport"],w.player.position+Vector2.UP*Arena.TILE*2,true)
	abra.cds.teleport=0.0
	var before:=abra.position
	abra.think(0.01,w);abra.think(0.5,w)
	assert_gt(abra.position.distance_to(before),0.0)
	for name in ["pidgeotto","machop","slowpoke","staryu","starmie","parasect"]:
		var e:=w.send_out(name,20,[],w.player.position+Vector2.UP*Arena.TILE*3,true)
		assert_eq(e.ai,"wild",name+" uses its own legal moves without hard-coded poison-sting access")
		e.think(2.0,w)

class WeighedTarget:
	extends Mon
	var mass:=1.0
	func weight_kg() -> float:return mass
func test_machop_low_kick_deals_increasing_damage_at_native_weight_thresholds() -> void:
	var game=game_at("arena_cerulean_gym","leader_misty")
	var w: World=game.world
	var target:=WeighedTarget.new()
	target.setup("rattata",50,Mon.TEAM_ENEMY)
	w.add_child(target)
	target.stats.def=100
	target.position=w.player.position+Vector2.UP*Arena.TILE
	var hit:=w.make_hit(w.player,"low_kick")
	hit.level=50;hit.atk=100;hit.crit=0.0;hit.stab=false;hit.mult=1.0
	var previous:=0
	for weight in [9.9,10.0,25.0,50.0,100.0,200.0]:
		target.mass=weight;target.max_hp=10000;target.hp=10000;target.invuln_t=0.0
		w.rng.seed=44
		w.apply_hit(target,hit,w.player.position)
		assert_gt(w.last_damage,previous,"Low Kick power increases at each weight boundary")
		previous=w.last_damage
