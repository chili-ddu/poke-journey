extends "res://tools/self_cut_preview.gd"

const EyeSample=preload("res://tools/samples/self_cut_eye_glint.gd")

func output_dir() -> String:return "res://docs/direct_field_hms/self_cut_eye_sample/"
func frame_count() -> int:return 220
func capture_notes() -> Dictionary:
	return {"sample_only":true,"game_runtime_modified":false,"preparation_seconds":EyeSample.EYE_PREPARE,"eye_delay_seconds":EyeSample.EYE_DELAY,"eye_flash_seconds":0.2,"source_pixels_edited":false}

func profile(species: String,place: String,flags: Array) -> void:
	await super.profile(species,place,flags)
	var sample:=EyeSample.new()
	sample.game=game;sample.trees=game.field_friends.trees
	game.field_friends=sample
