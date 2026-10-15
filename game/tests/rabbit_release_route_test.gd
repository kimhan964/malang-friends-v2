extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
const Art=preload("res://scripts/rabbit_pilot_art.gd")
const Generated=preload("res://scripts/generated_species_art.gd")
class IsolatedState extends State:
	func load_game() -> void:
		guide_seen=true
		selected=14
		for i in range(16): growth[str(i)]=36
	func save_game() -> void: pass
	func reward_activity(_species: int,_action: String) -> void: pass

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	assert(Art.data().version==9,"Normal game must default to the approved rabbit bank")
	var app=Main.new()
	app.state=IsolatedState.new()
	root.add_child(app)
	assert(not app.pet.motion.rabbit_pilot)
	# Same path as the native pet menu, with no preview-only flag setup.
	app.choose_friend(0)
	var m=app.pet.motion
	assert(m.rabbit_pilot,"Switching from koala must retain approved rabbit hopping")
	m.cancel_play()
	m.autonomy=false
	m.resting=true
	m.joy_left=0
	m.phase="wander"
	m.feet=Vector2(300,300)
	m.target=Vector2(312,300)
	var seen={}
	for tick in range(90):
		var sample=Generated.sample(m)
		assert(sample.get("pilot",false) and sample.bank=="walk")
		seen[sample.index]=true
		assert(is_equal_approx(sample.height,216.0))
		assert(sample.frame_mix==0.0)
		m.advance(1.0/60.0)
	assert(seen.size()==60,"All 60 hop cels must be played")
	# Both stages must use their own whole-frame hop bank.
	app.state.growth["0"]=0
	app.apply_growth()
	assert(m.rabbit_pilot)
	app.state.growth["0"]=36
	app.apply_growth()
	assert(m.rabbit_pilot)
	app.rabbit_pilot_mode=false
	app.choose_friend(0)
	assert(not app.pet.motion.rabbit_pilot,"Explicit comparison must still work")
	app.rabbit_pilot_mode=true
	app.choose_friend(14)
	assert(not app.pet.motion.rabbit_pilot and app.pet.motion.smooth_walk_enabled)
	app.choose_friend(0)
	assert(app.pet.motion.rabbit_pilot)
	app.queue_free()
	await process_frame
	var preview=preload("res://scripts/species_walk_preview.gd").new()
	root.add_child(preview)
	preview.selected=14
	preview.baby=true
	preview.select_pet()
	preview.app.pet.companion_selected.emit(0)
	for tick in range(4): await process_frame
	assert(preview.selected==0 and not preview.baby,"Native pet menu must synchronize preview selection")
	assert(preview.app.pet.motion.rabbit_pilot and preview.label.text.contains("60"))
	preview.queue_free()
	await process_frame
	print("RABBIT_RELEASE_ROUTE_PASS default v9, menu switch, 60 cels, age transition, explicit comparison, koala preserved")
	quit()
