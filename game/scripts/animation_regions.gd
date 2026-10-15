extends RefCounted
static var manifest: Dictionary={}

static func frames(path: String, source: Image) -> Array:
	if manifest.is_empty():
		manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animation-regions.json"))
	if not manifest.has(path): return []
	var sheet: Dictionary=manifest[path]
	if source.get_width()!=int(sheet.width) or source.get_height()!=int(sheet.height):
		push_error("Animation source changed; rebuild its region manifest: "+path)
		return []
	var left=0.0
	var right=0.0
	var top=0.0
	var bottom=0.0
	for region in sheet.regions:
		var body: Array=region.body
		var rect: Array=region.rect
		var anchor=Vector2(body[0]+body[2]*.5,body[1]+body[3])
		left=maxf(left,anchor.x-rect[0])
		right=maxf(right,rect[0]+rect[2]-anchor.x)
		top=maxf(top,anchor.y-rect[1])
		bottom=maxf(bottom,rect[1]+rect[3]-anchor.y)
	var size=Vector2i(ceili(maxf(left,right))*2+12,ceili(top+bottom)+12)
	var baseline=Vector2(size.x*.5,ceili(top)+6)
	var result: Array=[]
	for region in sheet.regions:
		var rect=Rect2i(int(region.rect[0]),int(region.rect[1]),int(region.rect[2]),int(region.rect[3]))
		var mask=Image.create(rect.size.x,rect.size.y,false,Image.FORMAT_RGBA8)
		mask.fill(Color.TRANSPARENT)
		for run in region.runs:
			var band=Rect2i(int(run[1])-rect.position.x-1,int(run[0])-rect.position.y-1,int(run[2])-int(run[1])+2,3)
			mask.fill_rect(band.intersection(Rect2i(Vector2i.ZERO,rect.size)),Color.WHITE)
		var cell=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		cell.fill(Color.TRANSPARENT)
		var body: Array=region.body
		var anchor=Vector2(body[0]+body[2]*.5,body[1]+body[3])
		var destination=Vector2i(baseline+Vector2(rect.position)-anchor)
		cell.blit_rect_mask(source.get_region(rect),mask,Rect2i(Vector2i.ZERO,rect.size),destination)
		result.append(ImageTexture.create_from_image(cell))
	return result
