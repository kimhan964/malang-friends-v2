extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
const Rabbit=preload("res://scripts/rabbit_pilot_art.gd")

func _initialize() -> void:
	assert(Smooth.version==14)
	var checked=0
	for species in range(16):
		for stage in range(2):
			var m=Motion.new()
			m.species=species
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species>0
			m.phase="wander"
			m.feet=Vector2(200,200)
			m.target=Vector2(500,200)
			var seen={}
			var reference=0.0
			for i in range(60):
				m.walk_phase=(i+.1)/60.0
				var sample=Art.sample(m)
				assert(sample.bank=="walk" and sample.frame_mix==0)
				assert(sample.get("pilot",false) if species==0 else sample.get("smooth_walk",false))
				assert(sample.texture!=null)
				if i==0: reference=sample.height
				assert(is_equal_approx(sample.height,reference))
				seen[sample.index]=true
			assert(seen.size()==60)
			m.phase="idle"
			assert(Art.sample(m).bank=="idle")
			if species>0:
				m.outfit_style=1
				assert(not Smooth.enabled(m),"Keep real outfit assets rather than silently removing clothes")
			checked+=1
	print("WALK_V14_ROUTE_PASS ",checked," banks; all 60 cels; fixed height; idle; outfit fallback")
	quit()
