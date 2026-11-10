extends SceneTree
func _init() -> void:
	var mon := Mon.new()
	mon.setup("charmander",5,Mon.TEAM_PLAYER)
	mon.attack_full_recovery=true
	mon.play_attack("Strike")
	var duration := mon.attack_anim_t
	var frames: Array=[]
	for i in 65:
		var time := float(i)*0.02
		var entries: Array=[]
		for facing in [Vector2.UP,Vector2.RIGHT]:
			mon.facing=facing
			var anim: Dictionary=mon._sprites.Strike if time<duration else mon._sprites.Idle
			var row:=MonSprite.row_for(anim,facing)
			var sheet_time:=mon.attack_sheet_time(time) if time<duration else 0.0
			var logical:=MonSprite.frame_at(anim,sheet_time,false)
			var frame:=mon.attack_pose_frame(logical) if time<duration else logical
			var order: Array=Mon.SCRATCH_POSE_ORDER if time<duration else []
			var visual:=MonSprite.visual_frame(anim,row,sheet_time,false,frame,-1,order)
			var old:=MonSprite.anchor_of(mon._sprites,anim)
			var fixed:=old
			if time<duration:
				old.x+=MonSprite.lunge_offset(anim,row,frame).x
				old.y=MonSprite.frame_bottom(anim,row,frame)-(float(mon._sprites.feet_dy)-1.0)
				fixed=mon.grounded_attack_anchor(anim,row,visual)
			var r: Rect2=visual.src
			for center in [old,fixed]:
				entries.append({"path":visual.tex.resource_path,"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"anchor":[center.x,center.y]})
		frames.append(entries)
	DirAccess.make_dir_recursive_absolute("res://docs/attack_anchor_review")
	var f:=FileAccess.open("res://docs/attack_anchor_review/selections.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(frames))
	mon.free()
	quit()
