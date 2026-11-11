class_name World
extends Node2D

const BattleContact = preload("res://scripts/battle/battle_contact.gd")
const FireField = preload("res://scripts/battle/fire_spin_field.gd")
const KantoMoveFx=preload("res://scripts/battle/kanto_move_fx.gd")
const AreaAim=preload("res://scripts/battle/aim_assist.gd")
var area_aim := AreaAim.new()
const AREA_CHARGE_TIME := .8
const AREA_MIN_RANGE := float(Arena.TILE)
var _area_charge: Dictionary = {}
var _area_suppressed_slots: Dictionary = {}

# 아레나 안의 모든 것을 한 걸음(step)씩 진행시킨다.
# 엔진의 _process 가 아니라 game.gd 가 step(dt) 을 직접 부른다 —
# 레벨업 창이 떠 있는 동안 멈추고, 스모크 테스트에서 실시간을 기다리지 않고 돌리려고.

signal enemy_defeated(enemy: Enemy, exp: int)
signal status_message(text: String)
signal inventory_changed
signal player_grass_rustled
signal player_move_used(move_id: String)
signal player_fainted
signal lured            # 달콤한향기를 썼다(바깥 풀숲이면 Game 이 야생을 하나 부른다)

# 적이 주는 피해 배율. 원작 공식 그대로(1배). 대신 모든 공격에 준비 동작을 둬서 보고 피하게 한다.
# (처음엔 0.5/0.35 로 깎았다가 2026-10-26 사용자 결정으로 1배.)
const ENEMY_DAMAGE_MULT := 1.0
const CONTACT_POWER := 30.0
const SPAWN_DELAY := 1.0
# 쓰러진 야생은 원작 지닌 물건에 더해 전투용 열매·상태 회복 열매를 확률적으로 떨어뜨린다.
const DROP_LIFE := 20.0
# 경험치 원작식 ⌊b·L/7⌋에 LevelProgression의 기본 0.5와 레벨 차이 보정을 적용한다.
# 관장·전용 이벤트의 no_exp는 먼저 처리하며, 체력·공격 피해 계산과는 독립이다.
const ZONE_CAST_RANGE := 5.0 * Arena.TILE   # 연막을 던지는 거리: 풀숲 5칸
const TEXT_COOLDOWN := 0.5
var _horn_flip := false          # 연속찌르기 뿔 타격의 좌우 번갈이
# 넉백·경직(사용자 결정 2026-10-30, 공식 3-②·B안):
#   물리기: 미끄러지는 거리 = 기본 3칸(나도 같다) × 2x/(1+x), x = (내 공격 ÷ 상대 방어) × √(내 몸무게 ÷ 상대 몸무게). 랭크 반영.
#           2x/(1+x) 는 힘이 같으면 1, 아무리 차이 나도 2 를 넘지 않는 포화 곡선 — 최대값을 따로 두지 않아도 알맞게 멈춘다.
#   특수기: 밀지 않고 그 자리에서 굳는다(flinch_t). 경직 = STUN_BASE × 2y/(1+y), y = 내 특공 ÷ 상대 특방(랭크 반영) — 같으면 0.4초, 상한 0.8초. 내가 맞으면 절반.
#   쓰러질 때: 물리기면 다 밀려난 뒤 넘어지고, 특수기면 경직 자세로 Mon.DIE_STUN(0.3초) 버틴 뒤 넘어진다(Mon.dying_t).
#   원거리 물리기(투사체·연발·부채꼴 탄·빔·던지기)는 위 거리의 절반(사용자 결정 2026-11-09).
#   기술이 넉백을 따로 정한 것(연속찌르기 knock 30)은 그대로, 원거리 물리기에는 같은 거리 보정을 적용한다.
const KNOCK_TILES := 3.0              # 밀리는 기본 거리(칸). 나도 같다(사용자 결정 2026-10-30: 0.6칸 따로 두지 않음) — 비율이 공격·방어·몸무게로 갈린다
const RANGED_PHYSICAL_KNOCK_DISTANCE := 0.5
const RANGED_KNOCK_SHAPES := ["projectile", "burst", "cone", "beam", "lob"]
# 히트스톱(사용자 결정 2026-11-02, 추천안): 맞는 순간 맞은 쪽(근접이면 때린 쪽도)이 잠깐 멈춘다 — 나머지 세계와 이펙트는 그대로.
#   근접 물리기(arc·burrow·dash) 0.14초, 투사체·특수기 0.07초, 연타기(기술이 넉백을 따로 정한 것) 0.03초, 쓰러뜨리는 타 0.2초, 급소 ×1.5. 내가 맞을 때도 같다.
const CONTACT_IMPACT_MOVES := ["scratch", "tackle", "pound", "peck", "astonish"]
const HITSTOP_CONTACT := 0.07
const IMPACT_CAMERA_DURATION := 0.10
var impact_camera_t := 0.0
var impact_camera_strength := 0.0
var impact_camera_direction := Vector2.DOWN
const HITSTOP_MELEE := 0.14
const HITSTOP_RANGED := 0.07
const HITSTOP_MULTI := 0.03
const HITSTOP_KILL := 0.2
const HITSTOP_CRIT := 1.5
const STUN_BASE := 0.4                # 특공·특방이 같을 때의 경직(초). 포화 곡선이라 두 배(0.8초)를 넘지 않는다
const ATTACK_MOVE_FACTOR := 0.3   # 기술을 쓰는 동안(attack_anim_t) 이동이 이만큼으로 줄어든다 — 때리면서 달리지 못하게

# Archived comparison scenes can opt out of live clashes.
var combat_clashes := true
const MELEE_CONTACT_WINDOW := 0.012

var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()   # 연출 전용(이로치 반짝임 등). 전투 난수(rng)를 건드리지 않게
var field_water := FieldWater.new()
var player: Player
var enemies: Array = []
var projectiles: Array = []
var zones: Array = []
var fxs: Array = []
const LOOT_BATCH_TIME := 0.18
const LOOT_MERGE_RADIUS := 24.0
var _loot_notices := {}
var _loot_notice_time := 0.0
var _loot_flights := {}
var drops: Array[LootItem] = [] # 원본 도구 아이콘: 낙하 → 바닥 → 주인공에게 입수
var bystanders: Array[Mon] = [] # Visible Pokémon waiting outside combat; never AI targets.
var npcs: Array = []            # 지도 위 사람(Npc: 간호순·점원·트레이너) — Game 이 장소 데이터대로 세운다
# 트레이너 배틀(사용자 결정 2026-10-29): 그 자리에서 싸우고, 배틀 중엔 battle_center 둘레 battle_radius 밖으로 못 나간다(원작도
# 트레이너 배틀은 도망칠 수 없다). INF 면 배틀 아님. 배틀 중엔 상대가 잠깐 없어도(다음 포켓몬을 내보내기 전) 랭크를 초기화하지 않는다.
var battle_center := Vector2.INF
var battle_radius := 0.0
var arena_cam := false          # 경기장: 카메라가 나와 상대 사이를 비춘다(Game 이 켬)
var cam_pos := Vector2.ZERO
var hold_cam := false           # step_visual 이 카메라를 건드리지 않게(Game 이 직접 움직이는 동안 — 트레이너가 포켓몬을 내보낼 때)
var pending_spawns: Array = []  # { species, level, pos, t }
var bursts: Array = []          # { mon, move, left, t, hit }
var pending_melee: Array = []   # { mon, move, hit, dir, t } 뛰어드는 동작이 닿을 때 판정
var pending_calls: Array = []   # { t, call } t 초 뒤에 부를 것(연막 공이 떨어지는 순간 등)
var no_skills := false          # 허브 마을: 걷기·점프만(기술은 안 나간다)
var hub := false                # 바깥 세계·건물 안(던전이 아님) — 동굴탈출로프를 못 씀
var overworld := false          # 바깥 세계 — 스프레이를 쓸 수 있음
var pending_casts: Array = []   # { mon, move, t } 힘을 모은 뒤 발사(플레이어의 Charge 기술)
var _volley_seq := 0            # 연발 묶음 번호
var pending_beams: Array = []   # { mon, hit, from, dir, len, t } 실이 다 늘어난 순간 닿은 상대에게 적용
var aim_point := Vector2.ZERO
var talk_ready := false         # 앞에 말 걸 사람·오브젝트가 있다(Game 이 매 프레임 정한다) — Space 가 점프 대신 대화
var move_override := Callable()  # Screen-relative directional movement in the 3D view.
var aim_override := Callable()   # 3D 화면(View3D)일 때 마우스가 가리키는 바닥 자리를 돌려준다 — 없으면 2D 마우스 자리
var cam: Camera2D = null
const CAM_ZOOM := 1.0          # 뷰포트 384×216 = 월드 px. 타일 24 → 한 화면 16×9칸(원작 GBA 15×10 에 가장 가까운 16:9)
var god := false              # 흐름 테스트용: 플레이어가 피해를 받지 않는다
var weather := ""             # 날씨: "" / "rain"(비바라기, 원작 5턴 = 5초)
var weather_t := 0.0
var _text_cd := 0.0
var progression_enabled := false
var progression_events: Array=[]

func wild_level(area: String, native_level: int) -> int:
	if not progression_enabled:return native_level
	return LevelProgression.encounter_level(area,native_level,player.level,progression_events,rng)

# ind: 플레이어 개체 정보 {pid, ivs}(Individual). 비었으면 개체값 0.
func stop_battle_audio() -> void:
	Sfx.stop_owner(get_instance_id())

func _exit_tree() -> void:
	stop_battle_audio()

func setup(seed_value: int, species_id: String, level: int, start_moves: Array, controller, ind: Dictionary = {}) -> void:
	rng.seed = seed_value
	fx_rng.seed = seed_value ^ 0xF00D
	y_sort_enabled = true
	var arena := Arena.new()
	arena.z_index = -10
	add_child(arena)
	# 지도의 위층(나무 윗부분)은 타일 행 띠로 나뉘어 포켓몬과 함께 y 정렬된다 — 나무 뒤(북쪽)의 포켓몬은 가려지고 앞은 보인다(ArenaTop).
	var top := ArenaTop.new()
	top.arena = arena
	add_child(top)
	player = Player.new()
	player.setup_player(species_id, level, start_moves, ind)
	player.controller = controller
	player.position = Arena.resolve(Arena.center(), player.radius)
	add_child(player)
	# 지도 모드: 카메라가 플레이어를 따라간다. 지도 밖은 보여 주지 않는다.
	if Arena.has_map():
		cam = Camera2D.new()
		cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
		cam.position_smoothing_enabled = false
		var b := Arena.bounds()
		cam.limit_left = int(b.position.x)
		cam.limit_top = int(b.position.y)
		cam.limit_right = int(b.end.x)
		cam.limit_bottom = int(b.end.y)
		add_child(cam)
		cam.make_current()
		cam.position = player.position.round()

func step(dt: float) -> void:
	_step_bystanders(dt)
	_tick_impact_camera(dt)
	_text_cd = maxf(0.0, _text_cd - dt)
	_tick_status(dt)
	field_water.step(self,dt)
	_step_player(dt)
	for e in enemies:
		if not e.dead and e.hitstop_t <= 0.0:
			e.think(dt, self)
	_step_bursts(dt)
	_step_pending_casts(dt)
	_step_pending_melee(dt)
	_step_pending_calls(dt)
	_step_burrows(dt)
	_step_pending_beams(dt)
	_move_mons(dt)
	_separate_enemies()
	_step_projectiles(dt)
	_step_zones(dt)
	_push_apart_player()
	_push_out_of_npcs()
	_fence_battle()
	_step_spawns(dt)
	_step_drops(dt)
	_step_weather(dt)
	_step_tall_grass()
	for f in fxs:
		f.step(dt)
	_update_smoke_density()
	for n in npcs:
		n.step(dt)
	_cleanup()
	# 원작의 '배틀 끝'(사용자 결정 2026-10-29): 주변에 적이 하나도 없으면(나오는 중인 녀석도 없으면) 내 랭크 변화를 초기화한다.
	# 바깥 세계는 야생이 잇달아 나와도 마리마다 따로 배틀인 셈이라, 다 쓰러뜨리거나 도망치면 성장·껍질에숨기도 풀린다.
	# 트레이너 배틀은 마지막 포켓몬까지 하나의 배틀이다.
	if remaining() == 0 and not player.dead and not in_battle():
		player.reset_stages()
	# 픽셀이 번지지 않게 카메라는 정수 좌표로만 움직인다.
	if cam != null:
		if arena_cam:
			# 경기장: 나와 상대 사이를 비춘다(필드가 시야보다 커서 — 트레이너가 뒤쪽에서 내보낸 상대도 화면에 들어오게). 부드럽게 따라감.
			var target := player.cam_anchor()
			var es := alive_enemies()
			if not es.is_empty():
				target = (player.cam_anchor() + (es[0] as Mon).cam_anchor()) * 0.5
			cam_pos = cam_pos.lerp(target, 0.12)
			cam.position = cam_pos.round()
		else:
			# 달려드는 근접 동작 중엔 앞으로 나간 몸을 따라간다(cam_anchor) — 자리가 옮겨질 때 화면이 한 번에 튀지 않게.
			cam_pos = player.cam_anchor()
			cam.position = cam_pos.round()
	queue_redraw()

# ── 조회 ──

func alive_enemies() -> Array:
	return enemies.filter(func(e): return not e.dead)

func remaining() -> int:
	return alive_enemies().size() + pending_spawns.size()

func opponents(team: int) -> Array:
	if team == Mon.TEAM_PLAYER:
		return alive_enemies()
	return [] if player.dead else [player]

# ── 출현 ──

# 풀숲이 있는 던전이면 풀숲 칸에서 풀을 흔들며 나온다. 없으면 가장자리에서 빛나는 원으로.
func wild_cfg() -> Dictionary:
	var cfg := DungeonDB.area_cfg(Arena.area_at(player.position))
	if player.travel_terrain==2 and Arena.is_water(Arena.tile_of(player.position)):
		cfg["encounters"]=cfg.get("water_encounters",[])
		cfg["encounter_rate"]=cfg.get("water_encounter_rate",1)
		cfg["encounter_terrain"]="water"
	return cfg

func resolve_mon(mon: Mon,pos: Vector2,cross_ledges: bool=false) -> Vector2:
	if Arena.native_at(Arena.tile_of(mon.position)):
		var count := maxi(1,ceili(pos.distance_to(mon.position)/(Arena.TILE*0.2)))
		var step := (pos-mon.position)/float(count)
		var at := mon.position
		for i in count: at=Arena.resolve(at+step,mon.radius,cross_ledges,mon.travel_terrain)
		return at
	return Arena.resolve(pos,mon.radius,cross_ledges,mon.travel_terrain)

func queue_spawn(species_id: String, level: int) -> bool:
	var area := Arena.area_at(player.position) if Arena.has_map() else ""
	if overworld:level=wild_level(area,level)
	var cfg := wild_cfg()
	var radius := float(SpeciesDB.get_species(species_id)["radius"])
	var points := _wild_spawn_points(cfg, radius) if DungeonDB.is_overworld() else _spawn_grass()
	var pos: Vector2
	if points.is_empty():
		# Walking encounters never fall back to map edges, water or a different route.
		if DungeonDB.is_overworld(): return false
		pos = Arena.edge_point(rng)
		if pos.distance_to(player.position) < 90.0:
			pos = Arena.resolve(Arena.center() * 2.0 - pos, radius)
	else:
		pos = points[rng.randi_range(0, points.size() - 1)]
	var cave := String(cfg.get("encounter_terrain", "grass")) == "cave"
	var aquatic := String(cfg.get("encounter_terrain", "grass")) == "water"
	if aquatic:
		add_fx("sprite",pos,{"text":"g4_ring_q","water_surface":true,"size":16.0,"grow":1.7,"lifetime":SPAWN_DELAY+0.3,"color":Color("c0efff")})
	else:
		add_fx("spawn" if cave or points.is_empty() else "rustle", pos,
			{"lifetime": SPAWN_DELAY + 0.3, "size": 8.0, "color": Color("c4b89a") if cave else Color("fff2a0")})
	pending_spawns.append({"species": species_id, "level": level, "pos": pos, "t": SPAWN_DELAY,
		"wild_area": area if DungeonDB.is_overworld() else "", "terrain":1 if aquatic else 0})
	return true

# Flood only reachable, clear floor. A cave wall, ledge or doorway stops the search.
func _wild_spawn_points(cfg: Dictionary, radius: float) -> Array:
	if not Arena.has_map() or cfg.get("encounters", []).is_empty(): return []
	var origin := Arena.tile_of(player.position)
	var area := Arena.area_at(player.position)
	var cave := String(cfg.get("encounter_terrain", "grass")) == "cave"
	var aquatic := String(cfg.get("encounter_terrain", "grass")) == "water"
	var queue: Array[Vector2i] = [origin]
	var seen := {origin: true}
	var points: Array = []
	var cursor := 0
	while cursor < queue.size():
		var tile: Vector2i = queue[cursor]
		cursor += 1
		var pos := Arena.tile_center(tile)
		var distance := pos.distance_to(player.position)
		if distance >= 60.0 and (Arena.is_water(tile) if aquatic else (cave or Arena.is_grass(tile))):
			points.append(pos)
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = tile + delta
			if seen.has(next): continue
			seen[next] = true
			var target := Arena.tile_center(next)
			if target.distance_to(player.position) > 400.0 or Arena.area_at(target) != area: continue
			if Arena.terrain_blocked(next,1 if aquatic else 0) or Arena.ledge_at(next.x, next.y) != 0: continue
			if not Arena.warp_at(target).is_empty(): continue
			if Arena.resolve(target, radius,false,1 if aquatic else 0).distance_to(target) > 0.1: continue
			queue.append(next)
	var half := get_viewport_rect().size * 0.5 - Vector2(12, 8)
	var visible := points.filter(func(p): return absf(p.x-player.position.x)<=half.x and absf(p.y-player.position.y)<=half.y)
	if not visible.is_empty(): return visible
	points.sort_custom(func(a,b): return a.distance_to(player.position)<b.distance_to(player.position))
	return points.slice(0, mini(6,points.size()))

func _spawn_grass() -> Array:
	if not Arena.has_map(): return []
	var p := player.position
	var pts := Arena.grass_points_near(p, 60.0, 400.0)
	var half := get_viewport_rect().size * 0.5 - Vector2(12, 8)
	var in_view := pts.filter(func(g): return absf(g.x-p.x)<=half.x and absf(g.y-p.y)<=half.y)
	if not in_view.is_empty(): return in_view
	var near := pts.filter(func(g): return g.distance_to(p)<=240.0)
	if not near.is_empty(): return near
	pts.sort_custom(func(a,b): return a.distance_to(p)<b.distance_to(p))
	return pts.slice(0,mini(6,pts.size()))

func _step_spawns(dt: float) -> void:
	for s in pending_spawns:
		s["t"] -= dt
		if s["t"] <= 0.0:
			var area := String(s.get("wild_area", ""))
			if not area.is_empty() and (Arena.area_at(player.position) != area or (player.repel_steps > 0 and not bool(s.get("fished",false)))): continue
			var e := Enemy.new()
			e.setup_enemy(s["species"], s["level"], rng)
			if s.has("moves"):
				e.cds.clear()
				for move_id in s["moves"]:e.cds[move_id]=rng.randf_range(0.6,1.8)
			if bool(s.get("no_exp",false)):e.set_meta("no_exp",true)
			e.travel_terrain=int(s.get("terrain",0))
			e.position = Arena.resolve(s["pos"], e.radius,false,e.travel_terrain)
			e.facing = (player.position - e.position).normalized()
			add_child(e)
			enemies.append(e)
			if e.shiny:
				shiny_fx(e)
			Sfx.cry(e.species_id, 1.0, _battle_sound_db(e.position), _battle_sound_pan(e.position), get_instance_id())
	pending_spawns = pending_spawns.filter(func(s): return s["t"] > 0.0)

# 바깥 세계: 플레이어에게서 너무 멀어진 야생 포켓몬은 조용히 사라진다(경험치 없음).
func despawn_far(center: Vector2, dist: float) -> void:
	for e in enemies.duplicate():
		if not e.dead and not e.trainer_owned and e.position.distance_to(center) > dist:
			enemies.erase(e)
			e.queue_free()

func scatter_enemies(keep_water: bool=false) -> void:
	for e in enemies:
		if not e.dead and not (keep_water and e.travel_terrain==1):
			e.dead = true
			add_fx("burst", e.position, {"color": Color(1, 1, 1), "size": e.radius, "lifetime": 0.3})
	pending_spawns = pending_spawns.filter(func(s): return keep_water and int(s.get("terrain",0))==1)
	if not keep_water: clear_enemy_projectiles()

func clear_enemy_projectiles() -> void:
	for p in projectiles:
		if p.team == Mon.TEAM_ENEMY:
			p.dead = true

# ── 플레이어 입력 ──

# Read-only mirror of the input gates below. No PP, RNG, movement, or timers
# are spent by checking a press; actual casting and hold-to-fire stay below.
func skill_input_blocked(slot: int) -> bool:
	if slot<0 or slot>=Player.SLOT_COUNT or player.dead: return true
	if not _committed_preparation(player).is_empty():return true
	if not _area_charge.is_empty() and slot!=int(_area_charge.slot):return true
	if player.hitstop_t>0.0 or not field_water.fishing.is_empty() or not player.can_act(): return true
	if not player.burrow.is_empty():
		return not (float(player.burrow.sink)<=0.0 and slot==int(player.burrow.get("slot",-1)) and float(player.burrow.t)<float(player.burrow.under)-0.2)
	if player.hop_t>0.0 or no_skills or player.rampage_t>0.0 or player.skill_lock_t>0.0 or player.para_lock_t>0.0: return true
	if not player.can_use(slot): return true
	var move := MoveDB.get_move(player.slots[slot])
	return move.shape in ["zone","ring"] and _has_own_zone(player.slots[slot])

func _step_player(dt: float) -> void:
	player.tick_cooldowns(dt)
	var c = player.controller
	var preparation:=_committed_preparation(player)
	if not preparation.is_empty():player.facing=preparation.locked_dir
	var fresh_skills: Array[int]=[]
	if not _area_charge.is_empty() and not _area_charge_valid():_cancel_area_charge()
	if c!=null and c.has_method("skill_is_held"):
		for slot in _area_suppressed_slots.keys():
			if not c.skill_is_held(int(slot)):_area_suppressed_slots.erase(slot)
	if c != null and c.has_method("consume_skill_presses"):
		for slot in c.consume_skill_presses(self):
			fresh_skills.append(slot)
			# A release/repress event can occur between simulation ticks.
			_area_suppressed_slots.erase(slot)
			if not player.dead and skill_input_blocked(slot): player.play_skill_denied_feedback()
	if player.dead:
		return
	if player.hitstop_t > 0.0:          # 히트스톱: 멈춘 동안은 입력도 없다(후딜레이·쿨타임은 흐른다)
		player.vel = Vector2.ZERO
		return
	if not field_water.fishing.is_empty():
		player.vel=Vector2.ZERO
		return
	if c.has_method("record_skill_input") and not no_skills:c.record_skill_input(self)
	aim_point = c.aim_point(self)
	var aim_dir := aim_point - player.position
	aim_dir = aim_dir.normalized() if aim_dir.length_squared() > 1.0 else player.facing
	# A sleep-curing berry must remain usable while sleeping blocks normal input.
	if player.sleep_t>0.0 and c.has_method("want_hotbar"):
		for n in Player.HOTBAR:
			var id: String=player.hotbar[n]
			if "sleep" in ItemDB.effect(id).get("cure",[]) and c.want_hotbar(n,self): _use_hotbar(n,false)
		player.vel=Vector2.ZERO
		return
	if not player.can_act():
		if player.recover_t > 0.0:
			player.vel = Vector2.ZERO      # 근접 동작 중·구멍파기에서 솟구친 뒤: 제자리
		return
	# 구멍파기 중(사용자 결정 2026-10-30): 땅속을 절반 속도로 움직이고 기술은 못 쓴다. 같은 칸을 다시 누르면(가라앉은 뒤) 바로 나온다.
	if not player.burrow.is_empty():
		var bm: Vector2 = c.move_dir(self)
		player.vel = bm * player.move_speed() * 0.5
		if bm.length_squared() > 0.01:
			player.facing = bm.normalized()
		var bslot := int(player.burrow.get("slot", -1))
		if float(player.burrow["sink"]) <= 0.0 and bslot >= 0 and c.want_skill(bslot, self) and float(player.burrow["t"]) < float(player.burrow["under"]) - 0.2:
			_emerge(player)
		return
	# 밀려나는 동안(knock)·경직 중엔 이동 입력을 받지 않는다(사용자 지적 2026-10-30: 키를 누른 채 밀리면 언덕 자동 뛰어내리기 등이
	# 겹쳐 순간이동처럼 튀었다). 회피·점프·언덕 내려가기도 그동안은 없다. 기술은 그대로 쓸 수 있다.
	var knocked := player.knock != Vector2.ZERO or player.flinch_t > 0.0
	var mv: Vector2 = Vector2.ZERO if knocked else c.move_dir(self)
	player.vel = mv * player.move_speed()
	if player.attack_anim_t > 0.0 and _area_charge.is_empty():
		player.vel *= ATTACK_MOVE_FACTOR
	if player.attack_anim_t > 0.0:
		var firing := _ember_direction(player)
		player.facing = player.attack_direction if not player.attack_direction.is_zero_approx() else (firing if firing != Vector2.ZERO else aim_dir)
	elif mv.length_squared() > 0.01:
		player.facing = mv.normalized()

	# 먹기 동작은 움직이면 바로 풀린다(이동 중에 먹으면 동작 없이 회복만).
	if mv.length_squared() > 0.01:
		player.eat_t = 0.0
	if c.has_method("want_item") and c.want_item(self):
		_try_eat(mv.length_squared() > 0.01)
	# 도구 편성 1~4(사용자 결정 2026-11-02): 오랭열매는 여기서 먹고, 나머지 도구는 가방에서 쓴 것과 같게(Game 이 받는다).
	if c.has_method("want_hotbar"):
		for n in Player.HOTBAR:
			if c.want_hotbar(n, self):
				_use_hotbar(n, mv.length_squared() > 0.01)
	# Long preparations commit on press. Walking/items remain available, but
	# jump/dodge/ledge hops or another skill cannot bypass the commitment.
	if not preparation.is_empty():
		player.facing=preparation.locked_dir
		return
	# 회피(우클릭): 이동 방향(없으면 조준 방향)으로 내달린다. 잠깐 무적, 쿨타임. 지금은 잠겨 있다(Player.dodge_unlocked).
	if knocked:
		pass
	elif Player.dodge_unlocked and c.want_dodge(self) and player.dodge_cd <= 0.0:
		_cancel_area_charge()
		var dd := mv.normalized() if mv.length_squared() > 0.01 else aim_dir
		_start_dodge(dd)
		player.eat_t = 0.0
		return
	# 점프(Space): 두 칸. 무적·쿨타임 없음(착지할 때까지는 다시 못 뛴다).
	elif player.travel_terrain==0 and c.has_method("want_jump") and c.want_jump(self):
		var d := mv.normalized() if mv.length_squared() > 0.01 else aim_dir
		var plan := plan_hop(player.position, d)
		if plan["ok"]:
			_cancel_area_charge()
			player.eat_t = 0.0
			_start_hop(plan["to"])
			return
	# 언덕을 걸어 내려가면 원작처럼 저절로 뛰어내린다(쿨타임 무관). 올라갈 땐 점프 키로 넘는다(사용자 결정 2026-10-28).
	var drop := Vector2.ZERO if knocked else Arena.ledge_drop_ahead(player.position, player.radius, mv)
	if drop != Vector2.ZERO and player.hop_t <= 0.0:
		var plan := plan_hop(player.position, drop)
		if plan["ok"]:
			_cancel_area_charge()
			_start_hop(plan["to"])
			return

	# 점프(Hop) 동작이 끝나기 전엔 기술을 못 쓴다(사용자 지적 2026-10-28). 마을에선 아예 안 쓴다.
	# 꽃잎댄스 난동 중에도 다른 기술은 못 쓴다(원작).
	if player.hop_t > 0.0 or no_skills or player.rampage_t > 0.0 or player.skill_lock_t > 0.0 or player.para_lock_t > 0.0:
		return                                   # skill_lock_t: 후딜레이(연타 금지), para_lock_t: 마비로 몸이 저린 동안
	if not _area_charge.is_empty():
		_step_area_charge(dt)
		return
	for i in Player.SLOT_COUNT:
		var id: String = player.slots[i]
		if _area_suppressed_slots.has(i):continue
		if not player.can_use(i):continue
		var requested: bool=c.want_skill(i,self)
		if not requested and fresh_skills.has(i) and c.has_method("skill_is_held") and AreaAim.is_area_move(MoveDB.get_move(id)):requested=true
		if not requested:continue
		# 장판·회오리는 하나가 남아 있는 동안 다시 못 쓴다.
		if MoveDB.get_move(id)["shape"] in ["zone", "ring"] and _has_own_zone(id):
			continue
		if AreaAim.is_area_move(MoveDB.get_move(id)) and c.has_method("skill_is_held"):
			if not c.skill_is_held(i) and not fresh_skills.has(i):continue
			_begin_area_charge(i,id)
			if not c.skill_is_held(i):_step_area_charge(0.0)
			break
		if full_paralysis(player):               # 마비: 25% 로 기술이 안 나간다
			player.play_skill_denied_feedback()
			return
		aim_point = _player_skill_aim(id)
		var corrected := aim_point - player.position
		aim_dir = corrected.normalized() if corrected.length_squared() > 1.0 else player.facing
		player.facing = aim_dir
		if c.has_method("stop_move"):
			c.stop_move()                         # 기술을 쓰면 클릭 이동은 멈춘다(사용자 2026-11-02)
			player.vel = Vector2.ZERO
		var mdef := MoveDB.get_move(id)
		var charge := float(mdef.get("cast_delay", 0.0))
		if charge > 0.0:
			# 힘을 모았다가 쏜다. 조준은 발사 순간에 다시 잡는다.
			var pending:={"mon":player,"move":id,"t":charge}
			if mdef.has("charge_turns"):
				pending["committed"]=true;pending["locked_dir"]=aim_dir
				player.attack_direction=aim_dir
			pending_casts.append(pending)
			player.play_attack(String(mdef.get("anim", "Charge")), charge + 0.05)
			# 로케트박치기: 모으는 턴에 방어 +1(원작). 솔라빔: 빛이 모여든다.
			if mdef.has("charge_stat"):
				_apply_stat(player, mdef["charge_stat"], false)
			if charge >= 0.5:
				charge_fx(player, mdef, charge)
		else:
			cast(player, id, aim_dir, aim_point)
			# lunge: Attack 시트 안의 움직임을 그대로 보여 준다(몸통박치기·불꽃엄니).
			player.play_attack(String(mdef.get("anim", "Attack")), 0.0, bool(mdef.get("lunge", false)))
		player.spend(i)
		if not player.burrow.is_empty():
			player.burrow["slot"] = i      # 같은 칸을 다시 누르면 일찍 나온다
		elif charge <= 0.0 and mdef["shape"] != "dash":
			_player_recover(id)            # 후딜(돌진은 끝난 뒤, 모으는 기술은 쏜 뒤)
			if mdef["shape"] == "arc":
				# 근접기(몸통박치기·할퀴기…)는 동작이 끝날 때까지 제자리 — 때리는 순간 잠깐 멈추는 맛(사용자 지적 2026-10-30).
				player.recover_t = maxf(player.recover_t, player.attack_anim_t)
				player.vel = Vector2.ZERO
		break    # 한 프레임에 기술 하나

