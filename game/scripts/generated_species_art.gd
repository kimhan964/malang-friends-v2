extends RefCounted
## VARCO full-character cels for all species, with separate baby/adult masters.
## Uses complete raster frames only; no anatomical part rig or recomposition.
const Catalog=preload("res://scripts/animal_catalog.gd")
const ROOT=Vector2(128,232)
const SIZE=256
static var manifests: Dictionary={}
static var cache: Dictionary={}
static var dressed_cache: Dictionary={}

static func release_other_species(species: int) -> void:
	preload("res://scripts/slapstick.gd").release_other_species(species)
	preload("res://scripts/hold_transition_art.gd").release_other_species(species)
	preload("res://scripts/struggle_art.gd").release_other_species(species)
	# This game shows one selected pet. Switching species must release the
	# previous pet's predecoded action banks rather than accumulating gigabytes.
	for key in cache.keys():
		if not str(key).begins_with(str(species)+"/"): cache.erase(key)
	for key in dressed_cache.keys():
		if not str(key).begins_with(Catalog.IDS[species]+"/"): dressed_cache.erase(key)

static func asset_root(species: int) -> String:
	# The approved current bank is mandatory; never silently resurrect old art.
	return "res://assets/species-v3/"+Catalog.IDS[species]

static func data(species: int) -> Dictionary:
	if not manifests.has(species):
		manifests[species]=JSON.parse_string(FileAccess.get_file_as_string(asset_root(species)+"/manifest.json"))
	return manifests[species]

static func stage_name(motion) -> String:
	var baby=motion.growth_stage==0 if motion.growth_stage>=0 else motion.growth_scale<.7
	return "baby" if baby else "adult"

static func frames(species: int, stage: String, action: String) -> Array:
	var key=str(species)+"/"+stage+"/"+action
	if not cache.has(key):
		var spec=data(species).stages[stage].sequences[action]
		var sheet=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(sheet,asset_root(species)+"/"+str(spec.file))!=OK: return []
		var sequence: Array=[]
		var columns=int(spec.get("columns",8))
		for i in range(int(spec.count)):
			sequence.append(ImageTexture.create_from_image(sheet.get_region(Rect2i(i%columns*SIZE,i/columns*SIZE,SIZE,SIZE))))
		preload("res://scripts/animal_tone.gd").register(sequence,species,stage)
		cache[key]=sequence
	return cache[key]

static func dressed_frames(species: int, stage: String, style: int, action: String) -> Array:
	var key="%s/%s/%s/%s"%[Catalog.IDS[species],stage,["cape","vest","sweater"][style-1],action]
	if not dressed_cache.has(key):
		var path="res://assets/outfits-dressed-v2/"+key+".png"
		if not preload("res://scripts/asset_images.gd").exists(path): return []
		var strip=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(strip,path)!=OK: return []
		if strip==null or strip.get_width()!=SIZE*16 or strip.get_height()!=SIZE: return []
		var sequence: Array=[]
		for i in range(16):
			sequence.append(ImageTexture.create_from_image(strip.get_region(Rect2i(i*SIZE,0,SIZE,SIZE))))
		dressed_cache[key]=sequence
	return dressed_cache[key]

static func action_for(motion) -> String:
	if motion.phase=="drop": return "carry"
	if motion.carried: return "carry"
	if motion.pointer_grab and motion.held: return "idle"
	if motion.landing_left>0: return "land"
	if motion.phase=="drink" and motion.visit_id=="water":
		if preload("res://scripts/dining_species_art.gd").enabled(motion): return "drink"
		return "drink" if motion.rabbit_pilot and preload("res://scripts/rabbit_pilot_art.gd").data().stages[stage_name(motion)].sequences.has("drink") else "sniff"
	match motion.phase:
		"wander","chase","return","visit":
			return "idle" if motion.held else "walk"
		"eat","drink","look","sniff","stretch","groom","rub":
			return motion.phase
		"doze": return "sleep"
		"relax": return "rest"
		"pet","cuddle": return "pet"
		"signature","playful": return "jump"
		"askplay","greet": return "wave"
		"inspect","ball_ready": return "look"
		"prop_use": return "toy" if motion.visit_id in ["plant","acorn"] else "rest"
		"react":
			match motion.reaction:
				"pet","yum","full","gift","nest": return "pet"
				"greet","askplay": return "wave"
				"inspect","anticipate": return "look"
	if motion.joy_left>0: return "pet"
	return "idle"

static func consumption_phase(action: String, phase: float) -> float:
	# Generated cels are evenly spaced, but natural eating is not: approach,
	# repeated bites/sips, swallow, then a short neutral pause.
	if action=="eat":
		if phase<.16: return remap(phase,0.0,.16,0.0,.25)
		if phase<.68: return remap(phase,.16,.68,.25,.75)
		if phase<.84: return remap(phase,.68,.84,.75,.94)
		return .97
	if action=="drink":
		if phase<.20: return remap(phase,0.0,.20,0.0,.31)
		if phase<.72: return remap(phase,.20,.72,.31,.75)
		if phase<.86: return remap(phase,.72,.86,.75,.94)
		return .97
	return phase

