extends "res://tools/self_cut_eye_visible_preview.gd"

const LargeSample=preload("res://tools/samples/self_cut_eye_large.gd")

func output_dir() -> String:return "res://docs/direct_field_hms/self_cut_eye_large_sample/"
func capture_notes() -> Dictionary:
	var notes:=super.capture_notes()
	notes.merge({"spark_size":27.0,"glint_scale_from_previous":LargeSample.GLINT_SCALE,"same_timing_as_previous":true},true)
	return notes

func profile(species: String,place: String,flags: Array) -> void:
	await super.profile(species,place,flags)
	var sample:=LargeSample.new()
	sample.game=game;sample.trees=game.field_friends.trees
	game.field_friends=sample
