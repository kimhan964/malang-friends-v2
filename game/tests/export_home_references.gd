extends SceneTree
func _initialize() -> void:
	var smooth=preload("res://scripts/smooth_species_art.gd")
	var rabbit=preload("res://scripts/rabbit_pilot_art.gd")
	smooth.select_version(14)
	rabbit.select_version(9)
	var catalog=preload("res://scripts/animal_catalog.gd")
	DirAccess.make_dir_recursive_absolute("res://assets/home-v2/references")
	for species in range(16):
		for age in ["baby","adult"]:
			var frames=rabbit.frames(age,"idle") if species==0 else smooth.frames(species,age,"idle")
			frames[0].get_image().save_png("res://assets/home-v2/references/%s-%s.png"%[catalog.IDS[species],age])
	quit()
