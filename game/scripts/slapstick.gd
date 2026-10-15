extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
const ROOT="res://assets/slapstick-varco-v1/"
const DURATIONS={"stumble":2.8,"sneeze":2.4}
static var banks={}
static var specs={}
var cooldown=50.0
var walking_time=0.0
var last_kind=""

static func release_other_species(species: int) -> void:
	for key in banks.keys():
		if not str(key).begins_with(Catalog.IDS[species]+"/"): banks.erase(key)

static func stage(m) -> String:
	return "baby" if m.growth_stage==0 else "adult"
static func metadata(m) -> Dictionary:
	var key=Catalog.IDS[m.species]+"/"+stage(m)
	if not specs.has(key):
		var file=ROOT+key+".json"
		specs[key]=JSON.parse_string(FileAccess.get_file_as_string(file)) if preload("res://scripts/asset_images.gd").exists(file) else {}
	return specs[key]
static func available(m) -> bool:
	# Additional garments need authored prone-pose fits; don't misplace a rigid cape.
	return m.outfit_style==0 and not metadata(m).is_empty()
static func frames(m,kind: String) -> Array:
	var key=Catalog.IDS[m.species]+"/"+stage(m)+"-"+kind
	if not banks.has(key):
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,ROOT+key+".png")!=OK: return []
		var result=[]
		var cell=int(metadata(m).get("cell_size",256))
		for i in range(60): result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*cell,i/8*cell,cell,cell))))
		preload("res://scripts/animal_tone.gd").register(result,m.species,stage(m))
		banks[key]=result
	return banks[key]
static func sample(m) -> Dictionary:
	var age=stage(m)
	var spec=metadata(m)
	var bank=frames(m,m.silly_kind)
	var index=clampi(int(m.elapsed/DURATIONS[m.silly_kind]*60),0,59)
	var anchor=spec.get("root",[128,232])
	return {"texture":bank[index],"action":"silly","stage":age,"height":spec.reference_height,"anchor":Vector2(anchor[0],anchor[1]),"fixed_cels":true,"slapstick":true,"dressed":false,"mouth":Vector2(164,150),"hand":Vector2(162,190)}
func start(m,kind: String) -> bool:
	if not DURATIONS.has(kind) or not available(m): return false
	if m.held or m.carried or m.resting or m.ball_visible or m.personality_active or not m.social_kind.is_empty(): return false
	if m.phase not in ["idle","wander"]: return false
	m.silly_followup=m.phase
	m.silly_kind=kind
	m.phase="silly"
	m.elapsed=0.0
	m.travel_speed=0.0
	m.travel_direction=Vector2.ZERO
	m.context_reactions.clear()
	m.say("앗… 아무 일도 없었어" if kind=="stumble" else "에취! 머쓱…")
	cooldown=m.rng.randf_range(90,150)
	walking_time=0
	last_kind=kind
	return true
func advance(m,delta: float) -> bool:
	cooldown=maxf(0,cooldown-delta)
	if m.phase=="silly":
		if m.elapsed>=DURATIONS[m.silly_kind]:
			m.phase=m.silly_followup
			m.silly_kind=""
			m.elapsed=0
			m.rest_left=2.0
		return true
	if not m.autonomy or m.held or m.resting or m.carried: return false
	if m.phase=="wander": walking_time+=delta
	else: walking_time=0
	if cooldown>0 or not available(m) or m.satiety<30 or m.hydration<30 or m.energy<30: return false
	# Only interrupt free walks at a grounded contact; never a furniture approach.
	if m.phase=="wander" and walking_time>1.2 and m.feet.distance_to(m.target)>24:
		if m.rabbit_pilot and m.pilot_hop.active: return false
		if absf(sin(m.walk_phase*TAU))>.18: return false
		return start(m,"stumble")
	if m.phase=="idle" and m.elapsed>3 and last_kind!="sneeze": return start(m,"sneeze")
	return false
