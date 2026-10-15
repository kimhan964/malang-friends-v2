extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var manifests: Dictionary={}
static var banks: Dictionary={}
static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		var path="res://assets/v2-run-hop/"+Catalog.IDS[species]+"/manifest.json"
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return manifests[species]
static func has_action(species: int,action: String) -> bool:
	return data(species).get("sequences",{}).has(action)
static func spec(species: int,action: String) -> Dictionary:
	return data(species).get("sequences",{}).get(action,{})
static func frames(species: int,action: String) -> Array:
	var key="%d/%s"%[species,action]
	if not banks.has(key):
		var metadata=spec(species,action)
		var im=Image.new();var result=[]
		var path="res://assets/v2-run-hop/"+Catalog.IDS[species]+"/"+str(metadata.file)
		if im.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK: return []
		for i in range(metadata.count):
			result.append(ImageTexture.create_from_image(im.get_region(Rect2i(i%int(metadata.columns)*256,int(i/int(metadata.columns))*256,256,256))))
		banks[key]=result
	return banks[key]
static func phase_at(metadata: Dictionary,seconds: float) -> float:
	return fposmod(seconds/float(metadata.duration),1.0) if metadata.loop else clampf(seconds/float(metadata.duration),0,1)
static func frame_index(metadata: Dictionary,seconds: float) -> int:
	var phase=phase_at(metadata,seconds)
	var curve: Array=metadata.get("phase_curve",[])
	for i in range(maxi(0,curve.size()-1)):
		if phase<=float(curve[i+1][0]):
			phase=lerpf(float(curve[i][1]),float(curve[i+1][1]),inverse_lerp(float(curve[i][0]),float(curve[i+1][0]),phase));break
	return mini(metadata.count-1,int(phase*(metadata.count if metadata.loop else metadata.count-1)))
static func lift_at(metadata: Dictionary,seconds: float) -> float:
	var phase=phase_at(metadata,seconds)
	var t=clampf(inverse_lerp(float(metadata.launch),float(metadata.land),phase),0,1)
	return maxf(0,sin(PI*t))*float(metadata.lift)
static func sample(m) -> Dictionary:
	var action: String=m.daily.action
	var metadata=spec(m.species,action)
	var cels=frames(m.species,action)
	var index=frame_index(metadata,m.daily.clock)
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":"daily_"+action,"bank":"daily-"+action,"index":index,"height":float(data(m.species).reference_height),"anchor":Vector2(128,232),"mouth":Vector2(158,125),"hand":Vector2(151,175),"stage":preload("res://scripts/smooth_species_art.gd").stage(m),"daily_animation":true,"fixed_cels":true,"soft_roster":true,"run_hop":true,"lift":lift_at(metadata,m.daily.clock)}
