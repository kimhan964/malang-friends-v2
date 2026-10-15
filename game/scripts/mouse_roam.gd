extends RefCounted
## Short independent walking legs. A pet visit freezes the target until contact.
var moving=false
var position=Vector2.ZERO
var goal=Vector2.ZERO
var pause=1.2
var direction=1
var legs=0
var rng=RandomNumberGenerator.new()
func _init() -> void: rng.randomize()
func stop(piece) -> void:
	moving=false
	pause=maxf(pause,.8)
	position=Vector2(piece.position)
	piece.roam_speed=0.0
func clear_lane(room,piece,to: Vector2) -> bool:
	var origin=Rect2(Vector2(piece.position),Vector2(piece.size)).grow(3)
	var corridor=origin.merge(Rect2(to,Vector2(piece.size)).grow(3))
	for other in room.pieces.values():
		if other==piece or not other.visible or other.item_id=="play_rug" or room.Catalog.is_wall(other.item_id): continue
		var area=Rect2(Vector2(other.position),Vector2(other.size))
		# A user can place the toy over scenery; let it leave that overlap.
		if not origin.intersects(area) and corridor.intersects(area): return false
	for prop in room.app.props.values():
		var area=Rect2(Vector2(prop.position),Vector2(prop.size))
		if prop.visible and not origin.intersects(area) and corridor.intersects(area): return false
	return true
func begin_leg(room,piece) -> bool:
	position=Vector2(piece.position)
	var m=room.app.pet.motion
	if rng.randf()<.3: direction=-direction
	for distance in [rng.randf_range(70,150),45.0]:
		for sign_value in [direction,-direction]:
			var target=position+Vector2(distance*sign_value,0)
			target.x=clampf(target.x,m.bounds.position.x+8-piece.size.x*.5,m.bounds.end.x-8-piece.size.x*.5)
			var limited=Vector2(piece.clamp_position(target))
			if absf(limited.x-position.x)<24 or not clear_lane(room,piece,limited): continue
			goal=limited;direction=sign_value;moving=true
			piece.set_mirrored(direction<0)
			return true
	pause=1.5
	return false
func advance(room,delta: float) -> void:
	if not room.pieces.has("toy_mouse") or not is_instance_valid(room.app.pet): moving=false;return
	var piece=room.pieces.toy_mouse
	var m=room.app.pet.motion
	var arranging=is_instance_valid(room.panel) and room.panel.visible
	var resizing=is_instance_valid(piece.size_editor) and piece.size_editor.visible
	if not piece.visible or piece.dragging or piece.arriving or piece.menu.visible or arranging or resizing or room.app.decorating or room.app.pet.menu.visible or m.held or m.carried or m.resting or room.toy_play.busy() or m.visit_id=="home_toy_mouse":
		stop(piece);return
	if moving and Vector2(piece.position).distance_to(position)>2:
		stop(piece);return
	if not moving:
		piece.roam_speed=0.0
		pause=maxf(0,pause-delta)
		if pause<=0: begin_leg(room,piece)
		return
	# Ease in/out over a few pixels; retain floating-point movement between draws.
	var remaining=position.distance_to(goal)
	var speed=clampf(minf(remaining*5,piece.roam_speed+110*delta),10,42)
	var next=position.move_toward(goal,speed*delta)
	if not clear_lane(room,piece,next):
		direction=-direction;stop(piece);room.save();return
	position=next
	piece.position=Vector2i(position.round())
	piece.roam_speed=speed
	piece.roam_time+=delta
	if position.distance_to(goal)<.5:
		piece.position=Vector2i(goal.round())
		legs+=1;stop(piece);pause=rng.randf_range(.9,2.3)
		room.save()
