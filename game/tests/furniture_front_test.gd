extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
class MemoryState extends State:
	func load_game() -> void: pass
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,text: String) -> void:
	if not ok: failures.append(text);push_error(text)
func _initialize() -> void:
	if not preload("res://tests/pack_fixture.gd").mount(): quit(1);return
	call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("commerce/enabled",false)
	var app=Main.new()
	app.state=MemoryState.new()
	app.state.guide_seen=true
	app.state.play_affection={"0":200}
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.pet.set_process(false)
	var room=app.furniture_room
	room.set_process(false)
	for id in room.Catalog.ITEMS: room.place(id,Vector2(550,600),false)
	for mode in ["floor","desktop"]:
		app.set_activity_space(mode)
		for mirrored in [false,true]:
			for p in room.pieces.values(): p.set_mirrored(mirrored)
			for id in room.HOME_IDS:
				var p=room.pieces[room.HOME_IDS[id]]
				var at=room.destination_point(id)
				var front=p.ground_point()
				check(at.y>=front.y,"approach behind furniture "+mode+"/"+id)
				check(absf(at.x-front.x)<(p.size.x+64 if p.item_id in room.arrivals.ITEMS else p.size.x+64),"side approach "+id)
				check(app.pet.motion.bounds.grow(.1).has_point(at),"outside bounds "+id)
				if p.item_id in ["plant_stand","shelf","dresser","vanity","aquarium","lamp","tv","record_player","turntable"]:
					check(absf(at.x-front.x)>=p.sprite.texture.get_width()*absf(p.sprite.scale.x)*.5+30,"face occluded by tall furniture "+id)
	app.set_activity_space("floor")
	var floor_y=preload("res://scripts/living_space.gd").ground(Rect2(app.usable_screen()))
	for piece in room.pieces.values():
		if not room.Catalog.is_wall(piece.item_id): check(absf(piece.ground_point().y-floor_y)<1.1,"furniture support floating: "+piece.item_id)
	for species in range(16):
		var m=Motion.new()
		m.configure(Rect2(app.usable_screen()),Vector2(350,900))
		m.species=species
		m.autonomy=false
		m.floor_space=true
		m.bounds=app.pet.motion.bounds
		m.move_to(Vector2(350,m.bounds.get_center().y))
		m.visit(Vector2(950,m.feet.y),"relax")
		for tick in range(1200): m.advance(1.0/60)
		check(absf(m.feet.x-950)<1,"blocked crossing furniture "+str(species))
	# A furniture press must request front-order restoration before release.
	app.layers_dirty=false
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=Vector2(20,20)
	room.pieces.sofa.handle_input(press)
	check(app.layers_dirty,"press did not restore pet layer")
	room.pieces.sofa.dragging=false
	# Automatic motion changes native stacking too, even without mouse input.
	await process_frame
	app.layers_dirty=false
	var moving_piece=room.pieces.sofa
	moving_piece.position.x+=12
	moving_piece._process(0.0)
	check(app.layers_dirty,"automatic furniture move did not request layer repair")
	check(app.layer_restore_queued,"layer repair not deferred until native moves finish")
	app.queue_free()
	await process_frame
	print("FURNITURE FRONT: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
