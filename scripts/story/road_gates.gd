extends RefCounted

# Runtime collision only: source maps and the Diglett's Cave doorway stay intact.
const Access=preload("res://scripts/data/road_access.gd")
class GateNpc:
	extends Npc
	func can_talk(at: Vector2) -> bool:
		return at.distance_to(position)<=Arena.TILE*1.6

var game: Node
var construction: Array[Npc]=[]
var bridge_cells: Array[Vector2i]=[]
var snorlax_cells: Array[Vector2i]=[]
var sleeper: Mon
var sleep_talk: Npc

func setup(owner: Node) -> void:
	game=owner
	if game.mode!="overworld":return
	if not game.events.has(Access.SAFFRON_VISITED):_close_bridge()
	if not game.events.has(Access.SNORLAX_AWAKENED):_place_snorlax()
	_recover_northern_save()
	# A legacy save can sit on a newly closed tile. Resolve once after patching.
	game.world.player.position=game.world.resolve_mon(game.world.player,game.world.player.position)

func _recover_northern_save() -> void:
	if bridge_cells.is_empty() or Arena.area_rect("cerulean_city").size==Vector2i.ZERO:return
	if Arena.area_at(game.world.player.position) not in ["route24","route25"]:return
	var bridge:=Arena.area_rect("route24")
	game.world.player.position=Arena.tile_center(Vector2i(bridge.position.x+11,bridge.end.y+2))

func _npc(id: String, tile: Vector2i, sprite: String) -> Npc:
	var actor:=GateNpc.new()
	actor.setup({"id":id,"tile":tile,"sprite":sprite,"talk":"road_gate"})
	actor.set_meta("roaming_trainer",true)
	game.world.add_child(actor);game.world.npcs.append(actor)
	return actor

func _close_bridge() -> void:
	var region:=Arena.area_rect("route24")
	if region.size==Vector2i.ZERO:return
	var y:=region.end.y-1
	for x in range(region.position.x,region.end.x):
		var cell:=Vector2i(x,y)
		# Include water so SURF cannot bypass an unfinished bridge from the side.
		if not Arena.solid_at(x,y):
			var local_x:=x-region.position.x
			var sprite:="worker_m" if local_x in [11,15] else "strength_boulder"
			construction.append(_npc("route24_construction",cell,sprite))
		Arena.set_dynamic_solid(cell,true);bridge_cells.append(cell)

func _place_snorlax() -> void:
	var region:=Arena.area_rect("route11")
	if region.size==Vector2i.ZERO:return
	# Cave door is (6,7). The barrier at x=10 is EAST of its return lane.
	var center:=region.position+Vector2i(10,9)
	for y in range(region.position.y,region.end.y):
		var cell:=Vector2i(center.x,y)
		Arena.set_dynamic_solid(cell,true);snorlax_cells.append(cell)
	sleeper=Mon.new();sleeper.setup("snorlax",30,Mon.TEAM_PLAYER)
	sleeper.sleep_t=INF;sleeper.facing=Vector2.DOWN
	sleeper.position=Arena.tile_center(center)-Vector2(0,sleeper.feet_offset())
	sleeper.set_meta("screen_facing",true)
	game.world.add_child(sleeper);game.world.bystanders.append(sleeper)
	sleep_talk=_npc("route11_snorlax",center,"worker_m")
	sleep_talk.visible=false

func talk(actor: Npc) -> void:
	var lines: Array
	if actor.id=="route11_snorlax":
		lines=["잠만보가 길을 막고 곤히 잠들어 있다.\n말을 걸어도 일어나지 않는다." if Lang.is_ko() else "SNORLAX is fast asleep, blocking the road.\nIt does not wake when called."]
	else:
		lines=["다리를 수리하고 있어 지금은 지나갈 수 없어.\n노랑시티에 다녀올 때쯤이면 끝날 거야!" if Lang.is_ko() else "The bridge is under repair.\nIt should be ready after your visit to SAFFRON CITY!"]
	game._say_pages(lines)

func refresh() -> void:
	if game.events.has(Access.SAFFRON_VISITED):
		for cell in bridge_cells:Arena.set_dynamic_solid(cell,false)
		bridge_cells.clear()
		for actor in construction:
			game.world.npcs.erase(actor);actor.queue_free()
		construction.clear()
	if game.events.has(Access.SNORLAX_AWAKENED):
		for cell in snorlax_cells:Arena.set_dynamic_solid(cell,false)
		snorlax_cells.clear()
		if is_instance_valid(sleeper):
			game.world.bystanders.erase(sleeper);sleeper.queue_free();sleeper=null
		if is_instance_valid(sleep_talk):
			game.world.npcs.erase(sleep_talk);sleep_talk.queue_free();sleep_talk=null

# Reserved for the future wake-up event, never called by visiting Saffron/talking.
func complete_snorlax_event() -> void:
	if not game.events.has(Access.SNORLAX_AWAKENED):
		game.events.append(Access.SNORLAX_AWAKENED)
		if not game.bot:SaveData.store_progress("events",Access.SNORLAX_AWAKENED)
	refresh()
