extends RefCounted

const Personality=preload("res://scripts/personality_behaviors.gd")
var daily=preload("res://scripts/daily_behaviors.gd").new()
var behavior_points=0
var personality_steps: Array=[]
var personality_origin=Vector2.ZERO
var personality_speed=1.0
var personality_active=false
var personality_cooldown=18.0

signal bonded
signal activity_bonded(action: String)
var personality_reward=false
signal visited(id: String)
signal activity_finished(id: String)
var reaction=""
var reaction_time=0.0
var reaction_duration=2.0
var reaction_followup="idle"
var reaction_variant=0
var reaction_context=""
var reaction_words=""
var reaction_strength=1.0
var context_reactions=preload("res://scripts/context_reactions.gd").new()
var pending_reaction=""
var affection=0
var can_ask_play=false
var ask_left=45.0
var cursor_position=Vector2.ZERO
const Profiles=preload("res://scripts/companion_profiles.gd")
var habit_cooldown=0.0
var habit_round=0
var habit_start=Vector2.ZERO
var habit_target=Vector2.ZERO
var destinations: Array=[]
var visit_id=""
var visit_action="idle"
var visit_reward=false
var action_left=0.0
var prop_dragging=false
var prop_press=Vector2.ZERO
var prop_last=Vector2.ZERO
var prop_strength=0.0
var prop_progress=0.0
var prop_effort=0.0
var soft_toy_contact=false
var soft_toy_time=0.0
var soft_toy_prop=""
var soft_scene_origin=Vector2.ZERO
var soft_scene_scale=Vector2.ONE
var soft_scene_mirrored=false
var soft_scene_lift=0.0
var soft_scene_style: Dictionary={}
var food_id=-1
var favorite_food=false
var autonomy=true
var energy=65.0
var satiety=70.0
var hydration=75.0
var recent_actions: Array=[]
var last_destination=""
var stay_after_visit=false
var favorite_place="cushion"
const SPEEDS=[66.0,52.0,82.0,46.0,54.0,72.0,44.0,50.0,60.0,56.0,62.0,42.0,56.0,48.0,44.0,46.0]
var species=0
var growth_scale=1.0
var growth_stage=-1
var outfit_style=0
var outfit_color=0
var bounds=Rect2(100,160,1080,520)
var feet=Vector2.ZERO
var travel_speed=0.0
var walk_phase=0.0
var rabbit_pilot=false
var smooth_walk_enabled=false # v5 rejected by user; only explicitly enabled in review scenes.
var smooth_walk_cycle=preload("res://scripts/smooth_species_motion.gd").new()
var pilot_hop=preload("res://scripts/rabbit_hop_motion.gd").new()
var pilot_start_left=0.0
var pilot_settle_left=0.0
var pilot_stop_phase=0.0
var pilot_contact_phase=0.0
var pilot_idle_index=0
var pilot_was_traveling=false
var can_playful=false
var can_personality=false
var can_follow=false
var can_rub=false
var social_kind=""
var social_left=0.0
var social_cooldown=12.0
var social_reward=false
var social_contact=0.0
var social_anchor=Vector2.ZERO
var voice_left=0.0
var voice_cooldown=0.0
var voice_text=""
var initiative_cooldown=5.0
var last_initiative=""
var tool_interest_left=7.0

func try_tool_interest() -> bool:
	# Basic needs and a deliberate rest take precedence over playing.
	if tool_interest_left>0 or energy<35 or satiety<48 or hydration<45 or resting or held: return false
	var choices: Array=[]
	for destination in destinations:
		if destination.id in ["acorn","plant","basket"]: choices.append(destination)
	if choices.is_empty(): return false
	var different=choices.filter(func(d): return d.id!=last_destination)
	if not different.is_empty(): choices=different
	var chosen=choices[rng.randi_range(0,choices.size()-1)]
	tool_interest_left=rng.randf_range(12,20)
	last_destination=chosen.id
	remember(chosen.action)
	visit(chosen.point,chosen.action,chosen.id,false)
	return true

func say(words: String) -> void:
	voice_text=words
	voice_left=2.8
	voice_cooldown=10.0

