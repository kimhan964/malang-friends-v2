extends RefCounted

var age=0.0
var stroking=false
var dragging=false
var stroke_distance=0.0
var last=Vector2.ZERO
var drag_offset=Vector2.ZERO

func reset() -> void:
	age=0.0
	stroking=false
	dragging=false
	stroke_distance=0.0
	last=Vector2.ZERO
	drag_offset=Vector2.ZERO

func sample(displacement: Vector2, delta: float) -> String:
	age+=delta
	if dragging: return "drag"
	# A small horizontal rub is petting; lifting or moving farther picks up.
	var limit=60.0 if age>=.18 else 36.0
	if absf(displacement.y)>24 or displacement.length()>limit:
		var direction=displacement.normalized()
		var threshold=minf(limit,24.0/absf(direction.y)) if absf(direction.y)>.0001 else limit
		drag_offset=direction*minf(threshold,displacement.length())
		dragging=true
		return "drag"
	if age>=.18:
		stroking=true
		stroke_distance+=displacement.distance_to(last)
	last=displacement
	return "stroke" if stroking else "press"
