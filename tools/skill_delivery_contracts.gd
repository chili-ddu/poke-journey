extends SceneTree

func _init() -> void:
	var rows:=[]
	for id in ["ember","water_gun","thunder_shock","razor_leaf","gust","confusion"]:
		var m:=MoveDB.get_move(id)
		var row:={"id":id}
		for field in ["type","cat","shape","anim","fx","hit_fx","cast_delay","hit_delay","speed","radius","range","count","interval","volley","spread_deg","grow","pierce"]:
			if m.has(field):row[field]=m[field]
		rows.append(row)
	FileAccess.open("res://docs/skill_delivery_study/move-contracts.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("DELIVERY CONTRACTS ",rows.size()," read-only move definitions, ",FxStyle.mode)
	quit()
