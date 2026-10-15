extends SceneTree
const Pet=preload("res://scripts/desktop_pet.gd")
const State=preload("res://scripts/pet_state.gd")
const Art=preload("res://scripts/struggle_art.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Outline=preload("res://scripts/animation_outline.gd")
var failures=[]
class TestState extends State:
	func save_game() -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	var pet=Pet.new()
	pet.state=TestState.new()
	root.add_child(pet)
	pet.set_process(false)
	pet.motion.autonomy=false
	for fps in [30,60,144]:
		for drag in [false,true]:
			pet.motion.move_to(Vector2(500,350))
			var point=Vector2(500,300)
			pet.begin_pointer(point)
			for step in range(fps*3+2):
				pet.move_pointer(point+Vector2(0,-60) if drag else point,1.0/fps)
				pet.motion.advance(1.0/fps)
				if step<fps*2-1: check(not pet.motion.is_struggling(),"premature protest %d/%s"%[fps,drag])
				if step>=fps*2+1: check(pet.motion.is_struggling(),"late two-second protest %d/%s"%[fps,drag])
			check(pet.motion.is_struggling(),"missing protest %d/%s"%[fps,drag])
			pet.release_pointer()
			check(not pet.motion.is_struggling() and pet.motion.phase=="drop","long release")
			pet.begin_pointer(point)
			pet.move_pointer(point+Vector2(0,-60),.1)
			pet.motion.advance(.1)
			check(not pet.motion.is_struggling() and is_equal_approx(pet.motion.carry_elapsed,.1),"regrab timer")
			pet.release_pointer()
			check(pet.motion.phase=="idle","short release must not fall")
	pet.motion.cancel_play()
	pet.motion.held=true
	pet.motion.advance(10)
	check(not pet.motion.is_struggling() and pet.motion.carry_elapsed==0,"menu hold is not pointer grab")
	pet.free()
	var checked=0
	for species in range(16):
		for stage in [0,2]:
			var motion=preload("res://scripts/desktop_pet_motion.gd").new()
			motion.species=species
			motion.growth_stage=stage
			motion.growth_scale=.93 if stage==0 else 1.0
			motion.held=true
			motion.pointer_grab=true
			motion.carried=true
			check(Art.frames(species,Art.stage_name(motion)).size()==60,"missing cels %d/%d"%[species,stage])
			if not Art.available(motion): continue
			var view=View.new()
			view.motion=motion
			root.add_child(view)
			var first_scale=Vector2.ZERO
			for facing in [-1.0,1.0]:
				motion.facing=facing
				for i in range(60):
					motion.carry_elapsed=motion.STRUGGLE_HOLD_SECONDS+motion.STRUGGLE_ENTRY_SECONDS+(i+.1)/60.0*1.4
					view.refresh()
					check(view.generated_sample.get("struggle",false),"wrong bank")
					var before=view.sprite.scale.abs()
					Outline.fit(view.sprite,View.FEET,View.WINDOW_SIZE)
					check(view.sprite.scale.abs().is_equal_approx(before),"window fitting shrank pet %d/%d/%d"%[species,stage,i])
					var correction=preload("res://scripts/hold_camera.gd").registration(species,view.generated_sample).scale
					if first_scale==Vector2.ZERO: first_scale=before/correction
					check(first_scale.is_equal_approx(before/correction),"unexpected camera scale")
					for point in Outline.blended_points(view.sprite):
						check(Rect2(Vector2(4,4),Vector2(248,216)).has_point(point),"clipped cel")
					checked+=1
			view.free()
	for failure in failures.slice(0,12): push_error(failure)
	print("HOLD_STRUGGLE_TEST poses=",checked," failures=",failures.size(),"; 30/60/144 Hz stationary/lift/regrab/menu/release")
	quit(1 if not failures.is_empty() else 0)
