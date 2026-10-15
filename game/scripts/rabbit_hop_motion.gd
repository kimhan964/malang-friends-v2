extends RefCounted
## A complete illustrated pose moves only while its feet are airborne.
var active=false
var age=0.0
var origin=Vector2.ZERO
var destination=Vector2.ZERO
var hop_index=0
var current_period=1.0
const TRAVEL_DISTANCE_SCALE=2.0
const PREPARE_SHARE=0.12
const LAND_SHARE=0.82
# Keep preparation and landing visible, with a quiet recovery before launch.
# Drawing, horizontal travel and vertical lift share this one phase clock.
static func playback_phase(time_phase: float,launch: float,land: float) -> float:
	if time_phase<PREPARE_SHARE: return lerpf(0,launch,time_phase/PREPARE_SHARE)
	if time_phase<LAND_SHARE: return lerpf(launch,land,(time_phase-PREPARE_SHARE)/(LAND_SHARE-PREPARE_SHARE))
	return lerpf(land,1.0,(time_phase-LAND_SHARE)/(1.0-LAND_SHARE))

static func stride_length(motion,spec: Dictionary) -> float:
	var scale=110.0*preload("res://scripts/animal_catalog.gd").HEIGHTS[0]*motion.growth_scale/float(spec.reference_height)
	# A short 12 px desktop hop read as jumping on the spot. Translation can
	# cover more ground during flight without changing the height or foot cels.
	return float(spec.stride)*scale*TRAVEL_DISTANCE_SCALE

static func flight_progress(phase: float,launch: float,land: float) -> float:
	return clampf((phase-launch)/maxf(.001,land-launch),0.0,1.0)

static func travel_fraction(phase: float,launch: float,land: float) -> float:
	var t=flight_progress(phase,launch,land)
	return t*t*(3.0-2.0*t)

static func lift(phase: float,launch: float,land: float,height: float) -> float:
	var arc=sin(flight_progress(phase,launch,land)*PI)
	return arc*arc*height

func reset() -> void:
	active=false
	age=0.0
	hop_index=0

func advance(motion,delta: float,spec: Dictionary) -> void:
	var base_period=float(spec.cycle_seconds)/preload("res://scripts/gait_profile.gd").TRAVEL_RATE
	var stride=stride_length(motion,spec)
	if not active:
		var offset=motion.target-motion.feet
		if offset.length()<.001:
			motion.travel_speed=0.0
			return
		current_period=base_period*(1.0+.065*sin(hop_index*1.17))
		stride*=1.0+.035*sin(hop_index*.83)
		hop_index+=1
		origin=motion.feet
		destination=origin+offset.normalized()*minf(stride,offset.length())
		motion.travel_direction=offset.normalized()
		if absf(offset.x)>.5: motion.facing=signf(offset.x)
		age=0.0
		active=true
		motion.pilot_was_traveling=true
	var period=current_period
	age=minf(period,age+delta)
	var phase=playback_phase(age/period,float(spec.launch_phase),float(spec.land_phase))
	var before=motion.feet
	motion.feet=origin.lerp(destination,travel_fraction(phase,float(spec.launch_phase),float(spec.land_phase)))
	motion.travel_speed=motion.feet.distance_to(before)/maxf(delta,.00001)
	motion.walk_phase=minf(phase,.999999)
	# Finish the landing/recovery drawings before the controller can stop.
	if age>=period:
		motion.feet=destination
		motion.walk_phase=0.0
		motion.pilot_idle_index=0
		active=false
