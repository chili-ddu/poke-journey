class_name BerryLoot
extends RefCounted

# Extra berries are independent of original held-item drops.
const COMMON_CHANCE := 0.25
const CURE_CHANCE := 0.20
const COMMON := [["oran_berry",70],["leppa_berry",20],["sitrus_berry",10]]
const CURES := {"poison":"pecha_berry","paralyze":"cheri_berry","sleep":"chesto_berry","burn":"rawst_berry","confuse":"persim_berry"}

static func status_berries(moves: Array) -> Array:
	var result: Array=[]
	for mid in moves:
		if not MoveDB.has_move(String(mid)): continue
		var move := MoveDB.get_move(String(mid))
		for effect in CURES:
			if float(move.get(effect,0.0))>0.0 and not result.has(CURES[effect]): result.append(CURES[effect])
	return result

static func roll(species: String,level: int,rng: RandomNumberGenerator,moves: Array=[]) -> Array:
	var out: Array=[]
	if rng.randf()<COMMON_CHANCE:
		var pick := rng.randi_range(1,100)
		for entry in COMMON:
			pick-=int(entry[1])
			if pick<=0:
				out.append(entry[0]);break
	var cures := status_berries(moves if not moves.is_empty() else SpeciesDB.enemy_moves(species,level))
	if not cures.is_empty() and rng.randf()<CURE_CHANCE: out.append(cures[rng.randi_range(0,cures.size()-1)])
	return out
