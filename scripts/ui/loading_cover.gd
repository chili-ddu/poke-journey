extends Control
## Lightweight loading feedback. No battle world, map or intro DOM is created.
var clock := 0.0

func _process(dt: float) -> void:
	clock+=dt
	queue_redraw()

func _draw() -> void:
	paint(self,size,clock,WebContent.message)

static func paint(canvas: CanvasItem,area: Vector2,time: float,message: String="") -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,area),Color("080b10"))
	var icon := PixelUi.ui_tex("plat/sum_ball")
	var at := Vector2(area.x-36,area.y-25)
	if icon!=null:
		var bounce := floorf(absf(sin(time*4.0))*2.0)
		canvas.draw_set_transform(at+Vector2(8,8-bounce),time*3.0)
		canvas.draw_texture_rect(icon,Rect2(-8,-8,16,16),false)
		canvas.draw_set_transform(Vector2.ZERO)
	if not message.is_empty():
		PixelUi.text(canvas,Vector2(area.x*0.5,area.y-45),message,true,Color.WHITE,Color.BLACK,HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		var alpha := 0.35+0.65*maxf(0.0,sin(time*5.0-float(i)*0.9))
		canvas.draw_rect(Rect2(at+Vector2(18+i*4,10),Vector2(2,2)),Color(0.9,0.94,1.0,alpha))
