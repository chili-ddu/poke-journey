extends SceneTree

# 바깥 세계 스모크: 오박사 연구소에서 시작 → 문으로 나가(암전·장면 재로드) 태초마을 → 1번도로까지 걸어가 야생 포켓몬이 구역별로 나오는지 본다.
# 고정 dt 로 pump 하고, 걷기는 플레이어 위치를 직접 옮긴다(충돌은 Arena.resolve 가 막는다).
#
#   godot --headless --path . -s tools/overworld_smoke.gd

const DT := 1.0 / 60.0
var game: Node

func _init() -> void:
	OS.set_environment("BOT", "1")
	OS.set_environment("SEED", "3")
	OS.set_environment("DUNGEON", "oaks_lab")
	SaveData.path = "user://save_overworld_smoke.cfg"
	SaveData.clear()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game          # 문 전환이 reload_current_scene 을 쓴다
	game.set_process(false)
	await process_frame
	print("시작: %s mode=%s state=%s tile=%s" % [DungeonDB.current, game.mode, game.state, Arena.tile_of(game.world.player.position)])
	assert(game.mode == "indoor" and game.world.no_skills)
	# 문(6,12)으로 두 칸 내려간다.
	OS.set_environment("DUNGEON", "")
	_pump(0.2)
	game.world.player.position = Arena.tile_center(Vector2i(6, 12))
	_pump(0.05)
	print("문 위: state=%s destination=%s" % [game.state, str(game.destination)])
	assert(game.state == "warp")
	# 암전 트윈이 장면을 다시 연다: 실시간 트윈이라 몇 프레임 기다린다.
	for i in 40:
		await process_frame
	game = current_scene
	game.set_process(false)
	await process_frame
	var pt := Arena.tile_of(game.world.player.position)
	print("밖: %s mode=%s state=%s tile=%s area=%s" % [DungeonDB.current, game.mode, game.state, pt, Arena.area_at(game.world.player.position)])
	assert(DungeonDB.current == "kanto_south" and pt == Arena.area_tile("pallet_town", Vector2i(16, 14)), "나오면 문(16,13) 앞 한 칸")
	# 위층(지붕) 행 캐시가 연구소 것으로 남아 있으면 마을 지붕이 안 그려진다.
	assert(Arena.top_row_has_pixels(84), "태초마을 집 지붕 행이 위층에 있다")
	# 문 앞에 서 있으면 되돌아가지 않는다.
	_pump(0.5)
	assert(game.state == "fight", "도착한 문은 내려선 뒤에야 열린다: " + game.state)
	# 태초마을엔 출현표가 없어 적이 안 나온다.
	_pump(8.0)
	print("마을 8초: 적 %d" % game.world.remaining())
	assert(game.world.remaining() == 0)
	# 1번도로 가운데로 걸어 올라간다(위치를 직접 옮김). 40초 동안 야생에게 쓰러지지 않게 무적(흐름 확인용).
	game.world.god = true
	game.world.player.position = Arena.tile_center(Arena.area_tile("route1", Vector2i(10, 18)))
	var seen := {}
	var maxc := 0
	var t := 0.0
	while t < 40.0:
		game.advance(DT)
		t += DT
		maxc = maxi(maxc, game.world.remaining())
		for e in game.world.alive_enemies():
			seen[e.species_id + " Lv" + str(e.level)] = true
	print("1번도로 40초: 동시 최대 %d, 본 포켓몬 %s, 남은 %d, HP %d/%d, 이름표 %s" % [maxc, seen.keys(), game.world.remaining(), game.world.player.hp, game.world.player.max_hp, game.location_name()])
	assert(maxc >= 1, "1번도로에서 야생이 나온다")
	# 쫓아오던 야생은 마을로 들어서면 도망친다.
	if game.world.remaining() == 0:
		game.world.queue_spawn("rattata", 3)
		var tw := 0.0
		while tw < 3.0 and game.world.remaining() == 0:      # 나올 때까지(봇이 바로 잡아 버리면 다시)
			game.advance(DT)
			tw += DT
			if game.world.remaining() == 0 and game.world.pending_spawns.is_empty():
				game.world.queue_spawn("rattata", 3)
	var before: int = game.world.remaining()
	game.world.player.position = Arena.tile_center(Arena.area_tile("pallet_town", Vector2i(10, 4)))     # 태초마을 북쪽
	_pump(0.2)
	print("마을로 들어섬: 야생 %d → %d, 구역 %s" % [before, game.world.remaining(), Arena.area_at(game.world.player.position)])
	assert(before > 0 and game.world.remaining() == 0, "마을에선 야생이 사라진다")
	game.world.player.position = Arena.tile_center(Arena.area_tile("route1", Vector2i(10, 18)))
	_wild_stats()
	assert(seen.size() >= 1)
	# 봇은 저장하지 않는다(사람 플레이의 저장 왕복은 test_rules 가 본다).
	assert(not SaveData.exists())
	_ledge_probe()
	_berry_probe()
	await _route2_probe()
	await _pewter_probe()
	SaveData.clear()          # 간호순이 적은 부활 자리(시험용 파일)를 지운다
	print("OK")
	quit()

