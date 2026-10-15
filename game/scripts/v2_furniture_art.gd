extends RefCounted
const IDS=["sofa","daybed","bathtub"]
static var metadata: Dictionary={}
static var banks: Dictionary={}
static func data() -> Dictionary:
	if metadata.is_empty(): metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2-furniture-life/manifest.json"))
	return metadata
static func frames(id: String) -> Array:
	if not banks.has(id):
		var spec: Dictionary=data()[id]
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-furniture-life/"+str(spec.file)))
		var cels: Array=[]
		for i in range(int(spec.count)): cels.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*512,int(i/8)*320,512,320))))
		banks[id]=cels
	return banks[id]
static func sample(id: String,time: float,using: bool) -> Texture2D:
	var cels: Array=frames(id)
	var index: int=mini(cels.size()-1,int(fposmod(time/float(data()[id].duration),1)*cels.size())) if using else 0
	return cels[index]
static var front: Texture2D
static func bath_front() -> Texture2D:
	if front==null:
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/v2-furniture-life/bathtub-front.png"))
		front=ImageTexture.create_from_image(image)
	return front
