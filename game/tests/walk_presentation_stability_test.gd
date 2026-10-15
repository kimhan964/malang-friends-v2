extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Presentation=preload("res://scripts/character_presentation.gd")
func _initialize() -> void:
	var cases=0
	for species in range(16):
		for stage in [0,2]:
			var motion=Motion.new()
			motion.species=species
			motion.growth_stage=stage
			motion.phase="wander"
			var previous={}
			for frame in range(32):
				motion.walk_phase=float(frame)/32
				var pose=Presentation.pose(species,Art.sample(motion))
				if not previous.is_empty():
					assert(pose.scale==previous.scale,"Walking must not resize at each cel")
					assert(pose.anchor==previous.anchor,"Walking must not reset the root at each cel")
				previous=pose
				cases+=1
	print("WALK_PRESENTATION_STABLE ",cases," cel checks across 16 species and both ages")
	quit()
