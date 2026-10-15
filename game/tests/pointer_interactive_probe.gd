extends SceneTree
const Pet=preload("res://scripts/desktop_pet.gd")
const State=preload("res://scripts/pet_state.gd")
class TestState extends State:
	func save_game() -> void: pass
var pet
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mouse_passthrough=true
	pet=Pet.new()
	pet.species=1
	pet.state=TestState.new()
	root.add_child(pet)
	pet.title="Pointer carry input review"
	pet.motion.autonomy=false
	pet.motion.resting=true
	pet.motion.move_to(Vector2(900,550))
	pet.window_input.connect(input_seen)
	create_timer(60).timeout.connect(quit)
func input_seen(event: InputEvent) -> void:
	if event is InputEventMouseButton or (event is InputEventMouseMotion and pet.motion.held):
		print("INPUT_TRACE ",event.as_text()," desktop=",DisplayServer.mouse_get_position()," held=",pet.motion.held," drag=",pet.dragging," feet=",pet.motion.feet," press=",pet.press_screen," window=",pet.position," canvas=",pet.size)
