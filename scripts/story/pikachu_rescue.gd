extends RefCounted

# Legacy filename/flag retained for saves; the Route 10 rescue is retired.
const ID := "route10_pikachu_rescue"
const ARENA := "arena_pikachu_rescue"
const WON := "pikachu_rescue_won"
const PLACE := "kanto_rock_pass"
const FRIEND := "friend_pikachu_flash"
const CAVES := ["rock_tunnel_1f","rock_tunnel_b1f"]
const FOLLOW_GAP := Arena.TILE*0.65
const FOLLOW_LIMIT := float(Arena.TILE)
var game: Node
var helper: Mon
var helper_lamp: PointLight2D
var pathfinder: AStarGrid2D
var dark_layer: CanvasLayer
var veil: ColorRect
var brightness := 0.0
var self_flash:=false

func setup(owner: Node) -> void:game=owner

func arrive() -> void:
	if DungeonDB.current not in CAVES:return
	_build_veil()
	if game.events.has(FRIEND) or game.FieldHMs.can_use(game.world.player,"flash"):
		_join()
		game._say(Lang.t("field_flash_self") if self_flash else ("피카츄가 합류해 동굴을 밝혔다!" if Lang.is_ko() else "PIKACHU joined you and lit the cave!"))

func _build_veil() -> void:
	if veil!=null:return
	dark_layer=CanvasLayer.new();dark_layer.layer=3;game.add_child(dark_layer)
	veil=ColorRect.new()
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/flash_cave.gdshader")
	veil.material=material;dark_layer.add_child(veil)
	update_light()

func _join() -> void:
	if game.FieldHMs.can_use(game.world.player,"flash"):
		if self_flash:return
		if is_instance_valid(helper):
			game.world.bystanders.erase(helper);helper.queue_free();helper=null
		helper_lamp=null;self_flash=true
		var p: Player=game.world.player
		p.set_meta("flash_helper",true);p.play_attack("Charge",0.4,false)
		helper_lamp=PointLight2D.new();helper_lamp.texture=Look.light_texture();helper_lamp.texture_scale=3.25
		helper_lamp.color=Color("fff2b4");helper_lamp.energy=0.0;helper_lamp.range_item_cull_mask=1;p.add_child(helper_lamp)
		Sfx.move("flash")
		return
	if is_instance_valid(helper):return
	var p: Player=game.world.player
	helper=Mon.new();helper.setup("pikachu",15,Mon.TEAM_PLAYER)
	helper.set_meta("flash_helper",true);helper.set_meta("screen_facing",true)
	var feet:=_follow_target(p)
	helper.position=feet-Vector2(0,helper.feet_offset())
	for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.ZERO]:
		var at: Vector2=feet+direction*FOLLOW_GAP
		if Arena.resolve(at,helper.radius).distance_to(at)>0.1:continue
		helper.position=at-Vector2(0,helper.feet_offset());break
	game.world.add_child(helper);game.world.bystanders.append(helper)
	helper_lamp=PointLight2D.new();helper_lamp.texture=Look.light_texture();helper_lamp.texture_scale=3.25
	helper_lamp.color=Color("fff2b4");helper_lamp.energy=0.0;helper_lamp.range_item_cull_mask=1;helper.add_child(helper_lamp)
	pathfinder=AStarGrid2D.new();pathfinder.region=Rect2i(0,0,int(Arena.map.width),int(Arena.map.height))
	pathfinder.cell_size=Vector2.ONE*Arena.TILE;pathfinder.offset=Vector2.ONE*(Arena.TILE/2.0)
	pathfinder.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;pathfinder.update()
	for y in int(Arena.map.height):
		for x in int(Arena.map.width):
			var at:=Arena.tile_center(Vector2i(x,y))
			pathfinder.set_point_solid(Vector2i(x,y),Arena.resolve(at,helper.radius).distance_to(at)>0.1)
	Sfx.cry("pikachu",1.0,-10.0)