func _player_skill_aim(move_id: String) -> Vector2:
	var controller = player.controller
	if controller != null and controller.has_method("skill_aim"):
		return controller.skill_aim(self, move_id, controller.aim_point(self))
	return aim_point

func _committed_preparation(mon: Mon) -> Dictionary:
	for pending in pending_casts:
		if pending.get("committed",false) and pending.mon==mon and not mon.dead:return pending
	return {}

## Read-only path for the selected/committed/active human dash. Width is its
## body radius; the optional offset projects the existing FRLG feet anchor.
func dash_aim_preview() -> Dictionary:
	if player==null or player.dead or not player.controller is Controllers.Human or no_skills:return {}
	var move_id: String=""
	var direction:=Vector2.ZERO
	var distance:=0.0
	var active:=not player.dash.is_empty() and String(player.dash.get("move",""))!=""
	if active:
		move_id=String(player.dash.move);direction=player.dash.dir
		distance=maxf(0.0,float(player.dash.t))*float(player.dash.speed)
	else:
		var preparation:=_committed_preparation(player)
		if not preparation.is_empty():
			move_id=String(preparation.move);direction=preparation.locked_dir
		else:
			var slot:=player.pp_focus_slot
			if not player.can_act() or player.hop_t>0.0 or player.skill_lock_t>0.0 or not player.can_use(slot):return {}
			move_id=String(player.slots[slot])
			if String(MoveDB.get_move(move_id).shape)!="dash":return {}
			var controller: Controllers.Human=player.controller
			var raw: Vector2=controller.peek_aim_point(self)
			var point: Vector2=controller.peek_skill_aim(self,move_id,raw)
			direction=(point-player.position).normalized() if point.distance_squared_to(player.position)>1.0 else player.facing
		var move:=MoveDB.get_move(move_id)
		if String(move.shape)!="dash":return {}
		distance=float(move.distance)
	var sweep:=BattleContact.forward_sweep(self,player,player.position,direction,distance)
	return {"from":player.position,"to":sweep.point,"width":player.radius,"move_id":move_id,"active":active,
		"ground_offset":Vector2.ZERO if Arena.native_at(Arena.tile_of(player.position)) else Vector2(0,player.feet_offset())}

func _area_charge_valid() -> bool:
	if _area_charge.is_empty() or player==null:return false
	var controller=player.controller
	if controller==null or controller!=_area_charge.controller or not controller.has_method("skill_is_held"):return false
	if controller.has_method("skill_input_revision") and controller.skill_input_revision()!=int(_area_charge.revision):return false
	if controller.get("hold")==true:return false
	var slot:=int(_area_charge.slot)
	if player.slots[slot]!=String(_area_charge.move) or not player.can_use(slot):return false
	if not player.can_act() or no_skills or player.hop_t>0 or player.rampage_t>0 or player.skill_lock_t>0 or player.para_lock_t>0:return false
	if not field_water.fishing.is_empty() or _has_own_zone(String(_area_charge.move)):return false
	return true

func _begin_area_charge(slot: int,move_id: String) -> void:
	var controller=player.controller
	player.attack_direction=Vector2.ZERO
	_area_charge={"slot":slot,"move":move_id,"elapsed":0.0,"controller":controller,
		"revision":controller.skill_input_revision() if controller.has_method("skill_input_revision") else 0,"offset":Vector2.ZERO}
	player.play_attack("Charge",.1)
	_update_area_charge_point()

func _update_area_charge_point() -> void:
	var move:=MoveDB.get_move(String(_area_charge.move))
	var reach:=lerpf(minf(AREA_MIN_RANGE,float(move.range)),float(move.range),clampf(float(_area_charge.elapsed)/AREA_CHARGE_TIME,0,1))
	var controller=player.controller
	var raw: Vector2=controller.aim_point(self)-player.position
	var direction:=raw.normalized() if raw.length_squared()>1.0 else player.facing
	var point:=player.position+direction*reach
	if controller.has_method("skill_aim"):point=controller.skill_aim(self,String(move.id),point)
	else:point=area_aim.resolve_area(self,player,move,point)
	_area_charge.offset=point-player.position
	if not (point-player.position).is_zero_approx():player.facing=(point-player.position).normalized()

## Read-only hit center/radius for the shared 2D/3D range preview.
func area_charge_preview() -> Dictionary:
	if not _area_charge_valid():return {}
	var move:=MoveDB.get_move(String(_area_charge.move))
	var offset: Vector2=_area_charge.offset
	return {"center":player.position+offset,"radius":float(move.get("area_radius",move.get("radius",Arena.TILE))),
		"progress":clampf(float(_area_charge.elapsed)/AREA_CHARGE_TIME,0,1),"range":offset.length(),
		"ground_offset":Vector2(0,player.feet_offset()) if move.id=="fire_spin" else Vector2.ZERO,"move_id":String(move.id)}

func _cancel_area_charge() -> void:
	if _area_charge.is_empty():return
	_area_suppressed_slots[int(_area_charge.slot)]=true
	_area_charge={}
	player.attack_anim_t=0.0

func _step_area_charge(dt: float) -> void:
	_area_charge.elapsed=float(_area_charge.elapsed)+dt
	_update_area_charge_point()
	if player.controller.skill_is_held(int(_area_charge.slot)):
		player.attack_anim_t=maxf(player.attack_anim_t,.1)
		return
	var charge: Dictionary=_area_charge
	_area_charge={}
	player.attack_anim_t=0.0
	if full_paralysis(player):player.play_skill_denied_feedback();return
	var point: Vector2=player.position+Vector2(charge.offset)
	var move:=MoveDB.get_move(String(charge.move))
	var wait:=maxf(0,float(move.get("cast_delay",0))-float(charge.elapsed))
	player.spend(int(charge.slot))
	if player.controller.has_method("stop_move"):player.controller.stop_move()
	if wait>0:
		pending_casts.append({"mon":player,"move":String(charge.move),"t":wait,"locked_point":point})
		player.play_attack(String(move.get("anim","Charge")),wait+.1)
		player.skill_lock_t=maxf(player.skill_lock_t,wait+.1+MoveDB.recover_of(String(charge.move)))
	else:
		cast(player,String(charge.move),(point-player.position).normalized(),point,{"area_point_locked":true})
		player.play_attack(String(move.get("anim","Attack")),.1)
		_player_recover(String(charge.move),.1)

# 후딜레이(사용자 정의 2026-10-30): 스킬 동작(지금 재생 중인 공격 도트, attack_anim_t)이 끝난 뒤 MoveDB.RECOVER 동안 어떤 스킬도 못 쓴다.
# 움직임·자세는 그대로(동작 중엔 ATTACK_MOVE_FACTOR 로 느릴 뿐). action: 동작 길이(없으면 지금 attack_anim_t).
func _player_recover(move_id: String, action: float = -1.0) -> void:
	var rec := MoveDB.recover_of(move_id)
	var act := action if action >= 0.0 else player.attack_anim_t
	player.skill_lock_t = maxf(player.skill_lock_t, act + rec)

func _has_own_zone(move_id: String) -> bool:
	for z in zones:
		if z.team == Mon.TEAM_PLAYER and not z.dead and z.hit.get("move", "") == move_id:
			return true
	return false

# ── 기술 ──

func make_hit(mon: Mon, move_id: String) -> Dictionary:
	var m := MoveDB.get_move(move_id)
	var physical: bool = m["cat"] == "physical"
	var hit := {
		"move": move_id, "type": m["type"], "cat": m["cat"],
		"level": mon.level,
		# 물리 공격에는 공격 랭크(울음소리 ↓, 메탈클로우 ↑)를 곱한다.
		"atk": int(round(float(mon.stats["atk"]) * Mon.stage_mult(mon.atk_stage))) if physical else int(round(float(mon.stats["spa"]) * Mon.stage_mult(mon.spa_stage))),
		"fixed": int(m.get("fixed", 0)), "hit_fx": String(m.get("hit_fx", "")),
		"stab": mon.types().has(m["type"]), "power": MoveDB.power(move_id) * (0.5 if move_id == "solar_beam" and weather == "rain" else 1.0)
			* (2.0 if bool(m.get("statused_double", false)) and (mon.burn_t > 0.0 or mon.poison_t > 0.0 or mon.para_t > 0.0) else 1.0),   # 객기(화상·독·마비)
		"burn": float(m.get("burn", 0.0)), "poison": float(m.get("poison", 0.0)), "slow": float(m.get("slow", 0.0)),
		"paralyze": float(m.get("paralyze", 0.0)),   # 마비 확률(용의숨결 30%)
		"flinch": float(m.get("flinch", 0.0)), "crit": float(m.get("crit", Damage.BASE_CRIT)),
		"team": mon.team, "mult": _damage_mult(mon),
		# 연타 기술용: 한 타의 넉백(없으면 기본)과 플레이어 피격 무적(없으면 Player.HIT_INVULN)
		"knock": float(m.get("knock", -1.0)), "invuln": float(m.get("invuln", Player.HIT_INVULN)),
		"acc_stage": mon.acc_stage,   # 연막에 맞은 쪽의 공격은 빗나갈 수 있다(apply_hit)
		"weight": mon.weight_kg(),    # 넉백: 무거운 쪽이 가벼운 쪽을 민다(src 는 아래 — 히트스톱에서 때린 쪽도 멈출 때 쓴다)
		# 이상해씨·꼬북이 기술의 부가 효과(MoveDB._apply_effect 가 플래티넘 effect 에서 채운다)
		"sleep": float(m.get("sleep", 0.0)), "confuse": float(m.get("confuse", 0.0)), "leech": bool(m.get("leech", false)),
		"stat_hit": m.get("stat_hit", {}), "stat_hit_chance": float(m.get("stat_hit_chance", 0.0)),
		"insomnia": bool(m.get("insomnia", false)), "src": mon, "bind": bool(m.get("bind", false)),
		# 기술머신 기술(2026-10-30): 소금물·깨뜨리다·기가드레인
		"half_double": bool(m.get("half_double", false)), "ignore_def_up": bool(m.get("ignore_def_up", false)), "drain": float(m.get("drain", 0.0)),
	}
	if m.has("recoil") or move_id=="struggle":
		hit.recoil=float(m.get("recoil",0))
		hit.recoil_state={"total":0,"paid":0,"bounced":false,"direction":mon.facing}
	return hit

func _damage_mult(mon: Mon) -> float:
	if mon.team == Mon.TEAM_PLAYER:
		return 1.0
	return ENEMY_DAMAGE_MULT

# Snapshot the source distance at playback; no global listener state survives scene changes.
# Four tiles retain full volume; smoothly fade to silence at sixteen tiles.
func _battle_sound_db(at: Vector2) -> float:
	if not is_instance_valid(player): return -80.0
	var distance := at.distance_to(player.position)
	var progress := clampf((distance-4.0*Arena.TILE)/(12.0*Arena.TILE),0.0,1.0)
	var gain := 1.0-smoothstep(0.0,1.0,progress)
	return linear_to_db(gain) if gain>0.0001 else -80.0

# Current 2D and fixed-yaw 3D cameras both map world +X to screen right.
func _battle_sound_pan(at: Vector2) -> float:
	if not is_instance_valid(player): return 0.0
	return clampf((at.x-player.position.x)/(8.0*Arena.TILE),-1.0,1.0)*0.65

