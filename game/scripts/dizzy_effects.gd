extends Node2D
const Style=preload("res://scripts/pet_visual_style.gd")
var view
var particles: Array=[]
var hover_left=0.0
var sparkle_clock=0.0
var last_action=""
var last_reaction=""
var reaction_elapsed=0.0
const MAX_PARTICLES=Style.PARTICLE_LIMIT

func tint(color: Color,alpha: float) -> Color:
	return Color(color,clampf(alpha,0,1))

func burst(kind: String,at: Vector2,count: int=2) -> void:
	# Petting already draws one heart in View; avoid a second overlapping burst.
	if kind=="heart" and view and view.motion.joy_left>0: return
	count=mini(count,2)
	for i in range(count):
		particles.append({"kind":kind,"at":at+Vector2((i-(count-1)*.5)*12,0),"velocity":Vector2((i-(count-1)*.5)*4,-13-i*2),"age":0.0,"life":1.15+i*.1,"spin":float(i)})
	while particles.size()>MAX_PARTICLES: particles.pop_front()

func _process(delta: float) -> void:
	if view and view.sprite and view.sprite.texture:
		var action=str(view.motion.phase)
		var reaction=str(view.motion.reaction) if action=="react" else ""
		if action!=last_action or reaction!=last_reaction:
			reaction_elapsed=0.0
			particles.clear()
			var center: Vector2=orbit_layout().center
			if action in ["prop_use","playful","signature"]: burst("sparkle",center,2)
			if reaction in ["happy","yum","gift","pet"]: burst("heart",center,1)
			last_action=action
			last_reaction=reaction
		reaction_elapsed+=delta
	for particle in particles:
		particle.age+=delta
		particle.at+=particle.velocity*delta
	particles=particles.filter(func(p): return p.age<p.life)
	hover_left=maxf(0,hover_left-delta)
	sparkle_clock+=delta
	queue_redraw()

func orbit_layout() -> Dictionary:
	var rect: Rect2=view.visible_head_bounds()
	return {"center":Vector2(rect.get_center().x,rect.position.y-11),"radius":Vector2(clampf(rect.size.x*.42,16,32),7)}

func star(at: Vector2,radius: float,color: Color,angle: float=0.0) -> void:
	var points=PackedVector2Array()
	for i in range(8):
		var a=angle-PI*.5+i*PI/4
		points.append(at+Vector2(cos(a),sin(a))*radius*(1.0 if i%2==0 else .22))
	draw_colored_polygon(points,color)

func heart(at: Vector2,radius: float,color: Color) -> void:
	var points=PackedVector2Array()
	for i in range(33):
		var a=i*TAU/32
		points.append(at+Vector2(16*pow(sin(a),3),-(13*cos(a)-5*cos(2*a)-2*cos(3*a)-cos(4*a)))*radius/16)
	draw_colored_polygon(points,color)

func _draw() -> void:
	if not view or not view.sprite or not view.sprite.texture: return
	var motion=view.motion
	var layout=orbit_layout()
	var center: Vector2=layout.center
	if motion.phase=="dizzy" and motion.soft_dizzy_wobble:
		var fade=minf(smoothstep(0,.2,motion.elapsed),clampf((motion.dizzy_duration-motion.elapsed)/.8,0,1))
		var orbit: Vector2=layout.radius
		var trail=PackedVector2Array()
		for j in range(49):
			var a=j*TAU/48
			trail.append(center+Vector2(cos(a),sin(a))*orbit)
		draw_polyline(trail,tint(Style.OAT,.18*fade),1,true)
		for i in range(2):
			var angle=motion.elapsed*TAU*.65+i*PI
			star(center+Vector2(cos(angle),sin(angle))*orbit,3.5,tint(Style.OAT,.8*fade),.15)
	elif motion.phase=="drop":
		for i in range(2):
			var at=center+Vector2((i*2-1)*17,10+i*6)
			draw_line(at,at+Vector2(0,7),tint(Style.MIST,.45),1,true)
	elif motion.is_struggling():
		var fade=.45+.15*sin(sparkle_clock*3)
		for i in range(2):
			var at=center+Vector2((i*2-1)*(layout.radius.x+3),8)
			draw_arc(at,3,-PI*.65,PI*.35,10,tint(Style.OAT,fade),1,true)
	if hover_left>0 and motion.phase not in ["dizzy","drop"] and not motion.carried:
		star(center+Vector2(layout.radius.x,1),3,tint(Style.SAGE,minf(.65,hover_left*.7)))
	if motion.phase=="react":
		var envelope=smoothstep(0,.15,reaction_elapsed)*(1.0-smoothstep(.7,1.35,reaction_elapsed))
		if motion.reaction=="surprised":
			var at=center+Vector2(layout.radius.x,4)
			draw_line(at-Vector2(0,4),at,tint(Style.OAT,.8*envelope),1.5,true)
			draw_circle(at+Vector2(0,3),.9,tint(Style.OAT,.8*envelope))
		elif motion.reaction=="angry":
			var points=PackedVector2Array()
			for i in range(12): points.append(center+Vector2(layout.radius.x+sin(i*.45)*2,6-i*.9-reaction_elapsed*3))
			draw_polyline(points,tint(Style.ROSE,.65*envelope),1.2,true)
		elif motion.reaction=="sleepy":
			draw_arc(center+Vector2(layout.radius.x,4-reaction_elapsed*4),3,0,TAU,16,tint(Style.MIST,.5*envelope),1,true)
	for particle in particles:
		var alpha=sin(clampf(particle.age/particle.life,0,1)*PI)*.72
		if particle.kind=="heart": heart(particle.at,3.3,tint(Style.ROSE,alpha))
		else: star(particle.at,2.8,tint(Style.SAGE,alpha))
