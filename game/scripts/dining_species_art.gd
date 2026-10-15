extends RefCounted
## Reviewed full-image dining banks. Enabled only alongside the motion trial.
const Catalog=preload("res://scripts/animal_catalog.gd")
const ROOT=Vector2(128,232)
static var manifests={}
static var cache={}

static func stage(motion) -> String:
	return "baby" if motion.growth_stage==0 else "adult"

static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		var path="res://assets/dining-v13/"+Catalog.IDS[species]+"/manifest.json"
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(path)) if preload("res://scripts/asset_images.gd").exists(path) else {}
	return manifests[species]

static func enabled(motion,action: String="drink") -> bool:
	return motion.smooth_walk_enabled and data(motion.species).get("stages",{}).get(stage(motion),{}).get("sequences",{}).has(action)

static func spec(motion,action: String="drink") -> Dictionary:
	return data(motion.species).stages[stage(motion)].sequences[action]

static func frames(motion,action: String="drink") -> Array:
	var key="%d/%s/%s"%[motion.species,stage(motion),action]
	if not cache.has(key):
		for old in cache.keys():
			if not str(old).begins_with(str(motion.species)+"/"): cache.erase(old)
		var metadata=spec(motion,action)
		var path="res://assets/dining-v13/"+Catalog.IDS[motion.species]+"/"+str(metadata.file)
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return []
		var cels=[]
		for i in range(int(metadata.count)):
			cels.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%int(metadata.columns)*256,i/int(metadata.columns)*256,256,256))))
		preload("res://scripts/animal_tone.gd").register(cels,motion.species,stage(motion))
		cache[key]=cels
	return cache[key]

static func contact_offset(motion,facing: float) -> Vector2:
	var point=spec(motion).contact_mouth
	var height=float(data(motion.species).stages[stage(motion)].reference_height)
	var scale=110*Catalog.HEIGHTS[motion.species]*motion.growth_scale/height
	return (Vector2(point[0],point[1])-ROOT)*Vector2(facing,1)*scale

static func sample(motion,action: String) -> Dictionary:
	var metadata=spec(motion,action)
	var cels=frames(motion,action)
	var phase=fposmod(motion.elapsed/float(metadata.duration),1.0)
	var index=mini(cels.size()-1,int(phase*cels.size()))
	var point=metadata.anchors[index]
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":action,"stage":stage(motion),"index":index,"height":float(data(motion.species).stages[stage(motion)].reference_height),"mouth":Vector2(point[0],point[1]),"hand":Vector2(148,175),"fixed_cels":true,"dining":true,"bank":"drink-v13"}