func _pump(sec: float) -> void:
	var t := 0.0
	while t < sec:
		game.advance(DT)
		t += DT

# 조종을 대본대로: mv 방향으로 걷고 jump 가 켜진 한 프레임만 점프(회피는 안 씀).
class Scripted:
	extends RefCounted
	var mv := Vector2.ZERO
	var jump := false
	var item := false
	func want_item(_w) -> bool:
		var d := item
		item = false
		return d
	func move_dir(_w) -> Vector2: return mv
	func aim_point(w) -> Vector2: return w.player.position + (mv if mv != Vector2.ZERO else Vector2.DOWN) * 40.0
	var dodge := false
	func want_dodge(_w) -> bool:
		var d := dodge
		dodge = false
		return d
	func want_jump(_w) -> bool:
		var d := jump
		jump = false
		return d
	func want_skill(_i, _w) -> bool: return false

# 언덕(사용자 결정 2026-10-28): 걸어 내려가면 자동 점프, 걸어 올라가면 막힘, 점프 키로는 올라간다.
# 점프는 Hop 동작(0.4초) 내내 두 칸(48px)을 날고, 언덕을 넘으면 시작 칸에서 정확히 두 칸 앞(언덕 바로 다음 칸) 가운데에 내려앉는다.
# 내려앉을 칸이 막혔거나 언덕이면(대각선 포함) 점프하지 않는다.
func _ledge_probe() -> void:
	var ledge := Vector2i(-1, -1)
	var r1 := Arena.area_rect("route1")
	for ty in range(r1.position.y, r1.end.y):
		for tx in range(r1.position.x, r1.end.x):
			if Arena.ledge_at(tx, ty) == Arena.LEDGE_CODES["s"] and not Arena.solid_at(tx, ty - 1) and Arena.ledge_at(tx, ty - 1) == 0 and not Arena.solid_at(tx, ty + 1) and Arena.ledge_at(tx, ty + 1) == 0 and not Arena.solid_at(tx, ty - 2) and Arena.ledge_at(tx, ty - 2) == 0:
				ledge = Vector2i(tx, ty)
		if ledge.x >= 0:
			break
	assert(ledge.x >= 0)
	for e in game.world.alive_enemies():
		e.hp = 0
		e.dead = true
	var ctl := Scripted.new()
	var p: Player = game.world.player
	p.controller = ctl
	var above := Arena.tile_center(ledge + Vector2i.UP)
	var below := Arena.tile_center(ledge + Vector2i.DOWN)
	# 1) 위에서 아래로 걷기 → 저절로 뛰어내려 언덕 바로 아래 칸 가운데.
	p.position = above
	ctl.mv = Vector2.DOWN
	_pump_until_hop(p, 1.0)
	ctl.mv = Vector2.ZERO
	_pump(0.6)
	print("언덕 내려가기: %s (아래 칸 가운데 %s)" % [p.position, below])
	assert(p.position.distance_to(below) < 0.6, "언덕 바로 아래 칸에 내려선다")
	# 2) 아래에서 위로 걷기 → 막힌다.
	ctl.mv = Vector2.UP
	_pump(1.0)
	print("언덕 올라가기(걷기): y=%.0f" % p.position.y)
	assert(p.position.y > float(ledge.y + 1) * Arena.TILE - 1.0, "걸어서는 못 올라간다")
	# 3) 점프 키 → 언덕 바로 위 칸 가운데로.
	p.position = below
	ctl.jump = true
	_pump(1.0 / 60.0)
	ctl.mv = Vector2.ZERO
	_pump(0.6)
	print("언덕 올라가기(점프): %s (위 칸 가운데 %s)" % [p.position, above])
	assert(p.position.distance_to(above) < 0.6, "점프로 올라가 바로 위 칸에")
	# 4) 두 칸 떨어져서 뛰면 언덕 위에 떨어지게 되므로 막힌다.
	p.position = Arena.tile_center(ledge + Vector2i.UP * 2)
	ctl.mv = Vector2.DOWN
	ctl.jump = true
	_pump(1.0 / 60.0)
	ctl.mv = Vector2.ZERO
	print("두 칸 떨어져 점프: 돌진 %s" % str(not p.dash.is_empty()))
	assert(p.dash.is_empty() and p.hop_t <= 0.0, "언덕에 내려앉는 점프는 막힌다")
	# 5) 평지 점프: 정확히 48px, 0.4초 동안 날아간다.
	var flat := Arena.tile_center(Arena.area_tile("route1", Vector2i(10, 18)))
	p.position = flat
	ctl.mv = Vector2.RIGHT
	ctl.jump = true
	_pump(1.0 / 60.0)
	ctl.mv = Vector2.ZERO
	_pump(0.3)
	var mid_flight := not p.dash.is_empty()
	_pump(0.3)
	print("평지 점프: %.1fpx, 0.3초 뒤에도 공중 %s" % [p.position.distance_to(flat), str(mid_flight)])
	assert(absf(p.position.distance_to(flat) - Player.JUMP_DISTANCE) < 1.0 and mid_flight)
	# 6) 대각선: 언덕 너머 착지 칸이 막혔으면 막히고, 열려 있으면 그 칸 가운데에.
	var bad := Vector2i(-1, -1)
	var good := Vector2i(-1, -1)
	var r1d := Arena.area_rect("route1")
	for ty in range(r1d.position.y, r1d.end.y):
		for tx in range(r1d.position.x + 1, r1d.end.x - 1):
			if Arena.ledge_at(tx, ty) != Arena.LEDGE_CODES["s"]:
				continue
			var a := Vector2i(tx - 1, ty - 1)
			if Arena.solid_at(a.x, a.y) or Arena.ledge_at(a.x, a.y) != 0:
				continue
			var land := Vector2i(tx + 1, ty + 1)
			var land_bad := Arena.solid_at(land.x, land.y) or Arena.ledge_at(land.x, land.y) != 0
			if land_bad and bad.x < 0:
				bad = a
			elif not land_bad and good.x < 0 and not Arena.solid_at(tx, ty):
				good = a
	print("대각선 시험 자리: 막힘 %s, 열림 %s" % [bad, good])
	if bad.x >= 0:
		p.position = Arena.tile_center(bad)
		ctl.mv = Vector2(1, 1).normalized()
		ctl.jump = true
		_pump(1.0 / 60.0)
		ctl.mv = Vector2.ZERO
		assert(p.dash.is_empty(), "대각선 착지 칸이 막혔으면 점프 안 함")
	if good.x >= 0:
		p.position = Arena.tile_center(good)
		ctl.mv = Vector2(1, 1).normalized()
		ctl.jump = true
		_pump(1.0 / 60.0)
		ctl.mv = Vector2.ZERO
		_pump(0.6)
		print("대각선 점프: %s (목표 %s)" % [p.position, Arena.tile_center(good + Vector2i(2, 2))])
		assert(p.position.distance_to(Arena.tile_center(good + Vector2i(2, 2))) < 0.6, "대각선으로 언덕 너머 칸 가운데에")
	# 7) 점프는 무적·쿨타임 없음: 뛰는 순간 무적이 아니고, 내려앉자마자 다시 뛸 수 있다.
	p.position = flat
	p.invuln_t = 0.0
	ctl.mv = Vector2.RIGHT
	ctl.jump = true
	_pump(1.0 / 60.0)
	var jump_invuln := p.invuln_t
	ctl.mv = Vector2.ZERO
	_pump(0.5)
	ctl.mv = Vector2.LEFT
	ctl.jump = true
	_pump(1.0 / 60.0)
	ctl.mv = Vector2.ZERO
	print("점프 무적 %.2f, 내려앉자마자 다시 점프 %s" % [jump_invuln, str(not p.dash.is_empty())])
	assert(jump_invuln == 0.0 and not p.dash.is_empty(), "점프는 무적·쿨타임 없음")
	_pump(0.5)
	# 8-0) 회피는 잠겨 있다: 우클릭해도 아무 일도 없다.
	p.position = flat
	p.dodge_cd = 0.0
	ctl.mv = Vector2.RIGHT
	ctl.dodge = true
	_pump(1.0 / 60.0)
	ctl.mv = Vector2.ZERO
	print("회피 잠금: 돌진 %s, 무적 %.2f" % [str(not p.dash.is_empty()), p.invuln_t])
	assert(p.dash.is_empty() and p.dodge_cd == 0.0, "잠겨 있으면 회피 안 됨")
	# 8) 회피(우클릭, 시험만 잠깐 열고): 64px 를 0.2초에, 무적·쿨타임 1.2초, 쿨타임 중엔 다시 안 됨.
	Player.dodge_unlocked = true
	p.position = flat
	p.dodge_cd = 0.0
	p.invuln_t = 0.0
	ctl.mv = Vector2.RIGHT
	ctl.dodge = true
	_pump(1.0 / 60.0)
	ctl.mv = Vector2.ZERO
	var dodge_invuln := p.invuln_t
	var trail := bool(p.dash.get("trail", false))
	_pump(0.3)
	var moved := p.position.distance_to(flat)
	var before := p.position
	ctl.dodge = true
	_pump(0.3)
	print("회피: %.1fpx, 무적 %.2f, 잔상 %s, 쿨타임 중 재회피 이동 %.1f" % [moved, dodge_invuln, str(trail), p.position.distance_to(before)])
	assert(absf(moved - Player.DODGE_DISTANCE) < 1.0 and dodge_invuln > 0.2 and trail, "회피 64px·무적·잔상")
	assert(p.position.distance_to(before) < 0.5, "쿨타임 중엔 회피 안 됨")
	# 9) 회피는 언덕을 못 넘는다.
	p.position = above
	p.dodge_cd = 0.0
	ctl.mv = Vector2.DOWN
	ctl.dodge = true
	_pump(1.0 / 60.0)
	ctl.mv = Vector2.ZERO
	_pump(0.3)
	print("언덕 쪽 회피: y=%.0f (언덕 윗변 %.0f)" % [p.position.y, float(ledge.y) * Arena.TILE])
	assert(p.position.y < float(ledge.y) * Arena.TILE, "회피는 언덕에서 멈춘다")
	Player.dodge_unlocked = false
	ctl.mv = Vector2.ZERO

