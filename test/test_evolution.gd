extends GutTest

# 진화 화면(EvolutionScreen — 플래티넘 evolution.c 순서): 끝까지 가면 한 번 진화하고, 교대 중 B 면 멈추며, 교대 밖에선 B 를 받지 않는다.
# 헤드리스라 곡은 틀지 않는다(Bgm._silent).

const DT := 1.0 / 60.0
const GameScript := preload("res://scripts/game.gd")

var screen: EvolutionScreen
var mon: Player
var evolved_n := 0
var result := []

func before_each() -> void:
	evolved_n = 0
	result = []
	mon = Player.new()
	mon.setup_player("charmander", 16, ["scratch"])
	add_child_autofree(mon)
	screen = EvolutionScreen.new()
	screen.size = EvolutionScreen.SCREEN
	add_child_autofree(screen)
	screen.evolved.connect(func(): evolved_n += 1)
	screen.finished.connect(func(did): result.append(did))

# phase 가 될 때까지(또는 limit 프레임) 한 프레임씩. 걸린 프레임 수.
func _run_until(cond: Callable, limit: int = 3000) -> int:
	var n := 0
	while n < limit and not cond.call():
		screen.step(DT)
		n += 1
	return n

func test_full_evolution_runs_in_platinum_order() -> void:
	screen.open(mon, "charmeleon")
	assert_true(screen.is_open())
	_run_until(func(): return screen.phase == "wait_what")
	assert_eq(screen.text, Lang.t("evolving", [Lang.species_name("charmander")]))
	_run_until(func(): return screen.phase == "alternate")
	assert_eq(screen.top, EvolutionScreen.BAND_TOP, "띠가 40px 까지 들어온 뒤 교대")
	assert_eq(screen.mon_level, 8, "두 모습은 5프레임마다 한 단계 하얘지는 중(40프레임 = 8단계)")
	# 교대: 옛 모습 줄고 새 모습 커짐, 한 바퀴마다 빨라져 64 까지.
	var deltas := {}
	var frames := _run_until(func():
		deltas[screen.shrink_delta] = true
		return screen.phase != "alternate")
	assert_almost_eq(frames, 200, 3, "이미터 9번(158 + 1 + 41)이 끝날 때까지 약 200프레임")
	assert_eq(deltas.keys(), [8, 16, 32, 64])
	assert_eq(screen.phase, "clamp_out")
	assert_eq(screen.scale_old, 0)
	assert_eq(screen.scale_new, EvolutionScreen.ONE)
	_run_until(func(): return screen.phase == "congrats")
	assert_eq(evolved_n, 1)
	assert_eq(screen.text, Lang.t("evolved", [Lang.species_name("charmander"), Lang.species_name("charmeleon")]))
	assert_eq(screen.pal_level, 0, "배경은 흰 페이드에서 돌아왔다")
	_run_until(func(): return not screen.is_open(), 6000)
	assert_eq(result, [true])
	assert_false(screen.visible)

func test_b_during_alternation_stops_evolution() -> void:
	screen.open(mon, "charmeleon")
	_run_until(func(): return screen.phase == "alternate")
	screen.step(DT * 30.0)
	screen.request_cancel()
	screen.step(DT)
	assert_eq(screen.phase, "cancel")
	_run_until(func(): return screen.phase == "cancel_text")
	assert_eq(screen.text, Lang.t("evolve_stopped", [Lang.species_name("charmander")]))
	assert_eq(screen.scale_old, EvolutionScreen.ONE, "옛 모습으로 돌아온다")
	assert_false(screen.show_new)
	assert_eq(screen.top, 0, "띠는 바로 걷힌다")
	assert_true(screen.particles.is_empty())
	_run_until(func(): return not screen.is_open())
	assert_eq(evolved_n, 0)
	assert_eq(result, [false])

func test_b_outside_alternation_is_ignored() -> void:
	screen.open(mon, "charmeleon")
	_run_until(func(): return screen.phase == "wait_what")
	assert_false(screen.can_cancel())
	screen.request_cancel()
	_run_until(func(): return screen.phase == "alternate")
	assert_eq(screen.phase, "alternate", "글 단계의 B 는 남지 않는다")
	_run_until(func(): return screen.phase == "clamp_out")
	screen.request_cancel()
	_run_until(func(): return not screen.is_open(), 6000)
	assert_eq(result, [true])

func test_game_declines_until_next_level() -> void:
	# 멈춘 레벨에선 다시 묻지 않고, 레벨이 오르면 다시 진화하려 한다(원작: 레벨업 때마다 진화 검사).
	mon.evolution_declined_level = 16
	var other := Player.new()
	add_child_autofree(other)
	other.setup_player("charmander", 16, ["scratch"])
	assert_false(GameScript.evolve_held(other), "Cancel state belongs to this Pokemon")
	assert_true(GameScript.evolve_held(mon))
	mon.set_level(17)
	assert_false(GameScript.evolve_held(mon))
	mon.evolution_declined_level = 0

