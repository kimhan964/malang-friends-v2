extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
class MemoryState extends State:
	func load_game() -> void: pass
	func save_game() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("commerce/enabled",false)
	var app=Main.new();app.state=MemoryState.new();app.state.selected=1;app.state.guide_seen=true;app.state.play_affection={"1":200}
	root.add_child(app);await process_frame
	app.set_process(false);app.furniture_room.set_process(false)
	for id in app.furniture_room.pieces.keys(): app.furniture_room.remove_piece(id)
	for prop in app.props.values(): prop.hide()
	app.furniture_room.place("sofa",Vector2(850,850),false)
	app.furniture_room.place("table",Vector2(1000,850),false)
	var m=app.pet.motion;m.autonomy=false;m.growth_stage=2;m.growth_scale=1.0
	m.move_to(Vector2(780,m.bounds.get_center().y));m.visit(Vector2(1100,m.feet.y),"relax")
	app.request_layer_order()
	await create_timer(3).timeout
	m.react("happy",100);m.reaction_time=30
	await create_timer(55).timeout
	m.phase="idle"
	await create_timer(12).timeout
	app.queue_free();quit()
