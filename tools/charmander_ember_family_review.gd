extends "res://tools/charmander_sv_forward_review.gd"

class FamilyWorld extends SVWorld:
	var previous_pose := "Attack"
	func configure(id: String) -> void:
		super.configure(id)
		if id=="flamethrower":
			var move:=MoveDB.get_move(id)
			previous_pose=move.get("anim","Attack")
			move.anim="Charge"

	func _player_recover(id: String, action: float = -1.0) -> void:
		if id=="flamethrower" and action<0:
			var move:=MoveDB.get_move(id)
			var emit_time:=float(move.interval)*(int(move.count)-1)
			player.attack_anim_t=maxf(player.attack_anim_t,emit_time)
			# Retain the previous move's input lock while playing the stationary pose.
			action=MonSprite.anim_length(player._sprites[previous_pose])
		super._player_recover(id,action)

func review_folder() -> String:
	return "res://docs/charmander_ember_family/"

func new_world():
	return FamilyWorld.new()

func new_art():
	return preload("res://tools/samples/charmander_ember_family_art.gd").new()
