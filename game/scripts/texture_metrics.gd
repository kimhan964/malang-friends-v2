extends RefCounted
# Animation textures are immutable. Keep only their small bounds metadata.
static var bounds: Dictionary={}
static var head_spans: Dictionary={}
static var opaque_areas: Dictionary={}

static func opaque_area(texture: Texture2D) -> float:
	var key=texture.get_instance_id()
	if not opaque_areas.has(key):
		var image=texture.get_image()
		if image.get_format()!=Image.FORMAT_RGBA8: image.convert(Image.FORMAT_RGBA8)
		var pixels=image.get_data()
		var total=0.0
		for index in range(3,pixels.size(),4): total+=pixels[index]
		opaque_areas[key]=maxf(1.0,total/255.0)
	return opaque_areas[key]
static func used_rect(texture: Texture2D) -> Rect2i:
	var key=texture.get_instance_id()
	if not bounds.has(key): bounds[key]=texture.get_image().get_used_rect()
	return bounds[key]

static func head_span(texture: Texture2D) -> float:
	var key=texture.get_instance_id()
	if not head_spans.has(key):
		var image=texture.get_image()
		var used=used_rect(texture)
		var widths: Array=[]
		# The widest connected run in the upper silhouette measures the face
		# without including a detached tail, whisker or gap between long ears.
		for y in range(used.position.y,mini(image.get_height(),used.position.y+roundi(used.size.y*.62))):
			var run=0
			var longest=0
			for x in range(used.position.x,used.end.x):
				if image.get_pixel(x,y).a>.5:
					run+=1
					longest=maxi(longest,run)
				else: run=0
			if longest>0: widths.append(longest)
		widths.sort()
		head_spans[key]=float(widths[mini(widths.size()-1,int(widths.size()*.95))]) if not widths.is_empty() else 1.0
	return head_spans[key]

static var torso_spans: Dictionary={}
static func torso_span(texture: Texture2D) -> float:
	var key=texture.get_instance_id()
	if not torso_spans.has(key):
		var image=texture.get_image()
		var used=used_rect(texture)
		var widths: Array=[]
		for y in range(used.position.y+roundi(used.size.y*.50),used.position.y+roundi(used.size.y*.85)):
			var run=0;var longest=0
			for x in range(used.position.x,used.end.x):
				if image.get_pixel(x,y).a>.5: run+=1;longest=maxi(longest,run)
				else: run=0
			if longest>0: widths.append(longest)
		widths.sort()
		torso_spans[key]=float(widths[widths.size()/2]) if not widths.is_empty() else 1.0
	return torso_spans[key]
