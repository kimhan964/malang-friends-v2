extends Window

var food: Texture2D
var in_reach=false
var drawing: Node2D

class FoodDrawing extends Node2D:
	var owner_window
	func _draw() -> void:
		var dish: Texture2D=owner_window.food
		if dish==null: return
		if owner_window.in_reach:
			draw_arc(Vector2(40,40),33,0,TAU,48,Color(.72,.88,.55,.9),3,true)
		var extent=dish.get_size()
		extent*=minf(66.0/extent.x,60.0/extent.y)
		draw_texture_rect(dish,Rect2(Vector2(40,40)-extent*.5,extent),false)

func _init() -> void:
	visible=false
	force_native=true
	borderless=true
	transparent=true
	transparent_bg=true
	always_on_top=true
	unfocusable=true
	unresizable=true
	transient=false
	exclusive=false
	mouse_passthrough=true
	size=Vector2i(80,80)

func _ready() -> void:
	title="집어 든 음식 · 입 근처에서 놓기"
	drawing=FoodDrawing.new()
	drawing.owner_window=self
	drawing.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(drawing)
	show()
	preload("res://scripts/native_mouse.gd").apply(self,true,true)

func follow_cursor(cursor: Vector2, ready_to_feed: bool) -> void:
	if in_reach!=ready_to_feed:
		in_reach=ready_to_feed
		drawing.queue_redraw()
	var target=Vector2i(cursor)-size/2
	if position!=target: position=target
