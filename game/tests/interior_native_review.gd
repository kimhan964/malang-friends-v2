extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
var failures=[]
var folder="res://interior-eating-review-2026-10-05"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	preview=Preview.new()
	root.add_child(preview)
	if not preview.is_node_ready(): await preview.ready
	preview.set_process(false)
	preview.app.set_process(false)
	preview.looping=false
	var app=preview.app
	var room=app.furniture_room
	var screen=app.usable_screen()
	for id in room.Catalog.ITEMS:
		var i=room.Catalog.ITEMS.keys().find(id)
		room.place(id,Vector2(screen.position)+Vector2(screen.size.x*.5-250+i*145,screen.size.y*.65),false)
		var before=room.pieces.size()
		room.place(id,Vector2.ZERO,false)
		if before!=room.pieces.size(): failures.append("duplicate "+id)
		var piece=room.pieces[id]
		var original=piece.position
		piece.press_position=Vector2(original)
		piece.press_cursor=Vector2(50,50)
		piece.move_dragged_to(Vector2(150,100))
		if piece.position!=original+Vector2i(100,50): failures.append("drag offset "+id)
		piece.position=original
	room.save()
	room.open()
	await process_frame
	await RenderingServer.frame_post_draw
	room.panel.get_texture().get_image().save_png(folder+"/furniture-panel.png")
	room.panel.hide()
	for test in [[0,false],[0,true],[1,false],[14,false]]:
		preview.selected=test[0]
		preview.baby=test[1]
		preview.select_pet()
		var pet=app.pet
		var m=pet.motion
		m.cancel_play()
		m.autonomy=false
		m.resting=true
		m.phase="eat"
		m.action_left=5.5
		m.elapsed=0
		m.visit_id="hand_feed"
		m.food_id=preload("res://scripts/animal_catalog.gd").DEFAULT_MEALS[m.species]
		var count=0
		var next_capture=.05
		var began=Time.get_ticks_msec()
		while m.phase=="eat" and Time.get_ticks_msec()-began<10000:
			await process_frame
			await RenderingServer.frame_post_draw
			if m.elapsed>=next_capture:
				var at=Vector2i(m.feet)-pet.position-Vector2i(128,190)
				pet.get_texture().get_image().get_region(Rect2i(at,Vector2i(256,224))).save_png(folder+"/eat-%d-%s-%02d.png"%[test[0],test[1],count])
				next_capture+=.5
				count+=1
		if m.phase=="eat": failures.append("stuck meal")
		print("NATIVE_MEAL ",test," captures=",count)
	preview.selected=0
	preview.baby=false
	preview.select_pet()
	room.open()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"furniture":room.pieces.keys()}))
	print("INTERIOR_NATIVE failures=",failures)
	if not OS.get_cmdline_user_args().has("--stay"): quit(0 if failures.is_empty() else 1)
