extends RefCounted
static var cache={}
static func texture(id: String) -> Texture2D:
	if not cache.has(id):
		var file="res://assets/ui-cozy-v1/"+id+".png"
		if FileAccess.file_exists("res://assets/v2-shared/ui-"+id+".png"): file="res://assets/v2-shared/ui-"+id+".png"
		if not preload("res://scripts/asset_images.gd").exists(file): return null
		var img=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(img,file)!=OK: return null
		cache[id]=ImageTexture.create_from_image(img)
	return cache[id]
static func decorate(button: Button,id: String,size: int=32) -> void:
	button.icon=texture(id)
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",size)
	button.add_theme_constant_override("h_separation",8)