func try_initiative() -> bool:
	if initiative_cooldown>0: return false
	initiative_cooldown=rng.randf_range(14,24)
	# Needs come before distractions; only visible unlocked destinations exist here.
	var wanted="bowl" if satiety<48 else ("water" if hydration<45 else ("cushion" if energy<35 else ""))
	if not wanted.is_empty():
		for destination in destinations:
			if destination.id==wanted or destination.id=={"bowl":"home_food","water":"home_water","cushion":"home_sofa"}[wanted]:
				last_initiative=wanted
				visit(destination.point,destination.action,destination.id)
				say({"bowl":"밥 먹으러 가자~","water":"목말라~","cushion":"졸려…"}[wanted])
				return true
		if wanted!=last_initiative:
			last_initiative=wanted
			react("greet",2.0)
			say("배고파…" if wanted=="bowl" else ("목말라…" if wanted=="water" else "잠깐 쉴래…"))
			return true
	var choices=["explore","watch","groom"]
	if affection>=3: choices.append("attention")
	if can_ask_play: choices.append("invite")
	choices.erase(last_initiative)
	var chosen=choices[rng.randi_range(0,choices.size()-1)]
	last_initiative=chosen
	match chosen:
		"explore":
			var point=(feet+Vector2(rng.randf_range(-110,110),rng.randf_range(-40,40))).clamp(bounds.position,bounds.end)
			visit(point,"sniff","explore")
			say("여긴 뭐지?")
		"watch":
			phase="look"
			elapsed=0
			action_left=2.5
			if absf(cursor_position.x-feet.x)>2: facing=signf(cursor_position.x-feet.x)
			say("빤히…")
		"groom":
			phase="stretch" if energy<55 else "groom"
			elapsed=0
			action_left=2.8
			say("으쌰~" if phase=="stretch" else "단장 중~")
		"attention":
			react("pet",2.2)
			say("쓰다듬어 줘~")
		"invite":
			var point=(feet+(cursor_position-feet).limit_length(75)).clamp(bounds.position,bounds.end)
			visit(point,"askplay","askplay")
			ask_left=60
			say("공놀이 할래?")
	return true
const VOICES=["뀨!","삐익!","찍찍!","킁킁!","쿠루!","캥!","크웅!","부엉!","야옹~","멍멍!","찍!","웅~","끼잉!","메에~","쿠우~","꽥꽥!"]

func speak() -> void:
	if voice_cooldown<=0:
		voice_text=""
		voice_left=2.0
		voice_cooldown=10.0

func start_social(kind: String, reward: bool=false) -> bool:
	if kind=="follow" and not can_follow: return false
	if kind=="rub" and (not can_rub or destinations.is_empty()): return false
	if kind not in ["follow","rub"]: return false
	cancel_play()
	resting=false
	held=false
	social_kind=kind
	social_left=7.0 if kind=="follow" else 12.0
	social_reward=reward
	social_contact=0
	social_cooldown=35.0
	if kind=="rub":
		var nearest=destinations[0].point
		for destination in destinations:
			if feet.distance_to(destination.point)<feet.distance_to(nearest): nearest=destination.point
		social_anchor=(nearest+Vector2(-28,0)).clamp(bounds.position,bounds.end)
	speak()
	return true

func advance_social(delta: float) -> void:
	social_left-=delta
	if social_kind=="follow":
		var offset=cursor_position-feet
		if offset.length()>500 or not bounds.grow(80).has_point(cursor_position): social_left=0
		target=(cursor_position-offset.normalized()*65).clamp(bounds.position,bounds.end)
		if offset.length()>80 or smooth_walk_cycle.active or (rabbit_pilot and pilot_hop.active):
			phase="wander"
			advance_travel(delta,.85)
			if travel_speed>5: social_contact+=delta
		else:
			phase="look"
			travel_speed=0
			if absf(offset.x)>2: facing=signf(offset.x)
	else:
		target=social_anchor
		if not travel_complete(2.0):
			phase="wander"
			advance_travel(delta,.7)
		else:
			phase="rub"
			social_contact+=delta
			if social_contact>=3: social_left=0
	if social_left<=0 and not smooth_walk_cycle.active and not (rabbit_pilot and pilot_hop.active):
		var finished=social_kind
		var earned=social_reward and social_contact>=1.0
		social_kind=""
		social_reward=false
		phase="idle"
		target=feet
		rest_left=2
		if earned: activity_bonded.emit(finished)
var travel_direction=Vector2.ZERO
var target=Vector2.ZERO
var phase="idle"
var facing=1.0
var elapsed=0.0
var rest_left=1.0
var joy_left=0.0
var cooldown=0.0
var resting=false
var held=false
var pointer_grab=false
var carried=false
var carry_elapsed=0.0
var carry_started_at=0.0
var hold_release: Dictionary={}
var soft_grab_point=Vector2(128,130)
var soft_touch_sample: Dictionary={}
var soft_recover_left=0.0
var soft_dizzy_wobble=true
var dizzy_duration=4.8
const CARRY_PICKUP_SECONDS=.24
const STRUGGLE_ENTRY_SECONDS=.32

