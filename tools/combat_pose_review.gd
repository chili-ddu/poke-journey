extends SceneTree

# Export the actual render selections for an old/new timing comparison.
func _init() -> void:
	var mon := Mon.new()
	mon.setup("charmander", 5, Mon.TEAM_PLAYER)
	mon.facing = Vector2.RIGHT
	mon.attack_full_recovery = true
	mon.play_attack("Strike")
	var duration := mon.attack_anim_t
	var rows: Array = []
	for i in 90:
		var time := float(i) * 0.02
		var samples: Array = []
		for kind in ["attack", "hurt"]:
			for after in [false, true]:
				var anim: Dictionary
				var visual: Dictionary
				var center := Vector2.ZERO
				if (kind == "attack" and time < duration) or (kind == "hurt" and time < Mon.HURT_ANIM):
					anim = mon._sprites.Strike if kind == "attack" else mon._sprites.Hurt
					var sheet_time := mon.attack_sheet_time(time) if kind == "attack" else (mon.hurt_sheet_time(time) if after else time)
					var frame := MonSprite.frame_at(anim, sheet_time, false)
					if kind == "attack": frame = mon.attack_pose_frame(frame)
					var order: Array = Mon.SCRATCH_POSE_ORDER if kind == "attack" and after else []
					visual = MonSprite.visual_frame(anim, 2, sheet_time, false, frame, -1, order)
					center = MonSprite.anchor_of(mon._sprites, anim)
					if kind == "attack":
						center.x += MonSprite.lunge_offset(anim, 2, frame).x
						center.y = MonSprite.frame_bottom(anim, 2, frame) - (float(mon._sprites.feet_dy) - 1.0)
						if after: center = mon.grounded_attack_anchor(anim, 2, visual)
				else:
					anim = mon._sprites.Idle
					visual = MonSprite.visual_frame(anim, 2, 0.0)
					center = MonSprite.anchor_of(mon._sprites, anim)
				var r: Rect2 = visual.src
				samples.append({"path": visual.tex.resource_path, "rect": [r.position.x,r.position.y,r.size.x,r.size.y], "anchor": [center.x,center.y]})
		rows.append(samples)
	DirAccess.make_dir_recursive_absolute("res://docs/combat_pose_timing")
	var file := FileAccess.open("res://docs/combat_pose_timing/selections.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows))
	mon.free()
	print("Exported before/after attack and hurt render selections")
	quit()
