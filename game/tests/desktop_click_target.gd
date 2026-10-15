extends SceneTree
# Separate OS process: a same-process Godot button cannot catch this regression.
var clicks=0
var counter: Button
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.title="Desktop click-through regression target"
	root.transparent=false
	root.transparent_bg=false
	root.borderless=false
	root.size=Vector2i(700,400)
	root.position=Vector2i(430,270)
	var background=ColorRect.new()
	background.color=Color("f4f0e8")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	counter=Button.new()
	counter.position=Vector2(90,95)
	counter.size=Vector2(520,160)
	counter.text="DESKTOP BUTTON — CLICKS: 0"
	counter.pressed.connect(func():
		clicks+=1
		counter.text="DESKTOP BUTTON — CLICKS: %d"%clicks
		print("CROSS_PROCESS_CLICK ",clicks))
	root.add_child(counter)
	create_timer(600).timeout.connect(quit)
