extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var manifests: Dictionary={}
static var banks: Dictionary={}
static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		var path: String="res://assets/v2-basics/"+Catalog.IDS[species]+"/manifest.json"
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return manifests[species]
static func frames(species: int,action: String) -> Array:
	var key: String="%d/%s"%[species,action]
	if not banks.has(key):
		for old in banks.keys():
			if not str(old).begins_with(str(species)+"/"): banks.erase(old)
		var spec: Dictionary=data(species).sequences[action]
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-basics/"+Catalog.IDS[species]+"/"+str(spec.file)))
		var result: Array=[]
		var columns: int=int(spec.columns)
		for i in range(int(spec.count)):
			result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%columns*256,int(i/columns)*256,256,256))))
		banks[key]=result
	return banks[key]
static func action_for(motion) -> String:
	if motion.phase=="home_use":
		var kind: String=preload("res://scripts/home_animation.gd").KINDS.get(motion.visit_id,"rest")
		return {"nap":"sleep","tea":"eat","music":"pet","play":"pet","groom":"pet","read":"idle","rest":"idle"}.get(kind,"idle")
	if motion.phase in ["doze","relax"]: return "sleep" if motion.phase=="doze" else "idle"
	if motion.phase in ["eat","drink"]: return "eat"
	if motion.phase in ["pet","cuddle","groom","rub","signature","playful","greet","askplay"] or motion.joy_left>0: return "pet"
	if motion.phase=="react":
		return "sleep" if motion.reaction=="sleepy" else ("pet" if motion.reaction in ["pet","happy","greet","askplay","gift","yum","full"] else "idle")
	return "idle"
static func sample(motion) -> Dictionary:
	var action: String=action_for(motion)
	var spec: Dictionary=data(motion.species).sequences[action]
	var cels: Array=frames(motion.species,action)
	var time: float=motion.reaction_time if motion.phase=="react" else motion.elapsed
	var phase: float=fposmod(time/float(spec.duration),1.0)
	var curve: Array=spec.get("phase_curve",[])
	if curve.size()>1:
		for i in range(curve.size()-1):
			if phase<=float(curve[i+1][0]):
				phase=lerpf(float(curve[i][1]),float(curve[i+1][1]),inverse_lerp(float(curve[i][0]),float(curve[i+1][0]),phase))
				break
	var index: int=mini(cels.size()-1,int(phase*cels.size()))
	var mouth: Array=spec.mouth[index]
	var hand: Array=spec.hand
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":action,"stage":preload("res://scripts/smooth_species_art.gd").stage(motion),"index":index,"height":float(spec.reference_height),"mouth":Vector2(mouth[0],mouth[1]),"hand":Vector2(hand[0],hand[1]),"fixed_cels":true,"soft_roster":true,"home_animation":motion.phase=="home_use","bank":action,"anchor":Vector2(128,232),"root_offset":Vector2.ZERO}
