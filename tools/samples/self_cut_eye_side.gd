# Preview revision: retain the tree-facing pose and mark only visible eyes.
extends "res://tools/samples/self_cut_eye_glint.gd"

const POINTS="res://tools/samples/self_cut_eye_points.json"
var starting_facing:=Vector2.ZERO
var visible_eyes:=0

func _self_cut(tree: Npc) -> bool:
	if not is_instance_valid(tree) or not tree.can_talk(game.world.player.position):return false
	pending_tree=tree;preparing=true;preparation_time=0.0;eye_glinted=false
	var p: Player=game.world.player
	original_screen_facing=p.get_meta("screen_facing") if p.has_meta("screen_facing") else null
	starting_facing=(tree.position-p.position).normalized()
	p.facing=starting_facing;p.vel=Vector2.ZERO
	p.attack_anim_t=0.0;p.attack_contact_hold=0.0;p._anim_name="Idle";p._anim_start=p.anim_t
	game.world.field_water.cancel(game.world,false)
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	focus=p.position;phase="self_cut";cut=false;game.state="field_cut"
	return true

func _flash_eyes() -> void:
	eye_glinted=true;flashes+=1
	var p: Player=game.world.player
	var anim: Dictionary=p._sprites["Idle"]
	var row:=MonSprite.row_for(anim,p.facing)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(POINTS))
	var points: Array=data[p.species_id].rows[row]
	var anchor:=MonSprite.anchor_of(p._sprites,anim)
	var center:=Vector2.ZERO
	visible_eyes=points.size()
	for point: Array in points:
		var pixel:=Vector2(float(point[0]),float(point[1]))
		var offset: Vector2=(pixel-anchor)*p.sprite_scale+Vector2(0,p.radius*Mon.GROUND_RATIO)
		center+=offset/float(points.size())
		var sparkle: Fx=game.world.add_fx("sprite",p.position+offset,{"text":"g4_spark","follow":p,"offset":offset,"body_impact":true,
			"size":4.0,"lifetime":0.18,"grow":0.2,"fade_in":0.035,"fade_out":0.7,"color":Color("fff9cb")})
		sparkle.set_meta("field_eye_glint",true)
	if not points.is_empty():
		game.world.add_fx("sprite",p.position+center,{"text":"g4_streak","follow":p,"offset":center,"body_impact":true,
			"size":0.8,"stretch":4.0,"rot":PI/2.0,"lifetime":0.14,"grow":0.6,"fade_out":0.75,"color":Color.WHITE})
		Sfx.play("pinpon",1.35,-12.0)

func step(dt: float) -> void:
	super.step(dt)
	assert(game.world.player.facing.distance_to(starting_facing)<0.001,"The sample never turns toward the camera")
