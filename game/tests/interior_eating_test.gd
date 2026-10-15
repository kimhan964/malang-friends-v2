extends SceneTree
const State=preload("res://scripts/pet_state.gd")
const Catalog=preload("res://scripts/furniture_catalog.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Art=preload("res://scripts/generated_species_art.gd")
var failures=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	preload("res://scripts/smooth_species_art.gd").select_version(14)
	var state=State.new()
	state.save_path="user://furniture-test-only.json"
	state.load_furniture({"sofa":[100,200],"lamp":[300,400],"bad":[0,0],"shelf":["x",1]})
	if state.furniture.size()!=2: failures.append("invalid furniture accepted")
	state.save_game()
	var restored=State.new()
	restored.save_path=state.save_path
	restored.load_game()
	if restored.furniture!=state.furniture: failures.append("layout round trip")
	DirAccess.remove_absolute(state.save_path)
	for id in Catalog.ITEMS:
		var tex=Catalog.texture(id)
		if tex==null or not tex.get_image().detect_alpha(): failures.append("missing transparent furniture "+id)
	var count=0
	for species in range(16):
		for stage in [0,2]:
			var m=Motion.new()
			m.species=species
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			m.autonomy=false
			m.phase="eat"
			m.action_left=5.5
			m.visit_id="hand_feed"
			m.food_id=preload("res://scripts/animal_catalog.gd").DEFAULT_MEALS[species]
			var view=View.new()
			view.motion=m
			root.add_child(view)
			var scale=-1.0
			var last=-1
			for tick in range(111):
				m.elapsed=tick*.05
				view.refresh()
				if scale<0: scale=view.sprite.scale.y
				if absf(scale-view.sprite.scale.y)>.00001: failures.append("meal scale drift %d/%d"%[species,stage])
				if view.generated_sample.index<last: failures.append("meal restarted %d/%d"%[species,stage])
				last=view.generated_sample.index
				count+=1
			m.phase="drink"
			m.visit_id="home_water"
			scale=-1
			last=-1
			for tick in range(111):
				m.elapsed=tick*.05
				view.refresh()
				if scale<0: scale=view.sprite.scale.y
				if absf(scale-view.sprite.scale.y)>.00001: failures.append("home water scale drift %d/%d"%[species,stage])
				if view.generated_sample.index<last: failures.append("home water restarted %d/%d"%[species,stage])
				last=view.generated_sample.index
				count+=1
			view.free()
		Art.release_other_species(-1)
		print("MEAL_CHECK ",species)
	print("INTERIOR_EATING poses=",count," failures=",failures.slice(0,20))
	quit(0 if failures.is_empty() else 1)
