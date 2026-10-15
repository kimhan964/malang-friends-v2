extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
class ReviewView extends "res://scripts/desktop_pet_view.gd":
	func prewarm_current_art() -> void: pass
var views=[]
var clock=0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.title="복슬복슬펫 · 현재 체형 의상 점검"
	root.size=Vector2i(840,800)
	root.position=Vector2i(350,100)
	root.borderless=false
	root.transparent=false
	var bg=ColorRect.new()
	bg.color=Color("faf8f3")
	bg.size=root.size
	root.add_child(bg)
	for row in range(3):
		for style in [1,2,3]:
			var m=Motion.new()
			m.species=[0,1,14][row]
			m.growth_stage=2
			m.growth_scale=1
			m.outfit_style=style
			m.rabbit_pilot=row==0
			m.smooth_walk_enabled=row>0
			m.phase="wander"
			var view=ReviewView.new()
			view.motion=m
			view.scale=Vector2.ONE*1.4
			view.position=Vector2((style-1)*275-38,row*232-30)
			root.add_child(view)
			views.append(view)
			var label=Label.new()
			label.text=["토끼","수달","코알라"][row]+" · "+["케이프","조끼","스웨터"][style-1]
			label.position=Vector2((style-1)*275+32,row*232+12)
			label.add_theme_color_override("font_color",Color("59564f"))
			root.add_child(label)
	create_timer(300).timeout.connect(quit)
func _process(delta: float) -> bool:
	clock+=delta
	for view in views:
		var m=view.motion
		m.elapsed=clock
		m.walk_phase=fposmod(clock/2.4,1)
		view.refresh(delta)
	return false
