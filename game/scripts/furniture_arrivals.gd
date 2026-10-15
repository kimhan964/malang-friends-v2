extends RefCounted
const ITEMS=["toy_ball","toy_mouse","alarm_clock"]
var fall: Dictionary={}
var pending=""
var delay=5.0
func busy() -> bool: return not fall.is_empty() or not pending.is_empty()
func advance(room,delta: float) -> void:
	var app=room.app
	if not is_instance_valid(app.pet): return
	if not fall.is_empty():
		if not room.pieces.has(fall.id): fall.clear();pending="";return
		if app.delivery_paused(): return
		fall.time+=delta
		var t=clampf(fall.time/1.4,0,1)
		var y=lerpf(fall.start.y,fall.target.y,pow(minf(t/.8,1),2))
		if t>.8: y-=sin((t-.8)/.2*PI)*10*(1-(t-.8)/.2)
		var piece=room.pieces[fall.id]
		piece.position=Vector2i(fall.target.x,roundi(y))
		if t>=1:
			piece.position=fall.target
			piece.arriving=false
			piece.update_input()
			pending=fall.id
			fall.clear()
			room.save()
			app.request_layer_order()
		return
	if app.delivery_paused() or not app.pet.motion.autonomy: return
	if not app.falling_gifts.is_empty() or not app.pending_gift_visits.is_empty() or not app.delivery_queue.is_empty(): return
	var m=app.pet.motion
	if m.energy<35 or m.satiety<48 or m.hydration<45: return
	if m.phase!="idle": return
	if not pending.is_empty():
		var id=pending
		pending=""
		if room.pieces.has(id): room.use_piece(id)
		delay=6.0
		return
	delay=maxf(0,delay-delta)
	for id in ITEMS:
		if app.state.arrival_seen.get(id,false) or not app.state.furniture_available(id): continue
		if room.pieces.has(id):
			app.state.arrival_seen[id]=true
			app.state.save_game()
			continue
		m.rest_left=maxf(m.rest_left,delay+.1)
		if delay<=0: start(room,id)
		return
func start(room,id: String) -> bool:
	if room.pieces.has(id) or not room.app.state.furniture_available(id): return false
	room.place(id,Vector2(500,300),false)
	if not room.pieces.has(id): return false
	var app=room.app
	var piece=room.pieces[id]
	var best=Vector2i.ZERO
	var found=false
	for dx in [120,-120,230,-230,340,-340,460,-460]:
		piece.position=piece.clamp_position(Vector2(app.pet.motion.feet.x+dx-piece.size.x*.5,app.pet.motion.feet.y-piece.size.y+10))
		room.floor_piece(piece)
		var area=Rect2i(piece.position,piece.size).grow(10)
		var blocked=false
		for other in room.pieces:
			if other!=id and room.pieces[other].visible and area.intersects(Rect2i(room.pieces[other].position,room.pieces[other].size)): blocked=true
		for prop in app.props.values():
			if prop.visible and area.intersects(Rect2i(prop.position,prop.size)): blocked=true
		if not blocked: best=piece.position;found=true;break
	if not found:
		room.remove_piece(id)
		delay=15.0
		return false
	var start=Vector2i(best.x,app.usable_screen().position.y-piece.size.y-12)
	fall={"id":id,"target":best,"start":start,"time":0.0}
	piece.arriving=true
	piece.position=start
	piece.update_input()
	app.state.home_owned[id]=true
	app.state.arrival_seen[id]=true
	app.pet.motion.context_reactions.queue("gift")
	room.save()
	return true
