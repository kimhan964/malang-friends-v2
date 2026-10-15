extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Art=preload("res://scripts/hold_transition_art.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
var failures=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	var boundaries=0
	for species in range(16):
		for stage in [0,2]:
			var m=Motion.new()
			m.species=species
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.configure(Rect2(0,0,1280,720),Vector2(500,470))
			m.autonomy=false
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			var view=View.new()
			view.motion=m
			root.add_child(view)
			check(Art.available(m),"missing transition bank")
			for name in Art.NAMES:
				check(Art.frames(species,"baby" if stage==0 else "adult",name).size()==17,"missing transition cels")
			for pickup in [0.0,1.95,2.0]:
				for clock in [.08,.23,1.99,2.01,2.15,2.32,2.45,2.67,3.02,5.99]:
					if clock<pickup: continue
					m.cancel_play()
					m.held=true
					m.pointer_grab=true
					m.carried=true
					m.carry_started_at=pickup
					m.carry_elapsed=clock
					view.refresh()
					var before=view.visible_pet_bounds()
					var before_rotation=view.sprite.rotation
					m.capture_hold_release()
					m.hold_release.angle=before_rotation
					m.held=false
					m.pointer_grab=false
					m.carried=false
					if clock>=3: m.begin_drop()
					view.refresh()
					var after=view.visible_pet_bounds()
					check(before.get_center().distance_to(after.get_center())<1.8,"release root jump %d/%d/%.2f"%[species,stage,clock])
					check(before.size.distance_to(after.size)<2.2,"release size jump %d/%d/%.2f"%[species,stage,clock])
					check(absf(view.sprite.rotation-before_rotation)<.001,"release angle reset")
					for step in range(50):
						m.advance(1.0/60.0)
						view.refresh()
						if m.phase=="drop" or (m.phase=="dizzy" and m.landing_left>0):
							check(view.generated_sample.get("hold_visual",false),"old carry leaked into landing")
					boundaries+=1
			m.cancel_play()
			m.begin_dizzy()
			m.elapsed=4.65
			m.landing_left=0
			view.refresh()
			check(view.generated_sample.get("bank","")=="hold-recover","missing recovery bridge")
			view.free()
	for failure in failures.slice(0,16): push_error(failure)
	print("HOLD_TRANSITION_TEST release_boundaries=",boundaries," banks=32 failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
