extends SceneTree
const Main=preload("res://scripts/main.gd")
const Context=preload("res://scripts/context_reactions.gd")
class ReviewState extends "res://scripts/pet_state.gd":
	func load_game() -> void:
		guide_seen=true
		selected=0
		growth={"0":36}
		play_affection={"0":70}
	func save_game() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	preload("res://scripts/smooth_species_art.gd").select_version(14)
	var app=Main.new()
	app.state=ReviewState.new()
	root.add_child(app)
	app.set_process(false)
	app.clear_falling_gifts()
	app.furniture_room.set_process(false)
	for prop in app.props.values(): prop.hide()
	app.pet.set_process(false)
	var m=app.pet.motion
	m.autonomy=false
	m.move_to(Vector2(980,997))
	var event="favorite_meal"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--event="): event=arg.trim_prefix("--event=")
	m.context_reactions.queue(event)
	for i in range(72):
		app.pet.advance_frame(1.0/60)
		await process_frame
	print("CONTEXT_NATIVE event=",m.reaction_context," phase=",m.phase," words=",m.reaction_words," feet=",m.feet)
	create_timer(180).timeout.connect(quit)
