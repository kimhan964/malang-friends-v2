extends SceneTree
const Main=preload("res://scripts/main.gd")
class ReviewState extends "res://scripts/pet_state.gd":
	func load_game() -> void:
		guide_seen=true
		selected=0
		growth={"0":36}
		play_affection={"0":2}
		activity_counts={"0":{"pet":2}}
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
	if OS.get_cmdline_user_args().has("--notice"):
		app.show_gift(0,["bowl","basket"])
		app.advance_gift_notices(0)
		Engine.time_scale=.05
		return
	app.pet.menu.section=3
	app.pet.open_menu()
	app.pet.menu.position=Vector2i(520,150)
	# Closing the first menu completes the third pet action in QA memory only.
	app.pet.menu.popup_hide.connect(func():
		if int(app.state.play_affection.get("0",0))==2:
			app.state.reward_activity(0,"pet")
			print("UI_QA reward accepted gifts=",app.gift_notices))
	print("UI_UNLOCK_NATIVE ready")
	create_timer(420).timeout.connect(quit)
