extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for file in ["scripts/typing_companion.gd","assets/typing-rabbit-v1/idle.png","assets/typing-rabbit-v1/left.png","assets/typing-rabbit-v1/right.png"]:
		assert(FileAccess.get_file_as_bytes("res://"+file)==FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+file),"Installed resource mismatch: "+file)
	var app=preload("res://tests/typing_visual_review.gd").FakeApp.new()
	root.add_child(app)
	var m=preload("res://scripts/desktop_pet_motion.gd").new()
	m.species=0
	m.growth_stage=2
	m.growth_scale=1
	app.pet={"species":0,"motion":m}
	var widget=preload("res://scripts/typing_companion.gd").new()
	widget.app=app
	app.add_child(widget)
	widget.input_bridge.stop()
	widget.paused=true
	assert(widget.typing_frames.size()==3 and widget.typing_sprite.visible)
	assert(not widget.view.visible)
	for key in widget.keys: assert(not key.visible)
	var zoom=widget.typing_sprite.scale
	var anchor=widget.typing_sprite.position
	var poses={}
	for i in range(300):
		widget.pending=true
		widget._process(1.0/60.0)
		poses[widget.typing_index]=true
		assert(widget.typing_sprite.scale==zoom and widget.typing_sprite.position==anchor)
		assert(widget.typing_sprite.rotation==0)
		assert(widget.typing_sprite.texture==widget.typing_frames[widget.typing_index])
	assert(poses.size()==3)
	widget.pending=false
	widget._process(1)
	assert(widget.typing_index==0)
	widget.queue_free()
	await process_frame
	print("GENERATED_TYPING_RABBIT_PASS: 3 full images; 300 input samples; fixed size/anchor; idle return")
	quit()