func _pump_until_hop(p: Player, limit: float) -> void:
	var t := 0.0
	while t < limit and p.dash.is_empty():
		game.advance(DT)
		t += DT

# 열매: 닿으면 가방에(바로 안 먹음) → Q 로 먹으면 0.4초 뒤 HP 10 → 가방이 가득이면 바닥에 남는다(사용자 결정 2026-10-28).
func _berry_probe() -> void:
	var w: World = game.world
	var p: Player = w.player
	var ctl = p.controller
	p.berries = 0
	p.hp = 5
	w.drops.append({"pos": p.position, "t": 5.0, "item": "oran_berry"})
	_pump(0.1)
	print("열매 줍기: 가방 %d, HP %d" % [p.berries, p.hp])
	assert(p.berries == 1 and p.hp == 5, "주우면 가방에만 들어간다")
	# 멈춰서 먹기: 즉시 HP 10, 먹기 동작이 나온다.
	ctl.mv = Vector2.ZERO
	ctl.item = true
	_pump(1.0 / 60.0)
	print("멈춰서 먹기: 가방 %d, HP %d, 먹기 동작 %.2f초" % [p.berries, p.hp, p.eat_t])
	assert(p.berries == 0 and p.hp == 15, "누르는 즉시 HP 10 회복")
	assert(p.eat_t > 0.0, "멈춰 있으면 먹기 동작")
	# 움직이면 바로 풀린다.
	ctl.mv = Vector2.RIGHT
	_pump(1.0 / 60.0)
	assert(p.eat_t == 0.0, "움직이면 먹기 동작이 풀린다")
	# 이동 중에 먹기: 회복만, 동작 없음.
	p.berries = 1
	p.berry_cd = 0.0
	p.hp = 5
	ctl.item = true
	_pump(1.0 / 60.0)
	print("이동 중 먹기: HP %d, 먹기 동작 %.2f초, 속도 %.0f" % [p.hp, p.eat_t, p.vel.length()])
	assert(p.hp == 15 and p.eat_t == 0.0, "이동 중엔 동작 없이 회복만")
	assert(p.vel.length() >= p.move_speed() * 0.99, "먹어도 느려지지 않는다")
	ctl.mv = Vector2.ZERO
	p.berries = Player.BERRY_MAX
	w.drops.append({"pos": p.position, "t": 5.0, "item": "oran_berry"})
	_pump(0.1)
	print("가방 가득: 가방 %d, 바닥 %d" % [p.berries, w.drops.size()])
	assert(p.berries == Player.BERRY_MAX and w.drops.size() == 1, "가득 차면 바닥에 남는다")
	w.drops.clear()

