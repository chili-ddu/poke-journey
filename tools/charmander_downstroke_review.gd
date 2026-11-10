extends "res://tools/charmander_ember_family_review.gd"

const OUTPUT := "res://docs/charmander_downstroke/"

static func variant_folder() -> String:
	var args:=OS.get_cmdline_user_args()
	if "--lift-stroke" in args: return OUTPUT+"lifted/"
	return OUTPUT+"raised/" if "--raised-finish" in args else OUTPUT

class Downstroke extends "res://tools/samples/charmander_ember_family_art.gd":
	var folder: String
	var lift := 0.0

	func sheet_path(id: String) -> String:
		if id in ["scratch","slash"]:
			return folder+"sheets/%s/sheet" % id
		return super.sheet_path(id)

	func draw_cut(t: float, _aim: Basis) -> void:
		draw_actor_cut(t,world.player)

	func draw_actor_cut(t: float, actor: Mon) -> void:
		var scratch:=move=="scratch"
		var cam:=view.cam.global_basis
		var forward:=Vector3(flow.x,0,flow.y)
		var body: Sprite3D=view._sprites[actor.get_instance_id()].sprite
		var center:=view.sprite_pixel_position(body,visible_bounds(body).get_center())
		var start:=center+forward*actor.radius*.83/Arena.TILE+Vector3.UP*.27
		start+=cam.y*lift/Arena.TILE
		# Ground travel follows the cast. Height falls toward the feet in every facing.
		# A front/back swing still crosses the body a little, keeping the claws visible edge-on.
		var side:=forward.dot(cam.x)
		var wrist:=.40*(1-absf(side))*(1.0 if side>=0 else -1.0)
		# Foreshorten a swing into the screen so its falling tip still reads from above.
		var depth:=minf(forward.dot(cam.y),.23)
		var along:=cam.x*(side+wrist)+cam.y*depth
		var plane:=Basis(along,cam.y,cam.z)
		var near_end:=Vector2(-23.5,-13.5) if scratch else Vector2(-43,-19.5)
		draw_sheet(t,start,plane,Vector2.ONE*(.62 if scratch else .66),1,origin+near_end)

func review_folder() -> String:
	return variant_folder()

func new_art():
	var art:=Downstroke.new()
	# A rigid translation reuses the original descending atlas and pivot.
	var lifted:="--lift-stroke" in OS.get_cmdline_user_args()
	art.folder=OUTPUT if lifted else variant_folder()
	art.lift=6.0 if lifted else 0.0
	return art
