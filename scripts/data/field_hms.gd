extends RefCounted

# Field progress grants knowledge, not a compulsory combat-slot assignment.
# Flash is TM70 in the Platinum learnability data used by this game.
const MACHINES={"cut":"HM01","fly":"HM02","surf":"HM03","strength":"HM04","flash":"TM70","rock_smash":"HM06","waterfall":"HM07"}
const SOURCES={"cut":"friend_scyther_cut","fly":"friend_bird_fly","surf":"friend_lapras_surf","flash":"friend_pikachu_flash"}

static func compatible(species: String,move: String) -> bool:
	return MACHINES.has(move) and SpeciesDB.has_species(species) and MACHINES[move] in SpeciesDB.get_species(species).get("tms",[])

static func can_use(player: Player,move: String) -> bool:
	return compatible(player.species_id,move) and move in player.known_moves()

static func pending(player: Player,events: Array) -> Array:
	var result: Array=[]
	for move in SOURCES:
		if events.has(SOURCES[move]) and compatible(player.species_id,move) and not player.known_moves().has(move):result.append(move)
	return result

static func sync(player: Player,events: Array) -> Array:
	var added:=pending(player,events)
	for move in added:player.add_learned(move)
	return added

static func pages(player: Player,moves: Array) -> Array:
	var result: Array=[]
	for move in moves:result.append(Lang.t("learned",[player.display_name(),MoveDB.move_name(move)]))
	return result