# 출현 통계(사용자 결정 2026-10-28: 원작 공식 0.5초 = 한 걸음, 살아 있는 수 + 1 로 나눔, 상한 없음): 무적으로 가만히 5분 서서
# 첫 출현까지 걸린 시간, 마리 수가 늘어나는 시각을 찍는다.
func _wild_stats() -> void:
	var w: World = game.world
	for e in w.alive_enemies():
		e.hp = 0
		e.dead = true
	_pump(1.0)
	w.god = true
	var ctl := Scripted.new()
	var saved_ctl = w.player.controller
	w.player.controller = ctl
	w.player.position = Arena.tile_center(Arena.area_tile("route1", Vector2i(10, 18)))
	game.wild_since = 0.0
	game.wild_buff = 0.0
	var t := 0.0
	var reached := {}
	while t < 300.0:
		game.advance(DT)
		t += DT
		var n := w.remaining()
		if not reached.has(n):
			reached[n] = snappedf(t, 0.1)
	print("출현 통계(5분, 가만히·무적): 마리 수가 처음 된 시각 %s" % str(reached))
	assert(reached.has(1), "5분 안에 첫 출현")
	w.god = false
	w.player.controller = saved_ctl
	for e in w.alive_enemies():
		e.hp = 0
		e.dead = true
	_pump(1.0)

