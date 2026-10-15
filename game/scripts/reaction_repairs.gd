extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
static var sheet: Array=[]
static func apply(species: int, sequence: Array) -> Array:
	var row=[5,13,15,9].find(species)
	if row<0: return sequence
	if sheet.is_empty():
		var path="res://assets/reactions/edge-repair.png"
		sheet=Keyed.AnimationRegions.frames(path,Keyed.pixels(path))
	if sheet.size()!=32: return sequence
	var source: Array=sheet.slice(row*8,row*8+8)
	var target_image: Image=sequence[0].get_image()
	var target_bounds=target_image.get_used_rect()
	var neutral: Rect2i=source[0].get_image().get_used_rect()
	var extent=Vector2.ZERO
	for frame in source: extent=extent.max(Vector2(frame.get_image().get_used_rect().size))
	var factor=minf(float(target_bounds.size.y)/neutral.size.y,minf((target_image.get_width()-12)/extent.x,(target_image.get_height()-12)/extent.y))
	var offset=8 if species==9 else 56
	for i in range(8):
		var raw: Image=source[i].get_image()
		var cut=raw.get_region(raw.get_used_rect())
		cut.resize(maxi(1,roundi(cut.get_width()*factor)),maxi(1,roundi(cut.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		var frame=Image.create(target_image.get_width(),target_image.get_height(),false,Image.FORMAT_RGBA8)
		frame.fill(Color.TRANSPARENT)
		frame.blit_rect(cut,Rect2i(Vector2i.ZERO,cut.get_size()),Vector2i((frame.get_width()-cut.get_width())/2,target_bounds.end.y-cut.get_height()))
		sequence[offset+i]=ImageTexture.create_from_image(frame)
	return sequence