func capture_hold_release() -> void:
	if not pointer_grab or not carried: return
	hold_release={"clock":carry_elapsed,"pickup":carry_started_at,"long":is_struggling(),"elapsed":0.0}
var landing_left=0.0
var dizzy_followup="idle"
var silly_kind=""
var silly_followup="idle"
var slapstick=preload("res://scripts/slapstick.gd").new()
const DIZZY_DURATION=4.8
const DIZZY_LANDING=0.45
const DROP_HOLD_SECONDS=3.0
const STRUGGLE_HOLD_SECONDS=2.0

func is_struggling() -> bool:
	return pointer_grab and held and carried and carry_elapsed>=STRUGGLE_HOLD_SECONDS

func struggle_age() -> float:
	return maxf(0.0,carry_elapsed-STRUGGLE_HOLD_SECONDS)

func should_drop_on_release() -> bool:
	return carry_elapsed>=DROP_HOLD_SECONDS
var drop_start=Vector2.ZERO
var drop_ground=Vector2.ZERO
var drop_duration=0.0
var ball_visible=false
var ball_velocity=Vector2.ZERO
var ball_height=0.0
var ball_lift=0.0
var ball_position=Vector2.ZERO
var ball_start=Vector2.ZERO
var ball_target=Vector2.ZERO
var throw_origin=Vector2.ZERO
var flight=0.0
var rng=RandomNumberGenerator.new()

func configure(screen: Rect2, initial: Vector2) -> void:
	# Coordinates are desktop pixels, including negative monitor origins.
	bounds=Rect2(screen.position+Vector2(128,190),(screen.size-Vector2(256,224)).max(Vector2.ONE))
	feet=initial.clamp(bounds.position,bounds.end)
	target=feet
	rng.randomize()
	rest_left=rng.randf_range(.6,1.2)
	habit_cooldown=rng.randf_range(2,4)

func pet() -> void:
	if cooldown>0: return
	speak()
	ask_left=55
	cancel_play()
	context_reactions.play(self,"pet")
	joy_left=1.8
	cooldown=2.2
	bonded.emit()

func cancel_play() -> void:
	daily.clear()
	context_reactions.clear()
	silly_kind=""
	hold_release.clear()
	carry_started_at=0.0
	pointer_grab=false
	carry_elapsed=0.0
	soft_recover_left=0.0
	soft_touch_sample.clear()
	soft_toy_contact=false
	soft_toy_time=0.0
	soft_toy_prop=""
	soft_scene_lift=0.0
	smooth_walk_cycle.reset()
	pilot_hop.reset()
	pilot_was_traveling=false
	pilot_start_left=0.0
	pilot_settle_left=0.0
	if rabbit_pilot: walk_phase=0.0
	social_kind=""
	social_reward=false
	prop_dragging=false
	prop_strength=0.0
	prop_progress=0.0
	prop_effort=0.0
	personality_reward=false
	personality_steps.clear()
	personality_active=false
	reaction=""
	reaction_followup="idle"
	carried=false
	landing_left=0
	dizzy_followup="idle"
	drop_duration=0.0
	ball_visible=false
	visit_id=""
	visit_reward=false
	stay_after_visit=false
	phase="idle"
	target=feet
	rest_left=rng.randf_range(1,2)

func move_to(point: Vector2) -> void:
	cancel_play()
	feet=point.clamp(bounds.position,bounds.end)
	target=feet

var floor_space=false
var drop_dizzy=true
func begin_drop(with_dizzy: bool=true) -> void:
	drop_dizzy=with_dizzy
	pointer_grab=false
	dizzy_followup=phase if phase in ["visit","react"] else "idle"
	drop_start=feet
	# Keep a deliberate drop onto a prop; ordinary releases fall to the desktop
	# floor. Moving the native window avoids clipping or shrinking tall falls.
	var floor_y=maxf(feet.y,target.y) if phase=="visit" else maxf(feet.y,bounds.end.y)
	drop_ground=Vector2(feet.x,floor_y)
	if floor_space:
		drop_ground=drop_ground.clamp(bounds.position,bounds.end)
		drop_ground.y=bounds.get_center().y
	if dizzy_followup!="visit": target=drop_ground
	drop_duration=clampf(sqrt(2.0*maxf(0.0,floor_y-feet.y)/1600.0),.18,1.25)
	carried=false
	held=false
	landing_left=0.0
	phase="drop"
	elapsed=0.0
	carry_elapsed=0.0
	voice_left=0.0
	joy_left=0.0

