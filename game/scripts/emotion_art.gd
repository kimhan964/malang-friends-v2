extends RefCounted
## Full-body expression cels generated from each species' baby/adult master.
const Catalog=preload("res://scripts/animal_catalog.gd")
const KINDS=["surprised","happy","angry","sleepy"]
static var cache: Dictionary={}

static func texture(species: int,stage: String,kind: String) -> Texture2D:
	var index=KINDS.find(kind)
	if index<0: return null
	var key=Catalog.IDS[species]+"/"+stage
	if not cache.has(key):
		var path="res://assets/emotions-v2/"+key+".png" if species==1 else "res://assets/emotions-v1/"+key+".png"
		if not preload("res://scripts/asset_images.gd").exists(path): return null
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return null
		if image==null or image.get_width()!=1024 or image.get_height()!=256: return null
		var frames: Array=[]
		for i in range(4):
			frames.append(ImageTexture.create_from_image(image.get_region(Rect2i(i*256,0,256,256))))
		for texture in frames: preload("res://scripts/animal_tone.gd").register([texture],species,stage)
		cache[key]=frames
	return cache[key][index]
