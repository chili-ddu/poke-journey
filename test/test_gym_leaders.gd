extends GutTest

const Game=preload("res://scripts/game.gd")
const Data=preload("res://scripts/data/gym_leaders.gd")
const Roads=preload("res://scripts/data/road_trainer_db.gd")

class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func after_each() -> void:
	Game.destination={};Game.arena_trip={};Game.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func open(place: String):
	var bot:=OS.get_environment("BOT");var map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.carry={};Game.arena_trip={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game)
	game.set_process(false);game.world.god=true;game.world.player.controller=Still.new()
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",map)
	return game

func finish_talk(game) -> void:
	for i in 60:
		if game.state!="talk":break
		game._talk_next()

func reachable(game) -> Dictionary:
	var occupied: Dictionary={}
	for n in game.world.npcs:occupied[Arena.tile_of(n.position)]=true
	var start:=Arena.tile_of(game.world.player.position)
	var queue: Array[Vector2i]=[start];var seen: Dictionary={start:true};var cursor:=0
	while cursor<queue.size():
		var cell: Vector2i=queue[cursor];cursor+=1
		var nexts: Array[Vector2i]=[]
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:nexts.append(cell+direction)
		var warp:=Arena.warp_at(Arena.tile_center(cell))
		if not warp.is_empty() and DungeonDB.warp_destination(warp)==DungeonDB.current:
			var target:=Arena.warp_tile(String(warp.to),int(warp.to_warp))
			if target.x>=0:nexts.append(target)
		for tile in nexts:
			if seen.has(tile) or occupied.has(tile) or Arena.solid_at(tile.x,tile.y):continue
			if Arena.resolve(Arena.tile_center(tile),game.world.player.radius).distance_to(Arena.tile_center(tile))>0.1:continue
			seen[tile]=true;queue.append(tile)
	return seen

func test_all_eight_gyms_have_only_one_battle_opponent_and_noncombat_members() -> void:
	assert_eq(Data.GYMS.size(),8);assert_eq(Data.NPC_PARTIES.size(),41)
	var count:=0
	for place in Data.GYMS:
		var cfg: Dictionary=Data.GYMS[place];var game=open(place)
		assert_eq(game.trainers.size(),1);assert_eq(game.trainers[0].trainer_id,cfg.leader)
		assert_false(Roads.POOLS.has(place))
		var walkable:=reachable(game)
		var lead: Npc=game.trainers[0]
		var at:=Arena.tile_center(lead.tile+Vector2i.DOWN)
		assert_true(walkable.has(lead.tile+Vector2i.DOWN),place+" leader is reachable past dialogue-only members")
		game.world.player.position=at;assert_eq(game.npc_in_reach(),lead,place+" nearby members do not steal the leader interaction")
		for n in game.world.npcs:
			if n==lead:continue
			if n.talk not in ["gym_member","gym_surprised"]:continue
			assert_false(n.is_trainer());assert_false(n.sees(n.position+Vector2.DOWN*Arena.TILE))
			assert_true(walkable.has(n.talk_tile),place+" has a reachable conversation: "+n.id)
			if Data.NPC_PARTIES.has(n.id):count+=1
		game.free()
	assert_eq(count,41)

func test_every_member_and_guide_only_talks_and_does_not_change_battle_progress() -> void:
	for place in Data.GYMS:
		var game=open(place)
		var bag: Dictionary=game.world.player.bag.duplicate();var beaten: Array=game.beaten.duplicate()
		for n in game.world.npcs:
			if n.talk not in ["gym_member","gym_surprised"]:continue
			game.world.player.position=Arena.tile_center(n.talk_tile)
			assert_true(n.can_talk(game.world.player.position));assert_eq(game.npc_in_reach(),n,n.id+" can be addressed directly")
			game._check_trainers();assert_eq(game.state,"town")
			game._talk(n);assert_eq(game.state,"talk");finish_talk(game)
			assert_eq(game.state,"town");assert_true(game.battle.is_empty());assert_true(Game.arena_trip.is_empty())
			assert_eq(game.beaten,beaten);assert_eq(game.world.player.bag,bag)
		game.free()

func test_all_leaders_start_a_cutin_and_their_own_indoor_arena() -> void:
	for place in Data.GYMS:
		var cfg: Dictionary=Data.GYMS[place];var game=open(place)
		game.events.append(RoadAccess.SAFFRON_VISITED)
		game.beaten=[];game._talk(game.trainers[0]);finish_talk(game)
		assert_eq(game.state,"encounter");assert_eq(game.encounter.kind,"leader")
		assert_eq(Game.arena_trip.trainer,cfg.leader);assert_eq(Game.arena_trip.arena,cfg.arena)
		assert_eq(Game.arena_trip.back.map,place)
		var tr: Dictionary=TrainerDB.get_trainer(cfg.leader)
		for key in ["mugshot","banner"]:assert_true(ResourceLoader.exists("res://assets/ui/"+String(tr.cutin[key])+".png"))
		assert_true(FileAccess.file_exists("res://assets/maps/"+String(cfg.arena)+"/hd2d_cards.json"))
		game.free()

