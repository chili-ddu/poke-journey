class_name Controllers
extends RefCounted

# 플레이어 입력원. World 는 아래 함수만 부른다.
#   move_dir(world) -> Vector2      이동 방향(길이 0~1)
#   aim_point(world) -> Vector2     조준 지점(월드 좌표)
#   want_skill(i, world) -> bool    i번 칸 기술을 쓰고 싶은가(누르고 있으면 쿨타임마다 연사)
#   want_jump(world) -> bool        점프(Space — 앞에 말 걸 사람이 있으면 대화가 먼저) — 없는 조작기는 안 뛴다
#   want_dodge(world) -> bool       회피
#   want_hotbar(n, world) -> bool   도구 편성 n번(0~3)을 쓰고 싶은가(World 가 has_method 로 확인)
#   want_item(world) -> bool        (봇·시험용 옛 이름) 오랭열매 먹기
# 사람 조작(사용자 결정 2026-11-02): 기술 Q·W·E·R(마우스 커서 쪽 — 방향키로 움직이는 중이면 바라보는 앞쪽), 이동은 방향키 또는 마우스 왼쪽 클릭(누른 자리로 걸어감,
# 누르고 있으면 커서를 따라감), 1·2·3·4 는 도구 편성. Space 는 대화·오브젝트(앞에 없으면 점프). 회피는 잠김(풀리면 Shift).
# (처음엔 WASD 이동·좌클릭/우클릭 기술 두 칸·Q 열매였다 — W·E 가 기술 키와 겹쳐 이동은 방향키로 옮겼다.)

const SKILL_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R]
const HOTBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const ACTIONS := {
	"move_up": [KEY_UP], "move_down": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT],
	"move_click": [MOUSE_BUTTON_LEFT],     # 처음엔 오른쪽 클릭 → 왼쪽 클릭(사용자 2026-11-02)
	"skill_0": [KEY_Q], "skill_1": [KEY_W], "skill_2": [KEY_E], "skill_3": [KEY_R],
	"item_0": [KEY_1], "item_1": [KEY_2], "item_2": [KEY_3], "item_3": [KEY_4],
	"jump": [KEY_SPACE],
	"dodge": [KEY_SHIFT],              # 회피는 잠겨 있다(Player.dodge_unlocked)
}

# 입력 맵을 코드로 등록한다. project.godot 에 직렬화된 InputEvent 를 손으로 쓰면 틀리기 쉬워서.
static func ensure_input_map() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in ACTIONS[action]:
			var ev: InputEvent
			if code in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				ev = InputEventMouseButton.new()
				ev.button_index = code
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = code
			InputMap.action_add_event(action, ev)

