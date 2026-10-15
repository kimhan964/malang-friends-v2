extends RefCounted
## Complete-body VARCO cels: impact, lean left, lean right, recovery.
const Catalog=preload("res://scripts/animal_catalog.gd")
static var cache: Dictionary={}

static func texture(species: int,stage: String,index: int) -> Texture2D:
	if index<0 or index>3: return null
	var key=Catalog.IDS[species]+"/"+stage
	if not cache.has(key):
		var path="res://assets/dizzy-v1/"+key+".png"
		if not preload("res://scripts/asset_images.gd").exists(path): return null
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return null
		if image.get_width()!=1024 or image.get_height()!=256: return null
		var frames: Array=[]
		for i in range(4):
			frames.append(ImageTexture.create_from_image(image.get_region(Rect2i(i*256,0,256,256))))
		preload("res://scripts/animal_tone.gd").register(frames,species,stage)
		cache[key]=frames
	return cache[key][index]
