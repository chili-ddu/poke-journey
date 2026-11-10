extends SceneTree
const Palette = preload("res://scripts/view/charmander_palette.gd")
const DEST := "res://docs/charmander_resolution_sample/"
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"source"))
	var reference := Image.create(1024,640,false,Image.FORMAT_RGBA8)
	var metadata := []
	for row in 2:
		var name: String=["Idle","Walk"][row]
		var anim: Dictionary=MonSprite.load_set(4)[name]
		for column in 4:
			var frame := mini(column,anim.durations.size()-1)
			var image: Image=anim.tex.get_image().get_region(Rect2i(frame*anim.fw,2*anim.fh,anim.fw,anim.fh))
			image=Palette.process(image)
			if image.get_height()==32:
				var padded := Image.create(32,40,false,Image.FORMAT_RGBA8)
				padded.blit_rect(image,Rect2i(0,0,32,32),Vector2i(0,4))
				image=padded
			image.save_png(DEST+"source/%s-%d.png"%[name.to_lower(),column])
			image.resize(256,320,Image.INTERPOLATE_NEAREST)
			reference.blit_rect(image,Rect2i(0,0,256,320),Vector2i(column*256,row*320))
		metadata.append({"action":name,"ticks":anim.durations,"cell":[anim.fw,anim.fh]})
	reference.save_png(DEST+"reference.png")
	FileAccess.open(DEST+"source.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"  "))
	print("Existing polished Charmander: unchanged source poses, 4 Idle / 4 Walk cells")
	quit()
