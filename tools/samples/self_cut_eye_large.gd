# Same centered glint and timing, 50% larger for the next review sample.
extends "res://tools/samples/self_cut_eye_visible.gd"

const GLINT_SCALE=1.5

func _flash_eyes() -> void:
	super._flash_eyes()
	for fx: Fx in game.world.fxs:
		if not fx.dead and fx.follow==game.world.player and fx.get_meta("eye_surface_aligned",false):
			fx.size*=GLINT_SCALE
			_align(fx,game.world.player,game.view3d)