func test_assets_exist() -> void:
	assert_not_null(PixelUi.ui_tex("plat/evo_bg"))
	for n in ["evo_glow", "evo_star", "evo_ray", "evo_ring_a", "evo_ring_b"]:
		assert_true(ResourceLoader.exists("res://assets/fx/%s.png" % n), n)
	for e in EvolutionScreen.EMITTERS:
		assert_true(ResourceLoader.exists("res://assets/fx/%s.png" % e["tex"]), e["tex"])

func test_pending_victory_runs_evolution_and_cancel_to_completion() -> void:
	for cancel in [false, true]:
		mon.learned.clear()
		mon.slots.fill("")
		mon.setup_player("charmander", 16, ["scratch"])
		mon.evolution_declined_level = 0
		var w := World.new()
		w.player = mon
		add_child_autofree(w)
		var game = GameScript.new()
		game.world = w
		game.evolution_screen = screen
		game.panel = ChoicePanel.new()
		add_child_autofree(game.panel)
		game.state = "fight"
		game.bot = true
		screen.evolved.connect(game._on_evolved)
		screen.finished.connect(game._on_evolve_finished)
		game.pending_learns = ["protect"]
		game._win()
		game.advance(DT)
		assert_eq(game.state, "fight", "Learn the pre-evolution move first")
		assert_true(mon.known_moves().has("protect"))
		game.advance(game.SAY_TIME + DT)
		assert_eq(game.state, "evolve")
		var frames := 0
		while game.state != "victory" and frames < 6000:
			if cancel and screen.can_cancel(): screen.request_cancel()
			game.advance(DT)
			frames += 1
		assert_eq(game.state, "victory", "Evolution must not strand the pending victory")
		assert_eq(mon.species_id, "charmander" if cancel else "charmeleon")
		assert_eq(GameScript.evolve_held(mon), cancel)
		assert_true(game.pending_learns.is_empty())
		if not cancel:
			for move in SpeciesDB.moves_at_level("charmeleon", 16):
				assert_true(mon.known_moves().has(move), "Post-evolution move is learned before victory")
		screen.evolved.disconnect(game._on_evolved)
		screen.finished.disconnect(game._on_evolve_finished)
		game.free()

func test_evolution_cancel_and_moves_save_without_touching_real_slot() -> void:
	var keep := SaveData.path
	SaveData.path = "user://test_evolution_flow_%d.cfg" % Time.get_ticks_usec()
	mon.evolution_declined_level = 16
	mon.add_learned("protect")
	SaveData.store(mon, [])
	var saved := SaveData.load_saved()
	assert_eq(saved["evolution_declined_level"], 16)
	assert_true(saved["learned"].has("protect"))
	var restored := Player.new()
	add_child_autofree(restored)
	restored.setup_player(saved["species"], saved["level"], saved["slots"])
	restored.evolution_declined_level = saved["evolution_declined_level"]
	assert_true(GameScript.evolve_held(restored))
	restored.set_level(17)
	assert_false(GameScript.evolve_held(restored))
	mon.evolve_to("charmeleon")
	SaveData.store(mon, [])
	saved = SaveData.load_saved()
	assert_eq(saved["species"], "charmeleon")
	assert_eq(saved["evolution_declined_level"], 0)
	assert_true(saved["learned"].has("protect"))
	assert_eq(saved["slots"], mon.slots)
	var legacy := ConfigFile.new()
	assert_eq(legacy.load(SaveData.path), OK)
	legacy.erase_section_key("mon", "evolution_declined_level")
	assert_eq(legacy.save(SaveData.path), OK)
	assert_eq(SaveData.load_saved()["evolution_declined_level"], 0, "Older saves default to no cancellation")
	SaveData.clear()
	SaveData.path = keep

func test_multi_level_gain_finishes_learning_before_single_evolution() -> void:
	mon.set_level(12)
	mon.exp_total = SpeciesDB.exp_for_level(12, SpeciesDB.growth_of(mon.species_id))
	var w := World.new()
	w.player = mon
	add_child_autofree(w)
	var game = GameScript.new()
	game.world = w
	game.evolution_screen = screen
	game.panel = ChoicePanel.new()
	add_child_autofree(game.panel)
	game.bot = true
	game.state = "fight"
	screen.evolved.connect(game._on_evolved)
	screen.finished.connect(game._on_evolve_finished)
	var foe := Enemy.new()
	foe.setup_enemy("caterpie", 5, w.rng)
	add_child_autofree(foe)
	game._on_enemy_defeated(foe, SpeciesDB.exp_for_level(20, SpeciesDB.growth_of(mon.species_id)) - mon.exp_total)
	game._win()
	var entered := false
	for frame in 12000:
		game.advance(DT)
		if game.state == "evolve" and not entered:
			entered = true
			assert_true(game.stat_queue.is_empty())
			assert_true(game.growth_learns.is_empty())
			for level in range(13, 21):
				for move in SpeciesDB.moves_at_level("charmander", level):
					assert_true(mon.known_moves().has(move))
		if game.state == "victory": break
	assert_true(entered)
	assert_eq(evolved_n, 1)
	assert_eq(mon.species_id, "charmeleon")
	assert_eq(mon.level, 20)
	assert_eq(game.state, "victory")
	screen.evolved.disconnect(game._on_evolved)
	screen.finished.disconnect(game._on_evolve_finished)
	game.free()
