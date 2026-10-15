extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var manifests: Dictionary={}
static var cache: Dictionary={}

static func release_other_species(species: int) -> void:
	for key in cache.keys():
		if not str(key).begins_with(str(species)+"/"): cache.erase(key)

static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		var path="res://assets/struggle-v1/%s/manifest.json"%Catalog.IDS[species]
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(path)) if preload("res://scripts/asset_images.gd").exists(path) else {}
	return manifests[species]

static func stage_name(motion) -> String:
	return "baby" if motion.growth_stage==0 or (motion.growth_stage<0 and motion.growth_scale<.7) else "adult"

static func available(motion) -> bool:
	return data(motion.species).get("stages",{}).has(stage_name(motion))

static func frames(species: int,stage: String) -> Array:
	var key="%d/%s"%[species,stage]
	if not cache.has(key):
		var spec=data(species).get("stages",{}).get(stage,{})
		if spec.is_empty(): return []
		var path="res://assets/struggle-v1/%s/%s"%[Catalog.IDS[species],spec.file]
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return []
		var sequence: Array=[]
		for i in range(int(spec.count)):
			sequence.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*256,i/8*256,256,256))))
		preload("res://scripts/animal_tone.gd").register(sequence,species,stage)
		cache[key]=sequence
	return cache[key]

static func sample(motion) -> Dictionary:
	return sample_at(motion,maxf(0.0,motion.struggle_age()-motion.STRUGGLE_ENTRY_SECONDS))

static func sample_at(motion,age: float) -> Dictionary:
	var stage=stage_name(motion)
	var spec=data(motion.species).stages[stage]
	var phase=fposmod(age/float(spec.cycle_seconds),1.0)
	var index=mini(59,int(phase*60))
	return {"texture":frames(motion.species,stage)[index],"action":"carry","stage":stage,
		"index":index,"height":float(spec.reference_height),"fixed_cels":true,"struggle":true,"bank":"struggle-v1",
		"grip":Vector2(spec.grip[0],spec.grip[1]),"mouth":Vector2(138,126),"hand":Vector2(154,171)}
