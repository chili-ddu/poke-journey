extends GutTest

var world: World
var enemy: Enemy
var center: Vector2

func before_each() -> void:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	world = World.new()
	add_child_autofree(world)
	world.setup(7, "charmander", 20, ["ember"], null)
	center = Arena.center()
	world.player.position = center + Vector2(-90, 25)
	enemy = Enemy.new()
	enemy.setup_enemy("squirtle", 20, world.rng)
	enemy.position = center + Vector2(90, 25)
	world.add_child(enemy)
	world.enemies.append(enemy)

func shot(mon: Mon, move: String, offset: Vector2, velocity: Vector2, packet: Dictionary = {}) -> Projectile:
	var hit := world.make_hit(mon, move) if packet.is_empty() else packet
	world._spawn_projectile(mon, hit, MoveDB.get_move(move), velocity)
	var p: Projectile = world.projectiles.back()
	p.position = center + offset
	p.radius = 3.0
	p.grow = 1.0
	p.range_full = 200.0
	p.range_left = 200.0
	return p

func test_advantaged_water_reduces_entire_ember_cast_and_pauses_only_winner() -> void:
	world.cast(world.player, "ember", Vector2.RIGHT, enemy.position)
	world.cast(enemy, "water_gun", Vector2.LEFT, world.player.position)
	var fire: Dictionary = world.bursts[0].hit
	var water: Dictionary = world.bursts[1].hit
	var f := shot(world.player, "ember", Vector2(-13, 0), Vector2.RIGHT * 100, fire)
	var rear := shot(world.player, "ember", Vector2(-30, 0), Vector2.RIGHT * 100, fire)
	var w := shot(enemy, "water_gun", Vector2(13, 0), Vector2.LEFT * 100, water)
	var free := shot(enemy, "water_gun", Vector2(13, 30), Vector2.LEFT * 100)
	world._step_projectiles(0.12)
	assert_true(f.dead and rear.dead)
	assert_false(w.dead)
	assert_eq(float(fire.power), 0.0)
	assert_eq(float(water.power), 20.0)
	assert_eq(w.radius, 1.5)
	assert_almost_eq(w.position.x, center.x + 3.0, 0.01)
	assert_almost_eq(free.position.x, center.x + 1.0, 0.01)
	assert_eq(world.bursts.size(), 1)
	var pos := w.position
	var left: int = world.bursts[0].left
	world._step_bursts(0.02)
	assert_eq(int(world.bursts[0].left), left)
	world._step_projectiles(0.02)
	assert_eq(w.position, pos)
	world._step_projectiles(0.05)
	assert_lt(w.position.x, pos.x)
	var m := MoveDB.get_move("water_gun")
	world._spawn_projectile(enemy, water, m, Vector2.LEFT * 100)
	assert_almost_eq(float(world.projectiles.back().radius), float(m.radius) / 2.0, 0.001)

func test_tied_casts_cancel_across_a_long_frame() -> void:
	var a := shot(world.player, "ember", Vector2(-45, 0), Vector2.RIGHT * 200)
	var b := shot(enemy, "ember", Vector2(45, 0), Vector2.LEFT * 200)
	world._step_projectiles(0.5)
	assert_true(a.dead and b.dead)
	assert_almost_eq(a.position.x, center.x - 3.0, 0.01)
	assert_almost_eq(b.position.x, center.x + 3.0, 0.01)

func test_sequential_clashes_spend_only_remaining_base_power() -> void:
	var a := shot(world.player, "water_gun", Vector2(-28, 0), Vector2.RIGHT * 100)
	var b := shot(enemy, "ember", Vector2(0, 0), Vector2.LEFT * 100)
	var c := shot(enemy, "ember", Vector2(33, 0), Vector2.LEFT * 100)
	world._step_projectiles(0.9)
	assert_true(a.dead and b.dead and c.dead)
	assert_eq(float(a.hit.power), 0.0)

