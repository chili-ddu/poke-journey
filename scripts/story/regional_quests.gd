extends RefCounted

# Regional side stories. Only the Route 1 sighting (campaign catalog) bypasses
# this common unlock. All numbers are normal species stats, never event scales.
const UNLOCK := "visited_area_saffron_city"
const DAYCARE_EGG := "daycare_egg_left"
const EEVEE_FOLLOW := "eevee_following"
const EEVEE_RESEARCH := "eevee_research_assistant"
const SNORLAX_AWAKE := "route11_snorlax_awakened"

## Returns fresh data so save-specific stage state cannot leak between records.
static func quests(starter: String = "charmander") -> Array:
	if starter not in ["charmander", "bulbasaur", "squirtle"]:
		starter = SpeciesDB.base_form(starter)
	if starter not in ["charmander", "bulbasaur", "squirtle"]:
		starter = "charmander"
	return [_forest(), _museum(), _bill(), _daycare(starter), _eevee(), _ditto(), _snorlax(), _forest_descendants()]

static func _quest(id: String, title: String, stages: Array, reward: Dictionary, xp: float = 0.55) -> Dictionary:
	return {"id":id, "name":title, "requires":[UNLOCK], "stages":stages,
		"reward":reward, "xp_levels":xp}

static func _foe(species: String, offset: int, low: int, high: int) -> Dictionary:
	return {"species":species, "offset":offset, "min":low, "max":high}

static func _forest() -> Dictionary:
	var quest := _quest("forest_truce", "상록숲의 작은 평화", [
		{"map":"forest_gate_south", "tile":Vector2i(5,6), "sprite":"bug_catcher",
			"place":"상록숲 남쪽 관문", "objective":"곤충채집소년의 부탁을 듣기",
			"intro":["곤충채집소년: 숲 안에서 버터플과 독침붕이 다투고 있어! 알을 낳으러 돌아왔는데 서로 자기 자리래.",
				"곤충채집소년: 남쪽 길에서 오른쪽으로 돌아가면 있는 숲의 공터야. 다치기 전에 싸움을 말려 줘!"],
			"flag":"forest_truce_accepted"},
		{"map":"viridian_forest", "tile":Vector2i(40,28), "species":"butterfree",
			"place":"상록숲 동쪽 공터", "objective":"버터플과 독침붕 양쪽의 싸움을 멈추고 협상하기",
			"companions":[{"species":"beedrill", "tile":Vector2i(43,28)},
				{"species":"caterpie", "tile":Vector2i(39,26)}, {"species":"weedle", "tile":Vector2i(44,26)}],
			"intro":["버터플: 돌아와 보니 알을 돌볼 자리를 독침붕들이 차지했어!", "독침붕: 우리도 새끼를 키울 곳이 필요하다고!", "양쪽 성충의 싸움을 멈추자. 어린 포켓몬들은 안전한 곳으로 물러났다."],
			"battle":[_foe("butterfree",0,12,26), _foe("beedrill",0,12,26), _foe("butterfree",1,12,26), _foe("beedrill",1,12,26)],
			"outro":["버터플: 알들이 놀랐겠어... 우리가 너무 흥분했구나.", "독침붕: 꽃이 많은 공터는 버터플에게, 나무가 울창한 동쪽은 우리에게 어때?", "버터플: 좋아. 물가로 가는 길은 함께 쓰자. 서로의 알과 새끼도 지켜 주자!", "양쪽이 서식지를 나누고 함께 돌보기로 합의했다."],
			"flag":"forest_habitat_agreed"}
	], {"oran_berry":6, "pecha_berry":3})
	quest["unless"] = ["campaign_parent_forest_truce"]
	quest["repeat"] = ["버터플: 숲은 다시 평화로워졌어. 우리 아이들도 함께 자라고 있어!"]
	return quest

