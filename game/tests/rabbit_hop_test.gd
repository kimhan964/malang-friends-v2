extends SceneTree
const Hop=preload("res://scripts/rabbit_hop_motion.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
var errors=[]
func _initialize() -> void:
	var art=preload("res://scripts/rabbit_pilot_art.gd")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--version="): art.select_version(int(argument.trim_prefix("--version=")))
	var spec=art.data().stages.adult
	var launch=float(spec.launch_phase)
	var land=float(spec.land_phase)
	var lift_height=float(spec.lift_canvas)
	for fps in [30,60,144]:
		var previous=0.0
		for frame in range(fps*3+1):
			var phase=float(frame)/float(fps*3)
			var travel=Hop.travel_fraction(phase,launch,land)
			var height=Hop.lift(phase,launch,land,lift_height)
			if phase<=launch and absf(travel)>.00001: errors.append("grounded launch slides")
			if phase>=land and absf(travel-1.0)>.00001: errors.append("grounded landing slides")
			if (phase<=launch or phase>=land) and absf(height)>.00001: errors.append("grounded vertical drift")
			if travel<previous or travel>1.0 or height<-.00001 or height>lift_height+.00001: errors.append("invalid trajectory")
			previous=travel
	# Exercise the actual controller: landing must not end recovery early.
	for fps in [30,60,144]:
		var motion=Motion.new()
		motion.rabbit_pilot=true
		motion.growth_stage=1
		motion.autonomy=false
		motion.resting=true
		motion.phase="wander"
		motion.feet=Vector2(300,300)
		motion.target=motion.feet+Vector2(12,0)
		var elapsed=0.0
		var cycle=float(spec.cycle_seconds)/preload("res://scripts/gait_profile.gd").TRAVEL_RATE
		while elapsed<cycle-2.0/fps:
			motion.advance(1.0/fps)
			elapsed+=1.0/fps
			if motion.phase!="wander": errors.append("recovery ended at landing")
		for frame in range(ceilf(.2*fps)): motion.advance(1.0/fps)
		if motion.phase!="idle" or motion.pilot_hop.active: errors.append("cycle did not finish")
		if motion.feet.distance_to(Vector2(312,300))>.001: errors.append("destination mismatch")
	print("HOP_CONTACT_TRAJECTORY ","PASS" if errors.is_empty() else errors)
	quit(0 if errors.is_empty() else 1)

