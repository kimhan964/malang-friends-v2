extends RefCounted
## Match each complete action bank to the current age's approved idle palette.
## Fixed bank calibration keeps tone stable across every cel and transition.
const Catalog=preload("res://scripts/animal_catalog.gd")
static var references={}
static var calibrations={}
static var active_materials={}
static func palette(images: Array) -> Array:
	var points: Array[Vector3]=[]
	for image in images:
		for y in range(0,image.get_height(),4):
			for x in range(0,image.get_width(),4):
				var c=image.get_pixel(x,y)
				if c.a>.95 and c.get_luminance()>.16:
					points.append(Vector3(c.r,c.g,c.b))
	if points.is_empty(): return []
	points.sort_custom(func(a,b): return a.dot(Vector3(.2126,.7152,.0722))<b.dot(Vector3(.2126,.7152,.0722)))
	var centers=[points[int(points.size()*.15)],points[int(points.size()*.5)],points[int(points.size()*.85)]]
	for iteration in range(8):
		var sums=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
		var counts=[0,0,0]
		for point in points:
			var nearest=0
			for i in range(1,3):
				if point.distance_squared_to(centers[i])<point.distance_squared_to(centers[nearest]): nearest=i
			sums[nearest]+=point
			counts[nearest]+=1
		for i in range(3):
			if counts[i]>0: centers[i]=sums[i]/counts[i]
	return centers
static func reference_palette(species: int,age: String) -> Array:
	var key="%d/%s"%[species,age]
	if not references.has(key):
		var path="res://assets/rabbit-frame-pilot-v9/%s-idle.png"%age
		if species>0:
			var root="res://assets/walk-v14/%s/"%Catalog.IDS[species]
			var metadata=JSON.parse_string(FileAccess.get_file_as_string(root+"manifest.json"))
			path=root+str(metadata.stages[age].idle_file)
		var image=Image.new()
		preload("res://scripts/asset_images.gd").decode_into(image,path)
		image=image.get_region(Rect2i(0,0,256,256))
		references[key]=palette([image])
	return references[key]
static func register(sequence: Array,species: int,age: String) -> void:
	if sequence.is_empty(): return
	var target=reference_palette(species,age)
	var images=[sequence[0].get_image()]
	if sequence.size()>2:
		images.append(sequence[sequence.size()/2].get_image())
		images.append(sequence[-1].get_image())
	var source=palette(images)
	if source.is_empty() or target.is_empty(): return
	var best=[0,1,2]
	var distance=INF
	for order in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
		var score=0.0
		for i in range(3): score+=source[i].distance_squared_to(target[order[i]])
		if score<distance: distance=score; best=order
	var matched=[]
	for i in range(3):
		# Bound changes and reject mismatched accessory/food hues.
		var shift=(target[best[i]]-source[i]).clamp(Vector3.ONE*-.14,Vector3.ONE*.14)
		matched.append(source[i]+shift if source[i].distance_to(target[best[i]])<.34 else source[i])
	var calibration={"source":source,"target":matched}
	for texture in sequence: calibrations[texture.get_instance_id()]=calibration
static func apply(material: ShaderMaterial,texture: Texture2D) -> void:
	var key=texture.get_instance_id()
	var owner=material.get_instance_id()
	if active_materials.get(owner,-1)==key: return
	active_materials[owner]=key
	var values=calibrations.get(key,{})
	material.set_shader_parameter("tone_match",not values.is_empty())
	if values.is_empty(): return
	for i in range(3):
		var a: Vector3=values.source[i]
		var b: Vector3=values.target[i]
		material.set_shader_parameter("tone_source%d"%i,Color(a.x,a.y,a.z))
		material.set_shader_parameter("tone_target%d"%i,Color(b.x,b.y,b.z))
static func release_other_species(_species: int) -> void:
	calibrations.clear()
	active_materials.clear()