func test_unconnected_paths_and_fixed_attacks_pass_without_clashing() -> void:
	var a := shot(world.player, "water_gun", Vector2(-15, 0), Vector2.RIGHT * 100)
	var b := shot(enemy, "ember", Vector2(15, 8), Vector2.LEFT * 100)
	var fixed := shot(enemy, "dragon_rage", Vector2(15, 0), Vector2.LEFT * 100)
	world._step_projectiles(0.3)
	assert_false(a.dead or b.dead or fixed.dead)
	assert_false(a.hit.has("clash_resume"))
	assert_almost_eq(a.position.x, center.x + 15.0, 0.01)

func test_range_or_wall_before_contact_preserves_opposing_power() -> void:
	var short := shot(world.player, "ember", Vector2(-35, 0), Vector2.RIGHT * 100)
	short.range_left = 8.0
	var water := shot(enemy, "water_gun", Vector2(35, 0), Vector2.LEFT * 100)
	world._step_projectiles(0.4)
	assert_true(short.dead)
	assert_false(water.dead)
	assert_eq(float(water.hit.power), 40.0)
	water.dead = true
	var obstacles := Arena.obstacles
	Arena.obstacles = obstacles.duplicate()
	Arena.obstacles.append({"pos":center + Vector2(-22, 0), "r":2.0})
	var blocked := shot(world.player, "ember", Vector2(-35, 0), Vector2.RIGHT * 100)
	var incoming := shot(enemy, "water_gun", Vector2(35, 0), Vector2.LEFT * 100)
	world._step_projectiles(0.4)
	Arena.obstacles = obstacles
	assert_true(blocked.dead)
	assert_false(incoming.dead)
	assert_eq(float(incoming.hit.power), 40.0)

func test_only_the_residual_attack_reaches_the_pokemon() -> void:
	world.player.position = center + Vector2(-54, 0)
	var health := world.player.hp
	var fire := shot(world.player, "ember", Vector2(-16, 0), Vector2.RIGHT * 100)
	var water := shot(enemy, "water_gun", Vector2(16, 0), Vector2.LEFT * 100)
	world._step_projectiles(0.9)
	assert_true(fire.dead)
	assert_lt(world.player.hp, health)
	assert_eq(float(water.hit.power), 20.0)
	assert_true(water.hit_ids.has(world.player.get_instance_id()))

func test_same_team_and_status_packets_do_not_clash() -> void:
	var a := shot(world.player, "ember", Vector2(-15, 0), Vector2.RIGHT * 100)
	var ally := shot(world.player, "ember", Vector2(15, 0), Vector2.LEFT * 100)
	var status := shot(enemy, "water_gun", Vector2(15, 0), Vector2.LEFT * 100)
	status.hit.cat = "status"
	world._step_projectiles(0.3)
	assert_false(a.dead or ally.dead or status.dead)
	assert_false(a.hit.has("clash_fraction"))

func test_expanding_projectiles_collide_even_when_centers_never_get_within_initial_width() -> void:
	var a := shot(world.player, "ember", Vector2(-30, 0), Vector2.RIGHT * 100)
	var b := shot(enemy, "ember", Vector2(30, 9), Vector2.LEFT * 100)
	a.grow = 5.0
	b.grow = 5.0
	world._step_projectiles(0.45)
	assert_true(a.dead and b.dead)

func test_remaining_water_power_uses_actual_recipient_type_once() -> void:
	var fire := world.make_hit(world.player, "ember")
	var water := world.make_hit(enemy, "water_gun")
	world.resolve_clash(fire, water, center, Vector2.RIGHT, Vector2.LEFT)
	for species in ["charmander", "meowth"]:
		var target := Enemy.new()
		target.setup_enemy(species, 20, world.rng)
		world.add_child(target)
		target.max_hp = 300
		target.hp = 300
		var control := world.make_hit(enemy, "water_gun")
		control.power = 20.0
		var rng_state := world.rng.state
		assert_true(world.apply_hit(target, control, center))
		var expected := target.hp
		target.hp = 300
		world.rng.state = rng_state
		assert_true(world.apply_hit(target, water, center))
		assert_eq(target.hp, expected, species)