# 2번도로 → 남쪽 관문 → 상록숲 → 북쪽 관문 → 2번도로 북쪽 → 회색시티(사용자 요청 2026-10-28). 문 칸에 차례로 서서 지나간다.
func _route2_probe() -> void:
	for e in game.world.alive_enemies():
		e.hp = 0
		e.dead = true
	game.world.player.position = Arena.tile_center(Arena.area_tile("route2", Vector2i(5, 52)))   # 남쪽 관문 문 바로 아래
	await _through(Arena.area_tile("route2", Vector2i(5, 51)))
	print("2번도로 남쪽 문 → %s" % DungeonDB.current)
	assert(DungeonDB.current == "forest_gate_south")
	await _through(Vector2i(7, 1))
	print("관문 → %s %s" % [DungeonDB.current, Arena.tile_of(game.world.player.position)])
	assert(DungeonDB.current == "viridian_forest" and game.mode == "overworld")
	assert(DungeonDB.area_cfg(Arena.area_at(game.world.player.position)).has("encounters"), "상록숲은 출현표가 있는 바깥 세계")
	await _through(Vector2i(5, 9))
	print("상록숲 북쪽 → %s" % DungeonDB.current)
	assert(DungeonDB.current == "forest_gate_north")
	await _through(Vector2i(7, 1))
	print("북쪽 관문 → %s 구역 %s" % [DungeonDB.current, Arena.area_at(game.world.player.position)])
	assert(DungeonDB.current == "kanto_south" and Arena.area_at(game.world.player.position) == "route2")
	# 2번도로 북쪽 끝에서 회색시티로 걸어 들어간다(끊김 없음).
	var into := Arena.area_tile("pewter_city", Vector2i(24, 38))
	game.world.player.position = Arena.tile_center(into)
	_pump(0.1)
	print("회색시티: 구역 %s, 이름표 %s" % [Arena.area_at(game.world.player.position), game.location_name()])
	assert(Arena.area_at(game.world.player.position) == "pewter_city")

