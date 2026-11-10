extends SceneTree
const Game=preload("res://scripts/game.gd")
const Johto=preload("res://scripts/data/johto_maps.gd")
const OUT="res://docs/continent_world/"
const Continent=preload("res://scripts/data/continent_world.gd")
const DT=1.0/60.0
var game: Node
var transitions: Array=[]
var walked: Array=[]
var shots: Array=[]
var native:=false
var expected_pp: Array=[]

class Walker:
	extends RefCounted
	var target:=Vector2.ZERO
	var active:=false
	func move_dir(w):
		var d: Vector2=target-w.player.position
		return d.normalized()*minf(1.0,d.length()/4.0) if active and d.length()>0.4 else Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*48
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void: run.call_deferred()

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		FileAccess.open(OUT+"failure.txt",FileAccess.WRITE).store_string(message)
		quit(1)
	return ok

func configure() -> void:
	game.set_process(false);game.bot=true
	game.world.player.controller=Walker.new()
	if game.view3d!=null:game.view3d.set_process(false)
	game.banner_t=0;game.dialog_text="";game.last_small_message=""

func check_streamed_culling(node: Node) -> int:
	var count:=0
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(i)
			if material is BaseMaterial3D:
				check(material.cull_mode==BaseMaterial3D.CULL_BACK,"Cave surfaces retain back culling after collision creation")
				count+=1
	for child in node.get_children():count+=check_streamed_culling(child)
	return count

func render() -> void:
	if game.view3d!=null:game.view3d._process(DT)
	await process_frame

func shot(label: String) -> void:
	if not native:return
	game.view3d._cam_ready=false
	for i in 12:await render()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
	check(root.size==Vector2i(384,216),"Native window stays at minimum 1x size")
	shots.append(label)

func path_to(goal: Vector2i) -> Array:
	var start:=Arena.tile_of(game.world.player.position)
	var queue: Array[Vector2i]=[start];var parents: Dictionary={start:start};var cursor:=0
	while cursor<queue.size() and not parents.has(goal):
		var at: Vector2i=queue[cursor];cursor+=1
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i=at+d
			var ledge:=Arena.ledge_at(next.x,next.y)
			if ledge!=0:
				if Vector2(d)!=Arena.LEDGE_DIRS[ledge]:continue
				if not game.world.plan_hop(Arena.tile_center(at),Vector2(d)).ok:continue
				next=at+d*2
			if parents.has(next) or Arena.terrain_blocked(next,2) or Arena.ledge_at(next.x,next.y)!=0:continue
			if next!=goal and not Arena.warp_at(Arena.tile_center(next)).is_empty():continue
			if Arena.resolve(Arena.tile_center(next),game.world.player.radius,false,2).distance_to(Arena.tile_center(next))>0.1:continue
			parents[next]=at;queue.append(next)
	var result: Array=[]
	if not parents.has(goal):return result
	var at:=goal
	while at!=start:result.push_front(at);at=parents[at]
	return result

func walk(goal: Vector2i, label: String) -> bool:
	if Arena.is_continent() and goal.x>408:goal+=Continent.offset()
	var path:=path_to(goal)
	if not check(not path.is_empty() or Arena.tile_of(game.world.player.position)==goal,"Reachable actual-body path: "+label):return false
	var walker=game.world.player.controller
	var count:=0;var hops:=0;var was_hop:=false;var water:=0
	for tile in path:
		walker.target=Arena.tile_center(tile);walker.active=true
		if Arena.is_water(tile):
			# Use the existing shore-entry action. Setting surf on dry land
			# would immediately be cancelled by normal shoreline handling.
			if not Arena.is_water(Arena.tile_of(game.world.player.position)):
				game.world.player.facing=(walker.target-game.world.player.position).normalized()
				if not check(game.world.field_water.surf(game.world),"Existing Surf enters water in "+label):return false
			else:game.world.player.travel_terrain=2
			water+=1
		for i in 180:
			if game.world.player.position.distance_to(walker.target)<1.0:break
			game.world.step(DT)
			game.world.step_visual(DT)
			var hop: bool=game.world.player.dash.get("hop",false)
			if hop and not was_hop:hops+=1
			was_hop=hop
			count+=1
			if count%12==0:await render()
		if not check(game.world.player.position.distance_to(walker.target)<1.5,"World movement reaches "+str(tile)+" in "+label+" (at "+str(game.world.player.position)+")"):return false
	walker.active=false
	for i in 45:
		game.world.step(DT);game.world.step_visual(DT)
		if i%12==0:await render()
	walked.append({"label":label,"scene":DungeonDB.current,"target":[goal.x,goal.y],"tiles":path.size(),"logic_frames":count,"hops":hops,"water_tiles":water})
	print("Walked ",label,": ",path.size()," tiles / ",hops," hops / ",water," water")
	return true

