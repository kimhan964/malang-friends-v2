extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Layer=preload("res://scripts/outfit_layer.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
var failures=[]
var checks=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and label not in failures: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var layer=Layer.new()
	for species in range(16):
		for stage in [0,2]:
			var m=Motion.new()
			m.species=species
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species>0
			var age="baby" if stage==0 else "adult"
			for action in ["idle","wander","eat","doze"]:
				m.phase=action
				m.elapsed=1.4
				m.food_id=preload("res://scripts/animal_catalog.gd").DEFAULT_MEALS[species]
				m.outfit_style=0
				var expected=Art.sample(m)
				for style in [1,2,3]:
					for color in range(6):
						m.outfit_style=style
						m.outfit_color=color
						var sample=Art.sample(m)
						check(sample.texture==expected.texture and sample.height==expected.height,"clothing replaced animal %d/%s/%s"%[species,age,action])
						check(not sample.get("dressed",false),"legacy body returned")
						check(layer.outfit_texture(species,age,style,color)!=null,"missing garment")
			m.phase="wander"
			var size=Vector2.ZERO
			for frame in range(60):
				m.walk_phase=frame/60.0
				var sample=Art.sample(m)
				check(sample.get("pilot",false) if species==0 else sample.get("smooth_walk",false),"new walk disabled")
				var fit=layer.fitting_box(species,age,sample,Rect2(Metrics.used_rect(sample.texture)))
				if frame==0: size=fit.size
				check(fit.size.is_equal_approx(size),"garment resized during walk")
		Art.release_other_species(-1)
	layer.free()
	print("OUTFIT_CURRENT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
