extends "res://tools/ranged_origin_review.gd"
## Captures effects drawn by the game renderer, with only actors and cast timing scripted.
const DUELS = [
	["ranged", "ember", "water_gun", "squirtle", 36],
	["tie", "scratch", "scratch", "meowth", 26],
	["residual", "slash", "scratch", "meowth", 26],
]
const STEP := 1.0 / 120.0
var issues: Array[String] = []
var results := {}
var output: String

func run() -> void:
	output = OS.get_environment("CLASH_CAPTURE_DIR")
	if output.is_empty():
		printerr("Run tools/run_battle_clash_review.py to supply a private frame directory.")
		quit(1)
		return
	SaveData.path = output.path_join("private.cfg")
	for pair in [["BOT","1"],["GOD","0"],["CAP_VIEW","384x216"],["CAP_AUDIO","0"],["SEED","7"],["STARTER","charmander"],["DUNGEON","kanto_south"]]:
		OS.set_environment(pair[0], pair[1])
	await CaptureWindow.park(self)
	for duel in DUELS:
		await record_duel(duel)
	print("Battle clash runtime ", JSON.stringify(results), " issues ", issues)
	var report := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(results))
	report.close()
	quit(0 if issues.is_empty() else 1)

func expect(condition: bool, reason: String) -> void:
	if not condition:
		issues.append(reason)

func strike_start(actor: Mon, move: String) -> int:
	var delay := actor.lunge_timing("Strike").y
	delay = delay + 1.0/60.0 if delay > 0 else float(MoveDB.get_move(move).hit_delay)
	return 72 - roundi(delay / STEP)

func cast_attack(w: World, actor: Mon, other: Mon, move: String, close: bool) -> Dictionary:
	if close:
		actor.play_attack("Strike", 0, true)
	elif actor != w.player:
		actor.play_attack("Shoot")
	w.cast(actor, move, actor.facing, other.position)
	for queue in [w.pending_melee, w.bursts]:
		for cast in queue:
			if cast.mon == actor:
				return cast.hit
	for shot: Projectile in w.projectiles:
		if shot.team == actor.team:
			return shot.hit
	return {}

