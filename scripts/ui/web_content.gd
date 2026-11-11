class_name WebContent
extends RefCounted

## Wait under the title transition before synchronous sprite/map loaders run.
## Desktop builds already contain these resources and return immediately.
static var message := ""
static var mounted: Dictionary = {}

static func prepare(tree: SceneTree, species: String) -> Error:
	if not OS.has_feature("web"):return OK
	var bridge := JavaScriptBridge.get_interface("journeyContent")
	if bridge==null:
		push_error("Web content loader is missing")
		return ERR_UNAVAILABLE
	bridge.begin(species)
	while true:
		var state: Dictionary=JSON.parse_string(String(bridge.status()))
		message=String(state.get("message",""))
		if bool(state.get("done",false)):
			if not String(state.get("error","")).is_empty():
				message=""
				return ERR_CANT_OPEN
			for path: String in state.paths:
				if mounted.has(path):continue
				if not ProjectSettings.load_resource_pack(path,false):
					push_error("Cannot mount Web content: "+path)
					return ERR_FILE_CORRUPT
				mounted[path]=true
			message=""
			return OK
		await tree.process_frame
	return FAILED
