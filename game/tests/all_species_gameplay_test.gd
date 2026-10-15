extends SceneTree
const Catalog=preload("res://scripts/animal_catalog.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Pet=preload("res://scripts/desktop_pet.gd")
const State=preload("res://scripts/pet_state.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Outline=preload("res://scripts/animation_outline.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
const PHASES=["idle","wander","pet","eat","drink","doze","carry","playful","look","sniff","greet","groom","stretch","rub","prop_use","relax"]
var checked=0
var failures: Array=[]
var rows: Array=[]

class TestState extends State:
	func save_game() -> void: pass
	func reward_activity(_species: int,_action: String) -> void: pass

func _initialize() -> void: call_deferred("run")

func validate(view, label: String) -> void:
	view.refresh()
	if view.sprite.texture==null or not Metrics.used_rect(view.sprite.texture).has_area(): failures.append(label+" empty")
	Outline.fit(view.sprite,View.FEET,View.WINDOW_SIZE)
	for point in Outline.blended_points(view.sprite):
		if not Rect2(4,4,248,216).has_point(point):
			failures.append(label+" clipped")
			break
	checked+=1

func run() -> void:
	for species in range(16):
		for stage in [0,2]:
			var m=Motion.new()
			m.species=species
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			var view=View.new()
			view.motion=m
			root.add_child(view)
			m.phase="idle"
			view.refresh()
			var standing=Metrics.used_rect(view.sprite.texture).size.y*absf(view.sprite.scale.y)
			var min_walk=INF
			var max_walk=0.0
			for phase in PHASES:
				m.phase=phase
				m.carried=phase=="carry"
				m.visit_id="plant" if phase=="prop_use" else ("water" if phase=="drink" else "bowl")
				m.food_id=Catalog.DEFAULT_MEALS[species]
				m.action_left=20
				m.travel_speed=Motion.SPEEDS[species]
				for facing in [-1.0,1.0]:
					m.facing=facing
					for step in range(32):
						m.elapsed=step/32.0*4.8
						m.carry_elapsed=m.elapsed
						m.walk_phase=step/32.0
						validate(view,"%d/%d/%s/%d"%[species,stage,phase,step])
						var height=Metrics.used_rect(view.sprite.texture).size.y*absf(view.sprite.scale.y)
						if phase=="wander":
							min_walk=minf(min_walk,height)
							max_walk=maxf(max_walk,height)
						if phase in ["idle","wander","pet","eat","carry","greet"] and absf(height/standing-1)>.015:
							failures.append("%d/%d/%s scale %.3f"%[species,stage,phase,height/standing])
			m.carried=false
			m.phase="react"
			for emotion in ["surprised","happy","angry","sleepy"]:
				m.reaction=emotion
				m.reaction_duration=3
				for step in range(12):
					m.reaction_time=step/12.0*3
					validate(view,"emotion %d/%d/%s"%[species,stage,emotion])
			m.reaction=""
			for style in range(1,4):
				m.outfit_style=style
				for color in range(6):
					m.outfit_color=color
					for phase in PHASES:
						m.phase=phase
						m.carried=phase=="carry"
						m.visit_id="plant" if phase=="prop_use" else "bowl"
						for step in [0,8,16,24]:
							m.elapsed=step/32.0*4.8
							m.carry_elapsed=m.elapsed
							m.walk_phase=step/32.0
							validate(view,"outfit %d/%d/%d/%d/%s"%[species,stage,style,color,phase])
			rows.append({"species":Catalog.IDS[species],"stage":"baby" if stage==0 else "adult","walk_height_variation":max_walk/min_walk-1,"standing_height":standing})
			view.free()
		# Exercise the actual pet release handler on both sides of the 3s limit.
		var pet=Pet.new()
		pet.species=species
		pet.state=TestState.new()
		root.add_child(pet)
		pet.motion.autonomy=false
		pet.motion.configure(Rect2(-1280,-100,1280,720),Vector2(-700,400))
		for held_time in [0.0,2.999,3.0,3.1]:
			pet.motion.move_to(Vector2(-700,400))
			pet.begin_pointer(Vector2(-700,360))
			pet.move_pointer(Vector2(-700,280),.1)
			pet.motion.advance(held_time)
			var point=pet.motion.feet
			pet.release_pointer()
			var expected="drop" if held_time>=3 else "idle"
			if pet.motion.phase!=expected: failures.append("release %d at %.3f: %s"%[species,held_time,pet.motion.phase])
			if held_time<3:
				pet.motion.advance(.3)
				if pet.motion.feet!=point: failures.append("short release moved")
		pet.free()
		print("GAMEPLAY_TEST_SPECIES=",species)
	var output=FileAccess.open("res://design/gameplay-audit-2026-10-02/automated-report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"poses":checked,"species":rows,"failures":failures},"\t"))
	for failure in failures.slice(0,20): push_error(failure)
	print("ALL_SPECIES_GAMEPLAY_POSES=",checked," FAILURES=",failures.size())
	quit(1 if not failures.is_empty() else 0)
