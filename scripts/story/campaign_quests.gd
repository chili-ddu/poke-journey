extends RefCounted

# Location objectives are independent investigations; their evidence is combined by
# CampaignDirector, without closing towns or making a prescribed route.
static func quests() -> Array:
	var result: Array = [
		{"id":"moon_mining","hide_on_complete":true,"name":"달맞이산의 수상한 채굴","kind":"main","reward":{"sitrus_berry":2,"leppa_berry":2},"xp_levels":0.5,"stages":[
			{"area":"cerulean_city","tile":Vector2i(30,22),"sprite":"gym_guy","objective":"체육관 안내인에게 이슬의 행방을 묻기","intro":["이슬 관장은 달맞이산에 갔어.\n밤마다 광석을 나르는 사람들이 있다더군.","첫 통과 때 해결할 필요는 없어.\n도와주려면 달맞이산 지하를 살펴봐 줘."]},
			{"map":"mt_moon_b2f","tile":Vector2i(17,10),"sprite":"misty","objective":"이슬과 함께 불법 채굴을 저지하기","intro":["이슬: 광석을 무단으로 캐고 있어!\n뒤쪽의 알과 야생 포켓몬도 위험해.","로켓단: 화물은 이미 일부 보냈다!\n이 광석의 용도는 알 필요 없어!"],"battle":[{"species":"zubat","offset":0,"min":10,"max":28},{"species":"raticate","offset":2,"min":12,"max":30}],"outro":["이슬: 채굴은 멈췄어. 고마워!\n나는 블루시티 체육관으로 돌아갈게.","수신지를 지운 운송 기록을 찾았다.\n화물에는 보랏빛 원 모양 표식이 있다.","다른 운송 기록을 찾으면\n광석이 향한 곳을 알아낼 수 있겠다."]}
		]},
		{"id":"silph_theft","discover_requires":["bill_silph_research_tip"],"name":"도난당한 포획 장치 기술","kind":"main","reward":{"sitrus_berry":2,"leppa_berry":2},"xp_levels":0.5,"stages":[
			{"map":"silph_co_1f","tile":Vector2i(10,15),"sprite":"scientist","objective":"실프주식회사의 도난 사건 조사하기","intro":["연구원: 포획 장치의 제어 설계가\n사라졌어. 운송장을 빼앗아 갔어!", "로켓단: 그 자료에서 떨어져라!"],"battle":[{"species":"grimer","offset":1,"min":15,"max":38},{"species":"golbat","offset":2,"min":17,"max":40}],"outro":["연구원: 운송장을 되찾았구나!\n목적지는 무지개시티 게임코너야.","광석 화물과 같은 보랏빛 원 표식이다.\n포획 장치의 기술도 그곳으로 흘러갔다."]}
		]},
		{"id":"hideout","discover_requires":["quest_silph_theft_complete"],"hide_on_complete":true,"name":"게임코너 아래의 제작실","kind":"main","reward":{"sitrus_berry":3,"leppa_berry":2},"xp_levels":0.75,"stages":[
			{"map":"rocket_hideout_b4f","tile":Vector2i(6,5),"sprite":"rocket_m","objective":"게임코너 지하에서 제작 계획 확보하기","intro":["로켓단: 여기는 네가 올 곳이 아니다!\n제작 기록은 넘길 수 없어!"],"battle":[{"species":"arbok","offset":1,"min":20,"max":48},{"species":"weezing","offset":3,"min":22,"max":50}],"outro":["제작 기록: 실프의 제어 설계와\n달맞이산 광석을 결합한다.","어떤 포켓몬도 놓치지 않는\n마스터볼의 시제품을 제작 중이다.","포획 대상은 암호명 M2.\n출처는 홍련의 연구 기록으로 보인다."]}
		]},
		{"id":"cinnabar_records","discover_requires":["rumor_cinnabar_research"],"name":"홍련에 남겨진 연구 기록","kind":"main","reward":{"sitrus_berry":3,"leppa_berry":2},"xp_levels":0.5,"stages":[
			{"map":"pokemon_mansion_b1f","tile":Vector2i(22,18),"sprite":"scientist","objective":"포켓몬저택 지하의 연구 기록 읽기","intro":["남겨진 연구 일지:\n뮤의 유전자를 연구해 뮤츠가 태어났다.","뮤츠는 연구 시설을 떠났다.\n그 힘은 우리가 감당할 수 없었다.","후속 목격 기록:\n블루시티 근처 깊은 동굴을 조사할 것."],"outro":["암호명 M2와 연구 기록을 연결할\n단서를 확보했다. 기록을 간직하자."]}
		]},
		{"id":"mysterious_bird_clue","auto_record":true,"name":"신비로운 새를 찾아서 · 첫 단서","requires":["campaign_hooh_sighted"],"reward":{"oran_berry":2},"stages":[
			{"area":"route1","tile":Vector2i(10,13),"species":"pidgey","objective":"1번도로 구구에게 방금 본 새에 대해 묻기","intro":["구구: 방금 무지갯빛으로 빛나는\n아주 큰 새가 지나갔어!", "같은 새를 보았다는 말을 찾으면\n그 새가 어디로 갔는지 알 수 있겠지?"],"outro":["첫 단서를 기록했다!\n메뉴의 이야기 기록에서 목표를 확인하자.","신비로운 새의 추적은 계속된다.\n다른 전설의 새에 관한 정보도 모아 보자."]}
		]},
		{"id":"articuno_trail","name":"신비로운 새를 찾아서 · 차가운 날개","requires":["campaign_hooh_sighted","visited_area_saffron_city"],"reward":{"sitrus_berry":4,"leppa_berry":3},"xp_levels":1.0,"stages":[
			{"map":"route15_west_entrance_2f","tile":Vector2i(5,4),"sprite":"youngster","objective":"15번도로 관문 망원경의 목격담 듣기","intro":["망원경으로 바다 쪽을 봤어.\n크고 빛나는 새가 남쪽으로 날았어.","차가운 바람까지 불었다더군.\n쌍둥이섬 해안을 조사해 보는 건 어때?"]},
			{"map":"seafoam_islands_1f","tile":Vector2i(8,5),"sprite":"swimmer_m_land","objective":"쌍둥이섬 해안의 차가운 바람 조사하기","intro":["물살이 거세지면 얼음 같은 울음이 들려.\n바위를 내려 물살을 막으면 깊이 갈 수 있어.","네가 처음 본 무지갯빛 새와는\n다른 전설의 새일지도 몰라."]},
			{"map":"seafoam_islands_b4f","tile":Vector2i(16,17),"species":"articuno","objective":"쌍둥이섬 깊은 곳의 프리져와 승부하기","intro":["차가운 날개가 조용히 펼쳐진다.\n프리져가 너의 도전을 받아들였다!"],"battle":[{"species":"articuno","offset":4,"min":35,"max":65}],"outro":["프리져는 고개를 숙여 실력을 인정했다.\n차가운 깃털의 기억을 기록했다.","1번도로에서 본 새는 이 새와 달랐다.\n신비로운 새의 추적은 계속된다."]}
		]},
		{"id":"zapdos_trail","name":"신비로운 새를 찾아서 · 우레의 울음","requires":["campaign_hooh_sighted","visited_area_saffron_city"],"reward":{"sitrus_berry":4,"leppa_berry":3},"xp_levels":1.0,"stages":[
			{"area":"route17","tile":Vector2i(7,20),"sprite":"biker","objective":"17번도로에서 폐발전소 소문 듣기","intro":["찌리리공을 찾으러 폐발전소에 갔지.\n그런데 지붕 너머에 큰 날개가 보였어.","10번도로에서 이상한 방전을\n봤다는 사람도 있더군."]},
			{"area":"route10","tile":Vector2i(10,9),"sprite":"scientist","objective":"10번도로의 비정상 방전 조사하기","intro":["번개가 치지 않았는데 기계가 반응했어!\n폐발전소에서 우레 같은 울음도 들렸어."]},
			{"map":"power_plant","tile":Vector2i(8,5),"species":"zapdos","objective":"폐발전소의 썬더와 승부하기","intro":["발전소의 공기를 가르는 전기!\n썬더가 너의 도전을 받아들였다!"],"battle":[{"species":"zapdos","offset":4,"min":35,"max":65}],"outro":["썬더는 날개를 접어 실력을 인정했다.\n우레 같은 울음의 기억을 기록했다.","1번도로의 무지갯빛 새와는 달랐다.\n신비로운 새의 추적은 계속된다."]}
		]},
		{"id":"moltres_trail","name":"신비로운 새를 찾아서 · 불탄 깃털","requires":["campaign_hooh_sighted","visited_area_saffron_city"],"reward":{"sitrus_berry":4,"leppa_berry":3},"xp_levels":1.0,"stages":[
			{"map":"cinnabar_island_pokemon_lab_research_room","tile":Vector2i(4,5),"sprite":"scientist","objective":"홍련 연구실에서 전설의 새 기록 읽기","intro":["기록에는 프리져·썬더·파이어라는\n세 전설의 새가 등장해.","챔피언로드에서 불타는 깃털을\n보았다는 최근 목격담도 있어."]},
			{"map":"victory_road_1f","tile":Vector2i(15,12),"sprite":"cooltrainer_m","objective":"챔피언로드에서 불탄 깃털 조사하기","intro":["깃털이 떨어지자 바위가 따뜻해졌어.\n큰 새는 위층으로 날아갔지."]},
			{"map":"victory_road_2f","tile":Vector2i(27,10),"species":"moltres","objective":"챔피언로드의 파이어와 승부하기","intro":["불꽃 같은 날개가 바위를 비춘다.\n파이어가 너의 도전을 받아들였다!"],"battle":[{"species":"moltres","offset":4,"min":35,"max":65}],"outro":["파이어는 열기를 거두어 실력을 인정했다.\n불타는 날개의 기억을 기록했다.","하지만 1번도로에서 본 새는 아니었다.\n신비로운 새의 추적은 계속된다."]}
		]},
		{"id":"mewtwo_final","name":"아버지의 꿈, 나의 승부","kind":"main","requires":["campaign_cycle_2","campaign_father_rescued"],"stages":[
			{"map":"cerulean_cave_b1f","tile":Vector2i(24,16),"species":"mewtwo","objective":"블루시티 동굴 깊은 곳에서 뮤츠에게 도전하기","intro":["뮤츠: 누군가의 명령으로 온 것이 아니군.\n네가 선택한 승부인가?", "아버지의 꿈을 넘어,\n자신의 의지로 최강에 도전한다!"],"battle":[{"species":"mewtwo","offset":5,"min":50,"max":80}],"outro":["뮤츠: 힘을 지배가 아닌 자유를 위해 쓰는가.\n좋다. 너의 강함을 인정한다.","아버지와 나란히 새로운 길을 걷는다.\n최강이라는 이름도, 여행의 목적도 스스로 정한다.","진엔딩 — 이어지는 의지"]}
		]}
	]

	return _expand_independent_bird_clues(result)

static func _expand_independent_bird_clues(source: Array) -> Array:
	var expanded: Array = []
	for original in source:
		var quest: Dictionary = original.duplicate(true)
		if quest.id not in ["articuno_trail","zapdos_trail","moltres_trail"]:
			expanded.append(quest)
			continue
		# Both witness clues can be collected in either order. Only the nest
		# encounter waits for their combination; the map itself stays open.
		var requirements: Array = (quest.requires as Array).duplicate()
		for index in 2:
			var clue_id := String(quest.id)+"_clue_"+str(index+1)
			expanded.append({"id":clue_id,"name":String(quest.name)+(" · 목격담" if index == 0 else " · 현장 조사"),"parent":quest.id,"requires":(quest.requires as Array).duplicate(),"reward":{"oran_berry":1},"stages":[quest.stages[index]]})
			requirements.append("quest_"+clue_id+"_complete")
		quest["stages"] = [quest.stages[2]]
		quest["requires"] = requirements
		expanded.append(quest)
	return expanded
