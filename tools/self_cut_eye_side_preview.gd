extends "res://tools/self_cut_eye_preview.gd"

const SideSample=preload("res://tools/samples/self_cut_eye_side.gd")

func output_dir() -> String:return "res://docs/direct_field_hms/self_cut_eye_side_sample/"
func capture_notes() -> Dictionary:
	var notes:=super.capture_notes()
	notes.merge({"facing_changed":false,"visible_eyes_only":true,"eye_flash_seconds":0.18,"last_sample_eye_count":game.field_friends.visible_eyes},true)
	return notes

func profile(species: String,place: String,flags: Array) -> void:
	await super.profile(species,place,flags)
	var sample:=SideSample.new()
	sample.game=game;sample.trees=game.field_friends.trees
	game.field_friends=sample
