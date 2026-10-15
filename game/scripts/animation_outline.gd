extends RefCounted
static var outlines: Dictionary={}
static var hulls: Dictionary={}

static func local_hull(texture: Texture2D) -> PackedVector2Array:
	var key=texture.get_instance_id()
	if not hulls.has(key):
		var points=local_points(texture)
		hulls[key]=Geometry2D.convex_hull(points) if points.size()>=3 else points
	return hulls[key]

static func local_points(texture: Texture2D) -> PackedVector2Array:
	var key=texture.get_instance_id()
	if not outlines.has(key):
		var bitmap=BitMap.new()
		bitmap.create_from_image_alpha(texture.get_image(),.005)
		var points=PackedVector2Array()
		for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,bitmap.get_size()),1):
			points.append_array(polygon)
		outlines[key]=points
	return outlines[key]

static func blended_points(sprite: Sprite2D) -> PackedVector2Array:
	var points=PackedVector2Array()
	if sprite==null or sprite.texture==null: return points
	var next: Texture2D=sprite.material.get_shader_parameter("next_frame")
	var frames=[sprite.texture]
	if next!=null and next!=sprite.texture: frames.append(next)
	for texture in frames:
		var ratio=sprite.texture.get_size()/texture.get_size()
		# Fitting and hit testing both use convex extrema; interior outline
		# vertices do not affect either result under an affine transform.
		var transform=sprite.get_global_transform()*Transform2D.IDENTITY.scaled(ratio)
		points.append_array(transform*local_hull(texture))
	return points

static func fit(sprite: Sprite2D, anchor: Vector2, window_size: Vector2) -> void:
	var factor=1.0
	for point in blended_points(sprite):
		var delta=point-anchor
		if delta.x<0: factor=minf(factor,(anchor.x-5)/-delta.x)
		elif delta.x>0: factor=minf(factor,(window_size.x-5-anchor.x)/delta.x)
		if delta.y<0: factor=minf(factor,(anchor.y-5)/-delta.y)
		elif delta.y>0: factor=minf(factor,(window_size.y-5-anchor.y)/delta.y)
	if factor<1:
		var local_anchor=sprite.get_parent().get_global_transform().affine_inverse()*anchor
		sprite.position=local_anchor+(sprite.position-local_anchor)*factor
		sprite.scale*=factor