func begin_dizzy(dazed: bool=true) -> void:
	soft_dizzy_wobble=dazed
	dizzy_duration=DIZZY_DURATION if dazed else DIZZY_LANDING+.65
	pointer_grab=false
	# Preserve a prop visit started by the drop; resume it after recovery.
	if phase!="drop": dizzy_followup=phase if phase in ["visit","react"] else "idle"
	carried=false
	held=false
	landing_left=DIZZY_LANDING
	phase="dizzy"
	elapsed=0.0
	rest_left=4.0

func prepare_ball() -> void:
	cancel_play()
	resting=false
	held=false
	phase="ball_ready"
	ball_visible=true
	ball_height=0
	ball_position=(feet+Vector2(70*facing,0)).clamp(bounds.position,bounds.end)

func release_ball(point: Vector2, velocity: Vector2) -> void:
	held=false
	ball_position=point.clamp(bounds.position,bounds.end)
	ball_velocity=velocity.limit_length(1400)
	ball_height=0
	ball_lift=minf(180,ball_velocity.length()*.18)
	throw_origin=feet
	flight=0
	ask_left=70
	phase="ball_flight" if ball_velocity.length()>=70 else "ball_ready"

func advance_ball(delta: float) -> void:
	# Substeps keep bounces stable if the desktop briefly drops frames.
	var remaining=minf(delta,.25)
	while remaining>0:
		var step=minf(remaining,1.0/120.0)
		remaining-=step
		ball_position+=ball_velocity*step
		ball_velocity*=exp(-3.0*step)
		for axis in [0,1]:
			if ball_position[axis]<bounds.position[axis] or ball_position[axis]>bounds.end[axis]:
				ball_position[axis]=clampf(ball_position[axis],bounds.position[axis],bounds.end[axis])
				ball_velocity[axis]*=-.55
		ball_lift-=620*step
		ball_height+=ball_lift*step
		if ball_height<0:
			ball_height=0
			ball_lift=-ball_lift*.32 if absf(ball_lift)>35 else 0.0
	flight+=delta
	if ball_velocity.length()<18 and ball_height<1 or flight>3:
		ball_height=0
		ball_target=ball_position
		target=ball_target
		phase="chase"

func visit(point: Vector2, action: String, id: String="", reward: bool=false) -> void:
	cancel_play()
	resting=false
	held=false
	target=point.clamp(bounds.position,bounds.end)
	if floor_space: target.y=bounds.get_center().y
	visit_action=action
	visit_id=id
	visit_reward=reward
	phase="visit"

func begin_prop_drag(cursor: Vector2) -> void:
	if phase!="prop_use": return
	prop_dragging=true
	prop_press=cursor
	prop_last=cursor
	action_left=8.0

func drag_prop(cursor: Vector2) -> void:
	if not prop_dragging or phase!="prop_use": return
	var distance=cursor.distance_to(prop_last)
	prop_effort+=minf(distance,30.0)
	prop_progress+=minf(distance,30.0)/18.0
	prop_last=cursor
	prop_strength=clampf((cursor.x-prop_press.x)/maxf(30,70*growth_scale),0,1)

func release_prop_drag() -> void:
	prop_dragging=false
	prop_strength=0
	if phase=="prop_use" and prop_effort>=30:
		visit_reward=true
		action_left=minf(action_left,1.2)

func finish_prop_use() -> void:
	var completed=visit_id
	var reward=visit_reward and (species!=9 or completed!="plant" or prop_effort>=30)
	prop_dragging=false
	prop_strength=0
	visit_reward=false
	visit_id=""
	phase="idle"
	rest_left=2.5
	if reward:
		activity_bonded.emit(completed)
		joy_left=1.8
	activity_finished.emit(completed)

func remember(action: String) -> void:
	recent_actions.append(action)
	if recent_actions.size()>2: recent_actions.pop_front()

