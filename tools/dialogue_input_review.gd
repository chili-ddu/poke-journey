extends SceneTree
const OUT := "res://docs/dialogue_input/"
var game: Node
var visual := false
func _init() -> void: call_deferred("run")

func key(code: int, pressed: bool = true) -> void:
    var event := InputEventKey.new()
    event.pressed = pressed;event.physical_keycode = code;event.keycode = code
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func click(pressed: bool = true) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT;event.pressed = pressed;event.position = Vector2(300,185)
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func shot(name: String) -> void:
    if not visual:return
    for frame in 2: await process_frame
    await RenderingServer.frame_post_draw
    assert(DisplayServer.window_get_size()==Vector2i(384,216) and root.size==Vector2i(384,216))
    root.get_texture().get_image().save_png(OUT+name+".png")

func run() -> void:
    visual = DisplayServer.get_name()!="headless"
    for pair in [["BOT","1"],["GOD","0"],["SEED","1"],["LANG_CODE","ko"],["DUNGEON","viridian_center"],["CAP_VIEW","384x216"],["CAP_AUDIO","0"]]:OS.set_environment(pair[0],pair[1])
    SaveData.path = "user://dialogue_input_review_private.cfg"
    SaveData.slot_pattern = "user://dialogue_input_review_%s.cfg"
    SaveData.allow_migrate = false
    if visual:await CaptureWindow.park(self)
    ViewScale.window_ready = true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game);current_scene = game;game.set_process(false)
    game.bot = false
    game.world.player.controller = Controllers.Human.new()
    var nurse: Npc = game.world.npcs[0]
    game._say_pages(game._pages(["첫 번째 대사입니다.","클릭으로 다음 대사를 확인했습니다."],nurse)+["해설은 자동으로도 넘어갑니다."])
    for frame in 240:game.advance(1.0/60)
    assert(game.dialog_text=="첫 번째 대사입니다.","Spoken dialogue never auto advances")
    await shot("01_before_click")
    key(KEY_ENTER);key(KEY_ENTER,false);key(KEY_KP_ENTER);key(KEY_KP_ENTER,false)
    assert(game.dialog_text=="첫 번째 대사입니다.")
    click()
    assert(game.dialog_text=="클릭으로 다음 대사를 확인했습니다.","Root mouse input advances speech")
    click(false)
    assert(game.dialog_text=="클릭으로 다음 대사를 확인했습니다.","Release never skips another page")
    await shot("02_after_click")
    key(KEY_SPACE);key(KEY_SPACE,false)
    assert(game.dialog_t>0.0)
    for frame in 180:game.advance(1.0/60)
    assert(game.state!="talk","Narration retains automatic advancement")
    game._say_pages(["등장 연출은 끝까지 기다립니다."])
    game.sendout={"phase":"show","t":0.0}
    click();click(false);key(KEY_SPACE);key(KEY_SPACE,false)
    assert(game.state=="talk","Click and Space respect the same sendout gate")
    game.sendout.clear()
    click()
    assert(game.state!="talk")
    var before: Vector2=game.world.player.position
    game.world._step_player(1.0/60)
    assert(game.world.player.position==before and game.world.player.hop_t==0.0,"Closing click cannot move or jump")
    click(false)
    game.state="fight"
    game.world.talk_ready=false
    # Verify the jump suppression where jumping is physically possible.
    var found:=false
    for y in range(2,int(Arena.map.height)-2):
        for x in range(2,int(Arena.map.width)-2):
            var at:=Arena.tile_center(Vector2i(x,y))
            if not Arena.blocks(at,game.world.player.radius) and game.world.plan_hop(at,Vector2.RIGHT).ok:
                game.world.player.position=at;found=true;break
        if found:break
    assert(found)
    game.world.player.facing=Vector2.RIGHT
    game._say_pages(["마지막 입력은 점프로 이어지지 않습니다."])
    key(KEY_SPACE)
    assert(Input.is_action_pressed("jump"),"Synthetic root key updates actual jump action state")
    for frame in 3:
        game.world._step_player(1.0/60)
        assert(game.world.player.hop_t==0.0,"Held closing Space cannot jump")
        await process_frame
    await shot("03_closed_without_jump")
    key(KEY_SPACE,false)
    game.world._step_player(1.0/60)
    await process_frame
    key(KEY_SPACE)
    print("Fresh Space input: ",game.state," hold=",game.world.player.controller.hold," jump=",Input.is_action_just_pressed("jump")," talk_ready=",game.world.talk_ready)
    game.world._step_player(1.0/60)
    assert(game.world.player.hop_t>0.0,"A fresh Space still jumps normally")
    key(KEY_SPACE,false)
    game.world.player.dash.clear();game.world.player.hop_t=0.0;game.world.player.lift=0.0
    game.state="fight";game.dialog_text=""
    game._queue_status_message("클릭으로 알림을 닫습니다.")
    click();click(false)
    assert(game.dialog_text.is_empty(),"Click dismisses timed combat notice")
    game._queue_status_message("스페이스로 알림을 닫습니다.")
    key(KEY_SPACE);key(KEY_SPACE,false)
    game.world._step_player(1.0/60)
    assert(game.dialog_text.is_empty() and game.world.player.hop_t==0.0,"Timed notice Space cannot leak to jump")
    game._queue_status_message("자동으로 사라지는 알림입니다.")
    for frame in 180:game.advance(1.0/60)
    assert(game.dialog_text.is_empty(),"Combat notices retain auto advance")
    var report:={"passed":true,"root_mouse_and_keyboard_events":true,"dialogue_click":true,"sendout_gate_preserved":true,"closing_click_no_movement":true,"closing_space_no_jump":true,"held_key_suppressed":true,"fresh_space_jumps":true,"timed_click_and_space":true,"narration_auto_advance":true,"window":"384x216" if visual else "headless","actual_user_saves_used":false}
    FileAccess.open(OUT+("native.json" if visual else "headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("Dialogue input review passed: ",JSON.stringify(report))
    game.free();current_scene=null
    quit()
