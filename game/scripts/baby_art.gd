extends RefCounted
const Regions=preload("res://scripts/animation_regions.gd")
const Keyed=preload("res://scripts/keyed_art.gd")
static var sheets: Dictionary={}
static var bounds: Dictionary={}
static var preview_puppy=false
static var puppy_preview: Array=[]
static func frames(species: int) -> Array:
	if species==9:
		if puppy_preview.is_empty():
			var path="res://assets/babies/puppy-style-v3.png"
			puppy_preview=Regions.frames(path,Keyed.pixels(path)).slice(8,16)
		if not puppy_preview.is_empty(): bounds[species]=puppy_preview[0].get_image().get_used_rect()
		return puppy_preview
	var group=species/4
	if not sheets.has(group):
		var path="res://assets/babies/babies-toon-%d.png"%group
		var image=Keyed.pixels(path)
		if image==null: return []
		sheets[group]=Regions.frames(path,image)
	var row=species%4
	var sequence: Array=sheets[group].slice(row*8,row*8+8)
	if not sequence.is_empty(): bounds[species]=sequence[0].get_image().get_used_rect()
	return sequence

static var extras: Dictionary={}
static func extra_frames(species: int) -> Array:
	var group=species/4
	if not extras.has(group):
		var path="res://assets/babies/extra-%d.png"%group
		extras[group]=Regions.frames(path,Keyed.pixels(path))
	return extras[group].slice((species%4)*8,(species%4)*8+8)
