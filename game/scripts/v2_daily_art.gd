extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
const KINDS=["sad","peek","drink","sing","study","work","pajama","fight"]
const HOME_ACTIONS={"home_shelf":"study","home_reading_chair":"study","home_wall_shelf":"study","home_record_player":"sing","home_turntable":"sing","home_tea":"drink"}
static var manifests={}
static var banks={}
static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		var path="res://assets/v2-daily/"+Catalog.IDS[species]+"/manifest.json"
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return manifests[species]
static func frames(species: int,action: String) -> Array:
	var key="%d/%s"%[species,action]
	if not banks.has(key):
		for old in banks.keys():
			if not str(old).begins_with(str(species)+"/"): banks.erase(old)
		var result=[]
		var image=Image.new()
		var spec: Dictionary=data(species).sequences[action]
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-daily/"+Catalog.IDS[species]+"/"+str(spec.file)))
		for i in range(int(spec.count)): result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*256,int(i/8)*256,256,256))))
		banks[key]=result
	return banks[key]
static func active(m) -> bool:
	return (m.phase=="daily_action" and not m.daily.action.is_empty()) or (m.phase=="drink" and m.visit_id=="home_water") or (m.phase=="home_use" and HOME_ACTIONS.has(m.visit_id))
static func sample(m) -> Dictionary:
	var kind: String=m.daily.action if m.phase=="daily_action" else "drink"
	if m.phase=="home_use": kind=HOME_ACTIONS[m.visit_id]
	if kind in ["roll","fly"]: return preload("res://scripts/adventure_art.gd").sample(m)
	if preload("res://scripts/run_hop_art.gd").has_action(m.species,kind):
		return preload("res://scripts/run_hop_art.gd").sample(m)
	if kind=="run":
		var result=preload("res://scripts/smooth_species_art.gd").sample(m,"walk")
		result.bank="daily-run";result.daily_animation=true
		return result
	if kind in ["jump","happy"]:
		var action="pet"
		var cels=preload("res://scripts/v2_basic_art.gd").frames(m.species,action) if m.species!=3 else preload("res://scripts/soft_hedgehog_art.gd").frames(action)
		var index=mini(cels.size()-1,int(fposmod(m.daily.clock/2.4,1.0)*cels.size()))
		var reference_height=205.0 if m.species!=3 else 210.0
		return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":"daily_"+kind,"bank":"daily-"+kind,"index":index,"height":reference_height,"mouth":Vector2(156,125),"hand":Vector2(151,175),"anchor":Vector2(128,232),"stage":preload("res://scripts/smooth_species_art.gd").stage(m),"home_animation":m.phase=="home_use","daily_animation":true,"fixed_cels":true,"soft_roster":true}
	var cels=frames(m.species,kind)
	var time: float=m.daily.clock if m.phase=="daily_action" else m.elapsed
	var index=mini(cels.size()-1,int(fposmod(time/float(data(m.species).sequences[kind].duration),1.0)*cels.size()))
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":"daily_"+kind,"bank":"daily-"+kind,"index":index,"height":float(data(m.species).reference_height),"mouth":Vector2(156,125),"hand":Vector2(151,175),"anchor":Vector2(128,232),"stage":preload("res://scripts/smooth_species_art.gd").stage(m),"home_animation":m.phase=="home_use","daily_animation":true,"embedded_food":kind=="drink","dressed":kind=="pajama","fixed_cels":true,"soft_roster":true}
