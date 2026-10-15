extends RefCounted
const AnimationRegions=preload("res://scripts/animation_regions.gd")

# Chroma-key asset decoding; generated PNG originals remain untouched.
static func pixels(path: String) -> Image:
	var image=Image.new()
	if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return null
	if image==null or image.is_empty(): return null
	image.convert(Image.FORMAT_RGBA8)
	var bytes=image.get_data()
	for i in range(0,bytes.size(),4):
		var spill=mini(bytes[i],bytes[i+2])-bytes[i+1]
		if spill>70:
			var alpha=1.0-smoothstep(70.0,155.0,float(spill))
			bytes[i+3]=int(bytes[i+3]*alpha)
			if alpha>0:
				bytes[i]=mini(bytes[i],bytes[i+1]+65)
				bytes[i+2]=mini(bytes[i+2],bytes[i+1]+65)
	return Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,bytes)

static func cells(path: String, columns: int, rows: int, trim: bool=true, row_edges: Array=[], column_edges: Array=[]) -> Array:
	var image=pixels(path)
	var result: Array=[]
	if image==null: return result
	if not trim and (path.begins_with("res://assets/reactions/") or path.begins_with("res://assets/habits/")):
		return AnimationRegions.frames(path,image)
	for row in range(rows):
		for column in range(columns):
			var x=floori(column*image.get_width()/float(columns))
			var y=floori(row*image.get_height()/float(rows))
			var right=floori((column+1)*image.get_width()/float(columns))
			var bottom=floori((row+1)*image.get_height()/float(rows))
			if column_edges.size()==columns+1:
				x=int(column_edges[column])
				right=int(column_edges[column+1])
			if row_edges.size()==rows+1:
				y=int(row_edges[row])
				bottom=int(row_edges[row+1])
			var cell=image.get_region(Rect2i(x,y,right-x,bottom-y))
			var used=cell.get_used_rect()
			if trim and used.has_area(): cell=cell.get_region(used)
			result.append(ImageTexture.create_from_image(cell))
	return result
