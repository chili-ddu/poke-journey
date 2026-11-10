class_name LootItem
extends Node2D
const ItemPalette = preload("res://scripts/view/item_palette.gd")

# Inventory is committed before the cosmetic flight: save/reload cannot duplicate loot.
const FALL_TIME := 0.38
const FLY_TIME := 0.46
const MERGE_TIME := 0.10
var merge_target: LootItem
var merge_age := -1.0
var merge_height := 0.0
var item_id := ""
var count := 1
var texture: Texture2D
var age := 0.0
var ttl := 30.0
var flight := -1.0
var collector: Player
var start := Vector2.ZERO
var draw_at := Vector2.ZERO
var height := 0.0
var draw_scale := 1.0
var alpha := 1.0
var done := false

func setup(id: String,at: Vector2) -> void:
	item_id=id
	texture=ItemPalette.texture(ItemDB.icon(id))
	position=at
	draw_at=at
	visibility_layer=1 # upright Sprite3D; never bake onto the floor overlay.
	update_visual(0.0)

func collect(player: Player,amount: int=1) -> void:
	collector=player
	count=amount
	start=draw_at
	flight=0.0
	update_visual(0.0)

func merge_into(leader: LootItem) -> void:
	start=draw_at
	merge_height=height
	merge_target=leader
	merge_age=0.0
	flight=0.0 # Cosmetic only; never eligible for a second inventory transfer.

func update_visual(dt: float) -> void:
	age+=dt
	if merge_age>=0.0:
		merge_age+=dt
		if not is_instance_valid(merge_target) or merge_target.done:
			done=true
			return
		var t := clampf(merge_age/MERGE_TIME,0.0,1.0)
		draw_at=start.lerp(merge_target.draw_at,smoothstep(0.0,1.0,t))
		height=lerpf(merge_height,merge_target.height,t)
		draw_scale=lerpf(1.0,0.6,t)
		alpha=1.0-t
		done=t>=1.0
	elif flight>=0.0:
		flight+=dt
		var t := clampf(flight/FLY_TIME,0.0,1.0)
		var eased := t*t*(3.0-2.0*t)
		var target := collector.position if is_instance_valid(collector) else start
		draw_at=start.lerp(target,eased)
		height=4.0+18.0*sin(PI*t)+6.0*t
		draw_scale=lerpf(1.0,0.45,t*t)
		alpha=clampf((1.0-t)/0.22,0.0,1.0)
		done=t>=1.0
	else:
		draw_at=position
		var t := clampf(age/FALL_TIME,0.0,1.0)
		height=14.0*(1.0-t*t) if t<1.0 else 3.0+sin(age*4.0)
	queue_redraw()

func _draw() -> void:
	if texture==null or done:return
	var at := draw_at-position
	if flight<0.0:
		draw_set_transform(at,0.0,Vector2(1,0.4))
		draw_circle(Vector2.ZERO,4.0,Color(0,0,0,0.2))
		draw_set_transform(Vector2.ZERO)
	var size := Vector2.ONE*16.0*draw_scale
	draw_texture_rect(texture,Rect2(at-Vector2(0,height)-size*0.5,size),false,Color(1,1,1,alpha))
