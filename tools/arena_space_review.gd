extends "res://tools/arena_camera_review.gd"

func run() -> void:
	out="res://docs/arena_space_review/after"
	await super.run()

func frame(advance: bool=true) -> void:
	await super.frame(advance)
	var view: View3D=game.view3d
	var pitch := rad_to_deg(asin(view.cam.basis.z.y))
	var opacity: float=view._sun.shadow_opacity
	if not game.sendout.is_empty() and game.sendout.phase=="show":
		var field: Array=Arena.map.arena.field
		var enemy: Mon=game.battle.mon
		assert(is_equal_approx(enemy.position.y,(float(field[1])+2.0)*Arena.TILE),"Opponent keeps its original two-tile inset from the court edge")
		assert(is_equal_approx(game.world.player.position.y-enemy.position.y,9.5*Arena.TILE),"Initial combatant separation stays unchanged")
	if absf(pitch-View3D.ARENA_INTRO_ELEV)<0.01:
		assert(is_zero_approx(opacity),"Low intro has no off-screen sun-shadow wedges")
	elif absf(pitch-View3D.elev_deg)<0.01:
		assert(is_equal_approx(opacity,float(View3D.SKY[View3D.sky_kind(DungeonDB.current)][3])),"Battle restores normal lighting")
	# A readable foot contact is retained during the close-up.
	if is_instance_valid(game.arena_trainer):
		var id: int=game.arena_trainer.get_instance_id()
		if view._sprites.has(id):
			assert(view._sprites[id].blob.visible,"Trainer retains a contact shadow")
