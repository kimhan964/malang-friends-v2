extends RefCounted
static func plush(m,hand: Vector2) -> Dictionary:
	var duration=preload("res://scripts/home_animation.gd").duration("home_toy_plush")
	var loops=maxi(1,roundi((duration-1.3)/2.4))
	var cycle=clampf((m.elapsed-.65)/maxf(.01,duration-1.3),0,1)*loops
	var phase=fposmod(cycle,1)
	var toss=sin(clampf((phase-.74)/.26,0,1)*PI) if int(cycle)%3==2 else 0.0
	return {"position":hand+Vector2(sin(phase*TAU)*3,-toss*22),"angle":sin(phase*TAU)*.13+toss*.22,"reach":smoothstep(.25,1.25,m.elapsed)*smoothstep(.25,1.25,m.action_left),"toss":toss}
