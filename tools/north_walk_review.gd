extends "res://tools/kanto_expansion_review.gd"
const RoadData = preload("res://scripts/data/road_trainer_db.gd")
var automatic_jumps := 0
# Keep this terrain traversal deterministic: combat is covered separately.
func setup_controller() -> void:
	super.setup_controller()
	game.world.player.repel_steps=1000000
	game.road_pursuit.clear(game.world)
	for id in RoadData.TRAINERS:
		if not game.beaten.has(id):game.beaten.append(id)

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_north_walk_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"north_walk_plan.json"))
	await open_fixture("kanto_north")
	game.world.player.position=Arena.tile_center(Vector2i(int(plan.start[1])+48,int(plan.start[2])))
	walker.target=game.world.player.position
	var index := 0
	for leg in plan.legs:
		assert(DungeonDB.current==leg.place or (leg.place=="kanto_north" and DungeonDB.current=="kanto_south"))
		print("WALK ",leg.place," -> ",leg.goal)
		await walk_to(Vector2i(int(leg.goal[0])+(48 if leg.place=="kanto_north" else 0),int(leg.goal[1])),leg.to!="")
		if leg.to!="":await arrive(leg.to,"north_walk_%02d"%index)
		index+=1
	assert(Arena.area_at(game.world.player.position)=="cerulean_city")
	assert(game.world.player.hop_t<=0,"Final landing completes")
	await shot("north_walk_cerulean_arrival")
	assert(automatic_jumps>0,"Automatic ledges were exercised")
	print("Native path to Cerulean completed through Mt Moon: ",plan.walk_steps," planned steps, ",automatic_jumps," actual automatic ledge jumps")
	FileAccess.open(OUT+"north_walk_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"planned_steps":plan.walk_steps,"actual_automatic_jumps":automatic_jumps,"destination":Arena.area_at(game.world.player.position),"transitions":results},"  "))
	game.queue_free()
	await process_frame
	quit()

func walk_to(goal: Vector2i, warp := false) -> void:
	var start := Arena.tile_of(game.world.player.position)
	var queue: Array[Vector2i] = [start]
	var parents := {start:start}
	var cursor := 0
	while cursor<queue.size() and not parents.has(goal):
		var at := queue[cursor];cursor+=1
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var n: Vector2i = at+d
			var ledge := Arena.ledge_at(n.x,n.y)
			if ledge>0:
				if Arena.LEDGE_DIRS[ledge]!=Vector2(d):continue
				n=at+d*2
			if parents.has(n) or Arena.solid_at(n.x,n.y) or Arena.ledge_at(n.x,n.y)>0:continue
			var center := Arena.tile_center(n)
			if center.distance_to(Arena.resolve(center,game.world.player.radius))>0.1:continue
			if n!=goal and not Arena.warp_at(center).is_empty():continue
			parents[n]=at;queue.append(n)
	assert(parents.has(goal),"Walkable route exists to "+str(goal))
	var path: Array[Vector2i] = []
	var cell := goal
	while cell!=start:path.push_front(cell);cell=parents[cell]
	for tile in path:
		walker.target=Arena.tile_center(tile)
		for i in 240:
			var was_hopping: bool = game.world.player.hop_t>0
			game.advance(1.0/60)
			if not was_hopping and game.world.player.hop_t>0:automatic_jumps+=1
			if game.state=="warp":
				assert(warp and tile==goal,"Only planned warp triggers")
				return
			if game.world.player.position.distance_to(walker.target)<=0.8 and game.world.player.hop_t<=0:break
			if i%4==0:await process_frame
		assert(game.world.player.position.distance_to(walker.target)<=0.8,"Walk/land at "+str(tile))
	assert(not warp,"Door must trigger")
