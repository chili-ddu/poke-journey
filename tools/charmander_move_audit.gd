extends "res://tools/material_hit_fx_review.gd"

const OUTPUT = "res://docs/charmander_move_audit/"
const STAGES = ["atk","def","spa","spd","spe","acc","eva"]

func move_pool() -> Dictionary:
	var pool := {}
	var species := SpeciesDB.get_species("charmander")
	for pair in species.learnset:
		pool[pair[1]] = ["Lv.%d" % int(pair[0])]
	for id in MoveDB.all_ids():
		var machine = MoveDB.get_move(id).get("tm")
		if machine in species.tms:
			if not pool.has(id): pool[id] = []
			pool[id].append(machine)
	for id in species.tutor:
		if not pool.has(id): pool[id] = []
		pool[id].append("가르침")
	return pool

func ranks(mon: Mon) -> Dictionary:
	var result := {}
	for stat in STAGES:
		var value := int(mon.get(stat + "_stage"))
		if value != 0: result[stat] = value
	return result

func run() -> void:
	var visual := DisplayServer.get_name() != "headless"
	if visual: await CaptureWindow.park(self)
	SaveData.path = "user://save_charmander_move_audit.cfg"
	var settings := {"BOT":"1","GOD":"1","SEED":"7","STARTER":"charmander","DUNGEON":"kanto_south"}
	for key in settings: OS.set_environment(key,settings[key])
	FxStyle.set_mode("custom")
	var rows := []
	var pool := move_pool()
	for move: String in pool:
		if visual and not String(pool[move][0]).begins_with("Lv."): continue
		seed(7)
		var game
		var w: World
		var input := ReviewInput.new()
		if visual:
			game = load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			current_scene = game
			game.set_process(false)
			game.ui_root.visible = false
			game.stream.clear()
			game.view3d.set_process(false)
			w = game.world
			w.player.setup_player("charmander",40,[move])
			w.player.position = open_cross() - Vector2.RIGHT * 30
			game.view3d._cam_ready = false
		else:
			DungeonDB.set_current("test_meadow")
			Arena.configure(DungeonDB.theme())
			w = World.new()
			root.add_child(w)
			w.setup(7,"charmander",40,[move],input)
			w.player.position = Arena.center()
		w.player.controller = input
		w.no_skills = false
		w.player.facing = Vector2.RIGHT
		w.player.repel_steps = 100000
		var foes: Array[Enemy] = []
		for offset: Vector2 in [Vector2(28,0),Vector2(55,0),Vector2(30,-22)]:
			var enemy := Enemy.new()
			enemy.setup_enemy("chansey",45,w.rng)
			enemy.frozen = true
			for id in enemy.cds: enemy.cds[id] = 9999
			enemy.position = w.player.position + offset
			enemy.facing = Vector2.LEFT
			w.add_child(enemy)
			w.enemies.append(enemy)
			foes.append(enemy)
		input.target = foes[0]
		var folder := OUTPUT+move+"/"
		if visual: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var defn := MoveDB.get_move(move)
		var changed := [false,false,false]
		var damage := [0,0,0]
		var status := [{},{},{}]
		var initial_pp := int(w.player.pp[0])
		var pp_used := false
		var self_damage := 0
		for frame in 120:
			if frame == 5: input.requested = true
			var hp := foes.map(func(e): return e.hp)
			var self_hp := w.player.hp
			w.step(1.0/30)
			pp_used = pp_used or int(w.player.pp[0]) < initial_pp
			self_damage += maxi(0,self_hp-w.player.hp)
			for i in foes.size():
				damage[i] += maxi(0,int(hp[i])-foes[i].hp)
				for effect in ["burn","poison","para","confuse","sleep","bind","flinch"]:
					if float(foes[i].get(effect+"_t")) > 0: status[i][effect] = true
				changed[i] = changed[i] or not ranks(foes[i]).is_empty()
			if visual:
				game.view3d._process(1.0/30)
				if frame % 3 == 0:
					await process_frame
					await RenderingServer.frame_post_draw
					assert(root.size == Vector2i(384,216))
					root.get_texture().get_image().save_png(folder+"%03d.png"%frame)
		rows.append({"id":move,"sources":pool[move],"explicit":MoveDB.is_shaped(move),"definition":defn,"pp_used":pp_used,"damage":damage,"status":status,"ranks":foes.map(ranks),"rank_changed":changed,"self_damage":self_damage,"self_ranks":ranks(w.player)})
		print(move, " ",defn.shape," ",damage, " PP ",pp_used)
		if visual: game.free()
		else: w.free()
		await process_frame
	var file := FileAccess.open(OUTPUT+("native.json" if visual else "headless.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	quit()
