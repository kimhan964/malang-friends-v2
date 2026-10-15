extends SceneTree
const Pet=preload("res://scripts/desktop_pet.gd")
const Behavior=preload("res://scripts/expression_behavior.gd")
class TestState extends "res://scripts/pet_state.gd":
	func save_game() -> void: pass
var folder="res://quiet-style-review-2026-10-05"
var failures=[]
var records=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for species in [0,1,4,8]:
		if "--otter" in OS.get_cmdline_user_args() and species!=1: continue
		for stage in [0,2]:
			var pet=Pet.new()
			pet.species=species
			pet.state=TestState.new()
			root.add_child(pet)
			pet.set_process(false)
			pet.window_input.disconnect(pet.handle_input)
			var m=pet.motion
			m.autonomy=false
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			m.move_to(Vector2(900,550))
			pet.view.dizzy_effects.set_process(false)
			for action in ["idle","happy","surprised","angry","sleepy","struggle","dizzy","doze"]:
				m.cancel_play()
				m.held=false
				m.pointer_grab=false
				m.carried=false
				m.hold_release={}
				m.landing_left=0
				m.joy_left=0
				m.voice_left=0
				m.phase=action
				m.elapsed=.7
				m.action_left=5
				if action in Behavior.Emotions.KINDS:
					m.react(action,Behavior.duration(species,action))
					m.reaction_time=.6
				if action=="struggle":
					m.held=true
					m.pointer_grab=true
					m.carried=true
					m.carry_elapsed=2.7
					m.carry_started_at=.2
				pet.sync_position()
				pet.view.position=m.feet-Vector2(pet.position)-pet.view.FEET
				pet.view.refresh()
				pet.view.dizzy_effects._process(.45)
				pet.update_mouse_region()
				await process_frame
				await RenderingServer.frame_post_draw
				# Native canvas resize is presented asynchronously on Windows.
				# Compare settled poses using the new canvas dimensions.
				await process_frame
				await RenderingServer.frame_post_draw
				await process_frame
				await RenderingServer.frame_post_draw
				var words="내려줄래?" if action=="struggle" else str(Behavior.WORDS.get(action,"좋아"))
				var bubble=pet.view.voice_bubble_layout(words).area
				bubble.position+=pet.view.position
				if not Rect2(Vector2.ZERO,Vector2(pet.size)).encloses(bubble): failures.append("bubble clipped %d/%d/%s"%[species,stage,action])
				if pet.view.dizzy_effects.particles.size()>3: failures.append("too many particles")
				var at=pet.view.position+pet.view.FEET
				var crop=Rect2i(Vector2i(at-Vector2(100,180)),Vector2i(200,210))
				var name="%02d-%d-%s.png"%[species,stage,action]
				pet.get_texture().get_image().get_region(crop).save_png(folder+"/"+name)
				if action=="struggle" and species==1 and stage==2:
					pet.get_texture().get_image().save_png(folder+"/hold-full.png")
					print("HOLD_CAPTURE root=",at," motion=",m.feet," window=",pet.position," view=",pet.view.position," actual=",pet.view.visible_pet_bounds()," canvas=",pet.size)
				records.append({"file":name,"species":species,"stage":stage,"action":action})
			pet.free()
			print("QUIET_STYLE ",species,"/",stage)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"failures":failures}))
	print("QUIET_STYLE_DONE captures=",records.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
