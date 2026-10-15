extends SceneTree
const Piece=preload("res://scripts/furniture_window.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var p=Piece.new()
	p.item_id="toy_ball"
	root.add_child(p)
	await process_frame
	var failures=[]
	var half=p.sprite.texture.get_size()*p.sprite.scale*.5
	for i in range(180):
		var angle=TAU*i/180.0
		for corner in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
			var at=p.art_origin+half+corner.rotated(angle)
			# Includes the authored 3px wobble and two pixels of filter bleed.
			if not Rect2(Vector2(5,5),Vector2(p.size)-Vector2(10,10)).has_point(at): failures.append(angle)
			if not Geometry2D.is_point_in_polygon(at,p.mouse_passthrough_polygon): failures.append("native clipping "+str(angle))
	p.queue_free()
	await process_frame
	print("TOY BALL BOUNDS: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
