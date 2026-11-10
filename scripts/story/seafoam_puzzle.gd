extends RefCounted
const Data=preload("res://scripts/data/seafoam_puzzle.gd")
const PUSH_TIME:=0.22
const FALL_TIME:=0.3
const FLOW_SPEED:=6.0*Arena.TILE
class Boulder:
	extends Npc
	var puzzle: RefCounted
	var root: String
	var pushable:=true
	func can_talk(at: Vector2) -> bool:
		if not pushable or puzzle.phase!="idle":return false
		var p: Player=puzzle.game.world.player
		var delta:=tile-Arena.tile_of(at)
		return abs(delta.x)+abs(delta.y)==1 and Vector2(delta).dot(p.facing)>0.7 and at.distance_to(position)<Arena.TILE*1.45
	func visual_frame() -> Dictionary:return {"tex":_tex,"src":Rect2(0,0,16,32)}

var game: Node
var state: Dictionary
var rocks: Array[Npc]=[]
var holes: Dictionary={}
var currents: Dictionary={}
var phase:="idle"
var elapsed:=0.0
var focus:=Vector2.ZERO
var safe_at:=Vector2.ZERO
var moving: Npc
var from:=Vector2.ZERO
var to:=Vector2.ZERO
var player_from:=Vector2.ZERO
var player_to:=Vector2.ZERO
var path: Array[Vector2]=[]
var fall_target: Dictionary={}

func setup(owner: Node) -> void:
	game=owner
	if not game.puzzles.has(Data.ID):game.puzzles[Data.ID]=Data.initial()
	state=game.puzzles[Data.ID]
	for root in Data.data().roots:
		if not state.boulders.has(root):state.boulders[root]=Data.data().roots[root].duplicate(true)
	var floor_data: Dictionary=Data.data().floors[DungeonDB.current]
	for h in floor_data.holes:holes[Data.vec(h.tile)]=h
	for at in floor_data.arrival_only:
		var tile:=Data.vec(at);Arena._warps.erase("%d,%d"%[tile.x,tile.y])
	for c in floor_data.currents:currents[Vector2i(c[0],c[1])]=Vector2i(c[2],c[3])
	_spawn_rocks()
	game.world.player.position=game.world.resolve_mon(game.world.player,game.world.player.position)

func _spawn_rocks() -> void:
	for n in rocks:
		Arena.set_dynamic_solid(n.tile,false);game.world.npcs.erase(n);n.queue_free()
	rocks.clear()
	for root in state.boulders:
		var record: Dictionary=state.boulders[root]
		if record.floor!=DungeonDB.current:continue
		var object: Dictionary=Data.data().objects[record.stage]
		var rock:=Boulder.new();rock.puzzle=self;rock.root=root;rock.pushable=object.pushable
		rock.setup({"id":root,"tile":Data.vec(record.tile),"sprite":"strength_boulder","talk":"seafoam_boulder"})
		rock.set_meta("roaming_trainer",true)
		game.world.add_child(rock);game.world.npcs.append(rock);rocks.append(rock)
		Arena.set_dynamic_solid(rock.tile,true)

func stopped() -> bool:return state.stopped.has(DungeonDB.current)

