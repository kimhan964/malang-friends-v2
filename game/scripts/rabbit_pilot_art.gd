extends RefCounted
## Complete illustrated cels only. No rig, mesh deformation or part animation.
const ROOT=Vector2(128,232)
static var path="res://assets/rabbit-frame-pilot-v9/"
static var manifest={}
static var banks={}
static func select_version(version: int) -> void:
	var next_path="res://assets/rabbit-frame-pilot-v9/"
	if not preload("res://scripts/asset_images.gd").exists(next_path+"manifest.json"): return
	if path==next_path: return
	path=next_path
	manifest={}
	banks={}
static func data() -> Dictionary:
	if manifest.is_empty(): manifest=JSON.parse_string(FileAccess.get_file_as_string(path+"manifest.json"))
	return manifest
static func frames(stage: String,action: String) -> Array:
	var key=stage+"/"+action
	if not banks.has(key):
		var spec=data().stages[stage].sequences[action]
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path+spec.file)!=OK: return []
		var result=[]
		var columns=int(spec.get("columns",8))
		for i in range(int(spec.count)):
			result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%columns*256,i/columns*256,256,256))))
		preload("res://scripts/animal_tone.gd").register(result,0,stage)
		banks[key]=result
	return banks[key]
static func prewarm(stage: String) -> void:
	for action in data().stages[stage].sequences:
		for cel in frames(stage,action):
			preload("res://scripts/animation_outline.gd").local_hull(cel)
static func sample(motion,stage: String,action: String) -> Dictionary:
	var index=motion.pilot_idle_index
	var bank="idle"
	var frame_phase=float(index)
	if action!="walk" and data().stages[stage].sequences.has(action):
		bank=action
		var action_spec=data().stages[stage].sequences[action]
		var duration=float(action_spec.get("duration",4.8))
		var phase=clampf(motion.elapsed/duration,0.0,1.0) if action_spec.get("one_shot",false) else fposmod(motion.elapsed/duration,1.0)
		if action=="eat": phase=preload("res://scripts/eating_timing.gd").progress(motion.elapsed)
		index=mini(int(action_spec.count)-1,int(phase*int(action_spec.count)))
		var phases=action_spec.get("phases",[])
		if not phases.is_empty():
			index=0
			for i in range(phases.size()):
				if float(phases[i])<=phase: index=i
				else: break
	if motion.pilot_start_left>0:
		bank="idle"
	elif motion.pilot_settle_left>0:
		bank="walk"
		var progress=clampf(1.0-motion.pilot_settle_left/.42,0.0,1.0)
		var collected=lerpf(motion.pilot_stop_phase,motion.pilot_contact_phase,progress)
		frame_phase=fposmod(collected,1.0)*frames(stage,bank).size()
		index=int(frame_phase)
	elif action=="walk":
		bank="walk"
		frame_phase=fposmod(motion.walk_phase,1.0)*frames(stage,bank).size()
		index=int(frame_phase)
		var phases=data().stages[stage].sequences.walk.get("phases",[])
		if not phases.is_empty():
			index=0
			for i in range(phases.size()):
				if float(phases[i])<=motion.walk_phase: index=i
				else: break
	var cels=frames(stage,bank)
	index=clampi(index,0,cels.size()-1)
	var offset=Vector2.ZERO
	var spec=data().stages[stage]
	if bank=="walk" and spec.get("locomotion","")=="short_hop":
		offset.y=-preload("res://scripts/rabbit_hop_motion.gd").lift(motion.walk_phase,float(spec.launch_phase),float(spec.land_phase),float(spec.lift_canvas))
	# An authored cel is shown once; dissolves create duplicate paws and eyes.
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":action,"stage":stage,"index":index,
		"height":float(data().stages[stage].reference_height),"mouth":Vector2(149,136),"hand":Vector2(128,182),
		"pilot":true,"bank":bank,"root_offset":offset,"embedded_food":spec.sequences[bank].get("embedded_food",false)}
