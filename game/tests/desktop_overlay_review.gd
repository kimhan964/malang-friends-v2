extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preview=Preview.new()
	root.add_child(preview)
	if not preview.is_node_ready(): await preview.ready
	preview.looping=false
	var app=preview.app
	var room=app.furniture_room
	room.set_process(false)
	app.delivery_queue.clear()
	app.pending_gift_visits.clear()
	app.delivery_delay=9999
	for piece in room.pieces.values(): piece.hide()
	for prop in app.props.values(): prop.hide()
	var id="table"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-piece="): id=argument.trim_prefix("--review-piece=")
	room.place(id,Vector2(750,470),false)
	var piece=room.pieces[id]
	piece.position=Vector2i(750,470)
	piece.show()
	var m=app.pet.motion
	m.cancel_play()
	m.autonomy=false
	m.resting=false
	m.move_to(room.destination_point("home_tea" if id=="table" else "home_"+id)-Vector2(16,0))
	if OS.get_cmdline_user_args().has("--review-drag"):
		m.move_to(room.destination_point("home_tea" if id=="table" else "home_"+id)+Vector2(260,30))
		app.pet.dropped_on_desktop.connect(func(point): print("OVERLAY_DROP accepted=",app.pet.furniture_drop_accepted," phase=",m.phase," visit=",m.visit_id," feet=",point))
		m.visited.connect(func(key): print("OVERLAY_ARRIVED ",key," phase=",m.phase))
		var input_timer=Timer.new()
		input_timer.wait_time=2
		input_timer.autostart=true
		input_timer.timeout.connect(func(): print("OVERLAY_POINTER cursor=",DisplayServer.mouse_get_position()," feet=",m.feet," passthrough=",app.pet.mouse_passthrough," held=",m.held))
		root.add_child(input_timer)
	app.refresh_destinations()
	app.request_layer_order()
	print("OVERLAY_REVIEW_READY native=",preload("res://scripts/native_mouse.gd").available())
	if OS.get_cmdline_user_args().has("--replay-drag"):
		await create_timer(1).timeout
		app.pet.set_process(false)
		var start=m.feet-Vector2(0,48)
		var end=room.destination_point("home_tea" if id=="table" else "home_"+id)-Vector2(0,48)
		app.pet.begin_pointer(start)
		for step in range(121):
			app.pet.move_pointer(start.lerp(end,step/120.0),1.0/60)
			app.pet.advance_frame(1.0/60)
			await process_frame
		app.pet.release_pointer()
		for step in range(600):
			app.pet.advance_frame(1.0/60)
			await process_frame
			if m.phase=="home_use" and m.elapsed>=2.8: break
		print("OVERLAY_REPLAY_RESULT phase=",m.phase," id=",m.visit_id," accepted=",app.pet.furniture_drop_accepted)
	create_timer(300).timeout.connect(quit)