func push(rock: Npc) -> bool:
	var p: Player=game.world.player
	if phase!="idle" or game.state!="fight" or p.dead or p.travel_terrain!=0 or p.is_dashing() or not game.battle.is_empty():return false
	if not rocks.has(rock) or not rock.can_talk(p.position):return false
	var direction:=rock.tile-Arena.tile_of(p.position)
	var next_tile: Vector2i=rock.tile+direction
	if Arena.terrain_blocked(next_tile) or Arena.ledge_at(next_tile.x,next_tile.y)!=0 or (not holes.has(next_tile) and not Arena.warp_at(Arena.tile_center(next_tile)).is_empty()):
		game._toast("앞이 막혀 있어 밀 수 없다." if Lang.is_ko() else "There is no room to push it.");return false
	var target:=Arena.tile_center(next_tile)
	if not holes.has(next_tile) and Arena.resolve(target,Arena.TILE*0.4).distance_to(target)>0.1:return false
	phase="pushing";elapsed=0.0;moving=rock
	from=rock.position;to=target;safe_at=p.position;player_from=p.position;player_to=Arena.tile_center(rock.tile)
	focus=player_to.lerp(to,0.5)
	Arena.set_dynamic_solid(rock.tile,false);Arena.set_dynamic_solid(next_tile,true)
	rock.tile=next_tile;p.vel=Vector2.ZERO;p.facing=Vector2(direction)
	game.world.field_water.cancel(game.world,false)
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	p.play_attack("Charge",PUSH_TIME,false)
	game.state="seafoam_event";Sfx.move("rock_throw",0.18,-5.0)
	game.world.add_fx("sprite",from,{"text":"g4_dust","size":13.0,"lifetime":PUSH_TIME,"grow":1.4,"color":Color("dceaf0")})
	return true

func step(dt: float) -> void:
	elapsed+=dt;game.world.step_visual(dt)
	if phase=="pushing":
		var k:=smoothstep(0,1,clampf(elapsed/PUSH_TIME,0,1))
		moving.position=from.lerp(to,k);game.world.player.position=player_from.lerp(player_to,k)
		if k>=1:
			state.boulders[moving.root].tile=[moving.tile.x,moving.tile.y]
			if holes.has(moving.tile):phase="rock_fall";elapsed=0.0;Sfx.play("dansa",0.65)
			else:_finish_push()
	elif phase=="rock_fall":
		var k:=clampf(elapsed/FALL_TIME,0,1)
		moving.scale=Vector2.ONE*(1.0-0.8*k);moving.modulate.a=1.0-k
		moving.position=to+Vector2(0,8*k)
		if k>=1:
			var record: Dictionary=state.boulders[moving.root]
			var reveal: String=Data.data().objects[record.stage].reveal
			if Data.data().objects.has(reveal):
				var next_object: Dictionary=Data.data().objects[reveal]
				record.floor=next_object.floor;record.tile=next_object.tile.duplicate();record.stage=reveal
			else:record.floor=""
			Arena.set_dynamic_solid(moving.tile,false);game.world.npcs.erase(moving);rocks.erase(moving);moving.queue_free();moving=null
			_update_stopped();_finish_push()
	elif phase=="player_fall":
		game.world.player.modulate.a=1.0-clampf(elapsed/FALL_TIME,0,1)
		if elapsed>=FALL_TIME:_warp(fall_target.floor,Arena.tile_center(Data.vec(fall_target.arrival)))
	elif phase=="current":
		var left:=FLOW_SPEED*dt
		while left>0.0 and not path.is_empty():
			var distance: float=game.world.player.position.distance_to(path[0])
			if distance<=left:game.world.player.position=path.pop_front();left-=distance
			else:
				game.world.player.facing=(path[0]-game.world.player.position).normalized()
				game.world.player.position=game.world.player.position.move_toward(path[0],left);left=0
		focus=game.world.player.position
		if path.is_empty():
			if DungeonDB.current=="seafoam_islands_b3f":_warp("seafoam_islands_b4f",Arena.tile_center(Vector2i(27,21)))
			else:
				game.world.player.travel_terrain=0 if not Arena.is_water(Arena.tile_of(game.world.player.position)) else 2
				phase="idle";game.state="fight";game._save_here()

func _finish_push() -> void:
	moving=null;phase="idle";game.state="fight"
	game.world.player.attack_anim_t=0.0;game.world.player.vel=Vector2.ZERO
	_persist();game._save_here()

func _update_stopped() -> void:
	for floor in ["seafoam_islands_b3f","seafoam_islands_b4f"]:
		var count:=0
		for record in state.boulders.values():
			if record.floor==floor and not Data.data().objects[record.stage].pushable:count+=1
		if count>=2 and not state.stopped.has(floor):
			state.stopped.append(floor)
			game._toast("아래층의 물살이 잦아들었다!" if Lang.is_ko() else "The current below has calmed!")

