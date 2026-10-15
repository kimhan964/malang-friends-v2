extends RefCounted
## The approved roster uses complete, unchanged raster cels.
const Smooth=preload("res://scripts/smooth_species_art.gd")
static func prewarm(motion) -> Array:
	var result: Array=Smooth.frames(motion.species,Smooth.stage(motion),"walk").duplicate()
	result.append_array(Smooth.frames(motion.species,Smooth.stage(motion),"idle"))
	if motion.species==3:
		for action in ["idle","pet","sleep","eat"]:
			result.append_array(preload("res://scripts/soft_hedgehog_art.gd").frames(action))
	else:
		for action in ["idle","pet","sleep","eat"]:
			result.append_array(preload("res://scripts/v2_basic_art.gd").frames(motion.species,action))
	for action in ["carry","struggle","landing","dizzy","recover"]:
		result.append_array(preload("res://scripts/v2_interaction_art.gd").frames(motion.species,action))
	for action in ["sofa","bed","play","bath"]:
		result.append_array(preload("res://scripts/v2_life_art.gd").frames(motion.species,action))
		result.append_array(preload("res://scripts/v2_life_art.gd").frames(motion.species,action,true))
	# Prepare complete cels and their hit outlines before normal play begins.
	for action in preload("res://scripts/v2_daily_art.gd").KINDS:
		result.append_array(preload("res://scripts/v2_daily_art.gd").frames(motion.species,action))
	for action in ["roll","fly"]:
		result.append_array(preload("res://scripts/adventure_art.gd").frames(motion.species,action))
	for action in ["run","jump"]:
		if preload("res://scripts/run_hop_art.gd").has_action(motion.species,action):
			result.append_array(preload("res://scripts/run_hop_art.gd").frames(motion.species,action))
	return result
static func sample(motion) -> Dictionary:
	var result: Dictionary
	if preload("res://scripts/v2_interaction_art.gd").active(motion):
		result=preload("res://scripts/v2_interaction_art.gd").sample(motion)
	elif preload("res://scripts/v2_daily_art.gd").active(motion):
		result=preload("res://scripts/v2_daily_art.gd").sample(motion)
	elif preload("res://scripts/v2_life_art.gd").active(motion):
		result=preload("res://scripts/v2_life_art.gd").sample(motion)
	elif motion.species==3:
		result=preload("res://scripts/soft_hedgehog_art.gd").sample(motion)
	else:
		var walking: bool=motion.phase in ["wander","chase","return","visit"] and not motion.held and not motion.carried and motion.landing_left<=0
		# Walking retains the approved atlas; basic care uses this skin's new cels.
		result=Smooth.sample(motion,"walk") if walking else preload("res://scripts/v2_basic_art.gd").sample(motion)
	result.soft_roster=true
	result.fixed_cels=true
	if result.bank!="touch" and not result.get("adventure_animation",false): result.anchor=Vector2(128,232)
	return result
