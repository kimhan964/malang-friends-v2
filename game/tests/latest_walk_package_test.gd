extends SceneTree
const Catalog=preload("res://scripts/animal_catalog.gd")
const Art=preload("res://scripts/smooth_species_art.gd")
const Rabbit=preload("res://scripts/rabbit_pilot_art.gd")
func _initialize() -> void:
	if not preload("res://tests/pack_fixture.gd").mount(): quit(1);return
	var failures=[]
	for species in range(1,16):
		var d=Art.data(species)
		for age in ["baby","adult"]:
			if not d.get("stages",{}).has(age): failures.append(Catalog.IDS[species]+"/"+age);continue
			var frames=Art.frames(species,age)
			if frames.size()!=60: failures.append("not 60 cels "+Catalog.IDS[species]+age)
	for age in ["baby","adult"]:
		if not Rabbit.data().get("stages",{}).has(age): failures.append("rabbit missing "+age);continue
		if Rabbit.frames(age,"walk").size()!=60: failures.append("rabbit not 60 "+age)
	print("LATEST WALK PACKAGE: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
