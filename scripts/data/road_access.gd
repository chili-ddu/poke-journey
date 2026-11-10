class_name RoadAccess
extends RefCounted

const SAFFRON_VISITED := "visited_area_saffron_city"
const SNORLAX_AWAKENED := "route11_snorlax_awakened"

static func can_fly(area: String, events: Array) -> bool:
	if area in ["route24", "route25"]:return events.has(SAFFRON_VISITED)
	if area=="route11":return events.has(SNORLAX_AWAKENED)
	return true
