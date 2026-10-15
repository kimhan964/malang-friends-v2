extends Node
var app
var checks=[]
var failed=false
var trace=[]
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failed=true;push_error("SCENE_CHECK_FAILED "+label)
func output() -> String:
	var path=OS.get_executable_path().get_base_dir().path_join("검수/바닥과생쥐")
	DirAccess.make_dir_recursive_absolute(path)
	return path
func capture(room,name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var origin=Vector2i(app.pet.motion.bounds.get_center().x-340,app.pet.motion.bounds.end.y-150)
	var result=Image.create(680,190,false,Image.FORMAT_RGBA8)
	result.fill(Color("faf8f3"))
	var rect=Rect2i(origin,result.get_size())
	var windows=room.ordered_pieces();windows.append(app.pet)
	for window in windows:
		if not window.visible: continue
		var image: Image=window.get_texture().get_image()
		var part=Rect2i(window.position,image.get_size()).intersection(rect)
		if part.has_area(): result.blend_rect(image,Rect2i(part.position-window.position,part.size),part.position-origin)
	result.save_png(output().path_join(name+".png"))
func run() -> void:
	await get_tree().process_frame
	app.set_process(false)
	var room=app.furniture_room
	room.set_process(false)
	app.pet.set_process(false)
	app.state.hidden.clear();app.expanded_props=true;app.decorating=true
	for species in range(16):
		await app.choose_friend(species)
		app.pet.set_process(false)
		app.apply_prop_visibility()
		for id in app.state.RETIRED_PROPS: check(not app.props[id].visible,"no pixel prop %d/%s"%[species,id])
		app.queue_delivery("plant")
		check("plant" not in app.delivery_queue,"no legacy plant arrival "+str(species))
		app.refresh_destinations()
		for destination in app.pet.motion.destinations: check(destination.id not in app.state.RETIRED_PROPS,"no retired visit "+str(destination.id))
	app.decorating=false
	await app.choose_friend(3)
	var m=app.pet.motion
	app.pet.set_process(false)
	m.autonomy=false;m.resting=false;m.held=false;m.carried=false;m.cancel_play();m.joy_left=0;m.voice_left=0
	for prop in app.props.values(): prop.hide()
	room.place("play_rug",Vector2(600,450),false)
	room.place("toy_mouse",Vector2(700,450),false)
	room.place("sofa",Vector2(1050,450),false)
	for piece in room.pieces.values(): piece.hide();piece.set_process(false)
	var mouse=room.pieces.toy_mouse
	var rug=room.pieces.play_rug
	var sofa=room.pieces.sofa
	for piece in [mouse,rug]: piece.show()
	var center=m.bounds.get_center().x
	mouse.position.x=roundi(center-120)
	rug.position.x=roundi(center-150)
	room.floor_piece(mouse);room.floor_piece(rug)
	check(rug.sprite.texture.get_width()>rug.sprite.texture.get_height()*2.5,"rug lies in flattened floor perspective")
	rug.stack_order=999;sofa.stack_order=-999
	check(room.ordered_pieces()[0]==rug,"rug stays underneath every furniture layer")
	check(absf(room.destination_point("home_play_rug").y-rug.art_point(Vector2(.5,.64)).y)<1,"pet stands on rug top surface")
	var start=mouse.position
	var max_step=0.0
	room.toy_play.cancel()
	room.mouse_roam.stop(mouse);room.mouse_roam.pause=0;room.mouse_roam.rng.seed=912
	for i in range(1800):
		var previous=mouse.position
		room.mouse_roam.advance(room,1.0/60)
		max_step=maxf(max_step,Vector2(mouse.position-previous).length())
		check(absf(mouse.ground_point().y-preload("res://scripts/living_space.gd").ground(Rect2(app.usable_screen())))<2,"mouse floor contact "+str(i))
	check(room.mouse_roam.legs>=4,"mouse moves independently with pauses")
	check(max_step<=2,"mouse smooth subpixel integration")
	var held_at=mouse.position
	m.held=true
	for i in range(60): room.mouse_roam.advance(room,1.0/60)
	check(mouse.position==held_at,"pickup pauses mouse")
	m.held=false
	room.use_piece("toy_mouse")
	var visit_at=mouse.position
	var fixed_target=m.target
	for i in range(120): room.mouse_roam.advance(room,1.0/60)
	check(mouse.position==visit_at and m.target==fixed_target,"pet approach freezes toy and destination")
	room.toy_play.cancel();m.cancel_play()
	sofa.show();sofa.position=Vector2i(mouse.position.x+mouse.size.x+22,mouse.position.y-45)
	check(not room.mouse_roam.clear_lane(room,mouse,Vector2(mouse.position)+Vector2(120,0)),"mouse avoids sofa collision")
	sofa.hide()
	var travel=[]
	for rate in [30,60,144]:
		mouse.position=start;mouse.set_mirrored(false)
		room.mouse_roam.stop(mouse);room.mouse_roam.pause=0;room.mouse_roam.rng.seed=912;room.mouse_roam.direction=1
		for i in range(rate*2): room.mouse_roam.advance(room,1.0/rate)
		travel.append(mouse.position.x)
	check(absf(travel.max()-travel.min())<=3,"mouse travel independent of display frame rate")
	mouse.position.x=roundi(m.bounds.end.x-8-mouse.size.x*.5)
	room.mouse_roam.stop(mouse);room.mouse_roam.pause=0;room.mouse_roam.direction=1
	check(room.mouse_roam.begin_leg(room,mouse) and room.mouse_roam.goal.x<mouse.position.x and mouse.mirrored,"screen edge turns mouse to face its actual travel")
	# Real native rendered playback of the same simulation used by normal play.
	mouse.position=start;room.mouse_roam.stop(mouse);room.mouse_roam.pause=0;room.mouse_roam.direction=1;room.mouse_roam.rng.seed=913
	m.feet=room.destination_point("home_play_rug");m.target=m.feet
	room.use_piece("play_rug");m.feet=m.target;m.phase="home_use";m.elapsed=0;m.visit_id="home_play_rug"
	app.pet.advance_frame(0)
	await capture(room,"rug-under-pet")
	for i in range(360):
		if i==180:
			sofa.position.x=roundi(center+190);room.floor_piece(sofa);sofa.show()
		room.mouse_roam.advance(room,1.0/30)
		mouse._process(1.0/30)
		app.pet.advance_frame(1.0/30)
		trace.append({"frame":i,"x":mouse.position.x,"y":mouse.position.y,"speed":mouse.roam_speed,"mirrored":mouse.mirrored})
		if DisplayServer.get_name()!="headless": await capture(room,"mouse-%03d"%i)
	var file=FileAccess.open(output().path_join("scene-validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks,"trace":trace,"max_mouse_step":max_step,"frame_rate_positions":travel},"\t"))
	print("SCENE_VALIDATED ",checks.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)
