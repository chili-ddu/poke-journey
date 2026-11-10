extends RefCounted

# The collection/research trainer battle has been replaced by bill_rescue in
# regional_quests.gd. Retain this house/PC adapter for old maps and save records.
const PLACE := "route25_sea_cottage"
var game: Node
var actor: Npc = null
var computer: Npc
var phase := "idle"

func setup(owner: Node) -> void:
	game = owner
	computer = Npc.new()
	computer.setup({"id":"bill_pc", "sprite":"bill", "talk":"bill_pc",
		"tile":Vector2i(4,5), "talk_tile":Vector2i(4,6)})
	computer.visible = false
	computer.set_meta("roaming_trainer", true)
	game.world.add_child(computer)
	game.world.npcs.append(computer)

func talk(_npc: Npc) -> void:
	game._say_pages(["이수재의 컴퓨터에는 포켓몬의 진화와 성장에 관한 연구자료가 정리되어 있다." if Lang.is_ko() else "BILL's computer contains research on POKéMON evolution and growth."])

func arrive() -> void:
	# No automatic approach, capture attempt, ticket, or trainer challenge.
	pass

func step(_dt: float) -> void:
	pass
