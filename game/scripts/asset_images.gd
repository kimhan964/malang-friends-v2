extends RefCounted
## Storage-only cropping. All callers receive the original canvas and coordinates.
static var index: Dictionary={}
static var initialized=false
static func metadata() -> Dictionary:
	if not initialized:
		initialized=true
		var path="res://assets/image-storage.json"
		if FileAccess.file_exists(path):
			var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary: index=parsed
	return index
static func exists(path: String) -> bool:
	var entry=metadata().get(path,{})
	return FileAccess.file_exists(str(entry.file)) if not entry.is_empty() else FileAccess.file_exists(path)
static func decode_into(image: Image,path: String) -> Error:
	var entry=metadata().get(path,{})
	if entry.is_empty(): return image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	var stored=Image.new()
	var bytes=FileAccess.get_file_as_bytes(str(entry.file))
	var error=stored.load_webp_from_buffer(bytes) if str(entry.file).ends_with(".webp") else stored.load_png_from_buffer(bytes)
	if error!=OK: return error
	stored.convert(Image.FORMAT_RGBA8)
	var canvas=Image.create(int(entry.size[0]),int(entry.size[1]),false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(stored,Rect2i(Vector2i.ZERO,stored.get_size()),Vector2i(int(entry.offset[0]),int(entry.offset[1])))
	image.copy_from(canvas)
	return OK
static func load_image(path: String) -> Image:
	var image=Image.new()
	return image if decode_into(image,path)==OK else null
