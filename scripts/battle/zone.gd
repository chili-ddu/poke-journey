class_name Zone
extends Node2D

# 일정 시간 남는 장판.
#   smoke  연막. 안에 든 적을 느리게 하고 길을 잃게 한다(피해 없음).
#   static 전기파. 안에 든 상대를 마비시켜 느리게 한다(피해 없음).
#   fire_spin  전방으로 날아가 착지한 자리에서 매 턴 피해를 준다(FireSpinField).
#   petal  꽃잎댄스. ring 과 같이 치고, 플래티넘 petal_dance.spa 의 꽃잎들이 둘레를 춤추듯 돈다.

var kind := "static"
var team := Mon.TEAM_PLAYER
var radius := 40.0
var lifetime := 3.0
var age := 0.0
var follow: Mon = null
var hit := {}
var tick := 0.35
var next_hit := {}       # 적 instance id → 다음에 맞을 수 있는 age
var slow := 0.0
var dead := false

func step(dt: float) -> void:
	age += dt
	if follow != null and is_instance_valid(follow) and not follow.dead:
		position = follow.position
	if age >= lifetime:
		dead = true

func ready_to_hit(target: Mon) -> bool:
	var id := target.get_instance_id()
	if age < float(next_hit.get(id, 0.0)):
		return false
	next_hit[id] = age + tick
	return true

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var fade := clampf((lifetime - age) / 0.5, 0.0, 1.0)
	if kind == "static":
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.95, 0.4, 0.14 * fade))
		for i in 6:
			var a := float(i) / 6.0 * TAU + age * 9.0
			var p := Vector2(cos(a), sin(a) * 0.7) * radius * 0.7
			var q := p + Vector2(cos(a + 1.3), sin(a + 1.3)) * 6.0
			draw_line(p, q, Color(1.0, 0.9, 0.3, 0.9 * fade), 1.5)
			draw_line(q, q + Vector2(cos(a - 0.9), sin(a - 0.9)) * 5.0, Color(1.0, 1.0, 0.7, 0.9 * fade), 1.0)
	elif kind == "petal":
		var names := ["g4_petal_a", "g4_petal_b", "g4_petal_c"]
		for i in 12:
			var a := float(i) / 12.0 * TAU + age * 4.5
			var rr := radius * (0.75 + 0.25 * sin(age * 3.0 + i))
			var p := Vector2(cos(a), sin(a) * 0.75) * rr
			var tex := Fx.sheet(names[i % 3])
			if tex == null:
				draw_circle(p, 3.0, Color(1.0, 0.6, 0.7, 0.9 * fade))
				continue
			var sc := 9.0 / float(tex.get_width())
			draw_set_transform(p, age * 5.0 + i, Vector2(sc, sc))
			draw_texture(tex, -Vector2(tex.get_width(), tex.get_height()) / 2.0, Color(1, 1, 1, 0.95 * fade))
			draw_set_transform(Vector2.ZERO)
	elif kind == "ring" or (kind=="fire_spin" and not Look.view3d):
		# 회오리불꽃: 플래티넘 fire_spin.spa 의 불꽃·불덩이 텍스처가 둘레를 돈다.
		var flame := Fx.sheet("g4_flame")
		var puff := Fx.sheet("g4_fire_puff")
		for i in 10:
			var a := float(i) / 10.0 * TAU + age * 6.0
			var p := Vector2(cos(a), sin(a) * 0.75) * radius
			var flick := 1.0 + 0.3 * sin(age * 20.0 + i)
			if flame == null:
				draw_circle(p, 5.0 * flick, Color(1.0, 0.45, 0.1, 0.8 * fade))
				continue
			var tex := flame if i % 2 == 0 else puff
			var sc := (14.0 if i % 2 == 0 else 12.0) * flick / 32.0
			draw_set_transform(p, 0.0 if i % 2 == 0 else age * 3.0, Vector2(sc, sc))
			draw_texture(tex, Vector2(-16, -16), Color(1.0, 0.55, 0.15, 0.85 * fade))
			draw_texture(tex, Vector2(-16, -16), Color(1.0, 0.9, 0.4, 0.6 * fade))
			draw_set_transform(Vector2.ZERO)
