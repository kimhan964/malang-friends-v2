extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Context=preload("res://scripts/context_reactions.gd")
const Main=preload("res://scripts/main.gd")
const Behavior=preload("res://scripts/expression_behavior.gd")
class State extends "res://scripts/pet_state.gd":
	func save_game() -> void: pass
class Pet extends Node:
	var species=0
	var motion=Motion.new()
var failures=[]
func check(ok: bool,label: String) -> void:
	if not ok and label not in failures: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var count=0
	for species in range(16):
		for stage in [0,2]:
			for event in Context.EVENTS:
				var m=Motion.new()
				m.species=species
				m.growth_stage=stage
				m.autonomy=false
				m.configure(Rect2(0,0,1280,720),Vector2(600,600))
				m.phase="eat"
				m.action_left=10
				m.context_reactions.queue(event)
				for i in range(30): m.advance(1.0/60)
				check(m.phase=="eat","interrupted eating")
				m.phase="idle"
				m.advance(.02)
				check(m.phase=="react" and m.reaction_context==event,"missing context "+event)
				check(not m.reaction_words.is_empty(),"missing words")
				var feet=m.feet
				for p in [0,.3,.6,1]:
					m.reaction_time=m.reaction_duration*p
					var pose=Behavior.pose(m)
					check(pose.offset.is_finite() and absf(pose.angle)<.2,"invalid gesture")
				m.advance(.02)
				check(m.phase=="idle" and m.feet==feet,"reaction moved world position")
				check(not m.context_reactions.queue(event),"same-event cooldown failed")
				count+=1
	var m=Motion.new()
	m.autonomy=false
	m.context_reactions.queue("held_long")
	check(not m.context_reactions.queue("hello"),"low priority overwrote boundary response")
	m.held=true
	m.advance(11)
	m.held=false
	m.advance(.1)
	check(m.phase!="react" and m.context_reactions.pending.is_empty(),"stale response replayed")
	m.context_reactions.queue("water")
	m.cancel_play()
	m.advance(.5)
	check(m.phase!="react","cancelled response replayed")
	m.phase="ball_ready"
	m.ball_visible=true
	m.context_reactions.queue("ball")
	m.advance(.3)
	check(m.phase=="react" and m.ball_visible,"reaction hid playable ball")
	m.advance(5)
	check(m.phase=="ball_ready" and m.ball_visible,"ball followup lost")
	m=Motion.new()
	m.autonomy=false
	m.context_reactions.queue("tired")
	for i in range(20):
		m.context_reactions.queue("tired")
		m.advance(.02)
	check(m.phase=="react","repeated queue starved reaction")
	# Exercise actual completion signal -> Main mapping, including home IDs.
	var app=Main.new()
	app.state=State.new()
	var pet=Pet.new()
	app.pet=pet
	pet.motion.autonomy=false
	pet.motion.activity_finished.connect(app.on_activity_finished)
	for id in ["home_sofa","home_tea","home_shelf","home_daybed","home_vanity","home_record_player","home_play_rug","home_window_seat","hand_feed","water","empty"]:
		pet.motion.context_reactions=Context.new()
		pet.motion.cancel_play()
		pet.motion.visit_id=id
		pet.motion.phase="home_use" if id.begins_with("home_") else "eat"
		pet.motion.action_left=.01
		pet.motion.advance(.02)
		pet.motion.advance(.3)
		check(pet.motion.reaction_context==Context.completed_event(id,pet.motion),"completion not wired "+id)
	pet.free()
	app.free()
	print("CONTEXT_REACTIONS cases=",count," failures=",failures)
	quit(0 if failures.is_empty() else 1)
