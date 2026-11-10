extends RefCounted

# Display-only recovery. Spending/damage, new actors, and capacity changes snap immediately.
var value := 0.0
var target := 0.0
var origin := 0.0
var elapsed := 0.0
var duration := 0.22
var _identity := ""
var _capacity := -1.0

func step(actual: float,capacity: float,identity: String,dt: float) -> void:
	actual=clampf(actual,0.0,maxf(0.0,capacity))
	if identity!=_identity or capacity!=_capacity or actual<target:
		_identity=identity
		_capacity=capacity
		value=actual;target=actual;origin=actual;elapsed=duration
		return
	if actual>target:
		origin=value;target=actual;elapsed=0.0
	elapsed=minf(duration,elapsed+maxf(0.0,dt))
	var t := clampf(elapsed/maxf(0.001,duration),0.0,1.0)
	value=lerpf(origin,target,t*t*(3.0-2.0*t))

func ratio() -> float:
	return value/_capacity if _capacity>0.0 else 0.0
