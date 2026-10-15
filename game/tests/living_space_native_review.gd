extends SceneTree
const Main=preload("res://scripts/main.gd")
class ReviewState extends "res://scripts/pet_state.gd":
	func load_game() -> void:
		guide_seen=true
		selected=0
		growth={"0":36}
		play_affection={"0":70}
		furniture={"sofa":[520,650],"table":[820,620],"reading_chair":[1160,660]}
	func save_game() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preload("res://scripts/smooth_species_art.gd").select_version(14)
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	var app=Main.new()
	app.state=ReviewState.new()
	root.add_child(app)
	app.clear_falling_gifts()
	app.pet.motion.autonomy=false
	app.furniture_room.home_delay=9999
	app.furniture_room.use_piece("sofa")
	app.furniture_room.open()
	var timer=Timer.new()
	timer.wait_time=3
	timer.autostart=true
	timer.timeout.connect(func(): print("SPACE_REVIEW mode=",app.state.activity_space," feet=",app.pet.motion.feet," bounds=",app.pet.motion.bounds," phase=",app.pet.motion.phase))
	root.add_child(timer)
	create_timer(420).timeout.connect(quit)
