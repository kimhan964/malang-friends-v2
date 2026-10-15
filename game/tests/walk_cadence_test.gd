extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Gait=preload("res://scripts/gait_profile.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
var cases=0
var rows=[]
func _initialize() -> void:
	Smooth.select_version(12)
	for species in range(16):
		for stage in [0,2]:
			for modern in [false,true]:
				if modern and not Smooth.data(species).get("stages",{}).has("baby" if stage==0 else "adult"): continue
				for multiplier in [1.0,1.5]:
					for fps in [30,60,144]:
						var m=Motion.new()
						m.species=species
						m.growth_stage=stage
						m.growth_scale=.93 if stage==0 else 1.0
						m.smooth_walk_enabled=modern
						m.feet=Vector2(300,400)
						m.target=Vector2(100000,400)
						m.bounds=Rect2(0,0,200000,1000)
						var nominal=m.SPEEDS[species]*lerpf(.72,1.0,clampf(inverse_lerp(.62,1.0,m.growth_scale),0,1))
						var stride=m.smooth_walk_cycle.stride_length(m,Smooth.spec(m)) if modern else maxf(16.0,nominal*Gait.STRIDE_PERIOD[species])
						var target_cycle=Gait.PERIOD[species]/Gait.TRAVEL_RATE/minf(multiplier,Gait.MAX_WALK_MULTIPLIER)
						var turns=0.0
						var measured_turns=0.0
						var measured_time=0.0
						var previous=m.walk_phase
						var origin=m.feet
						for tick in range(fps*10):
							m.advance_travel(1.0/fps,multiplier)
							var phase_step=fposmod(m.walk_phase-previous,1.0)
							assert(phase_step<.03,"Gait phase jumps")
							turns+=phase_step
							if tick>=fps:
								measured_turns+=phase_step
								measured_time+=1.0/fps
							previous=m.walk_phase
							assert(absf(m.feet.distance_to(origin)-turns*stride)<.1,"Foot cadence no longer follows desktop travel")
						var measured_cycle=measured_time/measured_turns
						assert(absf(measured_cycle-target_cycle)<.06,"Unexpected cycle speed")
						assert(measured_cycle>=Gait.PERIOD[species]/Gait.TRAVEL_RATE/Gait.MAX_WALK_MULTIPLIER-.02,"Walking accelerated too far")
						if fps==60: rows.append({"species":Catalog.IDS[species],"stage":"baby" if stage==0 else "adult","bank":"v12" if modern else "legacy","multiplier":multiplier,"measured_cycle":measured_cycle,"stride_px":stride})
						cases+=1
	# The approved rabbit hop bypasses both changed travel paths.
	var rabbit=Motion.new()
	rabbit.species=0
	rabbit.rabbit_pilot=true
	rabbit.growth_stage=2
	assert(not Smooth.enabled(rabbit))
	# Reproduce a behaviour-speed change halfway through an airborne step.
	# The old age/new-duration calculation jumped backwards at this boundary.
	for fps in [30,60,144]:
		var m=Motion.new()
		m.species=1
		m.growth_stage=2
		m.smooth_walk_enabled=true
		m.target=Vector2(10000,0)
		var previous=0.0
		for tick in range(fps):
			m.advance_travel(1.0/fps,1.0 if tick<fps/2 else .7)
			assert(m.walk_phase>=previous,"Mid-stride retiming reversed the gait")
			assert(absf(m.walk_phase-previous-1.0/fps/Gait.PERIOD[1]*Gait.TRAVEL_RATE)<.00001,"Mid-stride cadence changed")
			previous=m.walk_phase
	print("MID_STRIDE_CADENCE_CHECKS_OK 3")
	var return_cases=0
	for fps in [30,60,144]:
		var m=Motion.new()
		m.species=14
		m.growth_stage=2
		m.autonomy=false
		m.resting=true
		m.feet=Vector2(500,500)
		m.bounds=Rect2(0,0,2000,1000)
		var stride=m.SPEEDS[14]*Gait.STRIDE_PERIOD[14]
		for trip in range(8):
			m.phase="wander"
			m.travel_speed=0
			m.target=m.feet+Vector2((1 if trip%2==0 else -1)*stride*3,0)
			for tick in range(fps*9):
				m.advance(1.0/fps)
				if m.phase=="idle": break
			assert(m.phase=="idle","Legacy round trip did not arrive")
			if minf(m.walk_phase,1-m.walk_phase)>=.001: print("ROUND_TRIP_FAILURE ",fps," ",trip," ",m.walk_phase," feet ",m.feet," target ",m.target)
			assert(minf(m.walk_phase,1-m.walk_phase)<.001,"Stop/reverse accumulated foot phase error")
			return_cases+=1
	print("LEGACY_ROUND_TRIP_CHECKS_OK ",return_cases)
	var report=FileAccess.open("res://design/walk-cadence-review/runtime-cadence.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"cases":cases,"results":rows},"\t"))
	print("WALK_CADENCE_CHECKS_OK ",cases)
	quit()

