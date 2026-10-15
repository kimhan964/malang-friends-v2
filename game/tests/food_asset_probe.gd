extends SceneTree
func _initialize() -> void:
	for species in [0,1,14]:
		var tex=preload("res://scripts/food_catalog.gd").icon_for(species,preload("res://scripts/animal_catalog.gd").DEFAULT_MEALS[species])
		tex.get_image().save_png("res://interior-eating-review-2026-10-05/food-%d.png"%species)
		print("FOOD ",species," ",tex.get_size())
	quit()