func choose_autonomous_action() -> void:
	if try_tool_interest(): return
	if try_initiative(): return
	if social_cooldown<=0 and energy>30:
		if can_follow and feet.distance_to(cursor_position)<260 and feet.distance_to(cursor_position)>85:
			if start_social("follow"): return
		if can_rub and not destinations.is_empty():
			if start_social("rub"): return
	if can_personality and personality_cooldown<=0 and energy>30:
		start_personality()
		return
	if can_ask_play and ask_left<=0 and energy>35:
		ask_left=rng.randf_range(55,90)
		var near=feet+(cursor_position-feet).limit_length(100)
		visit(near,"askplay","askplay")
		return
	# Give each friend a visible animation regularly, even without unlocked props.
	if can_playful and habit_cooldown<=0 and energy>25:
		remember("signature")
		start_habit()
		return
	var options: Array=[]
	if can_playful and habit_cooldown<=0:
		options.append({"action":"signature","weight":38.0 if energy>35 else 12.0})
	for action in ["wander","look","groom","stretch","doze"]:
		var weight={"wander":42.0,"look":10.0,"groom":12.0,"stretch":8.0,"doze":.4}[action]
		if action=="doze" and energy<40: weight+=(40-energy)*1.2
		if action in recent_actions: weight*=.15
		options.append({"action":action,"weight":weight})
	for destination in destinations:
		var action=destination.action
		var weight=24.0 if destination.id in ["acorn","plant","basket"] and energy>=35 else 8.0
		if action=="eat": weight+=(100-satiety)*.55
		elif action=="drink": weight+=(100-hydration)*.45
		elif action in ["relax","doze"]:
			weight=2.0 if energy>=40 else 8.0+(40-energy)*1.2
		if destination.id==favorite_place: weight*=1.6
		if destination.id==last_destination: weight*=.12
		if action in recent_actions: weight*=.3
		options.append({"action":action,"weight":weight,"destination":destination})
	var total=0.0
	for option in options: total+=option.weight
	var roll=rng.randf()*total
	var chosen=options.back()
	for option in options:
		roll-=option.weight
		if roll<=0:
			chosen=option
			break
	remember(chosen.action)
	if chosen.action=="signature":
		start_habit()
	elif chosen.has("destination"):
		var destination=chosen.destination
		last_destination=destination.id
		visit(destination.point,destination.action,destination.id)
	elif chosen.action=="wander":
		# Short strolls are more common than crossing the whole desktop.
		var angle=rng.randf_range(-PI,PI)
		var step=Vector2(cos(angle),sin(angle)*.55)*rng.randf_range(65,155)
		target=(feet+step).clamp(bounds.position,bounds.end)
		if feet.distance_to(target)<30: target=(feet-step).clamp(bounds.position,bounds.end)
		phase="wander"
	else:
		phase=chosen.action
		elapsed=0
		action_left=rng.randf_range(24,40) if phase=="doze" else rng.randf_range(1.4,2.8)
		if phase=="doze": react("sleepy",2.4,"doze")

func react(kind: String, duration: float=2.0, followup: String="idle") -> void:
	reaction_context=""
	reaction_words=""
	reaction_strength=1.0
	ball_visible=false
	reaction=kind
	reaction_time=0
	reaction_duration=duration
	reaction_followup=followup
	reaction_variant=rng.randi_range(0,1)
	phase="react"
	elapsed=0
	target=feet

func start_personality(reward: bool=false) -> void:
	cancel_play()
	personality_reward=reward
	resting=false
	held=false
	personality_origin=feet
	personality_steps=Personality.sequence(species,feet,cursor_position,facing)
	personality_active=true
	personality_cooldown=rng.randf_range(38,60)
	next_personality_step()

func next_personality_step() -> void:
	if personality_steps.is_empty():
		if personality_reward: activity_bonded.emit("personality")
		personality_reward=false
		personality_active=false
		reaction=""
		phase="idle"
		target=feet
		rest_left=rng.randf_range(1,2)
		return
	var step: Dictionary=personality_steps.pop_front()
	if step.has("offset"):
		reaction=""
		phase="wander"
		elapsed=0
		target=(personality_origin+step.offset).clamp(bounds.position,bounds.end)
		personality_speed=step.speed
	else:
		react(step.pose,step.duration)

func advance_personality(delta: float) -> void:
	if phase=="wander":
		advance_travel(delta,personality_speed)
		if travel_complete(): next_personality_step()
	elif reaction_time>=reaction_duration:
		next_personality_step()

func start_habit() -> void:
	habit_round+=1
	if habit_round%2==1:
		start_playful()
		habit_cooldown=rng.randf_range(10,18)
		return
	cancel_play()
	phase="signature"
	elapsed=0
	habit_start=feet
	var distance={0:42.0,5:50.0}.get(species,0.0)
	var direction=facing
	if not bounds.has_point(feet+Vector2(direction*distance,0)): direction=-direction
	facing=direction
	habit_target=(feet+Vector2(direction*distance,0)).clamp(bounds.position,bounds.end)
	habit_cooldown=rng.randf_range(10,18)

func start_playful(reward: bool=false) -> void:
	cancel_play()
	resting=false
	held=false
	phase="playful"
	elapsed=0
	action_left=3.0
	visit_id="playful"
	visit_action="playful"
	visit_reward=reward

