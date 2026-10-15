extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Rabbit=preload("res://scripts/rabbit_pilot_art.gd")
var failures=[]
var cases=0
func make_rabbit(stage: int):
	var m=Motion.new()
	m.rabbit_pilot=true
	m.growth_stage=stage
	m.growth_scale=.93 if stage==0 else 1.0
	m.configure(Rect2(0,0,1920,1080),Vector2(700,650))
	m.autonomy=false
	m.resting=true
	return m
func _initialize() -> void:
	for stage in [0,2]:
		for fps in [30,60,144]:
			for direction in [-1,1]:
				var m=make_rabbit(stage)
				var start=m.feet
				m.phase="wander"
				m.target=start+Vector2(direction*160,0)
				for tick in range(fps*9):
					m.advance(1.0/fps)
					if m.phase=="idle": break
				if m.feet.distance_to(m.target)>.01 or m.phase!="idle": failures.append("160px trip not complete in 9s %d/%d/%d"%[stage,fps,direction])
				cases+=1
			# A user interruption immediately followed by a new destination must
			# not keep the previous hop's origin/destination.
			var m=make_rabbit(stage)
			m.phase="wander"
			m.target=m.feet+Vector2(160,0)
			for tick in range(int(fps*.4)): m.advance(1.0/fps)
			m.cancel_play()
			if m.pilot_hop.active: failures.append("cancel retains old hop %d/%d"%[stage,fps])
			var start=m.feet
			m.visit(start+Vector2(-80,0),"sniff","review")
			for tick in range(fps):
				m.advance(1.0/fps)
				if m.feet.x>start.x+.01:
					failures.append("new trip travels toward cancelled destination %d/%d"%[stage,fps])
					break
			cases+=1
	print("RABBIT_DESKTOP_TRAVEL cases=",cases," failures=",failures)
	quit(0 if failures.is_empty() else 1)
