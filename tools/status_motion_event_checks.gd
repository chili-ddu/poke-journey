extends SceneTree
const Motion=preload("res://tools/samples/status_motion_preview.gd")

func _init() -> void:call_deferred("run")

func pick_seed(threshold: float,below: bool) -> int:
	for value in range(1,1000):
		var r:=RandomNumberGenerator.new();r.seed=value
		if (r.randf()<threshold)==below:return value
	return 1

func count(observer,event: String) -> int:
	return observer.events.filter(func(e):return e.kind==event).size()

func run() -> void:
	OS.set_environment("BOT","1")
	SaveData.path="user://save_status_motion_event_checks.cfg"
	Mon.poison_unlocked=true;Mon.burn_unlocked=true
	var world:=World.new();root.add_child(world)
	var player:=Player.new();player.setup_player("chansey",25,["scratch"]);world.player=player;world.add_child(player)
	var view:=View3D.new();view.root3d=Node3D.new()
	var observer=Motion.new(view);observer.observe(player,0.0)
	world._cure("poison");observer.observe(player,.1)
	assert(observer.events.is_empty(),"A cure without a status must be silent")
	for kind in ["poison","burn","paralyze"]:
		if kind=="paralyze":world._paralyze(player)
		else:world._inflict_status(player,kind)
		observer.observe(player,.2)
		world._cure(kind);observer.observe(player,.3)
		world._cure(kind);observer.observe(player,.4)
		assert(count(observer,"enter_"+kind)==1 and count(observer,"clear_"+kind)==1)
	world._paralyze(player);observer.observe(player,.5)
	world.rng.seed=pick_seed(Mon.PARA_FAIL,false)
	var hp:=player.hp;var pp: Array=player.pp.duplicate()
	assert(not world.full_paralysis(player));observer.observe(player,.6)
	assert(count(observer,"paralysis_block")==0)
	world.rng.seed=pick_seed(Mon.PARA_FAIL,true)
	assert(world.full_paralysis(player));observer.observe(player,.7)
	assert(count(observer,"paralysis_block")==1 and player.hp==hp and player.pp==pp)
	world._cure("paralyze");observer.observe(player,.8)
	world.confuse(player);observer.observe(player,.9)
	world.rng.seed=pick_seed(Mon.CONFUSE_SELF_HIT,false)
	assert(not world.confusion_self_hit(player));observer.observe(player,1.0)
	assert(count(observer,"confusion_self_hit")==0 and player.hp==hp)
	world.rng.seed=pick_seed(Mon.CONFUSE_SELF_HIT,true)
	assert(world.confusion_self_hit(player));observer.observe(player,1.1)
	assert(count(observer,"confusion_self_hit")==1 and player.hp<hp)
	world._cure("confuse");observer.observe(player,1.2)
	world._apply_extra_status(player,{"sleep":1.0,"src":player});observer.observe(player,1.3)
	for i in 400:
		world._tick_status(1.0/60);observer.observe(player,1.3+float(i+1)/60)
	assert(player.sleep_t==0 and count(observer,"clear_sleep")==1)
	world.confuse(player);observer.observe(player,8.1)
	for i in 400:
		world._tick_status(1.0/60);observer.observe(player,8.1+float(i+1)/60)
	assert(player.confuse_t==0 and count(observer,"clear_confuse")==2)
	player.shiny=true
	assert(observer.wake_info(player).is_empty(),"Normal-color wake extras must not replace a shiny")
	print("STATUS EVENT CHECKS: absent/repeated cure, paralysis success/failure, confusion success/self-hit, natural wake/expiry, shiny guard passed")
	view.root3d.free();view.free();observer=null;world.free()
	Mon.poison_unlocked=false;Mon.burn_unlocked=false
	quit()
