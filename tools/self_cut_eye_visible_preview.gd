extends "res://tools/self_cut_eye_side_preview.gd"

const VisibleSample=preload("res://tools/samples/self_cut_eye_visible.gd")

func output_dir() -> String:return "res://docs/direct_field_hms/self_cut_eye_visible_sample/"
func capture_notes() -> Dictionary:
	var notes:=super.capture_notes()
	notes["art_source"]="existing character/map; code-generated pixelfx glint"
	notes.merge({"eye_flash_seconds":0.28,"eye_surface_alignment":true,"last_sample_depth_correction":game.field_friends.depth_correction,"last_sample_screen_error_before":game.field_friends.screen_error_before,"last_sample_aligned_effects":game.field_friends.aligned_fx,"spark_size":18.0,"effect_art_source":"pixelfx code; three actual render reviews; centered peak sprite","live_rendered_eye_tracking":true},true)
	return notes

func profile(species: String,place: String,flags: Array) -> void:
	await super.profile(species,place,flags)
	var sample:=VisibleSample.new()
	sample.game=game;sample.trees=game.field_friends.trees
	game.field_friends=sample
