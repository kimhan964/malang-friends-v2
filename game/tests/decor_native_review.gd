extends SceneTree
const Main=preload("res://scripts/main.gd")
class ReviewState extends "res://scripts/pet_state.gd":
	func load_game() -> void:
		guide_seen=true
		selected=0
		growth={"0":36}
		play_affection={"0":70}
		furniture={"sofa":[450,650],"tv":[850,620],"turntable":[1200,660,true]}
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
	app.furniture_room.use_piece("tv")
	app.furniture_room.open()
	print("DECOR_NATIVE ready items=",app.furniture_room.pieces.keys())
	create_timer(420).timeout.connect(quit)
