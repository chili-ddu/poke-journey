extends "res://tools/forest_rescue_review.gd"
const Pikachu=preload("res://scripts/story/pikachu_rescue.gd")
const FOLLOW_OUT="res://docs/pikachu_follow/"
var checks: Array=[]

class Walker:
	extends RefCounted
	var target: Vector2
	func move_dir(w):
		var delta: Vector2=target-w.player.position
		return delta.normalized()*minf(1.0,delta.length()/(w.player.move_speed()/60.0))
	func aim_point(_w):return target
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func shot(name: String) -> void:
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(FOLLOW_OUT+name+".png")

func review_route(event) -> PackedVector2Array:
	var start:=Arena.tile_of(game.world.player.position)
	var best: PackedVector2Array=[]
	var best_turns:=0
	for y in int(Arena.map.height):
		for x in int(Arena.map.width):
			var to:=Vector2i(x,y)
			if event.pathfinder.is_point_solid(to):continue
			var path: PackedVector2Array=event.pathfinder.get_point_path(start,to)
			if path.size()<12 or path.size()>28:continue
			var warps:=false
			for i in range(1,path.size()):
				if not Arena.warp_at(path[i]).is_empty():warps=true;break
			if warps:continue
			var turns:=0
			for i in range(1,path.size()-1):
				if (path[i]-path[i-1]).normalized()!=(path[i+1]-path[i]).normalized():turns+=1
			if turns>best_turns:best=path;best_turns=turns
			if best_turns>=3:return best
	return best

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLLOW_OUT))
	SaveData.path="user://save_pikachu_follow_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	Game.bot_events=[Pikachu.FRIEND];Game.arena_trip={};Game.carry={};Game.destination={}
	for place in Pikachu.CAVES:
		await open_place(place);finish_talk()
		game.ui_root.visible=false
		game.world.player.repel_steps=999999
		var event=game.pikachu_rescue
		var walker:=Walker.new();game.world.player.controller=walker
		var route:=review_route(event)
		assert(route.size()>=12,"Native route found")
		var max_gap:=0.0
		var ticks:=0
		for index in route.size():
			walker.target=route[index]
			for _i in 600:
				var feet: Vector2=game.world.player.position+Vector2(0,game.world.player.feet_offset())
				if game.world.player.position.distance_to(walker.target)<0.1:break
				game.advance(DT);ticks+=1
				assert(current_scene==game and DungeonDB.current==place)
				feet=game.world.player.position+Vector2(0,game.world.player.feet_offset())
				var helper_feet: Vector2=event.helper.position+Vector2(0,event.helper.feet_offset())
				max_gap=maxf(max_gap,helper_feet.distance_to(feet))
				assert(max_gap<=Arena.TILE+0.01,"Pikachu stays within one tile during actual input movement")
				assert(Arena.resolve(helper_feet,event.helper.radius).distance_to(helper_feet)<0.1)
				await process_frame
			if game.world.player.position.distance_to(walker.target)>=0.1:
				print("Waypoint blocked: ",place," index=",index," goal=",walker.target," body=",game.world.player.position," feet_offset=",game.world.player.feet_offset()," state=",game.state," radius=",game.world.player.radius)
				quit(1);return
			if index in [3,route.size()/2 as int,route.size()-1]:await shot(place+"_"+str(index))
		for _i in 30:game.advance(DT);await process_frame
		var parked: Vector2=event.helper.position
		for _i in 30:game.advance(DT);await process_frame
		assert(event.helper.position.distance_to(parked)<0.01,"No jitter after stopping")
		checks.append({"place":place,"waypoints":route.size(),"movement_frames":ticks,"max_gap_tiles":max_gap/Arena.TILE,"wall_collision":false,"stopped_without_jitter":true})
	FileAccess.open(FOLLOW_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("Pikachu follow: real input through both native cave floors passed: ",checks)
	game.free();await process_frame;SaveData.clear();quit()
