class_name Lang
extends RefCounted

# 언어 옵션: 처음에는 기기 언어를 따른다(한국어·영어, 미지원 언어는 영어).
# L 키로 직접 바꾸면 user://settings.cfg 에 저장하고 이후 기기 언어보다 우선한다.
#   en  플래티넘(미국판) 글꼴·표기. 포켓몬·기술 이름은 pret 데이터(대문자).
#   ko  갈무리11 글꼴(assets/fonts/Galmuri11.ttf, OFL). 포켓몬·기술·타입·능력치 이름은 assets/data/names_ko.json(PokeAPI, tools/ko_names.py).
# 문구는 S 에 키마다 두 언어로. 한국어 조사는 "{은/는}" 처럼 적어 두면 t() 가 앞 글자의 받침을 보고 고른다(숫자·영문 끝도 처리).
# 도구·테스트는 환경변수 LANG_CODE 로 강제한다(저장 안 함).

const SETTINGS := "user://settings.cfg"
static var settings_path := SETTINGS # Isolated settings files for tools/tests.
const CODES := ["en", "ko"]
const NAMES_KO := "res://assets/data/names_ko.json"
const LABELS := {"en": "English", "ko": "한국어"}
# Bootstrap before load_saved; the actual initial language comes from the OS.
const DEFAULT := "ko"
# Retained for older settings readers; loading no longer resets saved choices by tag.
const DEFAULT_TAG := "ko-2026-10-29"

static var code := DEFAULT
static var _ko := {}
static var _ko_loaded := false

