extends Enemy

# Review only. Combat timers remain intact; only the drawing call uses Idle.
var reference_preview := false

func hit_feedback_tint() -> Color:
	return Color.WHITE if reference_preview else super.hit_feedback_tint()

func hit_feedback_offset() -> Vector2:
	return Vector2.ZERO if reference_preview else super.hit_feedback_offset()

func hit_feedback_scale() -> Vector2:
	return Vector2.ONE if reference_preview else super.hit_feedback_scale()

func _draw_sheet(ground: Vector2) -> void:
	if not reference_preview:
		super._draw_sheet(ground)
		return
	var saved := [hurt_t,flinch_t,flash_t,shake_t,sleep_t]
	hurt_t=0.0;flinch_t=0.0;flash_t=0.0;shake_t=0.0;sleep_t=0.0
	super._draw_sheet(ground)
	hurt_t=saved[0];flinch_t=saved[1];flash_t=saved[2];shake_t=saved[3];sleep_t=saved[4]
