extends SceneTree

func _init() -> void:
	var rows := []
	for id in MoveDB.all_ids():
		var m := MoveDB.get_move(id)
		rows.append({"id":id,"type":m.type,"category":m.cat,
			"explicit_shape":MoveDB.is_shaped(id),"shape":m.get("shape",""),
			"fx":m.get("fx",""),"hit_fx":m.get("hit_fx",""),"animation":m.get("anim",""),
			"custom_fx":MoveShapes.CUSTOM_FX.has(id)})
	var path := "res://docs/skill_fx_bases/inventory.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"mode":FxStyle.mode,"moves":rows},"  "))
	print("Exported ",rows.size()," moves; custom mode ",FxStyle.mode)
	quit()
