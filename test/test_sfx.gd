extends GutTest

# 효과음·울음소리(사용자 요청 2026-10-30): 플래티넘 SDAT 에서 뽑은 파일이 다 있고(tools/plat_sfx.py), 이 게임의 종족마다 울음소리가 있다.

func test_ui_and_battle_se_exist() -> void:
	for n in ["select", "decide", "pinpon", "door", "dansa", "save", "regi", "pc_login", "kouka_h", "kouka_m", "kouka_l", "bowa"]:
		assert_true(Sfx.has(n), n)

func test_move_se_for_shaped_moves() -> void:
	var missing: Array = []
	for id in MoveShapes.SHAPES:
		if not Sfx.has("mv_" + id):
			missing.append(id)
	# 소리 기술은 종족 울음소리를 사용한다(차밍보이스는 하이퍼보이스의 음성 방식 재사용).
	var unexpected := missing.filter(func(id):return id not in ["growl","disarming_voice"])
	assert_true(unexpected.is_empty(), "기술 SE 없음: " + str(unexpected))

func test_cries_for_every_species_with_sprites() -> void:
	for id in ["charmander", "charmeleon", "squirtle", "bulbasaur", "weedle", "kakuna", "beedrill", "caterpie", "metapod", "pidgey", "rattata",
			"pikachu", "sandshrew", "geodude", "onix", "venusaur", "charizard", "blastoise"]:
		assert_true(ResourceLoader.exists(Sfx.CRY_DIR + id + ".wav"), id)

class IdleInput:
	extends RefCounted
	func move_dir(_w): return Vector2.ZERO
	func aim_point(w): return w.player.position+Vector2.RIGHT*30
	func want_skill(_i,_w): return false
	func want_dodge(_w): return false
	func want_jump(_w): return false
	func want_item(_w): return false

func _world() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7,"charmander",20,["scratch","fire_fang"],IdleInput.new())
	w.player.position = Arena.center()
	return w

func test_melee_sound_waits_for_attack_frame_and_cancels_on_faint() -> void:
	var audio := Sfx._node()
	await get_tree().process_frame
	var events := []
	var listener := func(path,_pitch,_db,duration):events.append({"path":path,"duration":duration})
	audio.sound_requested.connect(listener)
	for move in ["scratch","fire_fang"]:
		var w := _world()
		events.clear()
		w.cast(w.player,move,Vector2.RIGHT,w.player.position+Vector2.RIGHT*30)
		assert_eq(events.size(),0,"No attack sound while preparing")
		assert_gt(w.pending_melee.size(),0)
		var delay: float = w.pending_melee[0].t
		w._step_pending_melee(delay-0.001)
		assert_eq(events.size(),0)
		w._step_pending_melee(0.002)
		assert_eq(events.size(),1,"One swing/bite sound even when it misses")
		assert_true(events[0].path.ends_with("mv_"+move+".wav"))
		events.clear()
		w.cast(w.player,move,Vector2.RIGHT,w.player.position+Vector2.RIGHT*30)
		w.player.dead = true
		w._step_pending_melee(1.0)
		assert_eq(events.size(),0,"Cancelled attack stays silent")
	audio.sound_requested.disconnect(listener)

func test_growl_uses_species_cry_and_flame_audio_has_deadline() -> void:
	var audio := Sfx._node()
	await get_tree().process_frame
	var events := []
	var listener := func(path,_pitch,_db,duration):events.append({"path":path,"duration":duration})
	audio.sound_requested.connect(listener)
	var w := _world()
	w.cast(w.player,"growl",Vector2.RIGHT,w.player.position+Vector2.RIGHT*30)
	assert_eq(events[0].path,Sfx.CRY_DIR+"charmander.wav")
	events.clear()
	w.cast(w.player,"flamethrower",Vector2.RIGHT,w.player.position+Vector2.RIGHT*30)
	assert_true(events[0].path.ends_with("mv_flamethrower.wav"))
	assert_almost_eq(float(events[0].duration),0.84,0.001)
	audio.sound_requested.disconnect(listener)

