extends RefCounted
## Fresh complete-character illustrations. No limb rigging or crossfade.
const Catalog=preload("res://scripts/animal_catalog.gd")
const KINDS={"basket":"play","home_sofa":"rest","home_tea":"tea","home_shelf":"read","home_lamp":"nap","home_reading_chair":"read","home_daybed":"nap","home_vanity":"groom","home_record_player":"music","home_play_rug":"play","home_window_seat":"rest","home_tv":"rest","home_turntable":"music","home_wall_shelf":"read","home_dresser":"groom","home_fireplace":"rest","home_bathtub":"bath","home_toy_plush":"play"}
const DURATIONS={"rest":8.0,"tea":7.2,"read":8.4,"nap":10.8,"groom":6.8,"music":7.2,"play":6.4}
# These are authored key poses with deliberate holds, not 60 newly drawn cels.
const TRACKS={
	"rest":[0,1,2,3,4,3,4,3,2,1,0],
	"tea":[0,1,2,3,2,3,2,4,5,0],
	"read":[0,1,2,3,4,2,3,4,5,0],
	"nap":[0,1,2,3,4,3,4,3,4,2,5,0],
	"groom":[0,1,2,1,3,4,3,5,0],
	"music":[0,1,2,0,3,4,3,0,1,2,0],
	"play":[0,1,2,3,4,5,4,0]}
static var manifests={}
static var textures={}
static func age(m) -> String: return "baby" if m.growth_stage==0 else "adult"
static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		var path="res://assets/home-v2/%s/manifest.json"%Catalog.IDS[species]
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(path)) if preload("res://scripts/asset_images.gd").exists(path) else {}
	return manifests[species]
static func available(m) -> bool:
	if FileAccess.file_exists("res://assets/v2-life/"+Catalog.IDS[m.species]+"/manifest.json"): return true
	if FileAccess.file_exists("res://assets/v2-basics/"+Catalog.IDS[m.species]+"/manifest.json"): return m.outfit_style==0
	return m.outfit_style==0 and data(m.species).get("stages",{}).has(age(m))
static func active(m) -> bool:
	return m.phase=="home_use" and KINDS.has(m.visit_id) and available(m)
static func base_duration(id: String) -> float:
	return {"home_sofa":7.7,"home_daybed":10.9,"home_bathtub":10.9,"home_toy_plush":6.1}.get(id,DURATIONS.get(KINDS.get(id,"rest"),8.0))
static func duration(id: String) -> float:
	return base_duration(id)*4.0
static func frames(m,kind: String) -> Array:
	var key="%d/%s/%s"%[m.species,age(m),kind]
	if not textures.has(key):
		for old in textures.keys():
			if not str(old).begins_with(str(m.species)+"/"): textures.erase(old)
		var metadata=data(m.species).stages[age(m)]
		var source=metadata.get("overrides",{}).get(kind,metadata)
		var image=Image.new()
		preload("res://scripts/asset_images.gd").decode_into(image,"res://assets/home-v2/%s/%s"%[Catalog.IDS[m.species],source.file])
		var cels=[]
		for frame in metadata.sequences[kind]:
			var r=frame.rect
			cels.append(ImageTexture.create_from_image(image.get_region(Rect2i(r[0],r[1],r[2],r[3]))))
		preload("res://scripts/animal_tone.gd").register(cels,m.species,age(m))
		textures[key]=cels
	return textures[key]
static func sample(m) -> Dictionary:
	var kind: String=KINDS[m.visit_id]
	var track: Array=TRACKS[kind]
	var phase=fposmod(m.elapsed/base_duration(m.visit_id),1.0)
	var index=int(track[mini(track.size()-1,int(phase*track.size()))])
	if kind!="rest" and (m.elapsed<.55 or m.action_left<.55):
		kind="rest"
		index=0 if m.elapsed<.2 or m.action_left<.2 else 1
	var metadata=data(m.species).stages[age(m)]
	var anchor=metadata.sequences[kind][index].anchor
	var source=metadata.get("overrides",{}).get(kind,metadata)
	return {"texture":frames(m,kind)[index],"action":"home_use","stage":age(m),"index":index,"height":float(source.reference_height),"anchor":Vector2(anchor[0],anchor[1]),"mouth":Vector2.ZERO,"hand":Vector2.ZERO,"fixed_cels":true,"home_animation":true,"embedded_food":true,"bank":kind}
