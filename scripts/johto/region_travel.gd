extends RefCounted

## Reversible map travel. Uses the existing mon carry/save transition.
const PATH := "res://assets/data/johto_travel.json"
var game: Node
var side := ""
static var _data := {}

static func data() -> Dictionary:
	if _data.is_empty(): _data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data

static func destination_for(from_side: String) -> Dictionary:
	var target: Dictionary=data().get("johto" if from_side=="kanto" else "kanto",{})
	var tile: Array=target.arrival
	return {"map":String(target.map),"pos":Arena.tile_center(Vector2i(int(tile[0]),int(tile[1]))),"region_arrival":true}

func setup(owner: Node) -> void:
	game=owner
	for key in ["kanto","johto"]:
		var cfg: Dictionary=data()[key]
		if DungeonDB.current != cfg.map: continue
		side=key
		var npc := Npc.new()
		npc.setup({"id":"johto_ferry","sprite":"sailor","talk":"johto_ferry","tile":Vector2i(cfg.npc[0],cfg.npc[1]),"talk_tile":Vector2i(cfg.talk[0],cfg.talk[1])})
		game.world.add_child(npc)
		game.world.npcs.append(npc)

func talk(npc: Npc) -> void:
	npc.face_toward(game.world.player.position)
	var line := ("성도의 담청항으로 가는 배야. 타고 갈래?" if side=="kanto" else "관동의 갈색항으로 돌아가는 배야. 타고 갈래?") if Lang.is_ko() else ("Sail to Olivine in Johto?" if side=="kanto" else "Sail back to Vermilion in Kanto?")
	game._say_pages(game._pages([line],npc),open_menu)

func open_menu() -> void:
	game._menu_open("johto_ferry")
	var title := ("성도행 연락선" if side=="kanto" else "관동행 연락선") if Lang.is_ko() else ("Ferry to Johto" if side=="kanto" else "Ferry to Kanto")
	game.panel.show_items(title,[
		{"name":"배를 탄다" if Lang.is_ko() else "Board","sub":"무료" if Lang.is_ko() else "Free"},
		{"name":Lang.t("bag_close"),"sub":"Esc"}],2,1)

func choose(index: int) -> void:
	game._close_menu()
	if index != 0: return
	game.state="warp"
	game.world.player.vel=Vector2.ZERO
	game._carry_out()
	game.get_script().destination=destination_for(side)
	if not game.bot: SaveData.store(game.world.player,game.cleared)
	var tween := game.create_tween()
	tween.tween_property(game.fader,"color:a",1.0,0.25)
	tween.tween_callback(func():game.get_tree().reload_current_scene())
