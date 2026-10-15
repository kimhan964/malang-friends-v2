extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var manifests: Dictionary={}
static var banks: Dictionary={}
static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2-interactions/"+Catalog.IDS[species]+"/manifest.json"))
	return manifests[species]
static func frames(species: int,action: String) -> Array:
	var key: String="%d/%s"%[species,action]
	if not banks.has(key):
		for old in banks.keys():
			if not str(old).begins_with(str(species)+"/"): banks.erase(old)
		var spec: Dictionary=data(species).sequences[action]
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-interactions/"+Catalog.IDS[species]+"/"+str(spec.file)))
		var result: Array=[]
		for i in range(int(spec.count)):
			result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*256,int(i/8)*256,256,256))))
		banks[key]=result
	return banks[key]
static func active(m) -> bool:
	return (m.pointer_grab and m.held) or m.carried or m.phase in ["drop","dizzy"] or m.soft_recover_left>0
static func sample(m) -> Dictionary:
	# A stationary press keeps the exact cel that was under the pointer. The
	# newly drawn suspension sequence starts only once an actual lift begins.
	if m.pointer_grab and m.held and not m.carried and not m.soft_touch_sample.is_empty():
		var held: Dictionary=m.soft_touch_sample.duplicate()
		held.soft_interaction=true
		held.bank="touch"
		held.index=0
		return held
	var action="carry"
	var progress=0.0
	if m.carried:
		action="struggle" if m.is_struggling() else "carry"
		var clock: float=m.struggle_age() if m.is_struggling() else maxf(0,m.carry_elapsed-m.carry_started_at)
		progress=fposmod(clock/float(data(m.species).sequences[action].duration),1.0)
	elif m.phase=="drop":
		# Retain a complete suspended pose while the real physics moves the pet.
		progress=.75
	elif m.phase=="dizzy":
		if m.landing_left>0:
			action="landing"
			progress=clampf(1-m.landing_left/m.DIZZY_LANDING,0,1)
		elif m.elapsed>=m.dizzy_duration-.65:
			action="recover"
			progress=clampf((m.elapsed-(m.dizzy_duration-.65))/.65,0,1)
			if not m.soft_dizzy_wobble: progress=lerpf(.5,1.0,progress)
		else:
			action="dizzy"
			progress=fposmod(maxf(0,m.elapsed-m.DIZZY_LANDING)/1.4,1.0)
	elif m.soft_recover_left>0:
		action="recover"
		progress=lerpf(.5,1.0,1-clampf(m.soft_recover_left/.65,0,1))
	var cels: Array=frames(m.species,action)
	var index: int=clampi(int(progress*(cels.size() if action in ["carry","struggle","dizzy"] else cels.size()-1)),0,cels.size()-1)
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":action,"stage":preload("res://scripts/smooth_species_art.gd").stage(m),"index":index,"height":float(data(m.species).reference_height),"mouth":Vector2(156,125),"hand":Vector2(151,175),"fixed_cels":true,"soft_roster":true,"soft_interaction":true,"bank":action,"anchor":Vector2(128,232),"root_offset":Vector2.ZERO}
