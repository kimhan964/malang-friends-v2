extends RefCounted
static var cache: Dictionary={}
static func texture(id: String) -> Texture2D:
	if not cache.has(id):
		var path: String="res://assets/v2-shared/"+id+".png"
		if not FileAccess.file_exists(path): return null
		var image=Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK: return null
		cache[id]=ImageTexture.create_from_image(image)
	return cache[id]
