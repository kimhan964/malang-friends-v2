extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
class MemoryState extends State:
	func load_game() -> void: pass
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,msg: String) -> void:
	if not ok: failures.append(msg);push_error(msg)
func _initialize() -> void:
	if not preload("res://tests/pack_fixture.gd").mount(): quit(1);return
	call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("commerce/enabled",false)
	var app=Main.new();app.state=MemoryState.new()
	app.state.guide_seen=true;app.state.play_affection={"0":200}
	root.add_child(app);await process_frame
	app.set_process(false);app.pet.set_process(false)
	var room=app.furniture_room;room.set_process(false)
	app.delivery_queue.clear()
	for id in room.pieces.keys(): room.remove_piece(id)
	for prop in app.props.values(): prop.hide()
	var m=app.pet.motion
	for species in range(16):
		m.species=species
		m.autonomy=false
		for id in ["toy_mouse","toy_ball"]:
			m.cancel_play();room.toy_play.cancel()
			m.move_to(Vector2(600,m.bounds.get_center().y))
			room.place(id,Vector2(650,300),false)
			room.pieces[id].set_process(false)
			check(room.use_piece(id),"use "+id)
			var original=Vector2(room.pieces[id].position)
			var pet_start=m.feet
			var following=false;var finished=false;var moved=0.0;var elapsed=0.0
			var leg_target=Vector2.ZERO
			var last_stage=""
			for tick in range(2400):
				var prior=m.feet
				m.advance(1.0/60)
				room.toy_play.advance(room,1.0/60)
				if room.toy_play.stage=="follow":
					if last_stage!="follow": leg_target=m.target
					else: check(m.target.is_equal_approx(leg_target),"pursuit target jitter "+str(species))
				last_stage=room.toy_play.stage
				elapsed+=1.0/60
				following=following or (room.toy_play.stage=="follow" and m.phase=="visit")
				moved=maxf(moved,Vector2(room.pieces[id].position).distance_to(original))
				check(m.feet.distance_to(prior)<8,"pet teleported "+str(species))
				if following and not room.toy_play.busy(): finished=true;break
			check(following and moved>30 and m.feet.distance_to(pet_start)>30,"no pursuit "+str(species)+id)
			check(finished and elapsed<35,"interaction stuck "+str(species)+id)
			room.remove_piece(id)
	# A grab must stop the toy without moving the character.
	m.cancel_play();m.phase="idle";room.place("toy_mouse",Vector2(650,300),false)
	room.toy_play.arrived(room,"home_toy_mouse")
	m.visit_id="home_toy_mouse";m.held=true
	room.toy_play.advance(room,.1)
	check(not room.toy_play.busy(),"grab did not cancel pursuit")
	m.held=false;m.species=0;m.autonomy=false
	for key in ["toy_mouse","toy_ball"]:
		m.cancel_play();room.toy_play.cancel()
		room.place(key,Vector2(650,300),false)
		var piece=room.pieces[key];piece.set_process(false)
		var original=piece.position
		room.toy_play.launch_user(room,key,Vector2(210,0))
		var fixed=m.target
		for tick in range(30):
			room.toy_play.advance(room,1.0/60)
			check(m.target.is_equal_approx(fixed),"user toy target jitter")
		check(piece.position.x>original.x+40,"user toy did not move independently")
		for tick in range(120): room.toy_play.advance(room,1.0/60)
		check(room.toy_play.user_motion.settled,"user toy friction did not stop")
		var stopped=piece.position
		room.toy_play.arrived(room,"home_"+key)
		for tick in range(60): room.toy_play.advance(room,1.0/60)
		check(not room.toy_play.busy(),"user toy interaction did not finish")
		check(piece.position==stopped,"settled toy drifted")
		if key=="toy_ball": check(absf(piece.roll_angle)>.5,"yarn did not rotate")
		room.remove_piece(key)
	app.queue_free();await process_frame
	print("TOY PLAY: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
