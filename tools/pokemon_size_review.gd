extends SceneTree

const OUT="res://docs/pokemon_sizes/"
var stage: Comparison

class Comparison:
	extends Node2D
	var mons: Array[Mon]=[]
	var cols:=4
	var title:="원작 키·몸길이 기준 8단계"
	func _draw() -> void:
		draw_rect(Rect2(0,0,512,400),Color("edf0d9"))
		PixelUi.text(self,Vector2(16,8),title)
		PixelUi.text(self,Vector2(16,26),"같은 화면 배율 · 바닥선 일치 · 게임에서 사용하는 실제 스프라이트",true)
		var cell:=512.0/float(cols)
		var pitch:=154.0 if cols==4 else 112.0
		var baseline:=109.0 if cols==4 else 67.0
		for i in mons.size():
			var m:=mons[i];var x:=(float(i%cols)+0.5)*cell;var y:=48.0+float(i/cols)*pitch
			draw_rect(Rect2(x-cell*0.5+3,y,cell-6,pitch-4),Color("dbe5be"))
			draw_line(Vector2(x-cell*0.5+8,y+baseline),Vector2(x+cell*0.5-8,y+baseline),Color("99b28b"),1)
			PixelUi.text(self,Vector2(x,y+3),"%d단계 · %s"%[m.size_tier,PokemonSize.label(m.size_tier)],true,PixelUi.INK,PixelUi.INK_SHADOW,HORIZONTAL_ALIGNMENT_CENTER)
			PixelUi.text(self,Vector2(x,y+baseline+9),m.display_name(),false,PixelUi.INK,PixelUi.INK_SHADOW,HORIZONTAL_ALIGNMENT_CENTER)
			PixelUi.text(self,Vector2(x,y+baseline+26),"%.1fm · 화면 %dpx"%[float(SpeciesDB.get_species(m.species_id).height_dm)/10.0,int(m.display_span)],true,PixelUi.INK,PixelUi.INK_SHADOW,HORIZONTAL_ALIGNMENT_CENTER)

func _init() -> void:call_deferred("run")

func comparison(ids: Array, name: String, cols: int=4) -> void:
	if is_instance_valid(stage):stage.free()
	stage=Comparison.new();stage.cols=cols
	if cols==3:stage.title="진화에 따라 달라지는 몸집"
	root.add_child(stage)
	var cell:=512.0/float(cols)
	var pitch:=154.0 if cols==4 else 112.0
	var baseline:=109.0 if cols==4 else 67.0
	for i in ids.size():
		var mon:=Mon.new();mon.setup(ids[i],36,Mon.TEAM_ENEMY)
		mon.facing=Vector2.RIGHT
		mon.position=Vector2((float(i%cols)+0.5)*cell,48.0+float(i/cols)*pitch+baseline-mon.feet_offset())
		stage.mons.append(mon);stage.add_child(mon)
	stage.queue_redraw()
	for _i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func run() -> void:
	OS.set_environment("LANG_CODE","ko")
	OS.set_environment("CAP_VIEW","512x368")
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await comparison(["caterpie","charmander","bulbasaur","charmeleon","charizard","lapras","dragonair","onix"],"eight_tiers")
	root.content_scale_size=Vector2i(512,400);DisplayServer.window_set_size(root.content_scale_size)
	await comparison(["charmander","charmeleon","charizard","bulbasaur","ivysaur","venusaur","squirtle","wartortle","blastoise"],"starter_evolutions",3)
	print("Size comparison: eight native tiers and three evolution families captured at equal scale")
	stage.free();quit()
