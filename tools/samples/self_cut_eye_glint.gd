# Preview-only sequencing; the game's field_friends.gd is unchanged.
extends "res://scripts/story/field_friends.gd"

const EYE_PREPARE=0.38
const EYE_DELAY=0.08
const EYES={"charmander":[Vector2(12,13),Vector2(20,13)],"bulbasaur":[Vector2(12,21),Vector2(18.5,21)]}
var preparing:=false
var pending_tree: Npc
var original_screen_facing: Variant
var preparation_time:=0.0
var flashes:=0

func _self_cut(tree: Npc) -> bool:
	if not is_instance_valid(tree) or not tree.can_talk(game.world.player.position):return false
	pending_tree=tree;preparing=true;preparation_time=0.0;eye_glinted=false
	var p: Player=game.world.player
	original_screen_facing=p.get_meta("screen_facing") if p.has_meta("screen_facing") else null
	p.set_meta("screen_facing",true);p.facing=Vector2.DOWN;p.vel=Vector2.ZERO
	p.attack_anim_t=0.0;p.attack_contact_hold=0.0;p._anim_name="Idle";p._anim_start=p.anim_t
	game.world.field_water.cancel(game.world,false)
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	focus=p.position;phase="self_cut";cut=false;game.state="field_cut"
	return true

func _flash_eyes() -> void:
	eye_glinted=true;flashes+=1
	var p: Player=game.world.player
	var anim: Dictionary=p._sprites["Idle"]
	var anchor:=MonSprite.anchor_of(p._sprites,anim)
	var points: Array=EYES[p.species_id]
	var center:=Vector2.ZERO
	for point: Vector2 in points:
		var offset: Vector2=(point-anchor)*p.sprite_scale+Vector2(0,p.radius*Mon.GROUND_RATIO)
		center+=offset*0.5
		var sparkle: Fx=game.world.add_fx("sprite",p.position+offset,{"text":"g4_spark","follow":p,"offset":offset,"body_impact":true,
			"size":5.0,"lifetime":0.2,"grow":0.35,"fade_in":0.035,"fade_out":0.7,"color":Color("fff9cb")})
		sparkle.set_meta("field_eye_glint",true)
	game.world.add_fx("sprite",p.position+center,{"text":"g4_streak","follow":p,"offset":center,"body_impact":true,
		"size":1.5,"stretch":6.0,"rot":PI/2.0,"lifetime":0.16,"grow":1.1,"fade_out":0.75,"color":Color.WHITE})
	Sfx.play("pinpon",1.35,-12.0)

func step(dt: float) -> void:
	if not preparing:
		super.step(dt);return
	preparation_time+=dt;game.world.step_fx(dt);game.world.player.anim_t+=dt
	game.world.player.vel=Vector2.ZERO
	if not eye_glinted and preparation_time>=EYE_DELAY:_flash_eyes()
	if preparation_time>=EYE_PREPARE:
		preparing=false
		var p: Player=game.world.player
		if original_screen_facing==null:p.remove_meta("screen_facing")
		else:p.set_meta("screen_facing",original_screen_facing)
		game.state="fight"
		assert(super._self_cut(pending_tree))