func cast(mon: Mon, move_id: String, dir: Vector2, aim_pos: Vector2, opts: Dictionary = {}) -> void:
	if confusion_self_hit(mon):
		return
	# The direction belongs to one attack; a later shot cannot inherit an
	# interrupted melee's pose lock. Long committed preparations pass it on.
	mon.attack_direction=dir.normalized() if opts.get("direction_locked",false) else Vector2.ZERO
	var m := MoveDB.get_move(move_id)
	if AreaAim.is_area_move(m) and not opts.get("area_point_locked",false):
		var assistance: RefCounted=area_aim
		if mon==player and player.controller is Controllers.Human:
			assistance=player.controller.aim_assist
		var precise: bool=player.controller.skill_aim_precise() if mon==player and player.controller is Controllers.Human else false
		aim_pos=assistance.resolve_area(self,mon,m,aim_pos,precise)
		if not aim_pos.is_equal_approx(mon.position):dir=(aim_pos-mon.position).normalized()
		mon.facing=dir
	if mon == player: player_move_used.emit(move_id)
	var hit := make_hit(mon, move_id)
	if hit.has("recoil_state"): hit.recoil_state.direction=dir.normalized()
	mon.attack_full_recovery = move_id == "scratch"
	mon.attack_contact_hold = float(m.get("contact_hold", 0.0))
	mon.attack_contact_time = 0.0
	if move_id in ["growl","disarming_voice"]:
		Sfx.cry(mon.species_id, 1.0, _battle_sound_db(mon.position), _battle_sound_pan(mon.position), get_instance_id())
	elif move_id=="flamethrower":
		# Last emitted flame plus its maximum travel time; fade the long source SE.
		var duration := float(m.get("interval",0.0))*maxi(0,int(m.get("count",1))-1)+float(m["range"])/maxf(1.0,float(m["speed"]))
		Sfx.move(move_id,duration,_battle_sound_db(mon.position), _battle_sound_pan(mon.position), get_instance_id())
	elif move_id not in ["scratch","fire_fang"]:
		Sfx.move(move_id,-1.0,_battle_sound_db(mon.position), _battle_sound_pan(mon.position), get_instance_id())
	match m["shape"]:
		"transform":
			if mon is Enemy:
				var targets: Array=opponents(mon.team)
				if not targets.is_empty() and mon.position.distance_to(targets[0].position)<=float(m["range"]):WildActions.transform(self,mon,targets[0])
		"counter":
			WildActions.stance(self,mon,String(m["counter_cat"]))
		"arc":
			if float(m.get("arc_deg",360.0))<360.0:mon.attack_direction=dir.normalized()
			if String(m.get("fx", "")) == "metal":
				mon.shine_t = 0.45   # 메탈클로우: 원작처럼 먼저 금속 번쩍임(MetallicShine)
			elif m.get("area_wave",false):
				var diameter:=2.0*(float(m.range)+mon.radius)
				add_fx("sprite",mon.position,{"text":"g4_ring","color":TypeChart.type_color(m.type),"size":diameter*.25,"grow":4.0,"lifetime":.32,"fade_out":.12})
			elif String(m.get("fx", "")) == "bulldoze":
				_bulldoze_fx(mon, float(m["range"]))
			# 할퀴기·몸통박치기: 때리는 순간(hit_delay)까지 앞으로 부드럽게 미끄러진다(사용자 요청 2026-11-02: 공격하며 1칸 전진,
			# 움직임은 자연스럽게). 도트의 달려듦과 합쳐 약 1칸. 상대에 닿거나 벽이면 거기서 멈춘다.
			# 박자는 도트에 맞춘다(사용자 2026-11-02: 할퀴기가 어색 — 준비 자세에서 미끄러지고, 할퀴는 프레임보다 먼저 맞고 멈췄다):
			# 맞는 순간 = 도트가 가장 앞으로 나간 프레임 시각, 미끄러지기 = 몸이 앞으로 나가기 시작하는 프레임부터 그 순간까지.
			var delay := float(m.get("hit_delay", 0.0))
			var tm: Vector2 = mon.lunge_timing(String(m.get("anim", "Attack"))) if (bool(m.get("lunge", false)) or String(m.get("anim", "")) == "Strike") else Vector2(-1, -1)
			if mon.attack_contact_hold > 0.0:
				var name := String(m.get("anim", "Attack"))
				if not mon._sprites.has(name): name = "Attack"
				tm = mon.lunge_timing(name)
				mon.attack_contact_time = tm.y if tm.y > 0.0 else delay
			if tm.y > 0.0:
				delay = tm.y + 1.0 / 60.0      # 동작 시간은 다음 틱부터 흐르므로 한 틱 더(앞으로 다 나간 프레임이 보이는 순간에 맞게)
			if m.has("glide"):
				var gd := float(m["glide"])
				var wait := tm.x if tm.y > 0.0 else 0.0
				var dur := (tm.y - tm.x + GLIDE_TAIL) if tm.y > 0.0 else float(m.get("hit_delay", 0.15))   # 맞는 순간을 조금 지나서까지 부드럽게
				mon.glide = {"dir": dir, "left": gd, "wait": wait, "speed": gd / maxf(0.04, dur)}
				if mon.attack_contact_hold > 0.0:
					var contact_wait := tm.x if tm.y > 0.0 else maxf(0.0, delay - 0.09)
					var contact_duration := maxf(0.04, delay - contact_wait)
					mon.glide.merge({"wait":contact_wait,"elapsed":0.0,"duration":contact_duration,"distance":gd,"blocked":0.0,"quick_strike":true,"stop_at_contact":bool(m.get("contact_stop",false))})
				if move_id == "scratch":
					mon.glide.merge({"elapsed": 0.0, "duration": maxf(0.12 if mon.species_id == "charmander" else 0.22, dur), "distance": gd, "blocked": 0.0, "quick_strike": mon.species_id == "charmander"})
			# 불꽃엄니처럼 "살짝 나서며" 무는 기술: step 만큼 앞으로 옮긴다(벽은 막힌다).
			var step := float(m.get("step", 0.0))
			if step > 0.0 and String(m.get("fx", "")) != "fang_c":
				mon.position = resolve_melee_advance(mon,dir*step)
			if String(m.get("fx", "")) == "fang_c":
				var fang := _fire_fang_cast_custom(mon, dir, maxf(delay, 0.01))
				if combat_clashes:
					fang.clash_hit = hit
					hit["cast_fx_ref"] = weakref(fang)
			if combat_clashes and FxStyle.mode == "custom" and move_id in ["scratch", "slash"]:
				var cut := add_fx("forward_cut", mon.position, {"text":move_id, "follow":mon, "dir":dir,
					"cut_delay":delay, "lifetime":delay + 0.30, "clash_hit":hit})
				hit["cast_fx_ref"] = weakref(cut)
				hit["forward_cut"] = true
			if delay > 0.0 or (combat_clashes and _clashable_melee(hit, m)):
				pending_melee.append({"mon": mon, "move": move_id, "hit": hit, "dir": dir, "t": delay,
					"fang_step":step if String(m.get("fx", "")) == "fang_c" else 0.0,"duration":delay})
			else:
				_melee_arc(mon, m, hit, dir)
		"gesture":
			status_message.emit(Lang.t("nothing"))
		"status_cone":
			if AreaAim.is_area_move(m):_powder_area(mon,m,aim_pos)
			else:_status_cone(mon, m, dir)
		"projectile", "cone":
			if move_id=="rock_throw" and AreaAim.is_area_move(m):
				_rock_tomb(mon,m,aim_pos,float(m["area_radius"]),1)
				return
			if m["shape"]=="cone": hit["contacts"]={}
			var count: int = m["count"]
			var spread := deg_to_rad(m["spread_deg"])
			for i in count:
				var a := dir.angle()
				if count > 1:
					a += lerpf(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
				var speed: float = m["speed"]
				_spawn_projectile(mon, hit, m, Vector2.from_angle(a) * speed)
		"burst":
			# 여러 발로 보이는 기술은 연출일 뿐 — 한 묶음은 언제나 한 번만 맞는다(사용자 결정 2026-10-28: 연발 없음).
			# volley 는 첫 발 방향 일자(용의분노), 아니면 조준을 따라간다(화염방사).
			_volley_seq += 1
			hit["volley"] = _volley_seq
			hit["contacts"] = {}
			var burst := {"mon": mon, "move": move_id, "left": int(m["count"]), "t": 0.0, "hit": hit}
			if m.get("volley",false):
				burst["dir"] = dir.normalized() if dir.length_squared()>0.001 else mon.facing
			bursts.append(burst)
		"dash":
			if bool(m.get("ramp", false)):
				# 구르기: 3초 안에 이어 쓰면 위력이 2배씩(원작 5턴, 최대 16배).
				mon.ramp_n = mini(4, mon.ramp_n + 1) if mon.ramp_move == move_id and mon.ramp_t > 0.0 else 0
				mon.ramp_move = move_id
				mon.ramp_t = 3.0
				hit["power"] = float(hit["power"]) * pow(2.0, mon.ramp_n)
			if move_id=="flare_blitz":
				add_fx("flare_coat",mon.position,{"follow":mon,"dir":dir,"lifetime":.46})
			mon.dash = {"dir": dir, "speed": float(m["distance"]) / float(m["duration"]),
				"t": float(m["duration"]), "move": move_id, "hit_ids": {}, "hit": hit}
			if mon == player and bool(m.get("dash_invulnerable",false)):
				mon.invuln_t = maxf(mon.invuln_t, float(m["duration"]) + 0.05)
		"lob":
			_lob(mon, m, dir, aim_pos)
		"zone":
			var target := mon.position + (aim_pos - mon.position).limit_length(ZONE_CAST_RANGE)
			var z := _add_zone(m.get("zone_kind", "smoke"), Arena.resolve(target, 4.0), mon, hit, m)
			z.slow = float(m["slow"])
		"ring":
			var life := float(m["lifetime"])
			if bool(m.get("rampage", false)):
				# 꽃잎댄스: 원작 난동 2~3턴(× TURN 초). 끝나면 혼란(_tick_status).
				life = float(rng.randi_range(Mon.RAMPAGE_TURNS.x, Mon.RAMPAGE_TURNS.y)) * Mon.TURN
				mon.rampage_t = life
			var z := _add_zone(String(m.get("zone_kind", "ring")), mon.position, mon, hit, m)
			z.lifetime = life
			if z is FireField:
				z.feet_offset=mon.feet_offset()
				z.target_point=aim_pos
				z.ground_targeted=AreaAim.is_area_move(m)
				z.direction=(aim_pos-mon.position).normalized() if z.ground_targeted else (dir.normalized() if not dir.is_zero_approx() else mon.facing)
				z.remaining=mon.position.distance_to(aim_pos) if z.ground_targeted else float(m["range"])
				z.turns=rng.randi_range(4,5)
				z.lifetime=z.turns*Mon.TURN
			else:
				z.follow=mon
			z.tick = float(m["tick"])
		"teleport":
			_teleport_mon(mon,m)
		"buff":
			_self_buff(mon, m)
		"heal":
			_self_heal(mon, m)
		"protect":
			_protect(mon)
		"weather":
			start_weather(String(m["weather"]), float(m.get("turns", 5)) * Mon.TURN)
		"beam":
			var length := float(m["range"])
			var strands:=3 if m.target_pattern=="fan" else 1
			hit["contacts"]={}
			for strand in strands:
				var angle:=deg_to_rad((strand-1)*MoveDB.Targeting.FAN_DEGREES*.5) if strands==3 else 0.0
				var flow:=dir.rotated(angle)
				var start: Vector2=mon.position+flow*(mon.radius+Projectile.RELEASE_GAP)
				if String(m.get("fx", ""))=="solar":
					_solar_beam_fx(mon,flow,length,float(m.lifetime))
				else:
					add_fx("beam",start+Vector2.UP*mon.radius*.2,{"dir":flow,"size":maxf(1,length-mon.radius-Projectile.RELEASE_GAP),
						"lifetime":m.lifetime,"color":TypeChart.type_color(m.type),"text":m.get("fx",""),"font_size":int(float(m.grow)*1000)})
			pending_beams.append({"mon":mon,"hit":hit,"from":mon.position,"dir":dir,"len":length,
				"width":float(m.width),"fan":strands>1,"t":float(m.grow)})

		"drain":
			_drain(mon, m, hit, dir)
		"burrow":
			_burrow(mon, m, hit)
		"radial", "spiral":
			var count: int = opts.get("count", m.get("count", 1))
			var offset: float = opts.get("offset", 0.0)
			for i in count:
				var a := offset + TAU * float(i) / float(count)
				_spawn_projectile(mon, hit, m, Vector2.from_angle(a) * float(m["speed"]))

func _step_pending_casts(dt: float) -> void:
	for pc in pending_casts:
		if not is_instance_valid(pc["mon"]) or pc["mon"].dead:
			pc["t"] = 0.0
			continue
		pc["t"] -= dt
		if pc["t"] <= 0.0:
			var mon: Mon = pc["mon"]
			if is_instance_valid(mon) and not mon.dead:
				var locked: bool = pc.has("locked_point")
				if locked:aim_point=pc.locked_point
				elif pc.get("committed",false):aim_point=mon.position+Vector2(pc.locked_dir)*100.0
				elif mon == player: aim_point = _player_skill_aim(String(pc["move"]))
				var dir: Vector2 = pc.locked_dir if pc.get("committed",false) else ((aim_point - mon.position).normalized() if mon == player or locked else mon.facing)
				mon.facing = dir
				cast(mon, pc["move"], dir, aim_point if mon == player or locked else mon.position + dir * 100.0,
					{"area_point_locked":locked,"direction_locked":bool(pc.get("committed",false))})
				# 쏘는 동안은 모으던 자세를 그대로 둔다 — 불씨마다 몸이 움직이지 않게(사용자 결정).
				var mm := MoveDB.get_move(pc["move"])
				var volley_len := float(mm.get("interval", 0.0)) * float(mm.get("count", 1)) + 0.1
				mon.play_attack(String(mm.get("anim", "Charge")), volley_len)
				if mon == player and mm["shape"] != "dash":
					_player_recover(String(pc["move"]), volley_len)
	pending_casts = pending_casts.filter(func(pc): return pc["t"] > 0.0)

# 실이 끝까지 늘어난 순간, 선에 닿아 있는 상대에게 효과(실뿜기: 스피드 랭크 −1)를 준다. 피해는 없다.
func _step_pending_beams(dt: float) -> void:
	for pb in pending_beams:
		pb["t"] -= dt
		if pb["t"] > 0.0:
			continue
		var a: Vector2 = pb["from"]
		var b: Vector2 = a + pb["dir"] * pb["len"]
		for t in opponents(pb["hit"]["team"]):
			var c := Geometry2D.get_closest_point_to_segment(t.position, a, b)
			var in_beam: bool=c.distance_to(t.position)<=t.radius+pb.width
			if pb.get("fan",false):
				var offset: Vector2=t.position-a
				in_beam=offset.length()<=pb.len+t.radius and absf(Vector2(pb.dir).angle_to(offset))<=deg_to_rad(MoveDB.Targeting.FAN_DEGREES*.5)
			if in_beam:
				apply_hit(t, pb["hit"], a)
	pending_beams = pending_beams.filter(func(pb): return pb["t"] > 0.0)

func _step_pending_calls(dt: float) -> void:
	for pc in pending_calls:
		pc["t"] -= dt
		if pc["t"] <= 0.0:
			pc["call"].call()
	pending_calls = pending_calls.filter(func(pc): return pc["t"] > 0.0)

# Compare the two move types once at contact. The surviving base power then
# enters ordinary damage calculation against each actual defender.
func resolve_clash(a: Dictionary, b: Dictionary, at: Vector2, dir_a: Vector2, dir_b: Vector2, melee := false) -> void:
	var rate_a := maxf(1.0, TypeChart.effectiveness(a.type, [b.type]))
	var rate_b := maxf(1.0, TypeChart.effectiveness(b.type, [a.type]))
	var difference := float(a.power) * rate_a - float(b.power) * rate_b
	var pair := {"at":at, "melee":melee}
	_set_clash_power(a, maxf(0.0, difference / rate_a), dir_a, pair)
	_set_clash_power(b, maxf(0.0, -difference / rate_b), dir_b, pair)

func _set_clash_power(hit: Dictionary, power: float, direction: Vector2, pair: Dictionary) -> void:
	var original := float(hit.get_or_add("clash_original_power", hit.power))
	hit.power = power
	hit["clash_fraction"] = power / original
	if pair.melee:
		hit["clash_melee"] = true
		hit["clash_pair"] = pair
		if hit.has("cast_fx_ref"):
			var cut: Fx = hit.cast_fx_ref.get_ref()
			if is_instance_valid(cut): hit["clash_visual_t"] = cut.age
	if power <= 0.0:
		add_fx("clash_chip", pair.at, {"text":hit.type, "dir":direction.normalized(),
			"lifetime":0.40, "clash_pair":pair})

func _faces_melee_target(strike: Dictionary, target: Mon) -> bool:
	var actor: Mon = strike.mon
	var offset := target.position - actor.position
	var move := MoveDB.get_move(strike.move)
	return offset.length() <= actor.radius + target.radius + float(move.range) and absf(Vector2(strike.dir).angle_to(offset)) <= deg_to_rad(float(move.arc_deg) * 0.5)

func _clashable_melee(hit: Dictionary, move: Dictionary) -> bool:
	return hit.cat == "physical" and hit.power > 0 and hit.fixed <= 0 and float(move.arc_deg) < 360.0

func _available_melee(strike: Dictionary) -> bool:
	var hit: Dictionary = strike.hit
	return not strike.get("cancel", false) and not hit.has("clash_melee") and _clashable_melee(hit, MoveDB.get_move(strike.move))

func _try_melee_clash(a: Dictionary) -> bool:
	if not combat_clashes or not _available_melee(a): return false
	var first: Mon = a.mon
	for b in pending_melee:
		if not _available_melee(b) or not is_instance_valid(b.mon) or b.mon.dead or b.mon.team == first.team: continue
		if absf(float(b.t) - float(a.t)) > MELEE_CONTACT_WINDOW: continue
		var second: Mon = b.mon
		if not _faces_melee_target(a, second) or not _faces_melee_target(b, first): continue
		var contact := first.position.lerp(second.position, 0.5)
		resolve_clash(a.hit, b.hit, contact, a.dir, b.dir, true)
		for strike in [a, b]:
			var actor: Mon = strike.mon
			if strike.move in ["scratch", "fire_fang"]:
				Sfx.move(strike.move, -1.0, _battle_sound_db(actor.position), _battle_sound_pan(actor.position), get_instance_id())
			actor.hitstop_t = maxf(actor.hitstop_t, ProjectileClashes.PAUSE)
			actor.glide.clear()
			strike.fang_step = 0.0
			strike.t = ProjectileClashes.PAUSE
		if a.hit.power <= 0.0 and b.hit.power <= 0.0:
			var axis := first.position.direction_to(second.position)
			if axis.is_zero_approx(): axis = Vector2(a.dir).normalized()
			var speed := knock_speed(Arena.TILE * 0.5)
			first.knock = -axis * speed
			second.knock = axis * speed
		return true
	return false

func _step_pending_melee(dt: float) -> void:
	var due: Array[Dictionary] = []
	for pm in pending_melee:
		if not is_instance_valid(pm["mon"]) or pm["mon"].dead:
			pm["cancel"] = true
		if pm.get("cancel", false):
			continue
		var before: float = float(pm["t"])
		pm["t"] -= dt
		if float(pm.get("fang_step", 0.0)) > 0.0:
			var caster: Mon = pm["mon"]
			if is_instance_valid(caster) and not caster.dead:
				caster.vel = Vector2.ZERO
				var duration: float = pm["duration"]
				var old_progress := clampf((duration-before-duration*0.6)/(duration*0.4),0.0,1.0)
				var new_progress := clampf((duration-float(pm["t"])-duration*0.6)/(duration*0.4),0.0,1.0)
				var distance := float(pm["fang_step"])*(new_progress*new_progress-old_progress*old_progress)
				caster.position=resolve_melee_advance(caster,Vector2(pm["dir"])*distance)
		if pm.t <= 0.0: due.append(pm)
	if due.size() > 1: due.sort_custom(func(a, b): return a.t < b.t)
	for pm in due:
		if pm.get("cancel", false) or pm.t > 0.0 or pm.mon.dead: continue
		if _try_melee_clash(pm): continue
		if pm.hit.has("clash_melee"):
			pm.mon.attack_lunge = false
			if pm.hit.power <= 0.0: continue
		_melee_arc(pm.mon, MoveDB.get_move(pm.move), pm.hit, pm.dir)
	pending_melee = pending_melee.filter(func(pm): return pm.t > 0.0 and not pm.get("cancel", false))

# Hits that arrive first can interrupt the opponent's wind-up.

func _interrupt_melee(target: Mon) -> void:
	var had := false
	for pm in pending_melee:
		if pm["mon"] == target and not pm.get("cancel", false):
			if pm.hit.get("clash_melee", false) and pm.hit.power <= 0.0: continue
			if pm.hit.has("cast_fx_ref") and not pm.hit.has("clash_melee"):
				var cut: Fx = pm.hit.cast_fx_ref.get_ref()
				if is_instance_valid(cut): cut.dead = true
			pm["cancel"] = true
			had = true
	if had:
		target.glide = {}
		target.attack_anim_t = 0.0
		target.attack_lunge = false
		target.attack_direction = Vector2.ZERO

# 변화기(울음소리·무서운얼굴): 앞 부채꼴(몸 가장자리 기준 range) 안의 상대 랭크를 바꾼다. 맞은 쪽은 떨고 원작 능력 변화 연출.
func _status_cone(mon: Mon, m: Dictionary, dir: Vector2) -> void:
	var reach: float = m["range"]
	var half := deg_to_rad(float(m["arc_deg"])) / 2.0
	var style := String(m.get("fx", ""))
	# 쓰는 쪽 연출
	var mouth := mon.position + Vector2(0, -mon.radius * 0.6) + dir * (mon.radius+Projectile.RELEASE_GAP)
	if String(m["id"])=="sing":
		KantoMoveFx.sing(self,mon,mouth,dir,reach)
	elif String(m["id"])=="hypnosis":
		KantoMoveFx.hypnosis(self,mon,dir,reach)
	elif String(m["id"])=="supersonic":
		KantoMoveFx.sonic(self,mon,mouth,dir,reach)
	elif style == "noise_c":
		_growl_fracture(mon,mouth,dir,reach)
	elif style == "noise":
		# 플래티넘 growl.spa: 입에서 소리 고리가 셋 차례로 커지며 앞으로 퍼진다.
		for k in 3:
			add_fx("sprite", mouth, {"text": "g4_ring", "color": Color(1.0, 0.8, 0.9, 0.9), "size": mon.radius * 1.2, "grow": 4.0,
				"dir": dir, "speed": reach / 0.45, "lifetime": 0.45, "delay": 0.12 * k})
	elif style == "thunderwave":
		# thunder_wave.spa: 노란 고리가 몸에서 커지며 앞으로 퍼지고, 호(arcs)가 뒤따른다.
		var body := mon.position + Vector2(0, -mon.radius * 0.4)
		add_fx("sprite", body, {"text": "g4_tw_ring", "color": Color8(248, 248, 96, 220), "size": mon.radius * 1.6, "grow": 3.5,
			"dir": dir, "speed": reach / 0.5, "lifetime": 0.5, "fade_out": 0.25})
		for k in 2:
			add_fx("sprite", body, {"text": "g4_tw_arcs", "color": Color8(248, 248, 0, 230), "size": mon.radius * 2.4, "rot": dir.angle() + PI / 2.0,
				"dir": dir, "speed": reach / 0.45, "lifetime": 0.45, "delay": 0.1 * (k + 1), "fade_out": 0.2})
	elif style == "sand":
		# 모래뿌리기: 모래색 연기 뭉치가 앞 부채꼴로 흩뿌려진다(smoke_screen 텍스처를 모래색으로).
		for k in 8:
			var a := dir.angle() + lerpf(-half, half, float(k) / 7.0) * 0.8
			add_fx("sprite", mouth, {"text": "g4_smoke", "color": Color(0.85, 0.75, 0.5, 0.9), "size": mon.radius * 1.0, "grow": 2.2,
				"dir": Vector2.from_angle(a), "speed": reach / 0.4 * randf_range(0.8, 1.1), "lifetime": 0.45, "delay": 0.02 * (k % 4)})
	elif style in ["powder_poison", "powder_sleep"]:
		# poison_powder / sleep_powder.spa: 가루 알갱이(보라 / 청록)가 앞 부채꼴로 흩날리며 내려앉는다.
		var col := Color8(208, 72, 248, 230) if style == "powder_poison" else Color8(104, 232, 176, 230)
		for k in 14:
			var a := dir.angle() + randf_range(-half, half)
			add_fx("sprite", mouth + Vector2(0, -6), {"text": "g4_powder", "color": col, "size": randf_range(6.0, 10.0),
				"dir": Vector2.from_angle(a), "speed": reach / 0.7 * randf_range(0.6, 1.1), "lifetime": 0.8, "delay": 0.03 * k, "fade_out": 0.4})
	elif style == "sweetscent":
		# sweet_scent.spa: 분홍 향기 안개가 몸 둘레로 둥글게 퍼지고 꽃잎이 사방으로 흩날린다(원형, 사용자 결정 2026-10-29).
		var body := mon.position + Vector2(0, -mon.radius * 0.4)
		for k in 10:
			var a := TAU * float(k) / 10.0
			add_fx("sprite", body, {"text": "g4_smoke", "color": Color8(248, 200, 208, 170), "size": mon.radius * 1.4, "grow": 2.6,
				"dir": Vector2.from_angle(a), "speed": (reach + mon.radius) / 0.9, "lifetime": 0.9, "fade_in": 0.15, "delay": 0.02 * (k % 3)})
		for k in 12:
			add_fx("sprite", body, {"text": "g4_petal_pink", "color": Color.WHITE, "size": 7.0, "spin": randf_range(-6.0, 6.0),
				"dir": Vector2.from_angle(randf() * TAU), "speed": (reach + mon.radius) / 0.8 * randf_range(0.6, 1.1), "lifetime": 0.9, "delay": 0.04 * k})
	elif style == "scaryface_c":
		_scary_face_custom(mon, dir, reach)
	elif style == "scaryface":
		# 플래티넘 scary_face.png: 배경이 검게 가라앉고 쓰는 쪽 위에 보라 얼굴이 4프레임으로 일그러진 뒤 맞은 쪽이 떤다.
		add_fx("dim", mon.position, {"lifetime": 0.9})
		add_fx("anim", mon.position + Vector2(0, -mon.radius * 1.2), {"text": "g4_scary_face", "frames": 4, "lifetime": 0.8, "size": mon.radius * 4.0, "delay": 0.1})
	if style == "scaryface_c":
		# Resolve the cone at the final-frame surprise, using the same visual clock.
		var caster_ref: WeakRef = weakref(mon)
		var resolve := func() -> void:
			var caster: Mon = caster_ref.get_ref()
			if is_instance_valid(caster) and not caster.dead:
				_status_cone_apply(caster, m, dir, reach, half, style)
		pending_calls.append({"t":Fx.SCARE_DURATION*Fx.SCARE_SNAP_START,"call":resolve})
	else:
		_status_cone_apply(mon, m, dir, reach, half, style)

# Broken wave fronts: paired shadow/highlight edges suggest disturbed air, not rings.
func _growl_fracture(mon: Mon, mouth: Vector2, forward: Vector2, reach: float) -> void:
	var side := forward.orthogonal()
	for pulse in 3:
		var delay := float(pulse)*0.09
		for lane in 5:
			var u := float(lane-2)/2.0
			var zig: float = [-0.65,0.20,-0.30,0.65,-0.10][lane]
			var axis := (side+forward*zig*0.55).normalized()
			var flow := forward*(reach/0.34)+side*u*(reach*0.48/0.34)
			var origin := mouth+side*u*mon.radius*0.6+forward*zig*1.5
			for edge in 2:
				add_fx("sprite",origin+forward*float(edge)*1.0,{
					"text":"g4_streak","sound_fracture":true,
					"color":Color(0.15,0.20,0.28,0.32) if edge==0 else Color(0.88,0.96,1.0,0.95-float(pulse)*0.15),
					"size":1.9 if edge==0 else 1.5,"stretch":1.6+float(lane%3)*0.25,"grow":1.85,
					"rot":axis.angle()+PI/2.0,"dir":flow.normalized(),"speed":flow.length(),
					"delay":delay+float(lane%3)*0.009,"lifetime":delay+float(lane%3)*0.009+0.34,"fade_in":0.08,"fade_out":0.6})

# 던지는 변화기(연막, 사용자 결정 2026-10-28): 사거리 안의 조준한 자리(클릭)에 검은 공을 던진다. 플래티넘 smoke_screen.spa —
# 공(덩어리 텍스처)이 날아가 떨어진 자리에서 연기 뭉치가 사방으로 퍼지고 고리가 번지며, 그 순간 둘레 radius 안의 상대에게 랭크 변화.
func _lob(mon: Mon, m: Dictionary, dir: Vector2, aim_pos: Vector2) -> void:
	var reach: float = m["range"]
	var radius: float = m["radius"]
	var mouth := mon.position + Vector2(0, -mon.radius * 0.6) + dir * (mon.radius+Projectile.RELEASE_GAP)
	var land := aim_pos if AreaAim.is_area_move(m) else mon.position + (aim_pos - mon.position).limit_length(reach)
	var dist := mouth.distance_to(land)
	var travel := clampf(0.15 + dist / 320.0, 0.15, 0.5)
	var style := String(m.get("fx", "smoke"))
	if style in ["leechseed", "worryseed", "seedbomb", "sludgebomb"]:
		_lob_seed(mon, m, mouth, land, travel, radius, style)
		return
	if style == "rocktomb":
		_rock_tomb(mon, m, land, radius)
		return
	if style == "smoke_c":
		_smoke_lob_custom(mon, m, mouth, land, travel, radius)
		return
	add_fx("sprite", mouth, {"text": "g4_smoke_blob", "color": Color(0.12, 0.12, 0.16, 1.0), "size": mon.radius * 1.4,
		"dir": (land - mouth).normalized(), "speed": dist / travel, "spin": 6.0, "lifetime": travel, "fade_out": 0.15})
	var stat: Dictionary = m.get("stat", {})
	var body_radius := mon.radius
	var source_team := mon.team
	var player_cast := mon == player
	var burst := func() -> void:
		for k in 12:
			var a := TAU * float(k) / 12.0 + randf_range(-0.2, 0.2)   # 연출 무작위는 게임 RNG 와 분리
			add_fx("sprite", land, {"text": "g4_smoke", "color": Color(0.18, 0.18, 0.24, 0.95), "size": body_radius * 1.4, "grow": 3.2,
				"dir": Vector2.from_angle(a), "speed": radius * 1.6 * randf_range(0.8, 1.2), "spin": randf_range(-3.0, 3.0),
				"lifetime": 0.7, "delay": 0.02 * (k % 4)})
		add_fx("sprite", land, {"text": "g4_smoke_ring", "color": Color(0.3, 0.3, 0.36, 0.8), "size": body_radius * 1.5,
			"grow": radius * 2.0 / (body_radius * 1.5), "lifetime": 0.45})
		_smoke_land_for_team(source_team, stat, land, radius, player_cast)
	pending_calls.append({"t": travel, "call": burst})

# 씨앗 던지기(씨뿌리기·고민씨·씨폭탄): 원작 Func_MoveEmitterA2BParabolic 처럼 씨앗 구슬이 포물선으로 날아가 떨어진다.
# 떨어진 자리 둘레 radius 의 상대에게: 씨뿌리기 = 씨앗(흡수), 고민씨 = 불면, 씨폭탄 = 피해(물리 80).
func _lob_seed(mon: Mon, m: Dictionary, mouth: Vector2, land: Vector2, travel: float, radius: float, style: String) -> void:
	var seeds := 3 if style == "leechseed" else 1
	var col: Color = {"leechseed": Color8(200, 152, 96), "worryseed": Color8(248, 216, 136), "seedbomb": Color8(200, 184, 0), "sludgebomb": Color8(160, 72, 168)}[style]
	for k in seeds:
		var spread := Vector2((k - (seeds - 1) / 2.0) * radius * 0.5, 0)
		var to := land + spread
		add_fx("sprite", mouth, {"text": "g4_sludge_blob" if style == "sludgebomb" else "g4_seedball", "color": col,
			"size": 8.0 if style not in ["seedbomb", "sludgebomb"] else 12.0,
			"dir": (to - mouth).normalized(), "speed": mouth.distance_to(to) / travel, "arc_h": 18.0 + 6.0 * k, "lifetime": travel,
			"delay": 0.03 * k, "fade_out": 0.1})
	var hit := make_hit(mon, String(m["id"]))
	var caster_ref: WeakRef=weakref(mon)
	var landed := func() -> void:
		if style == "seedbomb":
			for k in 6:
				var a := TAU * float(k) / 6.0
				add_fx("sprite", land, {"text": "g4_smoke_q", "color": Color8(248, 140, 0, 200), "size": radius * 0.6, "grow": 1.8,
					"dir": Vector2.from_angle(a), "speed": radius * 1.5, "lifetime": 0.4})
			add_fx("sprite", land, {"text": "g4_burst_q", "color": Color8(248, 208, 0, 200), "size": radius * 0.9, "grow": 1.3, "lifetime": 0.2})
		elif style == "worryseed":
			add_fx("sprite", land, {"text": "g4_puff", "color": Color(1, 1, 1, 0.85), "size": radius * 1.2, "grow": 1.8, "lifetime": 0.4})
		elif style == "sludgebomb":
			# sludge_bomb.spa: 오물 덩이가 터지며(보라, 진보라로 어두워짐) 거품이 사방으로 튄다.
			add_fx("sprite", land, {"text": "g4_sludge_blob", "color": Color8(216, 136, 216, 230), "size": radius * 1.2, "grow": 1.6, "lifetime": 0.3})
			for k in 6:
				var a := TAU * float(k) / 6.0 + 0.3
				add_fx("sprite", land, {"text": "g4_sludge_bubble", "color": Color8(224, 128, 224, 230), "size": radius * 0.5, "grow": 1.4,
					"dir": Vector2.from_angle(a), "speed": radius * 1.6, "lifetime": 0.4, "delay": 0.03 * k})
		var caster: Mon=caster_ref.get_ref()
		if not is_instance_valid(caster):
			return
		var hit_any := false
		for t in opponents(caster.team):
			if t.dead or t.position.distance_to(land) > radius + t.radius * 0.5:
				continue
			hit_any = true
			if style in ["seedbomb", "sludgebomb"]:
				apply_hit(t, hit, land)
			else:
				apply_status_move(t, hit)
				if style == "leechseed" and t.leech_t > 0.0:
					# 싹이 트는 연출(leech_seed.spa 싹 셋).
					for j in 3:
						var o := Vector2((j - 1) * t.radius * 0.6, -t.radius * 0.2)
						add_fx("sprite", t.position + o, {"text": ["g4_sprout_a", "g4_sprout_b", "g4_sprout_c"][j], "color": Color.WHITE,
							"size": t.radius * 1.0, "grow": 1.4, "lifetime": 0.6, "delay": 0.06 * j, "follow": t, "offset": o})
		if not hit_any and caster == player and _text_cd <= 0.0:
			float_text(land + Vector2(0, -10), Lang.t("nothing"), Color("e0e0e0"), 7)
			_text_cd = TEXT_COOLDOWN
	pending_calls.append({"t": travel, "call": landed})

# 암석봉인(rock_tomb.spa): 바위 셋이 조준한 자리 위에서 차례로 떨어진다. 마지막 바위가 닿는 순간 둘레 radius 의 상대에게 피해 + 스피드 −1.
func _rock_tomb(mon: Mon, m: Dictionary, land: Vector2, radius: float, count: int=3) -> void:
	const FALL := 0.3
	const DROP_H := 70.0
	for k in count:
		var a := TAU * float(k) / float(count) + 0.5
		var spot := land + Vector2.from_angle(a) * radius * 0.45 if count>1 else land
		add_fx("sprite", spot + Vector2(0, -DROP_H), {"text": "g4_rock", "color": Color.WHITE, "size": 14.0, "dir": Vector2.DOWN,
			"speed": DROP_H / FALL, "lifetime": FALL + 0.12 * k + 0.35, "delay": 0.12 * k, "fade_out": 0.15})
		add_fx("sprite", spot + Vector2(0, 4), {"text": "g4_puff", "color": Color(0.85, 0.8, 0.7, 0.8), "size": 10.0, "grow": 1.8,
			"lifetime": FALL + 0.12 * k + 0.35, "delay": FALL + 0.12 * k})
	var hit := make_hit(mon, String(m["id"]))
	var caster_ref: WeakRef=weakref(mon)
	var landed := func() -> void:
		var caster: Mon=caster_ref.get_ref()
		if not is_instance_valid(caster):
			return
		for t in opponents(caster.team):
			if not t.dead and t.position.distance_to(land) <= radius + t.radius * 0.5:
				apply_hit(t, hit, land)
				t.shake_t = 0.3
	pending_calls.append({"t": FALL + 0.12*(count-1), "call": landed})

## Existing powder particles gather around a fixed ground circle, then apply the normal status rules once.
func _powder_area(mon: Mon,m: Dictionary,land: Vector2) -> void:
	var radius: float=m["radius"]
	var color:=Color8(208,72,248,230) if String(m.id)=="poison_powder" else Color8(104,232,176,230)
	for index in 14:
		var angle:=TAU*float(index)/14.0
		var direction:=Vector2.from_angle(angle)
		var offset:=direction*radius*(.25+.5*float(index%4)/3.0)
		add_fx("sprite",land+offset+Vector2(0,-6),{"text":"g4_powder","color":color,"size":fx_rng.randf_range(6,10),
			"dir":direction,"speed":radius*.3,"lifetime":.8,"delay":.02*(index%3),"fade_out":.4})
	var hit:=make_hit(mon,String(m.id))
	var caster_ref: WeakRef=weakref(mon)
	var apply:=func() -> void:
		var caster: Mon=caster_ref.get_ref()
		if not is_instance_valid(caster):return
		for target: Mon in opponents(caster.team):
			if target.dead or not target.visible or target.appear<1.0:continue
			if target.position.distance_to(land)<=radius+target.radius*.5:apply_status_move(target,hit)
	pending_calls.append({"t":.12,"call":apply})

# 피해 없는 변화기(가루·씨뿌리기·고민씨)를 한 상대에게: 방어·명중(회피) 판정 뒤 상태만.
func apply_status_move(target: Mon, hit: Dictionary) -> void:
	if target.dead:
		return
	if target.protect_t > 0.0:
		float_text(target.position + Vector2(0, -target.radius - 14), Lang.t("protected", [_battle_name(target)]), Color("a8f0a8"), 7)
		return
	# 독가루: 독·강철 타입은 안 걸린다(원작). 이미 다른 상태면 실패.
	if float(hit.get("poison", 0.0)) > 0.0:
		if not Mon.poison_unlocked or target.types().has("poison") or target.types().has("steel") or target.poison_t > 0.0 or target.sleep_t > 0.0 or target.burn_t > 0.0:
			_status_text(target, Lang.t("no_effect" if target.types().has("poison") or target.types().has("steel") else "no_effect_status", [_battle_object_name(target)]))
		else:
			_inflict_status(target,"poison")
			target.start_tint(Color8(208, 72, 248), 0.5, 0.5)
	_apply_extra_status(target, hit)

# 부채꼴 안의 상대에게 랭크 변화를 준다.
func _status_cone_apply(mon: Mon, m: Dictionary, dir: Vector2, reach: float, half: float, style: String) -> void:
	if not is_instance_valid(mon):
		return
	var stat: Dictionary = m.get("stat", {})
	var hit_any := false
	var recipients:=opponents(mon.team)
	if m.get("target_pattern","") in ["self","friendly"]:
		recipients=[] if m.get("original_target",0)==3 else [mon]
	elif m.get("target_pattern","")=="field" and m.get("original_target",0) in [12,14]:
		recipients=recipients.duplicate()
		recipients.append(mon)
	for t in recipients:
		if t.dead:
			continue
		var to: Vector2 = t.position - mon.position
		if to.length() - mon.radius - t.radius > reach or absf(angle_difference(dir.angle(), to.angle())) > half:
			continue
		hit_any = true
		if m.has("poison") or m.has("sleep") or m.has("confuse"):
			# 가루: 맞은 자리에 가루 색이 번진다.
			apply_status_move(t, make_hit(mon, String(m["id"])))
		if m.has("paralyze"):
			if t.protect_t > 0.0:
				float_text(t.position + Vector2(0, -t.radius - 14), Lang.t("protected", [_battle_name(t)]), Color("a8f0a8"), 7)
			elif TypeChart.effectiveness(String(m["type"]), t.types()) <= 0.0 or t.sleep_t > 0.0 or t.poison_t > 0.0 or t.burn_t > 0.0 or t.para_t > 0.0:
				_status_text(t, Lang.t("no_effect" if TypeChart.effectiveness(String(m["type"]), t.types()) <= 0.0 else "no_effect_status", [_battle_object_name(t)]))      # 전기자석파: 땅 타입(전기 무효)·이미 상태이상이면 실패(원작)
			else:
				_paralyze(t)
		if not stat.is_empty():
			if t.protect_t > 0.0:
				_status_text(t, Lang.t("protected", [_battle_name(t)]))
				continue
			var attack_before: int = t.atk_stage
			_apply_stat(t, stat, style in ["scaryface", "scaryface_c"])
			if style == "noise_c" and t.atk_stage < attack_before:
				for side in [-1,1]:
					var offset := Vector2(float(side)*t.radius*0.8,-t.radius*0.6)
					add_fx("sprite",t.position+offset,{"text":"g4_streak","color":Color(0.55,0.72,1.0,0.75),
						"size":t.radius*0.5,"stretch":1.8,"grow":0.45,"dir":Vector2.DOWN,"speed":12.0,
						"lifetime":0.3,"fade_out":0.7,"follow":t,"offset":offset})
	# 달콤한향기: 바깥 풀숲에서 쓰면 원작처럼 야생을 불러낸다(Game 이 받는다).
	if bool(m.get("lure", false)) and mon == player:
		lured.emit()
	if not hit_any and mon == player and _text_cd <= 0.0 and not bool(m.get("lure", false)):
		float_text(mon.position + Vector2(0, -mon.radius - 10), Lang.t("nothing"), Color("e0e0e0"), 7)
		_text_cd = TEXT_COOLDOWN

# 마비(사용자 결정 2026-11-02: 원작 그대로): 고칠 때까지 이동 속도 1/4, 기술을 쓰려 할 때 25% 로 몸이 저려 못 쓴다(full_paralysis).
# 걸리는지(면역·이미 상태이상·방어)는 부르는 쪽이 본다.
func _paralyze(t: Mon) -> void:
	t.inflict("paralyze")
	_status_text(t, Lang.t("got_paralyzed", [_battle_name(t)]))
	_paralyze_fx(t)

# 마비된 포켓몬이 기술을 쓰려는 순간: 25% 로 기술이 나가지 않고(PP 도 그대로) 한 턴 동안 기술을 못 쓴다(사용자 요청 2026-11-02).
# true 면 기술이 막힌 것.
func full_paralysis(mon: Mon) -> bool:
	if mon.para_t <= 0.0 or rng.randf() >= Mon.PARA_FAIL:
		return false
	mon.para_lock_t = Mon.TURN
	mon.vel = Vector2.ZERO
	_status_text(mon, Lang.t("para_cant_move", [_battle_name(mon)]))
	_paralyze_fx(mon)
	return true

# thunder_wave.spa 의 번개 둘이 몸 양옆에서 지직거린다.
func _paralyze_fx(t: Mon) -> void:
	var up := Vector2(0, -t.radius * 0.5)
	for i in 2:
		var o := Vector2((i * 2 - 1) * t.radius * 0.7, 0)
		add_fx("sprite", t.position + up + o, {"text": "g4_tw_bolt_a" if i == 0 else "g4_tw_bolt_b", "color": Color8(248, 248, 0, 240),
			"size": t.radius * 1.8, "lifetime": 0.3, "follow": t, "offset": up + o, "fade_out": 0.15})
	add_fx("sprite", t.position + up, {"text": "g4_hitburst", "color": Color8(248, 248, 120, 200), "size": t.radius * 1.6, "grow": 1.5, "lifetime": 0.18})

# 땅고르기 시전: 내 발밑에서 흙먼지 고리가 둘레(reach)까지 퍼진다.
func _bulldoze_fx(mon: Mon, reach: float) -> void:
	var feet := mon.position + Vector2(0, mon.radius * 0.6)
	for k in 10:
		var a := TAU * float(k) / 10.0
		add_fx("sprite", feet, {"text": "g4_dust", "color": Color(0.8, 0.72, 0.55, 0.85), "size": mon.radius * 1.2, "grow": 2.0,
			"dir": Vector2.from_angle(a), "speed": reach / 0.3, "lifetime": 0.35, "delay": 0.02 * (k % 3), "fade_out": 0.2})
	mon.shake_t = 0.25

# Scarlet/Violet common text: subject, ownership and localized stat name.
func _battle_name(mon: Mon) -> String:
	var name := mon.display_name()
	if mon is Enemy:
		if (mon as Enemy).trainer_owned:
			name = ("상대 " if Lang.is_ko() else "The opposing ")+name
		else:
			name = ("야생 " if Lang.is_ko() else "The wild ")+name
	return name

# English ownership is lowercase when the name occurs inside a sentence.
func _battle_object_name(mon: Mon) -> String:
	var subject := _battle_name(mon)
	if Lang.code == "en" and subject.begins_with("The "):
		return "the " + subject.substr(4)
	return subject

func _rank_subject(mon: Mon, key: String) -> String:
	var name := _battle_name(mon)
	var label := Lang.stat_label(key) if Lang.is_ko() else str({"atk":"Attack","def":"Defense","spa":"Sp. Atk","spd":"Sp. Def","spe":"Speed","acc":"accuracy","eva":"evasiveness"}.get(key,key))
	return name+("의\n" if Lang.is_ko() else "’s ")+label

static func _rank_change_key(delta: int) -> String:
	if delta > 0:
		return "stat_drastic_rose" if delta>=3 else "stat_sharp_rose" if delta==2 else "stat_rose"
	return "stat_drastic_fell" if delta<=-3 else "stat_sharp_fell" if delta==-2 else "stat_fell"

# 랭크 변화를 적용하고 원작 대사·연출(몸 안에 무늬가 위/아래로 흐름)을 띄운다. delayed 면 얼굴이 뜬 뒤에 떨린다.
func _apply_stat(t: Mon, stat: Dictionary, delayed: bool) -> void:
	for key in stat:
		var amount := int(stat[key])
		var before: int = t.get(key + "_stage")
		var after := clampi(before + amount, -6, 6)
		t.set(key + "_stage", after)
		var msg: String
		var label := _rank_subject(t,key)
		if after == before:
			msg = Lang.t("stat_wont_up" if amount > 0 else "stat_wont_down", [label])
		else:
			msg = Lang.t(_rank_change_key(after-before), [label])
			t.play_stat(key + ("_up" if amount > 0 else "_down"))
			t.shake_t = 0.35
		float_text(t.position + Vector2(0, -t.radius - 10), msg, Color("c8d8ff"), 7)

# Scale only the artwork emitted for this hit. HUD text, status feedback and attack range are independent.
func _scale_melee_fx(hit: Dictionary, first: int) -> void:
	if not hit.get("clash_melee", false): return
	var ratio := float(hit.clash_fraction)
	for index in range(first, fxs.size()):
		var effect: Fx = fxs[index]
		if effect.kind in ["sprite", "anim", "impact", "fang", "fangfire"]:
			effect.size *= ratio
			effect.speed *= ratio

func _melee_arc(mon: Mon, m: Dictionary, hit: Dictionary, dir: Vector2) -> void:
	var move_id := String(hit.get("move",""))
	if move_id in ["scratch","fire_fang"] and not hit.has("clash_melee"): Sfx.move(move_id,-1.0,_battle_sound_db(mon.position), _battle_sound_pan(mon.position), get_instance_id())
	var reach: float = m["range"]   # 몸 가장자리에서 상대 몸 가장자리까지의 틈
	var half := deg_to_rad(m["arc_deg"]) / 2.0
	var style := "" if hit.get("forward_cut", false) else String(m.get("fx", ""))
	for t in opponents(mon.team):
		var to: Vector2 = t.position - mon.position
		if to.length() - mon.radius - t.radius > reach:
			continue
		# 몸이 겹칠 만큼 가까우면 각도와 상관없이 맞는다.
		if to.length() > mon.radius + t.radius and absf(angle_difference(dir.angle(), to.angle())) > half:
			continue
		if apply_hit(t, hit, mon.position):
			var first_fx := fxs.size()
			# 맞은 쪽은 밀려나므로 자국은 몸을 따라간다(follow).
			var up := Vector2(0, -t.radius * 0.5)
			var body: Vector2 = t.position + up
			# 할퀴기(플래티넘 scratch.spa): 발톱 자국 셋이 비스듬히 그어졌다 사라진다.
			if style == "claw":
				add_fx("sprite", body, {"text": "g4_claw3", "color": Color.WHITE, "size": t.radius * 3.2, "grow": 1.15,
					"rot": dir.angle() + PI / 2.0 + 0.45, "lifetime": 0.32, "follow": t, "offset": up})
			# 할퀴기 커스텀(FxStyle): 맞은 몸에 작은 발톱 자국과 짧은 타격 터짐. 범위 호는 그리지 않는다(사용자 2026-11-02).
			if style == "claw_c":
				_scratch_hit_custom(t, dir)
			# 베어가르기(slash.spa): 긴 줄 한 가닥이 크게 그어지고 별 불티 둘.
			if style == "slash":
				add_fx("sprite", body, {"text": "g4_streak", "color": Color.WHITE, "size": t.radius * 1.6, "stretch": 3.4, "grow": 1.3,
					"rot": dir.angle() + PI / 4.0, "lifetime": 0.28, "follow": t, "offset": up})
				for s in [-1.0, 1.0]:
					var o: Vector2 = up + dir.rotated(PI / 4.0) * s * t.radius * 0.8
					add_fx("sprite", t.position + o, {"text": "g4_spark", "color": Color.WHITE,
						"size": t.radius * 1.0, "grow": 1.6, "lifetime": 0.2, "delay": 0.05, "follow": t, "offset": o})
			# 메탈클로(moves/claw.png): 파란 빛이 발톱 자국으로 길어지는 5프레임이 두 번. 10% 로 자기 공격 ↑.
			if style == "metal":
				for swipe in 2:
					add_fx("anim", body, {"text": "g4_claw_strike", "frames": 5, "size": t.radius * 4.0, "lifetime": 0.3, "delay": swipe * 0.2,
						"rot": dir.angle() - Vector2(-1, 1).angle() + (PI if swipe == 1 else 0.0), "follow": t, "offset": up})
				t.shake_t = 0.3
				if rng.randf() < float(m.get("self_atk_up", 0.0)):
					_apply_stat(mon, {"atk": 1}, false)
			# 연속찌르기(플래티넘 horn_attack 뿔 + 타격 터짐): 뿔이 날아와 꽂히고(타마다 좌우 번갈아) 터짐, 맞은 쪽이 흔들린다.
			if style == "horn":
				var side := Vector2(-dir.y, dir.x) * (8.0 if _horn_flip else -8.0)
				_horn_flip = not _horn_flip
				var at: Vector2 = t.position + Vector2(0, -t.radius * 0.5) + side
				add_fx("sprite", at - dir * 36.0, {"text": "g4_horn", "color": Color.WHITE, "size": t.radius * 2.0, "rot": dir.angle() + PI / 2.0,
					"dir": dir, "speed": 36.0 / 0.12, "lifetime": 0.16, "fade_out": 0.25})
				add_fx("sprite", at, {"text": "g4_hitburst", "color": Color.WHITE, "size": t.radius * 2.0, "grow": 1.8, "lifetime": 0.2, "delay": 0.1})
				t.shake_t = 0.3
			if style in ["pound","peck","astonish"]:
				KantoMoveFx.contact_hit(self, t, style, dir)
			_melee_fx_new(mon, t, style, dir, up)
			# 몸통박치기(tackle.spa): 맞은 몸에서 타격 터짐.
			if style == "bump":
				add_fx("sprite", body, {"text": "g4_hitburst", "color": Color.WHITE, "size": t.radius * 2.4, "grow": 1.8, "lifetime": 0.22, "follow": t, "offset": up})
			_scale_melee_fx(hit, first_fx)
	# 고속스핀: 맞히든 아니든 씨뿌리기 같은 묶임에서 벗어나고(원작), 둘레에 소용돌이가 돈다.
	if bool(m.get("clear_hazards", false)):
		mon.leech_t = 0.0
		add_fx("sprite", mon.position + Vector2(0, -mon.radius * 0.4), {"text": "g4_swirl", "color": Color(0.72, 1.0, 1.0, 0.85),
			"size": (mon.radius + reach) * 1.5 * float(hit.get("clash_fraction", 1.0)), "spin": -14.0, "grow": 1.1, "lifetime": 0.35, "follow": mon, "offset": Vector2(0, -mon.radius * 0.4)})

# ── 커스텀 연출(FxStyle, 사용자 요청 2026-11-02) ──

# One bite: teeth close at 0.12s, then the hot core and small embers break outward.
func _fire_fang_cast_custom(mon: Mon, direction: Vector2, close_time: float) -> Fx:
	var aim := direction.normalized() if direction.length_squared() > 0.001 else mon.facing
	var row := posmod(roundi((aim.angle() + PI / 2.0) / (PI / 4.0)), 8)
	var facing := Vector2.UP.rotated(row * PI / 4.0)
	var reach := float(MoveDB.get_move("fire_fang")["range"])
	var offset := facing * (mon.radius + reach * 0.45) + Vector2(0, -mon.radius * 0.5)
	return add_fx("fang_directional", mon.position + offset, {"lifetime":close_time+0.13,"size":reach*1.5,
		"follow":mon,"offset":offset,"dir":facing,"fang_row":row,"fang_close_time":close_time})

func _fire_fang_hit_custom(target: Mon, forward: Vector2) -> void:
	var body := Vector2(0, -target.radius * 0.5)
	add_fx("sprite", target.position + body, {"text":"g4_hitburst","color":Color(1.0,0.88,0.48,0.9),
		"size":target.radius*1.5,"grow":1.25,"delay":0.0,"lifetime":0.25,"fade_out":0.8,"follow":target,"offset":body})
	for i in 6:
		var angle := TAU * i / 6.0 + randf_range(-0.18,0.18)
		var drift := Vector2.from_angle(angle)
		var offset := body + drift * target.radius * 0.2
		add_fx("sprite", target.position + offset, {"text":"g4_flame" if i%2==0 else "ff_puff",
			"color":Color(1.0,0.8,0.5,0.95),"size":target.radius*randf_range(1.1,1.4),
			"grow":1.7,"stretch":randf_range(0.8,1.25),"rot":angle*0.12,
			"dir":(drift*0.55+Vector2.UP*0.7).normalized(),"speed":18.0,
			"delay":i*0.009,"lifetime":0.54+i*0.009,"fade_in":0.1,"fade_out":0.55,"follow":target,"offset":offset})
		add_fx("sprite", target.position + body, {"text":"g4_spark","color":Color(1.0,0.72,0.25,0.85),
			"size":target.radius*0.22,"grow":0.3,"dir":(drift+forward*0.35).normalized(),"speed":36.0,
			"delay":0.01,"lifetime":0.42,"fade_out":0.8,"follow":target,"offset":body})
	target.shake_t = 0.3

func _scratch_hit_custom(target: Mon, direction: Vector2) -> void:
	var angle := -clampf(direction.x, -1.0, 1.0) * 0.28
	var across := Vector2.RIGHT.rotated(angle)
	var up := Vector2(0, -target.radius * 0.5)
	for i in 3:
		var offset := up + across * float(i-1) * target.radius * 0.48
		add_fx("sprite", target.position+offset, {
			"text":"g4_streak", "color":Color(0.92,0.87,0.76,0.95),
			"size":target.radius*0.48, "stretch":3.8 if i==1 else 3.1, "grow":1.0, "claw_downstroke":true,
			"rot":angle, "delay":float(i)*0.018, "lifetime":0.19+float(i)*0.018,
			"fade_in":0.08, "fade_out":0.65, "follow":target, "offset":offset})
	add_fx("anim", target.position+up, {"text":"pixelfx_scratch", "frames":16,
		"size":target.radius*2.6, "delay":0.025, "lifetime":0.23,
		"body_impact":true, "follow":target, "offset":up})

# 불꽃세례: 입에서 불씨가 터진다(발사 순간).
func _ember_muzzle(mon: Mon, dir: Vector2) -> void:
	var mouth := mon.position + Vector2(0, -mon.radius * 0.2) + dir * (mon.radius+Projectile.RELEASE_GAP)
	add_fx("sprite", mouth, {"text":"g4_flame","color":Color(1.0,0.55,0.15,0.9),
		"size":mon.radius*1.3,"grow":1.3,"lifetime":0.14})

# Ember uses the original Platinum flame mask and orange tint. A brief body
# envelope has actual front/back depth in HD-2D, without a physical hit-star.
func _ember_hit_custom(target: Mon, from_pos: Vector2, burn: bool = true) -> void:
	var up := Vector2(0, -target.radius * 0.5)
	var away := (target.position - from_pos).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	if burn:
		_ember_burn(target.position,away)
	for i in 6:
		var phase := TAU*float(i)/6.0
		var offset := up+Vector2(float(i%3-1)*target.radius*0.68,float(i%2)*target.radius*0.10)
		add_fx("sprite",target.position+offset,{
			"text":"g4_flame", "ember_coat":true,"ember_phase":phase,
			"color":Color(1.0,0.55,0.15,0.68 if i<3 else 0.78),
			"size":target.radius*(1.25+float(i%3)*0.10), "stretch":1.05+float(i%2)*0.15,
			"grow":0.25,"dir":Vector2.UP,"speed":4.0+float(i%3),
			"rot":float(i%3-1)*0.10,"delay":float(i%3)*0.018,"lifetime":0.50+float(i%3)*0.045,
			"fade_in":0.12,"fade_out":0.50,"follow":target,"offset":offset,
			"body_impact":true,"body_depth":-0.045 if i<3 else 0.035})
	var scorch := add_fx("sprite", target.position + Vector2(0, target.radius * 0.6), {"text": "g4_glow", "color": Color(0.12, 0.06, 0.02, 0.45),
		"size": target.radius * 2.6, "stretch": 0.45, "lifetime": 0.9, "fade_out": 0.5})
	scorch.z_index = -1
	target.start_tint(Color.RED, 10.0 / 16.0, 20.0 / 60.0)
	target.shake_t = 8.0 / 60.0
	target.shake_px = 1.0

# 불꽃세례가 맞지 않고 꺼졌다(사거리 끝·벽): 작은 연기와 불티 둘 — 어디까지 날아가는지 보인다.
func _ember_fizzle(at: Vector2, forward: Vector2) -> void:
	_ember_burn(at,forward)
	add_fx("sprite", at, {"text": "g4_smoke", "color": Color(0.6, 0.56, 0.52, 0.9), "size": 11.0, "grow": 1.8, "dir": Vector2.UP, "speed": 12.0, "lifetime": 0.4})
	for i in 3:
		add_fx("sprite", at, {"text":"g4_flame","ember_phase":float(i)*1.7,"color":Color(1.0,0.55,0.15,0.85), "size": 6.0, "grow": 0.4,
			"dir": Vector2(float(i - 1) * 0.6, -1.0).normalized(), "speed": 28.0, "lifetime": 0.3})

# A single lateral flare per volley: center first, then two waves to each side.
# Visual-only, attached to the ground rather than the moving victim.
func _ember_burn(at: Vector2, forward: Vector2) -> void:
	var direction := forward.normalized() if forward.length_squared()>0.001 else Vector2.RIGHT
	var side := direction.orthogonal()
	for lane in [-2,-1,0,1,2]:
		var wave := absf(float(lane))
		var spread := (side*signf(float(lane))+direction*0.12).normalized() if lane!=0 else Vector2.ZERO
		add_fx("sprite",at,{"text":"g4_flame","ember_phase":float(lane)*1.4,
			"color":Color(1.0,0.55,0.15,0.65),"size":11.0-wave*1.0,
			"grow":0.18,"lifetime":0.52+wave*0.09,"delay":wave*0.045,
			"fade_in":0.08,"fade_out":0.7,"dir":spread,"speed":0.0 if lane==0 else 18.0+wave*5.0,
			"grounded_flame":true})

# 연막: 떨어질 자리에 터질 범위 고리가 조여 들고(바닥), 연막탄은 포물선으로 날아가며 그림자가 바닥을 따라간다.
# 떨어지면 고리 안을 연기로 채운다(가운데 하나 + 안쪽 고리 여섯 + 바깥 고리 여덟). 효과는 원작 모드와 같이 _smoke_land.
func _smoke_lob_custom(mon: Mon, m: Dictionary, mouth: Vector2, land: Vector2, travel: float, radius: float) -> void:
	add_fx("dashring", land, {"color": Color(0.12, 0.12, 0.18, 0.8), "size": radius, "grow": 1.25, "lifetime": travel, "fade_in": 0.3})
	var dist := mouth.distance_to(land)
	var dirv := (land - mouth).normalized() if dist > 0.5 else Vector2.RIGHT
	add_fx("sprite", mouth, {"text": "g4_smoke_blob", "color": Color(0.12, 0.12, 0.16, 1.0), "size": mon.radius * 1.3,
		"dir": dirv, "speed": dist / travel, "spin": 6.0, "arc_h": 14.0 + dist * 0.12, "lifetime": travel, "fade_out": 0.1})
	var ground := mon.position + Vector2(0, mon.radius * 0.6)
	var shadow := add_fx("sprite", ground, {"text": "g4_glow", "color": Color(0.0, 0.0, 0.0, 0.3), "size": mon.radius * 1.2, "stretch": 0.5,
		"dir": (land - ground).normalized(), "speed": ground.distance_to(land) / travel, "lifetime": travel, "fade_out": 0.1})
	shadow.z_index = -1
	var stat: Dictionary = m.get("stat", {})
	var body_radius := mon.radius
	var source_team := mon.team
	var player_cast := mon == player
	var burst := func() -> void:
		_smoke_cloud_custom(land, radius, body_radius)
		_smoke_land_for_team(source_team, stat, land, radius, player_cast)
	pending_calls.append({"t": travel, "call": burst})

# Visual cloud only: expand from the center, then clear the outer wisps first.
var _smoke_serial := 0

func _smoke_cloud_custom(land: Vector2, radius: float, body_radius: float) -> void:
	_smoke_serial += 1
	# One short release puff; the existing veil continues to own coverage,
	# overlapping-cloud normalization and the gameplay debuff below.
	add_fx("anim",land+Vector2(0,-body_radius*0.4),{
		"text":"pixelfx_smoke", "frames":31, "size":minf(radius*1.4,body_radius*6.0),
		"smoke_group":_smoke_serial,
		"color":Color(0.72,0.76,0.82,0.7), "lifetime":0.48})
	for ring in 3:
		var count := 1 if ring == 0 else 6 if ring == 1 else 8
		var delay := float(ring)*0.055
		var lifetime := 1.05-float(ring)*0.19
		for i in count:
			var direction := Vector2.from_angle(TAU*float(i)/count+float(ring)*0.23)
			var start := radius*float(ring)*0.14
			var reach := radius*(0.48 if ring==1 else 0.86)
			var speed := 0.0 if ring==0 else (reach-start)/(lifetime-delay)
			add_fx("sprite",land+direction*start,{
				"text":"g4_smoke", "smoke_veil":true,
				"smoke_group":_smoke_serial, "smoke_origin":land, "smoke_radius":radius, "color":Color(0.21,0.23,0.29,0.68-float(ring)*0.08),
				"size":body_radius*(3.5-float(ring)*0.3), "grow":1.85, "stretch":0.62+float(i%3)*0.09,
				"dir":direction, "speed":speed, "rot":float(i%3-1)*0.16,
				"spin":0.16 if i%2==0 else -0.16,
				"lifetime":lifetime, "delay":delay, "fade_in":0.10, "fade_out":0.42})

# Normalize only overlapping casts; the fifteen puffs within one cast keep their original density.
# Gather once per cloud, so pair checks scale with casts rather than puff count.
func _update_smoke_density() -> void:
	var groups := {}
	for f in fxs:
		if not f.smoke_veil or f.smoke_group == 0: continue
		f.smoke_alpha_gain = 1.0
		if f.dead or f.age <= f.delay or f.age >= f.lifetime: continue
		var t := clampf((f.age-f.delay)/maxf(0.001,f.lifetime-f.delay),0.0,1.0)
		var envelope := minf(t/maxf(f.fade_in,0.001),1.0)*minf((1.0-t)/maxf(f.fade_out,0.001),1.0)
		if not groups.has(f.smoke_group):
			groups[f.smoke_group] = {"at":f.smoke_origin,"radius":f.smoke_radius,"weight":envelope}
		else:
			groups[f.smoke_group]["weight"] = maxf(groups[f.smoke_group]["weight"],envelope)
	var gains := {}
	for id in groups:
		var own: Dictionary = groups[id]
		var density := 1.0
		for other in groups:
			if id == other: continue
			var near: Dictionary = groups[other]
			var reach := maxf(1.0,minf(own.radius,near.radius)*1.5)
			var overlap := 1.0-smoothstep(0.0,reach,own.at.distance_to(near.at))
			density += overlap*float(near.weight)
		gains[id] = 1.0/density
	for f in fxs:
		if f.smoke_group != 0: f.smoke_alpha_gain = gains.get(f.smoke_group,1.0)

# Do not stack overlapping puffs into an opaque silhouette.
func smoke_body_shade(at: Vector2) -> float:
	var coverage := 0.0
	for f in fxs:
		coverage = maxf(coverage, f.smoke_cover(at))
	return minf(0.32, coverage*0.48)

# 연막이 떨어진 자리: 범위 안의 상대에게 랭크 변화(명중 −1). 원작·커스텀 모드 공통.
func _smoke_land_for_team(source_team: int, stat: Dictionary, land: Vector2, radius: float, player_cast: bool) -> void:
	var hit_any := false
	for t in opponents(source_team):
		if not t.dead and t.position.distance_to(land) <= radius + t.radius * 0.5:
			hit_any = true
			_apply_stat(t, stat, false)
	if not hit_any and player_cast and _text_cd <= 0.0:
		float_text(land + Vector2(0, -10), Lang.t("nothing"), Color("e0e0e0"), 7)
		_text_cd = TEXT_COOLDOWN

func _spawn_projectile(mon: Mon, hit: Dictionary, m: Dictionary, v: Vector2, scale: float = 1.0) -> void:
	var original := float(hit.get("clash_original_power", 0.0))
	if original > 0.0:
		if float(hit.power) <= 0.0: return
		scale *= float(hit.power) / original
	var p := Projectile.new()
	p.team = mon.team
	p.hit = hit
	p.vel = v
	p.radius = float(m["radius"]) * scale
	p.range_left = float(m["range"])
	p.range_full = float(m["range"])
	p.grow = float(m.get("grow", 1.0))
	p.pierce = bool(m.get("pierce", false))
	p.color = TypeChart.type_color(m["type"])
	p.style = String(m.get("fx", ""))
	if p.style in ["ember_c", "flame_c"]:
		p.flame_texture = "g4_fire_puff" if randf()<0.3 else "g4_flame"
		p.flame_size = randf_range(0.8,1.15)
		p.flame_aspect = Vector2(randf_range(0.75,1.2),randf_range(0.85,1.3))
		p.flame_tilt = randf_range(-0.24,0.24)
		p.flame_phase = randf()*TAU
		p.flame_mirror = randf()<0.5
	p.position = mon.position + v.normalized() * mon.radius * 0.8 + Vector2(0, -mon.radius * 0.2)
	p.emitter = weakref(mon)
	p.launch_position = p.position
	p.flat_release=v.normalized()*(mon.radius*.2+4.0+Projectile.RELEASE_GAP)
	add_child(p)
	projectiles.append(p)
	if p.style == "ember_c" and not Look.view3d:
		_ember_muzzle(mon, v.normalized())

func _add_zone(kind: String, pos: Vector2, mon: Mon, hit: Dictionary, m: Dictionary) -> Zone:
	var z: Zone = FireField.new() if kind=="fire_spin" else Zone.new()
	z.visibility_layer = 1 | Look.GROUND_LAYER          # 장판은 3D 화면에서 바닥 오버레이로
	z.kind = kind
	z.team = mon.team
	z.position = pos
	z.radius = float(m["radius"])
	z.lifetime = float(m["lifetime"])
	z.hit = hit
	z.z_index = -1
	add_child(z)
	zones.append(z)
	return z

# Keep the mouth and the locked Ember volley pointing together while allowing movement.
func _ember_direction(mon: Mon) -> Vector2:
	for burst in bursts:
		if burst["mon"] == mon and burst["move"] == "ember" and int(burst["left"])>0:
			return burst.get("dir",mon.facing)
	return Vector2.ZERO

func _step_bursts(dt: float) -> void:
	for b in bursts:
		if not is_instance_valid(b["mon"]):
			b["left"] = 0
			continue
		var mon: Mon = b["mon"]
		if not is_instance_valid(mon) or mon.dead:
			b["left"] = 0
			continue
		var hold_left := maxf(0.0, float(b.hit.get("clash_resume", 0.0)) - _projectile_clock)
		if hold_left > 0.0 and hold_left >= dt: continue
		b["t"] -= dt - hold_left
		if b["t"] > 0.0 or b["left"] <= 0:
			continue
		var m := MoveDB.get_move(b["move"])
		if mon == player and (not m.get("volley", false) or not b.has("dir")):
			aim_point = _player_skill_aim(String(b["move"]))
		# 연발은 첫 발 방향으로 일자로 나간다(volley). 그 밖의 연사(화염방사)는 조준을 따라간다.
		var dir: Vector2
		if m.get("volley", false):
			if not b.has("dir"):
				b["dir"] = (aim_point - mon.position).normalized() if mon == player else mon.facing
			dir = b["dir"]
		else:
			dir = (aim_point - mon.position).normalized() if mon == player else mon.facing
		var spread := deg_to_rad(m["spread_deg"])
		var a: float
		var speed := float(m["speed"])
		var scale := 1.0
		if m.get("volley", false):
			var total: int = int(m["count"])
			var k: int = total - int(b["left"])
			var u := 0.0 if total <= 1 else float(k) / float(total - 1)
			if bool(m.get("vary", false)):
				# 물대포(사용자 요청 2026-10-30): 쏠 때마다 물줄기 모양이 다르다 — 한 묶음마다 무늬를 뽑고 방울마다 조금씩 흔든다.
				if not b.has("pattern"):
					b["pattern"] = rng.randi_range(0, 3)
					b["spread_mul"] = rng.randf_range(0.8, 1.8)
				var sp: float = spread * float(b["spread_mul"])
				match int(b["pattern"]):
					0: a = dir.angle() + lerpf(-sp / 2.0, sp / 2.0, u)            # 위 → 아래로 훑기
					1: a = dir.angle() + lerpf(sp / 2.0, -sp / 2.0, u)            # 아래 → 위로
					2: a = dir.angle() + (sp / 2.0 if k % 2 == 0 else -sp / 2.0) * (1.0 - u)   # 바깥에서 가운데로 모이기
					_: a = dir.angle() + rng.randf_range(-1.0, 1.0) * sp / 2.0    # 제멋대로
				a += rng.randf_range(-0.03, 0.03)
				speed *= rng.randf_range(0.88, 1.12)
				scale = rng.randf_range(0.8, 1.25)
			else:
				# 원작 불꽃세례처럼 위·가운데·아래 차례로.
				a = dir.angle() + (0.0 if total <= 1 else lerpf(-spread / 2.0, spread / 2.0, u))
		else:
			a = dir.angle() + rng.randf_range(-1.0, 1.0) * spread / 2.0
		_spawn_projectile(mon, b["hit"], m, Vector2.from_angle(a) * speed, scale)
		b["left"] -= 1
		b["t"] = float(m["interval"])
	bursts = bursts.filter(func(b): return b["left"] > 0)

# ── 피격 ──

func _hit_result(target: Mon, hit: Dictionary, key: String) -> void:
	if int(hit.get("volley", 0)) != 0:
		var notices: Dictionary = hit.get("result_notices", {})
		var token := str(target.get_instance_id()) + ":" + key
		if notices.has(token):
			return
		notices[token] = true
		hit["result_notices"] = notices
	var name := _battle_object_name(target) if key == "no_effect" else _battle_name(target)
	_status_text(target, Lang.t(key, [name]))

func apply_hit(target: Mon, hit: Dictionary, from_pos: Vector2) -> bool:
	last_damage = 0
	if target.dead or target.invuln_t > 0.0:
		return false
	# 방어(지키기): 한 턴(1.5초) 동안 모든 공격·변화를 막는다(사용자 확인 2026-10-30: 1회가 아니라 시간). 탄은 막힌 자리에서 사라진다.
	if hit.has("contacts"):
		var target_id:=target.get_instance_id()
		if hit.contacts.has(target_id): return true
		hit.contacts[target_id]=true
	if target.protect_t > 0.0:
		_hit_result(target, hit, "protected")
		add_fx("sprite", target.position + Vector2(0, -target.radius * 0.5), {"text": "g4_protect", "color": Color(0.55, 1.0, 0.6, 0.8),
			"size": target.radius * 3.2, "grow": 1.1, "lifetime": 0.25, "follow": target, "offset": Vector2(0, -target.radius * 0.5)})
		return true
	# 연막에 맞아 명중률이 내려간 적의 공격은 원작 배율(3/(3+n))로 빗나간다. 빗나가도 공격은 '한' 것이라 탄은 사라진다.
	# 원작 명중 = 쓰는 쪽 명중 랭크 − 맞는 쪽 회피 랭크(달콤한향기는 회피를 내린다).
	var acc := clampi(int(hit.get("acc_stage", 0)) - target.eva_stage, -6, 6)
	if acc < 0 and hit["team"] == Mon.TEAM_ENEMY and rng.randf() > Mon.stage_acc(acc):
		_hit_result(target, hit, "missed")
		return true
	# 연발 한 묶음(불꽃세례 셋)은 한 번만 맞는다. 나머지 탄은 닿아도 그냥 사라진다.
	var volley := int(hit.get("volley", 0))
	if volley != 0:
		if target.last_volley == volley:
			return true
		target.last_volley = volley
	var defense: int = target.stats["def"] if hit["cat"] == "physical" else target.stats["spd"]
	if hit["cat"] == "physical" and target.def_stage != 0:
		if not (bool(hit.get("ignore_def_up", false)) and target.def_stage > 0):   # 깨뜨리다: 방어 랭크 상승을 뚫는다
			defense = int(round(defense * Mon.stage_mult(target.def_stage)))
	elif hit["cat"] == "special" and target.spd_stage != 0:
		defense = int(round(defense * Mon.stage_mult(target.spd_stage)))
	var eff := TypeChart.effectiveness(hit["type"], target.types())
	var crit := rng.randf() < float(hit["crit"])
	var power: float = float(hit["power"])
	if String(hit.get("move",""))=="low_kick":
		power=20.0
		for threshold in [10.0,25.0,50.0,100.0,200.0]:
			if target.weight_kg()>=threshold:power+=20.0
		power *= float(hit.get("clash_fraction", 1.0))
	if bool(hit.get("half_double", false)) and target.hp * 2 <= target.max_hp:
		power *= 2.0      # 소금물: 상대 HP 가 절반 이하면 2배(원작)
	var dmg := Damage.calc(hit["level"], hit["atk"], defense, power, hit["stab"], eff, crit,
		rng.randf_range(0.85, 1.0))
	# 고정 피해(용의분노 40): 상성·급소·자속 무시, 무효 타입에만 0.
	if int(hit["fixed"]) > 0:
		dmg = int(hit["fixed"]) if eff > 0.0 else 0
		crit = false
	if dmg > 0:
		dmg = maxi(1, int(round(dmg * float(hit.get("mult", 1.0)) * weather_mult(String(hit["type"])))))
	var to_player := target == player
	var col := Color("ff5a5a") if to_player else Color.WHITE
	if not to_player:
		if eff >= 2.0:
			col = Color("ffb13b")
		elif eff < 1.0:
			col = Color("a0a0a0")
	if hit["power"] > 0.0 or dmg > 0:
		Sfx.play("kouka_h" if eff >= 2.0 else ("kouka_l" if eff < 1.0 else "kouka_m"), 1.0, _battle_sound_db(target.position), _battle_sound_pan(target.position), get_instance_id())   # 원작 효과 SE
		float_text(target.position + Vector2(0, -target.radius - 4), str(dmg), col, 10 if crit else 8)
		# Keep both outcomes, in critical-hit then effectiveness order for each target.
		if crit and dmg > 0:
			_status_text(target, Lang.t("crit", [_battle_object_name(target)]))
		# Fixed damage ignores resistances/weaknesses, but still respects immunity.
		if int(hit["fixed"]) <= 0 or eff <= 0.0:
			var msg := Damage.effect_text(eff, _battle_object_name(target))
			if not msg.is_empty():
				_status_text(target, msg)
	var away := (target.position - from_pos).normalized()
	if hit["power"] > 0.0 or dmg > 0:
		_interrupt_melee(target)
		# 원작의 하얀 타격 섬광. 불꽃 기술은 맞은 자리에 작은 불꽃이 튄다(Move_EMBER 의 EmberFireHit).
		var move_def := MoveDB.get_move(hit["move"]) if hit["move"] != "" else {}
		var first_fx := fxs.size()
		var fx_name := String(move_def.get("fx", ""))
		if String(hit["hit_fx"]) == "dragonfire_c":
			_dragon_rage_hit_custom(target)
		elif String(hit["hit_fx"]) == "dragonfire":
			# 용의분노(dragon_rage.spa): 보라 불길 넷이 맞은 자리 둘레에서 솟고 빛이 번쩍, 몸이 떨린다.
			add_fx("sprite", target.position + Vector2(0, -target.radius * 0.5), {"text": "g4_glow", "color": Color(0.75, 0.55, 1.0, 0.9),
				"size": target.radius * 2.0, "grow": 2.2, "lifetime": 0.3})
			for off in [Vector2(2, 0), Vector2(-4, -6), Vector2(0, 10), Vector2(6, 2)]:
				add_fx("sprite", target.position + off * (target.radius / 10.0), {"text": "g4_flame", "color": Color(0.65, 0.4, 1.0, 1.0),
					"size": target.radius * 1.6, "grow": 0.5, "dir": Vector2.UP, "speed": 40.0, "lifetime": 0.45, "delay": 0.02 * off.length()})
			target.shake_t = 0.4
		elif fx_name == "fang_c":
			_fire_fang_hit_custom(target, (target.position - from_pos).normalized())
		elif fx_name == "fang":
			# 불꽃엄니(플래티넘 fire_fang): 송곳니가 위아래에서 닫혀 물고, 물린 자리에서 불덩이가 사방으로 부풀며 불길이 솟는다. 몸은 흔들린다.
			var up := Vector2(0, -target.radius * 0.5)
			add_fx("fang", target.position + up, {"lifetime": 0.5, "size": target.radius * 2.2, "follow": target, "offset": up})
			for i in 5:
				var a := TAU * float(i) / 5.0 + randf_range(-0.3, 0.3)
				add_fx("fangfire", target.position + up, {"lifetime": 0.4, "size": target.radius * 1.6, "dir": Vector2.from_angle(a),
					"delay": 0.08 + 0.03 * i, "follow": target, "offset": up})
			for off in [-0.5, 0.4]:
				var o := up + Vector2(off * target.radius, 0)
				add_fx("fangfire", target.position + o, {"lifetime": 0.45, "size": target.radius * 1.5, "text": "flame", "delay": 0.12,
					"follow": target, "offset": o})
			target.shake_t = 0.3
		elif fx_name == "needle":
			KantoMoveFx.needle_hit(self,target,(target.position-from_pos).normalized())
		elif fx_name == "spark":
			# 전기쇼크(thunder_shock.spa): 노란 타격 터짐과 번개 두 줄이 몸에서 튄다.
			add_fx("sprite", target.position + Vector2(0, -target.radius * 0.5), {"text": "g4_hitburst", "color": Color(1.0, 0.95, 0.4, 0.95),
				"size": target.radius * 2.0, "grow": 1.7, "lifetime": 0.2})
			for i in 2:
				var o := Vector2((i * 2 - 1) * target.radius * 0.5, -target.radius * 0.5)
				add_fx("sprite", target.position + o, {"text": "g4_bolt_a" if i == 0 else "g4_bolt_b", "color": Color(1.0, 0.95, 0.5, 1.0),
					"size": target.radius * 1.6, "rot": (i * 2 - 1) * 0.4, "lifetime": 0.25, "follow": target, "offset": o})
		elif fx_name == "ember_c":
			_ember_hit_custom(target, from_pos, not bool(hit.get("ember_burn_done",false)))
			hit["ember_burn_done"] = true
			add_fx("light", target.position, {"color": Color(1.0, 0.55, 0.2, 1.0), "size": target.radius * 5.0, "lifetime": 0.35})
		elif fx_name == "ember":
			add_fx("light", target.position, {"color": Color(1.0, 0.55, 0.2, 1.0), "size": target.radius * 5.0, "lifetime": 0.45})
			# 불꽃세례(플래티넘 res/moves/ember/anim.s 확인 2026-10-28): 이미터 하나가 맞는 쪽 자리(EMITTER_POS_NORMAL_END)에서
			# ember.spa 불꽃을 피워 올리고, 맞는 몸은 빨강 10/16 까지 물들었다 돌아오며(FadeBattlerSprite) 좌우 1px 로 두 번 떤다(Shake 1,0,1,2).
			# 다섯 불꽃은 몸 폭에 고르게(가운데·양옆) 흩고 조금씩 흔든다 — 무작위만 쓰면 한쪽에 몰려 보였다.
			# 불꽃마다 노란 속불을 겹친다(붉게 물든 몸 위에서도 주황 불꽃이 묻히지 않게).
			for i in 5:
				var lane := (float(i) / 4.0 - 0.5) * 1.8 + randf_range(-0.15, 0.15)
				var off := Vector2(lane * target.radius, randf_range(-1.0, 0.0) * target.radius)
				var sz := target.radius * randf_range(1.0, 1.3)
				var rise := randf_range(14.0, 26.0)
				for layer in 2:
					var o := off + Vector2(0, sz * 0.12 * layer)
					add_fx("sprite", target.position + o, {"text": "g4_flame",
						"color": Color(1.0, 0.55 + 0.15 * randf(), 0.15, 1.0) if layer == 0 else Color(1.0, 0.95, 0.6, 1.0),
						"size": sz * (1.0 if layer == 0 else 0.5), "grow": 0.9, "fade_in": 0.06, "fade_out": 0.4,
						"dir": Vector2.UP, "speed": rise, "lifetime": 0.42, "delay": 0.04 * i, "follow": target, "offset": o})
			target.start_tint(Color.RED, 10.0 / 16.0, 20.0 / 60.0)
			target.shake_t = 8.0 / 60.0
			target.shake_px = 1.0
		elif fx_name in ["flame", "flame_c"]:
			# 화염방사: 맞은 자리에서 불길 셋이 솟으며 꺼진다.
			for i in 3:
				add_fx("sprite", target.position + Vector2((i - 1) * target.radius * 0.6, -target.radius * 0.3), {"text": "g4_flame",
					"color": Color(1.0, 0.6, 0.2, 1.0), "size": target.radius * 1.4, "grow": 0.4,
					"dir": Vector2.UP, "speed": 35.0, "lifetime": 0.32, "delay": 0.05 * i})
		elif fx_name=="voice":
			KantoMoveFx.voice_hit(self,target)
		elif fx_name=="acid":
			KantoMoveFx.acid_hit(self,target,(target.position-from_pos).normalized())
		elif fx_name in ["lick","mud","ice"] or String(hit.get("move",""))=="headbutt":
			WildActions.hit_fx(self,target,"headbutt" if String(hit.get("move",""))=="headbutt" else fx_name,(target.position-from_pos).normalized())
		elif fx_name in ["leaf", "bubble", "water", "hydro", "pulse", "flash", "solar", "petal", "brine", "gigadrain", "breath", "rock"]:
			_hit_fx_new(target, fx_name, (target.position - from_pos).normalized())
		elif not hit.get("forward_cut", false):
			add_fx("impact", target.position + Vector2(0, -target.radius * 0.4), {"lifetime": 0.16, "size": target.radius, "color": Color.WHITE})
		_scale_melee_fx(hit, first_fx)
		# 맞으면 뒤로 밀린다(사용자: 몬스터 넉백 확실히). 보스도 똑같이(특별한 건 덩치·개체값뿐). 연타 기술은 기술이 정한 만큼만.
		# 물리기는 힘·몸무게 비율만큼(knock_factor), 특수기는 밀지 않고 경직(stun_time) — 상단 주석(사용자 결정 2026-10-30).
		if hit["knock"] >= 0.0:
			target.knock = away * float(hit["knock"])
		elif hit["cat"] == "physical":
			var tiles: float = KNOCK_TILES * knock_factor(float(hit["atk"]), float(defense), float(hit.get("weight", 10.0)), target.weight_kg())
			target.knock = away * knock_speed(tiles * Arena.TILE)
		else:
			target.knock = Vector2.ZERO
			target.flinch_t = maxf(target.flinch_t, stun_time(float(hit["atk"]), float(defense), to_player))
		if hit["cat"] == "physical" and String(move_def.get("shape", "")) in RANGED_KNOCK_SHAPES:
			# 일정 감속에서 거리 = v²/(2a). 속도에 √0.5를 곱해야 거리가 절반이 된다.
			target.knock *= sqrt(RANGED_PHYSICAL_KNOCK_DISTANCE)
		if hit.get("clash_melee", false): target.knock *= sqrt(float(hit.clash_fraction))
		target.play_hit_feedback(String(hit["type"]),String(hit["cat"]),away)
		target.flash_t = 0.12
		target.hurt_t = Mon.HURT_ANIM
	if to_player:
		target.invuln_t = float(hit["invuln"])
	# 원작처럼 불꽃 타입은 화상에 걸리지 않는다.
	if hit["burn"] > 0.0 and Mon.burn_unlocked and not target.types().has("fire") and rng.randf() < hit["burn"]:
		if target.burn_t <= 0.0:
			_inflict_status(target,"burn")
	# 독(독침 30%): 원작처럼 독·강철 타입은 안 걸린다. 걸리면 보라 거품이 떠오른다.
	if float(hit.get("poison", 0.0)) > 0.0 and Mon.poison_unlocked and not target.types().has("poison") and not target.types().has("steel") and rng.randf() < hit["poison"]:
		if target.poison_t <= 0.0:
			for i in 3:
				add_fx("sprite", target.position + Vector2((i - 1) * target.radius * 0.5, -target.radius * 0.8), {"text": "g4_bubble",
					"color": Color(0.75, 0.4, 1.0, 0.95), "size": target.radius * 0.8, "grow": 1.3, "dir": Vector2.UP, "speed": 25.0,
					"lifetime": 0.5, "delay": 0.08 * i})
			_inflict_status(target,"poison")
	if hit["slow"] > 0.0:
		# 새로 느려질 때만 원작 능력 하락 연출(몸 안에 파란 무늬가 아래로 흐름).
		if target.slow_t <= 0.0:
			target.play_stat("spe_down")
		target.slow_t = 1.2
		target.slow_amount = hit["slow"]
	if hit["flinch"] > 0.0 and rng.randf() < hit["flinch"]:
		target.flinch_t = Mon.FLINCH_DURATION
	_apply_extra_status(target, hit)
	# 반동·흡수는 원작처럼 '상대가 실제로 잃은 HP' 기준(남은 HP 보다 큰 피해는 남은 HP 까지만).
	last_damage = 0 if god and target==player else mini(dmg,target.hp)
	var lost:=last_damage
	damage(target, dmg)
	WildActions.reflect(self,target,hit,lost)
	if hit.has("recoil_state"): BattleContact.pay_recoil(self,hit,lost)
	last_damage=lost
	_hitstop(target, hit, dmg, crit)
	return true

# 히트스톱(상단 상수 주석). 맞은 쪽은 늘, 때린 쪽은 근접(arc·burrow·dash)일 때만. 겹치면 더 긴 쪽.
func _hitstop(target: Mon, hit: Dictionary, dmg: int, crit: bool) -> void:
	if dmg <= 0 or hit.get("clash_melee", false):
		return
	var move := String(hit.get("move", ""))
	var shape := String(MoveDB.get_move(move).get("shape", "arc")) if move != "" else "arc"
	var melee := shape in ["arc", "burrow", "dash"]
	var t: float
	if float(hit.get("knock", -1.0)) >= 0.0:
		t = HITSTOP_MULTI                   # 연타기: 한 타마다 짧게
	elif move in CONTACT_IMPACT_MOVES:
		t = HITSTOP_CONTACT
	elif melee:
		t = HITSTOP_MELEE
	else:
		t = HITSTOP_RANGED
	if target.dead:
		t = maxf(t, HITSTOP_KILL)
	if crit:
		t *= HITSTOP_CRIT
	target.hitstop_t = maxf(target.hitstop_t, t)
	var src = hit.get("src")
	if move in CONTACT_IMPACT_MOVES:
		target.hit_visual_strength = maxf(target.hit_visual_strength, 4.0 if crit else 2.8)
		target.hit_visual_squash = 0.10 if crit else 0.065
		if target == player or src == player:
			var strength := 2.0 if crit else 1.2
			if impact_camera_t <= 0.0 or strength > impact_camera_strength:
				impact_camera_strength = strength
				impact_camera_t = IMPACT_CAMERA_DURATION
				impact_camera_direction = Vector2.DOWN
				if src is Mon and is_instance_valid(src):
					impact_camera_direction = src.facing.normalized() if move in ["tackle","peck","astonish"] else Vector2(src.facing.x * 0.35, 1.0).normalized()
			if cam != null: cam.offset = impact_camera_offset()
	if melee and src is Mon and is_instance_valid(src) and not src.dead:
		src.hitstop_t = maxf(src.hitstop_t, t)

# One short directional kick, bounded even when a cone hits several opponents.
func impact_camera_offset() -> Vector2:
	if impact_camera_t <= 0.0: return Vector2.ZERO
	var progress := 1.0 - impact_camera_t / IMPACT_CAMERA_DURATION
	return impact_camera_direction * impact_camera_strength * cos(progress * PI * 1.5) * pow(1.0 - progress, 2.0)

func _tick_impact_camera(dt: float) -> void:
	impact_camera_t = maxf(0.0, impact_camera_t - dt)
	if cam != null: cam.offset = impact_camera_offset()

# 마지막 apply_hit 으로 상대가 실제로 잃은 HP(반동·흡수 계산용).
var last_damage := 0

# 날씨 보정(원작): 비 — 물 1.5배, 불꽃 0.5배.
func weather_mult(type: String) -> float:
	if weather == "rain":
		if type == "water":
			return 1.5
		if type == "fire":
			return 0.5
	return 1.0

# 잠·독(가루)·혼란·씨뿌리기·불면·능력 하락 부가 효과. 잠·독·화상은 원작처럼 하나만(이미 걸려 있으면 실패).
func _apply_extra_status(target: Mon, hit: Dictionary) -> void:
	if target.dead:
		return
	var major := target.sleep_t > 0.0 or target.poison_t > 0.0 or target.burn_t > 0.0 or target.para_t > 0.0
	if float(hit.get("paralyze", 0.0)) > 0.0 and rng.randf() < float(hit["paralyze"]):
		if major:
			_status_text(target, Lang.t("no_effect_status", [_battle_object_name(target)]))
		else:
			_paralyze(target)
	if float(hit.get("sleep", 0.0)) > 0.0 and rng.randf() < float(hit["sleep"]):
		if major or target.insomnia:
			_status_text(target, Lang.t("no_effect_status", [_battle_object_name(target)]))
		else:
			target.sleep_t = float(rng.randi_range(Mon.SLEEP_TURNS.x, Mon.SLEEP_TURNS.y)) * Mon.TURN
			_status_text(target, Lang.t("fell_asleep", [_battle_name(target)]))
			# 잠: status_effect.spa 의 Z 가 0.5초마다 머리 위로 떠오른다.
			for k in int(target.sleep_t / 0.5):
				add_fx("sprite", target.position, {"text": "g4_zzz", "color": Color8(224, 192, 248, 240), "size": 9.0, "grow": 1.3,
					"dir": Vector2(0.4, -1).normalized(), "speed": 14.0, "lifetime": 0.5 * k + 0.9, "delay": 0.5 * k, "fade_in": 0.2,
					"follow": target, "offset": Vector2(target.radius * 0.6, -target.radius * 1.4)})
	if float(hit.get("confuse", 0.0)) > 0.0 and rng.randf() < float(hit["confuse"]) and target.confuse_t <= 0.0:
		confuse(target)
	if bool(hit.get("leech", false)):
		if target.types().has("grass") or target.leech_t > 0.0:
			_status_text(target, Lang.t("no_effect_status", [_battle_object_name(target)]))
		else:
			target.inflict("leech")
			target.leech_by = hit.get("src", null)
			_status_text(target, Lang.t("seeded", [target.display_name()]))
	# 조이기: 2~5턴 동안 턴마다 1/16(이미 조여 있으면 새로 걸지 않는다).
	if bool(hit.get("bind", false)) and target.bind_t <= 0.0 and is_instance_valid(hit.get("src", null)):
		target.bind_t = float(rng.randi_range(Mon.BIND_TURNS.x, Mon.BIND_TURNS.y)) * Mon.TURN
		target.bind_acc = 0.0
		target.bind_by = hit["src"]
		_status_text(target, Lang.t("got_bound", [target.display_name(), (hit["src"] as Mon).display_name()]))
		var body := Vector2(0, -target.radius * 0.5)
		if String(hit.get("move",""))=="wrap":
			add_fx("wrap",target.position+body,{"lifetime":target.bind_t,"follow":target,"offset":body,"bind_source":weakref(hit["src"])})
		else:
			add_fx("sprite", target.position + body, {"text": "g4_bind_ring", "color": Color8(248, 232, 200, 220), "size": target.radius * 3.4,
				"grow": 0.75, "lifetime": target.bind_t, "fade_out": 0.3, "follow": target, "offset": body})
	if bool(hit.get("insomnia", false)):
		target.insomnia = true
		if target.sleep_t > 0.0:
			target.sleep_t = 0.0
		_status_text(target, Lang.t("got_insomnia", [target.display_name()]))
	var sh: Dictionary = hit.get("stat_hit", {})
	if not sh.is_empty() and rng.randf() < float(hit.get("stat_hit_chance", 1.0)):
		_apply_stat(target, sh, false)

func _inflict_status(target: Mon, kind: String) -> void:
	var field := "poison_t" if kind=="poison" else "burn_t"
	var before: float = target.get(field)
	target.inflict(kind)
	if before<=0.0 and float(target.get(field))>0.0:
		_status_text(target,Lang.t("got_poisoned" if kind=="poison" else "got_burned",[_battle_name(target)]))

func _status_text(t: Mon, msg: String) -> void:
	float_text(t.position + Vector2(0, -t.radius - 14), msg, Color("e8d0ff"), 7)

# 혼란(1~4초): 머리 위에 원작 혼란 오리(status_effect.spa 4번 텍스처)가 돈다.
func confuse(t: Mon) -> void:
	t.confuse_t = float(rng.randi_range(Mon.CONFUSE_TURNS.x, Mon.CONFUSE_TURNS.y)) * Mon.TURN
	_status_text(t, Lang.t("became_confused", [_battle_name(t)]))
	for i in 3:
		add_fx("sprite", t.position, {"text": "g4_duck", "color": Color.WHITE, "size": 10.0, "lifetime": t.confuse_t,
			"follow": t, "offset": Vector2(0, -t.radius * 1.6), "orbit_r": t.radius * 0.9, "orbit_speed": 4.0, "orbit_phase": TAU * i / 3.0,
			"fade_out": 0.1})

# 혼란 중에 기술을 쓰려 하면 50% 로 자신을 친다(위력 40, 타입 없음 — 원작 4세대). 쳤으면 true(기술은 나가지 않는다).
func confusion_self_hit(mon: Mon) -> bool:
	if mon.confuse_t <= 0.0 or rng.randf() >= Mon.CONFUSE_SELF_HIT:
		return false
	var dmg := Damage.calc(mon.level, int(mon.stats["atk"]), int(mon.stats["def"]), 40.0, false, 1.0, false, rng.randf_range(0.85, 1.0))
	float_text(mon.position + Vector2(0, -mon.radius - 14), Lang.t("hurt_itself"), Color("ffb0b0"), 7)
	mon.hurt_t = Mon.HURT_ANIM
	mon.flash_t = 0.12
	damage(mon, dmg)
	return true

func damage(target: Mon, amount: int) -> void:
	if target.dead or amount <= 0 or (god and target == player):
		return
	target.hp = maxi(0, target.hp - amount)
	if target.hp <= 0:
		# 기력의조각: 가방에 있으면 쓰러지는 순간 저절로 써서 HP 절반으로 일어난다(포켓몬 한 마리라 원작의 '쓰러진 포켓몬에게 쓰기'를 이렇게 옮김).
		if target == player and player.take_item("revive"):
			player.hp = maxi(1, int(player.max_hp * float(ItemDB.effect("revive")["revive"])))
			player.invuln_t = maxf(player.invuln_t, 1.5)
			player.shine_t = 0.6
			float_text(player.position + Vector2(0, -player.radius - 14), Lang.t("revived", [_battle_name(player)]), Color("ffe080"), 7)
			return
		_faint(target)

func heal(target: Mon, amount: int) -> void:
	var before := target.hp
	target.hp = mini(target.max_hp, target.hp + amount)
	if target.hp > before:
		_status_text(target, Lang.t("hp_restored", [_battle_name(target)]))
		float_text(target.position + Vector2(0, -target.radius - 4), "+%d" % (target.hp - before), Color("7dff8a"), 8)

func exp_gain(e: Enemy) -> int:
	if e.get_meta("no_exp",false):return 0
	return LevelProgression.experience(int(SpeciesDB.get_species(e.species_id)["exp"]),e.level,player.level)

func _faint(mon: Mon) -> void:
	if mon.dead: return
	Sfx.cry(mon.species_id, 0.8, _battle_sound_db(mon.position), _battle_sound_pan(mon.position), get_instance_id())             # 쓰러질 때 낮게(원작도 낮춰 튼다)
	mon.dead = true
	mon.dash = {}
	mon.trail.clear()
	mon.vel = Vector2.ZERO
	mon.faint_t = Mon.FAINT_TIME     # 쓰러지는 동작을 보여 준 뒤 치운다
	add_fx("burst", mon.position, {"color": Color(1, 1, 1), "size": mon.radius * 0.6, "lifetime": 0.25})
	if mon == player:
		_status_text(mon, Lang.t("fainted", [_battle_name(mon)]))
		player_fainted.emit()
		return
	# 적은 맞은 기세가 끝난 뒤에 넘어진다: 물리기면 다 밀려날 때까지(속도 ÷ 감속), 특수기면 경직 자세로 DIE_STUN 동안.
	if mon.knock != Vector2.ZERO:
		mon.dying_t = mon.knock.length() / Mon.KNOCK_DECEL
	elif mon.flinch_t > 0.0:
		mon.dying_t = Mon.DIE_STUN
	mon.flinch_t = 0.0
	var e: Enemy = mon
	var exp := exp_gain(e)
	if not e.trainer_owned:
		var loot: Array=BerryLoot.roll(e.species_id,e.level,rng,e.cds.keys())
		var held := ItemDB.roll_held(e.species_id,rng)
		if not held.is_empty(): loot.append(held)
		for id in loot:
			spawn_loot(String(id),e.position+Vector2(rng.randf_range(-6,6),rng.randf_range(-3,3)))
	enemy_defeated.emit(e, exp)

# ── 이동·충돌 ──

func _move_mons(dt: float) -> void:
	var all: Array = [player]
	all.append_array(enemies)
	for mon in all:
		if mon.dead or mon.hitstop_t > 0.0:
			continue
		if mon.attack_anim_t>0.0 and not mon.attack_direction.is_zero_approx():mon.facing=mon.attack_direction
		if mon.is_dashing():
			_step_dash(mon, dt)
			continue
		if not mon.glide.is_empty():
			_step_glide(mon, dt)
		var v: Vector2 = mon.knock
		if mon.flinch_t > 0.0 or mon.knock != Vector2.ZERO:
			mon.vel = Vector2.ZERO          # 경직·밀려나는 동안은 걷지 않는다(사용자 결정 2026-10-30)
		v += mon.vel
		mon.position = resolve_mon(mon,mon.position + v * dt)
		if mon==player and player.travel_terrain==2 and not Arena.is_water(Arena.tile_of(player.position)):
			# Stay amphibious while the body still overlaps the shoreline.
			if Arena.resolve(player.position,player.radius).distance_to(player.position)<0.1: player.travel_terrain=0

const GLIDE_TAIL := 0.06      # 미끄러지기가 맞는 순간 뒤로 더 이어지는 시간(한 번에 멈추면 딱딱했다)

## Includes the final authored lunge displacement, not only the glide timer.
func resolve_melee_advance(mon: Mon,displacement: Vector2) -> Vector2:
	return BattleContact.forward_sweep(self,mon,mon.position,displacement,displacement.length()).point

# 근접기 미끄러지기(Mon.glide): 남은 거리만큼 앞으로. 상대 몸에 닿을 자리면 거기서 끝(뚫고 지나가지 않게), 벽은 Arena 가 막는다.
func _step_glide(mon: Mon, dt: float) -> void:
	var g: Dictionary = mon.glide
	if float(g.get("wait", 0.0)) > 0.0:                  # 도트가 앞으로 나가기 시작할 때까지 기다린다(준비 자세에선 안 미끄러진다)
		var waiting := minf(dt, float(g["wait"]))
		g["wait"] = float(g["wait"]) - waiting
		dt -= waiting
		if dt <= 0.0: return
	var st := minf(float(g["speed"]) * dt, float(g["left"]))
	if g.has("duration"):
		var before := clampf(float(g["elapsed"]) / float(g["duration"]), 0.0, 1.0)
		g["elapsed"] = float(g["elapsed"]) + dt
		var after := clampf(float(g["elapsed"]) / float(g["duration"]), 0.0, 1.0)
		var progress := smoothstep(0.0, 1.0, after) - smoothstep(0.0, 1.0, before)
		if bool(g.get("quick_strike", false)):
			# Fast entry, short braking: most displacement happens at the strike,
			# leaving the low finishing pose stationary instead of drifting.
			progress = pow(1.0 - before, 3.0) - pow(1.0 - after, 3.0)
		st = minf(float(g["left"]), float(g["distance"]) * progress)
	var sweep:=BattleContact.forward_sweep(self,mon,mon.position,g.dir,st)
	mon.position=sweep.point
	g["left"] = float(g["left"]) - float(sweep.distance)
	if float(g["left"]) <= 0.01 or sweep.blocked:
		mon.glide = {}

# 점프 계획: 어디에 내려앉는가. {ok, to}.
#   평지: 바라보는 쪽으로 두 칸(48px). 벽이 있으면 돌진이 벽에서 멈춘다(전처럼).
#   길에 언덕이 끼면(넘거나 언덕에 내려앉게 되면): 시작 칸에서 그 방향으로 정확히 두 칸 앞 칸 가운데(언덕 바로 다음 칸).
#   그 칸이 막혔거나 언덕이거나 몸이 안 들어가면 점프하지 않는다(사용자 결정 2026-10-28: 대각선으로 언덕을 넘다 못 내려설 곳이면 막기).
func plan_hop(from: Vector2, dir: Vector2) -> Dictionary:
	if dir.length_squared() < 0.0001:
		return {"ok": false}
	dir = dir.normalized()
	var r := player.radius
	var to := from + dir * Player.JUMP_DISTANCE
	var crosses := false
	for k in range(1, 13):
		var q := from.lerp(to, float(k) / 12.0)
		var t := Arena.tile_of(q)
		if Arena.ledge_at(t.x, t.y) != 0:
			crosses = true
			break
	if not crosses and Arena.resolve(to, r) != Arena.resolve(to, r, true):
		crosses = true          # 몸이 언덕 칸에 걸쳐 내려앉게 된다
	if not crosses:
		return {"ok": true, "to": to}
	var step := Vector2i(int(signf(dir.x)) if absf(dir.x) > 0.38 else 0, int(signf(dir.y)) if absf(dir.y) > 0.38 else 0)
	var t0 := Arena.tile_of(from)
	var mid := t0 + step
	var land := t0 + step * 2
	if Arena.solid_at(mid.x, mid.y) or Arena.solid_at(land.x, land.y) or Arena.ledge_at(land.x, land.y) != 0:
		return {"ok": false}
	var at := Arena.tile_center(land)
	if Arena.resolve(at, r).distance_to(at) > 0.5:
		return {"ok": false}
	return {"ok": true, "to": at}

# 점프(Hop): to 까지 Hop 동작 길이(0.4초) 동안 날아간다 — 동작이 끝나는 순간 내려앉는다(전엔 0.2초만 날고 나머지는 걸어서 더 멀리 간 것처럼 보였다).
# 무적·쿨타임 없음(사용자 결정 2026-10-28: 피하기는 회피가 맡는다). 점프 돌진만 언덕 칸을 넘는다(dash["hop"], _step_dash).
func _start_hop(to: Vector2) -> void:
	Sfx.play("dansa", 1.0, 0.0, 0.0, get_instance_id())
	var off := to - player.position
	if off.length() < 1.0:
		return
	player.play_hop()
	var dur := maxf(player.hop_t, 0.2)
	player.dash = {"dir": off.normalized(), "speed": off.length() / dur, "left": off.length(),
		"t": dur + 0.05, "move": "", "hit_ids": {}, "hop": true, "from":player.position,
		"ground_from":Arena.ground_height(player.position),"ground_to":Arena.ground_height(to),"ground_length":off.length()}
	player.vel = Vector2.ZERO

# 회피: 64px 를 0.2초에 내달린다(처음 회피 그대로). 무적 0.26초, 쿨타임 1.2초. 언덕·벽에서 멈춘다. 걷기 동작 + 잔상.
func _start_dodge(dir: Vector2) -> void:
	player.dash = {"dir": dir, "speed": Player.DODGE_DISTANCE / Player.DODGE_DURATION, "left": Player.DODGE_DISTANCE,
		"t": Player.DODGE_DURATION + 0.05, "move": "", "hit_ids": {}, "trail": true}
	player.facing = dir
	player.invuln_t = maxf(player.invuln_t, Player.DODGE_DURATION + 0.06)
	player.dodge_cd = Player.DODGE_COOLDOWN
	player.vel = Vector2.ZERO

func _step_dash(mon: Mon, dt: float) -> void:
	var d: Dictionary = mon.dash
	if String(d.get("move",""))!="":
		if not d.get("hit",{}).has("recoil_state"):
			mon.trail.append(mon.position)
			if mon.trail.size()>3:mon.trail.pop_front()
		BattleContact.step_attack_dash(self,mon,dt)
		return
	# 잔상: 지나온 자리를 세 걸음 남긴다.
	mon.trail.append(mon.position)
	if mon.trail.size() > 3:
		mon.trail.pop_front()
	var stride: float = d["speed"] * dt
	if d.has("left"):
		stride = minf(stride, float(d["left"]))
		d["left"] = float(d["left"]) - stride
		if float(d["left"]) <= 0.001:
			d["t"] = 0.0      # 정한 자리에 닿으면 끝
	var want: Vector2 = mon.position + d["dir"] * stride
	var hop := bool(d.get("hop", false))
	var got := resolve_mon(mon,want,hop)
	mon.position = got
	mon.facing = d["dir"]
	if d["move"] != "":
		for t in opponents(mon.team):
			var id: int = t.get_instance_id()
			if d["hit_ids"].has(id):
				continue
			if mon.position.distance_to(t.position) < mon.radius + t.radius + 2.0:
				d["hit_ids"][id] = true
				d["t"] = 0.0                 # 돌진 기술은 포켓몬과 부딪치면 거기서 멈춘다 — 뚫고 지나가지 않는다(사용자 결정 2026-10-30)
				if apply_hit(t, d["hit"], mon.position) and last_damage > 0:
					# 반동이 없는 돌진기도 명중 순간에 전용 연출을 재생한다.
					var dm := MoveDB.get_move(d["move"])
					_dash_hit_fx(t, String(dm.get("fx", "")), d["dir"])
	d["t"] -= dt
	var blocked := got.distance_to(want) > 0.5
	if d["t"] <= 0.0:
		mon.dash = {}
		mon.trail.clear()
		if hop and not mon.dead: _hop_land_fx(mon)
		# 적은 뛰어든 뒤 잠깐 멈춘다 — 피한 다음 때릴 틈(보스도 같다).
		if mon is Enemy and d["move"] != "":
			mon.recover_t = Mon.RECOVER_DURATION
		elif mon == player and d["move"] != "":
			_player_recover(String(d["move"]), 0.0)   # 돌진이 끝난 뒤부터 후딜레이

# A short foot-level puff and a small visual recoil; no camera shake or gameplay delay.
func _hop_land_fx(mon: Mon) -> void:
	mon.landing_t = Mon.LANDING_DURATION
	var feet := mon.position+Vector2(0,mon.feet_offset())
	var indoors := DungeonDB.is_indoor()
	var grass := Arena.is_grass(Arena.tile_of(mon.position))
	var tint := Color(0.72,0.72,0.68,0.25) if indoors else Color(0.64,0.66,0.46,0.36) if grass else Color(0.78,0.71,0.57,0.42)
	var r := clampf(mon.radius,8.0,14.0)
	for i in (2 if indoors else 4):
		var side := -1.0 if i%2==0 else 1.0
		var direction := Vector2(side,0.22 if i<2 else -0.22).normalized()
		add_fx("sprite",feet+Vector2(side*r*0.28,0),{"text":"g4_dust","landing_dust":true,
			"color":tint,"size":r*(0.65 if i<2 else 0.5),"grow":1.65,"stretch":0.55,
			"dir":direction,"speed":r*1.7,"lifetime":0.28,"fade_in":0.12,"fade_out":0.8})

func _separate_enemies() -> void:
	var list := alive_enemies()
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a: Enemy = list[i]
			var b: Enemy = list[j]
			var d := b.position - a.position
			var min_d := a.radius + b.radius
			var dist := d.length()
			if dist >= min_d or dist < 0.001:
				continue
			var push := d / dist * (min_d - dist)
			# 덩치(반지름)가 클수록 덜 밀린다 — 보스가 특별한 건 덩치뿐이라 보스 표시가 아니라 크기로 나눈다.
			var wa := b.radius / min_d
			a.position -= push * wa
			b.position += push * (1.0 - wa)
	for e in list:
		e.position = resolve_mon(e,e.position)

const ProjectileClashes := preload("res://scripts/battle/projectile_clashes.gd")
var _projectile_clock := 0.0

func _step_projectiles(dt: float) -> void:
	var checked := {}
	if not combat_clashes or projectiles.is_empty():
		for p: Projectile in projectiles:
			_move_projectile(p, dt, checked)
		_projectile_clock += dt
		return
	var end := _projectile_clock + dt
	while _projectile_clock < end:
		var event := ProjectileClashes.next_event(projectiles, _projectile_clock, end)
		var travel := float(event.time)
		if travel > 0.0:
			for p: Projectile in projectiles:
				_move_projectile(p, travel, checked)
			_projectile_clock += travel
		if not event.has("a"): continue
		var a: Projectile = event.a
		var b: Projectile = event.b
		if travel == 0.0:
			# Overlapping at launch: walls and Pokémon at this position still take priority.
			_move_projectile(a, 0.0, checked)
			_move_projectile(b, 0.0, checked)
		if a.dead or b.dead: continue
		var before_a := float(a.hit.power)
		var before_b := float(b.hit.power)
		var contact := a.position.move_toward(b.position, a.hit_radius())
		resolve_clash(a.hit, b.hit, contact, a.vel.normalized(), b.vel.normalized())
		_update_clashed_volley(a.hit, before_a)
		_update_clashed_volley(b.hit, before_b)

func _update_clashed_volley(hit: Dictionary, previous: float) -> void:
	var ratio := float(hit.power) / previous
	for p: Projectile in projectiles:
		if p.dead or not is_same(p.hit, hit): continue
		if ratio <= 0.0: p.dead = true
		else: p.radius *= ratio
	if ratio <= 0.0:
		bursts = bursts.filter(func(b): return not is_same(b.hit, hit))
	else:
		hit["clash_resume"] = _projectile_clock + ProjectileClashes.PAUSE

func _move_projectile(p: Projectile, dt: float, checked: Dictionary) -> void:
	if p.dead or ProjectileClashes.held(p, _projectile_clock): return
	# Bound spatial steps, including walls and volley stop points; do not skip
	# directly to the frame endpoint during a stall. Stop work at remaining range.
	var speed: float = p.vel.length()
	var travel_time := minf(dt,maxf(0.0,p.range_left)/speed) if speed>0.0 else dt
	var max_step := clampf(p.radius,1.0,4.0)
	var steps := maxi(1,ceili(speed*travel_time/max_step))
	var targets := _projectile_candidates(p,p.position+p.vel*travel_time)
	# A clash can split this frame. Keep a single trail sample and accuracy roll per target.
	var first := not checked.has(p)
	var attempted: Dictionary = checked.get_or_add(p, {})
	for i in steps:
		if p.dead: break
		_advance_projectile(p,travel_time/steps,attempted,targets,first and i==0)

# Conservative broad phase: include the largest possible growing radius so that
# filtering cannot discard a target a later spatial step could reach.
func _projectile_candidates(p: Projectile, end: Vector2) -> Array:
	var candidates := []
	var radius := p.radius*maxf(1.0,p.grow)
	for target in opponents(p.team):
		var center: Vector2 = target.position+Vector2(0,-target.radius*0.2)
		var closest := p.position if p.position == end else Geometry2D.get_closest_point_to_segment(center,p.position,end)
		if center.distance_squared_to(closest)<=pow(radius+target.radius,2):
			candidates.append(target)
	return candidates

func _advance_projectile(p: Projectile, dt: float, attempted: Dictionary, targets: Array, record_trail: bool = true) -> void:
	var previous: Vector2 = p.position
	p.step(dt,record_trail)
	if Arena.blocks(p.position, p.radius):
		p.dead = true
		_projectile_fizzle(p, previous)
		return
	# 관통이 아닌 연발(물대포 다섯 방울): 첫 방울이 맞힌 자리에서 나머지도 끝난다 — 맞혀 쓰러뜨린 뒤 남은 물줄기가 그 자리를 지나
	# 뒤로 날아가 관통처럼 보였다(사용자 지적 2026-10-30). 무적 중인 내 포켓몬(땅속·회피)은 맞지 않았으니 그대로 지나간다.
	var vol := int(p.hit.get("volley", 0))
	if not p.pierce and vol != 0 and _volley_stop.has(vol) and p.position.distance_to(_volley_stop[vol]) <= p.hit_radius() + 6.0:
		p.dead = true
		return
	for t in targets:
		if not is_instance_valid(t) or t.dead: continue
		var id: int = t.get_instance_id()
		if p.hit_ids.has(id) or attempted.has(id):
			continue
		if p.position.distance_to(t.position + Vector2(0, -t.radius * 0.2)) < p.hit_radius() + t.radius:
			attempted[id] = true
			var landed := apply_hit(t, p.hit, p.position - p.vel.normalized() * 4.0)
			if p.pierce:
				p.hit_ids[id] = true
			elif landed:
				p.dead = true
				if vol != 0:
					_volley_stop[vol] = p.position
					if _volley_stop.size() > 64:
						_volley_stop.erase(_volley_stop.keys()[0])
				break
	if p.dead and p.range_left <= 0.0 and p.hit_ids.is_empty():
		_projectile_fizzle(p)

# 투사체가 맞지 않고 사라질 때(사거리 끝·벽)의 연출. 지금은 커스텀 불꽃세례만.
func _projectile_fizzle(p: Projectile, ground_at: Vector2 = Vector2.INF) -> void:
	if p.style == "ember_c" and not bool(p.hit.get("ember_burn_done",false)):
		p.hit["ember_burn_done"] = true
		var at := p.position if ground_at == Vector2.INF else ground_at
		var offset_at := at + Vector2(0, p.radius)
		if not Arena.blocks(offset_at, 0.0): at = offset_at
		if not Arena.blocks(at, 0.0):
			_ember_fizzle(at,p.vel.normalized())

var _volley_stop := {}       # 연발 묶음 번호 → 첫 방울이 맞힌 자리(나머지는 거기서 끝)

func _step_zones(dt: float) -> void:
	for z in zones:
		z.step(dt)
		if z is FireField: continue
		for t in opponents(z.team):
			if t.position.distance_to(z.position) > z.radius + t.radius * 0.5:
				continue
			if z.kind == "static":
				t.slow_t = maxf(t.slow_t, 0.15)
				t.slow_amount = z.slow
			elif (z.kind == "ring" or z.kind == "petal") and z.ready_to_hit(t):
				apply_hit(t, z.hit, z.position)

# 몸이 겹치면 서로 밀어낸다. 부딪히는 것만으로는 피해가 없다(사용자 결정) — 피해는 기술로만.
func _push_apart_player() -> void:
	if player.dead:
		return
	for e in enemies:
		if e.dead or e.is_dashing():
			continue
		var d: Vector2 = player.position - e.position
		var min_d: float = e.radius + player.radius
		var dist: float = d.length()
		if dist >= min_d or dist < 0.001:
			continue
		var push: Vector2 = d / dist * (min_d - dist)
		player.position = resolve_mon(player,player.position + push * 0.5)
		e.position = resolve_mon(e,e.position - push * 0.5)

# 사람은 지나갈 수 없다: 몸(BODY_R)에 겹치면 밀어낸다.
func _push_out_of_npcs() -> void:
	for n in npcs:
		for mon in [player] + enemies:
			if mon.dead:
				continue
			# A searching trainer discovers the occupied grass cell before body collision can push its occupant out.
			if mon==player and n.get_meta("roaming_trainer",false):continue
			var d: Vector2 = mon.position - n.position
			var min_d: float = Npc.BODY_R + mon.radius
			var dist: float = d.length()
			if dist >= min_d:
				continue
			var nrm: Vector2 = d / dist if dist > 0.001 else Vector2.DOWN
			mon.position = resolve_mon(mon,n.position + nrm * min_d)

# Waiting Pokémon animate without entering AI, targeting or combat counts.
func _step_bystanders(dt: float) -> void:
	for mon in bystanders:
		mon.anim_t += dt
		mon.queue_redraw()

# 세계를 멈춘 채 그림만 움직인다(회복 연출·배틀 사이 — 내 포켓몬의 동작·연출·사람, 쓰러진 상대의 동작).
func step_visual(dt: float) -> void:
	_step_bystanders(dt)
	step_loot_visual(dt)
	_tick_impact_camera(dt)
	player.tick_status(dt)
	for e in enemies:
		if e.dead:
			e.tick_faint(dt)
	for f in fxs:
		f.step(dt)
	_update_smoke_density()
	for n in npcs:
		n.step(dt)
	_cleanup()
	if cam != null and not hold_cam:
		cam.position = player.cam_anchor().round()
	queue_redraw()

# 세계를 멈춘 채 연출만 흘린다(트레이너가 포켓몬을 내보내는 동안 — 볼이 터지는 빛).
func step_fx(dt: float) -> void:
	_step_bystanders(dt)
	step_loot_visual(dt)
	_tick_impact_camera(dt)
	for f in fxs:
		f.step(dt)
	_update_smoke_density()
	_cleanup()
	queue_redraw()

func in_battle() -> bool:
	return battle_center != Vector2.INF

func start_battle(center: Vector2, radius: float) -> void:
	battle_center = center
	battle_radius = radius

func end_battle() -> void:
	stop_battle_audio()
	battle_center = Vector2.INF

# 배틀 울타리: 나와 상대 포켓몬 모두 원 안에 둔다. 반지름 0 이면 울타리 없음(경기장 — 벽이 이미 가둔다).
func _fence_battle() -> void:
	if not in_battle() or battle_radius <= 0.0:
		return
	for mon in [player] + enemies:
		if mon.dead:
			continue
		var d: Vector2 = mon.position - battle_center
		var lim: float = battle_radius - mon.radius
		if d.length() > lim:
			mon.position = resolve_mon(mon,battle_center + d.normalized() * lim)

# 배틀을 시작한 트레이너 쪽 포켓몬 하나를 그 자리에 내보낸다. hidden 이면 아직 안 보이게(appear 0) 두고 — 던진 볼이 닿으면
# Game 이 pop_out 으로 터뜨린다 — 아니면 바로 몬스터볼에서 나오는 빛과 함께.
func send_out(species_id: String, level: int, moves: Array, pos: Vector2, hidden := false, fixed_iv: int = 0) -> Enemy:
	var e := Enemy.new()
	e.setup_trainer_mon(species_id, level, moves, rng, fixed_iv)
	e.position = Arena.resolve(pos, e.radius)
	e.facing = (player.position - e.position).normalized()
	add_child(e)
	enemies.append(e)
	if hidden:
		e.appear = 0.0
		return e
	pop_out(e)
	return e

func pop_out(e: Mon, starter_table := false) -> void:
	var support := BallRelease.support_of(e,starter_table)
	e.release_fx = add_fx("ball_release",support,{"owner_mon":e,"starter_table":starter_table,"lifetime":BallRelease.LIFE})
	Sfx.play("bowa", 1.0, _battle_sound_db(e.position), _battle_sound_pan(e.position), get_instance_id())
	Sfx.cry(e.species_id, 1.0, _battle_sound_db(e.position), _battle_sound_pan(e.position), get_instance_id())

# ── 기술머신 기술(사용자 결정 2026-10-30, C안) ──

# 기가드레인: 투사체 없이 사거리 안에서 가장 가까운 상대 하나를 때리고, 준 피해의 절반을 회복한다(빛 구슬이 상대 → 나).
func _drain(mon: Mon, m: Dictionary, hit: Dictionary, dir: Vector2) -> void:
	var direction:=dir.normalized()
	var end:=mon.position+direction*float(m.range)
	var connected:=false
	for target: Mon in opponents(mon.team):
		if (target.position-mon.position).dot(direction)<0: continue
		var nearest:=Geometry2D.get_closest_point_to_segment(target.position,mon.position,end)
		if target.position.distance_to(nearest)>target.radius+3.0: continue
		if apply_hit(target,hit,mon.position) and last_damage>0:
			connected=true
			_drain_return(mon,m,hit,target)
	if not connected and mon==player and _text_cd<=0.0:
		float_text(mon.position+Vector2.UP*(mon.radius+14),Lang.t("nothing"),Color("e0e0e0"),7)
		_text_cd=TEXT_COOLDOWN

func _drain_return(mon: Mon,m: Dictionary,hit: Dictionary,best: Mon) -> void:
	var back := maxi(1, int(round(last_damage * float(hit["drain"]))))
	if String(m["id"]) in ["absorb","mega_drain"]:
		KantoMoveFx.drain(self,mon,best,String(m["id"])=="mega_drain")
	else:
		var from := best.position + Vector2(0, -best.radius * 0.5)
		var to := mon.position + Vector2(0, -mon.radius * 0.5)
		for k in 5:
			var start := from + Vector2.from_angle(TAU * float(k) / 5.0) * best.radius * 0.8
			add_fx("sprite", start, {"text": "g4_glow", "color": Color8(64, 248, 152, 230) if k % 2 == 0 else Color8(240, 248, 80, 230), "size": 6.0,
				"dir": (to - start).normalized(), "speed": start.distance_to(to) / 0.35, "lifetime": 0.35 + 0.05 * k, "delay": 0.05 * k, "fade_out": 0.1})
	var caster_ref: WeakRef=weakref(mon)
	var heal_back := func() -> void:
		var caster: Mon=caster_ref.get_ref()
		if is_instance_valid(caster) and not caster.dead:
			heal(caster, back)
	pending_calls.append({"t": 0.45, "call": heal_back})

# 구멍파기: 땅속으로. Rotate 동작으로 가라앉고(sink) under 초 동안 그림자만 남는다(무적). 끝나거나 다시 누르면 _emerge.
func _burrow(mon: Mon, m: Dictionary, hit: Dictionary) -> void:
	var sink := float(m.get("sink", 0.25))
	mon.burrow = {"t": float(m["under"]), "under": float(m["under"]), "sink": sink, "move": String(m["id"]), "hit": hit, "m": m}
	mon.invuln_t = maxf(mon.invuln_t, float(m["under"]) + sink + 0.1)
	mon.play_attack("Rotate", sink)
	_dig_dust(mon.position + Vector2(0, mon.feet_offset()), mon.radius, 6)

func _step_burrows(dt: float) -> void:
	var b: Dictionary = player.burrow
	if b.is_empty() or player.dead:
		return
	if float(b["sink"]) > 0.0:
		b["sink"] = float(b["sink"]) - dt
		return
	var before := float(b["t"])
	b["t"] = before - dt
	if int(before * 6.0) != int(float(b["t"]) * 6.0):      # 땅속을 지나는 자리에 흙이 들썩인다
		add_fx("sprite", player.position + Vector2(0, player.feet_offset()), {"text": "g4_dust", "color": Color8(200, 176, 112, 200),
			"size": player.radius * 0.9, "grow": 1.6, "lifetime": 0.3})
	if float(b["t"]) <= 0.0:
		_emerge(player)

# 솟구친다: 둘레 radius 의 상대를 치고(360°), 후딜(recover) 동안 움직이지 못한다.
func _emerge(mon: Mon) -> void:
	var b: Dictionary = mon.burrow
	mon.burrow = {}
	mon.invuln_t = 0.0
	var m: Dictionary = b["m"]
	mon.play_attack("Attack")
	var feet := mon.position + Vector2(0, mon.feet_offset())
	_dig_dust(feet, mon.radius, 10)
	for k in 3:
		var a := -PI / 2.0 + (k - 1) * 0.7
		add_fx("sprite", feet, {"text": "g4_rock_chunk", "color": Color.WHITE, "size": 6.0, "dir": Vector2.from_angle(a), "speed": 90.0,
			"spin": 8.0, "lifetime": 0.45, "fade_out": 0.2})
	_melee_arc(mon, {"range": float(m["radius"]), "arc_deg": 360.0, "fx": "dig"}, b["hit"], mon.facing)
	mon.recover_t = float(m.get("recover", 0.8))
	mon.vel = Vector2.ZERO

# dig.spa 흙먼지(이미터 색 200,176,112 → 152,128,56): 발밑에서 사방으로.
func _dig_dust(at: Vector2, r: float, n: int) -> void:
	for k in n:
		var a := TAU * float(k) / float(n) + randf_range(-0.2, 0.2)
		add_fx("sprite", at, {"text": "g4_dust", "color": Color8(200, 176, 112, 220), "size": r * 1.1, "grow": 1.8,
			"dir": Vector2.from_angle(a), "speed": r * 2.5 * randf_range(0.8, 1.2), "lifetime": 0.4, "delay": 0.02 * (k % 3)})

# 물리 넉백 배율: x = (공격 ÷ 방어) × √(내 몸무게 ÷ 상대 몸무게) 를 포화 곡선 2x/(1+x) 에 넣는다(힘이 같으면 1, 상한 2).
static func knock_factor(atk: float, def: float, my_kg: float, their_kg: float) -> float:
	var x := (atk / maxf(1.0, def)) * sqrt(maxf(0.1, my_kg) / maxf(0.1, their_kg))
	return 2.0 * x / (1.0 + x)

# 그 거리(px)만큼 미끄러지게 하는 처음 속도(Mon.KNOCK_DECEL 로 줄어든다).
static func knock_speed(dist: float) -> float:
	return sqrt(2.0 * Mon.KNOCK_DECEL * maxf(0.0, dist))

# 특수기 경직 시간: y = 특공 ÷ 특방 을 같은 포화 곡선에 넣어 STUN_BASE 에 곱한다(같으면 0.4초, 상한 0.8초). 내가 맞으면 절반.
static func stun_time(spa: float, spd: float, to_player: bool) -> float:
	var y := spa / maxf(1.0, spd)
	var t := STUN_BASE * 2.0 * y / (1.0 + y)
	return t * 0.5 if to_player else t

# (옛) 접촉 피해. 지금은 쓰지 않는다.
func _contact_damage() -> void:
	if player.dead or player.invuln_t > 0.0:
		return
	for e in enemies:
		if e.dead or e.is_dashing():
			continue
		if e.position.distance_to(player.position) < e.radius + player.radius - 1.0:
			var hit := {"move": "", "type": "normal", "cat": "physical", "level": e.level,
				"atk": e.stats["atk"], "stab": false,
				"power": CONTACT_POWER,
				"burn": 0.0, "poison": 0.0, "slow": 0.0, "flinch": 0.0, "crit": 0.0, "team": e.team,
				"mult": _damage_mult(e)}
			apply_hit(player, hit, e.position)
			return

func _tick_status(dt: float) -> void:
	var all: Array = [player]
	all.append_array(enemies)
	for mon in all:
		if mon.dead:
			mon.tick_faint(dt)
			continue
		# 씨뿌리기: 심은 쪽이 쓰러지면(사라지면) 풀린다(사용자 결정 2026-10-29). 조이기도 조인 쪽이 쓰러지면 풀린다(원작).
		if mon.leech_t > 0.0 and (not is_instance_valid(mon.leech_by) or mon.leech_by.dead):
			mon.leech_t = 0.0
		if mon.bind_t > 0.0 and (not is_instance_valid(mon.bind_by) or mon.bind_by.dead):
			mon.bind_t = 0.0
		var sleeping: bool = mon.sleep_t>0.0
		var confused: bool = mon.confuse_t>0.0
		var poison_before: float = mon.poison_acc
		var burn_before: float = mon.burn_acc
		var tick: int = mon.tick_status(dt)
		if sleeping and mon.sleep_t<=0.0: _status_text(mon,Lang.t("woke_up",[_battle_name(mon)]))
		if confused and mon.confuse_t<=0.0: _status_text(mon,Lang.t("confusion_ended",[_battle_name(mon)]))
		if tick > 0:
			if mon.poison_t>0.0 and mon.poison_acc<poison_before: _status_text(mon,Lang.t("poison_damage",[_battle_name(mon)]))
			if mon.burn_t>0.0 and mon.burn_acc<burn_before: _status_text(mon,Lang.t("burn_damage",[_battle_name(mon)]))
			var col := Color("ff8a3c") if mon.burn_t > 0.0 else (Color("80e060") if mon.leech_drained > 0 and mon.poison_t <= 0.0 else Color("c070f0"))
			float_text(mon.position + Vector2(0, -mon.radius - 4), str(tick), col, 7)
			# 씨뿌리기: 빼앗은 HP 가 초록 빛으로 쓴 쪽에게 날아가 회복한다(플래티넘 leech_seed 의 흡수 구슬).
			if mon.leech_drained > 0 and is_instance_valid(mon.leech_by) and not mon.leech_by.dead:
				var src: Mon = mon.leech_by
				add_fx("sprite", mon.position + Vector2(0, -mon.radius * 0.5), {"text": "g4_glow", "color": Color(0.6, 1.0, 0.4, 0.95),
					"size": 8.0, "dir": (src.position - mon.position).normalized(), "speed": src.position.distance_to(mon.position) / 0.35,
					"lifetime": 0.35, "fade_out": 0.3})
				heal(src, mon.leech_drained)
			damage(mon, tick)
		# 꽃잎댄스: 난동이 끝나면 지쳐서 혼란(원작).
		if mon.rampage_t > 0.0:
			mon.rampage_t -= dt
			if mon.rampage_t <= 0.0 and not mon.dead:
				confuse(mon)

# Drop simulation and inventory transfers run only during play; visual flights also run in dialogue.
func spawn_loot(id: String,at: Vector2) -> LootItem:
	var item := LootItem.new()
	item.setup(id,at)
	item.ttl=DROP_LIFE
	add_child(item)
	drops.append(item)
	return item

func pickup_visual(id: String,amount: int,at: Vector2) -> LootItem:
	var item := spawn_loot(id,at)
	_begin_loot_flight(item,amount)
	return item

func award_berries(reward: Dictionary,at: Vector2) -> Dictionary:
	var reserved := {}
	for id in reward:
		var amount := int(reward[id])
		var accepted := player.add_item(id,amount)
		if accepted>0: pickup_visual(id,accepted,at)
		if accepted<amount:
			reserved[id]=amount-accepted
			player.reward_reserve[id]=int(player.reward_reserve.get(id,0))+amount-accepted
	inventory_changed.emit()
	return reserved

func _begin_loot_flight(item: LootItem,amount: int=1) -> void:
	item.count=amount
	var previous = _loot_flights.get(item.item_id)
	if is_instance_valid(previous) and not previous.done and previous.flight<LOOT_BATCH_TIME and previous.start.distance_to(item.draw_at)<=LOOT_MERGE_RADIUS:
		previous.count+=amount
		item.merge_into(previous)
	else:
		item.collect(player,amount)
		_loot_flights[item.item_id]=item
		add_fx("pickup_trail",item.draw_at,{"lifetime":LootItem.FLY_TIME+0.24,"pickup_item":item})

# Fixed window from the first pickup: sustained collection cannot postpone messages forever.
func _queue_loot_notice(id: String,amount: int) -> void:
	if _loot_notices.is_empty(): _loot_notice_time=LOOT_BATCH_TIME
	_loot_notices[id]=int(_loot_notices.get(id,0))+amount

static func loot_summary_pages(items: Dictionary) -> Array[String]:
	var pages: Array[String]=[]
	var lines: Array[String]=[]
	for id in items:
		if int(items[id])<=0:continue
		lines.append(Lang.t("got_items",[ItemDB.name_of(id),int(items[id])]))
		if lines.size()==2:
			pages.append("\n".join(lines));lines.clear()
	if not lines.is_empty():pages.append("\n".join(lines))
	return pages

func _claim_reward_reserve() -> bool:
	if player.dead:return false
	var changed := false
	for id in player.reward_reserve.keys():
		var accepted := player.add_item(id,int(player.reward_reserve[id]))
		if accepted<=0:continue
		player.reward_reserve[id]-=accepted
		if int(player.reward_reserve[id])<=0:player.reward_reserve.erase(id)
		pickup_visual(id,accepted,player.position+Vector2(24,-8))
		_queue_loot_notice(id,accepted)
		changed=true
	return changed

func step_loot_visual(dt: float) -> void:
	if not _loot_notices.is_empty():
		_loot_notice_time-=dt
		if _loot_notice_time<=0.0:
			var pages := loot_summary_pages(_loot_notices)
			_loot_notices.clear()
			for page in pages:status_message.emit(page)
	for item in drops:
		item.update_visual(dt)
	for item in drops.duplicate():
		if item.done:
			drops.erase(item)
			item.queue_free()
	for id in _loot_flights.keys():
		var item = _loot_flights[id]
		if not is_instance_valid(item) or item.done:_loot_flights.erase(id)

func _loot_reachable(at: Vector2) -> bool:
	var delta := at-player.position
	for i in range(1,maxi(2,int(ceil(delta.length()/4.0)))):
		if Arena.blocks(player.position+delta.normalized()*float(i)*4.0,1.0):return false
	return true

func _step_drops(dt: float) -> void:
	step_loot_visual(dt)
	var changed := _claim_reward_reserve()
	for item in drops:
		if item.flight>=0.0:continue
		item.ttl-=dt
		if item.ttl<=0.0:
			item.done=true;continue
		if player.dead or item.age<LootItem.FALL_TIME or player.position.distance_to(item.position)>1.5*Arena.TILE:continue
		if not _loot_reachable(item.position):continue
		if player.add_item(item.item_id)==0:continue # Full bag: leave this drop on the ground.
		_begin_loot_flight(item)
		_queue_loot_notice(item.item_id,1)
		changed=true
	if changed:inventory_changed.emit()

# 가방에서 도구를 쓴다(가방 창). 결과: "" 쓰고 줄었다 / "escape" 던전 탈출(Game 이 장면을 바꾼다) / 그 밖은 Lang 키(안 썼음).
func use_item(id: String, pp_slot: int = -1) -> String:
	var eff := ItemDB.effect(id)
	if eff.is_empty() or int(player.bag.get(id, 0)) <= 0:
		return "trade_only"
	if eff.has("hold"):
		return "hold"                # Game 이 지니기 ↔ 돌려받기
	if eff.has("revive"):
		return "revive_auto"
	if eff.has("escape"):
		if hub:
			return "cant_use_here"
		player.take_item(id)
		return "escape"
	if eff.has("repel"):
		if not overworld:
			return "cant_use_here"
		player.take_item(id)
		player.repel_steps = int(eff["repel"])
		return ""
	if player.dead: return "item_no_effect"
	var heal_amount := player.max_hp if int(eff.get("heal",0))<0 else int(eff.get("heal",0))
	if eff.has("heal_ratio"): heal_amount=maxi(1,int(floor(player.max_hp*float(eff.heal_ratio))))
	var pp_target := -1
	if eff.has("pp_restore"):
		pp_target=berry_pp_slot(pp_slot)
	var did := heal_amount>0 and player.hp<player.max_hp
	for st in eff.get("cure",[]):
		if _has_status(st): did=true
	if pp_target>=0: did=true
	if not did: return "item_no_effect"
	var berry := ItemDB.pocket_of(id)=="berries"
	if berry and player.berry_cd>0.0: return "item_wait"
	player.take_item(id)
	if heal_amount>0: heal(player,heal_amount)
	for st in eff.get("cure",[]): _cure(st)
	if pp_target>=0:
		player.pp[pp_target]=mini(MoveDB.pp_of(player.slots[pp_target]),int(player.pp[pp_target])+int(eff.pp_restore))
		if player.can_swap(pp_target): player.regen_t[pp_target]=0.0
		_status_text(player,Lang.t("berry_pp_restored",[MoveDB.move_name(player.slots[pp_target])]))
	if berry:
		player.berry_cd=Player.BERRY_COOLDOWN
		if player.vel.length_squared()<0.01 and player.attack_anim_t<=0.0 and player.hop_t<=0.0: player.play_eat()
	return ""

# PP berries always default to the visible, last-pressed skill. Full/empty slots never redirect.
func berry_pp_slot(requested: int = -1) -> int:
	var slot := requested if requested>=0 else player.pp_focus_slot
	if slot<0 or slot>=Player.SLOT_COUNT or player.slots[slot]=="" or player.can_swap(slot):return -1
	return slot

const BERRY_LOW_HP := 0.35
const BERRY_LOW_PP := 0.25
func berry_needs_attention(id: String) -> bool:
	if player.dead or player.berry_cd>0.0 or int(player.bag.get(id,0))<=0 or ItemDB.pocket_of(id)!="berries":return false
	var effect := ItemDB.effect(id)
	for status in effect.get("cure",[]):
		if _has_status(status):return true
	if (effect.has("heal") or effect.has("heal_ratio")) and player.hp_ratio()<=BERRY_LOW_HP:return true
	if effect.has("pp_restore"):
		var slot := berry_pp_slot()
		return slot>=0 and float(player.pp[slot])/maxi(1,MoveDB.pp_of(player.slots[slot]))<=BERRY_LOW_PP
	return false

func _has_status(st: String) -> bool:
	match st:
		"burn": return player.burn_t > 0.0
		"poison": return player.poison_t > 0.0
		"paralyze": return player.para_t > 0.0
		"slow": return player.slow_t > 0.0
		"sleep": return player.sleep_t > 0.0
		"confuse": return player.confuse_t > 0.0
	return false

func _cure(st: String) -> void:
	var had := _has_status(st)
	match st:
		"burn": player.burn_t = 0.0
		"poison": player.poison_t = 0.0
		"paralyze": player.para_t = 0.0
		"slow": player.slow_t = 0.0
		"sleep": player.sleep_t = 0.0
		"confuse": player.confuse_t = 0.0

	var message_key: String = {"poison":"cured_poison","burn":"cured_burn","paralyze":"cured_paralyze","sleep":"woke_up","confuse":"confusion_ended"}.get(st,"")
	if had and not message_key.is_empty(): _status_text(player,Lang.t(message_key,[_battle_name(player)]))

# 포켓몬센터: HP·PP·상태를 모두 원래대로.
# shine: 회복한 몸이 한 번 번쩍(도구). 포켓몬센터 회복은 기계의 빛이 이미 연출이라 번쩍이지 않는다(사용자 지적 2026-10-30: 내려온 뒤에도 밝았다).
func full_restore(shine: bool = true) -> void:
	player.hp = player.max_hp
	for i in Player.SLOT_COUNT:
		if player.slots[i] != "":
			player.pp[i] = MoveDB.pp_of(player.slots[i])
			player.regen_t[i] = 0.0
	for st in ItemDB.STATUSES:
		_cure(st)
	if shine:
		player.shine_t = 0.6

signal hotbar_used(item_id: String)    # 편성한 도구(오랭열매 말고)를 썼다 — Game 이 가방에서 쓴 것과 같게 처리

func _use_hotbar(n: int, moving: bool) -> void:
	var id: String = player.hotbar[n] if n < player.hotbar.size() else ""
	if id == "" or int(player.bag.get(id, 0)) <= 0:
		return
	if id == "oran_berry":
		_try_eat(moving)
	else:
		hotbar_used.emit(id)

# 오랭열매 하나를 먹는다(도구 편성 칸 — 처음엔 Q). 즉시 HP 10(원작 값). 멈춰 있으면 먹기 동작이 나온다. HP 가 가득이면 원작처럼 "효과가 없을 것 같다".
func _try_eat(moving: bool) -> void:
	if player.berries <= 0 or player.berry_cd > 0.0 or player.hop_t > 0.0 or no_skills:
		return
	if player.hp >= player.max_hp:
		if _text_cd <= 0.0:
			float_text(player.position + Vector2(0, -player.radius - 14), Lang.t("item_no_effect"), Color("e0e0e0"), 7)
			_text_cd = TEXT_COOLDOWN
		return
	player.berries -= 1
	player.berry_cd = Player.BERRY_COOLDOWN
	heal(player, int(ItemDB.effect("oran_berry")["heal"]))
	float_text(player.position + Vector2(0, -player.radius - 14), Lang.t("oran"), Color("8fd0ff"), 7)
	if not moving and player.attack_anim_t <= 0.0:
		player.play_eat()

# ── 효과 ──

func add_fx(kind: String, pos: Vector2, opts: Dictionary = {}) -> Fx:
	var f := Fx.new()
	f.kind = kind
	f.position = pos
	f.light_mask = Look.UNLIT_MASK          # 효과 그림은 HD-2D 조명을 받지 않는다(타는 불꽃이 하얗게 날아가지 않게)
	for k in opts:
		f.set(k, opts[k])
	if kind in Look.GROUND_FX:
		f.visibility_layer = 1 | Look.GROUND_LAYER      # 3D 화면에선 바닥 오버레이로(View3D)
	if kind == "sprite" and Look.emissive(f.text, f.color):
		f.material = Look.additive()            # HD-2D 느낌: 불꽃·번개는 가산 합성으로 빛나게
	# 글자·섬광·발톱 자국은 포켓몬 위에, 나머지(예고·장판)는 아래에.
	f.z_index = 0 if kind == "tallgrass" else 5 if kind in ["ball_release", "text", "burst", "impact", "fang", "fang_directional", "fangfire", "sprite", "anim", "spark", "rain", "swipe", "wrap", "pickup_trail", "forward_cut", "clash_chip"] else (-5 if kind == "dim" else -1)
	add_child(f)
	fxs.append(f)
	return f

# 풀숲 흔들림(원작 FLDEFF_TALL_GRASS): 포켓몬이 새 칸에 들어섰고 그 칸이 풀숲이면 그 칸에 풀 효과를 하나.
# 뛰어오른 동안(점프·언덕)은 건너뛰고 내려앉은 칸에서 낸다. 처음 보는 포켓몬(막 나왔거나 장면을 연 직후)은 동작 없이 프레임 0 부터.
func _step_tall_grass() -> void:
	if not Arena.has_map():
		return
	var all: Array = [player]
	all.append_array(enemies)
	for mon in all:
		if mon.dead or mon.hop_t > 0.0:
			continue
		var feet: float = mon.feet_offset()
		var t := Arena.tile_of(mon.position + Vector2(0, feet))
		var first: bool = not mon.has_meta("grass_tile")
		if not first and mon.get_meta("grass_tile") == t:
			continue
		mon.set_meta("grass_tile", t)
		if Arena.is_grass(t):
			if mon==player and not first: player_grass_rustled.emit()
			# 노드 자리(y 정렬 기준)는 '발이 칸 바닥선에 닿는 position' 바로 위: 발이 이 칸에 있는 포켓몬보다 앞, 아래 칸보다 뒤.
			var sort_y := Arena.tile_center(t).y + Arena.TILE / 2.0 - 1.0 - feet
			add_fx("tallgrass", Vector2(Arena.tile_center(t).x, sort_y),
				{"tile": t, "owner_mon": mon, "settled": first, "lifetime": 1e9, "offset": Vector2(0, feet)})

# ── 이상해씨·꼬북이 기술의 자기 강화·회복·방어·날씨(사용자 요청 2026-10-28) ──

# 자기 랭크 올리기(단단해지기·껍질에숨기·철벽·성장). 연출은 기술마다 플래티넘 연출을 따른다.
func _self_buff(mon: Mon, m: Dictionary) -> void:
	var key := String(m.get("stat", "def"))
	var before: int = mon.get(key + "_stage")
	var after := mini(6, before + int(m.get("stages", 1)))
	mon.set(key + "_stage", after)
	var body := Vector2(0, -mon.radius * 0.5)
	match String(m.get("fx", "")):
		"withdraw":
			# withdraw.spa: 하늘색 껍질 두 쪽이 양옆에서 닫히고 흰 고리가 조여 든다.
			for sd in [-1.0, 1.0]:
				add_fx("sprite", mon.position + body + Vector2(sd * mon.radius * 1.6, 0), {"text": "g4_shell_l" if sd < 0 else "g4_shell_r",
					"color": Color8(128, 168, 248, 230), "size": mon.radius * 1.8, "dir": Vector2(-sd, 0), "speed": mon.radius * 1.6 / 0.25,
					"lifetime": 0.32, "fade_out": 0.3})
			add_fx("sprite", mon.position + body, {"text": "g4_ring_white", "color": Color8(160, 200, 255, 220), "size": mon.radius * 4.0,
				"grow": 0.4, "lifetime": 0.4, "follow": mon, "offset": body})
		"growth":
			# 원작 Func_Growth: 몸이 커졌다 돌아온다 → 빛이 부풀며 번진다.
			mon.shine_t = 0.4
			add_fx("sprite", mon.position + body, {"text": "g4_glow", "color": Color(1.0, 0.95, 0.6, 0.8), "size": mon.radius * 2.0,
				"grow": 2.6, "lifetime": 0.45, "follow": mon, "offset": body})
		"rockpolish":
			# rock_polish.spa: 분홍빛 별이 번쩍이고(이미터 248,200,248) 흰 빛줄기가 몸 둘레에서 솟는다.
			add_fx("sprite", mon.position + body, {"text": "g4_polish_star", "color": Color8(248, 200, 248, 240), "size": mon.radius * 3.2,
				"grow": 1.3, "lifetime": 0.35, "fade_out": 0.2})
			for k in 6:
				var a := TAU * float(k) / 6.0
				add_fx("sprite", mon.position + body + Vector2.from_angle(a) * mon.radius * 1.1, {"text": "g4_polish_streak", "color": Color8(248, 248, 248, 230),
					"size": mon.radius * 1.2, "dir": Vector2.UP, "speed": 40.0, "lifetime": 0.4, "delay": 0.05 * k, "fade_out": 0.2})
		"defensecurl":
			# defense_curl.spa: 물방울 막이 몸을 감싸고 C 자 고리가 돌며 오그라든다.
			mon.crouch_t = 0.4
			add_fx("sprite", mon.position + body, {"text": "g4_orb_bubble", "color": Color(1, 1, 1, 0.85), "size": mon.radius * 2.6,
				"grow": 0.85, "lifetime": 0.5, "fade_out": 0.25, "follow": mon, "offset": body})
			add_fx("sprite", mon.position + body, {"text": "g4_curl_c", "color": Color(0.95, 1.0, 1.0, 0.8), "size": mon.radius * 3.2,
				"grow": 0.5, "spin": 6.0, "lifetime": 0.45, "follow": mon, "offset": body})
		"irondefense":
			# 철벽: 금속 번쩍임(Func_StatChangeMetal) 두 번.
			mon.shine_t = 0.8
			add_fx("sprite", mon.position + body, {"text": "g4_star64", "color": Color(0.85, 0.9, 1.0, 0.95), "size": mon.radius * 2.0,
				"grow": 2.4, "spin": 1.5, "lifetime": 0.5, "follow": mon, "offset": body})
		_:
			# 단단해지기(harden.spa): 네 갈래 별 빛 + 금속 번쩍임.
			mon.shine_t = 0.6
			add_fx("sprite", mon.position + body, {"text": "g4_star64", "color": Color(0.95, 0.97, 1.0, 0.95),
				"size": mon.radius * 2.0, "grow": 2.4, "spin": 1.5, "lifetime": 0.5, "follow": mon, "offset": body})
			add_fx("impact", mon.position + Vector2(0, -mon.radius * 0.4), {"lifetime": 0.25, "size": mon.radius * 1.2, "color": Color(0.9, 0.95, 1.0)})
	if after > before:
		mon.play_stat(key + "_up")
	float_text(mon.position + Vector2(0, -mon.radius - 6), Lang.t(_rank_change_key(after-before) if after > before else "stat_wont_up", [_rank_subject(mon,key)]), Color("c8d8ff"), 7)

# 광합성: 최대 HP 의 1/2(비가 오면 1/4) 회복. synthesis.spa 의 빛줄기가 위에서 내려와 몸이 노랗게 빛난다.
func _teleport_mon(mon: Mon, move: Dictionary) -> void:
	var origin:=mon.position
	var best:=origin
	var distance:=origin.distance_squared_to(player.position)
	var field: Array=Arena.map.get("arena",{}).get("field",[])
	for i in 16:
		var point:=origin+Vector2.from_angle(TAU*i/16.0)*float(move.get("range",3*Arena.TILE))
		point=Arena.resolve(point,mon.radius)
		if Arena.has_map() and Arena.solid_at(Arena.tile_of(point).x,Arena.tile_of(point).y): continue
		if field.size()==4 and not Rect2(float(field[0])*Arena.TILE,float(field[1])*Arena.TILE,float(field[2])*Arena.TILE,float(field[3])*Arena.TILE).grow(-mon.radius).has_point(point):continue
		if not Arena.warp_at(point).is_empty() or Arena.area_at(point)!=Arena.area_at(origin):continue
		if point.distance_squared_to(player.position)>distance:
			best=point
			distance=point.distance_squared_to(player.position)
	for point in [origin,best]:
		add_fx("sprite",point,{"text":"g4_glow","size":mon.radius*2.2,"grow":1.8,"lifetime":0.3,"fade_out":0.2,"color":Color("d8b8ff")})
	mon.position=best
	mon.vel=Vector2.ZERO

func _self_heal(mon: Mon, m: Dictionary) -> void:
	var frac := float(m.get("heal", 0.5)) * (0.5 if weather == "rain" and String(m.get("id",""))=="synthesis" else 1.0)
	for k in 5:
		var x := (float(k) / 4.0 - 0.5) * mon.radius * 2.4
		add_fx("sprite", mon.position + Vector2(x, -mon.radius * 3.0), {"text": "g4_ray", "color": Color8(248, 248, 184, 230), "size": 5.0,
			"dir": Vector2.DOWN, "speed": mon.radius * 2.0 / 0.4, "lifetime": 0.45, "delay": 0.05 * k, "fade_out": 0.4})
	add_fx("sprite", mon.position + Vector2(0, -mon.radius * 0.5), {"text": "g4_glow", "color": Color8(248, 248, 152, 200), "size": mon.radius * 2.4,
		"grow": 1.6, "lifetime": 0.6, "delay": 0.2, "follow": mon, "offset": Vector2(0, -mon.radius * 0.5)})
	mon.start_tint(Color8(248, 248, 120), 0.5, 0.6)
	if mon.hp >= mon.max_hp:
		float_text(mon.position + Vector2(0, -mon.radius - 14), Lang.t("hp_full"), Color("e0e0e0"), 7)
		return
	heal(mon, maxi(1, int(round(mon.max_hp * frac))))

# 방어: 1초 동안 모든 공격을 막는다. 연달아(직전 방어가 끝난 지 1초 안) 쓰면 성공 확률이 1/2, 1/4 … (원작).
func _protect(mon: Mon) -> void:
	var chain := mon.protect_chain if mon.protect_gap < Mon.PROTECT_TIME + 1.0 else 0
	if chain > 0 and rng.randf() >= pow(0.5, chain):
		mon.protect_chain = 0
		float_text(mon.position + Vector2(0, -mon.radius - 14), Lang.t("protect_failed"), Color("e0e0e0"), 7)
		return
	mon.protect_chain = chain + 1
	mon.protect_gap = 0.0
	mon.protect_t = Mon.PROTECT_TIME
	# protect.spa: 초록→하늘 빛 16알이 몸을 감싸는 막(사분면 빛을 둥글게).
	add_fx("sprite", mon.position + Vector2(0, -mon.radius * 0.5), {"text": "g4_protect", "color": Color8(120, 248, 184, 140), "size": mon.radius * 6.0,
		"grow": 1.05, "fade_in": 0.1, "fade_out": 0.3, "lifetime": Mon.PROTECT_TIME, "follow": mon, "offset": Vector2(0, -mon.radius * 0.5)})
	add_fx("sprite", mon.position + Vector2(0, -mon.radius * 0.5), {"text": "g4_ring_white", "color": Color8(72, 176, 248, 200), "size": mon.radius * 3.6,
		"grow": 1.1, "fade_in": 0.1, "fade_out": 0.3, "lifetime": Mon.PROTECT_TIME, "follow": mon, "offset": Vector2(0, -mon.radius * 0.5)})

# 날씨 시작(비바라기). 원작 턴 = 1초. 비 오는 동안 화면에 빗줄기(rain_dance.spa 빗방울).
func start_weather(kind: String, sec: float) -> void:
	weather = kind
	weather_t = sec
	float_text(player.position + Vector2(0, -player.radius - 18), Lang.t("rain_started"), Color("a8d0ff"), 7)
	add_fx("rain", player.position, {"lifetime": sec, "follow": player})

func _step_weather(dt: float) -> void:
	if weather_t <= 0.0:
		return
	weather_t -= dt
	if weather_t <= 0.0:
		weather = ""
		float_text(player.position + Vector2(0, -player.radius - 18), Lang.t("rain_stopped"), Color("c0d8f0"), 7)

# 솔라빔: 노란 빛 마디(solar_beam.spa 의 긴 빛)가 쏜 자리에서 사거리까지 줄지어 번쩍인다.
func _solar_beam_fx(mon: Mon, dir: Vector2, length: float, life: float) -> void:
	var from := mon.position + Vector2(0, -mon.radius * 0.4) + dir * (mon.radius+Projectile.RELEASE_GAP)
	var n := int(length / 10.0)
	for k in n:
		var at := from + dir * (10.0 * k + 5.0)
		add_fx("sprite", at, {"text": "g4_beam_glow", "color": Color8(248, 248, 120, 230), "size": 30.0, "stretch": 0.5, "rot": dir.angle() + PI / 2.0,
			"grow": 1.2, "lifetime": life, "delay": 0.01 * k, "fade_out": 0.5})
	add_fx("sprite", from, {"text": "g4_solar_glow", "color": Color8(248, 248, 56, 230), "size": mon.radius * 2.4, "grow": 1.6, "lifetime": 0.3})

# 솔라빔을 모으는 동안: 빛 알갱이가 몸으로 모여든다(solar_beam.spa 의 수렴하는 빛).
func charge_fx(mon: Mon, m: Dictionary, time: float) -> void:
	match String(m.get("fx", "")):
		"solar":
			# 빛 알갱이가 0.4초마다 한 차례씩(차례마다 각도를 비껴) 몸으로 모여든다 — 모으는 시간이 길어도 끊기지 않게.
			var rounds := maxi(1, int(floor(time / 0.4)))
			for r in rounds:
				for k in 8:
					var a := TAU * (float(k) + 0.5 * float(r % 2)) / 8.0
					var start := mon.position + Vector2(cos(a), sin(a)) * mon.radius * 3.0
					add_fx("sprite", start, {"text": "g4_glow", "color": Color8(248, 248, 120, 220), "size": 7.0,
						"dir": (mon.position - start).normalized(), "speed": mon.radius * 3.0 / 0.5, "lifetime": 0.4 * r + 0.5,
						"delay": 0.4 * r, "fade_out": 0.15})   # lifetime 은 delay 를 포함한다(Fx)
			mon.start_tint(Color8(248, 248, 120), 0.4, time)
		"gigadrain":
			# 기가드레인: 모으는 동안 초록으로 물든다(giga_drain.spa 이미터 색).
			mon.start_tint(Color8(144, 248, 168), 0.35, time)
		"skullbash":
			# 로케트박치기: 몸을 웅크리며 붉게(원작 FadeBg + RotateMon) 빛난다.
			mon.start_tint(Color8(248, 96, 64), 0.35, time)

# 돌진류가 맞힌 순간의 원작 연출.
func _dash_hit_fx(t: Mon, style: String, dir: Vector2) -> void:
	var up := Vector2(0, -t.radius * 0.5)
	match style:
		"takedown", "skullbash":
			# take_down / skull_bash.spa: 뾰족한 타격 별 + 먼지 구름.
			add_fx("sprite", t.position + up, {"text": "g4_burst_q", "color": Color8(248, 208, 0, 240) if style == "takedown" else Color8(248, 248, 120, 240),
				"size": t.radius * 2.6, "grow": 1.5, "lifetime": 0.25, "follow": t, "offset": up})
			for k in 3:
				add_fx("sprite", t.position + Vector2((k - 1) * t.radius * 0.8, 0), {"text": "g4_puff", "color": Color(0.9, 0.85, 0.75, 0.8),
					"size": t.radius * 1.2, "grow": 1.8, "dir": Vector2((k - 1) * 0.6, -0.5).normalized(), "speed": 30.0, "lifetime": 0.4, "delay": 0.04 * k})
			t.shake_t = 0.3
		"rollout":
			# rollout.spa: 모래색 먼지가 터지고 바위 조각이 튄다(이미터 200,184,136).
			add_fx("sprite", t.position + up, {"text": "g4_roll_dust", "color": Color8(232, 224, 184, 230), "size": t.radius * 2.4, "grow": 1.6, "lifetime": 0.25, "follow": t, "offset": up})
			for k in 2:
				add_fx("sprite", t.position + up, {"text": "g4_roll_rock", "color": Color.WHITE, "size": t.radius * 0.7, "spin": randf_range(-10.0, 10.0),
					"dir": Vector2(dir.x * 0.4 + (k * 2 - 1) * 0.6, -0.8).normalized(), "speed": 70.0, "lifetime": 0.3, "fade_out": 0.15})
			t.shake_t = 0.3
		"facade":
			# facade.spa: 노란 타격 별(이미터 색 248,248,56)과 흰 점들이 흩어진다.
			add_fx("sprite", t.position + up, {"text": "g4_facade_burst", "color": Color8(248, 248, 120, 240), "size": t.radius * 2.8, "grow": 1.6, "lifetime": 0.25, "follow": t, "offset": up})
			for k in 4:
				var a := TAU * float(k) / 4.0 + 0.6
				add_fx("sprite", t.position + up, {"text": "g4_facade_dots", "color": Color(1, 1, 1, 0.9), "size": t.radius * 1.2, "dir": Vector2.from_angle(a), "speed": 50.0, "lifetime": 0.3})
			t.shake_t = 0.3
		"doubleedge":
			# double_edge.spa: 타격 별 + 반짝이 별 다섯이 튄다. 화면이 흔들린다.
			add_fx("sprite", t.position + up, {"text": "g4_burst_q", "color": Color8(248, 152, 152, 240), "size": t.radius * 3.0, "grow": 1.6, "lifetime": 0.25})
			for k in 5:
				var a := TAU * float(k) / 5.0
				add_fx("sprite", t.position + up, {"text": "g4_star5", "color": Color8(248, 220, 80, 240), "size": t.radius * 0.9, "spin": 6.0,
					"dir": Vector2.from_angle(a), "speed": 60.0, "lifetime": 0.35})
			t.shake_t = 0.4

# 새 원거리기가 맞은 자리의 원작 연출.
func _hit_fx_new(t: Mon, style: String, dir: Vector2) -> void:
	var up := Vector2(0, -t.radius * 0.5)
	var body: Vector2 = t.position + up
	match style:
		"breath":
			# dragon_breath.spa: 자홍 숨결 뭉치가 맞은 몸에서 노랗게 바래며 피어오른다.
			for i in 3:
				add_fx("sprite", body + Vector2((i - 1) * t.radius * 0.6, 0), {"text": "g4_breath_b", "color": Color8(248, 88, 160, 230),
					"size": t.radius * 1.3, "grow": 1.6, "dir": Vector2.UP, "speed": 28.0, "lifetime": 0.32, "delay": 0.04 * i, "fade_out": 0.2})
			add_fx("sprite", body, {"text": "g4_breath_a", "color": Color8(248, 216, 128, 220), "size": t.radius * 1.6, "grow": 1.4, "lifetime": 0.2})
		"rock":
			# rock_throw.spa: 바위가 부서져 조각과 먼지가 튄다.
			add_fx("sprite", body, {"text": "g4_dust", "color": Color(0.85, 0.8, 0.7, 0.85), "size": t.radius * 1.8, "grow": 1.8, "lifetime": 0.3})
			for i in 3:
				var a := dir.angle() + PI + (i - 1) * 0.7
				add_fx("sprite", body, {"text": "g4_rock_chunk", "color": Color.WHITE, "size": t.radius * 0.7, "spin": randf_range(-10.0, 10.0),
					"dir": Vector2.from_angle(a), "speed": 70.0, "lifetime": 0.3, "fade_out": 0.15})
			t.shake_t = 0.2
		"leaf":
			# razor_leaf.spa: 흰 → 연두 초승달 베기.
			add_fx("sprite", body, {"text": "g4_vine_arc", "color": Color8(200, 248, 200, 240), "size": t.radius * 2.4, "rot": dir.angle() + PI, "grow": 1.3, "lifetime": 0.2, "follow": t, "offset": up})
		"bubble":
			# 거품이 터지며 물방울.
			for k in 4:
				add_fx("sprite", body + Vector2((k - 1.5) * t.radius * 0.5, 0), {"text": "g4_bubble_blue", "color": Color(1, 1, 1, 0.9), "size": t.radius * 0.8,
					"grow": 1.6, "lifetime": 0.25, "delay": 0.03 * k})
		"water":
			KantoMoveFx.water_hit(self,t,dir,false)
		"hydro":
			# hydro_pump.spa: 기존 하이드로펌프 물보라·소용돌이.
			add_fx("sprite", body, {"text": "g4_splash", "color": Color8(200, 248, 248, 230), "size": t.radius * 2.8, "grow": 1.6, "lifetime": 0.3})
			add_fx("sprite", body, {"text": "g4_droplets", "color": Color8(120, 200, 248, 240), "size": t.radius * 2.0, "grow": 1.8, "lifetime": 0.35})
			add_fx("sprite", body, {"text": "g4_vortex", "color": Color8(0, 248, 248, 200), "size": t.radius * 3.0, "spin": 10.0, "lifetime": 0.4, "follow": t, "offset": up})
		"pulse":
			KantoMoveFx.water_hit(self,t,dir,true)
			t.start_tint(Color8(104,152,248),0.4,0.3)
		"flash":
			# flash_cannon.spa: 빛이 번쩍이고 은빛 번개가 튄다.
			add_fx("sprite", body, {"text": "g4_flash_star", "color": Color(1, 1, 1, 0.95), "size": t.radius * 3.0, "grow": 1.4, "lifetime": 0.25})
			for k in 3:
				var a := TAU * float(k) / 3.0 + 0.4
				add_fx("sprite", body, {"text": "g4_steel_bolt", "color": Color8(248, 104, 248, 230), "size": t.radius * 1.2, "rot": a,
					"dir": Vector2.from_angle(a), "speed": 40.0, "lifetime": 0.25})
		"brine":
			# brine.spa: 물기둥이 솟고 물보라가 튄다(하늘 → 흰색).
			add_fx("sprite", body, {"text": "g4_water_drop", "color": Color8(128, 200, 248, 230), "size": t.radius * 3.0, "grow": 1.2, "lifetime": 0.3, "fade_out": 0.4})
			for k in 4:
				var a := TAU * float(k) / 4.0 + 0.4
				add_fx("sprite", body, {"text": "g4_brine_splash", "color": Color8(200, 208, 248, 230), "size": t.radius * 1.0, "grow": 1.6,
					"dir": Vector2.from_angle(a), "speed": 45.0, "lifetime": 0.3, "delay": 0.04 * k})
		"gigadrain":
			# giga_drain.spa: 초록 고리와 별 반짝임이 맞은 몸에서.
			add_fx("sprite", body, {"text": "g4_drain_ring", "color": Color8(128, 248, 168, 230), "size": t.radius * 1.6, "grow": 2.2, "lifetime": 0.3, "follow": t, "offset": up})
			for k in 3:
				var o := Vector2((k - 1) * t.radius * 0.7, -t.radius * 0.4 * (k % 2))
				add_fx("sprite", t.position + o, {"text": "g4_drain_star", "color": Color8(208, 248, 232, 240), "size": t.radius * 0.9, "grow": 1.3, "lifetime": 0.3, "delay": 0.05 * k})
			t.start_tint(Color8(96, 208, 136), 0.4, 0.3)
		"solar":
			add_fx("sprite", body, {"text": "g4_solar_glow", "color": Color8(248, 248, 120, 230), "size": t.radius * 2.6, "grow": 1.6, "lifetime": 0.3})
			t.start_tint(Color8(248, 248, 120), 0.5, 0.3)
		"petal":
			for k in 3:
				add_fx("sprite", body, {"text": ["g4_petal_a", "g4_petal_b", "g4_petal_c"][k], "color": Color.WHITE, "size": t.radius * 0.9,
					"dir": Vector2.from_angle(randf() * TAU), "speed": 40.0, "spin": 8.0, "lifetime": 0.3})
	t.shake_t = maxf(t.shake_t, 0.2)

# 새 근접기 연출(덩굴채찍·물기·고속스핀·아쿠아테일).
func _melee_fx_new(mon: Mon, t: Mon, style: String, dir: Vector2, up: Vector2) -> void:
	var body: Vector2 = t.position + up
	match style:
		"vine":
			# vine_whip.spa: 초록 채찍 자국(초승달) 둘이 엇갈려 그어진다.
			for k in 2:
				add_fx("sprite", body, {"text": "g4_vine_arc", "color": Color8(56, 224, 56, 255), "size": t.radius * 5.0,
					"rot": dir.angle() + (0.6 if k == 0 else -0.6) + PI, "grow": 1.2, "lifetime": 0.22, "delay": 0.1 * k, "follow": t, "offset": up})
			t.shake_t = 0.25
		"bugbite":
			# bug_bite.spa: 초록 물린 자국 둘이 양옆에서 닫히고(색 248,248,248 → 16,248,0) 타격 터짐.
			for sd in [-1.0, 1.0]:
				add_fx("sprite", body + Vector2(sd * t.radius * 1.1, 0), {"text": "g4_bugbite_mark", "color": Color8(120, 248, 80, 240), "size": t.radius * 1.6,
					"rot": 0.0 if sd < 0 else PI, "dir": Vector2(-sd, 0), "speed": t.radius * 0.8 / 0.12, "lifetime": 0.28, "fade_out": 0.25, "follow": t, "offset": up + Vector2(sd * t.radius * 1.1, 0)})
			add_fx("sprite", body, {"text": "g4_hitburst", "color": Color8(200, 248, 160, 230), "size": t.radius * 1.8, "grow": 1.5, "lifetime": 0.18, "delay": 0.1})
			t.shake_t = 0.3
		"bulldoze":
			# 땅고르기(5세대, 플래티넘 파티클 조합): 맞은 발밑에서 흙먼지와 바위 조각(earthquake.spa)이 튀어 오른다.
			var feet: Vector2 = t.position + Vector2(0, t.radius * 0.6)
			add_fx("sprite", feet, {"text": "g4_dust", "color": Color(0.8, 0.72, 0.55, 0.9), "size": t.radius * 2.0, "grow": 1.8, "lifetime": 0.35})
			for i in 3:
				add_fx("sprite", feet, {"text": "g4_quake_rock", "color": Color.WHITE, "size": t.radius * 0.6, "spin": randf_range(-8.0, 8.0),
					"dir": Vector2((i - 1) * 0.6, -1.0).normalized(), "speed": 80.0, "lifetime": 0.35, "fade_out": 0.15, "delay": 0.03 * i})
			t.shake_t = 0.35
		"bite":
			# bite.spa: 아랫니·윗니가 위아래에서 닫힌다.
			add_fx("sprite", body + Vector2(0, t.radius * 0.9), {"text": "g4_jaw_low", "color": Color.WHITE, "size": t.radius * 2.6,
				"dir": Vector2.UP, "speed": t.radius * 0.9 / 0.12, "lifetime": 0.3, "fade_out": 0.3, "follow": t, "offset": up + Vector2(0, t.radius * 0.9)})
			add_fx("sprite", body - Vector2(0, t.radius * 0.9), {"text": "g4_jaw_up", "color": Color.WHITE, "size": t.radius * 2.6,
				"dir": Vector2.DOWN, "speed": t.radius * 0.9 / 0.12, "lifetime": 0.3, "fade_out": 0.3, "follow": t, "offset": up - Vector2(0, t.radius * 0.9)})
			add_fx("sprite", body, {"text": "g4_hitburst", "color": Color8(248, 240, 120, 230), "size": t.radius * 1.8, "grow": 1.5, "lifetime": 0.18, "delay": 0.12})
			t.shake_t = 0.3
		"spin":
			add_fx("sprite", body, {"text": "g4_ring_open", "color": Color8(216, 248, 248, 230), "size": t.radius * 2.4, "spin": 12.0, "lifetime": 0.25, "follow": t, "offset": up})
			t.shake_t = 0.2
		"brick":
			# brick_break.spa: 노란 타격 터짐(이미터 색 240,200,104)과 조각들이 튄다. 몸이 흔들린다.
			add_fx("sprite", body, {"text": "g4_hitburst", "color": Color8(248, 232, 160, 240), "size": t.radius * 2.6, "grow": 1.6, "lifetime": 0.22, "follow": t, "offset": up})
			for k in 4:
				var a := TAU * float(k) / 4.0 + 0.5
				add_fx("sprite", body, {"text": "g4_cube", "color": Color8(200, 248, 248, 230), "size": t.radius * 0.7, "spin": 9.0,
					"dir": Vector2.from_angle(a), "speed": 55.0, "lifetime": 0.3})
			t.shake_t = 0.35
		"dig":
			# dig.spa: 솟구친 자리의 흙먼지가 맞은 몸에도 튄다.
			_dig_dust(t.position + Vector2(0, t.feet_offset()), t.radius, 4)
			t.shake_t = 0.3
		"aquatail":
			# aqua_tail.spa: 물보라가 크게 튀고 파란 물결 자국.
			add_fx("sprite", body, {"text": "g4_ring_q", "color": Color8(120, 180, 248, 230), "size": t.radius * 2.8, "rot": dir.angle(), "grow": 1.4, "lifetime": 0.25})
			for k in 6:
				var a := TAU * float(k) / 6.0
				add_fx("sprite", body, {"text": "g4_splash", "color": Color8(208, 248, 248, 220), "size": t.radius * 1.0, "grow": 1.3,
					"dir": Vector2.from_angle(a), "speed": 50.0, "lifetime": 0.35})
			t.shake_t = 0.3

# 이로치 반짝임 — 플래티넘 res/battle/scripts/common_anims/shiny.s 그대로: 파티클 27번(status_effect.spa)의 이미터 0·1.
# 수치는 그 파일의 SPLResourceHeader 에서 읽었다(1 프레임 = 1/30초, 감속 = (airResistance + 384)/512 배/프레임).
#   이미터 0: 반지름 0.37 원 위에 7알을 고르게, 바깥으로 0.30/프레임(감속 44), 프레임마다 10° 돌며 퍼진다. 26프레임.
#             크기 0.21 → 1.64 → 0.86, 색 흰색 → (8,192,248) → (144,200,248), 투명도 1/31 → 31(0.22까지) → 0(0.75부터).
#             알마다 2프레임마다 작은 잔광(자식 입자: 6프레임, 크기 부모의 0.16 에서 0 으로, 흐려짐)을 남긴다.
#   이미터 1: 10프레임 뒤부터 24프레임 동안 3프레임마다 반지름 2.01 원 위 아무 데나 한 알(0.06/프레임, 감속 40). 15프레임.
#             크기 0.09 → 1.16 → 0.09(반짝), 색 흰색 → (104,224,248) → 흰색, 0.51 부터 흐려짐.
# 원작 단위 1 = SHINY_UNIT px. 4세대 전투 도트(80px)보다 PMD 도트가 작아서 그 비율로 줄였다.
const SHINY_UNIT := 8.0
func shiny_fx(mon: Mon) -> void:
	var u := SHINY_UNIT
	var off := Vector2(0, -mon.radius)
	var c := mon.position + off
	var rot_speed := -4630.0 / 65536.0 * TAU * Fx.SPL_FPS     # 알 자체 회전(minRotation~maxRotation 가운데)
	var swirl := 1828.0 / 65536.0 * TAU                       # spin 63708 = −1828 → 화면(y 아래)에선 시계 방향
	for i in 7:
		var a := TAU * float(i) / 7.0
		var f := add_fx("spark", c, {"pivot": c, "follow": mon, "offset": off, "ang": a, "rad0": 0.37 * u, "vel0": 0.30 * u, "drag": (44.0 + 384.0) / 512.0,
			"swirl": swirl, "lifetime": 26.0 / Fx.SPL_FPS, "size": 2.0 * 0.48 * u * 1.5, "spin": rot_speed,
			"scale3": Vector3(0.208, 1.636, 0.863), "alpha3": Vector3(1.0 / 31.0, 1.0, 0.0),
			"alpha_in": 57.0 / 255.0, "alpha_out": 192.0 / 255.0,
			"color": Color.WHITE, "color_mid": Color8(8, 192, 248), "color_end": Color8(144, 200, 248)})
		f.position = f.spark_pos(0.0)
		# 자식 잔광: 부모가 지나간 자리에 2프레임마다(속도 비율 0 이라 그 자리에 머문다).
		for k in range(0, 26, 2):
			var at := f.spark_pos(float(k))
			var ps := Fx._curve3(f.scale3, float(k) / 26.0, 0.5, 0.5)
			add_fx("spark", at, {"pivot": at, "follow": mon, "offset": at - mon.position, "delay": float(k) / Fx.SPL_FPS, "lifetime": float(k + 6) / Fx.SPL_FPS,
				"size": 2.0 * 0.48 * u * 1.5 * ps * (42.0 / 255.0), "scale3": Vector3(1.0, 0.5, 0.0),
				"alpha3": Vector3(1.0, 1.0, 0.0), "alpha_in": 0.0, "alpha_out": 0.0,
				"color": Color.WHITE, "color_mid": Color.WHITE, "color_end": Color.WHITE})
	for j in 8:
		var a := fx_rng.randf() * TAU
		var d := float(10 + j * 3)
		add_fx("spark", c, {"pivot": c, "follow": mon, "offset": off, "ang": a, "rad0": 2.01 * u, "vel0": 0.06 * u, "drag": (40.0 + 384.0) / 512.0,
			"delay": d / Fx.SPL_FPS, "lifetime": (d + 15.0) / Fx.SPL_FPS,
			"size": 2.0 * 0.40 * u * 1.5 * (1.0 - fx_rng.randf() * 49.0 / 255.0),
			"scale3": Vector3(0.089, 1.160, 0.089), "alpha3": Vector3(1.0, 1.0, 1.0 / 31.0),
			"alpha_in": 128.0 / 255.0, "alpha_out": 130.0 / 255.0,
			"color": Color.WHITE, "color_mid": Color8(104, 224, 248), "color_end": Color.WHITE})

func float_text(pos: Vector2, text: String, color: Color, size: int = 8) -> void:
	# Only damage/healing numbers remain over the body; all prose goes to dialogue.
	if not text.is_valid_int():
		status_message.emit(text)
		return
	add_fx("text", pos, {"text": text, "color": color, "font_size": size, "lifetime": 0.8})

func _cleanup() -> void:
	for list_name in ["projectiles", "zones", "fxs"]:
		var keep: Array = []
		for n in get(list_name):
			if n.dead:
				n.queue_free()
			else:
				keep.append(n)
		set(list_name, keep)
	var keep_e: Array = []
	for e in enemies:
		if e.dead and e.faint_t <= 0.0:
			e.queue_free()
		else:
			keep_e.append(e)
	enemies = keep_e

func _draw() -> void:
	# 배틀 울타리: 바닥에 점 고리(원작엔 없는 표시 — 못 나가는 범위를 알린다).
	if in_battle() and battle_radius > 0.0:
		var n := 72
		for k in n:
			draw_rect(Rect2((battle_center + Vector2.from_angle(TAU * float(k) / float(n)) * battle_radius).round() - Vector2(1, 1), Vector2(2, 2)),
				Color(1.0, 1.0, 1.0, 0.6))
func _dragon_rage_hit_custom(target: Mon) -> void:
	var offset := Vector2(0,-target.radius*0.5)
	add_fx("sprite",target.position+offset,{"text":"g4_hitburst","color":Color(0.7,0.95,1.0,0.95),
		"size":target.radius*1.7,"grow":1.7,"lifetime":0.18,"follow":target,"offset":offset})
	for i in 8:
		var direction := Vector2.from_angle(TAU*i/8.0)
		add_fx("sprite",target.position+offset,{"text":"g4_breath_a","color":Color(0.58,0.3,1.0,0.8),
			"size":target.radius*0.85,"grow":0.25,"dir":direction,"speed":48.0,"lifetime":0.34,
			"delay":0.015*(i%2),"fadeout":0.85})
	for i in 4:
		add_fx("sprite",target.position+offset,{"text":"g4_spark","color":Color(0.65,0.95,1.0,0.9),
			"size":target.radius*0.35,"grow":0.2,"dir":Vector2.from_angle(TAU*i/4.0+0.4),
			"speed":65.0,"lifetime":0.24,"fadeout":0.8})
	target.shake_t = 0.4

# Spectral eyes and teeth: small stare, sudden expansion, then fade.
# Purely visual: status cone, protection, rank limits and dialogue stay shared.
func _scary_face_custom(mon: Mon, forward: Vector2, reach: float) -> void:
	var face := Vector2(0,-mon.radius*3.3)
	add_fx("sprite",mon.position+face,{"text":"g4_glow","color":Color(0.08,0.025,0.14,0.26),
		"size":mon.radius*3.6,"grow":1.15,"lifetime":0.55,"fade_in":0.12,"fade_out":0.6,
		"follow":mon,"offset":face})
	# Low-opacity halo and local light peak with the final surprise, not the stare.
	add_fx("sprite",mon.position+face,{"text":"g4_glow","color":Color(0.55,0.3,1.0,0.16),
		"size":mon.radius*3.0,"grow":1.5,"delay":Fx.SCARE_DURATION*Fx.SCARE_SNAP_START,"lifetime":Fx.SCARE_DURATION,
		"fade_in":0.12,"fade_out":0.75,"follow":mon,"offset":face})
	add_fx("light",mon.position,{"color":Color(0.6,0.35,1.0,0.18),"size":mon.radius*3.0,
		"delay":Fx.SCARE_DURATION*Fx.SCARE_SNAP_START,"lifetime":Fx.SCARE_DURATION,"follow":mon})
	add_fx("anim",mon.position+face,{"text":"g4_scary_face","frames":4,"scare_snap":true,"color":Color.WHITE,
		"size":clampf(mon.radius,8.0,12.0)*4.0,"lifetime":Fx.SCARE_DURATION,
		"follow":mon,"offset":face})
	for lane in 5:
		var direction := forward.rotated(float(lane-2)*0.28)
		add_fx("sprite",mon.position+direction*mon.radius,{"text":"g4_glow","color":Color(0.12,0.04,0.2,0.14),
			"size":mon.radius*1.8,"grow":1.8,"dir":direction,"speed":reach/0.4,
			"delay":0.04,"lifetime":0.44,"fade_in":0.15,"fade_out":0.7})