static func _museum() -> Dictionary:
	var quest := _quest("museum_fossils", "되살아난 화석", [
		{"map":"pewter_museum_1f", "tile":Vector2i(11,5), "sprite":"scientist",
			"place":"회색시티 박물관 1층", "objective":"박물관 직원의 도움 요청 듣기",
			"intro":["박물관 직원: 큰일이야! 특별전시를 준비하던 화석 포켓몬들이 갑자기 움직이기 시작했어!", "박물관 직원: 왼쪽 계단으로 2층에 올라가서 진정시켜 줄 수 있겠니? 관람객은 모두 대피시켰어."]},
		{"map":"pewter_museum_2f", "tile":Vector2i(10,4), "species":"kabuto",
			"place":"회색시티 박물관 2층 특별전시", "objective":"되살아난 화석 포켓몬을 진정시키기",
			"companions":[{"species":"omanyte", "tile":Vector2i(12,4)}, {"species":"aerodactyl", "tile":Vector2i(10,2)}],
			"intro":["투구와 암나이트가 낯선 전시실을 두리번거린다. 프테라도 혼란에 빠져 날개를 퍼덕인다.", "더 큰 소동이 나기 전에 모두 진정시키자!"],
			"battle":[_foe("kabuto",0,14,30), _foe("omanyte",0,14,30), _foe("aerodactyl",2,16,32)],
			"outro":["화석 포켓몬들은 경계를 풀었다. 직원들이 안전한 보호 공간으로 안내한다.", "아래층 직원에게 무사하다고 알려 주자."]},
		{"map":"pewter_museum_1f", "tile":Vector2i(11,5), "sprite":"scientist",
			"place":"회색시티 박물관 1층", "objective":"직원에게 돌아가 홍련의 연구 소문 듣기",
			"intro":["박물관 직원: 도와줘서 고마워! 모두 무사해. 왜 갑자기 살아났는지는 아직 조사 중이야.", "박물관 직원: 홍련섬에서 포켓몬에 관한 여러 연구를 한다는 소문을 들었어. 혹시 연관이 있을까? 어디까지나 내 짐작이지만..."],
			"flag":"rumor_cinnabar_research"}
	], {"oran_berry":5, "sitrus_berry":2}, 0.75)
	quest["repeat"] = ["박물관 직원: 화석 포켓몬들은 잘 지내고 있어. 홍련 연구와의 연관성은 아직 밝혀지지 않았어."]
	return quest

static func _bill() -> Dictionary:
	var quest := _quest("bill_rescue", "이수재의 연구자료를 지켜라", [
		{"map":"route25_sea_cottage", "tile":Vector2i(9,5), "sprite":"rocket_m",
			"place":"25번도로 이수재의 집", "objective":"연구자료를 훔치려는 로켓단을 물리치기",
			"companions":[{"sprite":"bill", "tile":Vector2i(7,5)}],
			"intro":["로켓단: 진화 연구자료를 넘겨! 본부에서 온갖 연구를 모으고 있거든.", "이수재: 함부로 가져가게 둘 수는 없어! 그 자료는 포켓몬을 이해하기 위한 거야!", "로켓단이 자료를 가지고 달아나려 한다. 이수재를 돕자!"],
			"battle":[_foe("rattata",0,14,30), _foe("zubat",1,14,30), _foe("raticate",2,16,32)],
			"outro":["로켓단: 젠장, 자료는 두고 가야겠군...!", "이수재: 정말 고마워! 네 덕분에 연구자료를 지켰어."]},
		{"map":"route25_sea_cottage", "tile":Vector2i(7,5), "sprite":"bill",
			"place":"25번도로 이수재의 집", "objective":"이수재에게 로켓단의 연구자료 수집 정황 듣기",
			"intro":["이수재: 저들은 진화 연구만 노리는 게 아닌 것 같아. 서로 다른 분야의 자료를 닥치는 대로 모으고 있어.", "이수재: 노랑시티 실프주식회사의 포획 장치 연구도 노리고 있다는 말을 들었어. 그쪽을 조사하면 목적을 알 수 있을지도 몰라.", "이수재: 이미 실프를 조사했다면 이번 일도 연결될 수 있겠지. 어디부터 살펴볼지는 네게 맡길게."],
			"flag":"bill_silph_research_tip"}
	], {"oran_berry":5, "leppa_berry":3}, 0.7)
	quest["repeat"] = ["이수재: 포켓몬이 강해지는 방법은 하나가 아니야. 연구도 여행도 모두 배움이지!"]
	return quest

