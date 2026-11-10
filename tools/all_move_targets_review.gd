extends "res://tools/charmander_contact_review.gd"

const CATALOG_PATH:="res://docs/all_move_targets/"
const NUMBERS={"water_gun":[Vector2(13,0),Vector2(60,0),Vector2(30,38)],"icy_wind":[Vector2(63,-22),Vector2(63,22),Vector2(-32,0)],"discharge":[Vector2(30,0),Vector2(-30,0),Vector2(149,0)],"absorb":[Vector2(22,0),Vector2(40,0),Vector2(-22,0)]}

func run() -> void:
	SaveData.path="user://all_move_targets_private.cfg"
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CATALOG_PATH))
	var report:=FileAccess.open(CATALOG_PATH+"moves.csv",FileAccess.WRITE)
	var names: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/names_ko.json")).moves
	report.store_csv_line(["id","name_ko","original_target","pattern","delivery","category","art","effect_review","fixture_1_hp_lost","fixture_2_hp_lost","fixture_3_hp_lost"])
	var totals:={}
	for id: String in MoveDB.all_ids():
		if id=="none": continue
		var m:=MoveDB.get_move(id)
		var w:=World.new()
		root.add_child(w)
		w.setup(7,"charmander",40,[id],Still.new())
		w.player.position=Arena.center()
		w.player.facing=Vector2.RIGHT
		w.aim_point=w.player.position+Vector2.RIGHT*64
		var enemies: Array[Enemy]=[]
		var old_hp: Array[int]=[]
		for pos in NUMBERS.get(id,[Vector2(29,0),Vector2(39,-20),Vector2(-28,0)]):
			var enemy:=opponent(w,pos)
			enemies.append(enemy)
			old_hp.append(enemy.hp)
		w.cast(w.player,id,Vector2.RIGHT,w.aim_point)
		for step in 60: w.step(.025)
		var loss: Array[int]=[]
		for i in enemies.size():
			loss.append(old_hp[i]-enemies[i].hp if is_instance_valid(enemies[i]) else old_hp[i])
		if id in NUMBERS:
			check(loss[0]>0 and loss[1]>0 and loss[2]==0,id+" "+str(loss))
		var shape:=String(m.target_pattern)
		totals[shape]=totals.get(shape,0)+1
		var effect_note: String=""
		if m.cat=="status" and m.shape=="status_cone" and not m.get("fx") and not m.get("stat") and not m.has("sleep") and not m.has("poison") and not m.has("confuse") and not m.has("paralyze"):
			effect_note="고유 효과 추가 검토"
		report.store_csv_line([id,names.get(id,m.name),str(int(MoveDB.Targeting.ids[id])),shape,m.shape,m.cat,str(m.get("fx","")),effect_note,str(loss[0]),str(loss[1]),str(loss[2])])
		w.free()
		# Flush nodes disposed by the simulation between independent encounters.
		await process_frame
	print("Catalogue ",totals," issues ",failures)
	report.close()
	quit(0 if failures.is_empty() else 1)
