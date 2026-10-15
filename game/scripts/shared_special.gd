extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
static var sheets: Dictionary={}
static func frames(species: int) -> Array:
	var group=species/4
	if not sheets.has(group):
		var path="res://assets/specials/adult-%d.png"%group
		if not FileAccess.file_exists(path): return []
		sheets[group]=Keyed.AnimationRegions.frames(path,Keyed.pixels(path))
	return sheets[group].slice((species%4)*4,(species%4)*4+4)

# The same choreography runs at every age; only the drawings change.
static func pose(motion, baby: bool=false) -> int:
	return int(sample(motion,baby).x)

static func sample(motion, baby: bool=false) -> Vector3:
	if motion.carried or motion.landing_left>0 or motion.phase in ["wander","chase","return","visit"]: return Vector3(-1,-1,0)
	var t=motion.reaction_time if motion.phase=="react" else motion.elapsed
	var plan: Array=[]
	var speed=2.6
	if motion.phase in ["sniff","look","inspect"] or (motion.phase=="react" and motion.reaction in ["inspect","anticipate"]):
		plan=[0,1]
		speed=1.3
	if motion.phase in ["playful","askplay"] or (baby and motion.phase=="signature") or (motion.phase=="react" and motion.reaction in ["askplay","greet"]):
		plan=[2,2,3,3,1,0] if motion.species%2==0 else [0,1,2,3,3,1]
	if plan.is_empty(): return Vector3(-1,-1,0)
	var frame=t*speed
	var slot=int(frame)%plan.size()
	return Vector3(plan[slot],plan[(slot+1)%plan.size()],smoothstep(.45,1.0,frame-floorf(frame)))