class Human:
	extends RefCounted

	# 왼쪽 클릭 이동: 누른 자리(바닥)로 곧장 걸어간다. 누르고 있으면 커서를 따라간다. 방향키를 누르면 그만둔다.
	# 벽에 막혀 0.3초 동안 거의 못 가면 그만둔다(길찾기는 없다 — 막히면 다시 찍는다).
	var target := Vector2.ZERO
	var has_target := false
	var _stuck_t := 0.0
	var _last := Vector2.INF
	const ARRIVE := 3.0
	# Mobile movement and keys are independent of physical keyboard state.
	var touch_move := Vector2.ZERO
	var touch_aim := Vector2.ZERO
	var touch_active := false
	var touch_owned := false
	var touch_keys := {}
	var _touch_pending := {}
	var _touch_frame := {}
	var pad_move := Vector2.ZERO
	var pad_aim := Vector2.ZERO
	var pad_active := false
	var pad_keys := {}
	var _pad_pending := {}
	var _pad_frame := {}

	func press_gamepad_key(code: int) -> void:
		_release_hold()
		if hold or pad_keys.has(code):return
		pad_keys[code] = true;_pad_pending[code] = true;pad_active = true

	func release_gamepad_key(code: int, cancelled: bool = false) -> void:
		pad_keys.erase(code)
		if cancelled:_pad_pending.erase(code);_pad_frame.erase(code)

	func clear_gamepad() -> void:
		pad_move = Vector2.ZERO;pad_aim = Vector2.ZERO;pad_active = false
		pad_keys.clear();_pad_pending.clear();_pad_frame.clear()

	func press_touch_key(code: int) -> void:
		_release_hold()
		if hold or touch_keys.has(code):return
		touch_keys[code] = true
		_touch_pending[code] = true
		touch_active = true

	func release_touch_key(code: int, cancelled: bool = false) -> void:
		touch_keys.erase(code)
		if cancelled:
			_touch_pending.erase(code)
			_touch_frame.erase(code)

	func clear_touch() -> void:
		touch_active = false
		touch_move = Vector2.ZERO
		touch_aim = Vector2.ZERO
		touch_owned = false
		touch_keys.clear()
		_touch_pending.clear()
		_touch_frame.clear()

	func move_dir(world) -> Vector2:
		_release_hold()  # Indoor movement must unlock even when skills are not polled.
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v != Vector2.ZERO:
			has_target = false
			return world.move_override.call(v) if world.move_override.is_valid() else v
		if touch_owned or touch_move != Vector2.ZERO:
			has_target = false
			return world.move_override.call(touch_move) if world.move_override.is_valid() else touch_move
		if pad_move!=Vector2.ZERO:
			has_target = false
			return world.move_override.call(pad_move) if world.move_override.is_valid() else pad_move
		if not hold and Input.is_action_pressed("move_click"):
			target = aim_point(world)          # 누른 자리 표시는 없다(사용자 2026-11-02)
			has_target = true
		if not has_target:
			return Vector2.ZERO
		var p: Vector2 = world.player.position
		var d := target - p
		if d.length() <= ARRIVE:
			has_target = false
			return Vector2.ZERO
		if _last != Vector2.INF and p.distance_to(_last) < 0.2:
			_stuck_t += 1.0 / 60.0
			if _stuck_t > 0.3:
				has_target = false
				_stuck_t = 0.0
				return Vector2.ZERO
		else:
			_stuck_t = 0.0
		_last = p
		return d.normalized() * clampf(d.length() / 8.0, 0.35, 1.0)

	# 조준(사용자 결정 2026-11-02): 방향키로 움직이는 중이면 바라보는 쪽(앞)으로, 마우스를 쓰는 중이면 커서 쪽으로.
	# 방향키를 누르면 '키 조준', 마우스를 움직이거나 클릭하면 '마우스 조준'으로 바뀐다.
	var key_aim := false
	var _last_mouse := Vector2.INF
	const KEY_AIM_REACH := 80.0

	func aim_point(world) -> Vector2:
		if touch_aim.length_squared()>0.0001:
			var direction: Vector2 = world.move_override.call(touch_aim) if world.move_override.is_valid() else touch_aim
			return world.player.position+direction.normalized()*KEY_AIM_REACH
		if pad_aim.length_squared()>0.0001:
			var direction: Vector2 = world.move_override.call(pad_aim) if world.move_override.is_valid() else pad_aim
			return world.player.position+direction.normalized()*KEY_AIM_REACH
		# Read the current L-stick before World updates facing for this frame.
		var left: Vector2 = touch_move if touch_owned or touch_move!=Vector2.ZERO else pad_move
		if left.length_squared()>0.0001:
			var direction: Vector2 = world.move_override.call(left) if world.move_override.is_valid() else left
			return world.player.position+direction.normalized()*KEY_AIM_REACH
		if touch_active and not pad_active:
			return world.player.position + world.player.facing * KEY_AIM_REACH
		var mouse: Vector2 = world.aim_override.call() if world.aim_override.is_valid() else world.get_global_mouse_position()
		var screen: Vector2 = world.get_viewport().get_mouse_position()
		if pad_active:
			if Input.is_action_pressed("move_click") or (_last_mouse!=Vector2.INF and screen.distance_to(_last_mouse)>2.0):pad_active = false
			else:
				_last_mouse = screen
				return world.player.position+world.player.facing*KEY_AIM_REACH
		if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
			key_aim = true
		elif Input.is_action_pressed("move_click") or (_last_mouse != Vector2.INF and screen.distance_to(_last_mouse) > 2.0):
			key_aim = false
		_last_mouse = screen
		if key_aim:
			var f: Vector2 = world.player.facing
			return world.player.position + (f.normalized() if f.length_squared() > 0.0001 else Vector2.DOWN) * KEY_AIM_REACH
		return mouse

	# 기술 네 칸: Q·W·E·R 을 누르고 있으면 그 칸(쿨타임마다 연사).
	# hold: 가방·상태창을 닫은 직후 — 키·마우스를 다 뗄 때까지 기술·이동을 받지 않는다(창 안에서 누른 것이 새지 않게).
	var _feedback_presses: Array[int] = []
	var _feedback_down: Array[bool] = [false, false, false, false]
	var hold := false:
		set(value):
			hold = value
			if value:
				_feedback_presses.clear() # No stale input after a modal closes.
				clear_touch()
				clear_gamepad()
	func _release_hold() -> void:
		if not hold:
			return
		for a in ["skill_0", "skill_1", "skill_2", "skill_3", "move_click"]:
			if a == "move_click" and touch_owned:continue
			if Input.is_action_pressed(a):
				return
		hold = false

	var _selection_event_frame := -1
	func record_skill_event(slot: int, world) -> void:
		_release_hold()
		if hold:return
		world.player.select_skill(slot)
		_selection_event_frame=Engine.get_process_frames()
		if slot>=0 and slot<Player.SLOT_COUNT and not _feedback_presses.has(slot):
			_feedback_presses.append(slot)

	# Fresh presses only, including release/repress events between world ticks.
	# Kept separate from want_skill(): holding a key still auto-fires normally.
	func consume_skill_presses(_world) -> Array[int]:
		_release_hold()
		var fresh: Array[int] = []
		if not hold: fresh.assign(_feedback_presses)
		_feedback_presses.clear()
		_touch_frame = {} if hold else _touch_pending.duplicate()
		_touch_pending.clear()
		_pad_frame = {} if hold else _pad_pending.duplicate()
		_pad_pending.clear()
		for presses in [_touch_frame,_pad_frame]:
			for code in presses:
				var slot := SKILL_KEYS.find(code)
				if slot>=0:
					_world.player.select_skill(slot)
					if not fresh.has(slot):fresh.append(slot)
		for i in Player.SLOT_COUNT:
			var down := Input.is_action_pressed("skill_%d" % i)
			if not hold and down and not _feedback_down[i] and not fresh.has(i): fresh.append(i)
			_feedback_down[i] = down
		return fresh

	func record_skill_input(world) -> void:
		_release_hold()
		if hold or _selection_event_frame==Engine.get_process_frames():return
		for i in Player.SLOT_COUNT:
			if Input.is_action_just_pressed("skill_%d"%i):world.player.select_skill(i)

	func want_skill(i: int, _world) -> bool:
		_release_hold()
		if hold:
			return false
		return touch_keys.has(SKILL_KEYS[i]) or _touch_frame.has(SKILL_KEYS[i]) or pad_keys.has(SKILL_KEYS[i]) or _pad_frame.has(SKILL_KEYS[i]) or Input.is_action_pressed("skill_%d" % i)

	func want_dodge(_world) -> bool:
		return _touch_frame.has(KEY_SHIFT) or Input.is_action_just_pressed("dodge")

	# 기술을 쓰면 클릭 이동을 멈춘다(사용자 2026-11-02) — World 가 기술을 쓴 직후 부른다.
	func stop_move() -> void:
		has_target = false

	# Space: 앞에 말 걸 사람·오브젝트가 있으면 대화(Game 이 받는다), 없으면 점프(사용자 결정 2026-11-02).
	func want_jump(world) -> bool:
		return (_touch_frame.has(KEY_SPACE) or _pad_frame.has(KEY_SPACE) or Input.is_action_just_pressed("jump")) and not world.talk_ready

	# 도구 편성 1~4: 누른 순간 한 번(이전 상태와 비교 — 누르고 있어도 한 개만).
	var _item_down := [false, false, false, false]
	func want_hotbar(n: int, _world) -> bool:
		var down := Input.is_action_pressed("item_%d" % n)
		var fire: bool = _touch_frame.erase(HOTBAR_KEYS[n]) or _pad_frame.erase(HOTBAR_KEYS[n]) or (down and not _item_down[n])
		_item_down[n] = down
		return fire

