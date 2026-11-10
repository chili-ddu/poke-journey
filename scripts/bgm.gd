class_name Bgm
extends Node

# 배경 음악(사용자 결정 2026-10-29): 장소 곡은 파이어레드(tools/frlg_music.py), 시스템·배틀·팡파르는 플래티넘(tools/plat_music.py).
# 장면을 다시 불러도(문·경기장 왕복) 끊기지 않게 SceneTree 루트에 노드 하나를 두고 정적 함수로 다룬다.
#   play(곡)      배경 곡. 같은 곡이면 그대로 이어서, 다른 곡이면 바꾼다(fade 면 잠깐 줄였다가 — 원작 장소 바뀜처럼).
#   fanfare(곡)   짧은 곡을 한 번. 그동안 배경 곡은 멈췄다가 끝나면 멈춘 자리부터 다시(원작처럼 잠깐 끊고 울림).
#                 팡파르 도중에 play 로 곡이 바뀌면 새 곡은 팡파르가 끝난 뒤 시작한다.
# 곡 이름은 assets/audio/<이름>.wav. 루프는 WAV 의 smpl 구간(도구가 적음)을 Godot 가 읽는다.

const DIR := "res://assets/audio/"
const VOLUME_DB := -6.0
const BATTLE_VOLUME_DB := -9.0 # Leave room for skills and impacts during real-time battles.
const FADE := 0.5
# 장소 → 파이어레드 곡(pret/pokefirered 지도 map.json 의 music). 관동 남부는 구역(areas) 단위.
const PLACE := {
	"arena_lapras_escape":"mus_fuchsia",
	"vermilion_harbor":"mus_vermillion", "ssanne_exterior":"mus_vermillion",
	"pallet_town": "mus_pallet", "players_house_1f": "mus_pallet", "players_house_2f": "mus_pallet", "rivals_house": "mus_pallet",
	"oaks_lab": "mus_oak_lab",
	"route1": "mus_route1", "route2": "mus_route1",
	"viridian_city": "mus_pewter", "pewter_city": "mus_pewter", "forest_gate_south": "mus_pewter", "forest_gate_north": "mus_pewter",
	"pewter_museum_1f": "mus_pewter", "pewter_museum_2f": "mus_pewter", "pewter_house1": "mus_pewter", "pewter_house2": "mus_pewter",
	"viridian_center": "mus_poke_center", "viridian_mart": "mus_poke_center", "pewter_center": "mus_poke_center", "pewter_mart": "mus_poke_center",
	"viridian_forest": "mus_viridian_forest",
	"pewter_gym": "mus_gym",
	"route25_sea_cottage":"mus_fuchsia",
	"cerulean_north":"mus_route24", "route24":"mus_route24", "route25":"mus_route24",
}
const TITLE := "seq_title01"
const HEAL := "seq_asa"
const ITEM := "seq_fanfa4"      # 도구를 받을 때(원작 scripts_common.s: 도구 주머니 물건)
const TM := "seq_waza"          # 기술머신을 받을 때(원작 scripts_common.s: 기술머신 주머니)
const LEVEL_UP := "seq_fanfa1"
const EVOLVING := "seq_shinka"
const EVOLVED := "seq_fanfa5"
const BADGE := "seq_badge"

static var _inst: Bgm = null

var main: AudioStreamPlayer
var jingle: AudioStreamPlayer
var current := ""
var held := false                 # 팡파르가 배경 곡을 붙잡고 있나(재생 중이 아니면 stream_paused 는 늘 false 로 읽혀서 따로 센다)
var _tween: Tween = null
# 헤드리스(시험 도구)는 곡을 고르고 멈춤 상태만 바꾸고 실제로 틀지 않는다 — 끝날 때 재생 중인 곡이 '사용 중인 리소스'로 남는다.
var _silent := DisplayServer.get_name() == "headless"

static func play(song: String, fade := false) -> void:
	_node()._play(song, fade)

static func fanfare(song: String) -> void:
	_node()._fanfare(song)

static func stop(fade := true) -> void:
	_node()._play("", fade)

static func now() -> String:
	return _node().current

static func length(song: String) -> float:
	var path := DIR + song + ".wav"
	return (load(path) as AudioStream).get_length() if ResourceLoader.exists(path) else 0.0

static func place(id: String) -> String:
	return String(PLACE.get(id, DungeonDB.KantoWorld.MUSIC.get(id,DungeonDB.DiglettRoute.MUSIC.get(id,DungeonDB.Saffron.MUSIC.get(id,DungeonDB.RockPass.MUSIC.get(id,DungeonDB.Expansion.MUSIC.get(id, "")))))))

static func _node() -> Bgm:
	if not is_instance_valid(_inst):
		_inst = Bgm.new()
		_inst.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst

func _init() -> void:
	main = AudioStreamPlayer.new()
	main.volume_db = VOLUME_DB
	add_child(main)
	jingle = AudioStreamPlayer.new()
	jingle.volume_db = VOLUME_DB
	add_child(jingle)
	jingle.finished.connect(_on_jingle_done)

# 트리에 들어오기 전에 부른 것(첫 장면의 _ready)은 들어온 뒤에 소리 낸다.
func _ready() -> void:
	if current != "":
		_start(current)
	if jingle.stream != null:
		_fanfare_start()

func _play(song: String, fade: bool) -> void:
	if song == current:
		return
	current = song
	if _tween != null:
		_tween.kill()
		_tween = null
	if not is_inside_tree():
		return
	if fade and main.playing and not held and not _silent:
		_tween = create_tween()
		_tween.tween_property(main, "volume_db", -40.0, FADE)
		_tween.tween_callback(_start.bind(song))
	else:
		_start(song)

func _start(song: String) -> void:
	main.volume_db = BATTLE_VOLUME_DB if song.begins_with("seq_ba_") else VOLUME_DB
	var path := DIR + song + ".wav"
	if song == "" or not ResourceLoader.exists(path):
		main.stop()
		main.stream = null
		return
	main.stream = load(path)
	if not _silent:
		main.play()
	main.stream_paused = held

func _fanfare(song: String) -> void:
	var path := DIR + song + ".wav"
	if not ResourceLoader.exists(path):
		return
	jingle.stream = load(path)
	if is_inside_tree():
		_fanfare_start()

func _fanfare_start() -> void:
	held = true
	main.stream_paused = true
	if _silent:
		_on_jingle_done.call_deferred()       # 헤드리스: 바로 끝난 것으로
	else:
		jingle.play()

func _on_jingle_done() -> void:
	jingle.stream = null
	held = false
	main.stream_paused = false