func warp(index: int, target: String, source: String="") -> bool:
	var here:=DungeonDB.current
	var origin:=source if not source.is_empty() else here
	if here=="kanto_world" and source.is_empty():
		origin=Arena.area_at(game.world.player.position)
	var tile:=Arena.warp_tile(origin,index)
	if not check(Arena.has_warp(origin,index),"Warp exists: "+here+" / "+str(index)):return false
	if not await walk(tile,"door_"+here+"_"+str(index)):return false
	# Walking legitimately regenerates PP. Compare directly across the reload.
	expected_pp=game.world.player.pp.duplicate()
	game.warp_armed=true;game._check_warp()
	if not check(game.state=="warp","Actual door triggers scene travel"):return false
	var old=game
	for i in 240:
		await create_timer(0.01).timeout
		if current_scene!=old:break
	if not check(current_scene!=old,"Actual reload finishes: "+target):return false
	game=current_scene;configure()
	for i in 15:await render()
	if not check(DungeonDB.current==("kanto_world" if Continent.exterior(target) else target),"Correct arrival: "+target):return false
	if native and target=="johto_126":
		if not check(check_streamed_culling(game.view3d.native_renderer)>20,"Native cave material check covers actual streamed terrain"):return false
	if not check(game.world.player.hp==7 and game.world.player.bag.get("oran_berry")==17,"Travel keeps HP/items"):return false
	if not check(game.world.player.pp==expected_pp,"Travel preserves partially consumed PP: expected "+str(expected_pp)+" actual "+str(game.world.player.pp)):return false
	transitions.append({"from":here,"to":target})
	return true

func enter_current_door(target: String) -> bool:
	var tile:=Arena.tile_of(game.world.player.position)
	var wp:=Arena.warp_at(game.world.player.position)
	return await warp(int(wp.index),target,String(wp.map)) if not wp.is_empty() else check(false,"No door at "+str(tile))

func run() -> void:
	await CaptureWindow.park(self)
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	SaveData.path="user://continent_review_only.cfg";SaveData.clear()
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("LANG_CODE","ko")
	Game.skip_opening=true;Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={}
	OS.set_environment("DUNGEON","kanto_world")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	configure();OS.set_environment("DUNGEON","")
	game.world.player.position=Arena.tile_center(Vector2i(8,196))
	game.world.player.hp=7;game.world.player.bag={"oran_berry":17}
	game.world.player.pp[0]=1;expected_pp=game.world.player.pp.duplicate()
	if not await warp(0,"johto_299"):return
	await shot("01_reception_gate")
	if not await warp(0,"johto_030"):return
	await shot("02_route26")
	if not await walk(Vector2i(755,394),"route26_to_falls_east"):return
	if not await warp(1,"johto_126","johto_031"):return
	await shot("03_tohjo_falls_east")
	if not await warp(0,"johto_031"):return
	if not await walk(Vector2i(684,394),"falls_to_new_bark"):return
	if not check(Arena.area_at(game.world.player.position)=="johto_060","Road really reaches New Bark"):return
	await shot("04_new_bark_arrival")
	if not await walk(Vector2i(740,396),"new_bark_to_falls_west"):return
	if not await warp(0,"johto_126"):return
	await shot("05_tohjo_falls_west")
	if not await warp(1,"johto_031"):return
	if not await walk(Vector2i(909,296),"route27_to_route26_gate"):return
	if not await warp(2,"johto_299","johto_030"):return
	if not await warp(1,"kanto_world"):return
	if not check(Arena.area_at(game.world.player.position)=="route23","North gate preserves FRLG Route 23"):return
	await shot("06_route23_return")
	# Return via the northern original FRLG gate, then take the new west branch.
	var north:=Arena.warp_tile("route23",2)
	if not await walk(north,"route23_to_gate"):return
	if not await enter_current_door("johto_299"):return
	if not await warp(3,"johto_032"):return
	await shot("07_route28")
	var silver: Dictionary={}
	for w in Arena.continent_data.warps:
		if int(w.header)==90:silver=w;break
	if not await walk(Vector2i(int(silver.x),int(silver.z)),"route28_to_silver"):return
	if not check(Arena.area_at(game.world.player.position)=="johto_090","West road reaches Mount Silver"):return
	await shot("08_mount_silver")
	if not await walk(Vector2i(887,266),"silver_to_route28_gate"):return
	if not await warp(0,"johto_299"):return
	if not await warp(2,"kanto_world"):return
	if not check(Arena.area_at(game.world.player.position)=="route22","East gate returns to original Route 22"):return
	await shot("09_kanto_return")
	game.bot=false;game._save_here()
	var saved:=SaveData.load_saved()
	if not check(saved.map=="kanto_world","Travel finishes with a valid existing save location"):return
	FileAccess.open(OUT+("native_checks.json" if native else "headless_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"transitions":transitions,"walked":walked,"shots":shots,"hp_preserved":true,"items_preserved":true,"pp_preserved":true,"surf_fixture":true,"isolated_save":SaveData.path,"native_window":[384,216] if native else [],"saved_return":true},"  "))
	game.free();await process_frame;SaveData.clear()
	print("Unified continent review passed: real Kanto/Johto walking, Falls both ways, reception gate four branches, Silver roundtrip, HP/items/save")
	quit()
