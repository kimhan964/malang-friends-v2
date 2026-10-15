extends RefCounted
const Art=preload("res://scripts/run_hop_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
var origin=Vector2.ZERO
var direction=1.0
var stride=0.0
var steps=0
func begin(m) -> void:
	origin=m.feet;direction=m.facing;steps=0;stride=0
	if m.daily.action!="run": return
	var spec=Art.spec(m.species,"run")
	stride=float(spec.stride)*Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[m.species]*m.growth_scale/float(Art.data(m.species).reference_height)
	var room=(m.bounds.end.x-8-m.feet.x) if direction>0 else (m.feet.x-m.bounds.position.x-8)
	steps=mini(4,maxi(0,floori(room/maxf(.01,stride))))
	if steps==0:
		m.daily.action="happy"
		return
	m.target=origin+Vector2(direction*stride*steps,0)
func advance(m,delta: float) -> void:
	var action: String=m.daily.action
	var spec=Art.spec(m.species,action)
	var duration=float(spec.duration)
	if action=="jump":
		m.travel_speed=0
		if m.daily.clock>=duration: m.daily.finish(m)
		return
	var total=minf(m.daily.clock/duration,float(steps))
	var step=floori(total)
	var phase=total-step
	# Travel only while airborne. Complete the final landing and recovery
	# before returning to idle, including when approaching a screen boundary.
	var progress=smoothstep(float(spec.launch),float(spec.land),phase)
	var previous: Vector2=m.feet
	m.feet=origin+Vector2(direction*stride*(step+progress),0)
	m.walk_phase=phase
	m.travel_speed=m.feet.distance_to(previous)/maxf(.00001,delta)
	if total>=steps:
		m.feet=origin+Vector2(direction*stride*steps,0)
		m.daily.finish(m)
