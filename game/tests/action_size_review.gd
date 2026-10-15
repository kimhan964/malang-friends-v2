extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Behavior=preload("res://scripts/expression_behavior.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
var records=[]
var folder="res://action-size-review/before"
var native=false
var sweep=false
var checks=0
var failures=[]
var areas={}
var max_action_error=0.0
var max_walk_error=0.0
const Pet=preload("res://scripts/desktop_pet.gd")
class TestState extends "res://scripts/pet_state.gd":
	func save_game() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg=="--native": native=true
		if arg=="--sweep": sweep=true
	DirAccess.make_dir_recursive_absolute(folder)
	for species in range(16):
		for stage in [0,2]:
			var m=Motion.new()
			m.species=species
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			m.autonomy=false
			var pet
			var view
			if native:
				pet=Pet.new()
				pet.species=species
				pet.state=TestState.new()
				root.add_child(pet)
				pet.set_process(false)
				pet.motion=m
				pet.view.motion=m
				m.move_to(Vector2(900,550))
				view=pet.view
			else:
				view=View.new()
				view.motion=m
				root.add_child(view)
			view.refresh()
			var reference_area=rendered_area(view)
			for action in ["idle","wander","eat","drink","doze","relax","groom","stretch","pet","look","sniff","playful","carry","struggle","dizzy","surprised","happy","angry","sleepy"]:
				m.cancel_play()
				m.held=false
				m.pointer_grab=false
				m.carried=false
				m.hold_release={}
				m.landing_left=0
				m.joy_left=0
				m.phase=action
				m.elapsed=1.4
				m.action_left=5
				m.walk_phase=.3
				m.visit_id="water" if action=="drink" else "bowl"
				m.food_id=preload("res://scripts/animal_catalog.gd").DEFAULT_MEALS[species]
				if action in ["carry","struggle"]:
					m.held=true
					m.pointer_grab=true
					m.carried=true
					m.carry_started_at=.2
					m.carry_elapsed=1 if action=="carry" else 2.7
				if action in Behavior.Emotions.KINDS:
					m.react(action,Behavior.duration(species,action))
					m.reaction_time=m.reaction_duration*.5
				view.refresh()
				if native:
					# Render the requested pose without advancing AI: an unconfigured
					# destination otherwise turns wander/pet back into idle here.
					pet.sync_position()
					view.position=m.feet-Vector2(pet.position)-view.FEET
					view.refresh()
					pet.update_mouse_region()
					await process_frame
					await RenderingServer.frame_post_draw
					pet.get_texture().get_image().save_png(folder+"/native-%02d-%d-%s.png"%[species,stage,action])
				var tex=view.sprite.texture
				var name="%02d-%d-%s.png"%[species,stage,action]
				tex.get_image().save_png(folder+"/"+name)
				var bounds=Metrics.used_rect(tex)
				records.append({"species":species,"stage":stage,"action":action,"file":name,"scale":view.sprite.scale.y,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"position":[view.sprite.position.x,view.sprite.position.y],"rotation":view.sprite.rotation,"bank":view.generated_sample.get("bank","legacy"),"index":view.generated_sample.index})
				if sweep:
					for frame in range(61):
						m.elapsed=frame/60.0*5.0
						m.walk_phase=frame/61.0
						m.reaction_time=m.reaction_duration*frame/60.0
						if action in ["carry","struggle"]: m.carry_elapsed=frame/60.0*4.0
						view.refresh()
						var error=absf(sqrt(rendered_area(view)/reference_area)-1.0)
						var walking=action=="wander"
						var authored_idle=view.generated_sample.action=="idle" and (view.generated_sample.get("pilot",false) or view.generated_sample.get("smooth_walk",false))
						if walking: max_walk_error=maxf(max_walk_error,error)
						else: max_action_error=maxf(max_action_error,error)
						# Existing locomotion/idle cels retain their approved camera;
						# folding limbs/blinking may change projected ink coverage.
						var tolerance=.08 if walking else (.03 if authored_idle else .001)
						if error>tolerance: failures.append("%d/%d/%s/%d %.5f"%[species,stage,action,frame,error])
						checks+=1
			if native: pet.free()
			else: view.free()
		Art.release_other_species(-1)
		print("ACTION_SIZE_REVIEW ",species)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(records))
	print("ACTION_SIZE_SWEEP poses=",checks," action_error=",max_action_error," walk_error=",max_walk_error," failures=",failures.slice(0,12))
	FileAccess.open(folder+"/sweep.json",FileAccess.WRITE).store_string(JSON.stringify({"poses":checks,"action_error":max_action_error,"walk_error":max_walk_error,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func rendered_area(view) -> float:
	var texture=view.sprite.texture
	var key=texture.get_instance_id()
	if not areas.has(key):
		var image=texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var bytes=image.get_data()
		var total=0.0
		for i in range(3,bytes.size(),4): total+=bytes[i]/255.0
		areas[key]=total
	return areas[key]*absf(view.sprite.scale.x*view.sprite.scale.y)
