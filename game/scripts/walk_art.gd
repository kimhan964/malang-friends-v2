extends RefCounted
## Thirty-two complete-body cels: original contact poses and VARCO in-betweens.
const Catalog=preload("res://scripts/animal_catalog.gd")
static var cache: Dictionary={}

static func frames(species: int,stage: String) -> Array:
	var key=Catalog.IDS[species]+"/"+stage
	if not cache.has(key):
		# Keep recent stages only; visiting every species must not retain all
		# thirty-two texture strips in memory for the rest of the session.
		if cache.size()>=4: cache.clear()
		var file="res://assets/walk-v4/"+key+".png"
		if not preload("res://scripts/asset_images.gd").exists(file): return []
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,file)!=OK: return []
		if image.get_size()!=Vector2i(8192,256): return []
		var result: Array=[]
		for i in range(32):
			result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i*256,0,256,256))))
		cache[key]=result
	return cache[key]

static func texture(species: int,stage: String,index: int) -> Texture2D:
	var result=frames(species,stage)
	return result[index] if result.size()==32 and index>=0 and index<32 else null
