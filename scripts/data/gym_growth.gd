extends RefCounted

const Data=preload("res://scripts/data/gym_growth_data.gd")

static func supported(move: String) -> bool:
	return MoveDB.has_move(move) and not String(MoveDB.get_move(move).get("shape", "")).is_empty()

static func lineage(id: String,index: int,level: int) -> Array:
	var cfg: Dictionary=Data.LEADERS[id]
	var family: Array=cfg.families[cfg.slots[index]]
	return family.filter(func(stage):return int(stage.level)<=level)

static func moves_for(line: Array,level: int,authored: Array,team_moves: Array) -> Array:
	var learned: Dictionary={}
	for stage in line:
		for pair in SpeciesDB.learnset(stage.species):
			var move:=String(pair[1]);var at:=int(pair[0])
			if at<=level and supported(move):learned[move]=maxi(at,int(learned.get(move,0)))
	var known: Array=learned.keys()
	known.sort_custom(func(a,b):return int(learned[a])<int(learned[b]))
	var result: Array=known.slice(maxi(0,known.size()-4))
	# Retain one legal, authored attack TM as the leader's signature.
	var signature:=""
	for move in authored:
		if not supported(move) or MoveDB.power(move)<=0.0:continue
		var value=MoveDB.get_move(move).get("tm", "")
		var tm:=str(value) if value!=null else ""
		if tm=="":continue
		if line.any(func(stage):return tm in SpeciesDB.get_species(stage.species).tms):signature=move
	if signature!="" and not result.has(signature):
		if result.size()>=4:result.pop_front()
		result.append(signature)
	if not result.any(func(move):return MoveDB.power(move)>0.0):
		for move in known:
			if MoveDB.power(move)<=0.0:continue
			if result.size()>=4:result.pop_front()
			result.append(move);break
	# Abra has only Teleport before Lv16. The leader can teach a legal team TM.
	if not result.any(func(move):return MoveDB.power(move)>0.0):
		for move in team_moves:
			if not supported(move) or MoveDB.power(move)<=0.0:continue
			var value=MoveDB.get_move(move).get("tm", "")
			var tm:=str(value) if value!=null else ""
			if tm=="" or not line.any(func(stage):return tm in SpeciesDB.get_species(stage.species).tms):continue
			if result.size()>=4:result.pop_front()
			result.append(move);break
	return result

static func configure(id: String,source: Dictionary,player_level: int) -> Dictionary:
	var result: Dictionary=source.duplicate(true)
	if not Data.LEADERS.has(id):return result
	var lowest:=100;var highest:=1
	for row in source.party:
		lowest=mini(lowest,int(row[1]));highest=maxi(highest,int(row[1]))
	var party: Array=[]
	var team_moves: Array=[]
	for row in source.party:
		if row.size()>2:team_moves.append_array(row[2])
	for i in source.party.size():
		var row: Array=source.party[i]
		var rank:=float(int(row[1])-lowest)/float(maxi(1,highest-lowest))
		var bonus:=Data.LEVEL_BONUS.x+roundi(rank*(Data.LEVEL_BONUS.y-Data.LEVEL_BONUS.x))
		var level:=clampi(player_level+bonus,1,Data.MAX_LEVEL)
		var line:=lineage(id,i,level)
		var species:=String(line.back().species)
		party.append([species,level,moves_for(line,level,row[2] if row.size()>2 else [],team_moves)])
	result.party=party;result["reference_level"]=player_level
	return result