const S := {
	"town_map_title": {"ko":"관동 타운맵", "en":"KANTO TOWN MAP"},
	"town_map_places": {"ko":"지역 보기", "en":"REGIONS"},
	"town_map_close": {"ko":"닫기", "en":"CLOSE"},
	"town_map_hint": {"ko":"방향키 지역 선택 · 확인/취소 닫기", "en":"Arrows: regions  Confirm/Back: close"},
	"fly_map_title": {"ko": "관동 타운맵 · 날기", "en": "KANTO TOWN MAP - FLY"},
	"fly_pick_place": {"ko": "목적지 선택", "en": "DESTINATION"},
	"fly_go": {"ko": "여기로 날아간다", "en": "FLY HERE"},
	"fly_cancel": {"ko": "취소", "en": "BACK"},
	"fly_map_hint": {"ko": "↑↓ 선택 · Space 이동 · Esc 취소 · 클릭 선택", "en": "Arrows: select  Space: fly  Esc: back  Click: select"},
	"fly_unvisited": {"ko":"%s: 아직 방문하지 않은 지역", "en":"%s: not visited yet"},
	"fly_road_closed": {"ko":"%s: 길이 막혀 있어 갈 수 없다", "en":"%s: the road is still blocked"},
	"gym_tutorial_locked": {"ko":"지금은 체육관에 도전할 수 없다.\n노랑시티에 도착한 뒤 다시 와 보자.", "en":"GYM challenges are not open yet.\nReturn after reaching SAFFRON CITY."},
	"fly_unbuilt": {"ko": "%s: 아직 연결되지 않은 지역", "en": "%s: not connected yet"},

	"bird_caught": {"ko": "으앗!? 놔 줘!\n난 먹이가 아니라고!", "en": "Whoa! Let me go!\nI am not food!"},
	"bird_nest_drop": {"ko": "피죤이 커다란 둥지에 던져 놓고\n어디론가 날아가 버렸다!", "en": "PIDGEOTTO dropped you into a huge\nnest, then flew away!"},
	"bird_chicks_hungry": {"ko": "수많은 구구가 부리를 딱딱거린다.\n먹이인 줄 알고 몰려오기 시작했다!", "en": "Hungry PIDGEY snap their beaks.\nThey think you are their next meal!"},
	"bird_defend": {"ko": "잠깐! 날 먹으려는 거야!?\n이대로 당하고만 있진 않겠어!", "en": "Wait! You want to eat me!?\nI have to defend myself!"},
	"bird_angry": {"ko": "너, 우리 애들을\n왜 괴롭히는 거야!", "en": "Hey! Why are you\nhurting my little ones!?"},
	"bird_explain": {"ko": "네가 날 여기로 데려왔잖아!\n구구들이 날 쪼아먹으려고 했다고!", "en": "You brought me here!\nThey were trying to eat me!"},
	"bird_strong": {"ko": "이렇게 강한 포켓몬은\n지금까지 한 번도 못 봤어…!", "en": "I have never met a POKéMON\nas strong as you...!"},
	"bird_sorry": {"ko": "미안해. 내가 크게 오해했어.\n처음 있던 곳으로 데려다줄게.", "en": "I am sorry. I misunderstood.\nI will take you right back."},
	"bird_home": {"ko": "여기야. 아까 있던 자리 맞지?\n그런데 넌 어떻게 그렇게 강해?", "en": "Here we are. Right where you were.\nHow did you get so strong?"},
	"bird_dream": {"ko": "난 앞으로 더 강해질 거야!\n세상에서 최강의 포켓몬이 될 거라고!", "en": "I will keep getting stronger!\nI will be the strongest of all!"},
	"bird_fan": {"ko": "멋진 꿈이네!\n그럼 내가 네 1호 팬이 될게!", "en": "What an amazing dream!\nThen I will be your number one fan!"},
	"bird_promise": {"ko": "언제든 불러! 편하게 이동하도록\n내가 태워 줄게. 또 만나자!", "en": "Call me anytime!\nI will give you a lift. See you!"},
	"bird_friend_gained": {"ko": "피죤과 친구가 되었다!", "en": "PIDGEOTTO became your friend!"},
	"bird_friend_hint": {"ko": "점프 착지 전에 Space를 다시 누르면\n타운맵에서 목적지를 고를 수 있다!", "en": "Press Space again before landing\nto choose a destination on the map!"},

	"gym_liam": {"ko":"으앗! 야생 포켓몬이\n혼자 체육관에 들어왔잖아!?|트레이너는 어디 있어?\n설마 웅에게 도전하려고 온 거야?", "en":"Whoa! A wild POKéMON\nwalked into our GYM alone!?|Where is your TRAINER?\nAre you here to challenge BROCK?"},
	"gym_luis": {"ko":"어? 야생 포켓몬이 여길 어떻게…!\n수영하다가 잘못 들어온 거야?|이슬에게 도전하러 왔다고?\n포켓몬 혼자서도 도전을 하는구나!", "en":"Huh? A wild POKéMON in here!?\nDid you swim into the wrong place?|You came to challenge MISTY?\nWithout a TRAINER? Amazing!"},
	"gym_diana": {"ko":"꺅! 누구 포켓몬이야!?\n…주인 없이 혼자 온 거라고?|체육관에 야생 포켓몬이 오다니…\n이슬도 깜짝 놀라겠는데!", "en":"Ah! Whose POKéMON are you!?\nYou came here on your own?|A wild POKéMON visiting our GYM…\nMISTY will be surprised too!"},
	"bill_arrival": {"ko":"우리 집에 %s{이/가}\n제 발로 오다니!?", "en":"A %s came\nto my home on its own!?"},
	"rescue_ask": {"en":"Are you all right? What happened?\nYou're covered in wounds!", "ko":"괜찮아? 무슨 일이야?\n온몸이 상처투성이잖아!"},
	"rescue_champion_road": {"en":"I was heading to VICTORY ROAD\nto test how strong I am...", "ko":"내 강함을 시험해 보려고\n챔피언로드로 가던 길이었어…"},
	"rescue_warning": {"en":"The MANKEY surrounded me...\nCareful! They're behind you!", "ko":"망키들이 몰려들어서 그만…\n조심해! 네 뒤에도 있어!"},
	"rescue_gang_taunt": {"en":"This is our turf!\nYou're not getting past us either!", "ko":"여긴 우리 구역이야!\n너도 그냥 지나갈 순 없어!"},
	"rescue_wrong_way": {"en":"Ganging up on someone alone?\nLeave SCYTHER alone!", "ko":"혼자인 상대를 여럿이서 공격하다니!\n이제 스라크는 그만 괴롭혀!"},
	"rescue_help": {"en":"SCYTHER can't fight any more.\nI'll take you on!", "ko":"스라크는 더 싸울 수 없어.\n이번엔 내가 상대해 주겠어!"},
	"rescue_angry": {"en":"You asked for it!\nMANKEY, get that POKéMON!", "ko":"좋아, 네가 먼저 나선 거다!\n망키들아, 혼쭐을 내 주자!"},
	"rescue_battle_start": {"en":"The MANKEY gang is approaching!\nDefeat them and help SCYTHER!", "ko":"망키 무리가 몰려온다!\n무리를 물리치고 스라크를 구하자!"},
	"rescue_boss_arrives": {"en":"The MANKEY gang leader stepped in!", "ko":"우두머리 망키가 직접 나섰다!"},
	"rescue_battle_won": {"en":"The MANKEY gang has given up!\nGo back to SCYTHER.", "ko":"망키 무리가 싸움을 포기했다!\n스라크에게 돌아가자."},
	"rescue_thanks": {"en":"You saved me... Thank you.\nI've still got a lot to learn.", "ko":"덕분에 살았어… 고마워.\n난 아직 단련이 더 필요한가 봐."},
	"rescue_mankey_after": {"en":"All right, you win!\nWe'll leave you two alone!", "ko":"으윽… 알았어, 우리가 졌어!\n너희 둘은 더는 건드리지 않을게!"},
	"rescue_promise": {"en":"I want to help you too.\nMy blades can clear small trees!", "ko":"날 구해 준 너를 나도 돕고 싶어.\n작은 나무라면 내 칼로 벨 수 있어!"},
	"rescue_friend_gained": {"en":"SCYTHER became your friend!", "ko":"스라크와 친구가 되었다!"},
	"rescue_friend_hint": {"en":"Press Space at a small tree.\nYou'll cry out for SCYTHER's help!", "ko":"작은 나무 앞에서 Space를 누르면\n울부짖어 스라크를 부른다."},
	"rescue_friend_repeat": {"en":"I'll keep training to get stronger!\nCall me when a tree blocks your path.", "ko":"더 강해질 때까지 여기서 단련할게!\n길을 막는 작은 나무라면 불러 줘."},
	"friend_cut_needed": {"en":"A small tree blocks the path.\nA friend with blades could help.", "ko":"작은 나무가 길을 막고 있다.\n베어 줄 친구가 있으면 좋겠다."},
	"friend_cut_done": {"en":"SCYTHER cut the tree and cleared the path!", "ko":"스라크가 작은 나무를 베어 길을 열었다!"},
	"field_cut_self_hint": {"en":"Press Space at a small tree\nto use CUT yourself!","ko":"작은 나무 앞에서 Space를 누르면\n직접 풀베기를 사용할 수 있다!"},
	"field_cut_self_done": {"en":"%s used CUT and cleared the path!","ko":"%s의 풀베기로 길이 열렸다!"},
	"field_flash_teach": {"en":"PIKACHU: You can use FLASH too!\nI'll teach you how.","ko":"피카츄: 너도 플래시를 쓸 수 있겠구나!\n내가 방법을 가르쳐 줄게."},
	"field_flash_learned": {"en":"You learned FLASH!\nYou can light up the cave yourself.","ko":"플래시를 배웠다!\n동굴에서 직접 주위를 밝힐 수 있다."},
	"field_flash_self": {"en":"Used FLASH to light up the cave!","ko":"플래시로 직접 동굴을 밝혔다!"},
	"hint_cut": {"en":"SPACE  CUT", "ko":"Space  풀베기"},
	"hint_inspect": {"en":"SPACE  INSPECT", "ko":"Space  살펴보기"},
	"bill_pc_collection": {"en":"BILL's research: EEVEE,\nVAPOREON, JOLTEON, FLAREON.", "ko":"이수재의 이브이 연구 기록이다.\n샤미드·쥬피썬더·부스터가 보인다."},
	"pocket_key": {"en":"KEY ITEMS", "ko":"중요한 도구"},
	"jessie": {"en":"JESSIE", "ko":"로사"},
	"james": {"en":"JAMES", "ko":"로이"},
	"meowth_steps_out": {"en":"MEOWTH: My turn!\nMEOWTH stepped forward!", "ko":"나옹: 이번엔 내 차례다옹!\n나옹이 직접 앞으로 나섰다!"},
	"got_items": {"en":"Obtained %s ×%d!", "ko":"%s %d개를 얻었다!"},
	"trainer_berry_reward": {"en":"%s received from %s:\n%s ×%d!", "ko":"%s{은/는} %s에게서\n%s %d개를 받았다!"},
	"trainer_berry_reserve": {"en":"Bag full. The rest are saved.\nCollected when space opens.","ko":"남은 열매는 보관했다.\n빈자리가 생기면 자동으로 받는다."},
	"field_water": {"en": "Waterside", "ko": "물가에서 할 일"},
	"field_fishing": {"en": "Fishing", "ko": "낚시"},
	"field_old_rod": {"en": "Old Rod", "ko": "낡은낚싯대"},
	"field_good_rod": {"en": "Good Rod", "ko": "좋은낚싯대"},
	"field_super_rod": {"en": "Super Rod", "ko": "대단한낚싯대"},
	"field_surf": {"en": "Surf", "ko": "파도타기"},
	"field_surf_start": {"en": "Started surfing!", "ko": "파도타기를 시작했다!"},
	"field_cast": {"en": "Cast the line...", "ko": "낚싯줄을 드리웠다..."},
	"field_bite": {"en": "A bite! A wild Pokémon appeared!", "ko": "걸렸다! 야생 포켓몬이 나타났다!"},
	"field_no_bite": {"en": "Not even a nibble...", "ko": "입질이 없다..."},
	"field_fish_cancel": {"en": "Stopped fishing.", "ko": "낚시를 그만두었다."},
	"field_busy": {"en": "Finish battling before fishing.", "ko": "전투를 마친 뒤 낚시할 수 있다."},
	"field_no_water": {"en": "Face nearby water first.", "ko": "가까운 물가를 바라보자."},
	"hint_water": {"en": "F  FISH / SURF", "ko": "F  낚시·파도타기"},

	# 이상해씨·꼬북이 기술의 상태 문구(원작 대사)
	"protected": {"en": "%s protected itself!", "ko": "%s{은/는}\n공격으로부터 몸을 지켰다!"},
	"protect_failed": {"en": "But it failed!", "ko": "그러나 실패하고 말았다!!"},
	"no_effect_status": {"en": "But it failed to affect %s!", "ko": "그러나 %s에게는\n실패하고 말았다!"},
	"got_burned": {"en": "%s was burned!", "ko": "%s{은/는}\n화상을 입었다!"},
	"confusion_ended": {"en": "%s snapped out of its confusion!", "ko": "%s의\n혼란이 풀렸다!"},
	"cured_poison": {"en": "%s was cured of its poisoning!", "ko": "%s의 독은\n말끔하게 해독됐다!"},
	"cured_burn": {"en": "%s’s burn was cured!", "ko": "%s의\n화상이 나았다!"},
	"cured_paralyze": {"en": "%s was cured of paralysis!", "ko": "%s의\n몸저림이 풀렸다!"},
	"poison_damage": {"en": "%s was hurt by its poisoning!", "ko": "%s{은/는}\n독에 의한 데미지를 입었다!"},
	"burn_damage": {"en": "%s was hurt by its burn!", "ko": "%s{은/는}\n화상 데미지를 입었다!"},
	"fell_asleep": {"en": "%s fell asleep!", "ko": "%s{은/는}\n잠들어 버렸다!"},
	"woke_up": {"en": "%s woke up!", "ko": "%s{은/는}\n눈을 떴다!"},
	"became_confused": {"en": "%s became confused!", "ko": "%s{은/는}\n혼란에 빠졌다!"},
	"hurt_itself": {"en": "It hurt itself in its confusion!", "ko": "영문도 모른 채\n자신을 공격했다!"},
	"seeded": {"en": "%s was seeded!", "ko": "%s에게 씨앗을 심었다!"},
	"got_insomnia": {"en": "%s acquired INSOMNIA!", "ko": "%s의 특성이 불면이 되었다!"},
	"got_poisoned": {"en": "%s was poisoned!", "ko": "%s의\n몸에 독이 퍼졌다!"},
	# 마비(전기자석파·용의숨결, 2026-11-02 원작 그대로). 문구는 스칼렛·바이올렛 한국어/영어 덤프 기준.
	"got_paralyzed": {"en": "%s is paralyzed, so it may be unable to move!", "ko": "%s{은/는} 마비되어\n기술이 나오기 어려워졌다!"},
	"para_cant_move": {"en": "%s couldn’t move because it’s paralyzed!", "ko": "%s{은/는}\n몸이 저려서 움직일 수 없다!"},
	"hp_full": {"en": "HP is full!", "ko": "HP가 가득 찼다!"},
	"recoil": {"en": "Hit with recoil!", "ko": "반동으로 데미지를 입었다!"},
	"rain_started": {"en": "It started to rain!", "ko": "비가 내리기 시작했다!"},
	"rain_stopped": {"en": "The rain stopped.", "ko": "비가 그쳤다."},
	"stat_eva": {"en": "EVASIVENESS", "ko": "회피율"},
	# 시작 화면(PC 박스, 사용자 결정 2026-10-28)
	"title_box": {"en": "BOX 1", "ko": "박스 1"},
	"title_new": {"en": "NEW GAME", "ko": "새로 시작"},
	"title_continue": {"en": "CONTINUE", "ko": "이어하기"},
	"title_reset": {"en": "RESET", "ko": "리셋"},
	"title_cancel": {"en": "CANCEL", "ko": "그만두기"},
	"title_yes": {"en": "YES", "ko": "예"},
	"title_no": {"en": "NO", "ko": "아니오"},
	"title_reset_q": {"en": "Erase %s's record and start over?", "ko": "%s의 기록을 지우고 처음부터 할까?"},
	"title_saved_at": {"en": "Saved at %s", "ko": "%s에서 저장"},
	"title_slot_number": {"en": "Slot %d", "ko": "슬롯 %d"},
	"title_empty_slot": {"en": "Empty / Start", "ko": "빈 슬롯 · 시작"},
	"title_record_number": {"en": "Record %d", "ko": "기록 %d"},
	"title_new_record": {"en": "New record", "ko": "새 기록"},
	"title_delete_record": {"en": "DELETE RECORD", "ko": "기록 삭제"},
	"title_record_unreadable": {"en": "Cannot read record", "ko": "읽을 수 없는 기록"},
	"title_reset_record_q": {"en": "Delete record %d (%s)?", "ko": "기록 %d(%s)의 저장을 지울까?"},
	"title_records": {"en": "SAVE FILES", "ko": "세이브 파일"},
	"title_record_empty": {"en": "New game", "ko": "새로 시작"},
	"title_record_select": {"en": "SELECT / ENTER", "ko": "선택 · Enter"},
	"title_empty": {"en": "No record yet.", "ko": "아직 기록이 없다."},
	"title_hint_continue": {"en": "ENTER: Continue / Delete", "ko": "Enter: 이어하기 · 삭제"},
	"title_hint_new": {"en": "ENTER: Start", "ko": "Enter: 시작"},
	"wild_appeared": {"en": "Wild %s appeared!", "ko": "앗! 야생의 %s{이/가} 튀어나왔다!"},
	"exp_gained": {"en": "%s gained %d Exp. Points!", "ko": "%s{은/는}\n%d 경험치를 얻었다!"},
	"exp_gained_one": {"en": "%s gained %d Exp. Point!", "ko": "%s{은/는}\n%d 경험치를 얻었다!"},
	"grew": {"en": "%s grew to Lv. %d!", "ko": "%s{은/는}\n레벨 %d{으로/로} 올랐다!"},
	"learned": {"en": "%s learned %s!", "ko": "%s{은/는}\n%s{을/를} 배웠다!"},
	"forgot_learned": {"en": "1, 2, and… Poof! %s forgot %s. And… learned %s!",
		"ko": "하나 둘 셋… 짠! %s{은/는} %s{을/를} 깨끗이 잊었다! 그리고… %s{을/를} 배웠다!"},
	"did_not_learn": {"en": "%s did not learn %s.", "ko": "%s{은/는} %s{을/를} 배우지 않았다."},
	"swap_which": {"en": "Set %s to which slot?", "ko": "%s{을/를} 어느 칸에 끼울까?"},
	"swap_need_full": {"en": "PP must be full to swap!", "ko": "PP가 가득 차야 바꿀 수 있다!"},
	"learned_list": {"en": "%s learned %s! Equip it from the SUMMARY (C).", "ko": "%s{은/는} %s{을/를} 배웠다! 상태창(C)에서 끼울 수 있다."},
	"evolving": {"en": "What? %s is evolving!", "ko": "어…? %s의 상태가…!"},
	"evolved": {"en": "Congratulations! Your %s evolved into %s!", "ko": "축하합니다! %s{은/는} %s{으로/로} 진화했다!"},
	"evolve_stopped": {"en": "Huh? %s stopped evolving!", "ko": "어라…? %s의 변화가 멈췄다!"},   # 진화 취소(B) — 원작 BattleStrings_Text_HuhPokemonStoppedEvolving(사용자 승인 2026-10-30)
	"fled": {"en": "The wild POKéMON fled!", "ko": "야생 포켓몬은 도망쳤다!"},
	"lv_float": {"en": "Lv.%d!", "ko": "Lv.%d!"},
	"view": {"en": "View: %s", "ko": "시야: %s"},
	"lang_toast": {"en": "Language: English", "ko": "언어: 한국어"},
	"menu_title": {"en": "MENU", "ko": "메뉴"},
	"got_bound": {"en": "%s was squeezed by %s!", "ko": "%s{은/는} %s에게 조였다!"},
	"sent_out": {"en": "%s sent out %s!", "ko": "%s{은/는} %s{을/를} 내보냈다!"},
	"wants_battle": {"en": "%s\nwould like to battle!", "ko": "%s{이/가}\n승부를 걸어왔다!"},
	"foe_fainted": {"en": "The opposing %s fainted!", "ko": "상대 %s{은/는} 쓰러졌다!"},
	"trainer_beaten": {"en": "You defeated\n%s!", "ko": "%s{과/와}의 승부에서 이겼다!"},
	"got_tm": {"en": "%s received %s!", "ko": "%s{은/는} %s{을/를} 받았다!"},
	"menu_save_title": {"en": "SAVE & QUIT", "ko": "저장하고 끝내기"},
	"menu_save_title_sub": {"en": "To PC BOX", "ko": "시작 화면으로"},
	"left": {"en": "%d left", "ko": "%d마리 남음"},
	"cleared": {"en": "%s cleared!", "ko": "%s 클리어!"},
	"beat_all": {"en": "%s Lv%d beat all %d wild POKéMON!", "ko": "%s Lv%d — 야생 포켓몬 %d마리를 모두 쓰러뜨렸다!"},
	"wild_afraid": {"en": "Nearby Pokémon hid in fear of %s!", "ko": "주변 포켓몬들은 %s{을/를} 두려워해 모습을 감췄다!"},
	"fainted": {"en": "%s fainted!", "ko": "%s{은/는} 쓰러졌다!"},
	"defeated": {"en": "Defeated %d/%d  ·  Lv%d", "ko": "쓰러뜨림 %d/%d  ·  Lv%d"},
	"retry": {"en": "Press R to retry", "ko": "R 키로 다시 도전"},
	"forget_title": {"en": "%s wants to learn %s. Forget one? (1-5)", "ko": "%s{은/는} %s{을/를} 배우고 싶다. 어느 기술을 잊게 할까? (1-5)"},
	"forget": {"en": "Forget", "ko": "잊기"},
	"give_up": {"en": "Give up", "ko": "포기"},
	"dont_learn": {"en": "Don't learn", "ko": "배우지 않는다"},
	"keep_four": {"en": "Keeps all four", "ko": "지금 기술 그대로"},
	"new_move": {"en": "New: %s  ·  %s  ·  %s", "ko": "새 기술: %s  ·  %s  ·  %s"},
	"power": {"en": "POWER %d", "ko": "위력 %d"},
	"power_none": {"en": "POWER ---", "ko": "위력 ---"},
	"cat_physical": {"en": "PHYSICAL", "ko": "물리"},
	"cat_special": {"en": "SPECIAL", "ko": "특수"},
	"cat_status": {"en": "STATUS", "ko": "변화"},
	"nothing": {"en": "But nothing happened!", "ko": "그러나 아무 일도 일어나지 않았다!"},
	"stat_rose": {"en": "%s rose!", "ko": "%s{이/가} 올라갔다!"},
	"stat_sharp_rose": {"en": "%s rose sharply!", "ko": "%s{이/가} 크게 올라갔다!"},
	"stat_fell": {"en": "%s fell!", "ko": "%s{이/가} 떨어졌다!"},
	"stat_sharp_fell": {"en": "%s harshly fell!", "ko": "%s{이/가} 크게 떨어졌다!"},
	"stat_drastic_rose": {"en": "%s rose drastically!", "ko": "%s{이/가} 매우 크게 올라갔다!"},
	"stat_drastic_fell": {"en": "%s severely fell!", "ko": "%s{이/가} 매우 크게 떨어졌다!"},
	"stat_wont_up": {"en": "%s won’t go any higher!", "ko": "%s{은/는} 더 올라가지 않는다!"},
	"stat_wont_down": {"en": "%s won’t go any lower!", "ko": "%s{은/는} 더 떨어지지 않는다!"},
	"crit": {"en": "A critical hit on %s!", "ko": "%s의\n급소에 맞았다!"},
	"super_effective": {"en": "It’s super effective on %s!", "ko": "%s에게\n효과가 굉장했다!"},
	"not_very_effective": {"en": "It’s not very effective on %s.", "ko": "%s에게\n효과가 별로인 듯하다."},
	"no_effect": {"en": "It doesn’t affect %s...", "ko": "%s에게는\n효과가 없는 것 같다..."},
	"oran": {"en": "ORAN BERRY!", "ko": "오랭열매!"},
	"got_berry": {"en": "Obtained an ORAN BERRY!", "ko": "오랭열매 1개를 얻었다!"},
	"got_item": {"en": "+1 %s", "ko": "%s +1"},
	"hp_restored": {"en": "%s had its HP restored.", "ko": "%s의\n체력이 회복되었다!"},
	"revived": {"en": "%s recovered from fainting!", "ko": "%s{은/는}\n기력을 회복했다!"},
	# 간호순(사용자 승인 2026-10-29): 원작은 트레이너에게 하는 말이라, 지나가던 포켓몬(내 포켓몬)에게 하는 말로 — 원작 간호순 성격대로
	# 누구에게나 상냥한 존댓말, 먼저 살펴보고 안심시키고, 건강을 걱정하며 배웅. 흐름은 원작(맞이 → 맡기 → 회복 → 끝 → 배웅).
	# 영어는 글상자 두 줄에 안 들어가는 쪽을 "|" 로 나눈다(원작 \p 처럼 다음 쪽으로 — Game._pages).
	"nurse_hello": {"en": "Oh! Welcome to our POKéMON CENTER!|Did you come all this way\non your own?", "ko": "어머, 포켓몬센터에 어서 와요!\n혼자서 여기까지 왔나 보네요."},
	"nurse_check": {"en": "Let's see... You're all worn out,\n%s.|Don't worry, I'll have you\nbetter in no time.", "ko": "어디 보자… %s, 많이 지쳤네요.\n괜찮아요, 금방 낫게 해 줄게요."},
	"nurse_rest": {"en": "Hop up here\nand rest for a little while.", "ko": "자, 여기 위로 올라와서\n잠깐만 푹 쉬어요."},
	"nurse_done": {"en": "All done! Thank you for waiting.\nYou're in perfect health now!", "ko": "다 됐어요! 기다려 줘서 고마워요.\n이제 아주 건강해요!"},
	"nurse_bye": {"en": "Don't push yourself. Come back\nwhenever you're hurt.|We hope to see you again!", "ko": "무리하지 말고, 아프면 언제든 와요.\n또 만나요!"},
	# 새 게임 시작 이야기(사용자 승인 2026-10-29): 검은 화면 독백(내 포켓몬의 속마음) → 해설 → 오박사. 영어 "|" 는 쪽 나눔.
	"intro_self_bulbasaur": {"en": "I'm BULBASAUR, a GRASS POKéMON\nwith a seed on my back.", "ko": "나는 등에 씨앗을 짊어진\n풀 포켓몬, 이상해씨."},
	"intro_self_charmander": {"en": "I'm CHARMANDER, a FIRE POKéMON\nwith a flame on my tail.", "ko": "나는 꼬리에 불꽃을 단\n불꽃 포켓몬, 파이리."},
	"intro_self_squirtle": {"en": "I'm SQUIRTLE, a WATER POKéMON\nwith a sturdy shell.", "ko": "나는 단단한 등껍질을 가진\n물 포켓몬, 꼬북이."},
	"intro_world": {"en": "I can hear the world beyond this ball…\nthe wind, the grass,\nthe cries of strong POKéMON.",
		"ko": "볼 너머로 바깥세상의 소리가 들려온다.\n바람, 풀숲, 그리고 강한 포켓몬들의 울음소리."},
	"intro_resolve": {"en": "I can't just sit still in here!\nI'm going out there to become the strongest!",
		"ko": "언제까지 여기 가만히 있을 순 없어!\n저 밖으로 나가서 최강이 되고 말겠어!"},
	"intro_lab": {"en": "Morning light fills\nthe quiet lab.|But one of the POKé BALLS\non the table…", "ko": "아침 햇살이 드는 조용한 연구소.\n그런데 탁자 위 몬스터볼 하나가…"},
	"oak_escape": {"en": "What!? It broke out of\nits POKé BALL on its own…!", "ko": "아니!? 볼에서 혼자 나오다니…!"},
	"oak_wait": {"en": "H-hey! Where do you think\nyou're going!? Wait!", "ko": "어, 얘야! 어디 가는 게냐!?\n기다리거라!"},
	"oak_huff": {"en": "Huff… huff…\nMy, you're a quick one…", "ko": "헉헉… 이 녀석, 발도 빠르구나…"},
	"oak_eyes": {"en": "That look in your eyes…|You want to grow\nstrong out there.", "ko": "그 눈빛… 바깥세상에서\n강해지고 싶은 게로구나."},
	"oak_go": {"en": "Haha, there's no stopping you.|Come back whenever\nyou need to!", "ko": "허허, 말려도 소용없겠군.\n힘들면 언제든 돌아오너라!"},
	"oak_hello": {"en": "Oh, %s!\nHow's the world treating you?", "ko": "오, %s{이로구나/로구나}!\n바깥세상은 어떠냐?"},
	"oak_grow": {"en": "The more you battle, the stronger\nyou get.|Come show me how much\nyou've grown!", "ko": "싸우면 싸울수록 강해지는 법이란다.\n얼마나 성장했는지 가끔 보여 다오."},
	"shop_title": {"en": "What would you like? (Your trade goods: worth %d)", "ko": "무엇과 바꿀까? (가진 교환품 가치 %d)"},
	"worth": {"en": "WORTH %d", "ko": "가치 %d"},
	"shop_leave": {"en": "Leave", "ko": "그만둔다"},
	"shop_short": {"en": "Not enough goods to trade.", "ko": "교환할 물건이 모자란다."},
	"shop_full": {"en": "You can't carry any more.", "ko": "더 이상 가질 수 없다."},
	"shop_confirm": {"en": "Give %s for %s?", "ko": "%s{을/를} 주고 %s{을/를} 받을까?"},
	"trade_yes": {"en": "Trade", "ko": "바꾼다"},
	"trade_no": {"en": "Cancel", "ko": "그만둔다"},
	# 상록시티 체육관 앞 비주기(사용자 요청·승인 대사 A안 2026-10-30). 받는 글은 %s = 내 포켓몬·비주기·물건.
	"giovanni": {"en": "GIOVANNI", "ko": "비주기"},
	"gio_1": {"en": "…What's this? A POKéMON,\nalone? What is going on here?", "ko": "…뭐냐, 이건. 포켓몬이 혼자서\n여기서 뭘 하고 있는 거지?"},
	"gio_2": {"en": "You meant to walk into my GYM\nwithout a TRAINER, did you.", "ko": "트레이너도 없이 체육관에\n들어오려 했다는 건가."},
	"gio_3": {"en": "…Hm. That look in your eyes.\nI like it.", "ko": "…흠. 그 눈빛.\n마음에 드는군."},
	"gio_4": {"en": "The eyes of one who wants power.\nI had eyes like that once.", "ko": "강해지고 싶다는 눈이다.\n나도 한때는 그런 눈을 했었지."},
	"gio_5": {"en": "Fine. Take this.", "ko": "좋다. 이걸 가져가라."},
	"got_from": {"en": "%s obtained %s's\n%s!", "ko": "%s{은/는} %s에게서\n%s{을/를} 받았다!"},     # %s = 내 포켓몬·주는 이·물건(영어도 같은 차례)
	# 오랭열매 주기(사용자 결정 2026-10-30): 오박사 3개(연구소 문 앞), 그린 2·웅 3(기술머신 자리에서), 새미 2(흘리고 간 볼과 함께).
	"oak_name": {"en": "PROF. OAK", "ko": "오박사"},
	"oak_berry": {"en": "At least take these.\nEat them when you're worn out.", "ko": "이거라도 가져가거라.\n배고프면 먹고 힘내거라."},
	"got_oran": {"en": "%s obtained %s's\n%d ORAN BERRIES!", "ko": "%s{은/는} %s에게서\n오랭열매 %d개를 받았다!"},
	"got_drop_both": {"en": "%s picked up %s and\n%d ORAN BERRIES that SAMMY dropped!", "ko": "%s{은/는} 새미가 떨어뜨리고 간\n%s{과/와} 오랭열매 %d개를 주웠다!"},
	"got_drop": {"en": "%s picked up %s\nthat SAMMY dropped!", "ko": "%s{은/는} 새미가 떨어뜨리고 간\n%s{을/를} 주웠다!"},
	"gio_6": {"en": "An EVERSTONE… A gift, so that\nheart of yours never changes.", "ko": "변함없는돌… 그 마음, 변치 말라는\n뜻으로 주는 선물이다."},
	"gio_7": {"en": "Hold on to the resolve\nyou have now. All the way.", "ko": "지금의 그 다짐을 끝까지\n지켜 내 보거라."},
	"gio_8": {"en": "…Come to my GYM when you're ready.\nI'll see your strength for myself.", "ko": "…준비가 되면 체육관으로 와라.\n네 실력을 직접 보아 주지."},
	# 가방에서 지니는 물건을 고르면(%s = 내 포켓몬·물건).
	"hold_on": {"en": "%s is now holding\nthe %s.", "ko": "%s{은/는} %s{을/를} 지녔다."},
	"hold_off": {"en": "%s handed back\nthe %s.", "ko": "%s에게서 %s{을/를}\n돌려받았다."},
	"got_new": {"en": "Got %s!", "ko": "%s{을/를} 받았다!"},
	"bag_title": {"en": "BAG", "ko": "가방"},
	"bag_empty": {"en": "The BAG is empty.", "ko": "가방이 비어 있다."},
	"bag_close": {"en": "Close", "ko": "닫기"},
	"bag_close_row": {"en": "CLOSE BAG", "ko": "가방 닫기"},
	"bag_close_desc": {"en": "Close the BAG.", "ko": "가방을 닫는다."},
	"pocket_items": {"en": "ITEMS", "ko": "도구"},
	"pocket_medicine": {"en": "MEDICINE", "ko": "약"},
	"pocket_tms": {"en": "TMs & HMs", "ko": "기술머신"},
	"pocket_berries": {"en": "BERRIES", "ko": "열매"},
	"pocket_battle": {"en": "BATTLE ITEMS", "ko": "배틀 도구"},
	"item_wait": {"en":"It can't be used right now.","ko":"지금은 사용할 수 없다!"},
	"berry_pp_choose": {"en":"Restore which move's PP?","ko":"어느 기술의 PP를 회복할까?"},
	"berry_pp_restored": {"en":"%s's PP was restored!","ko":"%s의 PP가 회복됐다!"},
	"berry_cancel": {"en":"Cancel","ko":"취소"},
	"item_used": {"en": "Used %s!", "ko": "%s{을/를} 사용했다!"},
	"cant_use_here": {"en": "Can't use that here.", "ko": "여기서는 쓸 수 없다."},
	"revive_auto": {"en": "Used automatically on fainting.", "ko": "쓰러지면 저절로 쓴다."},
	"trade_only": {"en": "For trading.", "ko": "교환용이다."},
	"repel_off": {"en": "REPEL's effect wore off...", "ko": "스프레이의 효과가 다 되었다."},
	"hint_talk": {"en": "SPACE  TALK", "ko": "Space  말 걸기"},
	"hint_bag": {"en": "B  BAG", "ko": "B  가방"},
	"hint_summary": {"en": "C  SUMMARY", "ko": "C  상태"},
	"hint_menu": {"en": "Esc  MENU", "ko": "Esc  메뉴"},
	"sum_title_info": {"en": "POKéMON INFO", "ko": "포켓몬 정보"},
	"sum_title_skills": {"en": "POKéMON SKILLS", "ko": "포켓몬 능력"},
	"sum_title_moves": {"en": "BATTLE MOVES", "ko": "싸우는 기술"},
	"sum_item": {"en": "ITEM", "ko": "지닌 물건"},
	"sum_none": {"en": "NONE", "ko": "없음"},
	"sum_dex": {"en": "Dex No.", "ko": "도감번호"},
	"sum_name": {"en": "Name", "ko": "이름"},
	"sum_type": {"en": "Type", "ko": "타입"},
	"sum_ot": {"en": "OT", "ko": "어버이"},
	"sum_id": {"en": "ID No.", "ko": "ID No."},
	"sum_exp": {"en": "Exp. Points", "ko": "현재 경험치"},
	"sum_next": {"en": "To Next Lv.", "ko": "다음 레벨까지"},
	"sum_ability": {"en": "Ability", "ko": "특성"},
	"sum_category": {"en": "CATEGORY", "ko": "분류"},
	"sum_power": {"en": "POWER", "ko": "위력"},
	"sum_accuracy": {"en": "ACCURACY", "ko": "명중률"},
	"berry_full": {"en": "Can't carry more!", "ko": "더 이상 가질 수 없다!"},
	"item_no_effect": {"en": "It won't have any effect.", "ko": "효과가 없을 것 같다."},
	"stat_hp": {"en": "MAX. HP", "ko": "최대HP"},
	"stat_atk": {"en": "ATTACK", "ko": "공격"},
	"stat_def": {"en": "DEFENSE", "ko": "방어"},
	"stat_spa": {"en": "SP. ATK", "ko": "특수공격"},
	"stat_spd": {"en": "SP. DEF", "ko": "특수방어"},
	"stat_spe": {"en": "SPEED", "ko": "스피드"},
	"stat_acc": {"en": "ACCURACY", "ko": "명중률"},
	"cleared_tag": {"en": "CLEARED", "ko": "클리어"},
	"back_town": {"en": "Press R to return to %s", "ko": "R 키로 %s{으로/로} 돌아간다"},
	"back_overworld": {"en": "Press R to fly back", "ko": "R 키로 돌아간다"},
	"door_locked": {"en": "The door is locked.", "ko": "문이 잠겨 있다."},
	"saved": {"en": "Progress saved.", "ko": "기록했다."},
	"welcome": {"en": "%s is at full health.", "ko": "%s{은/는} 기운을 되찾았다."},
	"missed": {"en": "%s avoided the attack!", "ko": "%s에게는\n맞지 않았다!"},
}

