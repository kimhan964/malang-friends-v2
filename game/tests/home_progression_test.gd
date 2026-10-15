extends SceneTree
const State=preload("res://scripts/pet_state.gd")
const Main=preload("res://scripts/main.gd")
var failures=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state=State.new()
	state.save_path="user://home-progress-test-only.json"
	for species in range(16):
		for action in [0,1,11,15,16,23,30,34,35]: check(state.can_action(species,action),"basic communication locked")
		for food in range(32): check(state.food_available(species,food),"meal locked")
	check(state.furniture_available("table") and state.furniture_available("sofa") and state.furniture_available("play_rug"),"starter home")
	check(not state.furniture_available("shelf"),"premature furniture unlock")
	state.add_affection(0,3)
	state.add_affection(1,3)
	check(state.furniture_available("shelf"),"shared home threshold")
	check(state.home_owned.get("shelf",false),"permanent ownership")
	var old=FileAccess.open(state.save_path,FileAccess.WRITE)
	old.store_string(JSON.stringify({"version":6,"guide_seen":true,"furniture":{"tv":[400,500]},"affection":{"0":4},"growth":{"0":36},"layout":{"water":[100,200]}}))
	old.close()
	var migrated=State.new()
	migrated.save_path=state.save_path
	migrated.load_game()
	check(migrated.furniture_available("tv"),"existing furniture lost")
	check(migrated.growth_stage(0)==2 and migrated.home_points()==4,"existing progress lost")
	check(not migrated.guide_seen,"updated guide not offered")
	migrated.furniture.clear()
	migrated.home_initialized=true
	migrated.save_game()
	var restored=State.new()
	restored.save_path=state.save_path
	restored.load_game()
	check(restored.furniture_available("tv"),"stored furniture ownership lost")
	# Run actual app with isolated state, no account flow and no user save writes.
	ProjectSettings.set_setting("commerce/enabled",false)
	var app=Main.new()
	app.state.save_path="user://home-world-test-only.json"
	DirAccess.remove_absolute(app.state.save_path)
	app.state.guide_seen=true
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.pet.set_process(false)
	app.furniture_room.set_process(false)
	var placement_button=app.pet.menu.find_child("OpenFurniture",true,false)
	check(placement_button!=null,"missing prominent furniture button")
	placement_button.pressed.emit()
	await process_frame
	await process_frame
	check(is_instance_valid(app.furniture_room.panel) and app.furniture_room.panel.visible,"menu button did not open furniture window")
	app.furniture_room.panel.hide()
	for id in [0,1,2,11,16,22,23,29,30,34,35,36,37]:
		check(app.pet.menu.get_item_index(id)==-1,"retired action visible "+str(id))
	app.pet.motion.cancel_play()
	app.activity(36)
	check(app.pet.motion.phase=="idle","retired shortcut started action")
	app.activity(100)
	check(app.pet.motion.phase=="idle","food selection forced eating")
	var previous_threshold=-1
	for row in app.state.unlock_rows(0):
		check(row.threshold>=previous_threshold,"unlock order is not ascending")
		check(row.id.begins_with("home_") and not row.category.is_empty(),"non-item unlock")
		previous_threshold=row.threshold
	for id in ["table","sofa","play_rug"]: check(app.furniture_room.pieces.has(id),"missing starter "+id)
	app.refresh_destinations()
	for id in State.RETIRED_PROPS:
		check(not app.props.has(id) or not app.props[id].visible,"retired prop visible "+id)
		check(not app.delivery_queue.has(id),"retired prop delivery "+id)
	for destination in app.pet.motion.destinations: check(destination.id not in State.RETIRED_PROPS,"retired destination")
	app.furniture_room.use_piece("table","drink")
	check(app.pet.motion.visit_id=="home_water","water not routed to table")
	app.furniture_room.use_piece("table","eat")
	check(app.pet.motion.visit_id=="home_food","food not routed to table")
	app.furniture_room.remove_piece("table")
	check(not app.furniture_room.use_piece("table","drink"),"missing table must not start drinking")
	check(not app.props.has("water"),"pond restored as fallback")
	app.furniture_room.place("tv")
	check(not app.furniture_room.pieces.has("tv"),"locked furniture placement bypass")
	app.furniture_room.open()
	check(app.furniture_room.buttons.tv.disabled,"locked furniture button enabled")
	app.state.add_affection(0,6)
	check(not app.furniture_room.buttons.shelf.disabled,"unlock did not refresh UI")
	app.furniture_room.place("shelf")
	check(app.furniture_room.pieces.has("shelf"),"unlocked furniture cannot place")
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://builds/home-reframe-review")
		app.furniture_room.panel.get_texture().get_image().save_png("res://builds/home-reframe-review/furniture.png")
	app.queue_free()
	await process_frame
	for path in [state.save_path,"user://home-world-test-only.json"]: DirAccess.remove_absolute(path)
	print("HOME PROGRESSION: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
