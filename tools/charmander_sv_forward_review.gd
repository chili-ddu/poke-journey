extends "res://tools/charmander_forward_review.gd"

class SVWorld extends SampleWorld:
	func configure(id: String) -> void:
		super.configure(id)
		if id in ["dragon_breath","flare_blitz"]:
			MoveDB.get_move(id).cast_delay = .20
	func _smoke_cloud_custom(_land: Vector2, _radius: float, _body_radius: float) -> void:
		pass # Review art draws the cloud when the existing lob lands.

func review_folder() -> String:
	return "res://docs/charmander_sv_forward/"

func new_world():
	return SVWorld.new()

func new_art():
	return preload("res://tools/samples/charmander_sv_art.gd").new()