func _persist() -> void:
	if game.bot:game.bot_puzzles=game.puzzles.duplicate(true)
	else:SaveData.store_puzzle(Data.ID,state)

func reset_floor() -> void:
	if phase!="idle" or not game.battle.is_empty() or game.world.player.dead:return
	for record in state.boulders.values():
		var object: Dictionary=Data.data().objects[record.stage]
		if object.floor==DungeonDB.current and record.floor in ["",DungeonDB.current] and object.pushable:
			record.floor=DungeonDB.current
			record.tile=Data.data().objects[record.stage].tile.duplicate()
	_spawn_rocks()
	var p: Player=game.world.player
	var origin:=Arena.tile_of(p.position)
	for radius in range(0,6):
		var found:=false
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var at:=Arena.tile_center(origin+Vector2i(x,y))
				if Arena.warp_at(at).is_empty() and Arena.resolve(at,p.radius,false,p.travel_terrain).distance_to(at)<0.1:
					p.position=at;found=true;break
			if found:break
		if found:break
	_persist();game._save_here()
	game._toast("이 층의 바위 배치를 되돌렸다." if Lang.is_ko() else "This floor's boulders were reset.")

func check_fall(warp: Dictionary) -> bool:
	var tile:=Vector2i(int(warp.x),int(warp.y))
	if not holes.has(tile) or phase!="idle":return false
	phase="player_fall";elapsed=0.0;fall_target=holes[tile]
	safe_at=game.world.player.position-Vector2(game.world.player.facing)*Arena.TILE
	focus=game.world.player.position;game.world.player.vel=Vector2.ZERO
	game.state="seafoam_event";Sfx.play("dansa",0.8)
	return true

func check_environment() -> bool:
	var p: Player=game.world.player
	var tile:=Arena.tile_of(p.position)
	if stopped() or phase!="idle" or p.dead or p.travel_terrain!=2 or not currents.has(tile):return false
	var goal:=Vector2i(26,18) if DungeonDB.current=="seafoam_islands_b3f" else (Vector2i(27,18) if tile.x>=24 else Vector2i(12,14))
	var queue: Array[Vector2i]=[tile];var parents: Dictionary={};var seen={tile:true};var cursor:=0
	while cursor<queue.size() and not seen.has(goal):
		var at:=queue[cursor];cursor+=1
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next_tile: Vector2i=at+d
			var inlet: bool=DungeonDB.current=="seafoam_islands_b3f" and next_tile in [Vector2i(23,8),Vector2i(24,8)]
			if seen.has(next_tile) or Arena._dynamic_solid.has(next_tile):continue
			if next_tile!=goal and not Arena.is_water(next_tile) and not currents.has(next_tile) and not inlet:continue
			seen[next_tile]=true;parents[next_tile]=at;queue.append(next_tile)
	if not seen.has(goal):return false
	path.clear();var at:=goal
	while at!=tile:path.push_front(Arena.tile_center(at));at=parents[at]
	if DungeonDB.current=="seafoam_islands_b4f" and tile.x<24:
		path.append(Arena.tile_center(Vector2i(12,13)));path.append(Arena.tile_center(Vector2i(12,12)))
	phase="current";elapsed=0.0;safe_at=p.position;focus=p.position;p.vel=Vector2.ZERO
	p.dash.clear();p.glide.clear();game.world.field_water.cancel(game.world,false)
	game.state="seafoam_event"
	game._toast("거센 물살에 떠밀린다!" if Lang.is_ko() else "The current is too strong!")
	return true

func _warp(place: String,at: Vector2) -> void:
	phase="warp";game.state="warp";game._carry_out()
	game.destination={"map":place,"pos":at,"layout":1}
	var tween:=game.create_tween()
	tween.tween_property(game.fader,"color:a",1.0,0.15)
	tween.tween_callback(func():game.get_tree().reload_current_scene())
