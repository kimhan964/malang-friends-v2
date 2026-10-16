extends RefCounted
const LABELS={"stumble":"앗, 넘어졌다 일어나기","run":"신나게 달리기","jump":"폴짝 점프","happy":"기분 좋은 춤","sad":"잠깐 토라지기","peek":"궁금해서 빼꼼","drink":"차 한 모금","sing":"작은 노래","study":"책 읽고 공부","work":"새싹 돌보기","pajama":"잠옷 입고 꾸벅","fight":"나뭇잎 방패 놀이","roll":"데굴데굴 굴러가기","fly":"대나무 프로펠러 비행"}
const DURATIONS={"stumble":2.8,"run":4.5,"jump":1.25,"happy":3.2,"sad":3.5,"peek":3.2,"drink":4.8,"sing":6.4,"study":9.6,"work":7.6,"pajama":9.6,"fight":6.4,"roll":4.0,"fly":6.0}
var runner=preload("res://scripts/run_hop_motion.gd").new()
var generic_runner=preload("res://scripts/generic_run.gd").new()
var queued=""
var action=""
var clock=0.0
var cooldown=28.0
var enabled=true
var last=""
var direction=1.0
var resume_point=Vector2.ZERO
var previous_speed=0.0
var adventure_goal=Vector2.ZERO
static func duration(kind: String) -> float:
	# Repeat life activities longer without stretching jumps or travel physics.
	var multiplier=4.0 if kind in ["happy","sad","peek","drink","sing","study","work","pajama","fight"] else 1.0
	return float(DURATIONS.get(kind,3.2))*multiplier
func clear() -> void:
	action="";clock=0;queued=""
func start(m,kind: String) -> bool:
	if not preload("res://scripts/behavior_unlocks.gd").available(m.behavior_points,kind): return false
	if not LABELS.has(kind) or m.held or m.carried or m.phase in ["drop","dizzy"]: return false
	if m.phase not in ["idle","wander","daily_action"]: return false
	if preload("res://scripts/run_hop_art.gd").has_action(m.species,kind) and m.phase=="wander" and m.smooth_walk_cycle.active:
		queued=kind
		return true
	m.cancel_play()
	action=kind;last=kind;clock=0;direction=m.facing
	m.phase="daily_action";m.elapsed=0;m.resting=false;m.travel_speed=0
	resume_point=m.feet
	if kind in ["roll","fly"]:
		direction=1 if m.bounds.end.x-m.feet.x>m.feet.x-m.bounds.position.x else -1
		var distance=135.0
		if kind=="roll": distance=TAU*float(preload("res://scripts/adventure_art.gd").data(m.species).roll_radius)*preload("res://scripts/animal_catalog.gd").DISPLAY_HEIGHT/205.0*m.growth_scale
		adventure_goal=Vector2(clampf(m.feet.x+direction*distance,m.bounds.position.x+8,m.bounds.end.x-8),m.feet.y)
		m.facing=1
	if kind=="run":
		direction=1 if m.bounds.end.x-m.feet.x>m.feet.x-m.bounds.position.x else -1
		m.target=Vector2(clampf(m.feet.x+direction*210,m.bounds.position.x+8,m.bounds.end.x-8),m.feet.y)
		m.facing=direction
		if absf(m.target.x-m.feet.x)<18: action="happy"
	if preload("res://scripts/run_hop_art.gd").has_action(m.species,action): runner.begin(m)
	elif action=="run": generic_runner.begin(m)
	m.say({"stumble":"앗, 미끄러졌네… 괜찮아!","run":"가볍게 한 바퀴!","jump":"폴짝!","happy":"신나는 하루","sad":"잠깐만, 생각 중…","peek":"무슨 일일까?","drink":"따뜻한 한 모금","sing":"흥얼흥얼 ♪","study":"한 장만 더 읽자","work":"새싹아, 쑥쑥 자라라","pajama":"포근해서 졸려…","fight":"오늘은 잎새 기사!","roll":"데굴데굴, 한 바퀴!","fly":"두둥실, 날아보자!"}[kind])
	cooldown=m.rng.randf_range(32,52)
	return true
func finish(m) -> void:
	var done=action
	clear()
	m.phase="idle";m.elapsed=0;m.target=m.feet;m.walk_phase=0;m.travel_speed=0;m.rest_left=.35
	m.activity_finished.emit("daily_"+done)
func advance(m,delta: float) -> bool:
	cooldown=maxf(0,cooldown-delta)
	if not queued.is_empty():
		if m.held or m.carried or m.phase not in ["idle","wander"]: queued=""
		elif not m.smooth_walk_cycle.active:
			var requested=queued
			queued=""
			start(m,requested)
	if m.phase=="daily_action" and not action.is_empty():
		clock+=delta
		if action in ["roll","fly"]:
			m.feet=resume_point.lerp(adventure_goal,smoothstep(.1,.88,clock/(4.0 if action=="roll" else 6.0)))
		if preload("res://scripts/run_hop_art.gd").has_action(m.species,action):
			runner.advance(m,delta)
			return true
		if action=="run":
			generic_runner.advance(m,delta)
			return true
		if action=="drink": m.hydration=minf(100,m.hydration+delta*4)
		if action=="pajama": m.energy=minf(100,m.energy+delta*.6)
		if clock>=duration(action): finish(m)
		return true
	if not action.is_empty(): clear()
	if enabled and m.autonomy and not m.held and not m.carried and not m.resting and m.phase=="wander" and cooldown<=0 and m.elapsed>1.5 and absf(sin(m.walk_phase*TAU))<.18:
		return start(m,"stumble")
	if not enabled or not m.autonomy or m.resting or m.held or m.carried or m.phase!="idle" or cooldown>0 or m.energy<38 or m.satiety<40 or m.hydration<40: return false
	var choices=["happy","peek","sing","study","work","fight","jump","stumble"]
	for kind in ["roll","fly"]:
		if preload("res://scripts/behavior_unlocks.gd").available(m.behavior_points,kind): choices.append(kind)
	if Time.get_time_dict_from_system().hour>=21: choices.append("pajama")
	if preload("res://scripts/run_hop_art.gd").has_action(m.species,"run") and m.energy>65: choices.append("run")
	choices.erase(last)
	return start(m,choices[m.rng.randi_range(0,choices.size()-1)])