func advance_habit() -> void:
	var progress=clampf(elapsed/Profiles.HABIT_SECONDS[species],0,1)
	var travel=0.0
	match species:
		0:
			travel=.5*smoothstep(.12,.34,progress)+.5*smoothstep(.46,.68,progress)
		2:
			travel=smoothstep(.08,.36,progress)
		5:
			travel=smoothstep(.42,.68,progress)
	feet=habit_start.lerp(habit_target,travel)
	if progress>=1:
		phase="idle"
		target=feet
		rest_left=rng.randf_range(.8,2)

func travel_complete(tolerance: float=.5) -> bool:
	if preload("res://scripts/smooth_species_art.gd").enabled(self):
		return smooth_walk_cycle.arrived(self,preload("res://scripts/smooth_species_art.gd").spec(self))
	# Default legacy arrivals must consume the final fraction of the step.
	# Stopping .5px early accumulated a phase error on every preview reversal.
	var arrival_tolerance=.001 if not rabbit_pilot and is_equal_approx(tolerance,.5) else tolerance
	return feet.distance_to(target)<arrival_tolerance and not (rabbit_pilot and pilot_hop.active)

func advance_travel(delta: float, multiplier: float=1.0) -> void:
	if rabbit_pilot and species==0:
		advance_pilot_travel(delta,multiplier)
		return
	if preload("res://scripts/smooth_species_art.gd").enabled(self):
		smooth_walk_cycle.advance(self,delta,preload("res://scripts/smooth_species_art.gd").spec(self),multiplier)
		return
	var offset=target-feet
	var distance=offset.length()
	if distance<=.001:
		travel_speed=0.0
		return
	var direction=offset/distance
	if direction.dot(travel_direction)<0.0: travel_speed=0.0
	travel_direction=direction
	if absf(offset.x)>.5: facing=1.0 if offset.x>0 else -1.0
	var nominal=SPEEDS[species]*lerpf(.72,1.0,clampf(inverse_lerp(.62,1.0,growth_scale),0,1))
	var gait=preload("res://scripts/gait_profile.gd")
	var maximum=nominal*gait.STRIDE_PERIOD[species]/gait.PERIOD[species]*gait.TRAVEL_RATE*clampf(multiplier,0.0,gait.MAX_WALK_MULTIPLIER)
	var acceleration=maximum/0.24
	var desired=minf(maximum,sqrt(2.0*acceleration*distance))
	travel_speed=move_toward(travel_speed,desired,acceleration*delta)
	# The sprite contains the weight transfer. Keep desktop travel smooth and
	# advance the gait by actual distance, including starts and stops.
	var step=minf(distance,travel_speed*delta)
	var previous_feet=feet
	feet+=direction*step
	# Feet cadence follows actual travel, including acceleration and slowing down.
	# Vector2 rounds to float32: use the displacement actually stored, so many
	# short frames do not accumulate a foot-phase error over repeated trips.
	walk_phase=fposmod(walk_phase+feet.distance_to(previous_feet)/maxf(16.0,nominal*gait.STRIDE_PERIOD[species]),1.0)

func advance_pilot_travel(delta: float,multiplier: float) -> void:
	var spec=preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if growth_stage==0 else "adult"]
	if spec.get("locomotion","")=="short_hop":
		pilot_hop.advance(self,delta,spec)
		return
	var offset=target-feet
	var distance=offset.length()
	if not pilot_was_traveling:
		pilot_was_traveling=true
		pilot_start_left=.24
		walk_phase=float(pilot_idle_index)*.5
		travel_speed=0.0
	if absf(offset.x)>.5: facing=signf(offset.x)
	if pilot_start_left>0:
		pilot_start_left=maxf(0,pilot_start_left-delta)
		return
	if distance<=.001:
		travel_speed=0
		return
	var direction=offset/distance
	travel_direction=direction
	# Whole illustrated cels; the loop follows travel distance rather than the
	# wall clock, so slowing the window also slows the illustrated step.
	var height=float(preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if growth_stage==0 else "adult"].reference_height)
	var stride=float(preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if growth_stage==0 else "adult"].stride)*110.0*preload("res://scripts/animal_catalog.gd").HEIGHTS[0]*growth_scale/height
	var cycle=float(preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if growth_stage==0 else "adult"].cycle_seconds)
	var maximum=stride/cycle*preload("res://scripts/gait_profile.gd").TRAVEL_RATE*minf(multiplier,1.3)
	var acceleration=maximum/.62
	var desired=minf(maximum,sqrt(2*acceleration*distance))
	travel_speed=move_toward(travel_speed,desired,acceleration*delta)
	var step=minf(distance,travel_speed*delta)
	feet+=direction*step
	walk_phase=fposmod(walk_phase+step/stride,1.0)
	if feet.distance_to(target)<.5:
		walk_phase=fposmod(walk_phase+feet.distance_to(target)/stride,1.0)
		feet=target
		pilot_idle_index=int(round(fposmod(walk_phase,1.0)*2.0))%2

