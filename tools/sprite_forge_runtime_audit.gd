extends SceneTree

class AuditInput:
	extends RefCounted
	var direction := Vector2.RIGHT
	func move_dir(_w): return direction
	func aim_point(w): return w.player.position+direction*48
	func want_skill(_i,_w): return false
	func want_jump(_w): return false
	func want_dodge(_w): return false
	func want_item(_w): return false

func _init() -> void: call_deferred("run")

func run() -> void:
	OS.set_environment("BOT","1")
	SaveData.path="user://save_sprite_forge_audit.cfg"
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var report := []
	for species in ["charmander","bulbasaur","squirtle","pikachu"]:
		var input := AuditInput.new()
		var world := World.new()
		root.add_child(world)
		world.setup(7,species,12,["scratch"],input)
		world.player.repel_steps=100000
		world.player.position=Vector2(Arena.bounds().end.x-world.player.radius,Arena.center().y)
		world.player.vel=Vector2.ZERO
		var at := world.player.position
		var before := world.player._walk_visual_time
		var elapsed_before := world.player.anim_t
		for i in 15: world.step(1.0/60.0)
		report.append({"species":species,"case":"blocked_right_boundary",
			"distance":world.player.position.distance_to(at),
			"walk_phase_before":before,"walk_phase_after":world.player._walk_visual_time,
			"animation_time_delta":world.player.anim_t-elapsed_before,
			"velocity_after":[world.player.vel.x,world.player.vel.y],
			"polished_clock":world.player.uses_motion_polish()})
		world.free()
	FileAccess.open("res://docs/sprite_forge_audit/runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit()
