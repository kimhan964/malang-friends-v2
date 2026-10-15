extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var app=preload("res://tests/typing_visual_review.gd").FakeApp.new()
	root.add_child(app)
	var m=preload("res://scripts/desktop_pet_motion.gd").new()
	m.species=8
	app.pet={"species":8,"motion":m}
	var widget=preload("res://scripts/typing_companion.gd").new()
	widget.app=app
	app.add_child(widget)
	widget.set_process(false)
	widget.input_bridge.stop()
	preload("res://scripts/native_mouse.gd").apply(widget,false,true)
	await process_frame
	var settings: Button
	for node in widget.root.get_children():
		if node is Button: settings=node
	for zoom in range(3):
		app.state.typing_size=zoom
		widget.place()
		await process_frame
		var p=settings.get_global_rect().get_center()
		var move=InputEventMouseMotion.new()
		move.position=p
		widget.push_input(move,true)
		for down in [true,false]:
			var click=InputEventMouseButton.new()
			click.position=p
			click.button_index=MOUSE_BUTTON_LEFT
			click.pressed=down
			widget.push_input(click,true)
			await process_frame
		print("SETTINGS_CLICK ",zoom," center=",p," button_rect=",settings.get_global_rect()," menu_visible=",widget.menu.visible)
		widget.menu.hide()
		await process_frame
	widget.queue_free()
	await process_frame
	quit()