# 회색시티 건물(사용자 요청 2026-10-28): 문마다 들어갔다 나온다. 센터는 간호순 회복·부활 자리까지.
func _pewter_probe() -> void:
	var doors := [[Vector2i(17, 25), "pewter_center", Vector2i(7, 8)], [Vector2i(28, 18), "pewter_mart", Vector2i(4, 7)],
		[Vector2i(15, 16), "pewter_gym", Vector2i(6, 14)], [Vector2i(33, 11), "pewter_house1", Vector2i(4, 7)],
		[Vector2i(9, 30), "pewter_house2", Vector2i(4, 7)]]
	for d in doors:
		var door: Vector2i = Arena.area_tile("pewter_city", d[0])
		await _through(door)
		print("회색시티 문 %s → %s" % [d[0], DungeonDB.current])
		assert(DungeonDB.current == d[1], "문이 열려 %s 로" % d[1])
		if d[1] == "pewter_center":
			var n = null
			for npc in game.world.npcs:
				game.world.player.position = Arena.tile_center(npc.talk_tile)
				n = game.npc_in_reach()
			assert(n != null, "간호순 앞")
			game.world.player.hp = 1
			game._talk(n)
			# 대사(봇은 0.4초마다 넘김) + 회복 연출 + 끝 인사가 다 끝날 때까지.
			for i in 1200:
				_pump(1.0 / 60.0)
				if game.state == "town" and game.heal.is_empty() and game.world.player.hp == game.world.player.max_hp:
					break
			print("  간호순: HP %d/%d, 부활 자리 %s" % [game.world.player.hp, game.world.player.max_hp, SaveData.load_saved().get("respawn_map", "")])
			assert(game.world.player.hp == game.world.player.max_hp)
		if d[1] == "pewter_mart":
			assert(game.world.npcs.size() == 1 and game.world.npcs[0].talk == "shop", "점원")
		await _through(d[2], Vector2i.UP)
		print("  나옴 → %s %s" % [DungeonDB.current, Arena.tile_of(game.world.player.position)])
		assert(DungeonDB.current == "kanto_south" and Arena.area_at(game.world.player.position) == "pewter_city")
	# 박물관: 1층(문 0) → 2층 계단 → 1층 → 다른 문(1)으로 나옴.
	await _through(Arena.area_tile("pewter_city", Vector2i(17, 6)))
	assert(DungeonDB.current == "pewter_museum_1f")
	await _through(Vector2i(8, 8), Vector2i.UP)
	print("박물관 계단 → %s" % DungeonDB.current)
	assert(DungeonDB.current == "pewter_museum_2f")
	await _through(Vector2i(11, 8), Vector2i.UP)
	assert(DungeonDB.current == "pewter_museum_1f")
	await _through(Vector2i(22, 9), Vector2i.UP)
	print("박물관 동쪽 문 → %s %s" % [DungeonDB.current, Arena.tile_of(game.world.player.position)])
	assert(DungeonDB.current == "kanto_south" and Arena.tile_of(game.world.player.position) == Arena.area_tile("pewter_city", Vector2i(25, 5)), "박물관 동쪽 문(25,4) 앞 한 칸")

# 문 칸 하나를 지난다: 한 칸 아래에서 문을 열 준비(warp_armed)를 하고 문 위에 선 뒤 암전·장면 바뀜을 기다린다.
func _through(tile: Vector2i, arm := Vector2i.DOWN) -> void:
	game.world.player.position = Arena.tile_center(tile + arm)     # 건물 안 출구 매트는 아래가 벽이라 위(arm=UP)에서 준비한다
	_pump(0.1)
	game.world.player.position = Arena.tile_center(tile)
	_pump(0.05)
	var old = game
	for i in 40:
		await process_frame
	# 큰 지도는 다시 읽는 데 더 걸린다: 새 장면이 뜰 때까지 기다린다.
	for i in 300:
		if current_scene != null and current_scene != old and is_instance_valid(current_scene):
			break
		await process_frame
	game = current_scene
	game.set_process(false)
	await process_frame