# 스모크 테스트·스크린샷용 봇. 잘 싸우는 것이 목적이 아니라
# 웨이브·레벨업·진화·보스 흐름을 끝까지 밟아 보는 것이 목적이다.
class Bot:
	extends RefCounted

	var strafe := 1.0
	var flip_t := 0.0

	func _nearest(world) -> Mon:
		var best: Mon = null
		var best_d := INF
		for e in world.alive_enemies():
			var d: float = e.position.distance_to(world.player.position)
			if d < best_d:
				best_d = d
				best = e
		return best

	func move_dir(world) -> Vector2:
		var p: Mon = world.player
		var target := _nearest(world)
		flip_t -= 1.0 / 60.0
		if flip_t <= 0.0:
			flip_t = 2.5
			strafe = -strafe
		var to_center: Vector2 = Vector2.ZERO if Arena.has_map() else (Arena.center() - p.position) / 200.0
		if target == null:
			return to_center.limit_length(1.0)
		var to_t: Vector2 = target.position - p.position
		var dist := to_t.length()
		var dir := to_t / maxf(dist, 0.001)
		var side := Vector2(-dir.y, dir.x) * strafe
		# 고른 기술이 닿는 거리를 유지한다(근접은 바싹, 탄은 사거리의 2/3). 예전 고정 70px 은 불꽃세례(3칸 72px) 밖에서 헛쏘게 했다.
		var want := 70.0
		var id: String = p.slots[p.selected_slot] if p.selected_slot >= 0 and p.selected_slot < p.slots.size() else ""
		if id != "":
			var m := MoveDB.get_move(id)
			match m["shape"]:
				"arc": want = p.radius + target.radius + float(m["range"]) * 0.5
				"projectile", "burst", "cone", "status_cone", "lob": want = float(m["range"]) * 0.65
				"ring": want = 30.0
		var radial := clampf((dist - want) / 30.0, -1.0, 1.0)
		return (dir * radial + side * 0.7 + to_center * 0.6).limit_length(1.0)

	func aim_point(world) -> Vector2:
		var target := _nearest(world)
		return target.position if target != null else world.player.position + Vector2.RIGHT

	func want_skill(i: int, world) -> bool:
		# 바꿔 끼우려고 PP 가 차길 기다리는 칸은 쓰지 않는다(Game._bot_maintain).
		if int(world.player.get_meta("bot_hold_slot", -1)) == i:
			return false
		var target := _nearest(world)
		if target == null:
			return false
		var id: String = world.player.slots[i]
		var m := MoveDB.get_move(id)
		var dist: float = target.position.distance_to(world.player.position)
		match m["shape"]:
			"arc":
				return dist - world.player.radius - target.radius < float(m["range"])
			"dash", "ring":
				return dist < 70.0
			"lob":
				# 던지는 변화기(연막): 사거리 안이고 아직 안 내려간 상대에게만.
				if dist > float(m["range"]) + float(m["radius"]):
					return false
				for key in m.get("stat", {}):
					if int(target.get(key + "_stage")) <= -2:
						return false
				return true
			"status_cone":
				# 변화기는 아직 안 내려간 상대에게 사거리 안에서만(울음소리를 연발하다 죽지 않게).
				if dist - world.player.radius - target.radius > float(m["range"]):
					return false
				for key in m.get("stat", {}):
					if int(target.get(key + "_stage")) <= -2:
						return false
				return true
		return true

	# 봇은 HP 가 절반 아래면 열매를 먹는다.
	func want_item(world) -> bool:
		return world.player.hp_ratio() < 0.5

	func want_dodge(world) -> bool:
		var p: Mon = world.player
		for pr in world.projectiles:
			if pr.team == Mon.TEAM_ENEMY and pr.position.distance_to(p.position) < 28.0:
				return true
		return false
