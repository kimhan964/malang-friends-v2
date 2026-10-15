extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var cache: Dictionary={}

static func resource(species: int) -> Resource:
	if not cache.has(species):
		var animal=load(Catalog.path(species)).duplicate()
		if species==0:
			# Two source eating frames have missing body alpha. Hold the adjacent
			# complete poses without modifying the restaurant's original resource.
			animal.frames=animal.frames.duplicate(true)
			animal.frames[2][11]=animal.frames[2][10]
			animal.frames[2][12]=animal.frames[2][13]
		cache[species]=animal
	return cache[species]
