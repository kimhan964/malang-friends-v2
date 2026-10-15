extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
static var cache: Dictionary={}
static var neutral_bounds: Dictionary={}
static func frames(species: int) -> Array:
	if not cache.has(species):
		var sequence: Array=[]
		if species>=8:
			var animal=load(Catalog.path(species))
			sequence=animal.frames[3]
		else:
			sequence=Keyed.cells("res://assets/habits/"+Catalog.IDS[species]+".png",4,2,false)
		cache[species]=sequence
		if not sequence.is_empty(): neutral_bounds[species]=sequence[0].get_image().get_used_rect()
	return cache[species]
