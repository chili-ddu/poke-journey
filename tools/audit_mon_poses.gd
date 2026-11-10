extends SceneTree

const OUT := "res://docs/all_mon_pose_audit/"
var errors: Array = []
var warnings: Array = []
var records: Array = []
var previews: Array = []
var counts := {"species": 0, "sets": 0, "actions": 0, "samples": 0, "grounded_samples": 0, "intermediates": 0}
var source_image: Image
var source_id := 0

func _init() -> void: call_deferred("run")

func check(ok: bool, message: String, context: Dictionary) -> void:
	if not ok and errors.size() < 100:
		var error := context.duplicate()
		error["error"] = message
		errors.append(error)

func image_for(tex: Texture2D) -> Image:
	if source_id != tex.get_instance_id():
		source_id = tex.get_instance_id()
		source_image = tex.get_image()
		if source_image.is_compressed(): source_image.decompress()
	return source_image

func entry(visual: Dictionary, anchor: Vector2) -> Dictionary:
	var r: Rect2 = visual.src
	return {"path": visual.tex.resource_path, "rect": [r.position.x,r.position.y,r.size.x,r.size.y], "anchor": [anchor.x,anchor.y]}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var ids := SpeciesDB.all_ids()
	ids.sort_custom(func(a,b): return int(SpeciesDB.get_species(a).dex) < int(SpeciesDB.get_species(b).dex))
	for id in ids:
		var dex := int(SpeciesDB.get_species(id).dex)
		if not FileAccess.file_exists((MonSprite.ROOT % dex)+"AnimData.xml"): continue
		counts.species += 1
		for shiny in [false,true]:
			if shiny and not FileAccess.file_exists((MonSprite.ROOT % dex)+"shiny/AnimData.xml"): continue
			var mon := Mon.new()
			mon.shiny = shiny
			mon.setup(id,20,Mon.TEAM_PLAYER)
			counts.sets += 1
			var walk: Dictionary = mon._sprites.Walk
			var portrait := {"species":id,"dex":dex,"shiny":shiny,"directions":[]}
			for name in MonSprite.ANIMS:
				if not mon._sprites.has(name): continue
				var anim: Dictionary = mon._sprites[name]
				counts.actions += 1
				var record := {"species":id,"dex":dex,"shiny":shiny,"action":name,"source":anim.tex.resource_path,"rows":anim.rows,"frames":anim.durations.size(),"samples":0,"max_old_side_bias":0.0,"max_new_side_bias":0.0,"max_old_floor_error":0.0,"empty_samples":0}
				var loop: bool = name in ["Walk","Idle","Charge","Sleep","Dance","Rotate"]
				var order: Array = Mon.SCRATCH_POSE_ORDER if dex==4 and name=="Strike" and anim.durations.size()==9 else []
				var grounded: bool = name in ["Attack","Strike","Jab"]
				var walk_anchor := MonSprite.anchor_of(mon._sprites,walk)
				for direction in 8:
					mon.facing = Vector2.DOWN.rotated(-float(direction)*PI/4.0)
					var row := MonSprite.row_for(anim,mon.facing)
					var walk_row := MonSprite.row_for(walk,mon.facing)
					var reference_x: float = (walk.centers[walk_row][0] as Vector2).x-walk_anchor.x
					for logical in anim.durations.size():
						for phase in 4:
							var time := MonSprite.frame_start(anim,logical)+float(anim.durations[logical])*MonSprite.TICK*(float(phase)+0.05)/4.0
							var shown: int = order[logical] if not order.is_empty() else logical
							var visual := MonSprite.visual_frame(anim,row,time,loop,shown,-1,order)
							var context := {"species":id,"shiny":shiny,"action":name,"direction":direction,"frame":logical,"phase":phase}
							var rect := Rect2i(visual.src)
							var image := image_for(visual.tex)
							check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=image.get_width() and rect.end.y<=image.get_height(),"Frame exceeds atlas",context)
							var used := image.get_region(rect).get_used_rect()
							if not used.has_area(): record.empty_samples += 1
							check((visual.body_center as Vector2).is_finite(),"Invalid body marker",context)
							var next: int = (logical+1)%anim.durations.size() if loop else mini(logical+1,anim.durations.size()-1)
							if not order.is_empty(): next = order[next]
							if phase>0 and next!=shown:
								check(visual.tex!=anim.tex,"Missing C transition",context)
							if visual.tex!=anim.tex: counts.intermediates += 1
							if grounded and used.has_area():
								var anchor := mon.grounded_attack_anchor(anim,row,visual)
								var bias := absf((visual.body_center as Vector2).x-anchor.x-reference_x)
								var floor_error := absf(float(used.end.y-1)-anchor.y-(float(mon._sprites.feet_dy)-1.0))
								check(anchor.is_finite() and bias<0.001,"Sideways grounding drift",context)
								check(floor_error<0.001,"Visible foot drifts vertically",context)
								var old := MonSprite.anchor_of(mon._sprites,anim)
								old.x += MonSprite.lunge_offset(anim,row,shown).x
								old.y = MonSprite.frame_bottom(anim,row,shown)-(float(mon._sprites.feet_dy)-1.0)
								record.max_old_side_bias = maxf(record.max_old_side_bias,absf((visual.body_center as Vector2).x-old.x-reference_x))
								record.max_new_side_bias = maxf(record.max_new_side_bias,bias)
								record.max_old_floor_error = maxf(record.max_old_floor_error,absf(float(used.end.y-1)-old.y-(float(mon._sprites.feet_dy)-1.0)))
								counts.grounded_samples += 1
							counts.samples += 1
							record.samples += 1
				if record.empty_samples>0: warnings.append(record.duplicate())
				records.append(record)
			# All installed species/skins: four poses in every direction, kept at
			# the same world origin. Preview grounded Strike or contact Attack.
			var action := "Strike" if mon._sprites.has("Strike") else "Attack"
			if not mon._sprites.has(action): action = "Hurt"
			var anim: Dictionary = mon._sprites[action]
			portrait["action"] = action
			for direction in 8:
				mon.facing = Vector2.DOWN.rotated(-float(direction)*PI/4.0)
				var row := MonSprite.row_for(anim,mon.facing)
				var snapshots: Array = []
				for progress in [0.03,0.27,0.53,0.83]:
					var order: Array = Mon.SCRATCH_POSE_ORDER if dex==4 and action=="Strike" and anim.durations.size()==9 else []
					var visual := MonSprite.visual_frame(anim,row,MonSprite.anim_length(anim)*float(progress),false,-1,-1,order)
					var old := MonSprite.anchor_of(mon._sprites,anim)
					var frame := MonSprite.frame_at(anim,MonSprite.anim_length(anim)*float(progress),false)
					if not order.is_empty(): frame = order[frame]
					old.x += MonSprite.lunge_offset(anim,row,frame).x
					old.y = MonSprite.frame_bottom(anim,row,frame)-(float(mon._sprites.feet_dy)-1.0)
					snapshots.append({"fixed":entry(visual,mon.grounded_attack_anchor(anim,row,visual)),"before":entry(visual,old)})
				portrait.directions.append(snapshots)
			previews.append(portrait)
			mon.free()
		print("Audited ",id," (",counts.species,"/42)")
	var result := {"counts":counts,"errors":errors,"warnings":warnings,"records":records}
	var file := FileAccess.open(OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file = FileAccess.open(OUT+"previews.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(previews))
	print("POSE AUDIT: ",JSON.stringify(counts)," errors=",errors.size()," warnings=",warnings.size())
	quit(0 if errors.is_empty() else 1)
