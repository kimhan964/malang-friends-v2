extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var metadata={}
static var banks={}
static func data(species: int) -> Dictionary:
	if not metadata.has(species): metadata[species]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2-adventure/"+Catalog.IDS[species]+"/manifest.json"))
	return metadata[species]
static func frames(species: int,kind: String) -> Array:
	var key="%d/%s"%[species,kind]
	if not banks.has(key):
		for old in banks.keys():
			if not str(old).begins_with(str(species)+"/"): banks.erase(old)
		var entry: Dictionary=data(species).sequences[kind]
		var image=Image.new();image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-adventure/"+Catalog.IDS[species]+"/"+str(entry.get("file",kind+".png"))))
		var result=[]
		for i in range(32): result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*320,int(i/8)*320,320,320))))
		banks[key]=result
	return banks[key]
static func sample(m) -> Dictionary:
	var kind: String=m.daily.action
	var spec: Dictionary=data(m.species)
	var cels=frames(m.species,kind)
	var index=mini(31,int(fposmod(m.daily.clock/float(spec.sequences[kind].duration),1.0)*32))
	var anchor=spec.anchor
	var result={"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":"adventure_"+kind,"bank":"adventure-"+kind,"index":index,"height":float(spec.reference_height),"mouth":Vector2(170,175),"hand":Vector2(170,225),"anchor":Vector2(anchor[0],anchor[1]),"stage":preload("res://scripts/smooth_species_art.gd").stage(m),"fixed_cels":true,"soft_roster":true,"adventure_animation":true}
	if kind=="roll":
		result.roll_center=Vector2(spec.roll_center[0],spec.roll_center[1]);result.roll_radius=float(spec.roll_radius)
		result.roll_angle=m.daily.direction*TAU*smoothstep(.1,.88,m.daily.clock/4.0)
	else:
		var p=clampf(m.daily.clock/6.0,0,1)
		var envelope=smoothstep(0,.18,p)*smoothstep(0,.18,1-p)
		result.flight_lift=(65+sin(m.daily.clock*TAU/2.2)*3)*envelope*m.growth_scale
	return result
