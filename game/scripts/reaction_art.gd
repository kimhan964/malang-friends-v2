extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const ROWS={"greet":0,"pet":1,"anticipate":2,"yum":3,"askplay":4,"nest":5,"gift":6,"full":7}
static var cache: Dictionary={}
static var bounds: Dictionary={}
static func frames(species: int) -> Array:
	if not cache.has(species):
		var sequence=Keyed.cells("res://assets/reactions/"+Catalog.IDS[species]+".png",8,8,false)
		sequence=preload("res://scripts/reaction_repairs.gd").apply(species,sequence)
		cache[species]=sequence
		if not sequence.is_empty(): bounds[species]=sequence[0].get_image().get_used_rect()
	return cache[species]
