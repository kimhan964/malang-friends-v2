extends RefCounted
static var cels: Array=[]
static func frames() -> Array:
	if cels.is_empty():
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-toys/mouse-walk.png"))
		for i in range(64):cels.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*256,int(i/8)*224,256,224))))
	return cels
static func sample(time: float,moving: bool) -> Texture2D:
	var all=frames()
	return all[int(fposmod(time/(.68 if moving else 2.8),1)*64)]
