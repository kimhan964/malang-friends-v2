extends SceneTree
const Images=preload("res://scripts/asset_images.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
var failures=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not preload("res://tests/pack_fixture.gd").mount(): quit(1);return
	var index=Images.metadata()
	if index.is_empty(): failures.append("Missing storage index")
	var count=0
	for path in index:
		var spec=index[path]
		var image=Images.load_image(path)
		if image==null: failures.append("Missing image: "+path);continue
		if image.get_size()!=Vector2i(int(spec.size[0]),int(spec.size[1])): failures.append("Canvas changed: "+path)
		var crop=image.get_region(Rect2i(int(spec.offset[0]),int(spec.offset[1]),int(spec.crop_size[0]),int(spec.crop_size[1])))
		var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(crop.get_data())
		if hash.finish().hex_encode()!=str(spec.cropped_rgba_sha256): failures.append("RGBA pixels changed: "+path)
		count+=1
		if count%200==0:
			print("RGBA VERIFIED ",count)
			await process_frame
	for species in range(16):
		Art.release_other_species(species)
		for age in ["baby","adult"]:
			var m=Motion.new();m.species=species;m.growth_stage=0 if age=="baby" else 2
			for action in Art.data(species).stages[age].sequences:
				if Art.frames(species,age,action).is_empty(): failures.append("Missing action "+Catalog.IDS[species]+age+action)
			for kind in preload("res://scripts/home_animation.gd").TRACKS:
				if preload("res://scripts/home_animation.gd").frames(m,kind).size()!=6: failures.append("Missing home "+str(species)+age+kind)
			for kind in preload("res://scripts/slapstick.gd").DURATIONS:
				if preload("res://scripts/slapstick.gd").frames(m,kind).is_empty(): failures.append("Missing silly "+str(species)+age+kind)
			for kind in preload("res://scripts/emotion_art.gd").KINDS:
				if preload("res://scripts/emotion_art.gd").texture(species,age,kind)==null: failures.append("Missing expression")
			for name in preload("res://scripts/hold_transition_art.gd").NAMES:
				if preload("res://scripts/hold_transition_art.gd").frames(species,age,name).size()!=17: failures.append("Missing hold bridge")
			if preload("res://scripts/struggle_art.gd").frames(species,age).size()!=60: failures.append("Missing struggle")
		print("ANIMAL ACTIONS VERIFIED ",Catalog.IDS[species])
		await process_frame
	for id in preload("res://scripts/furniture_catalog.gd").ITEMS:
		if preload("res://scripts/furniture_catalog.gd").texture(id)==null: failures.append("Missing furniture "+id)
	print("OPTIMIZED ASSETS: ","PASS" if failures.is_empty() else failures," images=",count)
	quit(0 if failures.is_empty() else 1)
