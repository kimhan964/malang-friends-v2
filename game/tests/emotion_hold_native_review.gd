extends SceneTree
const Pet=preload("res://scripts/desktop_pet.gd")
const State=preload("res://scripts/pet_state.gd")
const Behavior=preload("res://scripts/expression_behavior.gd")
const Outline=preload("res://scripts/animation_outline.gd")
class TestState extends State:
	func save_game() -> void: pass
var records=[]
var folder="res://emotion-hold-native-v2"
func _initialize() -> void: call_deferred("run")
func capture(pet,kind: String,index: int) -> void:
	await RenderingServer.frame_post_draw
	var m=pet.motion
	var rect=pet.view.visible_head_bounds()
	var effect=pet.view.dizzy_effects.orbit_layout().center
	var clipped=false
	for point in Outline.blended_points(pet.view.sprite):
		if not Rect2(Vector2.ZERO,Vector2(pet.size)).has_point(point): clipped=true
	var record={"species":m.species,"stage":m.growth_stage,"kind":kind,"index":index,"clock":m.carry_elapsed,"reaction_time":m.reaction_time,"struggling":m.is_struggling(),"bank":pet.view.generated_sample.get("bank","legacy"),"effect_gap":rect.position.y-effect.y,"effect_x_error":rect.get_center().x-effect.x,"clipped":clipped}
	if index%6==0 or kind=="hold":
		var name="%02d-%d-%s-%03d.png"%[m.species,m.growth_stage,kind,index]
		var image=pet.get_texture().get_image()
		var crop=Rect2i(Vector2i(m.feet-Vector2(pet.position)-Vector2(150,260)),Vector2i(300,300)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		image.get_region(crop).save_png(folder+"/"+name)
		record.file=name
	records.append(record)
func run() -> void:
	root.mouse_passthrough=true
	DirAccess.make_dir_recursive_absolute(folder)
	for species in range(16):
		for stage in [0,2]:
			var pet=Pet.new()
			pet.species=species
			pet.state=TestState.new()
			root.add_child(pet)
			pet.set_process(false)
			var m=pet.motion
			m.autonomy=false
			m.resting=true
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			m.move_to(Vector2(900,550))
			pet.advance_frame(0)
			pet.begin_pointer(m.feet-Vector2(0,60))
			for index in range(223):
				pet.move_pointer(pet.press_screen,1.0/60)
				pet.advance_frame(1.0/60)
				if index in [0,59,113,118,119,120,126,138,150,174,198,222]: await capture(pet,"hold",index)
			pet.release_pointer()
			for kind in Behavior.Emotions.KINDS:
				m.cancel_play()
				m.move_to(Vector2(900,550))
				m.react(kind,Behavior.duration(species,kind))
				for index in range(61):
					m.reaction_time=m.reaction_duration*index/60.0
					pet.advance_frame(0)
					if species in [0,1,6,14] or index%12==0: await capture(pet,kind,index)
			pet.free()
			await process_frame
			print("EMOTION_HOLD_NATIVE ",species,"/",stage)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(records))
	print("EMOTION_HOLD_NATIVE_DONE ",records.size())
	quit()
