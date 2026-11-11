extends GutTest

class Idle:
	extends RefCounted
	func move_dir(_world):return Vector2.ZERO
	func aim_point(world):return world.player.position+Vector2.RIGHT*96.0
	func want_skill(_slot,_world):return false
	func want_jump(_world):return false
	func want_dodge(_world):return false
	func want_item(_world):return false

func fixture(move: String="smoke_screen") -> World:
	DungeonDB.set_current("test_meadow");Arena.configure(DungeonDB.theme());Arena.obstacles=[]
	var world:=World.new();add_child_autofree(world)
	world.setup(17,"charmander",30,[move],Idle.new())
	world.player.position=Vector2(300,170)
	return world

func enemy(world: World,offset: Vector2,species: String="squirtle") -> Enemy:
	var actor:=Enemy.new();actor.setup_trainer_mon(species,30,["tackle"],world.rng)
	actor.position=world.player.position+offset;actor.frozen=true
	world.add_child(actor);world.enemies.append(actor)
	return actor

func advance(world: World,duration: float) -> void:
	for _frame in ceili(duration*60.0):world.step(1.0/60.0)

func test_smoke_hits_manual_ground_area_without_selecting_closest_enemy() -> void:
	var world:=fixture()
	var closest:=enemy(world,Vector2(-50,0))
	var neighbor:=enemy(world,Vector2(70,24))
	var farther:=enemy(world,Vector2(70,0))
	world.cast(world.player,"smoke_screen",Vector2.RIGHT,farther.position)
	advance(world,1.0)
	assert_eq(closest.acc_stage,0)
	assert_eq(neighbor.acc_stage,-1)
	assert_eq(farther.acc_stage,-1,"Manual throw distance determines the area center")

func test_sleep_powder_applies_at_selected_circle_not_forward_cone() -> void:
	var world:=fixture("sleep_powder")
	var closest:=enemy(world,Vector2(-40,0))
	var neighbor:=enemy(world,Vector2(-40,18))
	var outside:=enemy(world,Vector2(40,0))
	world.cast(world.player,"sleep_powder",Vector2.LEFT,closest.position)
	assert_eq(closest.sleep_t,0.0,"Status begins with the visible powder release")
	advance(world,.5)
	assert_gt(closest.sleep_t,0.0);assert_gt(neighbor.sleep_t,0.0)
	assert_eq(outside.sleep_t,0.0)

func test_poison_powder_keeps_unlock_immunity_and_protect_rules() -> void:
	var world:=fixture("poison_powder")
	var closest:=enemy(world,Vector2(-40,0))
	var immune:=enemy(world,Vector2(-40,18),"bulbasaur")
	var protected:=enemy(world,Vector2(-40,-18));protected.protect_t=2.0
	var old:=Mon.poison_unlocked;Mon.poison_unlocked=true
	world.cast(world.player,"poison_powder",Vector2.LEFT,closest.position)
	advance(world,.5)
	assert_gt(closest.poison_t,0.0);assert_eq(immune.poison_t,0.0);assert_eq(protected.poison_t,0.0)
	Mon.poison_unlocked=old

func test_rock_throw_is_one_falling_area_hit_with_normal_stats_and_no_speed_debuff() -> void:
	var world:=fixture("rock_throw")
	var closest:=enemy(world,Vector2(-50,0))
	var neighbor:=enemy(world,Vector2(-50,18))
	var outside:=enemy(world,Vector2(60,0))
	var before:=closest.hp;var neighbor_before:=neighbor.hp;var outside_before:=outside.hp
	world.cast(world.player,"rock_throw",Vector2.LEFT,closest.position)
	assert_true(world.projectiles.is_empty(),"The move falls onto one selected ground area")
	assert_eq(closest.hp,before)
	advance(world,.6)
	assert_lt(closest.hp,before);assert_lt(neighbor.hp,neighbor_before);assert_eq(outside.hp,outside_before)
	assert_eq(closest.spe_stage,0,"Rock Throw never borrows Rock Tomb's slow")
	assert_eq(closest.stats,SpeciesDB.stats_at(closest.species_id,closest.level,closest.ivs))
	assert_eq(MoveDB.get_move("rock_throw").power,50.0)
	var after:=closest.hp;advance(world,.5);assert_eq(closest.hp,after,"Falling rocks apply one normal impact")

func test_fire_spin_lands_at_locked_ground_point_instead_of_chasing_target() -> void:
	var world:=fixture("fire_spin")
	var closest:=enemy(world,Vector2(-50,0))
	var farther:=enemy(world,Vector2(70,0))
	var locked: Vector2=closest.position
	world.cast(world.player,"fire_spin",Vector2.LEFT,locked)
	var field=world.zones[0]
	closest.position+=Vector2(0,65)
	advance(world,.5)
	assert_true(field.landed)
	assert_lt(field.position.distance_to(locked),.01)
	assert_eq(field.follow,null)
	assert_true(world._has_own_zone("fire_spin"))
	assert_eq(field.radius,23.0)
	assert_true(field.turns in [4,5])

func test_fire_spin_landing_hits_once_then_four_normal_residual_pulses() -> void:
	var world:=fixture("fire_spin")
	var target:=enemy(world,Vector2(50,0))
	world.player.acc_stage=6;target.eva_stage=-6
	var before:=target.hp
	world.cast(world.player,"fire_spin",Vector2.RIGHT,target.position,{"area_point_locked":true})
	var field=world.zones[0]
	field.turns=4;field.lifetime=4*Mon.TURN
	for _i in 60:
		world.step(1.0/60.0)
		if field.landed:break
	assert_true(field.landed)
	assert_lt(target.hp,before,"Landing applies the existing normal initial attack")
	var after_landing:=target.hp
	advance(world,.2)
	assert_eq(target.hp,after_landing,"The initial attack cannot repeat every field step")
	assert_eq(field.pulses,0)
	var residual:=target.residual()
	advance(world,4*Mon.TURN+.1)
	assert_eq(field.pulses,4)
	assert_eq(target.hp,after_landing-4*residual)
	assert_true(field.dead)

func test_area_damage_uses_release_snapshot_and_smoke_center_does_not_follow() -> void:
	var world:=fixture()
	var target:=enemy(world,Vector2(-50,0))
	world.cast(world.player,"smoke_screen",Vector2.RIGHT,target.position)
	target.position+=Vector2(0,80)
	advance(world,1.0)
	assert_eq(target.acc_stage,0,"Ground spells do not home after their release")

func test_ground_target_metadata_excludes_self_centered_skills() -> void:
	for move in ["smoke_screen","fire_spin","rock_throw","rock_tomb","sleep_powder","poison_powder","leech_seed","worry_seed","seed_bomb","sludge_bomb"]:
		assert_eq(MoveDB.get_move(move).get("targeting",""),"charged_area",move)
	for move in ["petal_dance","growl","growth","protect","ember"]:
		assert_ne(MoveDB.get_move(move).get("targeting",""),"charged_area",move)
