class_name Sfx
extends Node

# 효과음·울음소리(사용자 요청 2026-10-30): 플래티넘 SDAT 에서 뽑은 assets/audio/se/<이름>.wav 와 assets/audio/cry/<종족>.wav(tools/plat_sfx.py).
# Bgm 처럼 트리 뿌리에 하나 붙어 있고 정적 함수로 부른다. 재생기 몇 개를 돌려 쓰고, 헤드리스에선 소리를 내지 않는다.
# 이름: select(커서·글 넘김·취소) decide(결정) pinpon("!") door dansa(언덕) save regi(상점) pc_login(시작 화면) kouka_h/m/l(효과) bowa(볼 열림)
#       mv_<기술 id>(기술을 쓸 때 — 원작 연출 스크립트의 첫 SE)

const SE_DIR := "res://assets/audio/se/"
const CRY_DIR := "res://assets/audio/cry/"
const POOL := 8
const VOLUME_DB := -6.0
const CRY_DB := -3.0
# Source flame RMS is roughly 5 dB above ember/impact; trim without changing timing.
const MOVE_GAIN_DB := {"flamethrower": -5.0}

static var _inst: Sfx = null
static var _silent := false
signal sound_requested(path: String, pitch: float, db: float, max_duration: float)

var _players: Array = []
var _pan_buses: Dictionary = {}
var _panners: Dictionary = {}
const COALESCE_WINDOW := 0.04
var _next := 0
var _clock := 0.0
var _sequence := 0
signal sound_resolved(path: String, action: String, slot: int)

static func play(name: String, pitch: float = 1.0, db: float = 0.0, pan: float = 0.0, owner_id: int = 0) -> void:
	_node()._play(SE_DIR + name + ".wav", pitch, VOLUME_DB + db, -1.0, db, pan, owner_id)

# 기술을 쓸 때의 원작 SE(없는 기술은 조용히 넘어간다).
static func move(move_id: String, max_duration: float = -1.0, db: float = 0.0, pan: float = 0.0, owner_id: int = 0) -> void:
	_node()._play(SE_DIR+"mv_"+move_id+".wav",1.0,VOLUME_DB+float(MOVE_GAIN_DB.get(move_id,0.0))+db,max_duration,db,pan,owner_id)

# 울음소리. pitch < 1 이면 낮고 느리게(쓰러질 때 — 원작도 낮춰 튼다).
static func cry(species_id: String, pitch: float = 1.0, db: float = 0.0, pan: float = 0.0, owner_id: int = 0) -> void:
	_node()._play(CRY_DIR + species_id + ".wav", pitch, CRY_DB + db, -1.0, db, pan, owner_id)

# Do not create a persistent audio node just to clean up an already removed world.
static func stop_owner(owner_id: int) -> void:
	if owner_id==0 or not is_instance_valid(_inst): return
	_inst._stop_owner(owner_id)

func _stop_owner(owner_id: int) -> void:
	if owner_id==0: return
	for p in _players:
		if int(p.get_meta("owner_id",0))!=owner_id: continue
		p.stop()
		p.stream = null
		p.bus = &"Master"
		p.set_meta("remaining",-1.0)
		p.set_meta("owner_id",0)
		p.set_meta("pan",0.0)

static func has(name: String) -> bool:
	return ResourceLoader.exists(SE_DIR + name + ".wav")

static func _node() -> Sfx:
	if not is_instance_valid(_inst):
		_inst = Sfx.new()
		_inst.process_mode = Node.PROCESS_MODE_ALWAYS
		_silent = DisplayServer.get_name() == "headless"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst

func _init() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _play(path: String, pitch: float, db: float, max_duration: float = -1.0, distance_db: float = 0.0, pan: float = 0.0, owner_id: int = 0) -> void:
	if db <= -80.0 or not ResourceLoader.exists(path): return
	sound_requested.emit(path,pitch,db,max_duration)
	if _silent or not is_inside_tree():
		return
	pan = clampf(pan,-0.65,0.65)
	var priority := _priority(path)
	# Simultaneous identical battle sounds share one voice. Different pitch/volume stays distinct.
	if priority<3:
		for i in _players.size():
			var voice: AudioStreamPlayer = _players[i]
			if voice.playing and int(voice.get_meta("owner_id",0))==owner_id and voice.get_meta("path","")==path and _clock-float(voice.get_meta("started",-1.0))<COALESCE_WINDOW and is_equal_approx(voice.pitch_scale,pitch) and is_equal_approx(float(voice.get_meta("base_db",0.0)),db) and is_equal_approx(float(voice.get_meta("pan",0.0)),pan):
				sound_resolved.emit(path,"coalesced",i)
				return
	var slot := _select_voice(priority, distance_db)
	if slot<0:
		sound_resolved.emit(path,"dropped",-1)
		return
	var p: AudioStreamPlayer = _players[slot]
	sound_resolved.emit(path,"replaced" if p.playing else "started",slot)
	_next = (slot+1)%POOL
	_sequence += 1
	p.set_meta("owner_id",owner_id)
	p.set_meta("path",path)
	p.set_meta("priority",priority)
	p.set_meta("distance_db",distance_db)
	p.set_meta("started",_clock)
	p.set_meta("sequence",_sequence)
	p.stop()
	_set_pan(slot,pan)
	p.set_meta("pan",pan)
	p.stream = load(path)
	p.pitch_scale = pitch
	p.volume_db = db
	p.set_meta("remaining",max_duration)
	p.set_meta("base_db",db)
	p.play()

# One reusable panner per occupied slot; all routes still pass through Master protection.
func _set_pan(slot: int, pan: float) -> void:
	var p: AudioStreamPlayer = _players[slot]
	if is_zero_approx(pan):
		p.bus = &"Master"
		return
	if not _pan_buses.has(slot):
		var name := StringName("Sfx_%s_%s" % [get_instance_id(),slot])
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,name)
		AudioServer.set_bus_send(index,&"Master")
		var effect := AudioEffectPanner.new()
		AudioServer.add_bus_effect(index,effect)
		_pan_buses[slot] = name
		_panners[slot] = effect
	_panners[slot].pan = pan
	p.bus = _pan_buses[slot]

func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.bus = &"Master"
	for name in _pan_buses.values():
		var index := AudioServer.get_bus_index(name)
		if index>0: AudioServer.remove_bus(index)
	_pan_buses.clear()
	_panners.clear()

# Reusing a voice replaces its deadline, so an older skill cannot stop a newer sound.
func _process(dt: float) -> void:
	_clock += dt
	for player in _players:
		if not player.playing:
			player.stream = null
			player.set_meta("remaining",-1.0)
			continue
		var remaining: float = player.get_meta("remaining",-1.0)
		if remaining<0.0: continue
		remaining = maxf(0.0,remaining-dt)
		if remaining<=0.0:
			player.stop()
			player.stream = null
			player.set_meta("remaining",-1.0)
		else:
			player.set_meta("remaining",remaining)
			player.volume_db = float(player.get_meta("base_db",VOLUME_DB))+linear_to_db(minf(1.0,remaining/0.08))

# UI/world interaction > species cry > impact > move bed. No extra voices are allocated.
static func _priority(path: String) -> int:
	if path.begins_with(CRY_DIR): return 2
	var name := path.get_file().get_basename()
	if name.begins_with("kouka_"): return 1
	if name.begins_with("mv_"): return 0
	return 3

# Distance gain stays separate from source balancing and the end-of-sound fade.
# Higher importance still wins; within a battle class, farther voices yield first.
func _select_voice(priority: int, distance_db: float = 0.0) -> int:
	for n in POOL:
		var i := (_next+n)%POOL
		if not _players[i].playing: return i
	var candidate := -1
	for i in POOL:
		var p: AudioStreamPlayer = _players[i]
		var current: int = p.get_meta("priority",0)
		var proximity: float = p.get_meta("distance_db",0.0)
		if current>priority: continue
		if current==priority and priority<3 and proximity>distance_db+0.001: continue
		if candidate<0:
			candidate = i
			continue
		var chosen: AudioStreamPlayer = _players[candidate]
		var chosen_priority: int = chosen.get_meta("priority",0)
		var chosen_proximity: float = chosen.get_meta("distance_db",0.0)
		if current<chosen_priority:
			candidate = i
		elif current==chosen_priority:
			if current<3 and proximity<chosen_proximity-0.001:
				candidate = i
			elif (current==3 or absf(proximity-chosen_proximity)<=0.001) and int(p.get_meta("sequence",0))<int(chosen.get_meta("sequence",0)):
				candidate = i
	return candidate