static func _daycare(starter: String) -> Dictionary:
	var quest := _quest("daycare_courtship", "열매에 담은 마음", [
		{"map":"route5_pokemon_day_care", "tile":Vector2i(6,4), "species":starter, "opposite_sex":true,
			"place":"5번도로 교배집", "objective":"교배집의 이성 포켓몬과 친해지기",
			"intro":["교배집에서 너와 같은 계열의 이성 포켓몬과 눈이 마주쳤다.", "새 친구: 여행 중이구나? 나도 바깥세상 이야기를 듣는 게 좋아. 다음에 오랭열매를 함께 먹으며 이야기할래?"]},
		{"map":"route5_pokemon_day_care", "tile":Vector2i(6,4), "species":starter, "opposite_sex":true,
			"place":"5번도로 교배집", "objective":"오랭열매 2개를 선물하기", "cost":{"oran_berry":2},
			"intro":["새 친구: 날 생각해서 가져온 거야? 고마워. 하나씩 나눠 먹자!", "열매를 나누며 여행 이야기를 들려주었다. 둘 사이가 한결 가까워졌다."]},
		{"map":"route5_pokemon_day_care", "tile":Vector2i(6,4), "species":starter, "opposite_sex":true,
			"place":"5번도로 교배집", "objective":"과사열매 1개를 건네고 마음을 전하기", "cost":{"leppa_berry":1},
			"intro":["새 친구: 또 와 줬네! 이번에는 내가 네 이야기를 기다리고 있었어.", "과사열매와 함께 마음을 전했다. 둘은 앞으로도 서로의 여행을 응원하기로 했다.", "친구: 여행을 끝낼 때까지 기다릴게. 네가 가장 강해지려는 꿈도, 여기에서 생긴 인연도 잊지 마." ]},
		{"map":"route5_pokemon_day_care", "tile":Vector2i(6,4), "species":starter, "opposite_sex":true,
			"place":"5번도로 교배집", "objective":"둘의 알을 교배집에 맡기기",
			"intro":["얼마 후, 둘 사이에 작은 알이 생겼다.", "교배집 어르신: 이 알은 여기서 소중히 돌봐 주마. 너희가 남긴 인연을 꼭 지켜 주겠어.", "친구: 우리 아이에게도 네 용기와 기술이 전해질 거야. 무사히 돌아와!", "알을 교배집에 맡겼다. 새로운 세대로 이어질 인연이 생겼다."],
			"action":"daycare_egg", "flag":DAYCARE_EGG}
	], {"oran_berry":3, "leppa_berry":2}, 0.4)
	quest["unless"] = ["campaign_cycle_2"]
	quest["completion_flag"] = DAYCARE_EGG
	quest["repeat"] = ["친구: 알은 안전하게 돌보고 있어. 네가 돌아올 자리는 늘 여기야."]
	return quest

