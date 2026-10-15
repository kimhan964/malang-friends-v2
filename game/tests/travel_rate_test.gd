extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
const Rabbit=preload("res://scripts/rabbit_pilot_art.gd")
const Gait=preload("res://scripts/gait_profile.gd")
var failures=[]
var rows=[]
func _initialize() -> void:
	Smooth.select_version(14)
	Rabbit.select_version(9)
	for species in range(16):
		for stage in [0,2]:
			for fps in [30,60,144]:
				var m=Motion.new()
				m.species=species
				m.growth_stage=stage
				m.growth_scale=.93 if stage==0 else 1.0
				m.smooth_walk_enabled=true
				m.rabbit_pilot=species==0
				m.bounds=Rect2(0,0,100000,1000)
				m.feet=Vector2(300,400)
				m.target=Vector2(10000,400)
				var meta=Rabbit.data().stages["baby" if stage==0 else "adult"] if species==0 else Smooth.data(species).stages["baby" if stage==0 else "adult"]
				var before_cycle=float(meta.cycle_seconds) if species==0 else maxf(float(meta.cycle_seconds),Gait.PERIOD[species])
				var expected=before_cycle/1.5
				var origin=m.feet
				var seconds=0.0
				var cycles=0
				while cycles<3 and seconds<20:
					m.advance_travel(1.0/fps)
					seconds+=1.0/fps
					if not (m.pilot_hop.active if species==0 else m.smooth_walk_cycle.active): cycles+=1
				var actual=seconds/3.0
				var stride=float(meta.stride)*110*preload("res://scripts/animal_catalog.gd").HEIGHTS[species]*m.growth_scale/float(meta.reference_height)
				if species==0: stride*=2.0 # Deliberate rabbit desktop-travel adjustment.
				if absf(actual-expected)>1.0/fps+.001: failures.append("cycle %d/%d/%d"%[species,stage,fps])
				if absf(m.feet.distance_to(origin)-stride*3)>.01: failures.append("stride changed %d"%species)
				rows.append({"species":species,"stage":stage,"fps":fps,"before":before_cycle,"after":actual,"ratio":before_cycle/actual})
	FileAccess.open("res://travel-rate-review.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures},"\t"))
	print("TRAVEL_RATE cases=",rows.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
