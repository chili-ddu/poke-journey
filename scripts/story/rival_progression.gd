extends RefCounted

const Data=preload("res://scripts/data/rival_progression.gd")
const STARTERS={"charmander":"squirtle","squirtle":"bulbasaur","bulbasaur":"charmander"}
var game: Node
var waiting: Npc
var waiting_stage:=""

class Navigation:
	extends "res://scripts/battle/road_pursuit.gd"
	var occupied: Dictionary={}
	func walkable(tile: Vector2i) -> bool:return not occupied.has(tile) and super.walkable(tile)

func setup(owner: Node) -> void:game=owner

static func trainer_id(stage: String,starter: String) -> String:
	return "rival_"+stage+"_"+String(STARTERS.get(SpeciesDB.base_form(starter),"squirtle"))

static func stage_for(id: String) -> Dictionary:
	for stage in Data.STAGES:
		if id.begins_with("rival_"+String(stage.id)+"_"):return stage
	return {}

func owns(id: String) -> bool:return Data.TRAINERS.has(id)

func eligible(stage: Dictionary) -> bool:
	if game.beaten.has(trainer_id(stage.id,_starter())):return false
	match String(stage.rule):
		"before_brock":return not game.beaten.has("leader_brock")
		"all_leaders":
			for cfg in TrainerDB.GymData.GYMS.values():
				if not game.beaten.has(cfg.leader):return false
	return true

func _starter() -> String:return String(game.get_script().starter)

func _region(stage: Dictionary) -> Rect2i:return Arena.area_rect(stage.area)

func _here(stage: Dictionary) -> bool:
	if String(stage.map)!="":return DungeonDB.current==String(stage.map)
	return game.mode=="overworld" and Arena.area_at(game.world.player.position)==String(stage.area)

func _navigation(stage: Dictionary) -> Navigation:
	var nav:=Navigation.new();nav.area=stage.area
	for n in game.world.npcs:
		if is_instance_valid(n) and n!=waiting:nav.occupied[Arena.tile_of(n.position)]=true
	return nav

func _clear_waiting() -> void:
	if is_instance_valid(waiting):
		game.world.npcs.erase(waiting);waiting.visible=false;waiting.queue_free()
	waiting=null;waiting_stage=""

func _sync(stage: Dictionary) -> void:
	if stage.is_empty():_clear_waiting();return
	if is_instance_valid(waiting) and waiting_stage==String(stage.id):return
	_clear_waiting()
	var nav:=_navigation(stage);var bounds:=_region(stage)
	var origin:=bounds.position+Vector2i(int(stage.from[0]),int(stage.from[1]))
	var options: Array[Vector2i]=[origin]
	for radius in range(1,5):
		for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:options.append(origin+offset*radius)
	for tile in options:
		if not bounds.has_point(tile) or not nav.walkable(tile):continue
		if Arena.tile_center(tile).distance_to(game.world.player.position)<Arena.TILE*1.3:continue
		waiting=Npc.new();waiting.setup({"id":"green_"+String(stage.id),"trainer":trainer_id(stage.id,_starter()),"tile":tile,"face":"right"})
		waiting.speed=150.0;game.world.add_child(waiting);game.world.npcs.append(waiting)
		waiting_stage=stage.id;return

func check() -> bool:
	if game.state not in ["fight","town"] or not game.battle.is_empty() or game.world.player.dead or game.world.player.hop_t>0.0:return false
	var active: Dictionary={}
	for stage in Data.STAGES:
		if _here(stage) and eligible(stage):active=stage;break
	_sync(active)
	if active.is_empty() or not is_instance_valid(waiting):return false
	var r: Array=active.rect
	var zone:=Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
	var local:=Arena.tile_of(game.world.player.position)-_region(active).position
	if not zone.has_point(local):return false
	var nav:=_navigation(active);var start:=Arena.tile_of(waiting.position)
	var player_tile:=Arena.tile_of(game.world.player.position)
	nav.occupied[player_tile]=true
	var goals: Array[Vector2i]=[]
	for d in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
		var tile: Vector2i=player_tile+d
		if nav.walkable(tile) and Arena.tile_center(tile).distance_to(game.world.player.position)>=Npc.BODY_R+game.world.player.radius+2.0:goals.append(tile)
	goals.sort_custom(func(a,b):return a.distance_squared_to(start)<b.distance_squared_to(start))
	for goal in goals:
		var route: Array[Vector2i]=nav.route(start,goal)
		if route.is_empty() and start!=goal:continue
		var path: Array=[]
		for cell in route:path.append(Arena.tile_center(cell))
		var actor: Npc=waiting;waiting=null;waiting_stage=""
		actor.emote_t=Npc.EMOTE_TIME
		game.world.player.vel=Vector2.ZERO;game.world.player.emote_t=Npc.EMOTE_TIME
		Sfx.play("pinpon");game.rival={"npc":actor,"path":path,"t":0.0};game.state="rival";game._eye_music(actor)
		return true
	return false

func depart(id: String) -> bool:
	var stage:=stage_for(id)
	if stage.is_empty() or not _here(stage):return false
	_clear_waiting()
	var nav:=_navigation(stage);var bounds:=_region(stage)
	var at:=Arena.tile_of(game.world.player.position)
	nav.occupied[at]=true
	var starts: Array[Vector2i]=[]
	for d in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
		var tile: Vector2i=at+d
		if nav.walkable(tile) and Arena.tile_center(tile).distance_to(game.world.player.position)>=Npc.BODY_R+game.world.player.radius+2.0:starts.append(tile)
	if starts.is_empty():return false
	var start: Vector2i=starts[0]
	# Search only the connected room. A distant room behind a wall is not an exit.
	var queue: Array[Vector2i]=[start];var parents: Dictionary={start:start};var cursor:=0;var goal:=start
	while cursor<queue.size():
		var cell: Vector2i=queue[cursor];cursor+=1
		if cell.distance_squared_to(at)>goal.distance_squared_to(at):goal=cell
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i=cell+d
			if bounds.has_point(next) and not parents.has(next) and nav.walkable(next):
				parents[next]=cell;queue.append(next)
	var path: Array=[];var cell:=goal
	while cell!=start:
		path.push_front(Arena.tile_center(cell));cell=parents[cell]
	var actor:=Npc.new();actor.setup({"id":"green_depart","trainer":id,"tile":start,"face":"up"});actor.speed=150.0
	game.world.add_child(actor);game.world.npcs.append(actor)
	game.rival_exit={"npc":actor,"path":path};game.state="leave"
	return true
