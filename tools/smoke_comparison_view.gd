extends View3D
# Diagnostic-only switch for comparisons against the individual sprite path.
var batching_allowed := false
func _batchable_smoke() -> Array:
	return super._batchable_smoke() if batching_allowed else []
