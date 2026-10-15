extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
const Struggle=preload("res://scripts/struggle_art.gd")
const NAMES=["pickup","idle_entry","carry_entry","release0","release1","release2","release3","recover"]
const COUNT=17
const EXIT_SECONDS=.28
const RECOVER_SECONDS=.36
static var banks: Dictionary={}

static func available(motion) -> bool:
	return preload("res://scripts/asset_images.gd").exists("res://assets/hold-transitions-v1/%s/%s/recover.png"%[Catalog.IDS[motion.species],Struggle.stage_name(motion)])

static func frames(species: int,stage: String,name: String) -> Array:
	var key="%d/%s/%s"%[species,stage,name]
	if not banks.has(key):
		var path="res://assets/hold-transitions-v1/%s/%s/%s.png"%[Catalog.IDS[species],stage,name]
		if not preload("res://scripts/asset_images.gd").exists(path): return []
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return []
		var sequence: Array=[]
		for i in range(COUNT): sequence.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*256,i/8*256,256,256))))
		preload("res://scripts/animal_tone.gd").register(sequence,species,stage)
		banks[key]=sequence
	return banks[key]

static func release_other_species(species: int) -> void:
	for key in banks.keys():
		if not str(key).begins_with(str(species)+"/"): banks.erase(key)

static func bridge(motion,name: String,progress: float,reverse: bool=false) -> Dictionary:
	var stage=Struggle.stage_name(motion)
	var index=clampi(roundi(clampf(progress,0,1)*(COUNT-1)),0,COUNT-1)
	if reverse: index=COUNT-1-index
	var spec=Struggle.data(motion.species).stages[stage]
	var grip=Vector2(128,232)+(Vector2(spec.grip[0],spec.grip[1])-Vector2(128,232))*200.0/float(spec.reference_height)
	return {"texture":frames(motion.species,stage,name)[index],"action":"carry","stage":stage,"index":index,
		"height":200.0,"fixed_cels":true,"hold_transition":true,"hold_visual":true,"hold_loop_age":0.0,"bank":"hold-"+name,
		"grip":grip,"mouth":Vector2(138,126),"hand":Vector2(154,171)}

static func entry_start(motion,pickup: float) -> float:
	return motion.STRUGGLE_HOLD_SECONDS if pickup>=motion.STRUGGLE_HOLD_SECONDS-.04 else maxf(motion.STRUGGLE_HOLD_SECONDS,pickup+motion.CARRY_PICKUP_SECONDS)

static func held_at(motion,clock: float,pickup: float) -> Dictionary:
	var start=entry_start(motion,pickup)
	if clock>=start:
		var age=clock-start
		if age<motion.STRUGGLE_ENTRY_SECONDS:
			var name="idle_entry" if pickup>=motion.STRUGGLE_HOLD_SECONDS-.04 else "carry_entry"
			return bridge(motion,name,age/motion.STRUGGLE_ENTRY_SECONDS)
		var sample=Struggle.sample_at(motion,age-motion.STRUGGLE_ENTRY_SECONDS)
		sample.hold_visual=true
		sample.hold_loop_age=age-motion.STRUGGLE_ENTRY_SECONDS
		return sample
	if clock-pickup<motion.CARRY_PICKUP_SECONDS:
		return bridge(motion,"pickup",(clock-pickup)/motion.CARRY_PICKUP_SECONDS)
	# Keep precisely the same calibrated quiet pose until the protest starts.
	return bridge(motion,"pickup",1.0)

static func release_timing(motion) -> Dictionary:
	var release: Dictionary=motion.hold_release
	if not release.long:
		return {"wait":maxf(0.0,release.pickup+motion.CARRY_PICKUP_SECONDS-release.clock),"name":"pickup","reverse":true}
	var start=entry_start(motion,release.pickup)+motion.STRUGGLE_ENTRY_SECONDS
	var quarter=float(Struggle.data(motion.species).stages[Struggle.stage_name(motion)].cycle_seconds)/4.0
	# Finish the current quarter. Never round a nearly-finished optical-flow
	# cel to a key on the release event itself; that reintroduced a paw snap.
	var key=0 if release.clock<start else floori((release.clock-start)/quarter)+1
	return {"wait":maxf(.000001,start+key*quarter-release.clock),"name":"release%d"%(key%4),"reverse":false}

static func sample(motion) -> Dictionary:
	if not available(motion): return {}
	if motion.pointer_grab and motion.carried and motion.held:
		return held_at(motion,motion.carry_elapsed,motion.carry_started_at)
	if not motion.hold_release.is_empty() and motion.phase in ["idle","drop","dizzy"]:
		var timing=release_timing(motion)
		var age: float=motion.hold_release.elapsed
		if age<timing.wait:
			return held_at(motion,motion.hold_release.clock+age,motion.hold_release.pickup)
		if age<timing.wait+EXIT_SECONDS:
			return bridge(motion,timing.name,(age-timing.wait)/EXIT_SECONDS,timing.reverse)
		if motion.hold_release.long and motion.phase=="idle" and age<timing.wait+EXIT_SECONDS+RECOVER_SECONDS:
			return bridge(motion,"recover",(age-timing.wait-EXIT_SECONDS)/RECOVER_SECONDS)
		if motion.hold_release.long and (motion.phase=="drop" or (motion.phase=="dizzy" and motion.landing_left>0)):
			return bridge(motion,timing.name,1.0)
	if motion.phase=="dizzy" and motion.elapsed>=motion.DIZZY_DURATION-RECOVER_SECONDS:
		return bridge(motion,"recover",(motion.elapsed-motion.DIZZY_DURATION+RECOVER_SECONDS)/RECOVER_SECONDS)
	return {}