static func _eevee() -> Dictionary:
	var evolutions: Array = ["vaporeon", "jolteon", "flareon", "espeon", "umbreon", "leafeon", "glaceon"]
	var battles: Array = []
	var signature_moves: Dictionary={"vaporeon":"water_gun", "jolteon":"thunder_shock", "flareon":"ember",
		"espeon":"confusion", "umbreon":"bite", "leafeon":"razor_leaf", "glaceon":"icy_wind"}
	for species in evolutions:
		var opponent:=_foe(species,0,16,40)
		opponent["moves"]=[signature_moves[species],"tackle"]
		battles.append(opponent)
	var quest := _quest("eevee_evolution", "이브이가 고른 강함", [
		{"map":"celadon_city_condominiums_roof", "tile":Vector2i(9,13), "species":"eevee",
			"place":"무지개시티 맨션 옥상", "objective":"자신의 진화를 뽐내는 일곱 진화형과 승부하기",
			"companions":[{"species":"vaporeon", "tile":Vector2i(8,11)}, {"species":"jolteon", "tile":Vector2i(10,11)},
				{"species":"flareon", "tile":Vector2i(12,10)}, {"species":"espeon", "tile":Vector2i(8,9)},
				{"species":"umbreon", "tile":Vector2i(10,9)}, {"species":"leafeon", "tile":Vector2i(12,8)}, {"species":"glaceon", "tile":Vector2i(12,13)}],
			"intro":["샤미드: 물처럼 유연한 내가 제일 강해! 쥬피썬더: 내 번개를 따라올 수 있겠어?", "부스터: 뜨거운 불꽃이 최고지! 에브이와 블래키, 리피아와 글레이시아도 자신의 기술을 뽐낸다.", "이브이: 다들 자기가 제일 강하대... 모두와 겨뤄 보면 답을 알 수 있을까?"],
			"battle":battles,
			"outro":["이브이: 진화한 모습마다 다른 강점이 있구나. 그렇지만 난 아직 무엇을 고를지 모르겠어.", "이브이: 진화를 연구하는 이수재라는 사람이 25번도로에 산대. 나도 함께 찾아가 볼래!"],
			"action":"eevee_follow_start", "flag":EEVEE_FOLLOW},
		{"map":"route25_sea_cottage", "tile":Vector2i(7,5), "sprite":"bill",
			"place":"25번도로 이수재의 집", "objective":"이수재를 구한 뒤 이브이의 진화를 상담하기",
			"requires":["quest_bill_rescue_complete"],
			"intro":["이수재: 진화만이 강해지는 방법은 아니야. 경험을 쌓고, 기술을 익히고, 서로를 이해하는 것도 힘이 되지.", "이브이: 그럼 지금 모습으로도 할 수 있는 일이 있겠네! 네 연구를 도우면서 나만의 방법을 찾아볼래.", "이수재: 물론이지. 함께 연구해 보자!", "이브이는 스스로 연구를 돕기로 했다. 동행을 마치고 이수재의 곁에 남는다."],
			"action":"eevee_follow_end", "flag":EEVEE_RESEARCH}
	], {"leppa_berry":4, "sitrus_berry":2}, 1.0)
	quest["completed_companions"] = [{"species":"eevee", "tile":Vector2i(9,6)}]
	quest["repeat"] = ["이수재: 이브이가 연구를 정말 잘 도와주고 있어. 진화는 천천히 스스로 결정할 거야."]
	return quest

static func _ditto() -> Dictionary:
	var quest := _quest("ditto_rumor", "15번도로의 도플갱어", [
		{"map":"lavender_town_pokemon_center_1f", "tile":Vector2i(3,5), "sprite":"man",
			"place":"보라타운 포켓몬센터", "objective":"겁먹은 여행자에게 도플갱어 괴담 듣기",
			"intro":["겁먹은 여행자: 15번도로 외진 풀숲에서 나와 똑같이 생긴 녀석을 봤어! 내가 움직이면 똑같이 움직였다고!", "겁먹은 여행자: 길 동쪽, 북쪽 울타리 근처의 조용한 공터야. 다들 무서워서 근처에도 가지 못해."]},
		{"area":"route15", "tile":Vector2i(61,6), "species":"ditto", "appearance":"player",
			"place":"15번도로 동쪽 외진 풀숲", "objective":"자신과 같은 모습의 상대와 겨루고 괴담 해결하기",
			"intro":["수풀 너머에서 너와 똑같은 포켓몬이 나타났다. 모습뿐 아니라 성장과 기술까지 닮았다!", "네 모습을 한 상대가 장난스럽게 싸움을 걸어온다."],
			"battle":[{"species":"ditto", "mirror":true}],
			"outro":["상대가 말랑한 몸으로 돌아왔다. 정체는 메타몽이었다!", "메타몽: 다들 놀라는 게 재미있어서 그랬어. 이렇게 무서워할 줄은 몰랐어...", "메타몽: 약속할게. 이제는 사람들을 놀래키지 않을 거야. 다음엔 내 모습으로 친구가 될래!"],
			"flag":"ditto_promised_no_scares"},
		{"area":"route15", "tile":Vector2i(59,6), "sprite":"man",
			"place":"15번도로 동쪽 공터", "objective":"돌아온 여행자에게 괴담의 정체 알려 주기",
			"companions":[{"species":"ditto", "tile":Vector2i(61,6)}],
			"intro":["여행자: 소문 속 녀석이 메타몽이었구나! 이제 놀라게 하지 않겠다고 약속했다니 안심이야.", "사람들이 공터로 돌아왔다. 메타몽도 본래 모습으로 조심스럽게 인사한다."]}
	], {"oran_berry":6, "persim_berry":3}, 0.8)
	quest["repeat"] = ["여행자: 이제 이 공터도 다시 편하게 들를 수 있어. 메타몽도 우리와 함께 쉬고 있지!"]
	return quest

