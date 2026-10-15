extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
class ReviewState extends State:
	func save_game() -> void: pass
var samples=[]
var before=Vector2.ZERO
var app
var age=0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("commerce/enabled",false)
	app=Main.new();app.state=ReviewState.new()
	root.add_child(app);await process_frame
	app.set_process(false);app.furniture_room.set_process(false)
	app.clear_falling_gifts()
	app.pet.motion.cancel_play()
	app.pet.motion.autonomy=false
	app.pet.motion.move_to(Vector2(400,app.pet.motion.bounds.get_center().y))
	app.pet.motion.visit(Vector2(1600,app.pet.motion.feet.y),"look")
	before=app.pet.motion.feet
	for i in range(420):
		await process_frame
		var dt=root.get_process_delta_time()
		age+=dt
		var m=app.pet.motion
		samples.append({"dt":dt,"dx":m.feet.x-before.x,"phase":m.walk_phase,"action":m.phase})
		before=m.feet
	var report={"species":app.pet.species,"age":app.pet.motion.growth_stage,"seconds":age,"samples":samples}
	DirAccess.make_dir_recursive_absolute("user://general-walk-profile")
	var suffix="after" if OS.get_cmdline_user_args().has("--after") else "before"
	var report_file=FileAccess.open("user://general-walk-profile/"+suffix+".json",FileAccess.WRITE)
	if report_file == null:
		push_error("Cannot write walking profile")
		quit(1)
		return
	report_file.store_string(JSON.stringify(report))
	app.queue_free();await process_frame;quit()