static func sample(motion) -> Dictionary:
	# Walking has one current source. Missing assets must never select old cels.
	if action_for(motion)=="walk":
		if motion.species==0:
			return preload("res://scripts/rabbit_pilot_art.gd").sample(motion,stage_name(motion),"walk")
		return preload("res://scripts/smooth_species_art.gd").sample(motion,"walk")
	if preload("res://scripts/home_animation.gd").active(motion): return preload("res://scripts/home_animation.gd").sample(motion)
	var species: int=motion.species
	var stage=stage_name(motion)
	var action=action_for(motion)
	var hold_sample=preload("res://scripts/hold_transition_art.gd").sample(motion)
	if not hold_sample.is_empty(): return hold_sample
	if motion.is_struggling() and preload("res://scripts/struggle_art.gd").available(motion):
		return preload("res://scripts/struggle_art.gd").sample(motion)
	if action in ["idle","walk"] and preload("res://scripts/smooth_species_art.gd").enabled(motion):
		return preload("res://scripts/smooth_species_art.gd").sample(motion,action)
	if action=="drink" and motion.visit_id=="water" and preload("res://scripts/dining_species_art.gd").enabled(motion):
		return preload("res://scripts/dining_species_art.gd").sample(motion,action)
	var pilot_action=action in ["idle","walk"] or (action=="eat" and motion.food_id==Catalog.DEFAULT_MEALS[0]) or (action=="drink" and motion.visit_id=="water")
	if motion.rabbit_pilot and species==0 and pilot_action and preload("res://scripts/rabbit_pilot_art.gd").data().stages[stage].sequences.has(action):
		return preload("res://scripts/rabbit_pilot_art.gd").sample(motion,stage,action)
	var sequence="carry" if action=="land" else action
	var spec=data(species).stages[stage].sequences[sequence]
	var count=int(spec.count)
	var time=motion.reaction_time if motion.phase=="react" else motion.elapsed
	if action=="carry": time=motion.carry_elapsed
	var phase=fposmod(time/float(spec.duration),1.0)
	if motion.phase=="drink" and motion.visit_id=="water": phase=fposmod(time/3.2,1.0)
	if action=="walk": phase=fposmod(motion.walk_phase,1.0)
	# One complete approach/bite/recovery. The old 3.2 s modulo restarted
	# midway through the 5.5 s meal, then cut the second bite off abruptly.
	if action=="eat": phase=preload("res://scripts/eating_timing.gd").progress(time)
	if action=="drink" and motion.visit_id=="home_water": phase=preload("res://scripts/eating_timing.gd").progress(time)
	if action=="stretch": phase=clampf(time/float(spec.duration),0,.99999)
	if action in ["eat","drink"]: phase=consumption_phase(action,phase)
	var index=mini(count-1,int(phase*count))
	if action=="idle":
		if count>8:
			index=mini(count-1,int(phase*count))
		else:
			var elapsed=fposmod(time,4.8)
			var holds=[1.8,.9,.06,.09,.06,.2,.7,.99]
			index=7
			for i in range(8):
				if elapsed<holds[i]:
					index=i
					break
				elapsed-=holds[i]
	elif action=="sleep":
		var quarter=maxi(2,count/4)
		if time<.7: index=mini(quarter-1,int(time/.7*quarter))
		elif not motion.stay_after_visit and motion.action_left<.45: index=count-quarter+mini(quarter-1,int((.45-motion.action_left)/.45*quarter))
		else: index=quarter+int(time/.45)%maxi(2,count-quarter*2)
	elif action=="rest":
		var quarter=maxi(2,count/4)
		if time<.7: index=mini(quarter-1,int(time/.7*quarter))
		elif motion.action_left>0 and motion.action_left<.3: index=count-1
		else: index=quarter+int(time/.55)%maxi(2,count-quarter*2)
	elif action=="carry":
		var quarter=maxi(2,count/4)
		index=quarter # Quiet suspended pose until the deliberate three-second protest.
		if motion.phase=="drop": index=quarter
	elif action=="land":
		var quarter=maxi(2,count/4)
		var landing_duration=motion.DIZZY_LANDING if motion.phase=="dizzy" else .24
		index=count-quarter+mini(quarter-1,int(clampf(1-motion.landing_left/landing_duration,0,.99999)*quarter))
	elif motion.phase=="react" and action in ["pet","wave"]:
		index=mini(count-1,int(clampf(time/maxf(.01,motion.reaction_duration),0,.99999)*count))
	var result=sample_frame(species,stage,sequence,index)
	apply_dressed(result,motion)
	result.action=action
	if action=="eat":
		result.fixed_cels=true
		result.mouth=preload("res://scripts/eating_timing.gd").mouth_point(species,stage,result.mouth,spec.anchors[4].mouth)
	if action=="drink" and motion.visit_id=="home_water":
		result.fixed_cels=true
		result.mouth=preload("res://scripts/eating_timing.gd").mouth_point(species,stage,result.mouth,data(species).stages[stage].sequences.eat.anchors[4].mouth)
	return result

static func apply_dressed(result: Dictionary, motion) -> void:
	# The legacy dressed bank contains the OLD animal, not just its clothing.
	# Every palette must keep the same current character and animation bank.
	# Garments are drawn by OutfitLayer without replacing the animal cel.
	pass

static func sample_frame(species: int, stage: String, action: String, index: int) -> Dictionary:
	var spec=data(species).stages[stage].sequences[action]
	var anchor=spec.anchors[index]
	return {"texture":frames(species,stage,action)[index],"action":action,"stage":stage,
		"index":index,"height":float(data(species).stages[stage].reference_height),
		"mouth":Vector2(anchor.mouth[0],anchor.mouth[1]),"hand":Vector2(anchor.hand[0],anchor.hand[1])}
