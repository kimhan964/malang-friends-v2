extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Slap=preload("res://scripts/slapstick.gd")
var failures=[]
func check(ok: bool,why: String) -> void:
	if not ok: failures.append(why); push_error(why)
func _initialize() -> void:
	var m=Motion.new()
	m.species=0
	m.growth_stage=2
	m.rabbit_pilot=true
	m.bounds=Rect2(0,0,1600,900)
	m.feet=Vector2(400,700)
	m.target=Vector2(700,700)
	m.phase="wander"
	check(m.slapstick.start(m,"stumble"),"start wander stumble")
	var origin=m.feet
	var destination=m.target
	for i in range(168):
		m.advance(1.0/60.0)
		check(m.feet==origin,"teleport during stumble")
	m.advance(1.0/60.0)
	check(m.phase=="wander" and m.target==destination,"resume original destination")
	check(m.slapstick.cooldown>80,"repeat cooldown missing")
	for phase in ["visit","home_use","eat","drink","drop","dizzy"]:
		m.phase=phase
		check(not m.slapstick.start(m,"stumble"),"interrupted protected action "+phase)
	m.phase="idle"
	m.held=true
	check(not m.slapstick.start(m,"sneeze"),"interrupted drag")
	m.held=false
	check(m.slapstick.start(m,"sneeze"),"sneeze start")
	m.cancel_play()
	check(m.phase=="idle" and m.silly_kind.is_empty(),"cancel clears special motion")
	m.outfit_style=1
	check(not Slap.available(m),"unsupported prone garment enabled")
	m.outfit_style=0
	for kind in Slap.DURATIONS:
		var frames=Slap.frames(m,kind)
		check(frames.size()==60,"frame count")
		check(frames[0].get_image().get_data()==frames[59].get_image().get_data(),"neutral endpoint mismatch")
	print("SLAPSTICK: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
