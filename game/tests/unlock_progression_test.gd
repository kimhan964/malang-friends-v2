extends SceneTree
const State=preload("res://scripts/pet_state.gd")
const Main=preload("res://scripts/main.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
class MemoryState extends State:
	func save_game() -> void: pass
class Pet extends Node:
	var species=0
	var motion=Motion.new()
var failures=[]
var checks=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for species in range(16):
		for id in State.ACTION_ROUTES:
			var s=MemoryState.new()
			var route=State.ACTION_ROUTES[id]
			# Route boundary, independent of the legacy point threshold.
			s.activity_counts[str(species)]={route[0]:route[1]-1}
			check(not s.unlocked(species,id),"route opened early "+id)
			s.activity_counts[str(species)][route[0]]+=1
			check(s.unlocked(species,id),"route failed "+id)
			check(not s.unlocked((species+1)%16,id),"species leaked "+id)
			var old=MemoryState.new()
			old.play_affection[str(species)]=State.UNLOCKS[id]
			check(old.unlocked(species,id),"legacy threshold lost "+id)
	var state=MemoryState.new()
	var notices=[]
	state.affection_changed.connect(func(_s,gifts): notices.append_array(gifts))
	for i in range(3):
		state.reward_times.clear()
		state.reward_activity(0,"acorn")
	check(state.unlocked(0,"playful") and state.unlocked(0,"basket"),"early play route failed")
	check(notices.count("playful")==1 and notices.count("basket")==1,"route notification missing/duplicated")
	state.add_affection(0,50)
	check(notices.count("playful")==1 and notices.count("basket")==1,"point threshold repeated old gift")
	state=MemoryState.new()
	state.reward_activity(0,"home_rest")
	state.reward_activity(0,"home_rest")
	check(state.activity_counts["0"].home_rest==1,"home cooldown failed")
	state.reward_times["0:home_rest"]-=44
	state.reward_activity(0,"home_rest")
	check(state.activity_counts["0"].home_rest==1,"home cooldown too short")
	state.reward_times["0:home_rest"]-=2
	state.reward_activity(0,"home_rest")
	check(state.unlocked(0,"cushion") and state.activity_counts["0"].home_rest==2,"home rest reward failed")
	check(state.growth["0"]==2,"home growth failed")
	# Actual motion completion -> application -> recorded home activity.
	var app=Main.new()
	app.state=MemoryState.new()
	var pet=Pet.new()
	app.pet=pet
	pet.motion.autonomy=false
	pet.motion.activity_finished.connect(app.on_activity_finished)
	for id in ["home_sofa","home_tv","home_turntable","home_tea","home_shelf","home_vanity","home_play_rug"]:
		app.state.reward_times.clear()
		pet.motion.cancel_play()
		pet.motion.visit_id=id
		pet.motion.phase="home_use"
		pet.motion.action_left=.01
		pet.motion.advance(.02)
	for action in ["home_rest","home_music","home_tea","home_read","home_groom","home_play"]:
		check(app.state.activity_counts["0"].get(action,0)>0,"completion missing "+action)
	pet.free()
	app.free()
	# Isolated save round trip; never touch the real save.
	var disk=State.new()
	disk.save_path="user://unlock-progress-test-"+str(Time.get_ticks_usec())+".json"
	disk.activity_counts={"0":{"home_rest":6,"acorn":3},"1":{"home_music":3}}
	disk.play_affection={"2":50}
	disk.save_game()
	var loaded=State.new()
	loaded.save_path=disk.save_path
	loaded.load_game()
	check(loaded.unlocked(0,"shelter") and loaded.unlocked(1,"lamp") and loaded.unlocked(2,"shelter"),"save round trip lost unlocks")
	check(not loaded.unlocked(1,"shelter"),"saved species leaked")
	DirAccess.remove_absolute(disk.save_path)
	print("UNLOCK_PROGRESSION checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
