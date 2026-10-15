extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var manifests: Dictionary={}
static var banks: Dictionary={}
static var version=2
static func asset_root(species: int) -> String:
	return "res://assets/soft-roster-v2/"+Catalog.IDS[species]+"/"
static func asset_version(_species: int) -> int: return 2
static func select_version(_value: int) -> void:
	manifests.clear()
	banks.clear()
static func stage(motion) -> String:
	return "baby" if (motion.growth_stage==0 if motion.growth_stage>=0 else motion.growth_scale<.7) else "adult"
static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(asset_root(species)+"manifest.json"))
	return manifests[species]
static func enabled(motion) -> bool:
	return motion.smooth_walk_enabled and motion.species>=0 and data(motion.species).get("stages",{}).has(stage(motion))
static func spec(motion) -> Dictionary:
	var result: Dictionary=data(motion.species).stages[stage(motion)].duplicate()
	# Shorter physical stride at 2/3 size, with 1.3x the previous world speed.
	result.cycle_seconds=float(result.get("playback_seconds",1.6))*(Catalog.DISPLAY_HEIGHT/110.0)/Catalog.WORLD_SPEED_MULTIPLIER
	return result
static func frames(species: int,age: String,action: String="walk") -> Array:
	var key: String="%d/%s/%s"%[species,age,action]
	if not banks.has(key):
		for old in banks.keys():
			if not str(old).begins_with(str(species)+"/"): banks.erase(old)
		var metadata: Dictionary=data(species).stages[age]
		var path: String=asset_root(species)+str(metadata.idle_file if action=="idle" else metadata.file)
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return []
		var result: Array=[]
		if action=="idle": result.append(ImageTexture.create_from_image(image))
		else:
			var columns: int=int(metadata.get("columns",8))
			for i in range(int(metadata.count)):
				result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%columns*256,int(i/columns)*256,256,256))))
		# Preserve original approved colors; do not calibrate to the old skin.
		banks[key]=result
	return banks[key]
static func sample(motion,action: String) -> Dictionary:
	var age: String=stage(motion)
	var cels: Array=frames(motion.species,age,action)
	var index: int=mini(cels.size()-1,int(fposmod(motion.walk_phase,1.0)*cels.size())) if action=="walk" else 0
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":action,"stage":age,"index":index,"height":float(spec(motion).reference_height),"mouth":Vector2(158,120),"hand":Vector2(151,177),"smooth_walk":action=="walk","bank":action,"fixed_cels":true,"anchor":Vector2(128,232),"root_offset":Vector2.ZERO}
