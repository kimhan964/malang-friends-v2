extends RefCounted
const Smooth=preload("res://scripts/smooth_species_art.gd")
var origin=Vector2.ZERO
var stride=0.0
var period=0.0
var steps=0
var direction=1.0
func begin(m) -> void:
	var metadata=Smooth.spec(m)
	origin=m.feet;direction=m.facing
	stride=m.smooth_walk_cycle.stride_length(m,metadata)*1.5
	period=float(metadata.cycle_seconds)*.62
	var room=(m.bounds.end.x-8-origin.x) if direction>0 else (origin.x-m.bounds.position.x-8)
	steps=mini(4,maxi(1,floori(room/maxf(.01,stride))))
	stride=minf(stride,room/steps)
	m.target=origin+Vector2(direction*stride*steps,0)
func advance(m,delta: float) -> void:
	var cycles=minf(float(steps),m.daily.clock/maxf(.01,period))
	var before=m.feet
	m.feet=origin+Vector2(direction*stride*cycles,0)
	m.walk_phase=fposmod(cycles,1.0)
	m.travel_speed=m.feet.distance_to(before)/maxf(.00001,delta)
	if cycles>=steps:m.daily.finish(m)
static func sample(m) -> Dictionary:
	var result=Smooth.sample(m,"walk")
	var half=fposmod(m.walk_phase*2.0,1.0)
	var airborne=clampf((half-.12)/.72,0,1)
	result.bank="daily-run";result.daily_animation=true;result.run_hop=true
	result.lift=sin(airborne*PI)*18.0
	return result