func follow(dt: float) -> void:
	if DungeonDB.current in CAVES and not self_flash and game.FieldHMs.can_use(game.world.player,"flash"):_join()
	if self_flash:
		if dt>0.0 and game.state in ["fight","town"] and not game.world.player.dead:brightness=move_toward(brightness,1.0,dt/0.65)
		return
	if not is_instance_valid(helper):return
	if dt<=0.0 or game.state not in ["fight","town"] or game.world.player.dead:
		helper.vel=Vector2.ZERO;return
	brightness=move_toward(brightness,1.0,dt/0.65)
	var player: Player=game.world.player
	var feet:=helper.position+Vector2(0,helper.feet_offset())
	var player_feet:=player.position+Vector2(0,player.feet_offset())
	var to:=_follow_target(player)
	if feet.distance_to(player_feet)<=FOLLOW_GAP and _clear_follow_segment(feet,to):
		helper.vel=Vector2.ZERO;return
	var route:=_follow_route(feet,to)
	var distance:=0.0
	var previous:=feet
	for point in route:
		distance+=previous.distance_to(point);previous=point
	# Include any final offset from the grid center to the player's feet.
	distance+=previous.distance_to(to)+to.distance_to(player_feet)
	var speed:=maxf(110.0,player.vel.length()*1.35)
	# Keep at most one tile of walkable route between us, including during a
	# quick turn or dash. Spend the catch-up distance along the path, not walls.
	var budget:=minf(maxf(0.0,distance-FOLLOW_GAP),maxf(speed*dt,distance-FOLLOW_LIMIT))
	var next:=feet
	var blocked:=false
	for point in route:
		while budget>0.001 and next.distance_to(point)>0.001:
			var step:=minf(budget,minf(helper.radius*0.5,next.distance_to(point)))
			var wanted:=next.move_toward(point,step)
			if Arena.resolve(wanted,helper.radius).distance_to(wanted)>0.1:
				blocked=true;break
			next=wanted;budget-=step
		if blocked or budget<=0.001:break
	helper.vel=(next-feet)/dt
	if helper.vel.length()>0.1:helper.facing=helper.vel.normalized()
	helper.position=next-Vector2(0,helper.feet_offset())

func _follow_target(player: Player) -> Vector2:
	# Sprite feet can extend beyond the player's actual collision circle into
	# a wall. Follow the closest safe point on this side of that wall.
	var feet:=player.position+Vector2(0,player.feet_offset())
	var at:=Arena.resolve(player.position,helper.radius)
	var steps:=maxi(1,ceili(at.distance_to(feet)/(helper.radius*0.5)))
	var origin:=at
	for i in range(1,steps+1):
		var point:=origin.lerp(feet,float(i)/steps)
		if Arena.resolve(point,helper.radius).distance_to(point)>0.1:break
		at=point
	return at

func _clear_follow_segment(from: Vector2,to: Vector2) -> bool:
	var steps:=maxi(1,ceili(from.distance_to(to)/(helper.radius*0.5)))
	for i in range(1,steps+1):
		var point:=from.lerp(to,float(i)/steps)
		if Arena.resolve(point,helper.radius).distance_to(point)>0.1:return false
	return true

func _follow_route(from: Vector2,to: Vector2) -> PackedVector2Array:
	if _clear_follow_segment(from,to):return PackedVector2Array([to])
	var start:=Arena.tile_of(from);var end:=Arena.tile_of(to)
	if not pathfinder.is_in_boundsv(start) or not pathfinder.is_in_boundsv(end):return []
	if pathfinder.is_point_solid(start) or pathfinder.is_point_solid(end):return []
	var path:=pathfinder.get_point_path(start,end)
	# Only skip waypoint centers when the entire shortcut fits Pikachu's body.
	# Replan from the current positions each tick so a turn never uses stale tiles.
	for i in range(path.size()-1,-1,-1):
		if not _clear_follow_segment(from,path[i]):continue
		path=path.slice(i)
		if _clear_follow_segment(path[-1],to):path.append(to)
		return path
	return []

func _screen(mon: Mon) -> Vector2:
	if game.view3d!=null and game.view3d.visible:
		var view: View3D=game.view3d
		var bounds:=view.mon_focus_bounds(mon)
		if bounds.size!=Vector2.ZERO:return bounds.position
		return view.cam.unproject_position(View3D.to3d(mon.position+Vector2(0,mon.feet_offset()),0.4))/Vector2(view.vp.size)
	return (game.world.get_canvas_transform()*_body_center(mon))/game.get_viewport_rect().size

func _body_center(mon: Mon) -> Vector2:
	var frame:=mon.stat_overlay
	return mon.position+(frame.xform*frame.dst.get_center() if frame!=null and frame.tex!=null else Vector2.ZERO)

func update_light() -> void:
	if veil==null:return
	veil.size=game.get_viewport_rect().size
	var material: ShaderMaterial=veil.material
	material.set_shader_parameter("aspect_ratio",veil.size.x/maxf(1.0,veil.size.y))
	material.set_shader_parameter("player_center",_screen(game.world.player))
	var source: Mon=game.world.player if self_flash else helper
	material.set_shader_parameter("helper_center",_screen(source) if is_instance_valid(source) else Vector2(-10,-10))
	material.set_shader_parameter("helper_strength",brightness)
	if is_instance_valid(helper_lamp):
		helper_lamp.position=_body_center(source)-source.position
		helper_lamp.energy=0.3*brightness
