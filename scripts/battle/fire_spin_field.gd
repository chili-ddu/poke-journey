extends Zone
const BattleContact = preload("res://scripts/battle/battle_contact.gd")

var feet_offset := 0.0 # Keep the floor anchor fixed even if the caster faints.
var direction := Vector2.RIGHT
var remaining := 0.0
var flight_age := 0.0
var landed := false
var pulses := 0
var turns := 4
var attempted := {}
var ground_targeted := false
var target_point := Vector2.ZERO
var initial_applied := false

func step(dt: float) -> void:
	if dead: return
	var world=get_parent()
	if not landed:
		if remaining<.0001:landed=true
		var distance:=minf(remaining,220.0*dt)
		while distance>.0001 and not landed:
			var stride:=minf(2.0,distance)
			var dest:=position+direction*stride
			if Arena.blocks(dest,2):
				landed=true
				break
			var target: Mon=null if ground_targeted else BattleContact.first_contact(world,position,dest,team,2.0,attempted)
			if target!=null:
				attempted[target.get_instance_id()]=true
				if world.apply_hit(target,hit,position) and world.last_damage>0:
					position=target.position
					landed=true
			if not landed: position=dest
			flight_age+=stride/220.0
			remaining-=stride
			distance-=stride
			dt=maxf(0,dt-stride/220.0)
			if remaining<.0001: landed=true
		if not landed: return
	if ground_targeted and not initial_applied:
		initial_applied=true
		# Ground selection is locked at release; all opponents in that footprint
		# receive one normal initial hit before the unchanged residual pulses.
		for foe: Mon in world.opponents(team):
			if foe.dead or not foe.visible or foe.appear<1.0:continue
			if foe.position.distance_to(position)<=radius+foe.radius*.5:world.apply_hit(foe,hit,position)
	age+=dt
	while pulses<turns and age+.00001>=(pulses+1)*Mon.TURN:
		pulses+=1
		for foe: Mon in world.opponents(team):
			if foe.dead or foe.protect_t>0 or foe.invuln_t>0: continue
			if foe.position.distance_to(position)>radius+foe.radius*.5: continue
			var amount:=foe.residual()
			if world.god and foe==world.player: continue
			world.damage(foe,amount)
			world.float_text(foe.position+Vector2.UP*foe.radius,str(amount),Color("ffb884"),8)
	dead=pulses>=turns
