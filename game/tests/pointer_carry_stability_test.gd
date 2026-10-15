extends SceneTree
const Pet=preload("res://scripts/desktop_pet.gd")
const State=preload("res://scripts/pet_state.gd")
class TestState extends State:
	func save_game() -> void: pass
var failures=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var minimum=1.0
	var activation_jump=0.0
	var worst_follow=0.0
	var samples=0
	for species in range(16):
		for stage in [0,2]:
			var pet=Pet.new()
			pet.species=species
			pet.state=TestState.new()
			root.add_child(pet)
			pet.set_process(false)
			var m=pet.motion
			m.autonomy=false
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			m.move_to(Vector2(620,430))
			pet.advance_frame(0)
			var cursor=m.feet-Vector2(0,65)
			pet.begin_pointer(cursor)
			pet.advance_frame(0)
			pet.move_pointer(cursor+Vector2(10,0),.2)
			pet.advance_frame(.2)
			pet.move_pointer(cursor-Vector2(10,0),.02)
			pet.advance_frame(.02)
			if m.joy_left<=0: failures.append("rub fixture did not trigger")
			var happy=pet.view.EmotionArt.texture(species,"baby" if stage==0 else "adult","happy")
			if pet.view.generated_sample.action!="idle" or pet.view.sprite.texture==happy:
				failures.append("pre-lift rub replaced calibrated pose %d/%d"%[species,stage])
			var previous=m.feet
			cursor+=Vector2(0,-26)
			pet.move_pointer(cursor,1.0/60.0)
			activation_jump=maxf(activation_jump,m.feet.distance_to(previous))
			pet.advance_frame(1.0/60.0)
			var offset=m.feet-cursor
			for step in range(360):
				# Sweep every old native surface edge, then keep moving while protesting.
				cursor=Vector2(620+sin(step/45.0)*530,365+sin(step/31.0)*270)
				pet.move_pointer(cursor,1.0/60.0)
				pet.advance_frame(1.0/60.0)
				worst_follow=maxf(worst_follow,(m.feet-cursor).distance_to(offset))
				var fitted=pet.view.sprite.scale.abs()
				pet.view.refresh(0)
				var natural=pet.view.sprite.scale.abs()
				minimum=minf(minimum,fitted.y/natural.y)
				var root_point=Vector2(pet.position)+pet.view.position+pet.View.FEET
				if root_point.distance_to(m.feet)>.01: failures.append("window/root mismatch")
				samples+=1
			pet.release_pointer()
			m.move_to(Vector2(500,350))
			var quick_start=m.feet
			pet.begin_pointer(quick_start-Vector2(0,65))
			pet.move_pointer(quick_start-Vector2(0,65)+Vector2(200,-100),0.0)
			if not pet.dragging or m.feet.distance_to(quick_start)<180:
				failures.append("single-batch fast drag lost movement")
			pet.free()
	if minimum<.999: failures.append("native edge shrinks pet")
	if activation_jump>2.01: failures.append("drag activation teleports")
	if worst_follow>.01: failures.append("cursor offset changes at desktop edge")
	print("POINTER_CARRY_STABILITY samples=",samples," min_size_ratio=",minimum," activation_jump_px=",activation_jump," cursor_error_px=",worst_follow," failures=",failures.size())
	for failure in failures.slice(0,8): push_error(failure)
	quit(0 if failures.is_empty() else 1)