func test_authored_parties_preserve_native_archive_and_use_full_stats_and_assets() -> void:
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/gym_leaders.json"))
	var game=open("pewter_gym");var count:=0
	for id in Data.TRAINERS:
		var archived: Dictionary=Data.TRAINERS[id];var expected: Dictionary=native.origins[id]
		assert_eq(archived.party.size(),expected.party.size())
		for i in archived.party.size():
			var row: Array=archived.party[i]
			assert_eq(row[0],expected.party[i][0]);assert_eq(int(row[1]),int(expected.party[i][1]))
			assert_eq(row[2],expected.party[i][2]);assert_eq(int(archived.ivs[i]),int(expected.native_ivs[i])*31/255)
		var tr:=TrainerDB.for_battle(id,40)
		assert_eq(tr.party.size(),5 if id=="leader_giovanni" else 4)
		for i in tr.party.size():
			var row: Array=tr.party[i]
			var mon: Enemy=game.world.send_out(row[0],int(row[1]),row[2],Arena.center(),false,int(tr.ivs[i]))
			assert_eq(mon.stats,SpeciesDB.stats_at(row[0],int(row[1]),mon.ivs));assert_eq(mon.max_hp,int(mon.stats.hp));assert_eq(mon.hp,mon.max_hp)
			assert_eq(game.world._damage_mult(mon),1.0)
			assert_true(mon.cds.keys().any(func(move):return MoveDB.power(move)>0.0),id+" has attack moves")
			for move in mon.cds:assert_true(MoveDB.has_move(move));assert_false(String(MoveDB.get_move(move).shape).is_empty())
			var dex:=int(SpeciesDB.get_species(row[0]).dex)
			var motion: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motion_2x/%04d.json"%dex))
			for variant in ["","shiny/"]:
				var dir:="res://assets/sprites/%04d/"%dex+String(variant)
				assert_true(ResourceLoader.exists(dir+"Walk-Anim.png"));assert_true(motion.has(dir+"Walk-Anim.png"))
			assert_true(ResourceLoader.exists("res://assets/audio/cry/"+row[0]+".wav"))
			game.world.enemies.erase(mon);mon.free();count+=1
	assert_eq(count,25)

func test_winning_marks_only_the_leader_and_members_remain_noncombat() -> void:
	for place in Data.GYMS:
		var game=open(place);game.beaten=[]
		game.battle={"trainer":game.trainers[0],"resume":"town"}
		game._trainer_defeated();finish_talk(game)
		assert_eq(game.beaten,[Data.GYMS[place].leader]);assert_true(game.battle.is_empty())
		for n in game.world.npcs:
			if n.talk in ["gym_member","gym_surprised"]:assert_false(n.is_trainer());assert_false(game.beaten.has(n.id))
		game.free()

func test_viridian_stays_open_after_the_existing_gift_event() -> void:
	var game=open("kanto_world")
	if not game.events.has(Game.GIO_EVENT):game.events.append(Game.GIO_EVENT)
	game._lock_doors()
	var found:=0
	for warp in Arena.warps():
		if String(warp.to)==Game.GIO_DOOR:
			found+=1;assert_false(Arena.solid_at(int(warp.x),int(warp.y)),"The existing gift event cannot lock the new leader battle")
	assert_gt(found,0)

func test_every_custom_leader_party_really_executes_its_known_moves() -> void:
	var game=open("arena_pewter_gym");var w: World=game.world
	w.player.setup("raichu",80,Mon.TEAM_PLAYER);w.no_skills=false
	w.player.position=Arena.center();var count:=0
	for id in Data.TRAINERS:
		var tr:=TrainerDB.for_battle(id,40)
		for i in tr.party.size():
			var row: Array=tr.party[i]
			var mon:=w.send_out(row[0],int(row[1]),row[2],w.player.position+Vector2.UP*Arena.TILE*2,false,int(tr.ivs[i]))
			for move in mon.cds:mon.cds[move]=0.0
			var action:=false
			for frame in 300:
				w.step(1.0/60.0)
				if mon.windup_t>0.0 or mon.attack_anim_t>0.0:action=true
			assert_true(action,id+" / "+row[0]+" executes its supplied move list")
			w.enemies.erase(mon);mon.free();w.clear_enemy_projectiles();count+=1
	assert_eq(count,25)

func test_delayed_gym_attacks_handle_the_caster_being_freed() -> void:
	var game=open("arena_pewter_gym");var w: World=game.world
	w.player.position=Arena.center();w.player.invuln_t=0
	for move in ["giga_drain","rock_tomb","seed_bomb"]:
		var mon:=w.send_out("victreebel",29,[move],w.player.position+Vector2.UP*Arena.TILE)
		w.player.invuln_t=0
		w.cast(mon,move,Vector2.DOWN,w.player.position)
		w._step_pending_casts(1.0)
		assert_false(w.pending_calls.is_empty(),move+" has a delayed effect")
		w.enemies.erase(mon);mon.free()
		w._step_pending_calls(1.0)
		assert_true(w.pending_calls.is_empty(),"Delayed effects release a defeated caster safely")
