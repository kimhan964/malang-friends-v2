extends RefCounted
# Runtime color calibration only: keep all original image assets intact.
# Match warm fur tones; do not tint white markings, eyes, scarves or food.
static var cache: Dictionary={}
static var samples: Dictionary={}
static func warm_palette(texture: Texture2D) -> Array:
	var key=texture.get_instance_id()
	if samples.has(key): return samples[key]
	var image=texture.get_image()
	var colors: Array[Vector3]=[]
	for y in range(0,image.get_height(),3):
		for x in range(0,image.get_width(),3):
			var c=image.get_pixel(x,y)
			var light=(c.r+c.g+c.b)/3.0
			if c.a>.95 and light>.12 and light<.88 and c.r>=c.g and c.g-c.b>.012 and c.r-c.b>.035 and c.r-c.b<.38 and c.r-c.g<(c.g-c.b)*2+.02:
				colors.append(Vector3(c.r,c.g,c.b))
	var centers=[Vector3(.28,.23,.19),Vector3(.52,.44,.38),Vector3(.77,.68,.59)]
	for iteration in range(10):
		var sums=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
		var counts=[0,0,0]
		for c in colors:
			var nearest=0
			for i in range(1,3):
				if c.distance_squared_to(centers[i])<c.distance_squared_to(centers[nearest]): nearest=i
			sums[nearest]+=c
			counts[nearest]+=1
		for i in range(3):
			if counts[i]>0: centers[i]=sums[i]/counts[i]
	centers.sort_custom(func(a,b): return a.x+a.y+a.z<b.x+b.y+b.z)
	samples[key]=centers
	return centers
static func register(sequence: Array, reference: Texture2D, neutral: Texture2D=null) -> void:
	if sequence.is_empty(): return
	var source=warm_palette(neutral if neutral!=null else sequence[0])
	var target=warm_palette(reference)
	var levels=Vector3.ZERO
	var shifts=[]
	for i in range(3):
		levels[i]=(source[i].x+source[i].y+source[i].z)/3.0
		shifts.append((target[i]-source[i]).clamp(Vector3.ONE*-.10,Vector3.ONE*.10))
	for texture in sequence: cache[texture.get_instance_id()]={"levels":levels,"shifts":shifts}
static func apply(material: ShaderMaterial, texture: Texture2D) -> void:
	var calibration=cache.get(texture.get_instance_id(),{})
	material.set_shader_parameter("fur_match",not calibration.is_empty())
	if calibration.is_empty(): return
	material.set_shader_parameter("fur_levels",calibration.levels)
	for i in range(3): material.set_shader_parameter("fur_shift%d"%i,calibration.shifts[i])
