extends "res://tools/charmander_downstroke_review.gd".Downstroke
## Reuse the lifted single-cast placement for each participant.
var caster: Mon
var ink: Image

func prepare(v: View3D, actor: Mon, id: String, direction: Vector2) -> void:
	view=v
	caster=actor
	move=id
	flow=direction
	folder="res://docs/charmander_downstroke/"
	lift=6.0
	var path:=sheet_path(id)
	var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	cells=info.frames
	fps=info.meta.pixelfx.fps
	origin=Vector2(info.meta.pixelfx.pivot[0],info.meta.pixelfx.pivot[1])
	ink=Image.load_from_file(ProjectSettings.globalize_path(path+".png"))
	atlas=ImageTexture.create_from_image(ink)
	sprite=layer(atlas)

func show_contact(seconds_until: float) -> void:
	var t:=.095-seconds_until
	if t<0 or t>=(.32 if move=="scratch" else .38):
		sprite.hide()
		return
	draw_actor_cut(t,caster)

# Apply after draw_actor_cut resets the authored transform each frame. Pin the
# crossing pixel while shrinking the rendered plane, including asymmetric cuts.
func shrink_at(contact: Vector3, elapsed: float, remaining: float) -> void:
	if not sprite.visible: return
	var ratio:=lerpf(1.0,remaining,smoothstep(0.0,2.0/30.0,elapsed))
	if ratio<=0:
		sprite.hide()
		return
	sprite.position=contact+(sprite.position-contact)*ratio
	sprite.basis.x*=ratio
	sprite.basis.y*=ratio

# Project visible atlas pixels onto the camera so fragments can start on a
# common stroke pixel even when the casters are asymmetric or face into depth.
func screen_ink() -> Dictionary:
	var result:={}
	var cell:=Rect2i(sprite.region_rect)
	for y in cell.size.y:
		for x in cell.size.x:
			if ink.get_pixel(cell.position.x+x,cell.position.y+y).a<.4: continue
			var local:=Vector3(x+.5-cell.size.x*.5,cell.size.y*.5-y-.5,0)*sprite.pixel_size
			var at:=sprite.to_global(local)
			result[Vector2i(view.cam.unproject_position(at).round())]=at
	return result
