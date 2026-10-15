extends SceneTree
const Prop=preload("res://scripts/desktop_prop.gd")
func _initialize() -> void:
	var p=Prop.new()
	p.kind="acorn"
	p.art_scale=.9
	var art=p.Decor.icon("acorn")
	var factor=minf(47.0/art.get_width(),57.0/art.get_height())
	var dimensions=art.get_size()*factor
	var mask=p.input_polygon()
	var outside=0
	var cases=0
	for step in range(121):
		var angle=lerpf(-.19,.19,step/120.0)
		for point in preload("res://scripts/animation_outline.gd").local_hull(art):
			var rotated=(Vector2(56,86)+(point*factor-Vector2(dimensions.x*.5,dimensions.y)).rotated(angle))*p.art_scale
			if not Geometry2D.is_point_in_polygon(rotated,mask): outside+=1
			cases+=1
	p.free()
	print("ACORN_CLIP vertices=",cases," outside_native_mask=",outside)
	quit(0 if outside==0 else 1)
