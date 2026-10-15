extends RefCounted
## VARCO generated full-character cels, separate baby/adult masters.
## One authored coordinate system, no per-pose auto-normalization or part rig.
const ROOT=Vector2(128,232)
const SIZE=256
static var manifest: Dictionary={}
static var cache: Dictionary={}

static func data() -> Dictionary:
	if manifest.is_empty():
		manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rabbit-v3/manifest.json"))
	return manifest

static func stage_name(motion) -> String:
	var baby=motion.growth_stage==0 if motion.growth_stage>=0 else motion.growth_scale<.7
	return "baby" if baby else "adult"

static func frames(stage: String, action: String) -> Array:
	var key=stage+"/"+action
	if not cache.has(key):
		var spec=data().stages[stage].sequences[action]
		var sheet=preload("res://scripts/asset_images.gd").load_image("res://assets/rabbit-v3/"+str(spec.file))
		var sequence: Array=[]
		for i in range(int(spec.count)):
			sequence.append(ImageTexture.create_from_image(sheet.get_region(Rect2i(i%8*SIZE,i/8*SIZE,SIZE,SIZE))))
		cache[key]=sequence
	return cache[key]

static func action_for(motion) -> String:
	if motion.carried: return "carry"
	if motion.landing_left>0: return "land"
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
		"prop_use": return "toy" if motion.visit_id=="plant" else "rest"
		"react":
			match motion.reaction:
				"pet","yum","full","gift","nest": return "pet"
				"greet","askplay": return "wave"
				"inspect","anticipate": return "look"
	if motion.joy_left>0: return "pet"
	return "idle"

static func sample(motion) -> Dictionary:
	var stage=stage_name(motion)
	var action=action_for(motion)
	var sequence="carry" if action=="land" else action
	var spec=data().stages[stage].sequences[sequence]
	var count=int(spec.count)
	var time=motion.reaction_time if motion.phase=="react" else motion.elapsed
	if action=="carry": time=motion.carry_elapsed
	var phase=fposmod(time/float(spec.duration),1.0)
	if action=="walk": phase=fposmod(motion.walk_phase,1.0)
	if action=="stretch": phase=clampf(time/float(spec.duration),0,.99999)
	var index=mini(count-1,int(phase*count))
	if action=="idle":
		var elapsed=fposmod(time,4.8)
		var holds=[1.8,.9,.06,.09,.06,.2,.7,.99]
		index=7
		for i in range(8):
			if elapsed<holds[i]:
				index=i
				break
			elapsed-=holds[i]
	elif action=="sleep":
		if time<.7: index=mini(3,int(time/.7*4))
		elif not motion.stay_after_visit and motion.action_left<.45: index=6+mini(1,int((.45-motion.action_left)/.45*2))
		else: index=4+int(time/.9)%2
	elif action=="rest":
		if time<.7: index=mini(3,int(time/.7*4))
		elif motion.action_left>0 and motion.action_left<.3: index=7
		else: index=3+[0,1,2,1][int(time/.7)%4]
	elif action=="carry":
		index=mini(1,int(time/.18*2)) if time<.18 else 2+int((time-.18)/.25)%4
	elif action=="land":
		index=6+mini(1,int(clampf(1-motion.landing_left/.24,0,.99999)*2))
	elif motion.phase=="react" and action in ["pet","wave"]:
		index=mini(7,int(clampf(time/maxf(.01,motion.reaction_duration),0,.99999)*8))
	var result=sample_frame(stage,sequence,index)
	result.action=action
	return result

static func sample_frame(stage: String, action: String, index: int) -> Dictionary:
	var spec=data().stages[stage].sequences[action]
	var a=spec.anchors[index]
	return {"texture":frames(stage,action)[index],"action":action,"stage":stage,
		"index":index,"height":float(data().stages[stage].reference_height),
		"mouth":Vector2(a.mouth[0],a.mouth[1]),"hand":Vector2(a.hand[0],a.hand[1])}