static func is_ko() -> bool:
	return code == "ko"

## Maps a device language/locale to the translations available in this game.
static func language_for_locale(locale: String) -> String:
	var language:=locale.strip_edges().to_lower().replace("-","_").get_slice("_",0).get_slice(".",0).get_slice("@",0)
	return language if language in CODES else "en"

## An optional locale allows deterministic tools without changing device settings.
static func load_saved(device_locale: String = "") -> void:
	var forced := OS.get_environment("LANG_CODE")
	if forced in CODES:
		code = forced
		return
	var cf := ConfigFile.new()
	cf.load(settings_path)
	var chosen := String(cf.get_value("lang", "code", ""))
	var locale := OS.get_locale_language() if device_locale.is_empty() else device_locale
	code = chosen if chosen in CODES else language_for_locale(locale)
	# Do not save the automatic choice: a later device language change must apply
	# until the player explicitly selects a language through set_code/toggle.

static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(settings_path)
	cf.set_value("lang", "code", code)
	cf.set_value("lang", "default_tag", DEFAULT_TAG)
	cf.save(settings_path)

static func set_code(c: String, persist: bool = true) -> void:
	code = c if c in CODES else DEFAULT
	UiFont.reset()
	if persist:
		save()

static func toggle() -> void:
	set_code(CODES[(CODES.find(code) + 1) % CODES.size()])