static func _snorlax() -> Dictionary:
	var quest := _quest("snorlax_wake", "잠만보의 아침", [
		{"area":"route11", "tile":Vector2i(7,9), "sprite":"worker_m",
			"place":"11번도로 서쪽 잠만보 앞", "objective":"잠만보를 깨우는 방법 알아보기",
			"intro":["길을 보던 사람: 잠만보 때문에 동쪽 길로 갈 수가 없어. 디그다굴과 갈색시티 쪽은 계속 오갈 수 있어.", "길을 보던 사람: 잠만보가 좋아하는 오랭열매 냄새와 일정한 박자로 부르는 소리가 도움이 된대. 오랭열매 세 개를 준비해 보자."],
			"flag":"snorlax_wake_method"},
		{"area":"route11", "tile":Vector2i(8,9), "sprite":"worker_m",
			"place":"11번도로 서쪽 잠만보 앞", "objective":"오랭열매 3개와 규칙적인 소리로 잠만보 깨우기", "cost":{"oran_berry":3},
			"intro":["잠만보 앞에 오랭열매를 놓고 규칙적인 박자로 소리를 냈다.", "잠만보: 으음... 좋은 냄새... 아침이야?", "잠만보가 기지개를 켜고 열매를 먹었다. 낮잠 자리는 길 밖으로 옮기기로 한다."],
			"outro":["길을 보던 사람: 고마워! 이제 동쪽 길도 열렸어. 이 열매는 답례야."],
			"action":"snorlax_wake"}
	], {"sitrus_berry":2, "leppa_berry":2}, 0.45)
	quest["completion_flag"] = SNORLAX_AWAKE
	quest["repeat"] = ["길을 보던 사람: 잠만보는 길 밖에서 쉬고 있어. 동쪽 길로 지나가도 괜찮아!"]
	return quest

static func _forest_descendants() -> Dictionary:
	var quest := _quest("forest_descendants", "상록숲이 기억하는 약속", [
		{"map":"forest_gate_south", "tile":Vector2i(5,6), "sprite":"bug_catcher",
			"place":"상록숲 남쪽 관문", "objective":"아버지의 숲 이야기를 듣기",
			"intro":["곤충채집소년: 너, 그때 숲을 구해 준 포켓몬을 꼭 닮았네! 아버지라고?", "곤충채집소년: 그때 지켰던 알에서 태어난 아이들이 이제 다 자랐어. 동쪽 공터에 가 보면 반가워할 거야."]},
		{"map":"viridian_forest", "tile":Vector2i(40,28), "species":"butterfree",
			"place":"상록숲 동쪽 공터", "objective":"아버지가 지켜 준 알의 후손들과 재회하고 겨루기",
			"companions":[{"species":"beedrill", "tile":Vector2i(43,28)},
				{"species":"caterpie", "tile":Vector2i(39,26)}, {"species":"weedle", "tile":Vector2i(44,26)}],
			"intro":["버터플: 네 아버지가 싸움을 말려 주지 않았다면 우리는 무사히 태어나지 못했을 거야.", "독침붕: 지금도 꽃밭과 나무숲을 나눠 쓰고 함께 새끼를 지키고 있어. 오늘은 다툼 대신 친선 승부를 하자!"],
			"battle":[_foe("butterfree",1,12,42), _foe("beedrill",1,12,42)],
			"outro":["버터플: 네 아버지에게 우리가 잘 자랐다고 전해 줘!", "독침붕: 너도 혼자 싸우는 게 아니야. 아버지에게 받은 약속을 우리가 이어 갈게.", "두 무리는 승부 뒤에도 함께 돌아가 어린 포켓몬들을 돌본다. 아버지의 도움이 새로운 세대로 이어져 있다."]}
	], {"oran_berry":4, "sitrus_berry":2}, 1.0)
	quest["requires"].append_array(["campaign_cycle_2", "campaign_parent_forest_truce"])
	quest["ng_plus_xp_levels"] = 1.25
	quest["repeat"] = ["버터플: 너희 아버지와 우리 부모가 한 약속을 우리도 지키고 있어!"]
	return quest
