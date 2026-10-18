extends RefCounted
## Each complete stride ends on its original contact pose before an action begins.
var active=false
var age=0.0
var cycle_seconds=0.0
var origin=Vector2.ZERO
var destination=Vector2.ZERO
func reset() -> void:
	active=false
	age=0.0
	cycle_seconds=0.0

func stride_length(motion,metadata: Dictionary) -> float:
	var scale=preload("res://scripts/animal_catalog.gd").DISPLAY_HEIGHT*preload("res://scripts/animal_catalog.gd").HEIGHTS[motion.species]*motion.growth_scale/float(metadata.reference_height)
	return float(metadata.stride)*scale

func arrived(motion,metadata: Dictionary) -> bool:
	if active: return false
	var offset=motion.target-motion.feet
	var stride=stride_length(motion,metadata)
	# A raster stride has fixed foot travel. Stop at its nearest contact rather
	# than compressing the whole animation into a tiny final displacement.
	if offset.length()<=stride*.5+.001: return true
	var next_contact=motion.feet+offset.normalized()*stride
	# At a screen edge prefer the last safe contact to an off-screen step.
	return offset.length()<stride and not next_contact.is_equal_approx(next_contact.clamp(motion.bounds.position,motion.bounds.end))

func advance(motion,delta: float,metadata: Dictionary,multiplier: float) -> void:
	advance_continuous(motion,delta,metadata,multiplier)

func advance_continuous(motion,delta: float,metadata: Dictionary,multiplier: float) -> void:
	# All species consume the remainder of a display frame at each contact.
	# Keep their authored travel curves; only continuous_stride uses linear travel.
	var previous=motion.feet
	var remaining=maxf(0,delta)
	var iterations=0
	while remaining>0.000001 and iterations<16:
		iterations+=1
		if not active:
			if arrived(motion,metadata):break
			var offset=motion.target-motion.feet
			origin=motion.feet
			destination=origin+offset.normalized()*stride_length(motion,metadata)
			motion.travel_direction=offset.normalized()
			if absf(offset.x)>.5:motion.facing=signf(offset.x)
			var pace=clampf(multiplier,.01,preload("res://scripts/gait_profile.gd").MAX_WALK_MULTIPLIER)
			cycle_seconds=float(metadata.cycle_seconds)/pace
			age=0;active=true
		var consumed=minf(remaining,cycle_seconds-age)
		age+=consumed;remaining-=consumed
		var phase=clampf(age/cycle_seconds,0,1)
		var progress=phase
		var curve: Array=metadata.get("travel_curve",[])
		if not metadata.get("continuous_stride",false) and curve.size()>1:
			var position=phase*(curve.size()-1)
			var first=mini(int(position),curve.size()-2)
			progress=lerpf(float(curve[first]),float(curve[first+1]),position-first)
		motion.feet=origin.lerp(destination,progress)
		motion.walk_phase=minf(phase,.999999)
		if age>=cycle_seconds-.000001:
			motion.feet=destination;motion.walk_phase=0;active=false
			# Yield a grounded contact to pending actions and timed social exits.
			# Otherwise starting the next loop here leaves them permanently active.
			if not motion.daily.queued.is_empty() or (not motion.social_kind.is_empty() and motion.social_left<=0):break
	motion.travel_speed=motion.feet.distance_to(previous)/maxf(delta,.00001)
