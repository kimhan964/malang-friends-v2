extends SceneTree

const Catalog=preload("res://scripts/animal_catalog.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Walk=preload("res://scripts/walk_art.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Outline=preload("res://scripts/animation_outline.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var startup=Motion.new()
	startup.species=0
	startup.growth_stage=0
	var startup_view=View.new()
	startup_view.motion=startup
	root.add_child(startup_view)
	assert(Art.cache.has("0/baby/walk") and Walk.cache.has("rabbit/baby"))
	for image in Walk.frames(0,"baby"):
		assert(Outline.hulls.has(image.get_instance_id()))
	startup_view.free()
	var checked=0
	for species in range(Catalog.IDS.size()):
		for stage in ["baby","adult"]:
			var images=Walk.frames(species,stage)
			assert(images.size()==32,"missing 32-frame walk %s/%s"%[Catalog.IDS[species],stage])
			for image in images:
				assert(image.get_size()==Vector2(256,256))
				var used=image.get_image().get_used_rect()
				assert(used.has_area() and used.position.x>=2 and used.position.y>=2 and used.end.x<=254 and used.end.y<=254)
				checked+=1
			var motion=Motion.new()
			motion.species=species
			motion.growth_stage=0 if stage=="baby" else 2
			motion.phase="wander"
			motion.walk_phase=.5
			var sample=Art.sample(motion)
			assert(sample.index==16 and sample.texture==images[16])
			motion.outfit_style=1
			motion.outfit_color=0
			sample=Art.sample(motion)
			if Art.dressed_frames(species,stage,1,"walk").size()==16:
				assert(sample.index==8)
				assert(sample.get("dressed",false))
			else:
				assert(sample.index==16 and sample.texture==images[16])
	for species in range(Catalog.IDS.size()):
		for fps in [30,60,144]:
			var motion=Motion.new()
			motion.species=species
			motion.feet=Vector2.ZERO
			motion.target=Vector2(200,0)
			for tick in range(fps*12):
				var previous=motion.feet.x
				motion.advance_travel(1.0/fps)
				assert(motion.feet.x>=previous and motion.feet.x<=200.001)
			assert(motion.feet.distance_to(motion.target)<.01)
	print("WALK_V4_TEST_PASSED: %d complete-body cels, 48 travel cases"%checked)
	quit()
