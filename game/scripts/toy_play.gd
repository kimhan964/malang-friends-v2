extends RefCounted
## Reuse each animal's walk/sniff frames while following a moving toy.
const IDS=["toy_mouse","toy_ball","toy_plush"]
var hug_piece
var contact_motion
var id=""
var stage=""
var clock=0.0
var round_index=0
var species=-1
var start=Vector2.ZERO
var goal=Vector2.ZERO
var direction=1
var pet_start=Vector2.ZERO
var pet_goal=Vector2.ZERO
var user_motion: Dictionary={}
func busy() -> bool: return not id.is_empty() or not user_motion.is_empty()
func arrived(room,key: String) -> bool:
	if key not in ["home_toy_mouse","home_toy_ball","home_toy_plush"]: return false
	var m=room.app.pet.motion
	contact_motion=m
	if key=="home_toy_plush":
		id="toy_plush";species=m.species;stage="hug";clock=0
		hug_piece=room.pieces[id]
		hug_piece.hide()
		m.phase="home_use";m.elapsed=0;m.action_left=preload("res://scripts/home_animation.gd").duration(key)
		m.soft_toy_prop="toy_plush"
		m.say("꼬옥, 같이 놀자")
		return true
	if not user_motion.is_empty() and key=="home_"+str(user_motion.id):
		user_motion.arrived=true
		m.phase="sniff";m.elapsed=0;m.action_left=20
		m.soft_toy_contact=true;m.soft_toy_time=0
		return true
	if busy() and key=="home_"+id:
		if stage=="follow":
			room.pieces[id].position=Vector2i(goal)
			stage="inspect"
			clock=0
			m.phase="sniff"
			m.elapsed=0
			m.action_left=20
			m.facing=direction
			m.soft_toy_contact=true;m.soft_toy_time=0
			m.say("찾았다, 킁킁" if id=="toy_mouse" else "한 번 더 굴려볼까")
		return true
	id=key.trim_prefix("home_")
	species=m.species
	round_index=0
	direction=1 if not room.pieces[id].mirrored else -1
	stage="inspect"
	clock=0
	m.phase="sniff"
	m.elapsed=0
	m.action_left=20
	m.soft_toy_contact=true;m.soft_toy_time=0
	m.say("어디로 가는 거야?" if id=="toy_mouse" else "톡, 굴려볼까")
	return true
func cancel() -> void:
	if is_instance_valid(hug_piece): hug_piece.show()
	hug_piece=null
	if is_instance_valid(contact_motion):
		contact_motion.soft_toy_contact=false
		contact_motion.soft_toy_time=0
		contact_motion.soft_toy_prop=""
	contact_motion=null
	id="";stage="";clock=0;user_motion.clear()
func begin_follow(room) -> void:
	var piece=room.pieces[id]
	var m=room.app.pet.motion
	start=Vector2(piece.position)
	var distance=72.0 if id=="toy_mouse" else 54.0
	var found=false
	for sign_value in [direction,-direction]:
		var candidate=Vector2(piece.clamp_position(start+Vector2(distance*sign_value,0)))
		# Keep the animal's trailing point inside its actual activity space.
		var center=candidate.x+piece.size.x*.5
		if center< m.bounds.position.x+45 or center>m.bounds.end.x-45: continue
		var corridor=Rect2(start,Vector2(piece.size)).merge(Rect2(candidate,Vector2(piece.size))).grow(6)
		var blocked=false
		for other in room.pieces:
			if other!=id and room.pieces[other].visible and corridor.intersects(Rect2(Vector2(room.pieces[other].position),Vector2(room.pieces[other].size))): blocked=true
		for prop in room.app.props.values():
			if prop.visible and corridor.intersects(Rect2(Vector2(prop.position),Vector2(prop.size))): blocked=true
		if not blocked and absf(candidate.x-start.x)>18:
			goal=candidate;direction=sign_value;found=true;break
	if not found:
		finish(room)
		return
	stage="follow"
	clock=0
	m.phase="visit"
	m.soft_toy_contact=false
	m.visit_action="sniff"
	m.action_left=20
	m.elapsed=0
	pet_start=m.feet
	pet_goal=(follow_point(room)+goal-start).clamp(m.bounds.position,m.bounds.end)
	m.target=pet_goal
	m.say("살금살금 따라가자" if id=="toy_mouse" else "데굴데굴, 기다려")
func follow_point(room) -> Vector2:
	var piece=room.pieces[id]
	var m=room.app.pet.motion
	var point=piece.art_point(Vector2(.5,1.0))+Vector2(-direction*42,0)
	return point.clamp(m.bounds.position,m.bounds.end)
