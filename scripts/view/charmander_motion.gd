extends RefCounted

# Only display clocks change. Battle metadata, contact times and input locks
# remain in the source sheet's time domain.
const IDLE_SECONDS := 1.2
const CHARGE_SECONDS := 0.6
const STRIDE_PIXELS := 40.0

static func loop_time(anim: Dictionary, elapsed: float, period: float) -> float:
	return fposmod(maxf(0.0, elapsed), period) / period * MonSprite.anim_length(anim)

static func strike_time(_anim: Dictionary, time: float, _loop: bool) -> float:
	# Scratch keeps its approved wind-up/downstroke/recovery rhythm, including
	# the in-betweens. Changing only contact keys still changed how it felt.
	return time

static func stance_scale(name: String, elapsed: float) -> Vector2:
	var period := IDLE_SECONDS if name == "Idle" else CHARGE_SECONDS
	if name not in ["Idle", "Charge"]: return Vector2.ONE
	# Start and finish each loop at the neutral stance. Keep the feet as pivot.
	var weight := (1.0 - cos(TAU * maxf(0.0, elapsed) / period)) * 0.5
	var amount := 0.018 if name == "Idle" else 0.028
	return Vector2(1.0 - amount * weight * 0.5, 1.0 + amount * weight)