func record_duel(duel: Array) -> void:
	var case_id: String = duel[0]
	var close := case_id != "ranged"
	var folder := output.path_join(case_id)
	DirAccess.make_dir_recursive_absolute(folder)
	seed(7)
	FxStyle.set_mode("custom")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.stream.clear()
	game.ui_root.hide()
	var view: View3D = game.view3d
	view.set_process(false)
	var w: World = game.world
	w.god = false
	w.no_skills = false
	var p := w.player
	p.controller = DirectionInput.new()
	p.repel_steps = 99999
	p.ivs.clear()
	p.set_level(35, true)
	p.facing = Vector2.RIGHT
	p.position = open_cross() - Vector2.RIGHT * int(duel[4])
	var foe := Enemy.new()
	foe.setup_enemy(duel[3], 35, w.rng)
	foe.frozen = true
	for id in foe.cds: foe.cds[id] = 9999
	foe.facing = Vector2.LEFT
	foe.position = p.position + Vector2.RIGHT * 2 * int(duel[4])
	w.add_child(foe)
	w.enemies.append(foe)
	w.visibility_layer |= Look.GROUND_LAYER
	view._cam_ready = false
	var left_start := strike_start(p, duel[1]) if close else 36
	var right_start := strike_start(foe, duel[2]) if close else 36
	var initial_hp := Vector2i(p.hp, foe.hp)
	var before: Array[Dictionary] = [{}, {}]
	var contact_frame := -1
	var contact_x := Vector2.ZERO
	var chip_ids := {}
	var drawn_chips := {}
	var drawn_cuts := {}
	var full_widths := {}
	var cut_sizes := {}
	var held_ticks := 0
	var initial_radii := {}
	var remaining_sizes: Array[float] = []
	var water_id := 0
	var previous_water_position := Vector2.ZERO
	var projectile_hold_ticks := 0
	for frame in 44:
		if frame == 4 and not close:
			p.play_attack("Charge", 0.15)
		for substep in 4:
			var tick := frame * 4 + substep
			if tick == left_start:
				before[0] = cast_attack(w, p, foe, duel[1], close)
			if tick == right_start:
				before[1] = cast_attack(w, foe, p, duel[2], close)
			w.step(STEP)
			if not close:
				for shot: Projectile in w.projectiles:
					if shot.dead or shot.team != foe.team: continue
					var shot_id := shot.get_instance_id()
					if not shot.hit.has("clash_original_power"):
						initial_radii[shot_id] = shot.radius
					elif initial_radii.has(shot_id):
						remaining_sizes.append(shot.radius / float(initial_radii[shot_id]))
						if water_id == 0: water_id = shot_id
						if shot_id == water_id:
							if previous_water_position.is_equal_approx(shot.position):
								projectile_hold_ticks += 1
							previous_water_position = shot.position
			if p.hitstop_t > 0 and foe.hitstop_t > 0:
				held_ticks += 1
			for f: Fx in w.fxs:
				if f.kind != "clash_chip": continue
				chip_ids[f.get_instance_id()] = f.text + ("+" if f.dir.x > 0 else "-")
				if contact_frame < 0:
					contact_frame = frame
					contact_x = Vector2(p.position.x, foe.position.x)
		view._process(1.0/30.0)
		for f: Fx in w.fxs:
			if f.kind not in ["clash_chip", "forward_cut"]: continue
			for node in (view._sprites.get(f.get_instance_id(), {}) as Dictionary).values():
				if node is Sprite3D and f.kind == "forward_cut" and node.texture != null:
					var key := f.follow.get_instance_id() if is_instance_valid(f.follow) else 0
					if contact_frame < 0 and node.is_visible_in_tree():
						full_widths[key] = node.basis.x.length()
					elif contact_frame >= 0 and frame == contact_frame + 3 and full_widths.has(key):
						cut_sizes[key] = node.basis.x.length() / float(full_widths[key]) if node.is_visible_in_tree() else 0.0
				if node is Sprite3D and node.is_visible_in_tree() and node.texture != null:
					if f.kind == "forward_cut":
						drawn_cuts[f.get_instance_id()] = true
					elif node.material_override is ShaderMaterial:
						drawn_chips[f.get_instance_id()] = true
		await process_frame
		await RenderingServer.frame_post_draw
		if root.size != Vector2i(384, 216):
			printerr("Unexpected native test viewport ", root.size)
			quit(1)
			return
		expect(root.get_texture().get_image().save_png(folder.path_join("%02d.png" % frame)) == OK, "saving frame")
	var powers := Vector2i(before[0].get("power", -1), before[1].get("power", -1))
	var fraction := Vector2(before[0].get("clash_fraction", -1.0), before[1].get("clash_fraction", -1.0))
	var expected_power: Vector2i = {"ranged":Vector2i(0,20), "tie":Vector2i.ZERO, "residual":Vector2i(30,0)}[case_id]
	var expected_fraction := Vector2(expected_power) / Vector2(MoveDB.power(duel[1]), MoveDB.power(duel[2]))
	var chips := chip_ids.values()
	chips.sort()
	var expected_chips: Array = {"ranged":["fire+"], "tie":["normal+","normal-"], "residual":["normal-"]}[case_id]
	var loss := initial_hp - Vector2i(p.hp, foe.hp)
	var displacement := Vector2(p.position.x, foe.position.x) - contact_x
	var rendered_ratios := Vector2(cut_sizes.get(p.get_instance_id(), -1), cut_sizes.get(foe.get_instance_id(), -1))
	expect(contact_frame >= 0, case_id + " contact")
	expect(powers == expected_power and fraction.is_equal_approx(expected_fraction), case_id + " remaining power/size")
	expect(chips == expected_chips and drawn_chips.size() == chips.size(), case_id + " broken type, direction, rendered shader")
	if close:
		expect(rendered_ratios.is_equal_approx(expected_fraction), case_id + " rendered cut widths")
		expect(drawn_cuts.size() == 2 and held_ticks >= 5, case_id + " two rendered cuts and shared hitstop")
	if case_id == "ranged":
		expect(loss.x > 0 and loss.y == 0, case_id + " damage")
		expect(not remaining_sizes.is_empty() and remaining_sizes.all(func(r): return is_equal_approx(r, 0.5)),
			case_id + " water projectile radius halves")
		expect(projectile_hold_ticks >= 5, case_id + " projectile hitstop")
	elif case_id == "tie":
		expect(loss == Vector2i.ZERO and displacement.x < -4 and displacement.y > 4, case_id + " bilateral recoil without damage")
	else:
		expect(loss.x == 0 and loss.y > 0 and absf(displacement.x) < 2 and displacement.y > 8, case_id + " residual knockback")
	results[case_id] = {"contact":contact_frame,"power":[powers.x,powers.y],"fraction":[fraction.x,fraction.y],
		"hp_loss":[loss.x,loss.y],"displacement":[displacement.x,displacement.y],"chips":chips,
		"rendered_chip_layers":drawn_chips.size(),"rendered_cuts":drawn_cuts.size(),"rendered_cut_sizes":[rendered_ratios.x,rendered_ratios.y],"melee_hold_ticks":held_ticks,
		"projectile_hold_ticks":projectile_hold_ticks,"observed_projectile_width":remaining_sizes.front() if not remaining_sizes.is_empty() else null}
	game.free()
	await process_frame