func launch_user(room,toy_id: String,velocity: Vector2) -> void:
	if toy_id not in ["toy_ball","toy_mouse"] or not room.pieces.has(toy_id): return
	cancel()
	var piece=room.pieces[toy_id]
	var m=room.app.pet.motion
	contact_motion=m
	var friction=170.0 if toy_id=="toy_ball" else 230.0
	var speed=clampf(velocity.x,-360,360)
	var stop=Vector2(piece.clamp_position(Vector2(piece.position)+Vector2(signf(speed)*speed*speed/(2*friction),0)))
	var point=piece.art_point(Vector2(.5,1))+stop-Vector2(piece.position)+Vector2(-signf(speed)*42,0)
	user_motion={"id":toy_id,"position":Vector2(piece.position),"speed":speed,"friction":friction,"species":m.species,"settled":false,"arrived":false,"time":0.0,"inspect":0.0}
	m.visit(point.clamp(m.bounds.position,m.bounds.end),"sniff","home_"+toy_id,true)
	m.say("쥐가 움직인다!" if toy_id=="toy_mouse" else "데굴데굴, 같이 놀자")
func advance_user(room,delta: float) -> void:
	var key=str(user_motion.id)
	if not is_instance_valid(room.app.pet) or not room.pieces.has(key): cancel();return
	var piece=room.pieces[key]
	var m=room.app.pet.motion
	if piece.dragging or m.held or m.carried or m.species!=user_motion.species or m.visit_id!="home_"+key or room.app.decorating:
		room.save();cancel();return
	if room.app.pet.menu.visible: return
	user_motion.time+=delta
	var old_speed=float(user_motion.speed)
	var new_speed=move_toward(old_speed,0,float(user_motion.friction)*delta)
	var previous=Vector2(piece.position)
	var proposed=Vector2(user_motion.position)+Vector2((old_speed+new_speed)*.5*delta,0)
	var limited=Vector2(piece.clamp_position(proposed))
	# Preserve subpixel travel instead of rounding the simulation every frame.
	if absf(limited.x-proposed.x)>1:
		proposed.x=limited.x;new_speed=-new_speed*.3
	piece.position=Vector2i(proposed.round())
	user_motion.position=proposed;user_motion.speed=new_speed
	if key=="toy_ball": piece.roll_angle+=(piece.position.x-previous.x)/maxf(1,piece.sprite.texture.get_width()*piece.sprite.scale.x*.5)
	if absf(new_speed)<1 and not user_motion.settled:
		user_motion.settled=true
		room.save()
		var point=piece.art_point(Vector2(.5,1))+Vector2(-signf(old_speed)*42,0)
		user_motion.arrived=false
		m.visit(point.clamp(m.bounds.position,m.bounds.end),"sniff","home_"+key,true)
	if user_motion.arrived:
		m.action_left=maxf(m.action_left,2)
		m.soft_toy_contact=true
		if user_motion.settled:
			user_motion.inspect+=delta
			m.soft_toy_time=float(user_motion.inspect)
	if user_motion.inspect>=2.4 or user_motion.time>30:
		room.save();m.react("happy",1.4,"interaction_done");m.say("같이 놀아줘서 좋아");cancel()
func advance(room,delta: float) -> void:
	if not user_motion.is_empty(): advance_user(room,delta);return
	if not busy(): return
	if not is_instance_valid(room.app.pet) or not room.pieces.has(id): cancel();return
	var m=room.app.pet.motion
	var piece=room.pieces[id]
	if m.species!=species or m.visit_id!="home_"+id or m.held or m.carried or piece.dragging or room.app.decorating:
		cancel();return
	if room.app.pet.menu.visible: return
	clock+=delta
	if stage=="hug":
		if clock>=preload("res://scripts/home_animation.gd").duration("home_toy_plush"): finish(room)
	elif stage=="inspect":
		m.action_left=maxf(m.action_left,2)
		m.soft_toy_time=clock
		if clock>=2.4:
			if round_index>=2: finish(room)
			else: round_index+=1;begin_follow(room)
	elif stage=="follow":
		# The animal has ONE fixed destination for the whole walking leg.
		# Toy progress follows real travel; its rounded native window coordinates
		# never become a moving, jittering destination for the animal.
		var t=clampf(pet_start.distance_to(m.feet)/maxf(.01,pet_start.distance_to(pet_goal)),0,1)
		var previous_x=piece.position.x
		piece.position=Vector2i(start.lerp(goal,t).round())
		if id=="toy_ball": piece.roll_angle+=(piece.position.x-previous_x)/maxf(1,piece.sprite.texture.get_width()*piece.sprite.scale.x*.5)
func finish(room) -> void:
	var m=room.app.pet.motion
	room.save()
	m.react("happy",1.4,"interaction_done")
	m.say("잡았다!" if id=="toy_mouse" else ("꼬옥, 내 인형" if id=="toy_plush" else "공놀이 재밌어"))
	cancel()