# 문구. args 를 % 로 채운 뒤 한국어면 조사를 고른다.
static func t(key: String, args: Array = []) -> String:
	var entry: Dictionary = S[key]
	var s: String = entry.get(code, entry["en"])
	if not args.is_empty():
		s = s % args
	return josa(s) if code == "ko" else s

# "{이/가}" 꼴을 바로 앞 글자의 받침에 맞게 바꾼다. 앞이 숫자면 그 숫자를 읽은 소리의 받침(1 일 → ㄹ, 6 육 → ㄱ …), 영문이면 모음 끝만 받침 없음으로.
static func josa(s: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\{([^/{}]+)/([^/{}]+)\\}")
	var out := s
	var m := rx.search(out)
	while m != null:
		var at := m.get_start()
		var prev := out.unicode_at(at - 1) if at > 0 else 0
		var final := _final_of(prev)          # -1: 받침 없음, 0~27: 종성 번호(8 = ㄹ)
		var with_final := m.get_string(1)
		var without := m.get_string(2)
		var pick := without
		if final >= 0 and not (with_final == "으로" and final == 8):
			pick = with_final
		out = out.substr(0, at) + pick + out.substr(m.get_end())
		m = rx.search(out, at + pick.length())
	return out

# 글자 하나의 받침(종성 번호). 받침 없으면 -1.
static func _final_of(ch: int) -> int:
	if ch >= 0xAC00 and ch <= 0xD7A3:
		var j := (ch - 0xAC00) % 28
		return j - 1 if j > 0 else -1
	if ch >= 48 and ch <= 57:                    # 영 일 이 삼 사 오 육 칠 팔 구
		return [21, 8, -1, 16, -1, -1, 1, 8, 8, -1][ch - 48]
	if (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122):
		var c := char(ch).to_lower()
		if c in ["a", "e", "i", "o", "u", "w", "y"]:
			return -1
		return 8 if c in ["l", "r"] else 1
	return -1

# ── 이름 ──

static func _names() -> Dictionary:
	if not _ko_loaded:
		_ko_loaded = true
		if ResourceLoader.exists(NAMES_KO) or FileAccess.file_exists(NAMES_KO):
			var txt := FileAccess.get_file_as_string(NAMES_KO)
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary:
				_ko = parsed
	return _ko

static func species_name(id: String) -> String:
	var en: String = SpeciesDB.get_species(id)["name"]
	return _names().get("species", {}).get(id, en) if code == "ko" else en

static func move_name(id: String) -> String:
	var en: String = MoveDB.get_move(id)["name"]
	return _names().get("moves", {}).get(id, en) if code == "ko" else en

static func type_name(id: String) -> String:
	var en: String = TypeChart.NAMES.get(id, id)
	return _names().get("types", {}).get(id, en) if code == "ko" else en

static func stat_label(key: String) -> String:
	return t("stat_" + key)
