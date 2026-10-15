extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Home=preload("res://scripts/home_animation.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
var failures=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	preload("res://scripts/smooth_species_art.gd").select_version(14)
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
			if not Home.available(m):
				failures.append("missing home bank %d/%d"%[species,stage])
				continue
			var view=View.new()
			view.motion=m
			root.add_child(view)
			for id in Home.KINDS:
				m.phase="home_use"
				m.visit_id=id
				var first_scale=-1.0
				for tick in range(101):
					m.elapsed=Home.duration(id)*tick/101.0
					m.action_left=Home.duration(id)-m.elapsed
					view.refresh()
					if not view.generated_sample.get("home_animation",false): failures.append("fallback %d/%d/%s"%[species,stage,id])
					var scale=view.sprite.scale.y*view.generated_sample.height
					if first_scale<0: first_scale=scale
					if absf(scale-first_scale)>.00001: failures.append("camera changes %d/%d/%s"%[species,stage,id])
					if view.sprite.texture==null: failures.append("null texture")
					count+=1
			view.free()
		print("HOME_BANK_CHECK ",Catalog.IDS[species])
	print("HOME_ANIMATION poses=",count," failures=",failures.slice(0,30))
	quit(0 if failures.is_empty() else 1)
