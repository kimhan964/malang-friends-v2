extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
const Basic=preload("res://scripts/v2_basic_art.gd")
const KEYS={"basket":"play","home_sofa":"sofa","home_daybed":"bed","home_bathtub":"bath","home_toy_plush":"play"}
const EDGE=.65
static var manifests: Dictionary={}
static var banks: Dictionary={}
static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2-life/"+Catalog.IDS[species]+"/manifest.json"))
	return manifests[species]
static func frames(species: int,action: String,enter: bool=false) -> Array:
	var key: String="%d/%s/%s"%[species,action,str(enter)]
	if not banks.has(key):
		for old in banks.keys():
			if not str(old).begins_with(str(species)+"/"): banks.erase(old)
		var spec: Dictionary=data(species).sequences[action]
		var file: String=spec.enter_file if enter else spec.file
		var count: int=int(spec.enter_count if enter else spec.count)
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-life/"+Catalog.IDS[species]+"/"+file))
		var result: Array=[]
		for i in range(count): result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*256,int(i/8)*256,256,256))))
		banks[key]=result
	return banks[key]
static func active(m) -> bool:
	return (m.phase=="home_use" and KEYS.has(m.visit_id)) or (m.phase=="sniff" and m.soft_toy_contact) or (m.phase=="prop_use" and m.visit_id=="acorn")
static func sample(m) -> Dictionary:
	var action: String=KEYS.get(m.visit_id,"play")
	var spec: Dictionary=data(m.species).sequences[action]
	var is_toy: bool=m.phase in ["sniff","prop_use"]
	var duration: float=preload("res://scripts/home_animation.gd").duration(m.visit_id)
	var progress: float=clampf((m.elapsed-EDGE)/maxf(.01,duration-2*EDGE),0,1)
	var loops: int=maxi(1,roundi((duration-2*EDGE)/float(spec.duration)))
	var index: int=mini(31,int(fposmod(progress*loops,1)*32))
	var cels: Array
	var transition=false
	if not is_toy and (m.elapsed<EDGE or m.action_left<EDGE):
		transition=true
		var t: float=clampf(m.elapsed/EDGE if m.elapsed<EDGE else m.action_left/EDGE,0,1)
		cels=frames(m.species,action,true)
		index=mini(cels.size()-1,roundi(t*(cels.size()-1)))
	else:
		cels=frames(m.species,action)
		if is_toy: index=mini(31,int(fposmod((m.elapsed if m.visit_id=="acorn" else m.soft_toy_time)/float(spec.duration),1)*32))
	var hand=Vector2(146,194)
	if action=="play" and m.species==3:
		var p=float(index)/32*TAU
		hand=Vector2(166,183-6*(.5-.5*cos(p)))
	elif action=="play" and m.species==15:hand=Vector2(162,176)
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":action,"bank":"life_"+action,"index":index,"height":205.0,"anchor":Vector2(128,232),"mouth":Vector2(163,154),"hand":hand,"fixed_cels":true,"soft_roster":true,"home_animation":not is_toy,"life_animation":true,"life_transition":transition,"stage":preload("res://scripts/smooth_species_art.gd").stage(m)}
