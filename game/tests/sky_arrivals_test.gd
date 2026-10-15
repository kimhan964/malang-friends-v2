extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
class MemoryState extends State:
	func load_game() -> void: pass
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
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
	app.delivery_queue.clear()
	app.pending_gift_visits.clear()
	var m=app.pet.motion
	m.autonomy=true
	m.energy=90;m.satiety=90;m.hydration=90
	for prop in app.props.values(): prop.hide()
	for id in room.arrivals.ITEMS:
		m.cancel_play();m.phase="idle";m.resting=false
		check(room.arrivals.start(room,id),"failed arrival "+id)
		if room.arrivals.fall.is_empty(): continue
		var piece=room.pieces[id]
		var start=piece.position
		check(piece.arriving and piece.mouse_passthrough,"fall input not disabled")
		check(start.y+piece.size.y<app.usable_screen().position.y,"not above screen")
		for d in room.destinations(): check(d.id!="home_"+id,"visit midair")
		app.delivery_queue.append("acorn")
		app.delivery_delay=0
		app.advance_deliveries(1)
		check(app.falling_gifts.is_empty(),"two concurrent deliveries")
		app.delivery_queue.clear()
		m.held=true
		room.arrivals.advance(room,.5)
		check(piece.position==start,"fall not paused while held")
		m.held=false
		room.arrivals.advance(room,.7)
		check(piece.position.y>start.y and piece.arriving,"missing descent")
		room.arrivals.advance(room,.8)
		check(not piece.arriving and not piece.mouse_passthrough,"landing did not restore input")
		check(room.arrivals.pending==id,"landing lost interaction")
		room.arrivals.advance(room,.1)
		check(m.visit_id=="home_"+id and m.phase=="visit","did not approach landed object")
		m.autonomy=false
		for tick in range(1800):
			m.advance(1.0/60)
			if m.phase!="visit": break
		check(m.phase in ["home_use","playful","look","react","sniff"],"no interaction action "+id)
		if id=="alarm_clock": check(m.phase=="react" and m.reaction=="surprised","clock surprise missing")
		else: check(m.phase in ["playful","sniff"],"toy play missing")
		piece.set_active(true)
		piece._process(.25)
		check(piece.sprite.rotation!=0,"object reaction missing")
		check(not room.arrivals.start(room,id),"duplicate arrival")
		if OS.get_cmdline_user_args().has("--capture"):
			DirAccess.make_dir_recursive_absolute("res://builds/sky-arrival-review")
			app.pet.advance_frame(.4 if id=="alarm_clock" else 1.8)
			for frame in range(5): await process_frame
			await RenderingServer.frame_post_draw
			piece.get_texture().get_image().save_png("res://builds/sky-arrival-review/"+id+".png")
			app.pet.get_texture().get_image().save_png("res://builds/sky-arrival-review/"+id+"-pet.png")
			var file=FileAccess.open("res://builds/sky-arrival-review/"+id+"-scene.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"pet_position":[app.pet.position.x,app.pet.position.y],"piece_position":[piece.position.x,piece.position.y]}))
		m.autonomy=true
	var saved=State.new()
	saved.save_path="user://sky-arrival-test-only.json"
	saved.arrival_seen=app.state.arrival_seen.duplicate()
	saved.save_game()
	var restored=State.new();restored.save_path=saved.save_path;restored.load_game()
	check(restored.arrival_seen==saved.arrival_seen,"arrival repeated after restart")
	DirAccess.remove_absolute(saved.save_path)
	room.remove_piece("toy_ball")
	app.state.arrival_seen.erase("toy_ball")
	m.cancel_play();m.phase="idle";m.autonomy=true;m.resting=false
	room.arrivals.delay=0
	room.arrivals.advance(room,.1)
	check(room.arrivals.fall.get("id","")=="toy_ball","automatic unlocked arrival missing")
	app.queue_free()
	await process_frame
	print("SKY ARRIVALS: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
