extends "res://scripts/johto/hgss_pallet_sample.gd"

func collection_directory() -> String:
	return "res://assets/maps/johto_hgss/"

func initial_header() -> int:
	var requested := OS.get_environment("HGSS_HEADER")
	var id := int(requested) if requested.is_valid_int() else 76
	return id if collection.manifest.headers.has(str(id)) else 76
