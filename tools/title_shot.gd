extends SceneTree

# 시작 화면(PC 박스) 캡처. 실제 세이브는 건드리지 않는다(칸 파일 이름을 titleshot_*.cfg 로 바꾸고 옛 세이브 옮기기도 끈다).
#
#   godot --path . -s tools/title_shot.gd -- <출력.png>
#   CURSOR=0~2   고른 칸(기본 1 = 파이리)
#   SAMPLE=1     파이리 칸에 예시 세이브(리자드 Lv17, 1번도로)를 만들어 '이어하기' 화면을 찍는다
#   MENU=1       메뉴를 연 채로 / CONFIRM=1 리셋 확인까지
#   LANG_CODE=ko 한국어

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	var out: String = argv[0] if argv.size() > 0 else "title.png"
	SaveData.slot_pattern = "user://titleshot_%s.cfg"
	SaveData.allow_migrate = false
	for s in SaveData.STARTERS:
		SaveData.reset_slot(s)
	if OS.get_environment("SAMPLE") == "1":
		var cf := ConfigFile.new()
		cf.set_value("mon", "species", "charmeleon")
		cf.set_value("mon", "level", 17)
		cf.set_value("mon", "exp", 4000)
		cf.set_value("where", "map", "kanto_south")
		var r1 := Vector2(24 * Arena.TILE, 180 * Arena.TILE)
		cf.set_value("where", "x", r1.x)
		cf.set_value("where", "y", r1.y)
		cf.save(SaveData.slot_path("charmander"))
	await CaptureWindow.park(self)
	ViewScale.window_ready = true      # 시작 화면이 저장된 시야 크기로 창을 바꾸지 않게(캡처 크기 고정)
	var title: Node = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	for i in 3:
		await process_frame
	if OS.get_environment("CURSOR") != "":
		title.cursor = int(OS.get_environment("CURSOR"))
	if OS.get_environment("MENU") == "1" or OS.get_environment("CONFIRM") == "1":
		title._open_menu()
		if OS.get_environment("CONFIRM") == "1":
			title._choose("reset")
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	for s in SaveData.STARTERS:
		SaveData.reset_slot(s)
	quit()