func update_pilot_settle(delta: float) -> void:
	if not rabbit_pilot: return
	var traveling=phase in ["wander","chase","return","visit"] and not carried and not held
	if not traveling and pilot_was_traveling:
		pilot_was_traveling=false
		pilot_start_left=0
		pilot_stop_phase=walk_phase
		pilot_contact_phase=roundf(walk_phase*2.0)/2.0
		pilot_idle_index=int(round(fposmod(pilot_contact_phase,1.0)*2.0))
		if pilot_hop.active: pilot_hop.reset()
		if preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if growth_stage==0 else "adult"].get("locomotion","")=="short_hop": pilot_idle_index=0
		# The pilot plans its destination at contact, so do not move the feet
		# through extra walk drawings after desktop travel has stopped.
		pilot_settle_left=0.0
		travel_speed=0
	pilot_settle_left=maxf(0,pilot_settle_left-delta)

func advance(delta: float) -> void:
	context_reactions.tick(delta)
	if phase not in ["wander","chase","return","visit"] or carried or held or not preload("res://scripts/smooth_species_art.gd").enabled(self):
		smooth_walk_cycle.reset()
	update_pilot_settle(delta)
	initiative_cooldown=maxf(0,initiative_cooldown-delta)
	if not held and not resting: tool_interest_left=maxf(0,tool_interest_left-delta)
	voice_left=maxf(0,voice_left-delta)
	voice_cooldown=maxf(0,voice_cooldown-delta)
	social_cooldown=maxf(0,social_cooldown-delta)
	if held or phase not in ["wander","chase","return","visit"]:
		travel_speed=0.0
		travel_direction=Vector2.ZERO
	elapsed+=delta
	soft_recover_left=maxf(0,soft_recover_left-delta)
	if not hold_release.is_empty(): hold_release.elapsed+=delta
	if not reaction.is_empty(): reaction_time+=delta
	if carried or (pointer_grab and held): carry_elapsed+=delta
	landing_left=maxf(0,landing_left-delta)
	cooldown=maxf(0,cooldown-delta)
	joy_left=maxf(0,joy_left-delta)
	satiety=maxf(0,satiety-delta*.08)
	hydration=maxf(0,hydration-delta*.1)
	energy=maxf(0,energy-delta*(.2 if phase in ["wander","chase","return","visit"] else .025))
	if held: return
	if daily.advance(self,delta): return
	# Recover invalid elevated feet before any floor-lane walking, including
	# furniture visits interrupted by menus or old saved movement state.
	if floor_space and phase in ["wander","chase","return","visit"] and feet.y<bounds.position.y-2:
		begin_drop(false)
	if slapstick.advance(self,delta): return
	if context_reactions.advance(self): return
	if phase=="drop":
		carry_elapsed=elapsed
		var progress=clampf(elapsed/maxf(.01,drop_duration),0.0,1.0)
		feet=drop_start.lerp(drop_ground,progress*progress)
		if progress>=1.0:
			if drop_dizzy: begin_dizzy()
			elif smooth_walk_enabled: begin_dizzy(false)
			else:
				phase=dizzy_followup
				elapsed=0
				landing_left=0
		return
	if phase=="dizzy":
		if elapsed>=dizzy_duration:
			phase=dizzy_followup
			dizzy_followup="idle"
			landing_left=0.0
			elapsed=0.0
			if phase=="react": reaction_time=0.0
		return
	if not social_kind.is_empty():
		advance_social(delta)
		return
	if phase=="prop_use":
		action_left-=delta
		if not prop_dragging: prop_progress+=delta*.65*preload("res://scripts/prop_interactions.gd").SPEEDS[species]
		if prop_dragging: action_left=maxf(action_left,1.0)
		if visit_id=="lamp": energy=minf(100,energy+delta*2)
		if action_left<=0: finish_prop_use()
		return
	if phase=="home_use":
		action_left-=delta
		if visit_id in ["home_sofa","home_daybed","home_lamp","home_window_seat"]: energy=minf(100,energy+delta*1.5)
		if visit_id=="home_tea": hydration=minf(100,hydration+delta*5)
		if visit_id=="home_bathtub": energy=minf(100,energy+delta*.8)
		if action_left<=0:
			var completed=visit_id
			soft_toy_prop=""
			visit_id=""
			phase="idle"
			elapsed=0
			rest_left=.35
			activity_finished.emit(completed)
		return
	if phase=="ball_ready": return
	if phase=="interaction_done":
		var finished=visit_id
		var reward=visit_reward
		visit_id=""
		visit_reward=false
		phase="idle"
		rest_left=2
		if reward: activity_bonded.emit(finished)
		activity_finished.emit(finished)
		return
	if phase=="ball_flight":
		advance_ball(delta)
		return
	if not resting: personality_cooldown=maxf(0,personality_cooldown-delta)
	if personality_active:
		advance_personality(delta)
		return
	if not resting: ask_left=maxf(0,ask_left-delta)
	if phase=="react":
		if reaction_time>=reaction_duration:
			reaction=""
			phase=reaction_followup
			elapsed=0
			rest_left=rng.randf_range(1,2)
			if phase=="doze": action_left=rng.randf_range(28,48)
		return
	if phase=="idle" and not pending_reaction.is_empty():
		var next_reaction=pending_reaction
		pending_reaction=""
		react(next_reaction,2.4)
		return
	if phase=="idle" and autonomy and not resting and energy<30:
		context_reactions.queue("tired")
	habit_cooldown=maxf(0,habit_cooldown-delta)
	if phase=="signature":
		advance_habit()
	elif phase in ["wander","chase","return","visit"]:
		advance_travel(delta,1.5 if phase in ["chase","return"] else 1.0)
		if phase=="return": ball_position=feet+Vector2(facing*22,-28)
		if travel_complete():
			if phase=="visit":
				phase=visit_action
				action_left=rng.randf_range(28,48) if phase=="doze" else (rng.randf_range(3,5) if phase=="relax" else (5.5 if phase in ["eat","drink"] else 4.0))
				if phase=="drink" and visit_id=="water" and preload("res://scripts/dining_species_art.gd").enabled(self):
					# Finish the authored recovery instead of cutting off a bowed pose.
					action_left=float(preload("res://scripts/dining_species_art.gd").spec(self).duration)*2.0
				elapsed=0
				if phase=="home_use": action_left=preload("res://scripts/home_animation.gd").duration(visit_id)
				if phase=="prop_use":
					action_left=4.5 if visit_id=="acorn" else (14.0 if species==9 and visit_id=="plant" else 8.0)
					facing=1.0
				visited.emit(visit_id)
				if phase=="doze": react("sleepy",2.4,"doze")
				elif phase in ["askplay","inspect","pet"]:
					react(phase,2.2,"interaction_done" if visit_reward else "idle")
			elif phase=="chase":
				phase="return"
				target=throw_origin
			elif phase=="return":
				react("askplay",1.8,"ball_ready")
				context_reactions.queue("ball")
				ball_visible=true
				ball_height=0
				ball_position=(feet+Vector2(70*facing,0)).clamp(bounds.position,bounds.end)
				joy_left=1.8
				activity_bonded.emit("ball")
			else:
				phase="idle"
				rest_left=rng.randf_range(.7,1.8)
				if rabbit_pilot: elapsed=0.0
	elif phase in ["eat","drink","relax","sniff","look","groom","stretch","doze","cuddle","playful"]:
		action_left-=delta
		# A deliberate bed command keeps the actual sleeping pose until interrupted.
		if phase=="doze" and stay_after_visit: action_left=maxf(1.2,action_left)
		if phase=="doze" and visit_reward and elapsed>=3:
			visit_reward=false
			activity_bonded.emit("doze")
		if phase=="eat": satiety=minf(100,satiety+delta*7)
		elif phase=="drink": hydration=minf(100,hydration+delta*9)
		elif phase in ["relax","doze","cuddle"]: energy=minf(100,energy+delta*(2 if phase=="doze" else 1))
		if action_left<=0:
			var completed_id=visit_id if not visit_id.is_empty() else phase
			if visit_reward:
				activity_bonded.emit(visit_action if visit_action in ["doze","relax","cuddle"] else visit_id)
				joy_left=1.8
			visit_reward=false
			phase="idle"
			rest_left=rng.randf_range(.35,.65)
			if rabbit_pilot: elapsed=0.0
			if stay_after_visit: resting=true
			stay_after_visit=false
			visit_id=""
			activity_finished.emit(completed_id)
	elif phase=="pet":
		if joy_left<=0:
			phase="idle"
			rest_left=rng.randf_range(1,2)
	elif not resting and autonomy:
		rest_left-=delta
		if rest_left<=0:
			choose_autonomous_action()
