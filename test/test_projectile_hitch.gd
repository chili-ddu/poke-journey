extends GutTest

func _world() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7,"charmander",20,["ember"],null)
	w.player.position = Arena.center()
	return w

func _foe(w: World, distance: float) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy("rattata",20,w.rng)
	e.hp = 9999
	e.max_hp = 9999
	e.position = w.player.position+Vector2.RIGHT*distance
	w.add_child(e)
	w.enemies.append(e)
	return e

func _shot(w: World, move: String) -> Projectile:
	w._spawn_projectile(w.player,w.make_hit(w.player,move),MoveDB.get_move(move),Vector2.RIGHT*200.0)
	return w.projectiles.back()

func test_hitch_cannot_skip_target_for_three_custom_projectiles() -> void:
	for move in ["ember","flamethrower","dragon_rage"]:
		var w := _world()
		var target := _foe(w,50.0)
		_shot(w,move)
		w._step_projectiles(0.5)
		assert_lt(target.hp,9999,move+" crosses target during 500 ms hitch")

func test_nonpiercing_stops_at_nearest_target_even_if_list_order_is_reversed() -> void:
	var w := _world()
	var far := _foe(w,75.0)
	var near := _foe(w,40.0)
	var p := _shot(w,"dragon_rage")
	p.pierce=false # Exercise the nonpiercing collision path explicitly.
	w._step_projectiles(0.5)
	assert_lt(near.hp,9999)
	assert_eq(far.hp,9999)
	assert_true(p.dead)
	assert_lt(p.position.x,near.position.x)

func test_hitch_respects_wall_and_range_end() -> void:
	var w := _world()
	var target := _foe(w,60.0)
	var original_obstacles := Arena.obstacles.duplicate(true)
	Arena.obstacles = Arena.obstacles.duplicate(true)
	Arena.obstacles.append({"pos":w.player.position+Vector2.RIGHT*30,"r":3.0})
	var p := _shot(w,"ember")
	w._step_projectiles(0.5)
	assert_eq(target.hp,9999,"Wall blocks swept travel")
	assert_true(p.dead)
	Arena.obstacles = original_obstacles
	var far := _foe(w,140.0)
	target.dead = true
	var ranged := _shot(w,"dragon_rage")
	var start := ranged.position
	var travel := ranged.range_left
	w._step_projectiles(2.0)
	assert_eq(far.hp,9999,"No damage beyond range")
	assert_almost_eq(ranged.position.distance_to(start),travel,0.001)

func test_piercing_hits_each_target_only_once_across_substeps() -> void:
	var w := _world()
	var near := _foe(w,40.0)
	var far := _foe(w,70.0)
	var p := _shot(w,"flamethrower")
	w._step_projectiles(0.5)
	assert_lt(near.hp,9999)
	assert_lt(far.hp,9999)
	assert_eq(p.hit_ids.size(),2)
	var hp := [near.hp,far.hp]
	w._step_projectiles(0.5)
	assert_eq([near.hp,far.hp],hp)

class MissWorld:
	extends World
	var checks := 0
	func apply_hit(_target: Mon, _hit: Dictionary, _from_pos: Vector2) -> bool:
		checks += 1
		return false

func test_substeps_do_not_retry_failed_accuracy_roll_or_duplicate_trail_samples() -> void:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := MissWorld.new()
	add_child_autofree(w)
	w.setup(7,"charmander",20,["ember"],null)
	_foe(w,40.0)
	var p := _shot(w,"ember")
	p.style = "ember_c"
	w._step_projectiles(0.5)
	assert_eq(w.checks,1,"A missed accuracy roll is not retried at each spatial step")
	assert_eq(p.trail.size(),1,"Trail sampling stays once per frame")

func test_followup_volley_stops_at_old_contact_during_hitch() -> void:
	var w := _world()
	var far := _foe(w,75.0)
	var p := _shot(w,"dragon_rage")
	p.pierce=false
	p.hit["volley"] = 123
	w._volley_stop[123] = w.player.position+Vector2.RIGHT*40
	w._step_projectiles(0.5)
	assert_true(p.dead)
	assert_eq(far.hp,9999)
	assert_lt(p.position.x,far.position.x)

func test_broad_phase_keeps_growing_radius_and_endpoint_contacts() -> void:
	var w := _world()
	var p := _shot(w,"dragon_rage")
	p.radius = 3.0
	p.grow = 3.0
	var end := p.position+Vector2.RIGHT*80.0
	var grazing := _foe(w,40.0)
	grazing.position = p.position+Vector2(40,grazing.radius+8+grazing.radius*0.2)
	var endpoint := _foe(w,90.0)
	endpoint.position = end+Vector2(endpoint.radius+7,-0.0+endpoint.radius*0.2)
	var distant := _foe(w,40.0)
	distant.position = p.position+Vector2(40,100)
	var candidates := w._projectile_candidates(p,end)
	assert_true(candidates.has(grazing),"Growth envelope is included")
	assert_true(candidates.has(endpoint),"Capsule endpoint includes target radius")
	assert_false(candidates.has(distant),"Off-path target is filtered")