func test_bounded_audio_fades_and_reused_voice_gets_new_deadline() -> void:
	var audio := Sfx.new()
	add_child_autofree(audio)
	var silent_before := Sfx._silent
	Sfx._silent = false # Test runner uses the Dummy audio driver.
	audio._play(Sfx.SE_DIR+"mv_flamethrower.wav",1.0,-6.0,0.12)
	var voice: AudioStreamPlayer = audio._players[0]
	audio._process(0.08)
	assert_lt(voice.volume_db,-6.0,"Short fade instead of abrupt stop")
	voice.stop() # Explicitly reuse a free slot; busy voices now use priority selection.
	audio._next = 0
	audio._play(Sfx.SE_DIR+"mv_ember.wav",1.0,-6.0)
	audio._process(0.1)
	assert_not_null(voice.stream,"Old deadline must not cut off reused voice")
	assert_eq(voice.volume_db,-6.0)
	voice.stop() # Explicitly reuse a free slot; busy voices now use priority selection.
	audio._next = 0
	audio._play(Sfx.SE_DIR+"mv_flamethrower.wav",1.0,-6.0,0.1)
	audio._process(0.11)
	assert_null(voice.stream)
	Sfx._silent = silent_before

func test_simultaneous_hits_coalesce_but_later_and_pitched_hits_do_not() -> void:
	var audio := Sfx.new()
	add_child_autofree(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	for i in 6: audio._play(Sfx.SE_DIR+"kouka_m.wav",1.0,-6.0)
	assert_eq(audio._players.filter(func(p):return p.playing).size(),1)
	audio._process(0.05)
	audio._play(Sfx.SE_DIR+"kouka_m.wav",1.0,-6.0)
	audio._play(Sfx.SE_DIR+"kouka_m.wav",0.8,-6.0)
	assert_eq(audio._players.filter(func(p):return p.playing).size(),3,"Separate later hits and different pitches")
	assert_eq(audio._players.size(),8)
	Sfx._silent = previous

func test_pool_preserves_ui_and_drops_lower_priority_when_full() -> void:
	var audio := Sfx.new()
	add_child_autofree(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	for i in 8: audio._play(Sfx.SE_DIR+"decide.wav",1.0,-6.0)
	var streams := audio._players.map(func(p):return p.stream)
	audio._play(Sfx.SE_DIR+"mv_ember.wav",1.0,-6.0)
	for i in 8: assert_same(audio._players[i].stream,streams[i],"Move must not replace UI")
	audio._players[4].stop()
	audio._play(Sfx.SE_DIR+"mv_ember.wav",1.0,-6.0)
	assert_true(audio._players[4].get_meta("path").ends_with("mv_ember.wav"),"Reuse free voice first")
	audio._play(Sfx.SE_DIR+"kouka_m.wav",1.0,-6.0)
	assert_true(audio._players[4].get_meta("path").ends_with("kouka_m.wav"),"Impact replaces low-priority move")
	for i in 8:
		if i!=4: assert_same(audio._players[i].stream,streams[i])
	Sfx._silent = previous

func test_finished_voices_release_streams() -> void:
	var audio := Sfx.new()
	add_child_autofree(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	audio._play(Sfx.SE_DIR+"mv_ember.wav",1.0,-6.0)
	var voice: AudioStreamPlayer = audio._players[0]
	voice.stop()
	audio._process(0.01)
	assert_null(voice.stream,"Finished/stopped voices release audio resources")
	assert_eq(float(voice.get_meta("remaining")),-1.0)
	Sfx._silent = previous

func test_move_gain_keeps_deadline_and_other_sounds_unchanged() -> void:
	var audio := Sfx._node()
	await get_tree().process_frame
	var events := []
	var listener := func(path,_pitch,db,duration):events.append({"path":path,"db":db,"duration":duration})
	audio.sound_requested.connect(listener)
	Sfx.move("flamethrower", 0.84)
	Sfx.move("ember")
	Sfx.play("kouka_m")
	assert_eq(float(events[0].db), -11.0)
	assert_almost_eq(float(events[0].duration), 0.84, 0.001)
	assert_eq(float(events[1].db), -6.0)
	assert_eq(float(events[2].db), -6.0)
	audio.sound_requested.disconnect(listener)

func test_master_limits_combined_music_and_effects_without_boost() -> void:
	assert_eq(AudioServer.get_bus_name(0), &"Master")
	assert_false(AudioServer.is_bus_bypassing_effects(0))
	assert_eq(AudioServer.get_bus_effect_count(0), 1)
	var limiter := AudioServer.get_bus_effect(0, 0) as AudioEffectHardLimiter
	assert_not_null(limiter, "Project loads output protection on startup")
	if limiter == null: return
	assert_true(AudioServer.is_bus_effect_enabled(0, 0))
	assert_eq(limiter.pre_gain_db, 0.0, "Quiet sounds are not boosted")
	assert_eq(limiter.ceiling_db, -1.0)
	assert_almost_eq(limiter.release, 0.1, 0.00001)

func test_battle_distance_fades_and_far_cast_does_not_take_voice() -> void:
	var w := _world()
	var origin := w.player.position
	assert_eq(w._battle_sound_db(origin), 0.0)
	assert_eq(w._battle_sound_db(origin+Vector2.RIGHT*4*Arena.TILE), 0.0)
	assert_almost_eq(w._battle_sound_db(origin+Vector2.RIGHT*10*Arena.TILE), -6.0206, 0.001)
	assert_eq(w._battle_sound_db(origin+Vector2.RIGHT*16*Arena.TILE), -80.0)
	assert_eq(w._battle_sound_db(origin+Vector2.RIGHT*40*Arena.TILE), -80.0)
	var enemy := Enemy.new()
	enemy.setup_enemy("charmander",20,w.rng)
	w.add_child(enemy)
	var audio := Sfx._node()
	await get_tree().process_frame
	var events := []
	var listener := func(path,_pitch,db,_duration):events.append({"path":path,"db":db})
	audio.sound_requested.connect(listener)
	enemy.position = origin+Vector2.RIGHT*10*Arena.TILE
	w.cast(enemy,"ember",Vector2.LEFT,origin)
	assert_eq(events.size(),1)
	assert_almost_eq(float(events[0].db), -12.0206, 0.001)
	events.clear()
	enemy.position = origin+Vector2.RIGHT*20*Arena.TILE
	w.cast(enemy,"ember",Vector2.LEFT,origin)
	assert_eq(events.size(),0,"Out-of-range audio does not reach the pool")
	Sfx.play("decide")
	assert_eq(events.size(),1)
	assert_eq(float(events[0].db), -6.0,"UI remains independent of battle distance")
	audio.sound_requested.disconnect(listener)

func test_full_pool_preserves_nearby_moves_and_replaces_farthest_first() -> void:
	var audio := Sfx.new()
	add_child_autofree(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	var path := Sfx.SE_DIR+"mv_ember.wav"
	for i in 8:
		var distance_db := -18.0 if i==5 else 0.0
		audio._play(path,1.0+i*0.01,-6.0+distance_db,-1.0,distance_db)
	# A nearby flame is quieter by design, but distance priority must still beat far ember.
	audio._play(Sfx.SE_DIR+"mv_flamethrower.wav",1.0,-11.0,0.84,0.0)
	assert_true(audio._players[5].get_meta("path").ends_with("mv_flamethrower.wav"))
	assert_eq(float(audio._players[5].get_meta("distance_db")),0.0)
	var sequences := audio._players.map(func(p):return p.get_meta("sequence"))
	audio._play(path,1.2,-24.0,-1.0,-18.0)
	assert_eq(audio._players.map(func(p):return p.get_meta("sequence")),sequences,"Distant move cannot cut any nearby move")
	# A free slot remains usable regardless of distance.
	audio._players[3].stop()
	audio._play(path,1.2,-24.0,-1.0,-18.0)
	assert_eq(float(audio._players[3].get_meta("distance_db")),-18.0)
	assert_eq(audio._players.size(),8)
	Sfx._silent = previous

func test_distance_preserves_importance_and_equal_distance_uses_oldest() -> void:
	var audio := Sfx.new()
	add_child_autofree(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	for i in 8:
		audio._play(Sfx.SE_DIR+"mv_ember.wav",1.0+i*0.01,-6.0)
	audio._play(Sfx.SE_DIR+"mv_scratch.wav",1.0,-6.0)
	assert_true(audio._players[0].get_meta("path").ends_with("mv_scratch.wav"),"Equal distance replaces oldest")
	audio._play(Sfx.SE_DIR+"kouka_m.wav",1.0,-24.0,-1.0,-18.0)
	assert_true(audio._players[1].get_meta("path").ends_with("kouka_m.wav"),"Impact keeps higher importance than move")
	for p in audio._players: p.stop()
	for i in 8:
		audio._play(Sfx.SE_DIR+"kouka_m.wav",1.0+i*0.01,-24.0,-1.0,-18.0)
	var sequences := audio._players.map(func(p):return p.get_meta("sequence"))
	audio._play(Sfx.SE_DIR+"mv_ember.wav",1.0,-6.0)
	assert_eq(audio._players.map(func(p):return p.get_meta("sequence")),sequences,"Near move cannot evict higher-priority impact")
	Sfx._silent = previous

func test_screen_direction_pan_and_opposite_sounds_stay_separate() -> void:
	var w := _world()
	var origin := w.player.position
	assert_eq(w._battle_sound_pan(origin+Vector2.UP*100),0.0)
	assert_almost_eq(w._battle_sound_pan(origin+Vector2.RIGHT*4*Arena.TILE),0.325,0.001)
	assert_almost_eq(w._battle_sound_pan(origin+Vector2.LEFT*20*Arena.TILE),-0.65,0.001)
	var audio := Sfx.new()
	add_child_autofree(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	var path := Sfx.SE_DIR+"kouka_m.wav"
	audio._play(path,1.0,-6.0,-1.0,0.0,-0.65)
	audio._play(path,1.0,-6.0,-1.0,0.0,0.65)
	assert_eq(audio._players.filter(func(p):return p.playing).size(),2,"Opposite directions must not coalesce")
	audio._players[0].stop()
	audio._next = 0
	audio._play(Sfx.SE_DIR+"decide.wav",1.0,-6.0)
	assert_eq(audio._players[0].bus,&"Master","Reused UI voice returns to center")
	assert_eq(float(audio._players[0].get_meta("pan")),0.0)
	Sfx._silent = previous

func test_panner_mixer_channels_and_bus_cleanup() -> void:
	var initial_buses := AudioServer.bus_count
	var audio := Sfx.new()
	add_child(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	for pan in [-0.65,0.65]:
		audio._next = 0
		audio._play(Sfx.SE_DIR+"mv_flamethrower.wav",1.0,-11.0,-1.0,0.0,pan)
		var bus := AudioServer.get_bus_index(audio._players[0].bus)
		var capture := AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus,capture)
		await wait_seconds(0.2)
		var frames := capture.get_buffer(capture.get_frames_available())
		var left := 0.0
		var right := 0.0
		for frame in frames:
			left += frame.x*frame.x
			right += frame.y*frame.y
		assert_gt(frames.size(),0,"Dummy driver actually mixed audio")
		assert_gt(left if pan<0 else right, right if pan<0 else left,"Correct channel is louder")
		AudioServer.remove_bus_effect(bus,1)
		audio._players[0].stop()
	assert_eq(AudioServer.bus_count,initial_buses+1,"Reuse one panner for the same slot")
	audio.free()
	assert_eq(AudioServer.bus_count,initial_buses,"Removing Sfx releases owned buses")
	Sfx._silent = previous

func test_owner_cleanup_keeps_other_world_and_transition_audio() -> void:
	var audio := Sfx.new()
	add_child_autofree(audio)
	var previous := Sfx._silent
	Sfx._silent = false
	var path := Sfx.SE_DIR+"mv_flamethrower.wav"
	audio._play(path,1.0,-11.0,0.84,0.0,-0.3,101)
	audio._play(path,1.0,-11.0,0.84,0.0,-0.3,202)
	audio._play(Sfx.SE_DIR+"door.wav",1.0,-6.0)
	assert_eq(audio._players.filter(func(p):return p.playing).size(),3,"Different worlds must not coalesce")
	audio._stop_owner(101)
	assert_false(audio._players[0].playing)
	assert_null(audio._players[0].stream)
	assert_eq(audio._players[0].bus,&"Master")
	assert_eq(float(audio._players[0].get_meta("remaining")),-1.0)
	assert_true(audio._players[1].playing,"New world remains audible")
	assert_true(audio._players[2].playing,"Door/UI transition remains audible")
	audio._stop_owner(101)
	audio._stop_owner(0)
	assert_true(audio._players[1].playing)
	assert_true(audio._players[2].playing)
	Sfx._silent = previous

func test_world_exit_and_battle_end_stop_owned_cast_audio() -> void:
	var audio := Sfx._node()
	await get_tree().process_frame
	var previous := Sfx._silent
	Sfx._silent = false
	var w := _world()
	for phase in ["battle_end","scene_exit"]:
		w.cast(w.player,"flamethrower",Vector2.RIGHT,w.player.position+Vector2.RIGHT*30)
		var owned := audio._players.filter(func(p):return p.playing and int(p.get_meta("owner_id",0))==w.get_instance_id())
		assert_gt(owned.size(),0,"Cast attaches world ownership")
		if phase=="battle_end":
			w.end_battle()
		else:
			remove_child(w)
		for p in owned:
			assert_false(p.playing,phase)
			assert_null(p.stream,phase)
	add_child(w) # Restore fixture ownership for automatic cleanup.
	Sfx._silent = previous
